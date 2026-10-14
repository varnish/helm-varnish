#!/usr/bin/env bats

load _helpers

@test "Service: type defaults to ClusterIP" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --namespace default \
        --show-only templates/service.yaml \
        .) | yq -r '.spec.type')
    [ "${actual}" = "ClusterIP" ]
}

@test "Service: type configurable" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --set service.type=NodePort \
        --namespace default \
        --show-only templates/service.yaml \
        .) | yq -r '.spec.type')
    [ "${actual}" = "NodePort" ]
}

@test "Service: only HTTP by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --namespace default \
        --show-only templates/service.yaml \
        .) | yqj '.spec.ports')
    [ "${actual}" = '[{"port":80,"targetPort":"http","protocol":"TCP","name":"http"}]' ]
}

@test "Service: only HTTPS with TLS enabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --set broadcaster.tls.enabled=true \
        --set broadcaster.tls.secret=my-tls \
        --namespace default \
        --show-only templates/service.yaml \
        .) | yqj '.spec.ports')
    [ "${actual}" = '[{"port":443,"targetPort":"https","protocol":"TCP","name":"https"}]' ]
}

@test "Service: management port when enabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --set broadcaster.mgmt.enabled=true \
        --namespace default \
        --show-only templates/service.yaml \
        .) | yqj '.spec.ports[] | select(.name == "mgmt")')
    [ "${actual}" = '{"port":8089,"targetPort":"mgmt","protocol":"TCP","name":"mgmt"}' ]
}
