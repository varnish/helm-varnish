#!/usr/bin/env bats

load _helpers

@test "Service/router/dns: disabled by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --show-only templates/service-router-dns-backend.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.name' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Service/router/dns: can be enabled using inherited value" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set "router.dns.enabled=true" \
        --set "router.dnsService.enabled=-" \
        --show-only templates/service-router-dns-backend.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.name' | tee -a /dev/stderr)

    [ "${actual}" == "release-name-varnish-controller-router-dns-backend" ]
}

@test "Service/router/dns: can be disabled using inherited value" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set "router.dns.enabled=false" \
        --set "router.dnsService.enabled=-" \
        --show-only templates/service-router-dns-backend.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.name' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Service/router/dns: cannot be enabled using explicit value if dns is enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set "router.dns.enabled=false" \
        --set "router.dnsService.enabled=true" \
        --show-only templates/service-router-dns-backend.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.name' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Service/router/dns: can be disabled using explicit value" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set "router.dns.enabled=true" \
        --set "router.dnsService.enabled=false" \
        --show-only templates/service-router-dns-backend.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.name' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Service/router/dns: can be enabled using explicit value" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set "router.dns.enabled=true" \
        --set "router.dnsService.enabled=true" \
        --show-only templates/service-router-dns-backend.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.name' | tee -a /dev/stderr)

    [ "${actual}" == "release-name-varnish-controller-router-dns-backend" ]
}

@test "Service/router/dns/annotations: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "router.dns.enabled=true" \
        --namespace default \
        --show-only templates/service-router-dns-backend.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.metadata.annotations' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]
}

@test "Service/router/dns/annotations: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "router.dns.enabled=true" \
        --set "router.dnsService.annotations.hello=world" \
        --namespace default \
        --show-only templates/service-router-dns-backend.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.metadata.annotations' | tee -a /dev/stderr)
    [ "${actual}" == '{"hello":"world"}' ]
}

@test "Service/router/dns/annotations: can be configured as a templated string" {
    cd "$(chart_dir)"

    local annotations='
release-name: {{ .Release.Name }}
'

    local object=$((helm template \
        --set "router.dns.enabled=true" \
        --set "router.dnsService.annotations=${annotations}" \
        --namespace default \
        --show-only templates/service-router-dns-backend.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.metadata.annotations' | tee -a /dev/stderr)
    [ "${actual}" == '{"release-name":"release-name"}' ]
}
