#!/usr/bin/env bats

load _helpers

@test "ConfigMap: rendered" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/configmap.yaml \
        .) | yq -r 'length > 0')
    [ "${actual}" = "true" ]
}

@test "ConfigMap: name follows fullname" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/configmap.yaml \
        .) | yq -r '.metadata.name')
    [ "${actual}" = "release-name-orca-chart-orca-config" ]
}

@test "ConfigMap: license.secret stripped from rendered orca config" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set orca.license.secret=my-license \
        --namespace default \
        --show-only templates/configmap.yaml \
        .) | yq -r '.data."config.yaml"' | yq -r '.license.secret')
    [ "${actual}" = "null" ]
}

@test "ConfigMap: license.file rewritten when license.secret is set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set orca.license.secret=my-license \
        --namespace default \
        --show-only templates/configmap.yaml \
        .) | yq -r '.data."config.yaml"' | yq -r '.license.file')
    [ "${actual}" = "/etc/varnish-supervisor/license.lic" ]
}

@test "ConfigMap: TLS cert paths rewritten when secret is set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set orca.varnish.https[0].port=443 \
        --set orca.varnish.https[0].certificates[0].secret=my-tls \
        --namespace default \
        --show-only templates/configmap.yaml \
        .) | yq -r '.data."config.yaml"' | yq -o=json -I=0 '.varnish.https[0].certificates[0]')
    [ "${actual}" = '{"cert":"/etc/varnish-supervisor/cert-0-0.crt","private_key":"/etc/varnish-supervisor/cert-0-0.key"}' ]
}

@test "ConfigMap: HTTP port reaches orca config" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set orca.varnish.http[0].port=8080 \
        --namespace default \
        --show-only templates/configmap.yaml \
        .) | yq -r '.data."config.yaml"' | yq -r '.varnish.http[0].port')
    [ "${actual}" = "8080" ]
}

@test "ConfigMap: virtual_registry preserved" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/configmap.yaml \
        .) | yq -r '.data."config.yaml"' | yq -r '.virtual_registry.registries[] | select(.name == "dockerhub") | .default')
    [ "${actual}" = "true" ]
}
