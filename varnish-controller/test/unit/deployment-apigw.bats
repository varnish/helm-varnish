#!/usr/bin/env bats

load _helpers

@test "Deployment/apigw: enabled by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.containers[]? | select(.name == "apigw")' |
            tee -a /dev/stderr)
    [ "${actual}" != "" ]
}

@test "Deployment/apigw: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.enabled=false' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.containers[]? | select(.name == "apigw")' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]
}

@test "Deployment/apigw: inherits securityContext from global and apigw" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'global.securityContext.hello=world' \
        --set 'apigw.securityContext.runAsUser=1000' \
        --set 'apigw.securityContext.foo=bar' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"foo":"bar","hello":"world","runAsNonRoot":true,"runAsUser":1000}' ]
}

@test "Deployment/apigw: inherits securityContext from global and apigw with global as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set "global.securityContext=${securityContext}" \
        --set 'apigw.securityContext.runAsUser=1000' \
        --set 'apigw.securityContext.foo=bar' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .securityContext' | tee -a /dev/stderr)

    [ "${actual}" == '{"foo":"bar","release-name":"release-name","release-namespace":"default","runAsUser":1000}' ]
}

@test "Deployment/apigw: inherits securityContext from global and apigw with apigw as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set 'global.securityContext.hello=world' \
        --set "apigw.securityContext=${securityContext}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"hello":"world","release-name":"release-name","release-namespace":"default","runAsNonRoot":true,"runAsUser":999}' ]
}

@test "Deployment/apigw: inherits securityContext from global and apigw with both as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: to-be-override
"

    local actual=$((helm template \
        --set "global.securityContext=${securityContext}" \
        --set 'apigw.securityContext=release-namespace: {{ .Release.Namespace }}' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"release-name":"release-name","release-namespace":"default"}' ]
}

@test "Deployment/apigw/image: inherits tag from appVersion" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.image' |
            tee -a /dev/stderr)
    [ "${actual}" = "quay.io/varnish-software/varnish-controller-api-gw:$(app_version)" ]

    local actual=$(echo "$container" |
        yq -r -c '.imagePullPolicy' |
            tee -a /dev/stderr)
    [ "${actual}" = "IfNotPresent" ]
}

@test "Deployment/apigw/image: inherits tag and pullPolicy from global" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'global.controller.image.tag=latest' \
        --set 'global.controller.image.pullPolicy=Always' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.image' |
            tee -a /dev/stderr)
    [ "${actual}" == "quay.io/varnish-software/varnish-controller-api-gw:latest" ]

    local actual=$(echo "$container" |
        yq -r -c '.imagePullPolicy' |
            tee -a /dev/stderr)
    [ "${actual}" == "Always" ]
}

@test "Deployment/apigw/image: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'apigw.image.repository=docker-repo.local/varnish-software/varnish-controller-apigw' \
        --set 'apigw.image.tag=latest' \
        --set 'apigw.image.pullPolicy=Always' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.image' |
            tee -a /dev/stderr)
    [ "${actual}" == "docker-repo.local/varnish-software/varnish-controller-apigw:latest" ]

    local actual=$(echo "$container" |
        yq -r -c '.imagePullPolicy' |
            tee -a /dev/stderr)
    [ "${actual}" == "Always" ]
}

@test "Deployment/apigw: inherits imagePullSecret from global" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'global.imagePullSecrets[0].name=quay.io-varnish-software' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.imagePullSecrets' | tee -a /dev/stderr)
    [ "${actual}" == '[{"name":"quay.io-varnish-software"}]' ]
}

@test "Deployment/apigw: can enable serviceAccount" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'serviceAccount.create=true' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.serviceAccountName' | tee -a /dev/stderr)
    [ "${actual}" == "release-name-varnish-controller" ]
}

@test "Deployment/apigw: use default serviceAccount when disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'serviceAccount.create=false' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.serviceAccountName' | tee -a /dev/stderr)
    [ "${actual}" == "default" ]
}

@test "Deployment/apigw: inherits annotations from apigw" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.annotations.hello=varnish' \
        --set 'brainz.licenseSecret=apigw-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "Deployment/apigw: inherits annotations from apigw as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.annotations=hello: {{ .Release.Name }}' \
        --set 'brainz.licenseSecret=apigw-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "Deployment/apigw: inherits podAnnotations from server" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.podAnnotations.hello=varnish' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "Deployment/apigw: inherits podAnnotations from server as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.podAnnotations=hello: {{ .Release.Name }}' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "Deployment/apigw: inherits podLabels from global and apigw" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'global.podLabels.foo=bar' \
        --set 'apigw.podLabels.hello=varnish' \
        --set 'brainz.licenseSecret=apigw-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-controller-apigw","foo":"bar","hello":"varnish"}' ]
}

@test "Deployment/apigw: inherits podLabels from global and apigw with global as templated string" {
    cd "$(chart_dir)"

    local labels="
release-name: {{ .Release.Name }}
release-namespace: to-be-override
"

    local object=$((helm template \
        --set "global.podLabels=${labels}" \
        --set 'apigw.podLabels.release-namespace=varnish' \
        --set 'brainz.licenseSecret=apigw-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-controller-apigw","release-name":"release-name","release-namespace":"varnish"}' ]
}

@test "Deployment/apigw: inherits podLabels from global and apigw with apigw as templated string" {
    cd "$(chart_dir)"

    local labels="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local object=$((helm template \
        --set 'global.podLabels.release-namespace=to-be-override' \
        --set "apigw.podLabels=${labels}" \
        --set 'brainz.licenseSecret=apigw-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-controller-apigw","release-name":"release-name","release-namespace":"default"}' ]
}

@test "Deployment/apigw: inherits default selector labels" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    # .metadata.labels

    local actual=$(echo "$object" |
        yq -r -c '.metadata.labels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish-controller-apigw" ]

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
    [ "${actual}" == "varnish-controller-apigw" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.selector.matchLabels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]

    # .spec.template.metadata.labels

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish-controller-apigw" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}


@test "Deployment/apigw/nodeSelector: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.nodeSelector.tier=edge' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == '{"tier":"edge"}' ]
}

@test "Deployment/apigw/nodeSelector: can be as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.nodeSelector=tier: {{ .Release.Name }}-edge' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == '{"tier":"release-name-edge"}' ]
}

@test "Deployment/apigw/nodeSelector: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/apigw/tolerations: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.tolerations[0].key=far-network-disk' \
        --set 'apigw.tolerations[0].operator=Exists' \
        --set 'apigw.tolerations[0].effect=NoSchedule' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == '[{"effect":"NoSchedule","key":"far-network-disk","operator":"Exists"}]' ]
}

@test "Deployment/apigw/tolerations: can be configured as templated string" {
    cd "$(chart_dir)"

    local tolerations='
- key: ban-{{ .Release.Name }}
  operator: Exists
  effect: NoSchedule
'

    local actual=$((helm template \
        --set "apigw.tolerations=${tolerations}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == '[{"key":"ban-release-name","operator":"Exists","effect":"NoSchedule"}]' ]
}

@test "Deployment/apigw/tolerations: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/apigw/affinity: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchLabels.foo=bar' \
        --set 'apigw.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey=kubernetes.io/hostname' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.affinity' | tee -a /dev/stderr)

    [ "${actual}" == '{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"foo":"bar"}},"topologyKey":"kubernetes.io/hostname"}]}}' ]
}

@test "Deployment/apigw/affinity: can be configured as templated string" {
    cd "$(chart_dir)"

    local affinity='
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels:
          app.kubernetes.io/name: {{ include "varnish-controller.name" . }}
          app.kubernetes.io/instance: {{ .Release.Name }}
      topologyKey: kubernetes.io/hostname
'

    local actual=$((helm template \
        --set "apigw.affinity=${affinity}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.affinity' | tee -a /dev/stderr)

    [ "${actual}" == '{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"app.kubernetes.io/name":"varnish-controller","app.kubernetes.io/instance":"release-name"}},"topologyKey":"kubernetes.io/hostname"}]}}' ]
}

@test "Deployment/apigw/strategy: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.strategy=' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Deployment/apigw/strategy: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.strategy.type=RollingUpdate' \
        --set 'apigw.strategy.rollingUpdate.maxUnavailable=1' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"rollingUpdate":{"maxUnavailable":1},"type":"RollingUpdate"}' ]
}

@test "Deployment/apigw/strategy: can be configured as templated string" {
    cd "$(chart_dir)"

    local strategy='
type: RollingUpdate
rollingUpdate:
  maxUnavailable: {{ 1 }}
'

    local actual=$((helm template \
        --set "apigw.strategy=$strategy" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":1}}' ]
}

@test "Deployment/apigw/startupProbe: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .startupProbe' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/apigw/startupProbe: can be enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.startupProbe.initialDelaySeconds=10' \
        --set 'apigw.startupProbe.periodSeconds=20' \
        --set 'apigw.startupProbe.timeoutSeconds=2' \
        --set 'apigw.startupProbe.successThreshold=2' \
        --set 'apigw.startupProbe.failureThreshold=6' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .startupProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"tcpSocket":{"port":8002},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "Deployment/apigw/readinessProbe: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.readinessProbe.initialDelaySeconds=10' \
        --set 'apigw.readinessProbe.periodSeconds=20' \
        --set 'apigw.readinessProbe.timeoutSeconds=2' \
        --set 'apigw.readinessProbe.successThreshold=2' \
        --set 'apigw.readinessProbe.failureThreshold=6' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .readinessProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"tcpSocket":{"port":8002},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "Deployment/apigw/readinessProbe: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.readinessProbe=' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .readinessProbe' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Deployment/apigw/livenessProbe: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.livenessProbe.initialDelaySeconds=10' \
        --set 'apigw.livenessProbe.periodSeconds=20' \
        --set 'apigw.livenessProbe.timeoutSeconds=2' \
        --set 'apigw.livenessProbe.successThreshold=2' \
        --set 'apigw.livenessProbe.failureThreshold=6' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .livenessProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"tcpSocket":{"port":8002},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "Deployment/apigw/livenessProbe: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'apigw.livenessProbe=' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .livenessProbe' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Deployment/apigw/extraArgs: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/usr/bin/varnish-controller-api-gw"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .args' |
            tee -a /dev/stderr)
    [ "${actual}" == 'null' ]
}

@test "Deployment/apigw/extraArgs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set "apigw.extraArgs[0]=-help" \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/usr/bin/varnish-controller-api-gw"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .args' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-help"]' ]
}

@test "Deployment/apigw/extraEnvs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'apigw.extraEnvs.FOO=bar' \
        --set 'apigw.extraEnvs.BAZ=bax' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "Deployment/apigw/extraEnvs: can be configured as a templated string" {
    cd "$(chart_dir)"

    local extraEnvs="
- name: RELEASE_NAME
  value: {{ .Release.Name }}
- name: RELEASE_NAMESPACE
  value: {{ .Release.Namespace }}"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'brainz.enabled=true' \
        --set "apigw.extraEnvs=${extraEnvs}" \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .env[]? | select(.name == "RELEASE_NAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAME","value":"release-name"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .env[]? | select(.name == "RELEASE_NAMESPACE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAMESPACE","value":"default"}' ]
}

@test "Deployment/apigw/extraEnvs: can be configured as a list" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'apigw.extraEnvs[0].name=FOO' \
        --set 'apigw.extraEnvs[0].value=bar' \
        --set 'apigw.extraEnvs[1].name=BAZ' \
        --set 'apigw.extraEnvs[1].value=bax' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "Deployment/apigw/extraEnvs: can be configured as a list of non-value literalFrom" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'apigw.extraEnvs[0].name=FROM_CONFIGMAP' \
        --set 'apigw.extraEnvs[0].valueFrom.configMapKeyRef.name=my-configmap' \
        --set 'apigw.extraEnvs[0].valueFrom.configMapKeyRef.key=my-key' \
        --set 'apigw.extraEnvs[1].name=FROM_SECRET' \
        --set 'apigw.extraEnvs[1].valueFrom.secretKeyRef.name=my-secret' \
        --set 'apigw.extraEnvs[1].valueFrom.secretKeyRef.key=my-key' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .env[]? | select(.name == "FROM_CONFIGMAP")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_CONFIGMAP","valueFrom":{"configMapKeyRef":{"key":"my-key","name":"my-configmap"}}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .env[]? | select(.name == "FROM_SECRET")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_SECRET","valueFrom":{"secretKeyRef":{"key":"my-key","name":"my-secret"}}}' ]
}

@test "Deployment/apigw/resources: inherits resources from global and apigw" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'global.resources.limits.cpu=100m' \
        --set 'global.resources.requests.cpu=100m' \
        --set 'apigw.resources.limits.cpu=500m' \
        --set 'apigw.resources.limits.memory=512Mi' \
        --set 'apigw.resources.requests.memory=128Mi' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/apigw/resources: inherits resources from global and apigw with global as a templated string" {
    cd "$(chart_dir)"

    local resources="
limits:
  cpu: 500m
  memory: 512Mi
requests:
  memory: 128Mi
"

    local actual=$((helm template \
        --set 'global.resources.limits.cpu=100m' \
        --set 'global.resources.requests.cpu=100m' \
        --set "apigw.resources=${resources}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/apigw/resources: inherits resources from global and apigw with apigw as a templated string" {
    cd "$(chart_dir)"

    local resources="
limits:
  cpu: 100m
requests:
  cpu: 100m
"

    local actual=$((helm template \
        --set "global.resources=${resources}" \
        --set 'apigw.resources.limits.cpu=500m' \
        --set 'apigw.resources.limits.memory=512Mi' \
        --set 'apigw.resources.requests.memory=128Mi' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/apigw/resources: inherits resources from global and apigw with both as a templated string" {
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
        --set "global.resources=${globalResources}" \
        --set "apigw.resources=${resources}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/apigw/resources: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "apigw") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}
