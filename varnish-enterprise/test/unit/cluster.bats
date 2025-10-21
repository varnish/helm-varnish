#!/usr/bin/env bats

load _helpers

@test "Cluster: disabled by default, no secret" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/secret.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "false" ]
}

@test "Cluster: disabled by default, no service" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/service.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '. |
               select(.metadata.name != "release-name-varnish-enterprise")' | tee -a /dev/stderr)
    [ "${actual}" = "" ]
}

@test "Cluster: disabled by default, no configmap-vcl.yaml" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "false" ]
}

@test "Cluster: disabled by default, no VARNISH_CLUSTER_TOKEN" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -cr '.spec.template.spec.containers[] |
                select(.name == "varnish-enterprise").env[] |
                select(.name == "VARNISH_CLUSTER_TOKEN")' | tee -a /dev/stderr)
    [ "${actual}" = "" ]
}


@test "Cluster: check VARNISH_CLUSTER_TOKEN in default case" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -cr '.spec.template.spec.containers[] |
                select(.name == "varnish-enterprise").env[] |
                select(.name == "VARNISH_CLUSTER_TOKEN")' | tee -a /dev/stderr)
    [ "${actual}" = '{"name":"VARNISH_CLUSTER_TOKEN","valueFrom":{"secretKeyRef":{"name":"release-name-varnish-enterprise-cluster-secret","key":"token"}}}' ]
}

@test "Cluster: check configmap in default case" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --namespace default \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -cr '.data["wrapped-default.vcl"]' | tee -a /dev/stderr)
    echo "${actual}" | grep 'include "cluster.vcl";'
    echo "${actual}" | grep 'include "/etc/varnish/default.vcl";'
}

@test "Cluster: check headless service in default case" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --namespace default \
        --show-only templates/service.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -cr 'select(.metadata.name == "release-name-varnish-enterprise-peers").spec.ports' | tee -a /dev/stderr)
    [ "${actual}" = '[{"name":"http","port":6081,"targetPort":6081}]' ]
}

@test "Cluster: check secret in default case" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --namespace default \
        --show-only templates/secret.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -cr '.data.token' | tee -a /dev/stderr)
    [ "${actual}" != 'null' ]
}

@test "Cluster: check port if using non-default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'server.http.port=9999' \
        --namespace default \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -cr '.data["wrapped-default.vcl"]' | tee -a /dev/stderr)
    echo "${actual}" | grep '"release-name-varnish-enterprise-peers:9999"'
}

@test "Cluster: include path changes with vclConfigPath" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'server.vclConfigPath=/etc/varnish/non-default.vcl' \
        --namespace default \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -cr '.data["wrapped-default.vcl"]' | tee -a /dev/stderr)
    echo "${actual}" | grep 'include "/etc/varnish/non-default.vcl";'
}

@test "Cluster: no headless service if headlessServiceName is set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'cluster.headlessServiceName=foo-service' \
        --namespace default \
        --show-only templates/service.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '. |
               select(.metadata.name != "release-name-varnish-enterprise")' | tee -a /dev/stderr)
    [ "${actual}" = "" ]

    # wrapped-default.vcl should use foo-service though
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'cluster.headlessServiceName=foo-service' \
        --namespace default \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -cr '.data["wrapped-default.vcl"]' | tee -a /dev/stderr)
    echo "${actual}" | grep '"foo-service:6081"'

}

@test "Cluster: no secret if secretName is set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'cluster.secretName=foo-secret' \
        --namespace default \
        --show-only templates/secret.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "false" ]

    # wrapped-default.vcl should use foo-service though
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'cluster.secretName=foo-secret' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -cr '.spec.template.spec.containers[] |
                select(.name == "varnish-enterprise").env[] |
                select(.name == "VARNISH_CLUSTER_TOKEN")' | tee -a /dev/stderr)
    [ "${actual}" = '{"name":"VARNISH_CLUSTER_TOKEN","valueFrom":{"secretKeyRef":{"name":"foo-secret","key":"token"}}}' ]
}

@test "Cluster: server.http.enabled must be true" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'server.http.enabled=false' \
        --namespace default \
        --show-only templates/service.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "false" ]
}


