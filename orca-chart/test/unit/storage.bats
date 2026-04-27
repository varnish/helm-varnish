#!/usr/bin/env bats

load _helpers

# Common --set arguments for a single-store StatefulSet config.
default_store() {
    echo "--set kind=StatefulSet \
          --set orca.varnish.storage.stores[0].name=disk1 \
          --set orca.varnish.storage.stores[0].path=/var/lib/varnish-supervisor/storage/disk1 \
          --set orca.varnish.storage.stores[0].size=10G"
}

@test "Storage: no volumeClaimTemplates by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.spec.volumeClaimTemplates')
    [ "${actual}" = "null" ]
}

@test "Storage: vCT created per persistent store" {
    cd "$(chart_dir)"
    local actual=$((helm template $(default_store) \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.spec.volumeClaimTemplates | length')
    [ "${actual}" = "1" ]
}

@test "Storage: vCT name uses orca-storage-<store-name>" {
    cd "$(chart_dir)"
    local actual=$((helm template $(default_store) \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.spec.volumeClaimTemplates[0].metadata.name')
    [ "${actual}" = "orca-storage-disk1" ]
}

@test "Storage: container has volumeMount at store path" {
    cd "$(chart_dir)"
    local actual=$((helm template $(default_store) \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yqj '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "orca-storage-disk1")')
    [ "${actual}" = '{"name":"orca-storage-disk1","mountPath":"/var/lib/varnish-supervisor/storage/disk1"}' ]
}

@test "Storage: size 100G translates to 100Gi" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --set orca.varnish.storage.stores[0].name=disk1 \
        --set orca.varnish.storage.stores[0].path=/var/lib/varnish-supervisor/storage/disk1 \
        --set orca.varnish.storage.stores[0].size=100G \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.spec.volumeClaimTemplates[0].spec.resources.requests.storage')
    [ "${actual}" = "100Gi" ]
}

@test "Storage: size 100k translates to 100Ki" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --set orca.varnish.storage.stores[0].name=disk1 \
        --set orca.varnish.storage.stores[0].path=/var/lib/varnish-supervisor/storage/disk1 \
        --set orca.varnish.storage.stores[0].size=100k \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.spec.volumeClaimTemplates[0].spec.resources.requests.storage')
    [ "${actual}" = "100Ki" ]
}

@test "Storage: bare integer size passed through" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --set orca.varnish.storage.stores[0].name=disk1 \
        --set orca.varnish.storage.stores[0].path=/var/lib/varnish-supervisor/storage/disk1 \
        --set orca.varnish.storage.stores[0].size=1024 \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.spec.volumeClaimTemplates[0].spec.resources.requests.storage')
    [ "${actual}" = "1024" ]
}

@test "Storage: storageClassName applied" {
    cd "$(chart_dir)"
    local actual=$((helm template $(default_store) \
        --set storage.storageClassName=fast-ssd \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.spec.volumeClaimTemplates[0].spec.storageClassName')
    [ "${actual}" = "fast-ssd" ]
}

@test "Storage: storageClassName empty omits field" {
    cd "$(chart_dir)"
    local actual=$((helm template $(default_store) \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.spec.volumeClaimTemplates[0].spec.storageClassName')
    [ "${actual}" = "null" ]
}

@test "Storage: accessModes default to ReadWriteOnce" {
    cd "$(chart_dir)"
    local actual=$((helm template $(default_store) \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yqj '.spec.volumeClaimTemplates[0].spec.accessModes')
    [ "${actual}" = '["ReadWriteOnce"]' ]
}

@test "Storage: accessModes overridable" {
    cd "$(chart_dir)"
    local actual=$((helm template $(default_store) \
        --set 'storage.accessModes={ReadWriteMany}' \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yqj '.spec.volumeClaimTemplates[0].spec.accessModes')
    [ "${actual}" = '["ReadWriteMany"]' ]
}

@test "Storage: storage.labels applied to vCT" {
    cd "$(chart_dir)"
    local actual=$((helm template $(default_store) \
        --set storage.labels.tier=cache \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.spec.volumeClaimTemplates[0].metadata.labels.tier')
    [ "${actual}" = "cache" ]
}

@test "Storage: storage.annotations applied to vCT" {
    cd "$(chart_dir)"
    local actual=$((helm template $(default_store) \
        --set 'storage.annotations.backup\.io/policy=weekly' \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yq -r '.spec.volumeClaimTemplates[0].metadata.annotations."backup.io/policy"')
    [ "${actual}" = "weekly" ]
}

@test "Storage: multiple stores create multiple vCTs" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --set orca.varnish.storage.stores[0].name=disk1 \
        --set orca.varnish.storage.stores[0].path=/var/lib/varnish-supervisor/storage/disk1 \
        --set orca.varnish.storage.stores[0].size=10G \
        --set orca.varnish.storage.stores[1].name=disk2 \
        --set orca.varnish.storage.stores[1].path=/var/lib/varnish-supervisor/storage/disk2 \
        --set orca.varnish.storage.stores[1].size=20G \
        --namespace default \
        --show-only templates/statefulset.yaml \
        .) | yqj '[.spec.volumeClaimTemplates[].metadata.name]')
    [ "${actual}" = '["orca-storage-disk1","orca-storage-disk2"]' ]
}

@test "Storage: store entries reach the orca config" {
    cd "$(chart_dir)"
    local actual=$((helm template $(default_store) \
        --namespace default \
        --show-only templates/configmap.yaml \
        .) | yq -r '.data."config.yaml"' | yqj '.varnish.storage.stores[0]')
    [ "${actual}" = '{"name":"disk1","path":"/var/lib/varnish-supervisor/storage/disk1","size":"10G"}' ]
}
