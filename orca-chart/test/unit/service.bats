#!/usr/bin/env bats

load _helpers

@test "Service: enabled by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/service.yaml \
        . || echo "---") | yq -r 'length > 0')
    [ "${actual}" = "true" ]
}

@test "Service: type defaults to ClusterIP" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/service.yaml \
        .) | yq -r '.spec.type')
    [ "${actual}" = "ClusterIP" ]
}

@test "Service: type configurable" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set service.type=NodePort \
        --namespace default \
        --show-only templates/service.yaml \
        .) | yq -r '.spec.type')
    [ "${actual}" = "NodePort" ]
}

@test "Service: HTTP port renders" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/service.yaml \
        .) | yq -o=json -I=0 '.spec.ports[] | select(.name == "http")')
    [ "${actual}" = '{"port":80,"targetPort":"http","protocol":"TCP","name":"http"}' ]
}

@test "Service: HTTP port configurable" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set service.http.port=8080 \
        --namespace default \
        --show-only templates/service.yaml \
        .) | yq -r '.spec.ports[] | select(.name == "http") | .port')
    [ "${actual}" = "8080" ]
}

@test "Service: HTTPS not in default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/service.yaml \
        .) | yq -r '[.spec.ports[].name] | contains(["https"])')
    [ "${actual}" = "false" ]
}

@test "Service: HTTPS renders when enabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set service.https.enabled=true \
        --namespace default \
        --show-only templates/service.yaml \
        .) | yq -o=json -I=0 '.spec.ports[] | select(.name == "https")')
    [ "${actual}" = '{"port":443,"targetPort":"https","protocol":"TCP","name":"https"}' ]
}

@test "Service: NodePort honored when type=NodePort" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set service.type=NodePort \
        --set service.http.nodePort=30080 \
        --namespace default \
        --show-only templates/service.yaml \
        .) | yq -r '.spec.ports[] | select(.name == "http") | .nodePort')
    [ "${actual}" = "30080" ]
}

@test "Service: selector matches selectorLabels" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/service.yaml \
        .) | yq -o=json -I=0 '.spec.selector')
    [ "${actual}" = '{"app.kubernetes.io/name":"orca-chart","app.kubernetes.io/instance":"release-name"}' ]
}
