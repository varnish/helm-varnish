#!/usr/bin/env bats

load _helpers

@test "Validation: invalid kind fails" {
    cd "$(chart_dir)"
    run helm template \
        --set kind=DaemonSet \
        --namespace default \
        .
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"kind must be 'Deployment' or 'StatefulSet'"* ]]
}

@test "Validation: kind=Deployment with persistent storage fails" {
    cd "$(chart_dir)"
    run helm template \
        --set kind=Deployment \
        --set orca.varnish.storage.stores[0].name=disk1 \
        --set orca.varnish.storage.stores[0].path=/var/lib/varnish-supervisor/storage/disk1 \
        --set orca.varnish.storage.stores[0].size=10G \
        --namespace default \
        .
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"persistent storage requires 'kind: StatefulSet'"* ]]
}

@test "Validation: StatefulSet with both http and https disabled fails" {
    cd "$(chart_dir)"
    run helm template \
        --set kind=StatefulSet \
        --set service.http.enabled=false \
        --namespace default \
        .
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"the headless service needs at least one port"* ]]
}

@test "Validation: StatefulSet with https only is allowed" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --set service.http.enabled=false \
        --set service.https.enabled=true \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r 'length > 0')
    [ "${actual}" = "true" ]
}

@test "Validation: StatefulSet with persistence and replicaCount > 1 is allowed" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --set replicaCount=3 \
        --set orca.varnish.storage.stores[0].name=disk1 \
        --set orca.varnish.storage.stores[0].path=/var/lib/varnish-supervisor/storage/disk1 \
        --set orca.varnish.storage.stores[0].size=10G \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.spec.replicas')
    [ "${actual}" = "3" ]
}
