#!/usr/bin/env bats

load _helpers

@test "StatefulSet: disabled by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "false" ]
}

@test "StatefulSet: can be enabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'server.kind=StatefulSet' \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "StatefulSet/strategy: cannot be enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.strategy.type=RollingUpdate' \
        --set 'server.strategy.rollingUpdate.maxUnavailable=1' \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)

    [[ "${actual}" == *"'server.strategy' cannot be enabled"* ]]
}

@test "StatefulSet/updateStrategy: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.updateStrategy=' \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.updateStrategy' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "StatefulSet/updateStrategy: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.updateStrategy.type=RollingUpdate' \
        --set 'server.updateStrategy.rollingUpdate.maxUnavailable=1' \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.updateStrategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"rollingUpdate":{"maxUnavailable":1},"type":"RollingUpdate"}' ]
}

@test "StatefulSet/updateStrategy: can be configured as templated string" {
    cd "$(chart_dir)"

    local updateStrategy='
type: RollingUpdate
rollingUpdate:
  maxUnavailable: {{ 1 }}
'

    local actual=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set "server.updateStrategy=$updateStrategy" \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.updateStrategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":1}}' ]
}

@test "StatefulSet/extraVolumeClaimTemplates: disabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=StatefulSet" \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.volumeClaimTemplates' | tee -a /dev/stderr)
    [ "${actual}" == 'null' ]
}

@test "StatefulSet/extraVolumeClaimTemplates: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=StatefulSet" \
        --set "server.extraVolumeClaimTemplates[0].metadata.name=hello-pv" \
        --set "server.extraVolumeClaimTemplates[0].spec.accessModes[0]=ReadWriteOnce" \
        --set "server.extraVolumeClaimTemplates[0].spec.resources.requests.storage=10Gi" \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.volumeClaimTemplates' | tee -a /dev/stderr)
    [ "${actual}" == '[{"metadata":{"name":"hello-pv"},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"10Gi"}}}}]' ]
}

@test "StatefulSet/extraVolumeClaimTemplates: can be configured with templated string" {
    cd "$(chart_dir)"

    local volumeClaimTemplates='
- metadata:
    name: {{ .Release.Name }}-pv
  spec:
    accessModes: ["ReadWriteOnce"]
    resources:
      requests:
        storage: "10Gi"
'

    local object=$((helm template \
        --set "server.kind=StatefulSet" \
        --set "server.extraVolumeClaimTemplates=${volumeClaimTemplates}" \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.volumeClaimTemplates' | tee -a /dev/stderr)
    [ "${actual}" == '[{"metadata":{"name":"release-name-pv"},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"10Gi"}}}}]' ]
}
