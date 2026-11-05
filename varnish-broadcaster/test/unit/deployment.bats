#!/usr/bin/env bats

load _helpers

@test "Deployment: image tag defaults to appVersion" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yq -r '.spec.template.spec.containers[] | select(.name == "broadcaster") | .image')
    [ "${actual}" = "docker.io/varnish/varnish-enterprise:$(app_version)" ]
}

@test "Deployment: image tag can be overridden" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --set image.tag=latest \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yq -r '[.spec.template.spec.initContainers[].image, .spec.template.spec.containers[].image] | unique | .[]')
    [ "${actual}" = "docker.io/varnish/varnish-enterprise:latest" ]
}

@test "Deployment: fails without discovery.groups" {
    cd "$(chart_dir)"
    run helm template \
        --namespace default \
        --show-only templates/deployment.yaml \
        .
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"discovery.groups must list at least one Service"* ]]
}

@test "Deployment: fails with TLS enabled but no secret" {
    cd "$(chart_dir)"
    run helm template \
        --set discovery.groups={varnish} \
        --set broadcaster.tls.enabled=true \
        --namespace default \
        --show-only templates/deployment.yaml \
        .
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"broadcaster.tls.secret is required"* ]]
}

@test "Deployment: discovery groups become -group arguments" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups='{foo,bar}' \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yqj '.spec.template.spec.containers[] | select(.name == "discovery") | .args')
    [ "${actual}" = '["k8s","-server","https://kubernetes.default.svc/","-nodefile","/etc/broadcaster/nodes.conf","-port","0","-proto","http","-group","foo","-group","bar"]' ]
}

@test "Deployment: discovery extraArgs are appended" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --set discovery.extraArgs='{-every,10s}' \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yqj '.spec.template.spec.containers[] | select(.name == "discovery") | .args[-2:]')
    [ "${actual}" = '["-every","10s"]' ]
}

@test "Deployment: init container runs discovery once" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yqj '.spec.template.spec.initContainers[] | select(.name == "discovery-init") | [.command[0], .args[0], .args[-1]]')
    [ "${actual}" = '["varnish-discovery","k8s","-once"]' ]
}

@test "Deployment: broadcaster listens on port 8088" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yq -r '.spec.template.spec.containers[] | select(.name == "broadcaster") | .args | join(" ")')
    [[ "${actual}" == *"-cfg /etc/broadcaster/nodes.conf -confwatch 2s"* ]]
    [[ "${actual}" == *" -port 8088 "* ]]
    [[ "${actual}" != *"-https-port"* ]]
}

@test "Deployment: management interface bound to localhost by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yq -r '.spec.template.spec.containers[] | select(.name == "broadcaster") | .args | join(" ")')
    [[ "${actual}" == *"-mgmt-port 8089 -mgmt-host 127.0.0.1"* ]]
}

@test "Deployment: management interface exposed when enabled" {
    cd "$(chart_dir)"
    local output=$((helm template \
        --set discovery.groups={varnish} \
        --set broadcaster.mgmt.enabled=true \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yq -r '.spec.template.spec.containers[] | select(.name == "broadcaster")')
    local args=$(echo "${output}" | yq -r '.args | join(" ")')
    [[ "${args}" == *"-mgmt-port 8089 -mgmt-host 0.0.0.0"* ]]
    local port=$(echo "${output}" | yq -r '.ports[] | select(.name == "mgmt") | .containerPort')
    [ "${port}" = "8089" ]
}

@test "Deployment: TLS adds HTTPS port, certificate and volume" {
    cd "$(chart_dir)"
    local output=$(helm template \
        --set discovery.groups={varnish} \
        --set broadcaster.tls.enabled=true \
        --set broadcaster.tls.secret=my-tls \
        --namespace default \
        --show-only templates/deployment.yaml \
        .)
    local args=$(echo "${output}" | yq -r '.spec.template.spec.containers[] | select(.name == "broadcaster") | .args | join(" ")')
    [[ "${args}" == *"-https-port 8443 -crt /etc/broadcaster-tls/tls.crt -key /etc/broadcaster-tls/tls.key"* ]]
    local port=$(echo "${output}" | yq -r '.spec.template.spec.containers[] | select(.name == "broadcaster") | .ports[] | select(.name == "https") | .containerPort')
    [ "${port}" = "8443" ]
    [[ "${args}" != *" -port "* ]]
    local ports=$(echo "${output}" | yq -r '.spec.template.spec.containers[] | select(.name == "broadcaster") | [.ports[].name] | join(",")')
    [ "${ports}" = "https" ]
    local secret=$(echo "${output}" | yq -r '.spec.template.spec.volumes[] | select(.name == "tls") | .secret.secretName')
    [ "${secret}" = "my-tls" ]
}

@test "Deployment: async mode" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --set broadcaster.async=true \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yq -r '.spec.template.spec.containers[] | select(.name == "broadcaster") | .args | contains(["-a"])')
    [ "${actual}" = "true" ]
}

@test "Deployment: broadcaster extraArgs are appended" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --set broadcaster.extraArgs='{-tls-verify,NONE}' \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yqj '.spec.template.spec.containers[] | select(.name == "broadcaster") | .args[-2:]')
    [ "${actual}" = '["-tls-verify","NONE"]' ]
}

@test "Deployment: probes ping the management interface" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yq -r '.spec.template.spec.containers[] | select(.name == "broadcaster") | .readinessProbe.exec.command[2]')
    [[ "${actual}" == *"/dev/tcp/127.0.0.1/8089"*"GET /api/ping"* ]]
}

@test "Deployment: probes use TLS when enabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --set broadcaster.tls.enabled=true \
        --set broadcaster.tls.secret=my-tls \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yq -r '.spec.template.spec.containers[] | select(.name == "broadcaster") | .livenessProbe.exec.command[2]')
    [[ "${actual}" == *"GET /api/ping"*"openssl s_client -quiet -connect 127.0.0.1:8089"* ]]
}

@test "Deployment: probes can be overridden" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --set livenessProbe.tcpSocket.port=http \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yqj '.spec.template.spec.containers[] | select(.name == "broadcaster") | .livenessProbe')
    [ "${actual}" = '{"tcpSocket":{"port":"http"}}' ]
}

@test "Deployment: probes can be disabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --set-json 'readinessProbe={}' \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yq -r '.spec.template.spec.containers[] | select(.name == "broadcaster") | has("readinessProbe")')
    [ "${actual}" = "false" ]
}


@test "Deployment: extraEnvs map" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --set extraEnvs.FOO=bar \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yqj '.spec.template.spec.containers[] | select(.name == "broadcaster") | .env')
    [ "${actual}" = '[{"name":"FOO","value":"bar"}]' ]
}
