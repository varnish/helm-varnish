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
        yq -r -c '.spec.updateStrategy' | tee -a /dev/stderr)

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
        yq -r -c '.spec.updateStrategy' | tee -a /dev/stderr)

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
        yq -r -c '.spec.updateStrategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":1}}' ]
}

@test "StatefulSet/mse/persistence: disabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.kind=StatefulSet' \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.volumeClaimTemplates[]? | select(.metadata.name == "release-name-mse")' |
            tee -a /dev/stderr)
    [ "${actual}" = "" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-mse")' |
            tee -a /dev/stderr)
    [ "${actual}" = "" ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .volumeMounts[] | select(.name == "release-name-mse")' |
            tee -a /dev/stderr)
    [ "${actual}" = "" ]
}

@test "StatefulSet/mse/persistence: can be enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.mse.persistence.enabled=true' \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.volumeClaimTemplates[]? | select(.metadata.name == "release-name-mse") |
            .spec' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"10Gi"}}}' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-mse")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-mse","configMap":{"name":"release-name-varnish-enterprise-mse"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .volumeMounts[] | select(.name == "release-name-mse")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-mse","mountPath":"/var/lib/mse"}' ]
}

@test "StatefulSet/mse/persistence: can be enabled with custom values" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.mse.persistence.enabled=true' \
        --set 'server.mse.persistence.mountPath=/data1/mse' \
        --set 'server.mse.persistence.storageSize=100G' \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.volumeClaimTemplates[]? | select(.metadata.name == "release-name-mse") |
            .spec' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"100G"}}}' ]

    local containerObject=$(echo "$object" |
        yq -r '.spec.template.spec.containers[] | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$containerObject" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-mse")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-mse","mountPath":"/data1/mse"}' ]
}

@test "StatefulSet/mse4/persistence: disabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.mse4.enabled=true' \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.volumeClaimTemplates[]? | select(.metadata.name == "release-name-mse4")' |
            tee -a /dev/stderr)
    [ "${actual}" = "" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-mse4")' |
            tee -a /dev/stderr)
    [ "${actual}" = "" ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .volumeMounts[] | select(.name == "release-name-mse4")' |
            tee -a /dev/stderr)
    [ "${actual}" = "" ]
}

@test "StatefulSet/mse4/persistence: can be enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.mse4.enabled=true' \
        --set 'server.mse4.persistence.enabled=true' \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.volumeClaimTemplates[]? | select(.metadata.name == "release-name-mse4") |
            .spec' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"10Gi"}}}' ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.spec.volumes[]? | select(.name == "release-name-config-mse4")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-config-mse4","configMap":{"name":"release-name-varnish-enterprise-mse4"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise") |
            .volumeMounts[] | select(.name == "release-name-mse4")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-mse4","mountPath":"/var/lib/mse4"}' ]
}

@test "StatefulSet/mse4/persistence: can be enabled with custom values" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.mse4.enabled=true' \
        --set 'server.mse4.persistence.enabled=true' \
        --set 'server.mse4.persistence.mountPath=/data1/mse4' \
        --set 'server.mse4.persistence.storageSize=100G' \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.volumeClaimTemplates[]? | select(.metadata.name == "release-name-mse4") |
            .spec' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"100G"}}}' ]

    local containerObject=$(echo "$object" |
        yq -r '.spec.template.spec.containers[] | select(.name == "varnish-enterprise")' |
            tee -a /dev/stderr)

    local actual=$(echo "$containerObject" |
        yq -r -c '.volumeMounts[] | select(.name == "release-name-mse4")' |
            tee -a /dev/stderr)
    [ "${actual}" = '{"name":"release-name-mse4","mountPath":"/data1/mse4"}' ]
}

@test "StatefulSet/agent/persistence: can be enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=StatefulSet" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'server.agent.persistence.enabled=true' \
        --set 'server.agent.persistence.storageSize=1G' \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .volumeMounts[]? | select(.name == "release-name-varnish-controller")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"release-name-varnish-controller","mountPath":"/var/lib/varnish-controller"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.volumeClaimTemplates[]? |
            select(.metadata.name == "release-name-varnish-controller") |
            .spec' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"1G"}}}' ]
}

@test "StatefulSet/agent/persistence: can be enabled with volume name" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=StatefulSet" \
        --set 'server.agent.enabled=true' \
        --set 'server.secret=hello-varnish' \
        --set 'server.agent.persistence.enableWithVolumeName=my-varnish-controller-volume' \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "varnish-enterprise-agent") |
            .volumeMounts[]? | select(.name == "my-varnish-controller-volume")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"my-varnish-controller-volume","mountPath":"/var/lib/varnish-controller"}' ]
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
        yq -r -c '.spec.volumeClaimTemplates' | tee -a /dev/stderr)
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
        yq -r -c '.spec.volumeClaimTemplates' | tee -a /dev/stderr)
    [ "${actual}" == '[{"metadata":{"name":"hello-pv"},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"10Gi"}}}}]' ]
}

@test "StatefulSet/extraVolumeClaimTemplates: can be configured with persistency" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "server.kind=StatefulSet" \
        --set "server.agent.enabled=true" \
        --set "server.secret=hello-varnish" \
        --set "server.mse.persistence.enabled=true" \
        --set "server.agent.persistence.enabled=true" \
        --set "server.extraVolumeClaimTemplates[0].metadata.name=hello-pv" \
        --set "server.extraVolumeClaimTemplates[0].spec.accessModes[0]=ReadWriteOnce" \
        --set "server.extraVolumeClaimTemplates[0].spec.resources.requests.storage=10Gi" \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local appVersion=$(app_version)
    local actual=$(echo "$object" |
        yq -r -c '.spec.volumeClaimTemplates' | tee -a /dev/stderr)
    [ "${actual}" == '[{"metadata":{"name":"release-name-varnish-controller","labels":{"helm.sh/chart":"varnish-enterprise-0.1.0","app.kubernetes.io/name":"varnish-enterprise","app.kubernetes.io/instance":"release-name","app.kubernetes.io/version":"'${appVersion}'","app.kubernetes.io/managed-by":"Helm"}},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"512Mi"}}}},{"metadata":{"name":"release-name-mse","labels":{"helm.sh/chart":"varnish-enterprise-0.1.0","app.kubernetes.io/name":"varnish-enterprise","app.kubernetes.io/instance":"release-name","app.kubernetes.io/version":"'${appVersion}'","app.kubernetes.io/managed-by":"Helm"}},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"10Gi"}}}},{"metadata":{"name":"hello-pv"},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"10Gi"}}}}]' ]
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
        yq -r -c '.spec.volumeClaimTemplates' | tee -a /dev/stderr)
    [ "${actual}" == '[{"metadata":{"name":"release-name-pv"},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"10Gi"}}}}]' ]
}

@test "StatefulSet/extraVolumeClaimTemplates: can be configured with templated string with persistency" {
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
        --set "server.agent.enabled=true" \
        --set "server.secret=hello-varnish" \
        --set "server.mse.persistence.enabled=true" \
        --set "server.agent.persistence.enabled=true" \
        --set "server.extraVolumeClaimTemplates=${volumeClaimTemplates}" \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local appVersion=$(app_version)
    local actual=$(echo "$object" |
        yq -r -c '.spec.volumeClaimTemplates' | tee -a /dev/stderr)
    [ "${actual}" == '[{"metadata":{"name":"release-name-varnish-controller","labels":{"helm.sh/chart":"varnish-enterprise-0.1.0","app.kubernetes.io/name":"varnish-enterprise","app.kubernetes.io/instance":"release-name","app.kubernetes.io/version":"'${appVersion}'","app.kubernetes.io/managed-by":"Helm"}},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"512Mi"}}}},{"metadata":{"name":"release-name-mse","labels":{"helm.sh/chart":"varnish-enterprise-0.1.0","app.kubernetes.io/name":"varnish-enterprise","app.kubernetes.io/instance":"release-name","app.kubernetes.io/version":"'${appVersion}'","app.kubernetes.io/managed-by":"Helm"}},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"10Gi"}}}},{"metadata":{"name":"release-name-pv"},"spec":{"accessModes":["ReadWriteOnce"],"resources":{"requests":{"storage":"10Gi"}}}}]' ]
}
