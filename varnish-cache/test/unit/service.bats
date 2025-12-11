#!/usr/bin/env bats

load _helpers

@test "Service/externalTrafficPolicy: defaults to Cluster" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --namespace default \
        --show-only templates/service.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.externalTrafficPolicy' |
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
        yq -r -c '.spec.externalTrafficPolicy' |
        tee -a /dev/stderr)

    [ "${actual}" == "Local" ]
}
