#!/usr/bin/env bats

load _helpers

@test "Deployment: enabled by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "Deployment: can be disabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'server.kind=DaemonSet' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "false" ]
}

@test "Deployment/strategy: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=Deployment' \
        --set 'server.strategy=' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Deployment/strategy: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=Deployment' \
        --set 'server.strategy.type=RollingUpdate' \
        --set 'server.strategy.rollingUpdate.maxUnavailable=1' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"rollingUpdate":{"maxUnavailable":1},"type":"RollingUpdate"}' ]
}

@test "Deployment/strategy: can be configured as templated string" {
    cd "$(chart_dir)"

    local strategy='
type: RollingUpdate
rollingUpdate:
  maxUnavailable: {{ 1 }}
'

    local actual=$((helm template \
        --set 'server.kind=Deployment' \
        --set "server.strategy=$strategy" \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":1}}' ]
}

@test "Deployment/updateStrategy: cannot be enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=Deployment' \
        --set 'server.updateStrategy.type=RollingUpdate' \
        --set 'server.updateStrategy.rollingUpdate.maxUnavailable=1' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)

    [[ "${actual}" == *"'server.updateStrategy' cannot be enabled"* ]]
}

@test "Deployment/extraVolumeClaimTemplates: cannot be enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=Deployment' \
        --set "server.extraVolumeClaimTemplates[0].metadata.name=hello-pv" \
        --set "server.extraVolumeClaimTemplates[0].spec.accessModes[0]=ReadWriteOnce" \
        --set "server.extraVolumeClaimTemplates[0].spec.resources.requests.storage=10Gi" \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)

    [[ "${actual}" == *"'server.extraVolumeClaimTemplates' cannot be enabled"* ]]
}