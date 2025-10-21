#!/usr/bin/env bats

load _helpers

@test "Service: headless TLS service uses server TLS port instead of non-existent server.service.tls.port (non-regression test)" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'server.service.type=ClusterIP' \
        --set 'server.service.clusterIP=None' \
        --set 'server.service.https.enabled=true' \
        --set 'server.tls.enabled=true' \
        --set 'server.tls.port=443' \
        --namespace default \
        --show-only templates/service.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.spec.ports[1].port' | tee -a /dev/stderr)
    [ "${actual}" = "443" ]
}