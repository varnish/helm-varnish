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

@test "Service/externalTrafficPolicy: defaults to Cluster" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --namespace default \
        --show-only templates/service.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.externalTrafficPolicy' |
        tee -a /dev/stderr)

    [ "${actual}" == "Cluster" ]
}

@test "Service/externalTrafficPolicy: can be changed by user, for example Local" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.service.externalTrafficPolicy=Local' \
        --namespace default \
        --show-only templates/service.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.externalTrafficPolicy' |
        tee -a /dev/stderr)

    [ "${actual}" == "Local" ]
}
