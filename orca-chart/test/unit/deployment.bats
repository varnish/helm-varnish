#!/usr/bin/env bats

load _helpers

@test "Deployment: enabled by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | yq -r 'length > 0')
    [ "${actual}" = "true" ]
}

@test "Deployment: not rendered when kind=StatefulSet" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | yq -r 'length > 0')
    [ "${actual}" = "false" ]
}

@test "Deployment: replicas defaults to replicaCount" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set replicaCount=3 \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yq -r '.spec.replicas')
    [ "${actual}" = "3" ]
}

@test "Deployment: replicas omitted when autoscaling enabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set replicaCount=3 \
        --set autoscaling.enabled=true \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yq -r '.spec.replicas')
    [ "${actual}" = "null" ]
}

@test "Deployment: selector matches selectorLabels" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yqj '.spec.selector.matchLabels')
    [ "${actual}" = '{"app.kubernetes.io/name":"orca-chart","app.kubernetes.io/instance":"release-name"}' ]
}

@test "Deployment: name follows fullname" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yq -r '.metadata.name')
    [ "${actual}" = "release-name-orca-chart" ]
}
