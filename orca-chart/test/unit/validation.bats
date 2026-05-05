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

@test "Validation: store size > book_size + 1G is allowed (default book_size)" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --set orca.varnish.storage.stores[0].name=disk1 \
        --set orca.varnish.storage.stores[0].path=/var/lib/varnish-supervisor/storage/disk1 \
        --set orca.varnish.storage.stores[0].size=7G \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r 'length > 0')
    [ "${actual}" = "true" ]
}

@test "Validation: store size <= book_size + 1G fails (default book_size)" {
    cd "$(chart_dir)"
    run helm template \
        --set kind=StatefulSet \
        --set orca.varnish.storage.stores[0].name=disk1 \
        --set orca.varnish.storage.stores[0].path=/var/lib/varnish-supervisor/storage/disk1 \
        --set orca.varnish.storage.stores[0].size=6G \
        --namespace default \
        .
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"must be greater than book_size + 1G"* ]]
}

@test "Validation: store size at the boundary fails (5G + 1G == 6G)" {
    cd "$(chart_dir)"
    run helm template \
        --set kind=StatefulSet \
        --set orca.varnish.storage.stores[0].name=disk1 \
        --set orca.varnish.storage.stores[0].path=/var/lib/varnish-supervisor/storage/disk1 \
        --set orca.varnish.storage.stores[0].size=5G \
        --namespace default \
        .
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"must be greater than book_size + 1G"* ]]
}

@test "Validation: custom book_size respected (size 4G with book_size 2G allowed)" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --set orca.varnish.storage.stores[0].name=disk1 \
        --set orca.varnish.storage.stores[0].path=/var/lib/varnish-supervisor/storage/disk1 \
        --set orca.varnish.storage.stores[0].size=4G \
        --set orca.varnish.storage.stores[0].book_size=2G \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r 'length > 0')
    [ "${actual}" = "true" ]
}

@test "Validation: custom book_size respected (size 3G with book_size 2G fails)" {
    cd "$(chart_dir)"
    run helm template \
        --set kind=StatefulSet \
        --set orca.varnish.storage.stores[0].name=disk1 \
        --set orca.varnish.storage.stores[0].path=/var/lib/varnish-supervisor/storage/disk1 \
        --set orca.varnish.storage.stores[0].size=3G \
        --set orca.varnish.storage.stores[0].book_size=2G \
        --namespace default \
        .
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"must be greater than book_size + 1G"* ]]
}

@test "Validation: lowercase units accepted in size check" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --set orca.varnish.storage.stores[0].name=disk1 \
        --set orca.varnish.storage.stores[0].path=/var/lib/varnish-supervisor/storage/disk1 \
        --set orca.varnish.storage.stores[0].size=10g \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r 'length > 0')
    [ "${actual}" = "true" ]
}

@test "Validation: T-scale store size accepted" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --set orca.varnish.storage.stores[0].name=disk1 \
        --set orca.varnish.storage.stores[0].path=/var/lib/varnish-supervisor/storage/disk1 \
        --set orca.varnish.storage.stores[0].size=1T \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r 'length > 0')
    [ "${actual}" = "true" ]
}

@test "Validation: error names the offending store" {
    cd "$(chart_dir)"
    run helm template \
        --set kind=StatefulSet \
        --set orca.varnish.storage.stores[0].name=disk1 \
        --set orca.varnish.storage.stores[0].path=/var/lib/varnish-supervisor/storage/disk1 \
        --set orca.varnish.storage.stores[0].size=10G \
        --set orca.varnish.storage.stores[1].name=tiny \
        --set orca.varnish.storage.stores[1].path=/var/lib/varnish-supervisor/storage/tiny \
        --set orca.varnish.storage.stores[1].size=2G \
        --namespace default \
        .
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"\"tiny\""* ]]
}
