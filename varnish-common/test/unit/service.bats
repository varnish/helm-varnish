#!/usr/bin/env bats

load _helpers

@test "Service: headless TLS service uses server TLS port instead of non-existent server.service.tls.port (non-regression test)" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'server.service.type=ClusterIP' \
        --set 'server.service.clusterIP=None' \
        --set 'server.tls.enabled=true' \
        --set 'server.tls.port=443' \
        --namespace default \
        --show-only templates/service.yaml \
        . || render_failed) | tee -a /dev/stderr |
        yq -r '.spec.ports[1].port' | tee -a /dev/stderr)
    [ "${actual}" = "443" ]
}

@test "Service: https port present when server.tls.enabled=true" {
    cd "$(chart_dir)"
    local object=$((helm template \
        --set 'server.tls.enabled=true' \
        --set 'server.tls.config=frontend = {}' \
        --set 'server.tls.port=6443' \
        --namespace default \
        --show-only templates/service.yaml \
        . || render_failed) | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.ports[] | select(.name == "https") | [.port, .targetPort]' |
        tee -a /dev/stderr)
    [ "${actual}" == "[443,6443]" ]
}

@test "Service: https port absent when server.tls.enabled=false" {
    cd "$(chart_dir)"
    local object=$((helm template \
        --namespace default \
        --show-only templates/service.yaml \
        . || render_failed) | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '[.spec.ports[].name]' |
        tee -a /dev/stderr)
    [ "${actual}" == '["http"]' ]
}

@test "Service: http port absent when server.http.enabled=false" {
    cd "$(chart_dir)"
    local object=$((helm template \
        --set 'server.http.enabled=false' \
        --set 'server.startupProbe=' \
        --set 'server.readinessProbe=' \
        --set 'server.livenessProbe=' \
        --set 'server.tls.enabled=true' \
        --set 'server.tls.config=frontend = {}' \
        --namespace default \
        --show-only templates/service.yaml \
        . || render_failed) | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '[.spec.ports[].name]' |
        tee -a /dev/stderr)
    [ "${actual}" == '["https"]' ]
}

@test "Service/externalTrafficPolicy: defaults to Cluster" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --namespace default \
        --show-only templates/service.yaml \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.externalTrafficPolicy' |
        tee -a /dev/stderr)

    [ "${actual}" == "Cluster" ]
}

@test "Service/externalTrafficPolicy: can be changed by user, for example Local" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.service.externalTrafficPolicy=Local' \
        --namespace default \
        --show-only templates/service.yaml \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.externalTrafficPolicy' |
        tee -a /dev/stderr)

    [ "${actual}" == "Local" ]
}

@test "Service/internalTrafficPolicy: follows the values default" {
    cd "$(chart_dir)"
    local expected=$(yq -r '.server.service.internalTrafficPolicy' < values.yaml)

    local object=$((helm template \
        --namespace default \
        --show-only templates/service.yaml \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.internalTrafficPolicy // ""' |
        tee -a /dev/stderr)

    [ "${actual}" == "${expected}" ]
}

@test "Service/internalTrafficPolicy: can be changed by user, for example Local" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.service.internalTrafficPolicy=Local' \
        --namespace default \
        --show-only templates/service.yaml \
        . || render_failed) |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.internalTrafficPolicy' |
        tee -a /dev/stderr)

    [ "${actual}" == "Local" ]
}

@test "Service: fails when neither HTTP nor TLS is enabled" {
    cd "$(chart_dir)"
    run helm template \
        --set 'server.http.enabled=false' \
        --set 'server.tls.enabled=false' \
        --set 'server.livenessProbe=null' \
        --set 'server.readinessProbe=null' \
        --namespace default \
        --show-only templates/service.yaml \
        .
    echo "${output}" >&2
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"The Service needs a port: enable 'server.http.enabled' or 'server.tls.enabled', or disable 'server.service.enabled'"* ]]
}
