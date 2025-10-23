#!/usr/bin/env bats

load _helpers

@test "Service/router/http: enabled by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --show-only templates/service-router-http.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.name' | tee -a /dev/stderr)

    [ "${actual}" == "release-name-varnish-controller-router-http" ]
}

@test "Service/router/http: can be disabled using inherited value" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set "router.http.enabled=false" \
        --set "router.httpService.enabled=-" \
        --show-only templates/service-router-http.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.name' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Service/router/http: can be disabled using explicit value" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set "router.http.enabled=true" \
        --set "router.httpService.enabled=false" \
        --show-only templates/service-router-http.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.name' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Service/router/http/annotations: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --namespace default \
        --show-only templates/service-router-http.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.metadata.annotations' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]
}

@test "Service/router/http/annotations: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "router.httpService.annotations.hello=world" \
        --namespace default \
        --show-only templates/service-router-http.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.metadata.annotations' | tee -a /dev/stderr)
    [ "${actual}" == '{"hello":"world"}' ]
}

@test "Service/router/http/annotations: can be configured as a templated string" {
    cd "$(chart_dir)"

    local annotations='
release-name: {{ .Release.Name }}
'

    local object=$((helm template \
        --set "router.httpService.annotations=${annotations}" \
        --namespace default \
        --show-only templates/service-router-http.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.metadata.annotations' | tee -a /dev/stderr)
    [ "${actual}" == '{"release-name":"release-name"}' ]
}
