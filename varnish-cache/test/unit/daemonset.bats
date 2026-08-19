#!/usr/bin/env bats

load _helpers

@test "DaemonSet: disabled by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --show-only templates/daemonset.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "false" ]
}

@test "DaemonSet: can be enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=DaemonSet' \
        --namespace default \
        --show-only templates/daemonset.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "DaemonSet/strategy: cannot be enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=DaemonSet' \
        --set 'server.strategy.type=RollingUpdate' \
        --set 'server.strategy.rollingUpdate.maxUnavailable=1' \
        --namespace default \
        --show-only templates/daemonset.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)

    [[ "${actual}" == *"'server.strategy' cannot be enabled"* ]]
}

@test "DaemonSet/updateStrategy: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=DaemonSet' \
        --set 'server.updateStrategy=' \
        --namespace default \
        --show-only templates/daemonset.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.updateStrategy' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "DaemonSet/updateStrategy: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=DaemonSet' \
        --set 'server.updateStrategy.type=RollingUpdate' \
        --set 'server.updateStrategy.rollingUpdate.maxUnavailable=1' \
        --namespace default \
        --show-only templates/daemonset.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.updateStrategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"rollingUpdate":{"maxUnavailable":1},"type":"RollingUpdate"}' ]
}

@test "DaemonSet/updateStrategy: can be configured as templated string" {
    cd "$(chart_dir)"

    local updateStrategy='
type: RollingUpdate
rollingUpdate:
  maxUnavailable: {{ 1 }}
'

    local actual=$((helm template \
        --set 'server.kind=DaemonSet' \
        --set "server.updateStrategy=$updateStrategy" \
        --namespace default \
        --show-only templates/daemonset.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -o=json -I=0 '.spec.updateStrategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":1}}' ]
}

@test "DaemonSet/extraVolumeClaimTemplates: cannot be enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=DaemonSet' \
        --set "server.extraVolumeClaimTemplates[0].metadata.name=hello-pv" \
        --set "server.extraVolumeClaimTemplates[0].spec.accessModes[0]=ReadWriteOnce" \
        --set "server.extraVolumeClaimTemplates[0].spec.resources.requests.storage=10Gi" \
        --namespace default \
        --show-only templates/daemonset.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)

    [[ "${actual}" == *"'server.extraVolumeClaimTemplates' cannot be enabled"* ]]
}