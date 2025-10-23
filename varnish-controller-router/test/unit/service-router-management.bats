#!/usr/bin/env bats

load _helpers

@test "Service/router/management: disabled by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --show-only templates/service-router-management.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.name' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Service/router/management: can be enabled using inherited value" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set "router.management.enabled=true" \
        --set "router.managementService.enabled=-" \
        --show-only templates/service-router-management.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.name' | tee -a /dev/stderr)

    [ "${actual}" == "release-name-varnish-controller-router-management" ]
}

@test "Service/router/management: can be disabled using inherited value" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set "router.management.enabled=false" \
        --set "router.managementService.enabled=-" \
        --show-only templates/service-router-management.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.name' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Service/router/management: cannot be enabled using explicit value if management is enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set "router.management.enabled=false" \
        --set "router.managementService.enabled=true" \
        --show-only templates/service-router-management.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.name' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Service/router/management: can be disabled using explicit value" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set "router.management.enabled=true" \
        --set "router.managementService.enabled=false" \
        --show-only templates/service-router-management.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.name' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Service/router/management: can be enabled using explicit value" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set "router.management.enabled=true" \
        --set "router.managementService.enabled=true" \
        --show-only templates/service-router-management.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.name' | tee -a /dev/stderr)

    [ "${actual}" == "release-name-varnish-controller-router-management" ]
}

@test "Service/router/management/annotations: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "router.management.enabled=true" \
        --namespace default \
        --show-only templates/service-router-management.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.metadata.annotations' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]
}

@test "Service/router/management/annotations: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "router.management.enabled=true" \
        --set "router.managementService.annotations.hello=world" \
        --namespace default \
        --show-only templates/service-router-management.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.metadata.annotations' | tee -a /dev/stderr)
    [ "${actual}" == '{"hello":"world"}' ]
}

@test "Service/router/management/annotations: can be configured as a templated string" {
    cd "$(chart_dir)"

    local annotations='
release-name: {{ .Release.Name }}
'

    local object=$((helm template \
        --set "router.management.enabled=true" \
        --set "router.managementService.annotations=${annotations}" \
        --namespace default \
        --show-only templates/service-router-management.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.metadata.annotations' | tee -a /dev/stderr)
    [ "${actual}" == '{"release-name":"release-name"}' ]
}
