#!/usr/bin/env bats

load _helpers

@test "StatefulSet: not rendered by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") | yq -r 'length > 0')
    [ "${actual}" = "false" ]
}

@test "StatefulSet: rendered when kind=StatefulSet" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r 'length > 0')
    [ "${actual}" = "true" ]
}

@test "StatefulSet: replicas defaults to replicaCount" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --set replicaCount=3 \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.spec.replicas')
    [ "${actual}" = "3" ]
}

@test "StatefulSet: replicas omitted when autoscaling enabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --set replicaCount=3 \
        --set autoscaling.enabled=true \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.spec.replicas')
    [ "${actual}" = "null" ]
}

@test "StatefulSet: serviceName points at headless service" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.spec.serviceName')
    [ "${actual}" = "release-name-orca-chart-headless" ]
}

@test "StatefulSet: selector matches selectorLabels" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yqj '.spec.selector.matchLabels')
    [ "${actual}" = '{"app.kubernetes.io/name":"orca-chart","app.kubernetes.io/instance":"release-name"}' ]
}

@test "StatefulSet: name follows fullname" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.metadata.name')
    [ "${actual}" = "release-name-orca-chart" ]
}

@test "StatefulSet: no volumeClaimTemplates without stores" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.spec.volumeClaimTemplates')
    [ "${actual}" = "null" ]
}
