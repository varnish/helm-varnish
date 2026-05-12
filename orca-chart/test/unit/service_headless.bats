#!/usr/bin/env bats

load _helpers

@test "HeadlessService: not rendered by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/service-headless.yaml \
        . || echo "---") | yq -r 'length > 0')
    [ "${actual}" = "false" ]
}

@test "HeadlessService: rendered when kind=StatefulSet" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --namespace default \
        --show-only templates/service-headless.yaml \
        .) | yq -r 'length > 0')
    [ "${actual}" = "true" ]
}

@test "HeadlessService: clusterIP=None" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --namespace default \
        --show-only templates/service-headless.yaml \
        .) | yq -r '.spec.clusterIP')
    [ "${actual}" = "None" ]
}

@test "HeadlessService: publishNotReadyAddresses=true" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --namespace default \
        --show-only templates/service-headless.yaml \
        .) | yq -r '.spec.publishNotReadyAddresses')
    [ "${actual}" = "true" ]
}

@test "HeadlessService: name is fullname-headless" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --namespace default \
        --show-only templates/service-headless.yaml \
        .) | yq -r '.metadata.name')
    [ "${actual}" = "release-name-orca-chart-headless" ]
}

@test "HeadlessService: HTTP port included" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --namespace default \
        --show-only templates/service-headless.yaml \
        .) | yq -r '[.spec.ports[].name] | contains(["http"])')
    [ "${actual}" = "true" ]
}

@test "HeadlessService: HTTPS port included when enabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --set service.https.enabled=true \
        --namespace default \
        --show-only templates/service-headless.yaml \
        .) | yq -r '[.spec.ports[].name] | contains(["https"])')
    [ "${actual}" = "true" ]
}
