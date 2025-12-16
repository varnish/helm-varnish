#!/usr/bin/env bats

load _helpers

@test "Deployment/ui: enabled by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.containers[]? | select(.name == "ui")' |
            tee -a /dev/stderr)
    [ "${actual}" != "" ]
}

@test "Deployment/ui: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.enabled=false' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.containers[]? | select(.name == "ui")' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]
}

@test "Deployment/ui: inherits securityContext from global and ui" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'global.securityContext.hello=world' \
        --set 'ui.securityContext.runAsUser=1000' \
        --set 'ui.securityContext.foo=bar' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"foo":"bar","hello":"world","runAsNonRoot":true,"runAsUser":1000}' ]
}

@test "Deployment/ui: inherits securityContext from global and ui with global as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set "global.securityContext=${securityContext}" \
        --set 'ui.securityContext.runAsUser=1000' \
        --set 'ui.securityContext.foo=bar' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .securityContext' | tee -a /dev/stderr)

    [ "${actual}" == '{"foo":"bar","release-name":"release-name","release-namespace":"default","runAsUser":1000}' ]
}

@test "Deployment/ui: inherits securityContext from global and ui with ui as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set 'global.securityContext.hello=world' \
        --set "ui.securityContext=${securityContext}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"hello":"world","release-name":"release-name","release-namespace":"default","runAsNonRoot":true,"runAsUser":999}' ]
}

@test "Deployment/ui: inherits securityContext from global and ui with both as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: to-be-override
"

    local actual=$((helm template \
        --set "global.securityContext=${securityContext}" \
        --set 'ui.securityContext=release-namespace: {{ .Release.Namespace }}' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"release-name":"release-name","release-namespace":"default"}' ]
}

@test "Deployment/ui/image: inherits tag from appVersion" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.image' |
            tee -a /dev/stderr)
    [ "${actual}" = "quay.io/varnish-software/varnish-controller-ui:$(app_version)" ]

    local actual=$(echo "$container" |
        yq -r -c '.imagePullPolicy' |
            tee -a /dev/stderr)
    [ "${actual}" = "IfNotPresent" ]
}

@test "Deployment/ui/image: inherits tag and pullPolicy from global" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'global.controller.image.tag=latest' \
        --set 'global.controller.image.pullPolicy=Always' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.image' |
            tee -a /dev/stderr)
    [ "${actual}" == "quay.io/varnish-software/varnish-controller-ui:latest" ]

    local actual=$(echo "$container" |
        yq -r -c '.imagePullPolicy' |
            tee -a /dev/stderr)
    [ "${actual}" == "Always" ]
}

@test "Deployment/ui/image: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'ui.image.repository=docker-repo.local/varnish-software/varnish-controller-ui' \
        --set 'ui.image.tag=latest' \
        --set 'ui.image.pullPolicy=Always' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.image' |
            tee -a /dev/stderr)
    [ "${actual}" == "docker-repo.local/varnish-software/varnish-controller-ui:latest" ]

    local actual=$(echo "$container" |
        yq -r -c '.imagePullPolicy' |
            tee -a /dev/stderr)
    [ "${actual}" == "Always" ]
}

@test "Deployment/ui: inherits imagePullSecret from global" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'global.imagePullSecrets[0].name=quay.io-varnish-software' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.imagePullSecrets' | tee -a /dev/stderr)
    [ "${actual}" == '[{"name":"quay.io-varnish-software"}]' ]
}

@test "Deployment/ui: can enable serviceAccount" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'serviceAccount.create=true' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.serviceAccountName' | tee -a /dev/stderr)
    [ "${actual}" == "release-name-varnish-controller" ]
}

@test "Deployment/ui: use default serviceAccount when disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'serviceAccount.create=false' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.serviceAccountName' | tee -a /dev/stderr)
    [ "${actual}" == "default" ]
}

@test "Deployment/ui: inherits annotations from ui" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.annotations.hello=varnish' \
        --set 'brainz.licenseSecret=ui-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "Deployment/ui: inherits annotations from ui as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.annotations=hello: {{ .Release.Name }}' \
        --set 'brainz.licenseSecret=ui-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "Deployment/ui: inherits podAnnotations from ui" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.podAnnotations.hello=varnish' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "Deployment/ui: inherits podAnnotations from ui as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.podAnnotations=hello: {{ .Release.Name }}' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "Deployment/ui: inherits podLabels from global and ui" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'global.podLabels.foo=bar' \
        --set 'ui.podLabels.hello=varnish' \
        --set 'brainz.licenseSecret=ui-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-controller-ui","foo":"bar","hello":"varnish"}' ]
}

@test "Deployment/ui: inherits podLabels from global and ui with global as templated string" {
    cd "$(chart_dir)"

    local labels="
release-name: {{ .Release.Name }}
release-namespace: to-be-override
"

    local object=$((helm template \
        --set "global.podLabels=${labels}" \
        --set 'ui.podLabels.release-namespace=varnish' \
        --set 'brainz.licenseSecret=ui-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-controller-ui","release-name":"release-name","release-namespace":"varnish"}' ]
}

@test "Deployment/ui: inherits podLabels from global and ui with ui as templated string" {
    cd "$(chart_dir)"

    local labels="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local object=$((helm template \
        --set 'global.podLabels.release-namespace=to-be-override' \
        --set "ui.podLabels=${labels}" \
        --set 'brainz.licenseSecret=ui-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-controller-ui","release-name":"release-name","release-namespace":"default"}' ]
}

@test "Deployment/ui: inherits default selector labels" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    # .metadata.labels

    local actual=$(echo "$object" |
        yq -r -c '.metadata.labels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish-controller-ui" ]

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
    [ "${actual}" == "varnish-controller-ui" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.selector.matchLabels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]

    # .spec.template.metadata.labels

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish-controller-ui" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}


@test "Deployment/ui/nodeSelector: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.nodeSelector.tier=edge' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == '{"tier":"edge"}' ]
}

@test "Deployment/ui/nodeSelector: can be as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.nodeSelector=tier: {{ .Release.Name }}-edge' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == '{"tier":"release-name-edge"}' ]
}

@test "Deployment/ui/nodeSelector: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/ui/tolerations: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.tolerations[0].key=far-network-disk' \
        --set 'ui.tolerations[0].operator=Exists' \
        --set 'ui.tolerations[0].effect=NoSchedule' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == '[{"effect":"NoSchedule","key":"far-network-disk","operator":"Exists"}]' ]
}

@test "Deployment/ui/tolerations: can be configured as templated string" {
    cd "$(chart_dir)"

    local tolerations='
- key: ban-{{ .Release.Name }}
  operator: Exists
  effect: NoSchedule
'

    local actual=$((helm template \
        --set "ui.tolerations=${tolerations}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == '[{"key":"ban-release-name","operator":"Exists","effect":"NoSchedule"}]' ]
}

@test "Deployment/ui/tolerations: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/ui/affinity: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchLabels.foo=bar' \
        --set 'ui.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey=kubernetes.io/hostname' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.affinity' | tee -a /dev/stderr)

    [ "${actual}" == '{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"foo":"bar"}},"topologyKey":"kubernetes.io/hostname"}]}}' ]
}

@test "Deployment/ui/affinity: can be configured as templated string" {
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
        --set "ui.affinity=${affinity}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.affinity' | tee -a /dev/stderr)

    [ "${actual}" == '{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"app.kubernetes.io/name":"varnish-controller","app.kubernetes.io/instance":"release-name"}},"topologyKey":"kubernetes.io/hostname"}]}}' ]
}

@test "Deployment/ui/strategy: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.strategy=' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Deployment/ui/strategy: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.strategy.type=RollingUpdate' \
        --set 'ui.strategy.rollingUpdate.maxUnavailable=1' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"rollingUpdate":{"maxUnavailable":1},"type":"RollingUpdate"}' ]
}

@test "Deployment/ui/strategy: can be configured as templated string" {
    cd "$(chart_dir)"

    local strategy='
type: RollingUpdate
rollingUpdate:
  maxUnavailable: {{ 1 }}
'

    local actual=$((helm template \
        --set "ui.strategy=$strategy" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":1}}' ]
}

@test "Deployment/ui/startupProbe: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .startupProbe' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/ui/startupProbe: can be enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.startupProbe.initialDelaySeconds=10' \
        --set 'ui.startupProbe.periodSeconds=20' \
        --set 'ui.startupProbe.timeoutSeconds=2' \
        --set 'ui.startupProbe.successThreshold=2' \
        --set 'ui.startupProbe.failureThreshold=6' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .startupProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"tcpSocket":{"port":8080},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "Deployment/ui/readinessProbe: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.readinessProbe.initialDelaySeconds=10' \
        --set 'ui.readinessProbe.periodSeconds=20' \
        --set 'ui.readinessProbe.timeoutSeconds=2' \
        --set 'ui.readinessProbe.successThreshold=2' \
        --set 'ui.readinessProbe.failureThreshold=6' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .readinessProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"tcpSocket":{"port":8080},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "Deployment/ui/readinessProbe: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.readinessProbe=' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .readinessProbe' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Deployment/ui/livenessProbe: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.livenessProbe.initialDelaySeconds=10' \
        --set 'ui.livenessProbe.periodSeconds=20' \
        --set 'ui.livenessProbe.timeoutSeconds=2' \
        --set 'ui.livenessProbe.successThreshold=2' \
        --set 'ui.livenessProbe.failureThreshold=6' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .livenessProbe' | tee -a /dev/stderr)

    [ "${actual}" == '{"tcpSocket":{"port":8080},"failureThreshold":6,"initialDelaySeconds":10,"periodSeconds":20,"successThreshold":2,"timeoutSeconds":2}' ]
}

@test "Deployment/ui/livenessProbe: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'ui.livenessProbe=' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .livenessProbe' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Deployment/ui/extraArgs: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/usr/bin/varnish-controller-ui"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .args' |
            tee -a /dev/stderr)
    [ "${actual}" == 'null' ]
}

@test "Deployment/ui/extraArgs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set "ui.extraArgs[0]=-help" \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/usr/bin/varnish-controller-ui"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .args' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-help"]' ]
}

@test "Deployment/ui/extraEnvs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'ui.extraEnvs.FOO=bar' \
        --set 'ui.extraEnvs.BAZ=bax' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "Deployment/ui/extraEnvs: can be configured as a templated string" {
    cd "$(chart_dir)"

    local extraEnvs="
- name: RELEASE_NAME
  value: {{ .Release.Name }}
- name: RELEASE_NAMESPACE
  value: {{ .Release.Namespace }}"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set "ui.extraEnvs=${extraEnvs}" \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .env[]? | select(.name == "RELEASE_NAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAME","value":"release-name"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .env[]? | select(.name == "RELEASE_NAMESPACE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAMESPACE","value":"default"}' ]
}

@test "Deployment/ui/extraEnvs: can be configured as a list" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'ui.extraEnvs[0].name=FOO' \
        --set 'ui.extraEnvs[0].value=bar' \
        --set 'ui.extraEnvs[1].name=BAZ' \
        --set 'ui.extraEnvs[1].value=bax' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "Deployment/ui/extraEnvs: can be configured as a list of non-value literalFrom" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'ui.extraEnvs[0].name=FROM_CONFIGMAP' \
        --set 'ui.extraEnvs[0].valueFrom.configMapKeyRef.name=my-configmap' \
        --set 'ui.extraEnvs[0].valueFrom.configMapKeyRef.key=my-key' \
        --set 'ui.extraEnvs[1].name=FROM_SECRET' \
        --set 'ui.extraEnvs[1].valueFrom.secretKeyRef.name=my-secret' \
        --set 'ui.extraEnvs[1].valueFrom.secretKeyRef.key=my-key' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .env[]? | select(.name == "FROM_CONFIGMAP")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_CONFIGMAP","valueFrom":{"configMapKeyRef":{"key":"my-key","name":"my-configmap"}}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .env[]? | select(.name == "FROM_SECRET")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_SECRET","valueFrom":{"secretKeyRef":{"key":"my-key","name":"my-secret"}}}' ]
}

@test "Deployment/ui/resources: inherits resources from global and ui" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'global.resources.limits.cpu=100m' \
        --set 'global.resources.requests.cpu=100m' \
        --set 'ui.resources.limits.cpu=500m' \
        --set 'ui.resources.limits.memory=512Mi' \
        --set 'ui.resources.requests.memory=128Mi' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/ui/resources: inherits resources from global and ui with global as a templated string" {
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
        --set "ui.resources=${resources}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/ui/resources: inherits resources from global and ui with ui as a templated string" {
    cd "$(chart_dir)"

    local resources="
limits:
  cpu: 100m
requests:
  cpu: 100m
"

    local actual=$((helm template \
        --set "global.resources=${resources}" \
        --set 'ui.resources.limits.cpu=500m' \
        --set 'ui.resources.limits.memory=512Mi' \
        --set 'ui.resources.requests.memory=128Mi' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/ui/resources: inherits resources from global and ui with both as a templated string" {
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
        --set "ui.resources=${resources}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/ui/resources: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "ui") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}
