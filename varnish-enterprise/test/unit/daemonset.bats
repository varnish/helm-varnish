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
        yq -r -c '.spec.updateStrategy' | tee -a /dev/stderr)

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
        yq -r -c '.spec.updateStrategy' | tee -a /dev/stderr)

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
        yq -r -c '.spec.updateStrategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":1}}' ]
}

@test "DaemonSet/mse/persistence: cannot be enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=DaemonSet' \
        --set 'server.mse.persistence.enabled=true' \
        --namespace default \
        --show-only templates/daemonset.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" == "false" ]
}

@test "DaemonSet/agent/persistence: cannot be enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set "server.kind=DaemonSet" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'server.agent.persistence.enabled=true' \
        --namespace default \
        --show-only templates/daemonset.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)

    [[ "${actual}" == *"'server.agent.persistence.enabled' cannot be enabled"* ]]
}

@test "DaemonSet/agent/persistence: can be enabled with volume name" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=DaemonSet" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'server.agent.persistence.enableWithVolumeName=my-varnish-controller-volume' \
        --namespace default \
        --show-only templates/daemonset.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .volumeMounts[]? | select(.name == "my-varnish-controller-volume")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"my-varnish-controller-volume","mountPath":"/var/lib/varnish-controller"}' ]
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