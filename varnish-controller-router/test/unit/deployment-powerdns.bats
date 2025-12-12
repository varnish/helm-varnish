#!/usr/bin/env bats

load _helpers

@test "Deployment/powerdns: disabled by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.containers[]? | select(.name == "powerdns")' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]
}

@test "Deployment/powerdns: can be enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set 'powerdns.enabled=true' \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.containers[]? | select(.name == "powerdns")' |
            tee -a /dev/stderr)
    [ "${actual}" != "" ]
}

@test "Deployment/powerdns: inherits securityContext from global and powerdns" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'global.securityContext.hello=world' \
        --set 'powerdns.securityContext.runAsUser=1000' \
        --set 'powerdns.securityContext.foo=bar' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"foo":"bar","hello":"world","runAsNonRoot":true,"runAsUser":1000}' ]
}

@test "Deployment/powerdns: inherits securityContext from global and powerdns with global as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set "global.securityContext=${securityContext}" \
        --set 'powerdns.securityContext.runAsUser=1000' \
        --set 'powerdns.securityContext.foo=bar' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .securityContext' | tee -a /dev/stderr)

    [ "${actual}" == '{"foo":"bar","release-name":"release-name","release-namespace":"default","runAsUser":1000}' ]
}

@test "Deployment/powerdns: inherits securityContext from global and powerdns with powerdns as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'global.securityContext.hello=world' \
        --set "powerdns.securityContext=${securityContext}" \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"hello":"world","release-name":"release-name","release-namespace":"default","runAsNonRoot":true,"runAsUser":999}' ]
}

@test "Deployment/powerdns: inherits securityContext from global and powerdns with both as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: to-be-override
"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set "global.securityContext=${securityContext}" \
        --set 'powerdns.securityContext=release-namespace: {{ .Release.Namespace }}' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"release-name":"release-name","release-namespace":"default"}' ]
}

@test "Deployment/powerdns/image: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.image.repository=docker-repo.local/powerdns/powerdns' \
        --set 'powerdns.image.tag=latest' \
        --set 'powerdns.image.pullPolicy=Always' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.image' |
            tee -a /dev/stderr)
    [ "${actual}" == "docker-repo.local/powerdns/powerdns:latest" ]

    local actual=$(echo "$container" |
        yq -r -c '.imagePullPolicy' |
            tee -a /dev/stderr)
    [ "${actual}" == "Always" ]
}

@test "Deployment/powerdns: inherits imagePullSecret from global" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'global.imagePullSecrets[0].name=quay.io-varnish-software' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.imagePullSecrets' | tee -a /dev/stderr)
    [ "${actual}" == '[{"name":"quay.io-varnish-software"}]' ]
}

@test "Deployment/powerdns: can enable serviceAccount" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'serviceAccount.create=true' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.serviceAccountName' | tee -a /dev/stderr)
    [ "${actual}" == "release-name-varnish-controller-router" ]
}

@test "Deployment/powerdns: use default serviceAccount when disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'serviceAccount.create=false' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.serviceAccountName' | tee -a /dev/stderr)
    [ "${actual}" == "default" ]
}

@test "Deployment/powerdns: inherits annotations from powerdns" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.annotations.hello=varnish' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "Deployment/powerdns: inherits annotations from powerdns as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.annotations=hello: {{ .Release.Name }}' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "Deployment/powerdns: inherits podAnnotations from server" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.podAnnotations.hello=varnish' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "Deployment/powerdns: inherits podAnnotations from server as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.podAnnotations=hello: {{ .Release.Name }}' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "Deployment/powerdns: includes configmap checksum in podAnnotations by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.metadata.annotations' |
            tee -a /dev/stderr)

    # The checksum in the annotation is of
    # the rendered configmap, without comments or ---, and with a newline at the start.
    checksum="$( (echo; helm template \
        --set 'powerdns.enabled=true' \
        --namespace default \
        --show-only templates/configmap-powerdns.yaml . | grep -v -e '^#'  -e '^---$' ) | sha256sum | grep -o '^[^ ]*' )"

    echo Checksum: $checksum
    [ "${actual}" == "{\"checksum/release-name-varnish-controller-router\":\"${checksum}\"}" ]
}

@test "Deployment/powerdns: inherits podLabels from global and powerdns" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'global.podLabels.foo=bar' \
        --set 'powerdns.podLabels.hello=varnish' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-controller-router-powerdns","foo":"bar","hello":"varnish"}' ]
}

@test "Deployment/powerdns: inherits podLabels from global and powerdns with global as templated string" {
    cd "$(chart_dir)"

    local labels="
release-name: {{ .Release.Name }}
release-namespace: to-be-override
"

    local object=$((helm template \
        --set 'powerdns.enabled=true' \
        --set "global.podLabels=${labels}" \
        --set 'powerdns.podLabels.release-namespace=varnish' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-controller-router-powerdns","release-name":"release-name","release-namespace":"varnish"}' ]
}

@test "Deployment/powerdns: inherits podLabels from global and powerdns with powerdns as templated string" {
    cd "$(chart_dir)"

    local labels="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local object=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'global.podLabels.release-namespace=to-be-override' \
        --set "powerdns.podLabels=${labels}" \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-controller-router-powerdns","release-name":"release-name","release-namespace":"default"}' ]
}

@test "Deployment/powerdns: inherits default selector labels" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'powerdns.enabled=true' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    # .metadata.labels

    local actual=$(echo "$object" |
        yq -r -c '.metadata.labels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish-controller-router-powerdns" ]

    local actual=$(echo "$object" |
        yq -r -c '.metadata.labels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]

    local actual=$(echo "$object" |
        yq -r -c '.metadata.labels."app.kubernetes.io/version"' |
            tee -a /dev/stderr)
    [ "${actual}" != "" ]

    local actual=$(echo "$object" |
        yq -r -c '.metadata.labels."app.kubernetes.io/managed-by"' |
            tee -a /dev/stderr)
    [ "${actual}" == "Helm" ]

    # .spec.selector.matchLabels

    local actual=$(echo "$object" |
        yq -r -c '.spec.selector.matchLabels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish-controller-router-powerdns" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.selector.matchLabels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]

    # .spec.template.metadata.labels

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish-controller-router-powerdns" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "Deployment/powerdns/nodeSelector: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.nodeSelector.tier=edge' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == '{"tier":"edge"}' ]
}

@test "Deployment/powerdns/nodeSelector: can be as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.nodeSelector=tier: {{ .Release.Name }}-edge' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == '{"tier":"release-name-edge"}' ]
}

@test "Deployment/powerdns/nodeSelector: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/powerdns/tolerations: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.tolerations[0].key=far-network-disk' \
        --set 'powerdns.tolerations[0].operator=Exists' \
        --set 'powerdns.tolerations[0].effect=NoSchedule' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == '[{"effect":"NoSchedule","key":"far-network-disk","operator":"Exists"}]' ]
}

@test "Deployment/powerdns/tolerations: can be configured as templated string" {
    cd "$(chart_dir)"

    local tolerations='
- key: ban-{{ .Release.Name }}
  operator: Exists
  effect: NoSchedule
'

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set "powerdns.tolerations=${tolerations}" \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == '[{"key":"ban-release-name","operator":"Exists","effect":"NoSchedule"}]' ]
}

@test "Deployment/powerdns/tolerations: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/powerdns/affinity: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchLabels.foo=bar' \
        --set 'powerdns.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey=kubernetes.io/hostname' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.affinity' | tee -a /dev/stderr)

    [ "${actual}" == '{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"foo":"bar"}},"topologyKey":"kubernetes.io/hostname"}]}}' ]
}

@test "Deployment/powerdns/affinity: can be configured as templated string" {
    cd "$(chart_dir)"

    local affinity='
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels:
          app.kubernetes.io/name: {{ include "varnish-controller-router.name" . }}-powerdns
          app.kubernetes.io/instance: {{ .Release.Name }}
      topologyKey: kubernetes.io/hostname
'

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set "powerdns.affinity=${affinity}" \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.affinity' | tee -a /dev/stderr)

    [ "${actual}" == '{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"app.kubernetes.io/name":"varnish-controller-router-powerdns","app.kubernetes.io/instance":"release-name"}},"topologyKey":"kubernetes.io/hostname"}]}}' ]
}

@test "Deployment/powerdns/strategy: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.strategy=' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Deployment/powerdns/strategy: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.strategy.type=RollingUpdate' \
        --set 'powerdns.strategy.rollingUpdate.maxUnavailable=1' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"rollingUpdate":{"maxUnavailable":1},"type":"RollingUpdate"}' ]
}

@test "Deployment/powerdns/strategy: can be configured as templated string" {
    cd "$(chart_dir)"

    local strategy='
type: RollingUpdate
rollingUpdate:
  maxUnavailable: {{ 1 }}
'

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set "powerdns.strategy=$strategy" \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":1}}' ]
}

@test "Deployment/powerdns/extraArgs: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'powerdns.enabled=true' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/usr/bin/tini","--","/usr/local/sbin/pdns_server-startup"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .args' |
            tee -a /dev/stderr)
    [ "${actual}" == 'null' ]
}

@test "Deployment/powerdns/extraArgs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'powerdns.enabled=true' \
        --set "powerdns.extraArgs[0]=-help" \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/usr/bin/tini","--","/usr/local/sbin/pdns_server-startup"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .args' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-help"]' ]
}

@test "Deployment/powerdns/extraEnvs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.extraEnvs.FOO=bar' \
        --set 'powerdns.extraEnvs.BAZ=bax' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "Deployment/powerdns/extraEnvs: can be configured as a templated string" {
    cd "$(chart_dir)"

    local extraEnvs="
- name: RELEASE_NAME
  value: {{ .Release.Name }}
- name: RELEASE_NAMESPACE
  value: {{ .Release.Namespace }}"

    local object=$((helm template \
        --set 'powerdns.enabled=true' \
        --set "powerdns.extraEnvs=${extraEnvs}" \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .env[]? | select(.name == "RELEASE_NAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAME","value":"release-name"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .env[]? | select(.name == "RELEASE_NAMESPACE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAMESPACE","value":"default"}' ]
}

@test "Deployment/powerdns/extraEnvs: can be configured as a list" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.extraEnvs[0].name=FOO' \
        --set 'powerdns.extraEnvs[0].value=bar' \
        --set 'powerdns.extraEnvs[1].name=BAZ' \
        --set 'powerdns.extraEnvs[1].value=bax' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "Deployment/powerdns/extraEnvs: can be configured as a list of non-value literalFrom" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'powerdns.extraEnvs[0].name=FROM_CONFIGMAP' \
        --set 'powerdns.extraEnvs[0].valueFrom.configMapKeyRef.name=my-configmap' \
        --set 'powerdns.extraEnvs[0].valueFrom.configMapKeyRef.key=my-key' \
        --set 'powerdns.extraEnvs[1].name=FROM_SECRET' \
        --set 'powerdns.extraEnvs[1].valueFrom.secretKeyRef.name=my-secret' \
        --set 'powerdns.extraEnvs[1].valueFrom.secretKeyRef.key=my-key' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .env[]? | select(.name == "FROM_CONFIGMAP")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_CONFIGMAP","valueFrom":{"configMapKeyRef":{"key":"my-key","name":"my-configmap"}}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .env[]? | select(.name == "FROM_SECRET")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_SECRET","valueFrom":{"secretKeyRef":{"key":"my-key","name":"my-secret"}}}' ]
}

@test "Deployment/powerdns/resources: inherits resources from global and powerdns" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'global.resources.limits.cpu=100m' \
        --set 'global.resources.requests.cpu=100m' \
        --set 'powerdns.resources.limits.cpu=500m' \
        --set 'powerdns.resources.limits.memory=512Mi' \
        --set 'powerdns.resources.requests.memory=128Mi' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/powerdns/resources: inherits resources from global and powerdns with global as a templated string" {
    cd "$(chart_dir)"

    local resources="
limits:
  cpu: 500m
  memory: 512Mi
requests:
  memory: 128Mi
"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set 'global.resources.limits.cpu=100m' \
        --set 'global.resources.requests.cpu=100m' \
        --set "powerdns.resources=${resources}" \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/powerdns/resources: inherits resources from global and powerdns with powerdns as a templated string" {
    cd "$(chart_dir)"

    local resources="
limits:
  cpu: 100m
requests:
  cpu: 100m
"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set "global.resources=${resources}" \
        --set 'powerdns.resources.limits.cpu=500m' \
        --set 'powerdns.resources.limits.memory=512Mi' \
        --set 'powerdns.resources.requests.memory=128Mi' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/powerdns/resources: inherits resources from global and powerdns with both as a templated string" {
    cd "$(chart_dir)"

    local globalResources="
limits:
  cpu: 100m
requests:
  cpu: 100m
"

    local resources="
limits:
  cpu: 500m
  memory: 512Mi
requests:
  memory: 128Mi
"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --set "global.resources=${globalResources}" \
        --set "powerdns.resources=${resources}" \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/powerdns/resources: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'powerdns.enabled=true' \
        --namespace default \
        --show-only templates/deployment-powerdns.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "powerdns") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}
