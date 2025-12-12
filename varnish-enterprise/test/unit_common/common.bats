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
    [ "${actual}" == "release-name-varnish-enterprise" ]
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-enterprise","foo":"bar","hello":"varnish"}' ]
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

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-enterprise","release-name":"release-name","release-namespace":"varnish"}' ]
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

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-enterprise","release-name":"release-name","release-namespace":"default"}' ]
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
    [ "${actual}" == "varnish-enterprise" ]

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
    [ "${actual}" == "varnish-enterprise" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.selector.matchLabels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]

    # .spec.template.metadata.labels

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish-enterprise" ]

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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
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
        yq -r -c '.env[]? | select(.name == "VARNISH_LISTEN_ADDRESS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"fieldRef":{"fieldPath":"status.podIP"}}' ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_LISTEN_PORT") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "8090" ]
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
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
        yq -r -c '.env[]? | select(.name == "VARNISH_LISTEN_PORT")' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]
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

@test "${kind}/tls: can be enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.tls.enabled=true' \
        --set 'server.tls.port=8443' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-tls"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-tls")' |
            tee -a /dev/stderr)
    [ "${actual}" = '' ]

    local actual=$(echo "$container" |
        yq -r -c '.ports[]? | select(.name == "https")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"https","containerPort":8443,"protocol":"TCP"}' ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_TLS_CFG") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "true" ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-tls")' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]
}

@test "${kind}/tls: can be enabled with custom config" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.tls.enabled=true' \
        --set 'server.tls.config=test' \
        --set 'server.tls.port=8443' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-tls"' |
            tee -a /dev/stderr)
    [ "${actual}" = '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-tls")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-tls","configMap":{"name":"release-name-varnish-enterprise-tls"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_TLS_CFG") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "/etc/varnish/tls.conf" ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-tls")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-tls","mountPath":"/etc/varnish/tls.conf","subPath":"tls.conf"}' ]
}

@test "${kind}/tls: not enabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-tls"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.ports[]? | select(.name == "https")' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_TLS_CFG")' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_ADMIN_LISTEN_ADDRESS") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "127.0.0.1" ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_ADMIN_LISTEN_PORT") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "6082" ]
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_ADMIN_LISTEN_ADDRESS") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "0.0.0.0" ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_ADMIN_LISTEN_PORT") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "9999" ]
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "-a proxy=:8088,PROXY -a proxy-sock=/tmp/varnish-proxy.sock,user=www,group=www,mode=0700,PROXY" ]
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "-a althttp=:8888" ]
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "-a althttp=/tmp/varnish.sock" ]
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "" ]
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "RELEASE_NAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAME","value":"release-name"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "${kind}/extraEnvs: can be configured as a list of non-value literalFrom" {
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "FROM_CONFIGMAP")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_CONFIGMAP","valueFrom":{"configMapKeyRef":{"key":"my-key","name":"my-configmap"}}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_TTL") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "120" ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_MIN_THREADS") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "50" ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_MAX_THREADS") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "1000" ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_THREAD_TIMEOUT") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "120" ]
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_TTL") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "240" ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_MIN_THREADS") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "300" ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_MAX_THREADS") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "5000" ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_THREAD_TIMEOUT") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "500" ]
}

@test "${kind}/extraArgs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraArgs[0]=-p feature=+http2' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "-p feature=+http2" ]
}

@test "${kind}/extraArgs: can be configured as string" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraArgs=-p feature=+http2' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "-p feature=+http2" ]
}

@test "${kind}/extraArgs: can be configured with extraListens" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraArgs[0]=-p feature=+http2' \
        --set 'server.extraListens[0].name=proxy' \
        --set 'server.extraListens[0].port=8088' \
        --set 'server.extraListens[0].proto=PROXY' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "-p feature=+http2 -a proxy=:8088,PROXY" ]
}

@test "${kind}/extraArgs: can be configured as string with extraListens" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraArgs=-p feature=+http2' \
        --set 'server.extraListens[0].name=proxy' \
        --set 'server.extraListens[0].port=8088' \
        --set 'server.extraListens[0].proto=PROXY' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "-p feature=+http2 -a proxy=:8088,PROXY" ]
}

@test "${kind}/parameters: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "" ]
}

@test "${kind}/parameters: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.parameters.backendIdleTimeout=60" \
        --set "server.parameters.feature[0]=+http2" \
        --set "server.parameters.feature[1]=+validate_headers" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "-p backend_idle_timeout=60 -p feature=+http2,+validate_headers" ]
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "" ]
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
    [ "${actual}" = '{"name":"release-name-config-secret","secret":{"secretName":"release-name-varnish-enterprise-secret"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_SECRET_FILE") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "/etc/varnish/secret" ]

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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_SECRET_FILE") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "/etc/varnish/secret" ]

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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_SECRET_FILE") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

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
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","emptyDir":{"medium":"Memory"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_VCL_CONF") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" = '/etc/varnish/default.vcl' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","mountPath":"/etc/varnish/shared"}' ]

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
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","emptyDir":{"medium":"Memory"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","configMap":{"name":"release-name-varnish-enterprise-vcl"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_VCL_CONF") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" = "/etc/varnish/default.vcl" ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","mountPath":"/etc/varnish/shared"}' ]

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
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","emptyDir":{"medium":"Memory"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","configMap":{"name":"release-name-varnish-enterprise-vcl"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_VCL_CONF") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" = "/etc/varnish/default.vcl" ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","mountPath":"/etc/varnish/shared"}' ]

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
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","emptyDir":{"medium":"Memory"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","configMap":{"name":"release-name-varnish-enterprise-vcl"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl-main-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl-main-vcl","configMap":{"name":"release-name-varnish-enterprise-vcl-main-vcl"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_VCL_CONF") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" = "/etc/varnish/default.vcl" ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","mountPath":"/etc/varnish/shared"}' ]

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
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","emptyDir":{"medium":"Memory"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","configMap":{"name":"release-name-varnish-enterprise-vcl"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl-main-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl-main-vcl","configMap":{"name":"release-name-varnish-enterprise-vcl-main-vcl"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_VCL_CONF") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" = "/etc/varnish/default.vcl" ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","mountPath":"/etc/varnish/shared"}' ]

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
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","emptyDir":{"medium":"Memory"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","configMap":{"name":"release-name-varnish-enterprise-vcl"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl-main-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl-main-vcl","configMap":{"name":"release-name-varnish-enterprise-vcl-main-vcl"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_VCL_CONF") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" = "/etc/varnish/varnish.vcl" ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","mountPath":"/etc/varnish/shared"}' ]

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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_VCL_CONF") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "/etc/varnish/varnish.vcl" ]

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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_VCL_CONF") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" = '/etc/varnish/varnish.vcl' ]

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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_VCL_CONF") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "/etc/varnish/varnish.vcl" ]

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
    [ "${actual}" = '{"name":"release-name-config-cmdfile","configMap":{"name":"release-name-varnish-enterprise-cmdfile"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "-I /etc/varnish/cmds.cli" ]

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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "-I /etc/varnish/cmdfile" ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-cmdfile")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-cmdfile","mountPath":"/etc/varnish/cmdfile","subPath":"cmds.cli"}' ]
}

@test "${kind}/cmdfile: cannot be configured with agent" {
    cd "$(chart_dir)"

    local cmdfileConfig='
vcl.load vcl_tenant1 /etc/varnish/tenant1.vcl
vcl.label label_tenant1 vcl_tenant1
vcl.load vcl_main /etc/varnish/main.vcl
vcl.use vcl_main
'

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.cmdfileConfig=${cmdfileConfig}" \
        --set "server.agent.enabled=true" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"Cannot enable both cmdfile and agent"* ]]
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
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
          app.kubernetes.io/name: {{ include "varnish-enterprise.name" . }}
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

    [ "${actual}" == '{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"app.kubernetes.io/name":"varnish-enterprise","app.kubernetes.io/instance":"release-name"}},"topologyKey":"kubernetes.io/hostname"}]}}' ]
}

@test "${kind}/mse/memoryTarget: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.mse.memoryTarget=80%' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "MSE_MEMORY_TARGET") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "80%" ]
}

@test "${kind}/mse/memoryTarget: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "MSE_MEMORY_TARGET") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "" ]
}

@test "${kind}/mse/config: can be configured" {
    cd "$(chart_dir)"

    local mseConfig='
env: {
  id = "env";
  memcache_size = "auto";
  books = ( {
    id = "book1";
    directory = "{{ .Values.server.mse.persistence.mountPath }}/book1";
    database_size = "1G";
    stores = ( {
      id = "store";
      filename = "{{ .Values.server.mse.persistence.mountPath }}/store1.dat";
      size = "9G";
    } );
  } );
};'

    local expectedMseConfig='
env: {
  id = "env";
  memcache_size = "auto";
  books = ( {
    id = "book1";
    directory = "var/lib/mse/book1";
    database_size = "1G";
    stores = ( {
      id = "store";
      filename = "/var/lib/mse/store1.dat";
      size = "9G";
    } );
  } );
};'

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.mse.config=${mseConfig}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-mse"' |
            tee -a /dev/stderr)
    [ "${actual}" = '743d1704f0c1d9c5dcbadb6ecf463947ef37f1e8c3db0e58ac150ecd5a1a74a8' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-mse")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-mse","configMap":{"name":"release-name-varnish-enterprise-mse"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "MSE_CONFIG") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "/etc/varnish/mse.conf" ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-mse")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-mse","mountPath":"/etc/varnish/mse.conf","subPath":"mse.conf"}' ]
}

@test "${kind}/mse/config: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-mse"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-mse")' |
            tee -a /dev/stderr)
    [ "${actual}" = '' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "MSE_CONFIG")' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-mse")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]
}

@test "${kind}/mse/config: cannot be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.mse.enabled=false' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)

    [[ "${actual}" == *"Either MSE or MSE4 must be enabled: 'server.mse.enabled' or 'server.mse4.enabled'"* ]]
}

@test "${kind}/mse/config: can be disabled when mse4 is enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.mse.enabled=false' \
        --set 'server.mse4.enabled=true' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "VARNISH_STORAGE_BACKEND") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "mse4" ]
}

@test "${kind}/mse4/config: can be enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.mse4.enabled=true' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "VARNISH_STORAGE_BACKEND") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "mse4" ]
}

@test "${kind}/mse4/config: cannot be enabled when mse is enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.mse.enabled=true' \
        --set 'server.mse4.enabled=true' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)

    [[ "${actual}" == *"Only one of MSE or MSE4 can be enabled at the same time: 'server.mse.enabled' or 'server.mse4.enabled'"* ]]
}

@test "${kind}/mse4/memoryTarget: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.mse4.enabled=true' \
        --set 'server.mse4.memoryTarget=80%' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "MSE_MEMORY_TARGET") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "80%" ]
}

@test "${kind}/mse4/memoryTarget: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.mse4.enabled=true' \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .env[]? | select(.name == "MSE_MEMORY_TARGET") | .value' |
            tee -a /dev/stderr)

    [ "${actual}" == "" ]
}

@test "${kind}/mse4/config: can be configured" {
    cd "$(chart_dir)"

    local mse4Config='
env: {
  books = ( {
    id = "book";
    filename = "{{ .Values.server.mse4.persistence.mountPath }}/book";
    size = "1G";
    stores = ( {
      id = "store";
      filename = "{{ .Values.server.mse4.persistence.mountPath }}/store";
      size = "9G";
    } );
  } );
};'

    local expectedMse4Config='
env: {
  books = ( {
    id = "book";
    filename = "var/lib/mse4/book";
    database_size = "1G";
    stores = ( {
      id = "store";
      filename = "/var/lib/mse4/store";
      size = "9G";
    } );
  } );
};'

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.mse4.enabled=true' \
        --set "server.mse4.config=${mse4Config}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-mse4"' |
            tee -a /dev/stderr)
    [ "${actual}" = '4b7c702a1f2833fe90663595430b607bed979cacf9d523adb8ce2180f06f4102' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-mse4")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-mse4","configMap":{"name":"release-name-varnish-enterprise-mse4"}}' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "MSE4_CONFIG") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "/etc/varnish/mse4.conf" ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-mse4")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-mse4","mountPath":"/etc/varnish/mse4.conf","subPath":"mse4.conf"}' ]
}

@test "${kind}/mse4/config: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.mse4.enabled=true' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-mse4"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-mse4")' |
            tee -a /dev/stderr)
    [ "${actual}" = '' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "MSE4_CONFIG")' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-mse4")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | yq -r -c '.lifecycle' | tee -a /dev/stderr)
    [[ "${actual}" == *"MEMPOOL.sess"* ]]
    [[ "${actual}" == *"sleep 5"* ]]
    [[ "${actual}" == *"sleep 30"* ]]
}

@test "${kind}/delayedShutdown: can be enabled with shutdown_delay" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.delayedShutdown.method=shutdown_delay" \
        --set "server.delayedShutdown.shutdownDelay.seconds=120" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | yq -r -c '.lifecycle' | tee -a /dev/stderr)
    [ "${actual}" = "null" ]

    local actual=$(echo "$container" | yq -r -c '.env[]? | select(.name == "VARNISH_EXTRA") | .value' | tee -a /dev/stderr)
    [ "${actual}" == "-p shutdown_close=off -p shutdown_delay=120" ]
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

@test "${kind}/terminationGracePeriodSeconds: do nothing with delayedShutdown shutdown_delay seconds" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.terminationGracePeriodSeconds=180" \
        --set "server.delayedShutdown.method=mempool" \
        --set "server.delayedShutdown.shutdownDelay.seconds=1" \
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

@test "${kind}/agent: not enabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? |
            select(.name == "varnish-enterprise-agent")' | tee -a /dev/stderr)
    [ "${actual}" == "" ]
}

@test "${kind}/agent: can be enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_AGENT_NAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" = '-I /etc/varnish/shared/agent/cmds.cli' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | tee -a /dev/stderr |
            yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_AGENT_NAME") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"fieldRef":{"fieldPath":"metadata.name"}}' ]
}

@test "${kind}/agent: can be enabled without initAgent" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.initAgent.enabled=false" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_AGENT_NAME") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"fieldRef":{"fieldPath":"metadata.name"}}' ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" = '-I /var/lib/varnish-controller/varnish-controller-agent/$(VARNISH_CONTROLLER_AGENT_NAME)/cmds.cli' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | tee -a /dev/stderr |
            yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_AGENT_NAME") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"fieldRef":{"fieldPath":"metadata.name"}}' ]
}

@test "${kind}/agent: can be enabled without initAgent with useReleaseName" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.replicas=1" \
        --set "server.agent.enabled=true" \
        --set "server.initAgent.enabled=false" \
        --set "server.agent.useReleaseName=true" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_AGENT_NAME") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'release-name' ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_EXTRA") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" = '-I /var/lib/varnish-controller/varnish-controller-agent/$(VARNISH_CONTROLLER_AGENT_NAME)/cmds.cli' ]

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | tee -a /dev/stderr |
            yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_AGENT_NAME") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'release-name' ]
}

@test "${kind}/agent: can be enabled with custom http port" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.secret=hello-varnish" \
        --set 'server.http.enabled=true' \
        --set 'server.http.port=8090' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_VARNISH_HOST") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"fieldRef":{"fieldPath":"status.podIP"}}' ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_VARNISH_PORT") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "8090" ]
}

@test "${kind}/agent: cannot be enabled when http port is disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.secret=hello-varnish" \
        --set 'server.http.enabled=false' \
        --set 'server.service.http.enabled=false' \
        --set 'server.livenessProbe=' \
        --set 'server.readinessProbe=' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"HTTP support must be enabled to enable Varnish Controller Agent"* ]]
}

@test "${kind}/agent: can be enabled with custom admin port" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.secret=hello-varnish' \
        --set 'server.agent.enabled=true' \
        --set 'server.admin.address=0.0.0.0' \
        --set 'server.admin.port=9999' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_VARNISH_ADMIN_HOST") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "0.0.0.0" ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_VARNISH_ADMIN_PORT") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "9999" ]
}

@test "${kind}/agent: can be enabled with external secret" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.secretFrom.name=external-secret" \
        --set "server.secretFrom.key=varnish-secret" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-secret")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-secret","secret":{"secretName":"external-secret"}}' ]
}

@test "${kind}/agent: cannot be enabled without secret" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"Secret must be set to enable Varnish Controller agent"* ]]
}

@test "${kind}/agent: can be enabled with private token" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.privateToken=private-token" \
        --set 'server.secret=hello-varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_PRIVATE_TOKEN") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'private-token' ]
}

@test "${kind}/agent: inherits securityContext from global and agent" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'global.securityContext.hello=world' \
        --set 'server.securityContext.ignore-this=yes' \
        --set 'server.agent.securityContext.runAsUser=1001' \
        --set 'server.agent.securityContext.foo=baz' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"foo":"baz","hello":"world","runAsNonRoot":true,"runAsUser":1001}' ]
}

@test "${kind}/agent: inherits securityContext from global and agent with global as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set "global.securityContext=${securityContext}" \
        --set 'server.securityContext.ignore-this=yes' \
        --set 'server.agent.securityContext.runAsUser=1001' \
        --set 'server.agent.securityContext.foo=baz' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .securityContext' | tee -a /dev/stderr)

    [ "${actual}" == '{"foo":"baz","release-name":"release-name","release-namespace":"default","runAsUser":1001}' ]
}

@test "${kind}/agent: inherits securityContext from global and agent with agent as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'global.securityContext.hello=world' \
        --set 'server.securityContext.ignore-this=yes' \
        --set "server.agent.securityContext=${securityContext}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"hello":"world","release-name":"release-name","release-namespace":"default","runAsNonRoot":true,"runAsUser":999}' ]
}

@test "${kind}/agent: inherits securityContext from global and agent with both as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: to-be-override
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set "global.securityContext=${securityContext}" \
        --set 'server.securityContext.ignore-this=yes' \
        --set 'server.agent.securityContext=release-namespace: {{ .Release.Namespace }}' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"release-name":"release-name","release-namespace":"default"}' ]
}

@test "${kind}/agent: inherits nats configuration from global" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '$(VARNISH_CONTROLLER_NATS_USER):$(VARNISH_CONTROLLER_NATS_PASS)@$(VARNISH_CONTROLLER_NATS_HOST)' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"varnish-controller-credentials","key":"nats-varnish-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller-nats.default.svc.cluster.local:4222' ]
}

@test "${kind}/agent: inherits nats configuration from global with overridden values" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'global.natsServer.internal.namespace=varnish-controller' \
        --set 'global.natsServer.internal.releaseName=test' \
        --set 'global.natsServer.internal.clusterDomain=remote.local' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '$(VARNISH_CONTROLLER_NATS_USER):$(VARNISH_CONTROLLER_NATS_PASS)@$(VARNISH_CONTROLLER_NATS_HOST)' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"varnish-controller-credentials","key":"nats-varnish-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'test-nats.varnish-controller.svc.remote.local:4222' ]
}

@test "${kind}/agent: inherits nats configuration from global with external secret" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'global.natsServer.internal.namespace=varnish-controller' \
        --set 'global.natsServer.internal.releaseName=test' \
        --set 'global.natsServer.internal.clusterDomain=remote.local' \
        --set 'global.natsServer.internal.passwordFrom.name=external-secret' \
        --set 'global.natsServer.internal.passwordFrom.key=nats-password' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '$(VARNISH_CONTROLLER_NATS_USER):$(VARNISH_CONTROLLER_NATS_PASS)@$(VARNISH_CONTROLLER_NATS_HOST)' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"external-secret","key":"nats-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'test-nats.varnish-controller.svc.remote.local:4222' ]
}

@test "${kind}/agent: inherits nats configuration from global with external nats" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'global.natsServer.externalAddress=nats.local:4222' \
        --set 'global.natsServer.internal.enabled=false' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'nats.local:4222' ]
}

@test "${kind}/agent: cannot disable both external and internal nats" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'global.natsServer.externalAddress=' \
        --set 'global.natsServer.internal.enabled=false' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"Either 'global.natsServer.internal.enabled' or 'global.natsServer.externalAddress' must be set"* ]]
}

@test "${kind}/agent/logLevel: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'server.agent.logLevel=info' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_LOG")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_LOG","value":"info"}' ]
}

@test "${kind}/agent/extraEnvs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'server.agent.extraEnvs.FOO=bar' \
        --set 'server.agent.extraEnvs.BAZ=bax' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "${kind}/agent/extraEnvs: can be configured as a templated string" {
    cd "$(chart_dir)"

    local extraEnvs="
- name: RELEASE_NAME
  value: {{ .Release.Name }}
- name: RELEASE_NAMESPACE
  value: {{ .Release.Namespace }}"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.secret=hello-varnish' \
        --set 'server.agent.enabled=true' \
        --set "server.agent.extraEnvs=${extraEnvs}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "RELEASE_NAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAME","value":"release-name"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "RELEASE_NAMESPACE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAMESPACE","value":"default"}' ]
}

@test "${kind}/agent/extraEnvs: can be configured as a list" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.secret=hello-varnish' \
        --set 'server.agent.enabled=true' \
        --set 'server.agent.extraEnvs[0].name=FOO' \
        --set 'server.agent.extraEnvs[0].value=bar' \
        --set 'server.agent.extraEnvs[1].name=BAZ' \
        --set 'server.agent.extraEnvs[1].value=bax' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "${kind}/agent/extraEnvs: can be configured as a list of non-value literalFrom" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.secret=hello-varnish' \
        --set 'server.agent.enabled=true' \
        --set 'server.agent.extraEnvs[0].name=FROM_CONFIGMAP' \
        --set 'server.agent.extraEnvs[0].valueFrom.configMapKeyRef.name=my-configmap' \
        --set 'server.agent.extraEnvs[0].valueFrom.configMapKeyRef.key=my-key' \
        --set 'server.agent.extraEnvs[1].name=FROM_SECRET' \
        --set 'server.agent.extraEnvs[1].valueFrom.secretKeyRef.name=my-secret' \
        --set 'server.agent.extraEnvs[1].valueFrom.secretKeyRef.key=my-key' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "FROM_CONFIGMAP")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_CONFIGMAP","valueFrom":{"configMapKeyRef":{"key":"my-key","name":"my-configmap"}}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "FROM_SECRET")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_SECRET","valueFrom":{"secretKeyRef":{"key":"my-key","name":"my-secret"}}}' ]
}

@test "${kind}/agent/tags: unset by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_TAGS")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]
}

@test "${kind}/agent/tags: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'server.agent.tags[0]=tokyodc' \
        --set 'server.agent.tags[1]=highmem' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_TAGS")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_TAGS","value":"tokyodc,highmem"}' ]
}

@test "${kind}/agent/location: unset by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_LONGITUDE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_LATITUDE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]
}

@test "${kind}/agent/location: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'server.agent.location.latitude=37.354107' \
        --set 'server.agent.location.longitude=-121.955238' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_LATITUDE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_LATITUDE","value":"37.354107"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_LONGITUDE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_LONGITUDE","value":"-121.955238"}' ]
}

@test "${kind}/agent/resources: inherits resources from global and agent" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'global.resources.limits.cpu=100m' \
        --set 'global.resources.requests.cpu=100m' \
        --set 'server.resources.ignore-this=yes' \
        --set 'server.agent.resources.limits.cpu=500m' \
        --set 'server.agent.resources.limits.memory=512Mi' \
        --set 'server.agent.resources.requests.memory=128Mi' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/agent/resources: inherits resources from global and agent with global as a templated string" {
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
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'global.resources.limits.cpu=100m' \
        --set 'global.resources.requests.cpu=100m' \
        --set 'server.resources.ignore-this=yes' \
        --set "server.agent.resources=${resources}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/agent/resources: inherits resources from global and agent with server as a templated string" {
    cd "$(chart_dir)"

    local resources="
limits:
  cpu: 100m
requests:
  cpu: 100m
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set "global.resources=${resources}" \
        --set 'server.resources.ignore-this=yes' \
        --set 'server.agent.resources.limits.cpu=500m' \
        --set 'server.agent.resources.limits.memory=512Mi' \
        --set 'server.agent.resources.requests.memory=128Mi' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/agent/resources: inherits resources from global and agent with both as a templated string" {
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
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set "global.resources=${globalResources}" \
        --set 'server.resources.ignore-this=yes' \
        --set "server.agent.resources=${resources}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/agent/resources: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "${kind}/agent/persistence: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .volumeMounts[]? | select(.name == "release-name-varnish-controller")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-varnish-controller","mountPath":"/var/lib/varnish-controller"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.volumes[]? | select(.name == "release-name-varnish-controller")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-varnish-controller","emptyDir":{}}' ]
}

@test "${kind}/agent/vcl: use the bundled vcl by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '' ]
}

@test "${kind}/agent/vcl: included with controller agent" {
    cd "$(chart_dir)"

    local vclConfig='
vcl 4.1;

backend {{ .Release.Name }} {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set "server.vclConfig=${vclConfig}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-vcl","mountPath":"/etc/varnish/default.vcl","subPath":"default.vcl"}' ]
}

@test "${kind}/agent/vcl: included with controller agent when configured via vclConfigs" {
    cd "$(chart_dir)"

    local vclConfig='
vcl 4.1;

backend {{ .Release.Name }} {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set "server.vclConfig=" \
        --set 'server.vclConfigs.default\.vcl='"${vclConfig}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-vcl","mountPath":"/etc/varnish/default.vcl","subPath":"default.vcl"}' ]
}

@test "${kind}/agent/vcl: included with controller agent when configured via vclConfigs with extra vcls" {
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

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set "server.vclConfig=${vclConfig}" \
        --set 'server.vclConfigs.main\.vcl='"${extraVclConfig}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-vcl","mountPath":"/etc/varnish/default.vcl","subPath":"default.vcl"}' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl-main-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-vcl-main-vcl","mountPath":"/etc/varnish/main.vcl","subPath":"main.vcl"}' ]
}

@test "${kind}/agent/vcl: included with controller agent when configured via vclConfigs with extra vcls with default.vcl" {
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

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set "server.vclConfig=" \
        --set 'server.vclConfigs.default\.vcl='"${vclConfig}" \
        --set 'server.vclConfigs.main\.vcl='"${extraVclConfig}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-vcl","mountPath":"/etc/varnish/default.vcl","subPath":"default.vcl"}' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl-main-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-vcl-main-vcl","mountPath":"/etc/varnish/main.vcl","subPath":"main.vcl"}' ]
}

@test "${kind}/agent/vcl: included with controller agent when configured via vclConfigs with extra vcls with alternative names" {
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

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set "server.vclConfig=" \
        --set 'server.vclConfigPath=/etc/varnish/varnish.vcl' \
        --set 'server.vclConfigs.varnish\.vcl='"${vclConfig}" \
        --set 'server.vclConfigs.main\.vcl='"${extraVclConfig}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-vcl","mountPath":"/etc/varnish/varnish.vcl","subPath":"varnish.vcl"}' ]

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl-main-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-vcl-main-vcl","mountPath":"/etc/varnish/main.vcl","subPath":"main.vcl"}' ]
}

@test "${kind}/agent/vcl: included with controller agent when relocated" {
    cd "$(chart_dir)"

    local vclConfig='
vcl 4.1;

backend default {
  .host = "127.0.0.1";
  .port = "8080";
}'

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set "server.vclConfig=${vclConfig}" \
        --set "server.vclConfigPath=/etc/varnish/varnish.vcl" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-vcl","mountPath":"/etc/varnish/varnish.vcl","subPath":"varnish.vcl"}' ]
}

@test "${kind}/agent/extraArgs: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/usr/bin/varnish-controller-agent"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .args' |
            tee -a /dev/stderr)
    [ "${actual}" == 'null' ]
}

@test "${kind}/agent/extraArgs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set "server.agent.extraArgs[0]=-help" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/usr/bin/varnish-controller-agent"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .args' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-help"]' ]
}

@test "${kind}/agent/extraVolumeMounts: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'server.agent.extraVolumeMounts[0].name=varnish-data' \
        --set 'server.agent.extraVolumeMounts[0].mountPath=/var/data' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .volumeMounts[]? | select(.name == "varnish-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"mountPath":"/var/data","name":"varnish-data"}' ]
}

@test "${kind}/agent/extraVolumeMounts: can be configured as templated string" {
    cd "$(chart_dir)"

    local extraVolumeMounts="
- name: {{ .Release.Name }}-data
  mountPath: /var/data"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set "server.agent.extraVolumeMounts=${extraVolumeMounts}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .volumeMounts[]? | select(.name == "release-name-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"name":"release-name-data","mountPath":"/var/data"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be enabled with agent" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? |
            select(.name == "varnish-enterprise-vcli")' | tee -a /dev/stderr |
            yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "${kind}/agent/autoRemove/vcli: ignored if agent is not enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? |
            select(.name == "varnish-enterprise-vcli")' | tee -a /dev/stderr)
    [ "${actual}" = "" ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured with username and password" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.username=guest" \
        --set "server.agent.autoRemove.vcli.password=passw0rd" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_USERNAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_USERNAME","value":"guest"}' ]

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_PASSWORD")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_PASSWORD","value":"passw0rd"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured with passwordFrom" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.passwordFrom.name=my-secret" \
        --set "server.agent.autoRemove.vcli.passwordFrom.key=password-key" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_PASSWORD")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_PASSWORD","valueFrom":{"secretKeyRef":{"name":"my-secret","key":"password-key"}}}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured to skip certificate verification" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.insecure=true" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_INSECURE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_INSECURE","value":"true"}' ]
}

@test "${kind}/agent/autoRemove/vcli: configured to use internal varnish-controller by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"http://varnish-controller-apigw.default.svc.cluster.local:8080"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured to use internal controller in a different namespace" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.internal.namespace=other-namespace" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"http://varnish-controller-apigw.other-namespace.svc.cluster.local:8080"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured to use internal controller with a different release name" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.internal.releaseName=vc" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"http://vc-apigw.default.svc.cluster.local:8080"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured to use internal controller with a different port" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.internal.port=8888" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"http://varnish-controller-apigw.default.svc.cluster.local:8888"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured to use internal controller on port 80" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.internal.port=80" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"http://varnish-controller-apigw.default.svc.cluster.local"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured to use internal controller with https on port 443" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.internal.https=true" \
        --set "server.agent.autoRemove.vcli.internal.port=443" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"https://varnish-controller-apigw.default.svc.cluster.local"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured to use internal controller with https on non-port 443" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.internal.https=true" \
        --set "server.agent.autoRemove.vcli.internal.port=4444" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"https://varnish-controller-apigw.default.svc.cluster.local:4444"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured with external controller" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.externalAddress=https://varnish-controller.example.com" \
        --set "server.agent.autoRemove.vcli.internal.enabled=false" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"https://varnish-controller.example.com"}' ]
}

@test "${kind}/agent/autoRemove/vcli: configured with autoRemoveAgent by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.secret=foobar" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli")' |
            tee -a /dev/stderr)

    # Note: the script is actually tested in E2E
    local actual=$(echo "$container" |
        yq -r -c '.lifecycle.preStop.exec.command | first' |
            tee -a /dev/stderr)
    [ "${actual}" == '/bin/sh' ]
}

@test "${kind}/agent/autoRemove/vcli/extraEnvs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.autoRemove.method=vcli" \
        --set 'server.agent.autoRemove.vcli.extraEnvs.FOO=bar' \
        --set 'server.agent.autoRemove.vcli.extraEnvs.BAZ=bax' \
        --set 'server.secret=hello-varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "${kind}/agent/autoRemove/vcli/extraEnvs: can be configured as a templated string" {
    cd "$(chart_dir)"

    local extraEnvs="
- name: RELEASE_NAME
  value: {{ .Release.Name }}
- name: RELEASE_NAMESPACE
  value: {{ .Release.Namespace }}"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.extraEnvs=${extraEnvs}" \
        --set 'server.secret=hello-varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli") |
            .env[]? | select(.name == "RELEASE_NAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAME","value":"release-name"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli") |
            .env[]? | select(.name == "RELEASE_NAMESPACE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAMESPACE","value":"default"}' ]
}

@test "${kind}/agent/autoRemove/vcli/extraEnvs: can be configured as a list" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.autoRemove.method=vcli" \
        --set 'server.agent.autoRemove.vcli.extraEnvs[0].name=FOO' \
        --set 'server.agent.autoRemove.vcli.extraEnvs[0].value=bar' \
        --set 'server.agent.autoRemove.vcli.extraEnvs[1].name=BAZ' \
        --set 'server.agent.autoRemove.vcli.extraEnvs[1].value=bax' \
        --set 'server.secret=hello-varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "${kind}/agent/autoRemove/extraEnvs: can be configured as a list of non-value literalFrom" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.autoRemove.method=vcli" \
        --set 'server.agent.autoRemove.vcli.extraEnvs[0].name=FROM_CONFIGMAP' \
        --set 'server.agent.autoRemove.vcli.extraEnvs[0].valueFrom.configMapKeyRef.name=my-configmap' \
        --set 'server.agent.autoRemove.vcli.extraEnvs[0].valueFrom.configMapKeyRef.key=my-key' \
        --set 'server.agent.autoRemove.vcli.extraEnvs[1].name=FROM_SECRET' \
        --set 'server.agent.autoRemove.vcli.extraEnvs[1].valueFrom.secretKeyRef.name=my-secret' \
        --set 'server.agent.autoRemove.vcli.extraEnvs[1].valueFrom.secretKeyRef.key=my-key' \
        --set 'server.secret=hello-varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli") |
            .env[]? | select(.name == "FROM_CONFIGMAP")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_CONFIGMAP","valueFrom":{"configMapKeyRef":{"key":"my-key","name":"my-configmap"}}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli") |
            .env[]? | select(.name == "FROM_SECRET")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_SECRET","valueFrom":{"secretKeyRef":{"key":"my-key","name":"my-secret"}}}' ]
}

@test "${kind}/agent/autoRemove/vcli/resources: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.autoRemove.method=vcli" \
        --set 'server.agent.autoRemove.vcli.resources.limits.cpu=500m' \
        --set 'server.agent.autoRemove.vcli.resources.limits.memory=512Mi' \
        --set 'server.agent.autoRemove.vcli.resources.requests.cpu=100m' \
        --set 'server.agent.autoRemove.vcli.resources.requests.memory=128Mi' \
        --set 'server.secret=foobar' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/agent/autoRemove/vcli/resources: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.autoRemove.method=vcli" \
        --set 'server.secret=foobar' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "${kind}/agent/autoRemove/vcli/extraVolumeMounts: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.autoRemove.method=vcli" \
        --set 'server.agent.autoRemove.vcli.extraVolumeMounts[0].name=varnish-data' \
        --set 'server.agent.autoRemove.vcli.extraVolumeMounts[0].mountPath=/var/data' \
        --set 'server.secret=foobar' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli") |
            .volumeMounts[]? | select(.name == "varnish-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"mountPath":"/var/data","name":"varnish-data"}' ]
}

@test "${kind}/agent/autoRemove/vcli/extraVolumeMounts: can be configured as templated string" {
    cd "$(chart_dir)"

    local extraVolumeMounts="
- name: {{ .Release.Name }}-data
  mountPath: /var/data"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.extraVolumeMounts=${extraVolumeMounts}" \
        --set 'server.secret=foobar' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-vcli") |
            .volumeMounts[]? | select(.name == "release-name-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"name":"release-name-data","mountPath":"/var/data"}' ]
}

@test "${kind}/initAgent: enabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.initContainers[]? | select(.name == "init-agent") |
            length > 0' |
            tee -a /dev/stderr)

    [ "${actual}" == 'true' ]
}

@test "${kind}/initAgent/extraVolumeMounts: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'server.initAgent.extraVolumeMounts[0].name=varnish-data' \
        --set 'server.initAgent.extraVolumeMounts[0].mountPath=/var/data' \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.initContainers[]? | select(.name == "init-agent") |
            .volumeMounts[]? | select(.name == "varnish-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"mountPath":"/var/data","name":"varnish-data"}' ]
}

@test "${kind}/initAgent/extraVolumeMounts: can be configured as templated string" {
    cd "$(chart_dir)"

    local extraVolumeMounts="
- name: {{ .Release.Name }}-data
  mountPath: /var/data"
    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set "server.initAgent.extraVolumeMounts=${extraVolumeMounts}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.initContainers[]? | select(.name == "init-agent") |
            .volumeMounts[]? | select(.name == "release-name-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"name":"release-name-data","mountPath":"/var/data"}' ]
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa")' |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
            .args' |
            tee -a /dev/stderr)

    [ "${actual}" == '--help' ]
}

@test "${kind}/varnishncsa/image: inherit from varnish-enterprise by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.image.repository=localhost/varnish-enterprise" \
        --set "server.image.tag=latest" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
            .image' |
            tee -a /dev/stderr)

    [ "${actual}" == "localhost/varnish-enterprise:latest" ]
}

@test "${kind}/varnishncsa/image: can be overridden" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.image.repository=localhost/varnish-enterprise" \
        --set "server.image.tag=latest" \
        --set "server.varnishncsa.image.repository=localhost/varnish-enterprise-ncsa" \
        --set "server.varnishncsa.image.tag=ncsa-latest" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
            .image' |
            tee -a /dev/stderr)

    [ "${actual}" == "localhost/varnish-enterprise-ncsa:ncsa-latest" ]
}

@test "${kind}/varnishncsa/startupProbe: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
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
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-ncsa") |
            .volumeMounts[]? | select(.name == "release-name-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"name":"release-name-data","mountPath":"/var/data"}' ]
}

@test "${kind}/extraManifests: do nothing with templated string without checksum flag" {
    cd "$(chart_dir)"

    cat <<EOF > "$BATS_RUN_TMPDIR"/values.yaml
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
        -f "$BATS_RUN_TMPDIR"/values.yaml \
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

    cat <<EOF > "$BATS_RUN_TMPDIR"/values.yaml
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
        -f "$BATS_RUN_TMPDIR"/values.yaml \
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

    cat <<EOF > "$BATS_RUN_TMPDIR"/values.yaml
extraManifests:
  - name: clusterrole
    data:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: varnish-enterprise-clusterrole
      rules:
        - apiGroups: [""]
          resources: ["endpoints"]
          verbs: ["get", "list", "watch"]
  - name: clusterrolebinding
    data:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: varnish-enterprise-clusterrolebinding
      roleRef:
        kind: ClusterRole
        name: varnish-enterprise-clusterrole
        apiGroup: rbac.authorization.k8s.io
      subjects:
        - kind: ServiceAccount
          name: varnish-enterprise
          namespace: default
EOF

    local object=$((helm template \
        -f "$BATS_RUN_TMPDIR"/values.yaml \
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

    cat <<EOF > "$BATS_RUN_TMPDIR"/values.yaml
extraManifests:
  - name: clusterrole
    checksum: true
    data:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: varnish-enterprise-clusterrole
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
        name: varnish-enterprise-clusterrolebinding
      roleRef:
        kind: ClusterRole
        name: varnish-enterprise-clusterrole
        apiGroup: rbac.authorization.k8s.io
      subjects:
        - kind: ServiceAccount
          name: varnish-enterprise
          namespace: default
EOF

    local object=$((helm template \
        -f "$BATS_RUN_TMPDIR"/values.yaml \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrole"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'dd5731f8b37e11291ee9d37e4efdae991f3b58c4f863d75b3faac538a4df6ab3' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrolebinding"' |
            tee -a /dev/stderr)
    [ "${actual}" = '52e43eed97374991f0ca4fd84283acbbf54134898bb5b36c4dc70a03ce595805' ]
}

@test "${kind}/licenseSecret: creates a license volume and volumeMounts" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.licenseSecret=test-value' \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "varnish-license-volume")' |
        tee -a /dev/stderr)

    [ "${actual}" == '{"name":"varnish-license-volume","secret":{"secretName":"test-value"}}' ]

    local actual=$(echo "$object" |
        yq -r '
        .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
        .volumeMounts[]? | select(.name == "varnish-license-volume") |
        .mountPath' |
        tee -a /dev/stderr)

    # Check if the extracted mountPath is the one we expect
    [ "${actual}" == "/etc/varnish/varnish-enterprise.lic" ]
}

@test "${kind}/licenseSecret: license volume and volumeMounts does not exist by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r '
            .spec.template.spec.volumes[]? | select(.name == "varnish-license-volume")' |
        tee -a /dev/stderr)

    [ -z "${actual}" ]

    local actual=$(echo "$object" |
        yq -r '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .volumeMounts[]? | select(.name == "varnish-license-volume")' |
        tee -a /dev/stderr)

    [ -z "${actual}" ]
}
