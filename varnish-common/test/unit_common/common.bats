#!/usr/bin/env bats

load ../unit/_helpers

kind=${kind:-}
template=${template:-}
chart=$(chart_name)
default_fsgroup=$(yq -r '.global.podSecurityContext.fsGroup' < "$(chart_dir)/values.yaml")
default_uid=$(yq -r '.global.securityContext.runAsUser' < "$(chart_dir)/values.yaml")

teardown() {
    check_render
}

@test "${kind}: inherits imagePullSecret from global" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.imagePullSecrets[0].name=quay.io-varnish-software' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec.imagePullSecrets' | tee -a /dev/stderr)
    [ "${actual}" == '[{"name":"quay.io-varnish-software"}]' ]
}

@test "${kind}: can enable serviceAccount" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'serviceAccount.create=true' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec.serviceAccountName' | tee -a /dev/stderr)
    [ "${actual}" == "release-name-${chart}" ]
}

@test "${kind}: use default serviceAccount when disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'serviceAccount.create=false' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec.serviceAccountName' | tee -a /dev/stderr)
    [ "${actual}" == "default" ]
}

@test "${kind}: inherits securityContext from global" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.podSecurityContext.hello=world' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec.securityContext' | tee -a /dev/stderr)

    # Note: values.yaml sets a default 'global.podSecurityContext.fsGroup';
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"fsGroup":'"${default_fsgroup}"',"hello":"world"}' ]
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"hello":"world","release-name":"release-name","release-namespace":"default","runAsNonRoot":true,"runAsUser":'"${default_uid}"'}' ]
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"release-name":"release-name","release-namespace":"default"}' ]
}

@test "${kind}: inherits labels from global" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.labels.hello=varnish' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.metadata.labels.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "${kind}: inherits labels from global as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.labels=hello: {{ .Release.Name }}' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.metadata.labels.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "${kind}: inherits annotations from global" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.annotations.hello=varnish' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "${kind}: inherits annotations from global as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.annotations=hello: {{ .Release.Name }}' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "${kind}: inherits podAnnotations from global" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.podAnnotations.hello=varnish' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "${kind}: inherits podAnnotations from global as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.podAnnotations=hello: {{ .Release.Name }}' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "${kind}: global.labels apply to the workload only" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.labels.hello=varnish' \
        --set 'global.annotations.hello=varnish' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    [ "$(echo "$object" | yq -r '.spec.template.metadata.labels.hello')" == "null" ]
    [ "$(echo "$object" | yq -r '.spec.template.metadata.annotations.hello')" == "null" ]
}

@test "${kind}: inherits podLabels from global" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.podLabels.foo=bar' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"'"${chart}"'","foo":"bar"}' ]
}

@test "${kind}: inherits podLabels from global as templated string" {
    cd "$(chart_dir)"

    local labels="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "global.podLabels=${labels}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"'"${chart}"'","release-name":"release-name","release-namespace":"default"}' ]
}

@test "${kind}: global.podAnnotations are merged with the checksum annotations" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.podAnnotations.hello=varnish' \
        --set-string 'server.vclConfig=vcl 4.1;' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations | keys' |
            tee -a /dev/stderr)

    [ "${actual}" == '["checksum/release-name-vcl","hello"]' ]
}

@test "${kind}: inherits default selector labels" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    # .metadata.labels

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.metadata.labels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "${chart}" ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.metadata.labels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.metadata.labels."app.kubernetes.io/version"' |
            tee -a /dev/stderr)
    [ "${actual}" != "" ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.metadata.labels."app.kubernetes.io/managed-by"' |
            tee -a /dev/stderr)
    [ "${actual}" == "Helm" ]

    # .spec.selector.matchLabels

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.selector.matchLabels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "${chart}" ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.selector.matchLabels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]

    # .spec.template.metadata.labels

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.labels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "${chart}" ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.labels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "${kind}/http: can be enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.http.enabled=true' \
        --set 'server.http.port=8090' \
        --set 'server.http.podIP=false' \
        --set 'server.startupProbe.initialDelaySeconds=5' \
        --set 'server.readinessProbe.initialDelaySeconds=5' \
        --set 'server.livenessProbe.initialDelaySeconds=5' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.ports[]? | select(.name == "http")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"http","containerPort":8090,"protocol":"TCP"}' ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.startupProbe.tcpSocket.port' |
            tee -a /dev/stderr)
    [ "${actual}" == "8090" ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.readinessProbe.tcpSocket.port' |
            tee -a /dev/stderr)
    [ "${actual}" == "8090" ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.livenessProbe.tcpSocket.port' |
            tee -a /dev/stderr)
    [ "${actual}" == "8090" ]

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-a", "http=0.0.0.0:8090"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'http=0.0.0.0:8090' ]
}

@test "${kind}/http: listen address can be configured" {
   cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.http.enabled=true' \
        --set 'server.http.port=8090' \
        --set 'server.http.podIP=false' \
        --set 'server.http.address=127.0.0.2' \
        --set 'server.startupProbe.initialDelaySeconds=5' \
        --set 'server.readinessProbe.initialDelaySeconds=5' \
        --set 'server.livenessProbe.initialDelaySeconds=5' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-a", "http=127.0.0.2:8090"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'http=127.0.0.2:8090' ]
}

@test "${kind}/http: listen address can be configured to podIP" {
   cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.http.enabled=true' \
        --set 'server.http.port=8090' \
        --set 'server.http.podIP=true' \
        --set 'server.startupProbe.initialDelaySeconds=5' \
        --set 'server.readinessProbe.initialDelaySeconds=5' \
        --set 'server.livenessProbe.initialDelaySeconds=5' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-a", "http=$(POD_IP):8090"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'http=$(POD_IP):8090' ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[] | select(.name == "POD_IP") | .valueFrom.fieldRef.fieldPath' |
            tee -a /dev/stderr)
    [ "${actual}" == 'status.podIP' ]
}

@test "${kind}/http: can be disabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.http.enabled=false' \
        --set 'server.service.enabled=false' \
        --set 'server.startupProbe=' \
        --set 'server.readinessProbe=' \
        --set 'server.livenessProbe=' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.ports[]? | select(.name == "http")' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]

    local actual=$(echo "$container" | yq -r -o=json -I=0 '.startupProbe' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]

    local actual=$(echo "$container" | yq -r -o=json -I=0 '.readinessProbe' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]

    local actual=$(echo "$container" | yq -r -o=json -I=0 '.livenessProbe' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c 'index(["-a", "http=0.0.0.0:6081"])' |
            tee -a /dev/stderr)
    [ "${actual}" == 'null' ]
}

@test "${kind}/http: cannot be disabled without disabling startupProbe" {
    cd "$(chart_dir)"

    run helm template \
        --set "server.kind=${kind}" \
        --set 'server.http.enabled=false' \
        --set 'server.service.enabled=false' \
        --set 'server.startupProbe.initialDelaySeconds=' \
        --set 'server.readinessProbe=' \
        --set 'server.livenessProbe=' \
        --namespace default \
        --show-only ${template} \
        .
    echo "${output}" >&2
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"HTTP support must be enabled to enable startupProbe"* ]]
}

@test "${kind}/http: cannot be disabled without disabling readinessProbe" {
    cd "$(chart_dir)"

    run helm template \
        --set "server.kind=${kind}" \
        --set 'server.http.enabled=false' \
        --set 'server.service.enabled=false' \
        --set 'server.livenessProbe=' \
        --namespace default \
        --show-only ${template} \
        .
    echo "${output}" >&2
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"HTTP support must be enabled to enable readinessProbe"* ]]
}

@test "${kind}/http: cannot be disabled without disabling livenessProbe" {
    cd "$(chart_dir)"

    run helm template \
        --set "server.kind=${kind}" \
        --set 'server.http.enabled=false' \
        --set 'server.service.enabled=false' \
        --set 'server.readinessProbe=' \
        --namespace default \
        --show-only ${template} \
        .
    echo "${output}" >&2
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"HTTP support must be enabled to enable livenessProbe"* ]]
}

@test "${kind}/tls: can be enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.tls.enabled=true' \
        --set 'server.tls.port=8443' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-tls"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.spec.volumes[]? | select(.name == "release-name-config-tls")' |
            tee -a /dev/stderr)
    [ "${actual}" = '' ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.ports[]? | select(.name == "https")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"https","containerPort":8443,"protocol":"TCP"}' ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_TLS_CFG") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "true" ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.volumeMounts[] | select(.name == "release-name-config-tls")' |
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-tls"' |
            tee -a /dev/stderr)
    [ "${actual}" = '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.spec.volumes[]? | select(.name == "release-name-config-tls")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-tls","configMap":{"name":"release-name-'"${chart}"'-tls"}}' ]

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_TLS_CFG") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "/etc/varnish/tls.conf" ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.volumeMounts[] | select(.name == "release-name-config-tls")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-tls","mountPath":"/etc/varnish/tls.conf","subPath":"tls.conf"}' ]
}

@test "${kind}/tls: not enabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-tls"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.ports[]? | select(.name == "https")' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_TLS_CFG")' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]
}

@test "${kind}/admin: -T and -S are hardcoded" {
    cd "$(chart_dir)"

    local manifests=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        . || render_failed) |
        tee -a /dev/stderr)

    local object=$(echo "$manifests" |
        yq -o=json -I=0 'select(.kind == "'"${kind}"'")' |
        tee -a /dev/stderr)

    local command=$(echo "$object" |
        yq -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .command' |
        tee -a /dev/stderr)

    local actual=$(echo "$command" |
        jq -r -c '.[index(["-T", "127.0.0.1:6082"]) + 1]' |
        tee -a /dev/stderr)
    [ "${actual}" == '127.0.0.1:6082' ]

    local actual=$(echo "$command" |
        jq -r -c '.[index(["-S", "/etc/varnish/shared/secret"]) + 1]' |
        tee -a /dev/stderr)
    [ "${actual}" == '/etc/varnish/shared/secret' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.spec.volumes[]? | select(.name == "release-name-config-secret")' |
        tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-secret"' |
        tee -a /dev/stderr)
    [ "${actual}" == 'null' ]

    local actual=$(echo "$manifests" |
        yq -r 'select(.kind == "Secret") | .metadata.name' |
        tee -a /dev/stderr)
    [ "${actual}" == '' ]
}

@test "${kind}/admin: secret init container" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.securityContext.readOnlyRootFilesystem=true' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local server=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
        tee -a /dev/stderr)

    local init=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.spec.initContainers[0]' |
        tee -a /dev/stderr)

    local actual=$(echo "$init" | yq -r '.name' | tee -a /dev/stderr)
    [ "${actual}" == "${chart}-secret" ]

    local actual=$(echo "$init" | yq -r '.image' | tee -a /dev/stderr)
    local expected=$(echo "$server" | yq -r '.image' | tee -a /dev/stderr)
    [ -n "${expected}" ]
    [ "${actual}" == "${expected}" ]

    local actual=$(echo "$init" | yq -r -o=json -I=0 '.securityContext' | tee -a /dev/stderr)
    local expected=$(echo "$server" | yq -r -o=json -I=0 '.securityContext' | tee -a /dev/stderr)
    [[ "${actual}" == *'"readOnlyRootFilesystem":true'* ]]
    [ "${actual}" == "${expected}" ]

    local actual=$(echo "$init" | yq -r -o=json -I=0 '.volumeMounts' | tee -a /dev/stderr)
    [ "${actual}" == '[{"name":"release-name-config-shared","mountPath":"/etc/varnish/shared"}]' ]

    local actual=$(echo "$init" | yq -r -o=json -I=0 '.command' | tee -a /dev/stderr)
    [ "${actual}" == '["sh","-c","umask 077; test -s /etc/varnish/shared/secret || head -c 32 /dev/urandom > /etc/varnish/shared/secret"]' ]
}

@test "${kind}/threads: omitted when null" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.minThreads=null' \
        --set 'server.maxThreads=null' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .command' |
            jq -r -c 'if . == null then "no command" else [.[] | select(startswith("thread_pool_"))] end' |
            tee -a /dev/stderr)
    [ "${actual}" == '[]' ]
}

@test "${kind}/threads: min before max, before parameters" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.minThreads=10' \
        --set 'server.maxThreads=80' \
        --set 'server.parameters.acceptorSleepMax=0.05' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local command=$(echo "$object" |
        yq -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .command' |
            tee -a /dev/stderr)

    local actual=$(echo "$command" |
        jq -r -c '[index("thread_pool_min=10"), index("thread_pool_max=80"), index("acceptor_sleep_max=0.05")] |
            if all(. != null) and .[0] < .[1] and .[1] < .[2] then "ordered" else tostring end' |
        tee -a /dev/stderr)
    [ "${actual}" == 'ordered' ]

    local actual=$(echo "$command" |
        jq -r -c '[index(["-t"]), (.[] | select(startswith("thread_pool_timeout")))]' |
        tee -a /dev/stderr)
    [ "${actual}" == '[null]' ]
}

@test "${kind}/threads: defaults" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .command' |
            jq -r -c '[.[] | select(startswith("thread_pool_"))]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["thread_pool_min=50","thread_pool_max=1000"]' ]
}

@test "${kind}/threads: rejected in parameters" {
    cd "$(chart_dir)"

    for key in threadPoolMin threadPoolMax thread_pool_min thread_pool_max ThreadPoolMin ThreadPoolMax; do
        run helm template \
            --set "server.kind=${kind}" \
            --set "server.parameters.${key}=5" \
            --namespace default \
            --show-only ${template} \
            .
        echo "${output}" >&2
        [ "${status}" -ne 0 ]
        [[ "${output}" == *"Set thread pool sizes with 'server.minThreads'/'server.maxThreads', not 'server.parameters'"* ]]
    done
}

@test "${kind}/workdir: no -n" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.enabled=true' \
        --set-json 'server.varnishncsa.extraArgs=[]' \
        --set 'server.otel.enabled=true' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .command' |
        jq -r -c 'if . == null then "no command" else index(["-n"]) end' |
        tee -a /dev/stderr)
    [ "${actual}" == 'null' ]

    local actual=$(echo "$object" |
        yq -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
            .args' |
        tee -a /dev/stderr)
    [ "${actual}" == 'null' ]

    local actual=$(echo "$object" |
        yq -r '
            (.spec.template.spec.containers[]?, .spec.template.spec.initContainers[]?) |
            .env[]? | select(.name == "VARNISH_WORKDIR" or .name == "OTEL_VARNISH_WORKDIR") |
            .name' |
        tee -a /dev/stderr)
    [ "${actual}" == '' ]
}

@test "${kind}/extraListens: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .command' |
            jq -r -c '. as $cmd | indices("-a")[1]' |
            tee -a /dev/stderr)

    [ "${actual}" == "null" ]
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
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-a", "proxy=:8088,PROXY"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'proxy=:8088,PROXY' ]

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-a", "proxy-sock=/tmp/varnish-proxy.sock,user=www,group=www,mode=0700,PROXY"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'proxy-sock=/tmp/varnish-proxy.sock,user=www,group=www,mode=0700,PROXY' ]
}

@test "${kind}/extraListens: port can be configured partially" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraListens[0].name=althttp' \
        --set 'server.extraListens[0].port=8888' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-a", "althttp=:8888"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'althttp=:8888' ]
}

@test "${kind}/extraListens: path can be configured partially" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraListens[0].name=althttp' \
        --set 'server.extraListens[0].path=/tmp/varnish.sock' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-a", "althttp=/tmp/varnish.sock"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'althttp=/tmp/varnish.sock' ]
}

@test "${kind}/extraEnvs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraEnvs.FOO=bar' \
        --set 'server.extraEnvs.BAZ=bax' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .env[]? | select(.name == "RELEASE_NAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAME","value":"release-name"}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .env[]? | select(.name == "FROM_CONFIGMAP")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_CONFIGMAP","valueFrom":{"configMapKeyRef":{"key":"my-key","name":"my-configmap"}}}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-p", "thread_pool_min=50"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'thread_pool_min=50' ]

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-p", "thread_pool_max=1000"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'thread_pool_max=1000' ]
}

@test "${kind}/settings: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.minThreads=300' \
        --set 'server.maxThreads=5000' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-p", "thread_pool_min=300"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'thread_pool_min=300' ]

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-p", "thread_pool_max=5000"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'thread_pool_max=5000' ]
}

@test "${kind}/command: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set-json 'server.command=["/bin/sh", "-c", "exec varnishd -F"]' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") | .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/bin/sh","-c","exec varnishd -F"]' ]
}

@test "${kind}/command: null uses the default command" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.command=null' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") | .command[0]' |
            tee -a /dev/stderr)
    [ "${actual}" == "/usr/sbin/varnishd" ]
}

@test "${kind}/extraArgs: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .command' |
            jq -r -c '. as $cmd | indices("-a") | length' |
            tee -a /dev/stderr)
    [ "${actual}" == "1" ]
}

@test "${kind}/extraArgs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraArgs[0]=-p' \
        --set 'server.extraArgs[1]=feature=+http2' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-p", "feature=+http2"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'feature=+http2' ]
}

@test "${kind}/extraArgs: can be configured as string" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraArgs=-p feature=+http2' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-p", "feature=+http2"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'feature=+http2' ]
}

@test "${kind}/extraArgs: list items are passed as single string arguments" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set-json 'server.extraArgs=["-t", 600, "-p", true, "-p", "cc_command=exec cc -fpic -shared -o %o %s"]' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") | .command[-6:]' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-t","600","-p","true","-p","cc_command=exec cc -fpic -shared -o %o %s"]' ]
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
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-p", "feature=+http2"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'feature=+http2' ]

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-a", "proxy=:8088,PROXY"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'proxy=:8088,PROXY' ]
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
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-p", "feature=+http2"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'feature=+http2' ]

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-a", "proxy=:8088,PROXY"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'proxy=:8088,PROXY' ]
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
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-p", "feature=+http2,+validate_headers"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'feature=+http2,+validate_headers' ]

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-p", "backend_idle_timeout=60"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'backend_idle_timeout=60' ]
}

@test "${kind}/extraContainers: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.extraContainers[0].name=varnish-hello' \
        --set 'server.extraContainers[0].image=alpine:latest' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.volumes[]? | select(.name == "release-name-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"name":"release-name-data","hostPath":{"path":"/data/varnish","type":"directory"}}' ]
}

@test "${kind}/vcl: use the bundled vcl by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-vcl"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.spec.volumes[]? | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","emptyDir":{"medium":"Memory"}}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '' ]

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-f", "/etc/varnish/default.vcl"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == '/etc/varnish/default.vcl' ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.volumeMounts[] | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","mountPath":"/etc/varnish/shared"}' ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-vcl"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'e71c17a8bb11a3944b9029906deac70c7f3643ceec87cb1e8a304b7b8c92138d' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.spec.volumes[]? | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","emptyDir":{"medium":"Memory"}}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.spec.volumes[]? | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","configMap":{"name":"release-name-'"${chart}"'-vcl"}}' ]

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-f", "/etc/varnish/default.vcl"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == '/etc/varnish/default.vcl' ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.volumeMounts[] | select(.name == "release-name-config-shared")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-shared","mountPath":"/etc/varnish/shared"}' ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-vcl","mountPath":"/etc/varnish/default.vcl","subPath":"default.vcl"}' ]
}

@test "${kind}/vcl: extraVolumeMounts can add VCL files" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.extraVolumes[0].name=varnish-vcl-tenant1" \
        --set "server.extraVolumes[0].configMap.name=varnish-vcl-tenant1" \
        --set "server.extraVolumeMounts[0].name=varnish-vcl-tenant1" \
        --set "server.extraVolumeMounts[0].mountPath=/etc/varnish/tenant1.vcl" \
        --set "server.extraVolumeMounts[0].subpath=tenant1.vcl" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.spec.volumes[]? | select(.name == "varnish-vcl-tenant1")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"configMap":{"name":"varnish-vcl-tenant1"},"name":"varnish-vcl-tenant1"}' ]

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index("-f") + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == '/etc/varnish/default.vcl' ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.volumeMounts[] | select(.name == "varnish-vcl-tenant1")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"mountPath":"/etc/varnish/tenant1.vcl","name":"varnish-vcl-tenant1","subpath":"tenant1.vcl"}' ]
}

@test "${kind}/cmdfile: no -I without agent or routes" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        . || render_failed) |
        yq -r 'select(.kind == "ConfigMap") | .metadata.name' |
            tee -a /dev/stderr)
    [[ "${actual}" != *-cmdfile* ]]

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[] | select(.name == "'"${chart}"'") | .command' |
            tee -a /dev/stderr)
    [ -n "${actual}" ]
    [[ "${actual}" != *'"-I"'* ]]
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
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.image' |
            tee -a /dev/stderr)
    [ "${actual}" == "docker-repo.local/varnish-software/varnish-plus:latest" ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.imagePullPolicy' |
            tee -a /dev/stderr)
    [ "${actual}" == "Always" ]
}

@test "${kind}/startupProbe: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/resources: secret init container inherits server resources" {
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.initContainers[]? | select(.name == "'"${chart}"'-secret") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/resources: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == '{"tier":"edge"}' ]
}

@test "${kind}/nodeSelector: can be as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.nodeSelector=tier: {{ .Release.Name }}-edge' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == '{"tier":"release-name-edge"}' ]
}

@test "${kind}/nodeSelector: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec.tolerations' | tee -a /dev/stderr)

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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == '[{"key":"ban-release-name","operator":"Exists","effect":"NoSchedule"}]' ]
}

@test "${kind}/tolerations: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "${kind}/topologySpreadConstraints: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.topologySpreadConstraints[0].maxSkew=1' \
        --set 'server.topologySpreadConstraints[0].topologyKey=topology.kubernetes.io/zone' \
        --set 'server.topologySpreadConstraints[0].whenUnsatisfiable=DoNotSchedule' \
        --set 'server.topologySpreadConstraints[0].labelSelector.matchLabels.tier=edge' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec.topologySpreadConstraints' | tee -a /dev/stderr)

    [ "${actual}" == '[{"labelSelector":{"matchLabels":{"tier":"edge"}},"maxSkew":1,"topologyKey":"topology.kubernetes.io/zone","whenUnsatisfiable":"DoNotSchedule"}]' ]
}

@test "${kind}/topologySpreadConstraints: selects the release's pods by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.topologySpreadConstraints[0].maxSkew=1' \
        --set 'server.topologySpreadConstraints[0].topologyKey=topology.kubernetes.io/zone' \
        --set 'server.topologySpreadConstraints[0].whenUnsatisfiable=DoNotSchedule' \
        --set 'server.topologySpreadConstraints[1].maxSkew=2' \
        --set 'server.topologySpreadConstraints[1].topologyKey=kubernetes.io/hostname' \
        --set 'server.topologySpreadConstraints[1].whenUnsatisfiable=ScheduleAnyway' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '[.spec.template.spec.topologySpreadConstraints[].labelSelector]' | tee -a /dev/stderr)

    [ "${actual}" == '[{"matchLabels":{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"'"${chart}"'"}},{"matchLabels":{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"'"${chart}"'"}}]' ]
}

@test "${kind}/topologySpreadConstraints: defaults a null labelSelector to the release's pods" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set-json 'server.topologySpreadConstraints=[{"maxSkew":1,"topologyKey":"topology.kubernetes.io/zone","whenUnsatisfiable":"DoNotSchedule","labelSelector":null}]' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '[.spec.template.spec.topologySpreadConstraints[].labelSelector]' | tee -a /dev/stderr)

    [ "${actual}" == '[{"matchLabels":{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"'"${chart}"'"}}]' ]
}

@test "${kind}/topologySpreadConstraints: can be configured as templated string" {
    cd "$(chart_dir)"

    local topologySpreadConstraints='
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      tier: {{ .Release.Name }}-edge
- maxSkew: 1
  topologyKey: kubernetes.io/hostname
  whenUnsatisfiable: ScheduleAnyway
'

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.topologySpreadConstraints=${topologySpreadConstraints}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec.topologySpreadConstraints' | tee -a /dev/stderr)

    [ "${actual}" == '[{"labelSelector":{"matchLabels":{"tier":"release-name-edge"}},"maxSkew":1,"topologyKey":"topology.kubernetes.io/zone","whenUnsatisfiable":"DoNotSchedule"},{"labelSelector":{"matchLabels":{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"'"${chart}"'"}},"maxSkew":1,"topologyKey":"kubernetes.io/hostname","whenUnsatisfiable":"ScheduleAnyway"}]' ]
}

@test "${kind}/topologySpreadConstraints: not configured when the templated string renders empty" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set-json 'server.topologySpreadConstraints="{{- if .Values.server.hostNetwork }}- maxSkew: 1{{- end }}"' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec | has("topologySpreadConstraints")' | tee -a /dev/stderr)

    [ "${actual}" == 'false' ]
}

@test "${kind}/topologySpreadConstraints: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec.topologySpreadConstraints' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "${kind}/topologySpreadConstraints: fails on a templated string that is not valid YAML" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.topologySpreadConstraints=- maxSkew: [' \
        --namespace default \
        --show-only ${template} \
        . || true) 2>&1 |
        tee -a /dev/stderr)

    [[ "${actual}" == *"'server.topologySpreadConstraints' entries must be objects, got: error converting YAML to JSON"* ]]
}

@test "${kind}/topologySpreadConstraints: fails on a map instead of a list" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set-json 'server.topologySpreadConstraints={"maxSkew":1}' \
        --skip-schema-validation \
        --namespace default \
        --show-only ${template} \
        . || true) 2>&1 |
        tee -a /dev/stderr)

    [[ "${actual}" == *"'server.topologySpreadConstraints' must be a list"* ]]
}

@test "${kind}/topologySpreadConstraints: fails on a null entry" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set-json 'server.topologySpreadConstraints=[null]' \
        --skip-schema-validation \
        --namespace default \
        --show-only ${template} \
        . || true) 2>&1 |
        tee -a /dev/stderr)

    [[ "${actual}" == *"'server.topologySpreadConstraints' entries must be objects, got: <nil>"* ]]
}

@test "${kind}/affinity: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchLabels.foo=bar' \
        --set 'server.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey=kubernetes.io/hostname' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec.affinity' | tee -a /dev/stderr)

    [ "${actual}" == '{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"foo":"bar"}},"topologyKey":"kubernetes.io/hostname"}]}}' ]
}

@test "${kind}/affinity: can be configured as templated string" {
    cd "$(chart_dir)"

    local affinity='
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels:
          app.kubernetes.io/name: {{ include "'"${chart}"'.name" . }}
          app.kubernetes.io/instance: {{ .Release.Name }}
      topologyKey: kubernetes.io/hostname
'

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.affinity=${affinity}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.template.spec.affinity' | tee -a /dev/stderr)

    [ "${actual}" == '{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"app.kubernetes.io/name":"'"${chart}"'","app.kubernetes.io/instance":"release-name"}},"topologyKey":"kubernetes.io/hostname"}]}}' ]
}

@test "${kind}/mse4/config: disabled by default" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local container=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        yq -o=json -I=0 '.spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
        tee -a /dev/stderr)

    [ "$(echo "$container" | jq -c '.command | index("-s")')" == "null" ]
    [ "$(echo "$container" | jq -c '[.env[]? | select(.name == "VARNISH_STORAGE_BACKEND" or .name == "MSE4_CONFIG")]')" == "[]" ]
}

@test "${kind}/mse4/config: can be enabled" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.mse4.enabled=true' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
             .command' |
            jq -r -c '.[ index("-s") + 1 ] | split(",")[0]' |
            tee -a /dev/stderr)

    [ "${actual}" == "mse4" ]
}

@test "${kind}/mse4/memoryTarget: can be configured" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.mse4.enabled=true' \
        --set 'server.mse4.memoryTarget=80%' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .command[] | select(match("memory_target")) | split("=")[1]' |
            tee -a /dev/stderr)

    [ "${actual}" == "80%" ]
}

@test "${kind}/mse4/memoryTarget: not configured by default" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.mse4.enabled=true' \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .command[] | select(match("memory_target")) | split("=")[1]' |
            tee -a /dev/stderr)

    [ "${actual}" == "" ]
}

@test "${kind}/mse4/config: can be configured" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local mse4Config='
env: {
  books = ( {
    id = "book";
    filename = "/var/lib/mse4/book";
    size = "1G";
    stores = ( {
      id = "store";
      filename = "/var/lib/mse4/store";
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-mse4"' |
            tee -a /dev/stderr)
    [ "${actual}" = '4b7c702a1f2833fe90663595430b607bed979cacf9d523adb8ce2180f06f4102' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.spec.volumes[]? | select(.name == "release-name-config-mse4")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-mse4","configMap":{"name":"release-name-'"${chart}"'-mse4"}}' ]

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[ index("-s") + 1 ] | split(",")[1]' |
            tee -a /dev/stderr)
    [ "${actual}" == "/etc/varnish/mse4.conf" ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.volumeMounts[] | select(.name == "release-name-config-mse4")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-mse4","mountPath":"/etc/varnish/mse4.conf","subPath":"mse4.conf"}' ]
}

@test "${kind}/mse4/config: not configured by default" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.mse4.enabled=true' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-mse4"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.spec.volumes[]? | select(.name == "release-name-config-mse4")' |
            tee -a /dev/stderr)
    [ "${actual}" = '' ]

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[ index("-s") + 1 ] | split(",")[1]' |
            tee -a /dev/stderr)
    [ "${actual}" == "null" ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.volumeMounts[] | select(.name == "release-name-config-mse4")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]
}

@test "${kind}/delayedShutdown: not enabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | yq -r -o=json -I=0 '.lifecycle' | tee -a /dev/stderr)
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
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | yq -r -o=json -I=0 '.lifecycle' | tee -a /dev/stderr)
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
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | yq -r -o=json -I=0 '.lifecycle' | tee -a /dev/stderr)
    [[ "${actual}" == *"MEMPOOL.sess"* ]]
    [[ "${actual}" == *"sleep 5"* ]]
    [[ "${actual}" == *"sleep 30"* ]]

    # varnishstat finds varnishd's default working directory without -n
    local actual=$(echo "$container" | yq -r '.lifecycle.preStop.exec.command[2]' | tee -a /dev/stderr)
    [[ "${actual}" == *'varnishstat -1'* ]]
}

@test "${kind}/delayedShutdown: can be enabled with shutdown_delay" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.delayedShutdown.method=shutdown_delay" \
        --set "server.delayedShutdown.shutdownDelay.seconds=120" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | yq -r -o=json -I=0 '.lifecycle' | tee -a /dev/stderr)
    [ "${actual}" = "null" ]

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-p", "shutdown_close=off"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'shutdown_close=off' ]

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-p", "shutdown_delay=120"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == 'shutdown_delay=120' ]
}

@test "${kind}/terminationGracePeriodSeconds: not enabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.terminationGracePeriodSeconds' |
            tee -a /dev/stderr)
    [ "${actual}" == "120" ]
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.terminationGracePeriodSeconds' |
            tee -a /dev/stderr)
    [ "${actual}" == "180" ]
}

@test "${kind}/terminationGracePeriodSeconds: do nothing with delayedShutdown shutdown_delay seconds" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.terminationGracePeriodSeconds=180" \
        --set "server.delayedShutdown.method=mempool" \
        --set "server.delayedShutdown.shutdownDelay.seconds=1" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
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
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? |
            select(.name == "'"${chart}"'-agent")' | tee -a /dev/stderr)
    [ "${actual}" == "" ]
}

@test "${kind}/agent: can be enabled" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_AGENT_NAME") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"fieldRef":{"fieldPath":"metadata.name"}}' ]

    local actual=$(echo "$container" |
        yq -o=json -I=0 '.command' |
            jq -r -c '.[index(["-I", "/var/lib/varnish-controller/varnish-controller-agent/$(VARNISH_CONTROLLER_AGENT_NAME)/cmds.cli"]) + 1]' |
            tee -a /dev/stderr)
    [ "${actual}" == '/var/lib/varnish-controller/varnish-controller-agent/$(VARNISH_CONTROLLER_AGENT_NAME)/cmds.cli' ]

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" | tee -a /dev/stderr |
            yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_AGENT_NAME") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"fieldRef":{"fieldPath":"metadata.name"}}' ]
}

@test "${kind}/agent: can be enabled with custom http port" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.http.enabled=true' \
        --set 'server.http.port=8090' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_VARNISH_HOST") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"fieldRef":{"fieldPath":"status.podIP"}}' ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_VARNISH_PORT") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == "8090" ]
}

@test "${kind}/agent: cannot be enabled when http port is disabled" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    run helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.http.enabled=false' \
        --set 'server.service.enabled=false' \
        --set 'server.livenessProbe=' \
        --set 'server.readinessProbe=' \
        --namespace default \
        --show-only ${template} \
        .
    echo "${output}" >&2
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"HTTP support must be enabled to enable Varnish Controller Agent"* ]]
}

@test "${kind}/agent: uses the pod secret" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent")' |
        tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r '.env[]? | select(.name == "VARNISH_CONTROLLER_VARNISH_SECRET") | .value' |
        tee -a /dev/stderr)
    [ "${actual}" == '/etc/varnish/shared/secret' ]

    local actual=$(echo "$container" |
        yq -r '.env[]? | select(.name == "VARNISH_CONTROLLER_VARNISH_ADMIN_HOST") | .value' |
        tee -a /dev/stderr)
    [ "${actual}" == '127.0.0.1' ]

    local actual=$(echo "$container" |
        yq -r '.env[]? | select(.name == "VARNISH_CONTROLLER_VARNISH_ADMIN_PORT") | .value' |
        tee -a /dev/stderr)
    [ "${actual}" == '6082' ]

    local actual=$(echo "$container" |
        yq -r '.env[]? | select(.name == "VARNISH_CONTROLLER_VARNISH_NAME") | .name' |
        tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$container" |
        yq -r '.volumeMounts[] | select(.mountPath == "/etc/varnish/shared") | .name' |
        tee -a /dev/stderr)
    [ "${actual}" == 'release-name-config-shared' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '[.spec.template.spec.initContainers[].name]' |
        tee -a /dev/stderr)
    [ "${actual}" == '["'"${chart}"'-secret"]' ]
}

@test "${kind}/agent: inherits securityContext from global and agent" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'global.securityContext.hello=world' \
        --set 'server.securityContext.ignore-this=yes' \
        --set 'server.agent.securityContext.runAsUser=1001' \
        --set 'server.agent.securityContext.foo=baz' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"foo":"baz","hello":"world","runAsNonRoot":true,"runAsUser":1001}' ]
}

@test "${kind}/agent: inherits securityContext from global and agent with global as a templated string" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "global.securityContext=${securityContext}" \
        --set 'server.securityContext.ignore-this=yes' \
        --set 'server.agent.securityContext.runAsUser=1001' \
        --set 'server.agent.securityContext.foo=baz' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .securityContext' | tee -a /dev/stderr)

    [ "${actual}" == '{"foo":"baz","release-name":"release-name","release-namespace":"default","runAsUser":1001}' ]
}

@test "${kind}/agent: inherits securityContext from global and agent with agent as a templated string" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'global.securityContext.hello=world' \
        --set 'server.securityContext.ignore-this=yes' \
        --set "server.agent.securityContext=${securityContext}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"hello":"world","release-name":"release-name","release-namespace":"default","runAsNonRoot":true,"runAsUser":'"${default_uid}"'}' ]
}

@test "${kind}/agent: inherits securityContext from global and agent with both as a templated string" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: to-be-override
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "global.securityContext=${securityContext}" \
        --set 'server.securityContext.ignore-this=yes' \
        --set 'server.agent.securityContext=release-namespace: {{ .Release.Namespace }}' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"release-name":"release-name","release-namespace":"default"}' ]
}

@test "${kind}/agent: inherits nats configuration from global" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '$(VARNISH_CONTROLLER_NATS_USER):$(VARNISH_CONTROLLER_NATS_PASS)@$(VARNISH_CONTROLLER_NATS_HOST)' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"varnish-controller-credentials","key":"nats-varnish-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller-nats.default.svc.cluster.local:4222' ]
}

@test "${kind}/agent: inherits nats configuration from global with overridden values" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'global.natsServer.internal.namespace=varnish-controller' \
        --set 'global.natsServer.internal.releaseName=test' \
        --set 'global.natsServer.internal.clusterDomain=remote.local' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '$(VARNISH_CONTROLLER_NATS_USER):$(VARNISH_CONTROLLER_NATS_PASS)@$(VARNISH_CONTROLLER_NATS_HOST)' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"varnish-controller-credentials","key":"nats-varnish-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'test-nats.varnish-controller.svc.remote.local:4222' ]
}

@test "${kind}/agent: inherits nats configuration from global with external secret" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'global.natsServer.internal.namespace=varnish-controller' \
        --set 'global.natsServer.internal.releaseName=test' \
        --set 'global.natsServer.internal.clusterDomain=remote.local' \
        --set 'global.natsServer.internal.passwordFrom.name=external-secret' \
        --set 'global.natsServer.internal.passwordFrom.key=nats-password' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '$(VARNISH_CONTROLLER_NATS_USER):$(VARNISH_CONTROLLER_NATS_PASS)@$(VARNISH_CONTROLLER_NATS_HOST)' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"external-secret","key":"nats-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'test-nats.varnish-controller.svc.remote.local:4222' ]
}

@test "${kind}/agent: inherits nats configuration from global with external nats" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'global.natsServer.externalAddress=nats.local:4222' \
        --set 'global.natsServer.internal.enabled=false' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'nats.local:4222' ]
}

@test "${kind}/agent: cannot disable both external and internal nats" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    run helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'global.natsServer.externalAddress=' \
        --set 'global.natsServer.internal.enabled=false' \
        --namespace default \
        --show-only ${template} \
        .
    echo "${output}" >&2
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"Either 'global.natsServer.internal.enabled' or 'global.natsServer.externalAddress' must be set"* ]]
}

@test "${kind}/agent: leaves log level, tags, location and private token to the agent defaults" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            [.spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_LOG" or .name == "VARNISH_CONTROLLER_TAGS" or
                .name == "VARNISH_CONTROLLER_LATITUDE" or .name == "VARNISH_CONTROLLER_LONGITUDE" or
                .name == "VARNISH_CONTROLLER_PRIVATE_TOKEN")]' |
            tee -a /dev/stderr)
    [ "${actual}" == '[]' ]
}

@test "${kind}/agent/extraEnvs: can set the private token from a secret" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local values="${BATS_TEST_TMPDIR}/values.yaml"
    cat > "${values}" <<'EOT'
server:
  agent:
    enabled: true
    extraEnvs:
      - name: VARNISH_CONTROLLER_PRIVATE_TOKEN
        valueFrom:
          secretKeyRef:
            name: agent-token
            key: token
EOT

    local object=$((helm template \
        --set "server.kind=${kind}" \
        -f "${values}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_PRIVATE_TOKEN")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_PRIVATE_TOKEN","valueFrom":{"secretKeyRef":{"key":"token","name":"agent-token"}}}' ]
}

@test "${kind}/agent/extraEnvs: can be configured" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.agent.extraEnvs.FOO=bar' \
        --set 'server.agent.extraEnvs.BAZ=bax' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "${kind}/agent/extraEnvs: can be configured as a templated string" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local extraEnvs="
- name: RELEASE_NAME
  value: {{ .Release.Name }}
- name: RELEASE_NAMESPACE
  value: {{ .Release.Namespace }}"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.extraEnvs=${extraEnvs}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "RELEASE_NAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAME","value":"release-name"}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "RELEASE_NAMESPACE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAMESPACE","value":"default"}' ]
}

@test "${kind}/agent/extraEnvs: can be configured as a list" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.agent.extraEnvs[0].name=FOO' \
        --set 'server.agent.extraEnvs[0].value=bar' \
        --set 'server.agent.extraEnvs[1].name=BAZ' \
        --set 'server.agent.extraEnvs[1].value=bax' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "${kind}/agent/extraEnvs: can be configured as a list of non-value literalFrom" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.agent.extraEnvs[0].name=FROM_CONFIGMAP' \
        --set 'server.agent.extraEnvs[0].valueFrom.configMapKeyRef.name=my-configmap' \
        --set 'server.agent.extraEnvs[0].valueFrom.configMapKeyRef.key=my-key' \
        --set 'server.agent.extraEnvs[1].name=FROM_SECRET' \
        --set 'server.agent.extraEnvs[1].valueFrom.secretKeyRef.name=my-secret' \
        --set 'server.agent.extraEnvs[1].valueFrom.secretKeyRef.key=my-key' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "FROM_CONFIGMAP")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_CONFIGMAP","valueFrom":{"configMapKeyRef":{"key":"my-key","name":"my-configmap"}}}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .env[]? | select(.name == "FROM_SECRET")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_SECRET","valueFrom":{"secretKeyRef":{"key":"my-key","name":"my-secret"}}}' ]
}

@test "${kind}/agent/resources: inherits resources from global and agent" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'global.resources.limits.cpu=100m' \
        --set 'global.resources.requests.cpu=100m' \
        --set 'server.resources.ignore-this=yes' \
        --set 'server.agent.resources.limits.cpu=500m' \
        --set 'server.agent.resources.limits.memory=512Mi' \
        --set 'server.agent.resources.requests.memory=128Mi' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/agent/resources: inherits resources from global and agent with global as a templated string" {
    skip_unless_enterprise
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
        --set 'global.resources.limits.cpu=100m' \
        --set 'global.resources.requests.cpu=100m' \
        --set 'server.resources.ignore-this=yes' \
        --set "server.agent.resources=${resources}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/agent/resources: inherits resources from global and agent with server as a templated string" {
    skip_unless_enterprise
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
        --set "global.resources=${resources}" \
        --set 'server.resources.ignore-this=yes' \
        --set 'server.agent.resources.limits.cpu=500m' \
        --set 'server.agent.resources.limits.memory=512Mi' \
        --set 'server.agent.resources.requests.memory=128Mi' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/agent/resources: inherits resources from global and agent with both as a templated string" {
    skip_unless_enterprise
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
        --set "global.resources=${globalResources}" \
        --set 'server.resources.ignore-this=yes' \
        --set "server.agent.resources=${resources}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/agent/resources: not configured by default" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "${kind}/agent/persistence: not configured by default" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .volumeMounts[]? | select(.name == "release-name-varnish-controller")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-varnish-controller","mountPath":"/var/lib/varnish-controller"}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.volumes[]? | select(.name == "release-name-varnish-controller")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-varnish-controller","emptyDir":{}}' ]
}

@test "${kind}/agent/vcl: use the bundled vcl by default" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" = '' ]
}

@test "${kind}/agent/vcl: included with controller agent" {
    skip_unless_enterprise
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
        --set "server.vclConfig=${vclConfig}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.volumeMounts[] | select(.name == "release-name-config-vcl")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-config-vcl","mountPath":"/etc/varnish/default.vcl","subPath":"default.vcl"}' ]
}

@test "${kind}/agent/vcl: includes are mounted in the agent container" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local container=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.vclConfig=vcl 4.1; include "./vcls/helpers.vcl"; backend default none;' \
        --set-string 'server.vcls.includes.helpers\.vcl=sub x {}' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r '.volumeMounts[] | select(.name | test("config-vcl")) | .mountPath + ":" + .subPath' |
            tee -a /dev/stderr)
    [ "${actual}" == "/etc/varnish/default.vcl:default.vcl
/etc/varnish/vcls/helpers.vcl:helpers.vcl" ]
}

@test "${kind}/agent/extraArgs: not configured by default" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/usr/bin/varnish-controller-agent"]' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .args' |
            tee -a /dev/stderr)
    [ "${actual}" == 'null' ]
}

@test "${kind}/agent/extraArgs: can be configured" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.extraArgs[0]=-help" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/usr/bin/varnish-controller-agent"]' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .args' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-help"]' ]
}

@test "${kind}/agent/extraVolumeMounts: can be configured" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set 'server.agent.extraVolumeMounts[0].name=varnish-data' \
        --set 'server.agent.extraVolumeMounts[0].mountPath=/var/data' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .volumeMounts[]? | select(.name == "varnish-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"mountPath":"/var/data","name":"varnish-data"}' ]
}

@test "${kind}/agent/extraVolumeMounts: can be configured as templated string" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local extraVolumeMounts="
- name: {{ .Release.Name }}-data
  mountPath: /var/data"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.extraVolumeMounts=${extraVolumeMounts}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-agent") |
            .volumeMounts[]? | select(.name == "release-name-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"name":"release-name-data","mountPath":"/var/data"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be enabled with agent" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? |
            select(.name == "'"${chart}"'-vcli")' | tee -a /dev/stderr |
            yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "${kind}/agent/autoRemove/vcli: ignored if agent is not enabled" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.autoRemove.method=vcli" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? |
            select(.name == "'"${chart}"'-vcli")' | tee -a /dev/stderr)
    [ "${actual}" = "" ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured with username and password" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.username=guest" \
        --set "server.agent.autoRemove.vcli.password=passw0rd" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_USERNAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_USERNAME","value":"guest"}' ]

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_PASSWORD")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_PASSWORD","value":"passw0rd"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured with passwordFrom" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.passwordFrom.name=my-secret" \
        --set "server.agent.autoRemove.vcli.passwordFrom.key=password-key" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_PASSWORD")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_PASSWORD","valueFrom":{"secretKeyRef":{"name":"my-secret","key":"password-key"}}}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured to skip certificate verification" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.insecure=true" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_INSECURE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_INSECURE","value":"true"}' ]
}

@test "${kind}/agent/autoRemove/vcli: configured to use internal varnish-controller by default" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"http://varnish-controller-apigw.default.svc.cluster.local:8080"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured to use internal controller in a different namespace" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "global.natsServer.internal.namespace=other-namespace" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"http://varnish-controller-apigw.other-namespace.svc.cluster.local:8080"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured to use internal controller with a different release name" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "global.natsServer.internal.releaseName=vc" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"http://vc-apigw.default.svc.cluster.local:8080"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured to use internal controller with a different cluster domain" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "global.natsServer.internal.clusterDomain=remote.local" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"http://varnish-controller-apigw.default.svc.remote.local:8080"}' ]
}

@test "${kind}/agent/autoRemove/vcli: sets the agent name from the Pod name" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_AGENT_NAME") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"fieldRef":{"fieldPath":"metadata.name"}}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured to use internal controller with a different port" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.internal.port=8888" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"http://varnish-controller-apigw.default.svc.cluster.local:8888"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured to use internal controller on port 80" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.internal.port=80" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"http://varnish-controller-apigw.default.svc.cluster.local"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured to use internal controller with https on port 443" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.internal.https=true" \
        --set "server.agent.autoRemove.vcli.internal.port=443" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"https://varnish-controller-apigw.default.svc.cluster.local"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured to use internal controller with https on non-port 443" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.internal.https=true" \
        --set "server.agent.autoRemove.vcli.internal.port=4444" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"https://varnish-controller-apigw.default.svc.cluster.local:4444"}' ]
}

@test "${kind}/agent/autoRemove/vcli: can be configured with external controller" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.externalAddress=https://varnish-controller.example.com" \
        --set "server.agent.autoRemove.vcli.internal.enabled=false" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.env[]? | select(.name == "VARNISH_CONTROLLER_CLI_ENDPOINT")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_CLI_ENDPOINT","value":"https://varnish-controller.example.com"}' ]
}

@test "${kind}/agent/autoRemove/vcli: configured with autoRemoveAgent by default" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.agent.enabled=true" \
        --set "server.agent.autoRemove.method=vcli" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli")' |
            tee -a /dev/stderr)

    # Note: the script is actually tested in E2E
    local actual=$(echo "$container" |
        yq -r -o=json -I=0 '.lifecycle.preStop.exec.command[0]' |
            tee -a /dev/stderr)
    [ "${actual}" == '/bin/sh' ]
}

@test "${kind}/agent/autoRemove/vcli/extraEnvs: can be configured" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.autoRemove.method=vcli" \
        --set 'server.agent.autoRemove.vcli.extraEnvs.FOO=bar' \
        --set 'server.agent.autoRemove.vcli.extraEnvs.BAZ=bax' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "${kind}/agent/autoRemove/vcli/extraEnvs: can be configured as a templated string" {
    skip_unless_enterprise
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
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli") |
            .env[]? | select(.name == "RELEASE_NAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAME","value":"release-name"}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli") |
            .env[]? | select(.name == "RELEASE_NAMESPACE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAMESPACE","value":"default"}' ]
}

@test "${kind}/agent/autoRemove/vcli/extraEnvs: can be configured as a list" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.autoRemove.method=vcli" \
        --set 'server.agent.autoRemove.vcli.extraEnvs[0].name=FOO' \
        --set 'server.agent.autoRemove.vcli.extraEnvs[0].value=bar' \
        --set 'server.agent.autoRemove.vcli.extraEnvs[1].name=BAZ' \
        --set 'server.agent.autoRemove.vcli.extraEnvs[1].value=bax' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "${kind}/agent/autoRemove/extraEnvs: can be configured as a list of non-value literalFrom" {
    skip_unless_enterprise
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
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli") |
            .env[]? | select(.name == "FROM_CONFIGMAP")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_CONFIGMAP","valueFrom":{"configMapKeyRef":{"key":"my-key","name":"my-configmap"}}}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli") |
            .env[]? | select(.name == "FROM_SECRET")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_SECRET","valueFrom":{"secretKeyRef":{"key":"my-key","name":"my-secret"}}}' ]
}

@test "${kind}/agent/autoRemove/vcli/resources: can be configured" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.autoRemove.method=vcli" \
        --set 'server.agent.autoRemove.vcli.resources.limits.cpu=500m' \
        --set 'server.agent.autoRemove.vcli.resources.limits.memory=512Mi' \
        --set 'server.agent.autoRemove.vcli.resources.requests.cpu=100m' \
        --set 'server.agent.autoRemove.vcli.resources.requests.memory=128Mi' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/agent/autoRemove/vcli/resources: not configured by default" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.autoRemove.method=vcli" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "${kind}/agent/autoRemove/vcli/extraVolumeMounts: can be configured" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.autoRemove.method=vcli" \
        --set 'server.agent.autoRemove.vcli.extraVolumeMounts[0].name=varnish-data' \
        --set 'server.agent.autoRemove.vcli.extraVolumeMounts[0].mountPath=/var/data' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli") |
            .volumeMounts[]? | select(.name == "varnish-data")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"mountPath":"/var/data","name":"varnish-data"}' ]
}

@test "${kind}/agent/autoRemove/vcli/extraVolumeMounts: can be configured as templated string" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local extraVolumeMounts="
- name: {{ .Release.Name }}-data
  mountPath: /var/data"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.agent.enabled=true' \
        --set "server.agent.autoRemove.method=vcli" \
        --set "server.agent.autoRemove.vcli.extraVolumeMounts=${extraVolumeMounts}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-vcli") |
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa")' |
            tee -a /dev/stderr)

    [ "${actual}" == "" ]
}

@test "${kind}/varnishncsa: inherits securityContext from global" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'global.securityContext.hello=world' \
        --set 'server.securityContext.ignore-this=yes' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"hello":"world","runAsNonRoot":true,"runAsUser":'"${default_uid}"'}' ]
}

@test "${kind}/varnishncsa: inherits securityContext from global as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.enabled=true' \
        --set "global.securityContext=${securityContext}" \
        --set 'server.securityContext.ignore-this=yes' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
            .securityContext' | tee -a /dev/stderr)

    [ "${actual}" == '{"release-name":"release-name","release-namespace":"default"}' ]
}

@test "${kind}/varnishncsa/extraArgs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.extraArgs[0]=--help' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
            .args' |
            jq -r -c 'index(["--help"])' |
            tee -a /dev/stderr)

    [ "${actual}" != "null" ]
}

@test "${kind}/varnishncsa/extraArgs: list items are passed as single string arguments" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set-json 'server.varnishncsa.extraArgs=["-F", "%h %r", "-t", 3]' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") | .args' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-F","%h %r","-t","3"]' ]
}

@test "${kind}/varnishncsa/extraArgs: can be configured as string" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.extraArgs=--help' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
            .args' |
            jq -r -c 'index(["--help"])' |
            tee -a /dev/stderr)

    [ "${actual}" != 'null' ]
}

@test "${kind}/varnishncsa: no -n" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set-json 'server.varnishncsa.extraArgs=[]' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa")' |
            tee -a /dev/stderr)
    [ -n "${container}" ]

    local actual=$(echo "$container" | yq -o=json -I=0 '.args' | tee -a /dev/stderr)
    [ "${actual}" == 'null' ]
}

@test "${kind}/varnishncsa/image: uses server.image" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.image.repository=localhost/${chart}" \
        --set "server.image.tag=latest" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
            .image' |
            tee -a /dev/stderr)

    [ "${actual}" == "localhost/${chart}:latest" ]
}

@test "${kind}/varnishncsa: has no probes" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
            [has("startupProbe"), has("readinessProbe"), has("livenessProbe")]' |
            tee -a /dev/stderr)

    [ "${actual}" == '[false,false,false]' ]
}

@test "${kind}/varnishncsa/image: numeric tag 0 is kept when the schema is skipped" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.image.repository=localhost/${chart}" \
        --skip-schema-validation \
        --set "server.image.tag=0" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .image' |
            tee -a /dev/stderr)

    [ "${actual}" == "localhost/${chart}:0" ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
            .image' |
            tee -a /dev/stderr)

    [ "${actual}" == "localhost/${chart}:0" ]
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
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "${kind}/varnishncsa/resources: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) | tee -a /dev/stderr |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrole"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrolebinding"' |
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrole"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'b341e3a03d6bb568e16c2ccbfdc281924ad1a771b73fd2c4198a54a6ce568ebe' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrolebinding"' |
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
        -f "$BATS_RUN_TMPDIR"/values-"$BATS_TEST_NUMBER".yaml \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrole"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'null' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrolebinding"' |
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
        -f "$BATS_RUN_TMPDIR"/values-"$BATS_TEST_NUMBER".yaml \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrole"' |
            tee -a /dev/stderr)
    [ "${actual}" = 'dd5731f8b37e11291ee9d37e4efdae991f3b58c4f863d75b3faac538a4df6ab3' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrolebinding"' |
            tee -a /dev/stderr)
    [ "${actual}" = '52e43eed97374991f0ca4fd84283acbbf54134898bb5b36c4dc70a03ce595805' ]
}

@test "${kind}/licenseSecret: creates a license volume and volumeMounts" {
    skip_unless_enterprise
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.licenseSecret=test-value' \
        --set "server.kind=${kind}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.template.spec.volumes[]? | select(.name == "varnish-license-volume")' |
        tee -a /dev/stderr)

    [ "${actual}" == '{"name":"varnish-license-volume","secret":{"secretName":"test-value"}}' ]

    local actual=$(echo "$object" |
        yq -r '
        .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
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
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r '
            .spec.template.spec.volumes[]? | select(.name == "varnish-license-volume")' |
        tee -a /dev/stderr)

    [ -z "${actual}" ]

    local actual=$(echo "$object" |
        yq -r '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'") |
            .volumeMounts[]? | select(.name == "varnish-license-volume")' |
        tee -a /dev/stderr)

    [ -z "${actual}" ]
}

@test "${kind}/extraEnvs: can be configured for varnishncsa" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.extraEnvs.FOO=bar' \
        --set 'server.varnishncsa.extraEnvs.BAZ=bax' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "${kind}/extraEnvs: can be configured for varnishncsa as a templated string" {
    cd "$(chart_dir)"

    local extraEnvs="
- name: RELEASE_NAME
  value: {{ .Release.Name }}
- name: RELEASE_NAMESPACE
  value: {{ .Release.Namespace }}"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set "server.varnishncsa.extraEnvs=${extraEnvs}" \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
            .env[]? | select(.name == "RELEASE_NAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAME","value":"release-name"}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
            .env[]? | select(.name == "RELEASE_NAMESPACE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAMESPACE","value":"default"}' ]
}

@test "${kind}/extraEnvs: can be configured for varnishncsa as a list" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=${kind}" \
        --set 'server.varnishncsa.extraEnvs[0].name=FOO' \
        --set 'server.varnishncsa.extraEnvs[0].value=bar' \
        --set 'server.varnishncsa.extraEnvs[1].name=FROM_SECRET' \
        --set 'server.varnishncsa.extraEnvs[1].valueFrom.secretKeyRef.name=my-secret' \
        --set 'server.varnishncsa.extraEnvs[1].valueFrom.secretKeyRef.key=my-key' \
        --namespace default \
        --show-only ${template} \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '
            .spec.template.spec.containers[]? | select(.name == "'"${chart}"'-ncsa") |
            .env[]? | select(.name == "FROM_SECRET")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_SECRET","valueFrom":{"secretKeyRef":{"key":"my-key","name":"my-secret"}}}' ]
}
