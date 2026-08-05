#!/usr/bin/env bats

load _helpers

@test "Service: headless TLS service uses server TLS port instead of non-existent server.service.tls.port (non-regression test)" {
    cd "$(chart_dir)"
    run helm template \
        --set 'server.service.type=ClusterIP' \
        --set 'server.service.clusterIP=None' \
        --set 'server.service.https.enabled=true' \
        --set 'server.tls.enabled=true' \
        --set 'server.tls.port=443' \
        --namespace default \
        --show-only templates/service.yaml \
        .
    echo "$output"

    [ "${status}" == 0 ]

    local port=$( echo "$output" |  yq -r '.spec.ports[1].port' )

    echo Port: $port
    [ "${port}" == "443" ]
}

@test "Service/externalTrafficPolicy: defaults to Cluster" {
    cd "$(chart_dir)"

    run helm template \
        --namespace default \
        --show-only templates/service.yaml \
        .
    echo "$output"

    [ "${status}" == 0 ]

    local actual=$(echo "$output" |
        yq -r -c '.spec.externalTrafficPolicy' |
        tee -a /dev/stderr)

    [ "${actual}" == "Cluster" ]
}

@test "Service/externalTrafficPolicy: can be changed by user, for example Local" {
    cd "$(chart_dir)"

    run helm template \
        --set 'server.service.externalTrafficPolicy=Local' \
        --namespace default \
        --show-only templates/service.yaml \
        .
    echo "$output"
    
    [ "${status}" == 0 ]

    local actual=$(echo "$output" |
        yq -r -c '.spec.externalTrafficPolicy' |
        tee -a /dev/stderr)

    [ "${actual}" == "Local" ]
}
