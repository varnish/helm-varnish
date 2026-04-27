#!/usr/bin/env bats

load _helpers

@test "Ingress: not rendered by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/ingress.yaml \
        . || echo "---") | yq -r 'length > 0')
    [ "${actual}" = "false" ]
}

@test "Ingress: rendered when enabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set ingress.enabled=true \
        --namespace default \
        --show-only templates/ingress.yaml \
        .) | yq -r 'length > 0')
    [ "${actual}" = "true" ]
}

@test "Ingress: hosts configured" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set ingress.enabled=true \
        --set ingress.hosts[0].host=example.com \
        --set ingress.hosts[0].paths[0].path=/ \
        --set ingress.hosts[0].paths[0].pathType=Prefix \
        --namespace default \
        --show-only templates/ingress.yaml \
        .) | yq -r '.spec.rules[0].host')
    [ "${actual}" = "example.com" ]
}

@test "Ingress: ingressClassName applied" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set ingress.enabled=true \
        --set ingress.className=nginx \
        --namespace default \
        --show-only templates/ingress.yaml \
        .) | yq -r '.spec.ingressClassName')
    [ "${actual}" = "nginx" ]
}

@test "Ingress: tls block included when set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set ingress.enabled=true \
        --set ingress.tls[0].secretName=my-tls \
        --set ingress.tls[0].hosts[0]=example.com \
        --namespace default \
        --show-only templates/ingress.yaml \
        .) | yq -r '.spec.tls[0].secretName')
    [ "${actual}" = "my-tls" ]
}
