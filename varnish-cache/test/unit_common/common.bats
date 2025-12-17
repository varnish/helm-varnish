#!/usr/bin/env bats

load ../unit/_helpers

kind=${kind:-}
template=${template:-}

@test "${kind}: inherits imagePullSecret from global" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.imagePullSecrets[0].name=quay.io-varnish-software' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.imagePullSecrets' | tee -a /dev/stderr)
    [ "${actual}" == '[{"name":"quay.io-varnish-software"}]' ]
}

@test "${kind}: can enable serviceAccount" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'serviceAccount.create=true' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.serviceAccountName' | tee -a /dev/stderr)
    [ "${actual}" == "release-name-varnish-cache" ]
}

@test "${kind}: use default serviceAccount when disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'serviceAccount.create=false' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.serviceAccountName' | tee -a /dev/stderr)
    [ "${actual}" == "default" ]
}

@test "${kind}: inherits securityContext from global" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.podSecurityContext.hello=world' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.podSecurityContext.fsGroup=999' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"fsGroup":999,"hello":"world"}' ]
}

@test "${kind}: inherits securityContext from global and server" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.securityContext.hello=world' \
        --set 'server.securityContext.runAsUser=1000' \
        --set 'server.securityContext.foo=bar' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"foo":"bar","hello":"world","runAsNonRoot":true,"runAsUser":1000}' ]
}

@test "${kind}: inherits securityContext from global and server with global as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "global.securityContext=${securityContext}" \
        --set 'server.securityContext.runAsUser=1000' \
        --set 'server.securityContext.foo=bar' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .securityContext' | tee -a /dev/stderr)

    [ "${actual}" == '{"foo":"bar","release-name":"release-name","release-namespace":"default","runAsUser":1000}' ]
}

@test "${kind}: inherits securityContext from global and server with server as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.securityContext.hello=world' \
        --set "server.securityContext=${securityContext}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"hello":"world","release-name":"release-name","release-namespace":"default","runAsNonRoot":true,"runAsUser":999}' ]
}

@test "${kind}: inherits securityContext from global and server with both as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: to-be-override
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "global.securityContext=${securityContext}" \
        --set 'server.securityContext=release-namespace: {{ .Release.Namespace }}' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"release-name":"release-name","release-namespace":"default"}' ]
}

@test "${kind}: inherits labels from server" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.labels.hello=varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.labels.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "${kind}: inherits labels from server as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.labels=hello: {{ .Release.Name }}' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.labels.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "${kind}: inherits annotations from server" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.annotations.hello=varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "${kind}: inherits annotations from server as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.annotations=hello: {{ .Release.Name }}' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "${kind}: inherits podAnnotations from server" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.podAnnotations.hello=varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "${kind}: inherits podAnnotations from server as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.podAnnotations=hello: {{ .Release.Name }}' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "${kind}: inherits podLabels from global and server" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.podLabels.foo=bar' \
        --set 'server.podLabels.hello=varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-cache","foo":"bar","hello":"varnish"}' ]
}

@test "${kind}: inherits podLabels from global and server with global as templated string" {
    cd "$(chart_dir)"

    local labels="
release-name: {{ .Release.Name }}
release-namespace: to-be-override
"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "global.podLabels=${labels}" \
        --set 'server.podLabels.release-namespace=varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-cache","release-name":"release-name","release-namespace":"varnish"}' ]
}

@test "${kind}: inherits podLabels from global and server with server as templated string" {
    cd "$(chart_dir)"

    local labels="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.podLabels.release-namespace=to-be-override' \
        --set "server.podLabels=${labels}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-cache","release-name":"release-name","release-namespace":"default"}' ]
}

@test "${kind}: inherits default selector labels" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    # .metadata.labels

    local actual=$(echo "$object" |
        yq -r -c '.metadata.labels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish-cache" ]

    local actual=$(echo "$object" |
        yq -r -c '.metadata.labels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]

    local actual=$(echo "$object" |
        yq -r -c '.metadata.labels."app.kubernetes.io/version"' |
            tee -a /dev/stderr)
    [ "${actual}" != "" ]

    local actual=$(echo "$object" |
        yq -r -c '.metadata.labels."app.kubernetes.io/managed-by"' |
            tee -a /dev/stderr)
    [ "${actual}" == "Helm" ]

    # .spec.selector.matchLabels

    local actual=$(echo "$object" |
        yq -r -c '.spec.selector.matchLabels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish-cache" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.selector.matchLabels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]

    # .spec.template.metadata.labels

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish-cache" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "${kind}/http: can be enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.http.enabled=true' \
        --set 'server.http.port=8090' \
        --set 'server.startupProbe.initialDelaySeconds=5' \
        --set 'server.readinessProbe.initialDelaySeconds=5' \
        --set 'server.livenessProbe.initialDelaySeconds=5' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.ports[]? | select(.name == "http")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"http","containerPort":8090,"protocol":"TCP"}' ]

    local actual=$(echo "$container" |
        yq -r -c '.startupProbe.tcpSocket.port' |
            tee -a /dev/stderr)
    [ "${actual}" == "8090" ]

    local actual=$(echo "$container" |
        yq -r -c '.readinessProbe.tcpSocket.port' |
            tee -a /dev/stderr)
    [ "${actual}" == "8090" ]

    local actual=$(echo "$container" |
        yq -r -c '.livenessProbe.tcpSocket.port' |
            tee -a /dev/stderr)
    [ "${actual}" == "8090" ]

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-a") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-a","http=$(VARNISH_HTTP_ADDRESS):8090,HTTP"]' ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_HTTP_ADDRESS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"fieldRef":{"fieldPath":"status.podIP"}}' ]
}

@test "${kind}/http: can be disabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.http.enabled=false' \
        --set 'server.startupProbe=' \
        --set 'server.readinessProbe=' \
        --set 'server.livenessProbe=' \
        --set 'server.service.http.enabled=false' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.ports[]? | select(.name == "http")' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]

    local actual=$(echo "$container" | yq -r -c '.startupProbe' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]

    local actual=$(echo "$container" | yq -r -c '.readinessProbe' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]

    local actual=$(echo "$container" | yq -r -c '.livenessProbe' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-a")' |
            tee -a /dev/stderr)
    [ "${actual}" == "null" ]
}

@test "${kind}/http: cannot be disabled without disabling startupProbe" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.http.enabled=false' \
        --set 'server.startupProbe.initialDelaySeconds=' \
        --set 'server.readinessProbe=' \
        --set 'server.livenessProbe=' \
        --set 'server.service.http.enabled=false' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"HTTP support must be enabled to enable startupProbe"* ]]
}

@test "${kind}/http: cannot be disabled without disabling readinessProbe" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.http.enabled=false' \
        --set 'server.livenessProbe=' \
        --set 'server.service.http.enabled=false' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"HTTP support must be enabled to enable readinessProbe"* ]]
}

@test "${kind}/http: cannot be disabled without disabling livenessProbe" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.http.enabled=false' \
        --set 'server.readinessProbe=' \
        --set 'server.service.http.enabled=false' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"HTTP support must be enabled to enable livenessProbe"* ]]
}

@test "${kind}/http: cannot be disabled without disabling http service" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.http.enabled=false' \
        --set 'server.readinessProbe=' \
        --set 'server.livenessProbe=' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"HTTP support must be enabled"* ]]
}

@test "${kind}/admin: enabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-T") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-T","127.0.0.1:6082"]' ]
}

@test "${kind}/admin: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.admin.address=0.0.0.0' \
        --set 'server.admin.port=9999' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-T") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-T","0.0.0.0:9999"]' ]
}

@test "${kind}/extraListens: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraListens[0].name=proxy' \
        --set 'server.extraListens[0].port=8088' \
        --set 'server.extraListens[0].proto=PROXY' \
        --set 'server.extraListens[1].name=proxy-sock' \
        --set 'server.extraListens[1].path=/tmp/varnish-proxy.sock' \
        --set 'server.extraListens[1].user=www' \
        --set 'server.extraListens[1].group=www' \
        --set 'server.extraListens[1].mode=0700' \
        --set 'server.extraListens[1].proto=PROXY' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .args | . as $cmd | indices("-a")[1:] | map(. as $i | $cmd[$i:$i+2]) | flatten' |
            tee -a /dev/stderr)

    [ "${actual}" == '["-a","proxy=:8088,PROXY","-a","proxy-sock=/tmp/varnish-proxy.sock,user=www,group=www,mode=0700,PROXY"]' ]
}

@test "${kind}/extraListens: port can be configured partially" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraListens[0].name=althttp' \
        --set 'server.extraListens[0].port=8888' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .args | . as $cmd | indices("-a")[1:] | map(. as $i | $cmd[$i:$i+2]) | flatten' |
            tee -a /dev/stderr)

    [ "${actual}" == '["-a","althttp=:8888"]' ]
}

@test "${kind}/extraListens: path can be configured partially" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraListens[0].name=althttp' \
        --set 'server.extraListens[0].path=/tmp/varnish.sock' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .args | . as $cmd | indices("-a")[1:] | map(. as $i | $cmd[$i:$i+2]) | flatten' |
            tee -a /dev/stderr)

    [ "${actual}" == '["-a","althttp=/tmp/varnish.sock"]' ]
}

@test "${kind}/extraListens: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .command | . as $cmd | indices("-a")[1]' |
            tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "${kind}/extraEnvs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraEnvs.FOO=bar' \
        --set 'server.extraEnvs.BAZ=bax' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "${kind}/extraEnvs: can be configured as a templated string" {
    cd "$(chart_dir)"

    local extraEnvs="
- name: RELEASE_NAME
  value: {{ .Release.Name }}
- name: RELEASE_NAMESPACE
  value: {{ .Release.Namespace }}"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.extraEnvs=${extraEnvs}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .env[]? | select(.name == "RELEASE_NAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAME","value":"release-name"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .env[]? | select(.name == "RELEASE_NAMESPACE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAMESPACE","value":"default"}' ]
}


@test "${kind}/extraEnvs: can be configured as a list" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraEnvs[0].name=FOO' \
        --set 'server.extraEnvs[0].value=bar' \
        --set 'server.extraEnvs[1].name=BAZ' \
        --set 'server.extraEnvs[1].value=bax' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "${kind}/extraEnvs: can be configured as a list of non-value literal" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraEnvs[0].name=FROM_CONFIGMAP' \
        --set 'server.extraEnvs[0].valueFrom.configMapKeyRef.name=my-configmap' \
        --set 'server.extraEnvs[0].valueFrom.configMapKeyRef.key=my-key' \
        --set 'server.extraEnvs[1].name=FROM_SECRET' \
        --set 'server.extraEnvs[1].valueFrom.secretKeyRef.name=my-secret' \
        --set 'server.extraEnvs[1].valueFrom.secretKeyRef.key=my-key' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .env[]? | select(.name == "FROM_CONFIGMAP")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_CONFIGMAP","valueFrom":{"configMapKeyRef":{"key":"my-key","name":"my-configmap"}}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .env[]? | select(.name == "FROM_SECRET")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_SECRET","valueFrom":{"secretKeyRef":{"key":"my-key","name":"my-secret"}}}' ]
}

@test "${kind}/settings: configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-t") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-t","120"]' ]

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("thread_pool_min=50") as $i | $cmd[$i]' |
            tee -a /dev/stderr)
    [ "${actual}" == "thread_pool_min=50" ]

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("thread_pool_max=1000") as $i | $cmd[$i]' |
            tee -a /dev/stderr)
    [ "${actual}" == "thread_pool_max=1000" ]

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("thread_pool_timeout=120") as $i | $cmd[$i]' |
            tee -a /dev/stderr)
    [ "${actual}" == "thread_pool_timeout=120" ]
}

@test "${kind}/settings: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.ttl=240' \
        --set 'server.minThreads=300' \
        --set 'server.maxThreads=5000' \
        --set 'server.threadTimeout=500' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-t") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-t","240"]' ]

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("thread_pool_min=300") as $i | $cmd[$i]' |
            tee -a /dev/stderr)
    [ "${actual}" == "thread_pool_min=300" ]

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("thread_pool_max=5000") as $i | $cmd[$i]' |
            tee -a /dev/stderr)
    [ "${actual}" == "thread_pool_max=5000" ]

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("thread_pool_timeout=500") as $i | $cmd[$i]' |
            tee -a /dev/stderr)
    [ "${actual}" == "thread_pool_timeout=500" ]
}

@test "${kind}/extraArgs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraArgs[0]=-p' \
        --set 'server.extraArgs[1]=feature=+http2' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .args | . as $cmd | indices("-p")[3] as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)

    [ "${actual}" == '["-p","feature=+http2"]' ]
}

@test "${kind}/extraArgs: can be configured as string" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraArgs=-d' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .args | . as $cmd | index("-d") as $i | $cmd[$i]' |
            tee -a /dev/stderr)

    [ "${actual}" == "-d" ]
}

@test "${kind}/extraArgs: can be configured with extraListens" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraArgs[0]=-p' \
        --set 'server.extraArgs[1]=feature=+http2' \
        --set 'server.extraListens[0].name=proxy' \
        --set 'server.extraListens[0].port=8088' \
        --set 'server.extraListens[0].proto=PROXY' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | indices("-a")[1] as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-a","proxy=:8088,PROXY"]' ]

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | indices("-p")[3] as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-p","feature=+http2"]' ]
}

@test "${kind}/extraArgs: can be configured as string with extraListens" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraArgs=-d' \
        --set 'server.extraListens[0].name=proxy' \
        --set 'server.extraListens[0].port=8088' \
        --set 'server.extraListens[0].proto=PROXY' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | indices("-a")[1] as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-a","proxy=:8088,PROXY"]' ]

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-d") as $i | $cmd[$i]' |
            tee -a /dev/stderr)
    [ "${actual}" == '-d' ]
}

@test "${kind}/extraArgs: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .args | . as $cmd | indices("-a") | length' |
            tee -a /dev/stderr)
    [ "${actual}" == "1" ]
}

@test "${kind}/extraContainers: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraContainers[0].name=varnish-hello' \
        --set 'server.extraContainers[0].image=alpine:latest' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-hello")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"image":"alpine:latest","name":"varnish-hello"}' ]
}

@test "${kind}/extraContainers: can be configured as templated string" {
    cd "$(chart_dir)"

    local extraContainers="
- name: {{ .Release.Name }}-hello
  image: alpine:latest"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.extraContainers=${extraContainers}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "release-name-hello")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"name":"release-name-hello","image":"alpine:latest"}' ]
}

@test "${kind}/extraVolumeMounts: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraVolumeMounts[0].name=varnish-data' \
        --set 'server.extraVolumeMounts[0].mountPath=/var/data' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .volumeMounts[]? | select(.name == "varnish-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"mountPath":"/var/data","name":"varnish-data"}' ]
}

@test "${kind}/extraVolumeMounts: can be configured as templated string" {
    cd "$(chart_dir)"

    local extraVolumeMounts="
- name: {{ .Release.Name }}-data
  mountPath: /var/data"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.extraVolumeMounts=${extraVolumeMounts}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .volumeMounts[]? | select(.name == "release-name-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"name":"release-name-data","mountPath":"/var/data"}' ]
}

@test "${kind}/extraVolumes: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraVolumes[0].name=varnish-data' \
        --set 'server.extraVolumes[0].hostPath.path=/data/varnish' \
        --set 'server.extraVolumes[0].hostPath.type=directory' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.volumes[]? | select(.name == "varnish-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"hostPath":{"path":"/data/varnish","type":"directory"},"name":"varnish-data"}' ]
}

@test "${kind}/extraVolumes: can be configured as templated string" {
    cd "$(chart_dir)"

    local extraVolumes="
- name: {{ .Release.Name }}-data
  hostPath:
    path: /data/varnish
    type: directory"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.extraVolumes=${extraVolumes}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.volumes[]? | select(.name == "release-name-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"name":"release-name-data","hostPath":{"path":"/data/varnish","type":"directory"}}' ]
}

@test "${kind}/secret: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.secret=hello-varnish" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-secret"' |
            tee -a /dev/stderr)
    [ "${actual}" = '4ad139339508eb77f3875735b8415516f14f388e228071faa1d2b080429cdd9b' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-secret")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-secret","secret":{"secretName":"release-name-varnish-cache-secret"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-S") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-S","/etc/varnish/secret"]' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-secret")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-secret","mountPath":"/etc/varnish/secret","subPath":"secret"}' ]
}

@test "${kind}/secret: can be configured with external secret" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.secret=" \
        --set "server.secretFrom.name=external-secret" \
        --set "server.secretFrom.key=varnish-password" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-secret"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-secret")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-secret","secret":{"secretName":"external-secret"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-S") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-S","/etc/varnish/secret"]' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-secret")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-secret","mountPath":"/etc/varnish/secret","subPath":"varnish-password"}' ]
}

@test "${kind}/secret: cannot be configured with both value and external secret" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.secret=super-secure-secret" \
        --set "server.secretFrom.name=external-secret" \
        --set "server.secretFrom.key=varnish-password" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"Either 'server.secret' or 'server.secretFrom' can be set"* ]]
}

@test "${kind}/secret: cannot be configured with external secret without name" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.secret=" \
        --set "server.secretFrom.key=varnish-password" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"'server.secretFrom' must contain a 'name' key"* ]]
}

@test "${kind}/secret: cannot be configured with external secret with name set to empty string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.secret=" \
        --set "server.secretFrom.name=" \
        --set "server.secretFrom.key=varnish-password" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"'server.secretFrom' must contain a 'name' key"* ]]
}

@test "${kind}/secret: cannot be configured with external secret without key" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.secret=" \
        --set "server.secretFrom.name=external-secret" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"'server.secretFrom' must contain a 'key' key"* ]]
}

@test "${kind}/secret: cannot be configured with external secret with key set to empty string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.secret=" \
        --set "server.secretFrom.name=external-secret" \
        --set "server.secretFrom.key=" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"'server.secretFrom' must contain a 'key' key"* ]]
}

@test "${kind}/secret: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-secret"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-secret")' |
            tee -a /dev/stderr)
    [ "${actual}" = '' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .command | . as $cmd | index("-S")' |
            tee -a /dev/stderr)
    [ "${actual}" == 'null' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-secret")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]
}

@test "${kind}/vcl: use the bundled vcl by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-vcl"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-f") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" = '["-f","/etc/varnish/default.vcl"]' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '' ]
}

@test "${kind}/vcl: can be configured" {
    cd "$(chart_dir)"

    local vclConfig='
vcl 4.1;

backend {{ .Release.Name }} {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local expectedVclConfig='
vcl 4.1

backend release-name {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.vclConfig=${vclConfig}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-vcl"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'e71c17a8bb11a3944b9029906deac70c7f3643ceec87cb1e8a304b7b8c92138d' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","configMap":{"name":"release-name-varnish-cache-vcl"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-f") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" = '["-f","/etc/varnish/default.vcl"]' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","mountPath":"/etc/varnish/default.vcl","subPath":"default.vcl"}' ]
}

@test "${kind}/vcl: can be configured via vclConfigs" {
    cd "$(chart_dir)"

    local vclConfig='
vcl 4.1;

backend {{ .Release.Name }} {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local expectedVclConfig='
vcl 4.1

backend release-name {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.vclConfig=" \
        --set 'server.vclConfigs.default\.vcl='"${vclConfig}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-vcl"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'e71c17a8bb11a3944b9029906deac70c7f3643ceec87cb1e8a304b7b8c92138d' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","configMap":{"name":"release-name-varnish-cache-vcl"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-f") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" = '["-f","/etc/varnish/default.vcl"]' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","mountPath":"/etc/varnish/default.vcl","subPath":"default.vcl"}' ]
}

@test "${kind}/vcl: can be configured via vclConfigs with extra vcls" {
    cd "$(chart_dir)"

    local vclConfig='
vcl 4.1;

backend {{ .Release.Name }} {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local extraVclConfig='
vcl 4.1;

default {{ .Release.Name }} {
  .host = "127.0.0.1";
  .port = "8000";
}'

    local expectedVclConfig='
vcl 4.1

backend release-name {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local expectedExtraVclConfig='
vcl 4.1

backend release-name {
  .host = "127.0.0.1";
  .port = "8000";
}'

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.vclConfig=${vclConfig}" \
        --set 'server.vclConfigs.main\.vcl='"${extraVclConfig}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-vcl"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'e71c17a8bb11a3944b9029906deac70c7f3643ceec87cb1e8a304b7b8c92138d' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-vcl-main-vcl"' |
            tee -a /dev/stderr)
    [ "${actual}" = '11060980fc16de8bee3d626bfa600a13ab5db83471fd93fe60e15437f2d568b5' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","configMap":{"name":"release-name-varnish-cache-vcl"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl-main-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl-main-vcl","configMap":{"name":"release-name-varnish-cache-vcl-main-vcl"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-f") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" = '["-f","/etc/varnish/default.vcl"]' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","mountPath":"/etc/varnish/default.vcl","subPath":"default.vcl"}' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl-main-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl-main-vcl","mountPath":"/etc/varnish/main.vcl","subPath":"main.vcl"}' ]
}

@test "${kind}/vcl: can be configured via vclConfigs with extra vcls with default.vcl" {
    cd "$(chart_dir)"

    local vclConfig='
vcl 4.1;

backend {{ .Release.Name }} {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local extraVclConfig='
vcl 4.1;

default {{ .Release.Name }} {
  .host = "127.0.0.1";
  .port = "8000";
}'

    local expectedVclConfig='
vcl 4.1

backend release-name {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local expectedExtraVclConfig='
vcl 4.1

backend release-name {
  .host = "127.0.0.1";
  .port = "8000";
}'

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.vclConfig=" \
        --set 'server.vclConfigs.default\.vcl='"${vclConfig}" \
        --set 'server.vclConfigs.main\.vcl='"${extraVclConfig}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-vcl"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'e71c17a8bb11a3944b9029906deac70c7f3643ceec87cb1e8a304b7b8c92138d' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-vcl-main-vcl"' |
            tee -a /dev/stderr)
    [ "${actual}" = '11060980fc16de8bee3d626bfa600a13ab5db83471fd93fe60e15437f2d568b5' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","configMap":{"name":"release-name-varnish-cache-vcl"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl-main-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl-main-vcl","configMap":{"name":"release-name-varnish-cache-vcl-main-vcl"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-f") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" = '["-f","/etc/varnish/default.vcl"]' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","mountPath":"/etc/varnish/default.vcl","subPath":"default.vcl"}' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl-main-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl-main-vcl","mountPath":"/etc/varnish/main.vcl","subPath":"main.vcl"}' ]
}

@test "${kind}/vcl: can be configured via vclConfigs with extra vcls with alternative names" {
    cd "$(chart_dir)"

    local vclConfig='
vcl 4.1;

backend {{ .Release.Name }} {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local extraVclConfig='
vcl 4.1;

default {{ .Release.Name }} {
  .host = "127.0.0.1";
  .port = "8000";
}'

    local expectedVclConfig='
vcl 4.1

backend release-name {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local expectedExtraVclConfig='
vcl 4.1

backend release-name {
  .host = "127.0.0.1";
  .port = "8000";
}'

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.vclConfig=" \
        --set 'server.vclConfigPath=/etc/varnish/varnish.vcl' \
        --set 'server.vclConfigs.varnish\.vcl='"${vclConfig}" \
        --set 'server.vclConfigs.main\.vcl='"${extraVclConfig}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-vcl"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'e71c17a8bb11a3944b9029906deac70c7f3643ceec87cb1e8a304b7b8c92138d' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-vcl-main-vcl"' |
            tee -a /dev/stderr)
    [ "${actual}" = '11060980fc16de8bee3d626bfa600a13ab5db83471fd93fe60e15437f2d568b5' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","configMap":{"name":"release-name-varnish-cache-vcl"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl-main-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl-main-vcl","configMap":{"name":"release-name-varnish-cache-vcl-main-vcl"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-f") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" = '["-f","/etc/varnish/varnish.vcl"]' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","mountPath":"/etc/varnish/varnish.vcl","subPath":"varnish.vcl"}' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl-main-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl-main-vcl","mountPath":"/etc/varnish/main.vcl","subPath":"main.vcl"}' ]
}

@test "${kind}/vcl: cannot be configured with both vclConfig and vclConfigs using default.vcl" {
    cd "$(chart_dir)"

    local vclConfig='
vcl 4.1;

backend {{ .Release.Name }} {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local expectedVclConfig='
vcl 4.1

backend release-name {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.vclConfig=${vclConfig}" \
        --set 'server.vclConfigs.default\.vcl='"${vclConfig}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"Cannot enable both 'server.vclConfigs.\"default.vcl\""* ]]
}

@test "${kind}/vcl: cannot be configured with both vclConfig and vclConfigs using alternative names" {
    cd "$(chart_dir)"

    local vclConfig='
vcl 4.1;

backend {{ .Release.Name }} {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local expectedVclConfig='
vcl 4.1

backend release-name {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.vclConfig=${vclConfig}" \
        --set "server.vclConfigPath=/etc/varnish/varnish.vcl" \
        --set 'server.vclConfigs.varnish\.vcl='"${vclConfig}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"Cannot enable both 'server.vclConfigs.\"varnish.vcl\""* ]]
}

@test "${kind}/vcl: can be relocated" {
    cd "$(chart_dir)"

    local vclConfig='
vcl 4.1;

backend default {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.vclConfig=${vclConfig}" \
        --set "server.vclConfigPath=/etc/varnish/varnish.vcl" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-f") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-f","/etc/varnish/varnish.vcl"]' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-vcl","mountPath":"/etc/varnish/varnish.vcl","subPath":"varnish.vcl"}' ]

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.vclConfig=${vclConfig}" \
        --set "server.vclConfigPath=/etc/varnish/varnish.vcl" \
        --namespace default \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.data' | tee -a /dev/stderr)
    [ "${actual}" == '{"varnish.vcl":"\nvcl 4.1;\n\nbackend default {\n  .host = \"127.0.0.1\";\n  .port = \"8080\";\n}\n"}' ]
}

@test "${kind}/vcl: can be relocated without vclConfig" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.vclConfigPath=/etc/varnish/varnish.vcl" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-f") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-f","/etc/varnish/varnish.vcl"]' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]
}

@test "${kind}/vcl: can be relocated with extraVolumeMounts" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.vclConfigPath=/etc/varnish/varnish.vcl" \
        --set "server.extraVolumes[0].name=varnish-vcl-tenant1" \
        --set "server.extraVolumes[0].configMap.name=varnish-vcl-tenant1" \
        --set "server.extraVolumeMounts[0].name=varnish-vcl-tenant1" \
        --set "server.extraVolumeMounts[0].mountPath=/etc/varnish/tenant1.vcl" \
        --set "server.extraVolumeMounts[0].subpath=tenant1.vcl" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "varnish-vcl-tenant1")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"configMap":{"name":"varnish-vcl-tenant1"},"name":"varnish-vcl-tenant1"}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '
            .args | . as $cmd | index("-f") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-f","/etc/varnish/varnish.vcl"]' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "varnish-vcl-tenant1")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"mountPath":"/etc/varnish/tenant1.vcl","name":"varnish-vcl-tenant1","subpath":"tenant1.vcl"}' ]
}

@test "${kind}/cmdfile: can be configured" {
    cd "$(chart_dir)"

    local cmdfileConfig='
vcl.load vcl_tenant1 /etc/varnish/tenant1.vcl
vcl.label label_tenant1 vcl_tenant1
vcl.load vcl_main /etc/varnish/main.vcl
vcl.use vcl_main
'

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.cmdfileConfig=${cmdfileConfig}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-cmdfile"' |
            tee -a /dev/stderr)
    [ "${actual}" = '624d35eb30614898dff2f0a0d0b877fb27f394debc7f8316605a9208ed5b1c6d' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-cmdfile")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-cmdfile","configMap":{"name":"release-name-varnish-cache-cmdfile"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.args | . as $cmd | index("-I") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-I","/etc/varnish/cmds.cli"]' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-cmdfile")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-cmdfile","mountPath":"/etc/varnish/cmds.cli","subPath":"cmds.cli"}' ]
}

@test "${kind}/cmdfile: can be relocated" {
    cd "$(chart_dir)"

    local cmdfileConfig='
vcl.load vcl_tenant1 /etc/varnish/tenant1.vcl
vcl.label label_tenant1 vcl_tenant1
vcl.load vcl_main /etc/varnish/main.vcl
vcl.use vcl_main
'

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.cmdfileConfig=${cmdfileConfig}" \
        --set "server.cmdfileConfigPath=/etc/varnish/cmdfile" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.args | . as $cmd | index("-I") as $i | $cmd[$i:$i+2]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-I","/etc/varnish/cmdfile"]' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-cmdfile")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-cmdfile","mountPath":"/etc/varnish/cmdfile","subPath":"cmds.cli"}' ]
}

@test "${kind}/image: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.image.repository=docker-repo.local/varnish-software/varnish-plus' \
        --set 'server.image.tag=latest' \
        --set 'server.image.pullPolicy=Always' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.image' |
            tee -a /dev/stderr)
    [ "${actual}" == "docker-repo.local/varnish-software/varnish-plus:latest" ]

    local actual=$(echo "$container" |
        yq -r -c '.imagePullPolicy' |
            tee -a /dev/stderr)
    [ "${actual}" == "Always" ]
}

@test "${kind}/startupProbe: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .startupProbe' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "${kind}/startupProbe: can be enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.startupProbe.initialDelaySeconds=10' \
        --set 'server.startupProbe.periodSeconds=20' \
        --set 'server.startupProbe.timeoutSeconds=2' \
        --set 'server.startupProbe.successThreshold=2' \
        --set 'server.startupProbe.failureThreshold=6' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .startupProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"tcpSocket":{"port":6081},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "${kind}/startupProbe: can be configured as httpGet" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.startupProbe.initialDelaySeconds=10' \
        --set 'server.startupProbe.periodSeconds=20' \
        --set 'server.startupProbe.timeoutSeconds=2' \
        --set 'server.startupProbe.successThreshold=2' \
        --set 'server.startupProbe.failureThreshold=6' \
        --set 'server.startupProbe.httpGet=' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .startupProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"httpGet":{"port":6081,"path":"/"},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "${kind}/startupProbe: can be configured as httpGet with extra parameters" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.startupProbe.initialDelaySeconds=10' \
        --set 'server.startupProbe.periodSeconds=20' \
        --set 'server.startupProbe.timeoutSeconds=2' \
        --set 'server.startupProbe.successThreshold=2' \
        --set 'server.startupProbe.failureThreshold=6' \
        --set 'server.startupProbe.httpGet.path=/healthz' \
        --set 'server.startupProbe.httpGet.httpHeaders[0].name=X-Health-Check' \
        --set 'server.startupProbe.httpGet.httpHeaders[0].value=1' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .startupProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"httpGet":{"port":6081,"httpHeaders":[{"name":"X-Health-Check","value":1}],"path":"/healthz"},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "${kind}/startupProbe: cannot override port in httpGet" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.startupProbe.initialDelaySeconds=10' \
        --set 'server.startupProbe.periodSeconds=20' \
        --set 'server.startupProbe.timeoutSeconds=2' \
        --set 'server.startupProbe.successThreshold=2' \
        --set 'server.startupProbe.failureThreshold=6' \
        --set 'server.startupProbe.httpGet.port=0' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .startupProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"httpGet":{"port":6081,"path":"/"},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "${kind}/readinessProbe: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.readinessProbe.initialDelaySeconds=10' \
        --set 'server.readinessProbe.periodSeconds=20' \
        --set 'server.readinessProbe.timeoutSeconds=2' \
        --set 'server.readinessProbe.successThreshold=2' \
        --set 'server.readinessProbe.failureThreshold=6' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .readinessProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"tcpSocket":{"port":6081},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "${kind}/readinessProbe: can be configured as httpGet" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.readinessProbe.initialDelaySeconds=10' \
        --set 'server.readinessProbe.periodSeconds=20' \
        --set 'server.readinessProbe.timeoutSeconds=2' \
        --set 'server.readinessProbe.successThreshold=2' \
        --set 'server.readinessProbe.failureThreshold=6' \
        --set 'server.readinessProbe.httpGet=' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .readinessProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"httpGet":{"port":6081,"path":"/"},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "${kind}/readinessProbe: can be configured as httpGet with extra parameters" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.readinessProbe.initialDelaySeconds=10' \
        --set 'server.readinessProbe.periodSeconds=20' \
        --set 'server.readinessProbe.timeoutSeconds=2' \
        --set 'server.readinessProbe.successThreshold=2' \
        --set 'server.readinessProbe.failureThreshold=6' \
        --set 'server.readinessProbe.httpGet.path=/healthz' \
        --set 'server.readinessProbe.httpGet.httpHeaders[0].name=X-Health-Check' \
        --set 'server.readinessProbe.httpGet.httpHeaders[0].value=1' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .readinessProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"httpGet":{"port":6081,"httpHeaders":[{"name":"X-Health-Check","value":1}],"path":"/healthz"},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "${kind}/readinessProbe: cannot override port in httpGet" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.readinessProbe.initialDelaySeconds=10' \
        --set 'server.readinessProbe.periodSeconds=20' \
        --set 'server.readinessProbe.timeoutSeconds=2' \
        --set 'server.readinessProbe.successThreshold=2' \
        --set 'server.readinessProbe.failureThreshold=6' \
        --set 'server.readinessProbe.httpGet.port=0' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .readinessProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"httpGet":{"port":6081,"path":"/"},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "${kind}/readinessProbe: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.readinessProbe=' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .readinessProbe' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "${kind}/livenessProbe: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.livenessProbe.initialDelaySeconds=10' \
        --set 'server.livenessProbe.periodSeconds=20' \
        --set 'server.livenessProbe.timeoutSeconds=2' \
        --set 'server.livenessProbe.successThreshold=2' \
        --set 'server.livenessProbe.failureThreshold=6' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .livenessProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"tcpSocket":{"port":6081},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "${kind}/livenessProbe: can be configured as httpGet" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.livenessProbe.initialDelaySeconds=10' \
        --set 'server.livenessProbe.periodSeconds=20' \
        --set 'server.livenessProbe.timeoutSeconds=2' \
        --set 'server.livenessProbe.successThreshold=2' \
        --set 'server.livenessProbe.failureThreshold=6' \
        --set 'server.livenessProbe.httpGet=' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .livenessProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"httpGet":{"port":6081,"path":"/"},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "${kind}/livenessProbe: can be configured as httpGet with extra parameters" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.livenessProbe.initialDelaySeconds=10' \
        --set 'server.livenessProbe.periodSeconds=20' \
        --set 'server.livenessProbe.timeoutSeconds=2' \
        --set 'server.livenessProbe.successThreshold=2' \
        --set 'server.livenessProbe.failureThreshold=6' \
        --set 'server.livenessProbe.httpGet.path=/healthz' \
        --set 'server.livenessProbe.httpGet.httpHeaders[0].name=X-Health-Check' \
        --set 'server.livenessProbe.httpGet.httpHeaders[0].value=1' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .livenessProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"httpGet":{"port":6081,"httpHeaders":[{"name":"X-Health-Check","value":1}],"path":"/healthz"},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "${kind}/livenessProbe: cannot override port in httpGet" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.livenessProbe.initialDelaySeconds=10' \
        --set 'server.livenessProbe.periodSeconds=20' \
        --set 'server.livenessProbe.timeoutSeconds=2' \
        --set 'server.livenessProbe.successThreshold=2' \
        --set 'server.livenessProbe.failureThreshold=6' \
        --set 'server.livenessProbe.httpGet.port=0' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .livenessProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"httpGet":{"port":6081,"path":"/"},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "${kind}/livenessProbe: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.livenessProbe=' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .livenessProbe' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "${kind}/resources: inherits resources from global and server" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.resources.limits.cpu=100m' \
        --set 'global.resources.requests.cpu=100m' \
        --set 'server.resources.limits.cpu=500m' \
        --set 'server.resources.limits.memory=512Mi' \
        --set 'server.resources.requests.memory=128Mi' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/resources: inherits resources from global and server with global as a templated string" {
    cd "$(chart_dir)"

    local resources="
limits:
  cpu: 500m
  memory: 512Mi
requests:
  memory: 128Mi
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.resources.limits.cpu=100m' \
        --set 'global.resources.requests.cpu=100m' \
        --set "server.resources=${resources}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/resources: inherits resources from global and server with server as a templated string" {
    cd "$(chart_dir)"

    local resources="
limits:
  cpu: 100m
requests:
  cpu: 100m
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "global.resources=${resources}" \
        --set 'server.resources.limits.cpu=500m' \
        --set 'server.resources.limits.memory=512Mi' \
        --set 'server.resources.requests.memory=128Mi' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/resources: inherits resources from global and server with both as a templated string" {
    cd "$(chart_dir)"

    local globalResources="
limits:
  cpu: 100m
requests:
  cpu: 100m
"

    local resources="
limits:
  cpu: 500m
  memory: 512Mi
requests:
  memory: 128Mi
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "global.resources=${globalResources}" \
        --set "server.resources=${resources}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/resources: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "${kind}/nodeSelector: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.nodeSelector.tier=edge' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == '{"tier":"edge"}' ]
}

@test "${kind}/nodeSelector: can be as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.nodeSelector=tier: {{ .Release.Name }}-edge' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == '{"tier":"release-name-edge"}' ]
}

@test "${kind}/nodeSelector: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "${kind}/tolerations: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.tolerations[0].key=far-network-disk' \
        --set 'server.tolerations[0].operator=Exists' \
        --set 'server.tolerations[0].effect=NoSchedule' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == '[{"effect":"NoSchedule","key":"far-network-disk","operator":"Exists"}]' ]
}

@test "${kind}/tolerations: can be configured as templated string" {
    cd "$(chart_dir)"

    local tolerations='
- key: ban-{{ .Release.Name }}
  operator: Exists
  effect: NoSchedule
'

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.tolerations=${tolerations}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == '[{"key":"ban-release-name","operator":"Exists","effect":"NoSchedule"}]' ]
}

@test "${kind}/tolerations: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "${kind}/affinity: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchLabels.foo=bar' \
        --set 'server.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey=kubernetes.io/hostname' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.affinity' | tee -a /dev/stderr)

    [ "${actual}" == '{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"foo":"bar"}},"topologyKey":"kubernetes.io/hostname"}]}}' ]
}

@test "${kind}/affinity: can be configured as templated string" {
    cd "$(chart_dir)"

    local affinity='
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels:
          app.kubernetes.io/name: {{ include "varnish-cache.name" . }}
          app.kubernetes.io/instance: {{ .Release.Name }}
      topologyKey: kubernetes.io/hostname
'

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.affinity=${affinity}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.affinity' | tee -a /dev/stderr)

    [ "${actual}" == '{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"app.kubernetes.io/name":"varnish-cache","app.kubernetes.io/instance":"release-name"}},"topologyKey":"kubernetes.io/hostname"}]}}' ]
}

@test "${kind}/delayedHaltSeconds: not enabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | yq -r -c '.lifecycle' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]
}

@test "${kind}/delayedHaltSeconds: can be enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.delayedHaltSeconds=120" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | yq -r -c '.lifecycle' | tee -a /dev/stderr)
    [ "${actual}" == '{"preStop":{"exec":{"command":["/bin/sleep","120"]}}}' ]
}

@test "${kind}/delayedHaltSeconds: takes priority over delayedShutdown" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.delayedHaltSeconds=120" \
        --set "server.delayedShutdown.method=sleep" \
        --set "server.delayedShutdown.sleep.seconds=90" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | yq -r -c '.lifecycle' | tee -a /dev/stderr)
    [ "${actual}" == '{"preStop":{"exec":{"command":["/bin/sleep","120"]}}}' ]
}

@test "${kind}/delayedShutdown: not enabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | yq -r -c '.lifecycle' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]
}

@test "${kind}/delayedShutdown: can be enabled with sleep" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.delayedShutdown.method=sleep" \
        --set "server.delayedShutdown.sleep.seconds=120" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | yq -r -c '.lifecycle' | tee -a /dev/stderr)
    [ "${actual}" == '{"preStop":{"exec":{"command":["/bin/sleep","120"]}}}' ]
}

@test "${kind}/delayedShutdown: can be enabled with mempool" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.delayedShutdown.method=mempool" \
        --set "server.delayedShutdown.mempool.pollSeconds=5" \
        --set "server.delayedShutdown.mempool.waitSeconds=30" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | yq -r -c '.lifecycle' | tee -a /dev/stderr)
    [[ "${actual}" == *"MEMPOOL.sess"* ]]
    [[ "${actual}" == *"sleep 5"* ]]
    [[ "${actual}" == *"sleep 30"* ]]
}

@test "${kind}/terminationGracePeriodSeconds: not enabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.terminationGracePeriodSeconds' |
            tee -a /dev/stderr)
    [ "${actual}" == "null" ]
}

@test "${kind}/terminationGracePeriodSeconds: can be enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.terminationGracePeriodSeconds=120" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.terminationGracePeriodSeconds' |
            tee -a /dev/stderr)
    [ "${actual}" == "120" ]
}

@test "${kind}/terminationGracePeriodSeconds: can be enabled with delayedHaltSeconds" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.delayedHaltSeconds=60" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.terminationGracePeriodSeconds' |
            tee -a /dev/stderr)
    [ "${actual}" == "120" ]
}

@test "${kind}/terminationGracePeriodSeconds: can be overriden by grace period seconds" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.terminationGracePeriodSeconds=180" \
        --set "server.delayedHaltSeconds=60" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.terminationGracePeriodSeconds' |
            tee -a /dev/stderr)
    [ "${actual}" == "180" ]
}

@test "${kind}/terminationGracePeriodSeconds: do nothing with delayedShutdown sleep seconds" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.terminationGracePeriodSeconds=180" \
        --set "server.delayedShutdown.method=sleep" \
        --set "server.delayedShutdown.sleep.seconds=60" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.terminationGracePeriodSeconds' |
            tee -a /dev/stderr)
    [ "${actual}" == "180" ]
}

@test "${kind}/terminationGracePeriodSeconds: do nothing with delayedShutdown mempool seconds" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.terminationGracePeriodSeconds=180" \
        --set "server.delayedShutdown.method=mempool" \
        --set "server.delayedShutdown.mempool.pollSeconds=1" \
        --set "server.delayedShutdown.mempool.waitSeconds=5" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.terminationGracePeriodSeconds' |
            tee -a /dev/stderr)
    [ "${actual}" == "180" ]
}

@test "${kind}/varnishncsa: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.varnishncsa.enabled=false" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa")' |
            tee -a /dev/stderr)

    [ "${actual}" == "" ]
}

@test "${kind}/varnishncsa: inherits securityContext from global and varnishncsa" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.securityContext.hello=world' \
        --set 'server.securityContext.ignore-this=yes' \
        --set 'server.varnishncsa.securityContext.runAsUser=1001' \
        --set 'server.varnishncsa.securityContext.foo=baz' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"foo":"baz","hello":"world","runAsNonRoot":true,"runAsUser":1001}' ]
}

@test "${kind}/varnishncsa: inherits securityContext from global and varnishncsa with global as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set "global.securityContext=${securityContext}" \
        --set 'server.securityContext.ignore-this=yes' \
        --set 'server.varnishncsa.securityContext.runAsUser=1001' \
        --set 'server.varnishncsa.securityContext.foo=baz' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .securityContext' | tee -a /dev/stderr)

    [ "${actual}" == '{"foo":"baz","release-name":"release-name","release-namespace":"default","runAsUser":1001}' ]
}

@test "${kind}/varnishncsa: inherits securityContext from global and varnishncsa with varnishncsa as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'global.securityContext.hello=world' \
        --set 'server.securityContext.ignore-this=yes' \
        --set "server.varnishncsa.securityContext=${securityContext}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"hello":"world","release-name":"release-name","release-namespace":"default","runAsNonRoot":true,"runAsUser":999}' ]
}

@test "${kind}/varnishncsa: inherits securityContext from global and varnishncsa with both as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: to-be-override
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set "global.securityContext=${securityContext}" \
        --set 'server.securityContext.ignore-this=yes' \
        --set 'server.varnishncsa.securityContext=release-namespace: {{ .Release.Namespace }}' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"release-name":"release-name","release-namespace":"default"}' ]
}

@test "${kind}/varnishncsa/extraArgs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.extraArgs[0]=--help' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .args' |
            tee -a /dev/stderr)

    [ "${actual}" == '["--help"]' ]
}

@test "${kind}/varnishncsa/extraArgs: can be configured as string" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.extraArgs=--help' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .args' |
            tee -a /dev/stderr)

    [ "${actual}" == '--help' ]
}

@test "${kind}/varnishncsa/image: inherit from varnish-cache by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.image.repository=localhost/varnish-cache" \
        --set "server.image.tag=latest" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .image' |
            tee -a /dev/stderr)

    [ "${actual}" == "localhost/varnish-cache:latest" ]
}

@test "${kind}/varnishncsa/image: can be overridden" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.image.repository=localhost/varnish-cache" \
        --set "server.image.tag=latest" \
        --set "server.varnishncsa.image.repository=localhost/varnish-cache-ncsa" \
        --set "server.varnishncsa.image.tag=ncsa-latest" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .image' |
            tee -a /dev/stderr)

    [ "${actual}" == "localhost/varnish-cache-ncsa:ncsa-latest" ]
}

@test "${kind}/varnishncsa/startupProbe: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .startupProbe' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "${kind}/varnishncsa/startupProbe: can be enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.startupProbe.initialDelaySeconds=10' \
        --set 'server.varnishncsa.startupProbe.periodSeconds=20' \
        --set 'server.varnishncsa.startupProbe.timeoutSeconds=2' \
        --set 'server.varnishncsa.startupProbe.successThreshold=2' \
        --set 'server.varnishncsa.startupProbe.failureThreshold=6' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .startupProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"exec":{"command":["/usr/bin/varnishncsa","-d","-t 3"]},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "${kind}/varnishncsa/readinessProbe: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.readinessProbe.initialDelaySeconds=10' \
        --set 'server.varnishncsa.readinessProbe.periodSeconds=20' \
        --set 'server.varnishncsa.readinessProbe.timeoutSeconds=2' \
        --set 'server.varnishncsa.readinessProbe.successThreshold=2' \
        --set 'server.varnishncsa.readinessProbe.failureThreshold=6' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .readinessProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"exec":{"command":["/usr/bin/varnishncsa","-d","-t 3"]},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "${kind}/varnishncsa/readinessProbe: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.readinessProbe=' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .readinessProbe' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "${kind}/varnishncsa/livenessProbe: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.livenessProbe.initialDelaySeconds=10' \
        --set 'server.varnishncsa.livenessProbe.periodSeconds=20' \
        --set 'server.varnishncsa.livenessProbe.timeoutSeconds=2' \
        --set 'server.varnishncsa.livenessProbe.successThreshold=2' \
        --set 'server.varnishncsa.livenessProbe.failureThreshold=6' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .livenessProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"exec":{"command":["/usr/bin/varnishncsa","-d","-t 3"]},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "${kind}/varnishncsa/livenessProbe: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.livenessProbe=' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .livenessProbe' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "${kind}/varnishncsa/resources: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.resources.limits.cpu=500m' \
        --set 'server.varnishncsa.resources.limits.memory=512Mi' \
        --set 'server.varnishncsa.resources.requests.cpu=100m' \
        --set 'server.varnishncsa.resources.requests.memory=128Mi' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/varnishncsa/resources: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "${kind}/varnishncsa/extraVolumeMounts: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.extraVolumeMounts[0].name=varnish-data' \
        --set 'server.varnishncsa.extraVolumeMounts[0].mountPath=/var/data' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .volumeMounts[]? | select(.name == "varnish-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"mountPath":"/var/data","name":"varnish-data"}' ]
}

@test "${kind}/varnishncsa/extraVolumeMounts: can be configured as templated string" {
    cd "$(chart_dir)"

    local extraVolumeMounts="
- name: {{ .Release.Name }}-data
  mountPath: /var/data"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.varnishncsa.extraVolumeMounts=${extraVolumeMounts}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-cache-ncsa") |
            .volumeMounts[]? | select(.name == "release-name-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"name":"release-name-data","mountPath":"/var/data"}' ]
}

@test "${kind}/extraManifests: do nothing with templated string without checksum flag" {
    cd "$(chart_dir)"

    cat <<EOF > "$BATS_RUN_TMPDIR"/values-"$BATS_TEST_NUMBER".yaml
extraManifests:
  - name: clusterrole
    data: |
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: {{ .Release.Name }}-clusterrole
      rules:
        - apiGroups: [""]
          resources: ["endpoints"]
          verbs: ["get", "list", "watch"]
  - name: clusterrolebinding
    data: |
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: {{ .Release.Name }}-clusterrolebinding
      roleRef:
        kind: ClusterRole
        name: {{ .Release.Name }}-clusterrole
        apiGroup: rbac.authorization.k8s.io
      subjects:
        - kind: ServiceAccount
          name: {{ .Release.Name }}
          namespace: {{ .Release.Namespace }}
EOF

    local object=$((helm template \
        -f "$BATS_RUN_TMPDIR"/values-"$BATS_TEST_NUMBER".yaml \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrole"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrolebinding"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]
}

@test "${kind}/extraManifests: can be configured with checksum with templated string" {
    cd "$(chart_dir)"

    cat <<EOF > "$BATS_RUN_TMPDIR"/values-"$BATS_TEST_NUMBER".yaml
extraManifests:
  - name: clusterrole
    checksum: true
    data: |
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: {{ .Release.Name }}-clusterrole
      rules:
        - apiGroups: [""]
          resources: ["endpoints"]
          verbs: ["get", "list", "watch"]
  - name: clusterrolebinding
    checksum: true
    data: |
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: {{ .Release.Name }}-clusterrolebinding
      roleRef:
        kind: ClusterRole
        name: {{ .Release.Name }}-clusterrole
        apiGroup: rbac.authorization.k8s.io
      subjects:
        - kind: ServiceAccount
          name: {{ .Release.Name }}
          namespace: {{ .Release.Namespace }}
EOF

    local object=$((helm template \
        -f "$BATS_RUN_TMPDIR"/values-"$BATS_TEST_NUMBER".yaml \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrole"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'b341e3a03d6bb568e16c2ccbfdc281924ad1a771b73fd2c4198a54a6ce568ebe' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrolebinding"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'ba049cef23c6407b1c3866a543d8b6cb6b52e01cc40b18774021761b3560424e' ]
}

@test "${kind}/extraManifests: do nothing with yaml object without checksum flag" {
    cd "$(chart_dir)"

    cat <<EOF > "$BATS_RUN_TMPDIR"/values-"$BATS_TEST_NUMBER".yaml
extraManifests:
  - name: clusterrole
    data:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: varnish-cache-clusterrole
      rules:
        - apiGroups: [""]
          resources: ["endpoints"]
          verbs: ["get", "list", "watch"]
  - name: clusterrolebinding
    data:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: varnish-cache-clusterrolebinding
      roleRef:
        kind: ClusterRole
        name: varnish-cache-clusterrole
        apiGroup: rbac.authorization.k8s.io
      subjects:
        - kind: ServiceAccount
          name: varnish-cache
          namespace: default
EOF

    local object=$((helm template \
        -f "$BATS_RUN_TMPDIR"/values-"$BATS_TEST_NUMBER".yaml \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrole"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrolebinding"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]
}

@test "${kind}/extraManifests: can be configured with checksum with yaml object" {
    cd "$(chart_dir)"

    cat <<EOF > "$BATS_RUN_TMPDIR"/values-"$BATS_TEST_NUMBER".yaml
extraManifests:
  - name: clusterrole
    checksum: true
    data:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: varnish-cache-clusterrole
      rules:
        - apiGroups: [""]
          resources: ["endpoints"]
          verbs: ["get", "list", "watch"]
  - name: clusterrolebinding
    checksum: true
    data:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: varnish-cache-clusterrolebinding
      roleRef:
        kind: ClusterRole
        name: varnish-cache-clusterrole
        apiGroup: rbac.authorization.k8s.io
      subjects:
        - kind: ServiceAccount
          name: varnish-cache
          namespace: default
EOF

    local object=$((helm template \
        -f "$BATS_RUN_TMPDIR"/values-"$BATS_TEST_NUMBER".yaml \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrole"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'b1d1b7f802f0736a0666b0947539726b6fec6e737307cfc44ab1880c8e62eb62' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrolebinding"' |
            tee -a /dev/stderr)
    [ "${actual}" = '7823f0c2674876bd60bca3d758cb320a0ea13090ec80d5aead53cd9ce0e1a53f' ]
}

@test "${kind}/command: default has /usr/sbin/varnishd command with expected args" {
    cd "$(chart_dir)"
    
    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)
        
    local command=$(echo "$object" |
        yq -r -c '.spec.template.spec.containers[] | select(.name == "varnish-cache") | .command' |
            tee -a /dev/stderr)
    [ "${command}" = '["/usr/sbin/varnishd"]' ]
    
    local args=$(echo "$object" |
        yq -r '.spec.template.spec.containers[] | select(.name == "varnish-cache") | .args' |
            tee -a /dev/stderr)
    [[ "${args}" == *"-F"* ]]
    [[ "${args}" == *"http=\$(VARNISH_HTTP_ADDRESS):6081,HTTP"* ]]
    [[ "${args}" == *"-f"* ]]
    [[ "${args}" == *"/etc/varnish/default.vcl"* ]]
}

@test "${kind}/command: can override command without affecting args" {
    cd "$(chart_dir)"
    
    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.command[0]=/custom/path/varnishd' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)
        
    local command=$(echo "$object" |
        yq -r -c '.spec.template.spec.containers[] | select(.name == "varnish-cache") | .command' |
            tee -a /dev/stderr)
    [ "${command}" = '["/custom/path/varnishd"]' ]
    
    local args=$(echo "$object" |
        yq -r '.spec.template.spec.containers[] | select(.name == "varnish-cache") | .args' |
            tee -a /dev/stderr)
    [[ "${args}" == *"-F"* ]]
    [[ "${args}" == *"http=\$(VARNISH_HTTP_ADDRESS):6081,HTTP"* ]]
    [[ "${args}" == *"-f"* ]]
    [[ "${args}" == *"/etc/varnish/default.vcl"* ]]
}

@test "${kind}/command: can override args without affecting command" {
    cd "$(chart_dir)"
    
    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.args[0]=-F' \
        --set 'server.args[1]=-f' \
        --set 'server.args[2]=/custom/path/default.vcl' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)
        
    local command=$(echo "$object" |
        yq -r -c '.spec.template.spec.containers[] | select(.name == "varnish-cache") | .command' |
            tee -a /dev/stderr)
    [ "${command}" = '["/usr/sbin/varnishd"]' ]
    
    local args=$(echo "$object" |
        yq -r -c '.spec.template.spec.containers[] | select(.name == "varnish-cache") | .args' |
            tee -a /dev/stderr)
    [ "${args}" = '["-F","-f","/custom/path/default.vcl"]' ]
}

@test "${kind}/command: can override both command and args" {
    cd "$(chart_dir)"
    
    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.command[0]=/custom/path/varnishd' \
        --set 'server.args[0]=-d' \
        --set 'server.args[1]=-f' \
        --set 'server.args[2]=/custom/path/default.vcl' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)
        
    local command=$(echo "$object" |
        yq -r -c '.spec.template.spec.containers[] | select(.name == "varnish-cache") | .command' |
            tee -a /dev/stderr)
    [ "${command}" = '["/custom/path/varnishd"]' ]
    
    local args=$(echo "$object" |
        yq -r -c '.spec.template.spec.containers[] | select(.name == "varnish-cache") | .args' |
            tee -a /dev/stderr)
    [ "${args}" = '["-d","-f","/custom/path/default.vcl"]' ]
}

@test "${kind}/command: empty args array is respected" {
    cd "$(chart_dir)"
    
    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.args=[]' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)
    
    local args=$(echo "$object" |
        yq -r -c '.spec.template.spec.containers[] | select(.name == "varnish-cache") | .args' |
            tee -a /dev/stderr)
    [ "${args}" = '[]' ]
}
