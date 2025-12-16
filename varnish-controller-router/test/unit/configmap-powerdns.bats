#!/usr/bin/env bats

load _helpers

@test "ConfigMap/powerdns/config: can be set" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.config.someSetting=test' \
        --show-only templates/configmap-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.data["pdns.conf"]' | tee -a /dev/stderr)

    [[ "${actual}" == *"some-setting=test"* ]]
}

@test "ConfigMap/powerdns/config: serialize boolean as yes and no" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.config.booleanThing=true' \
        --set 'powerdns.config.anotherBooleanThing=false' \
        --show-only templates/configmap-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.data["pdns.conf"]' | tee -a /dev/stderr)

    [[ "${actual}" == *"boolean-thing=yes"* ]]
    [[ "${actual}" == *"another-boolean-thing=no"* ]]
}

@test "ConfigMap/powerdns/config: set launch" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.config.launch=gsqlite3' \
        --show-only templates/configmap-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.data["pdns.conf"]' | tee -a /dev/stderr)

    [[ "${actual}" == *"launch=gsqlite3"* ]]
}

@test "ConfigMap/powerdns/config: set launch if overridden" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.config.launch=' \
        --show-only templates/configmap-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.data["pdns.conf"]' | tee -a /dev/stderr)

    [[ "${actual}" == *"launch=remote"* ]]
}

@test "ConfigMap/powerdns/config: set remote connection string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.config.remoteConnectionString=' \
        --show-only templates/configmap-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.data["pdns.conf"]' | tee -a /dev/stderr)

    [[ "${actual}" == *"remote-connection-string=http:url=http://release-name-varnish-controller-router-dns-backend.default.svc.cluster.local:8091,post_json=1,post=1"* ]]
}

@test "ConfigMap/powerdns/config: set remote connection string and omit port if port is 80" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set 'router.dnsService.port=80' \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.config.remoteConnectionString=' \
        --show-only templates/configmap-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.data["pdns.conf"]' | tee -a /dev/stderr)

    [[ "${actual}" == *"remote-connection-string=http:url=http://release-name-varnish-controller-router-dns-backend.default.svc.cluster.local,post_json=1,post=1"* ]]
}

@test "ConfigMap/powerdns/config: set remote connection string if tls is enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set 'router.dns.tls=true' \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.config.remoteConnectionString=' \
        --show-only templates/configmap-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.data["pdns.conf"]' | tee -a /dev/stderr)

    [[ "${actual}" == *"remote-connection-string=http:url=https://release-name-varnish-controller-router-dns-backend.default.svc.cluster.local:8091,post_json=1,post=1"* ]]
}

@test "ConfigMap/powerdns/config: set remote connection string and omit port if tls is enabled and port is 443" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set 'router.dns.tls=true' \
        --set 'router.dnsService.port=443' \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.config.remoteConnectionString=' \
        --show-only templates/configmap-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.data["pdns.conf"]' | tee -a /dev/stderr)

    [[ "${actual}" == *"remote-connection-string=http:url=https://release-name-varnish-controller-router-dns-backend.default.svc.cluster.local,post_json=1,post=1"* ]]
}
