#!/usr/bin/env bats

load _helpers

@test "Deployment/router: enabled by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.containers[]? | select(.name == "router")' |
            tee -a /dev/stderr)
    [ "${actual}" != "" ]
}

@test "Deployment/router: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.enabled=false' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.containers[]? | select(.name == "router")' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]
}

@test "Deployment/router: inherits securityContext from global and router with global as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set 'router.enabled=true' \
        --set "global.securityContext=${securityContext}" \
        --set 'router.securityContext.runAsUser=1000' \
        --set 'router.securityContext.foo=bar' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .securityContext' | tee -a /dev/stderr)

    [ "${actual}" == '{"foo":"bar","release-name":"release-name","release-namespace":"default","runAsUser":1000}' ]
}

@test "Deployment/router: inherits securityContext from global and router with router as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set 'router.enabled=true' \
        --set 'global.securityContext.hello=world' \
        --set "router.securityContext=${securityContext}" \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"hello":"world","release-name":"release-name","release-namespace":"default","runAsNonRoot":true,"runAsUser":999}' ]
}

@test "Deployment/router: inherits securityContext from global and router with both as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: to-be-override
"

    local actual=$((helm template \
        --set 'router.enabled=true' \
        --set "global.securityContext=${securityContext}" \
        --set 'router.securityContext=release-namespace: {{ .Release.Namespace }}' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"release-name":"release-name","release-namespace":"default"}' ]
}

@test "Deployment/router: inherits nats configuration from global" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '$(VARNISH_CONTROLLER_NATS_USER):$(VARNISH_CONTROLLER_NATS_PASS)@$(VARNISH_CONTROLLER_NATS_HOST)' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"varnish-controller-credentials","key":"nats-varnish-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller-nats.default.svc.cluster.local:4222' ]
}

@test "Deployment/router: inherits nats configuration from global with external secret" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'global.natsServer.internal.passwordFrom.name=external-secret' \
        --set 'global.natsServer.internal.passwordFrom.key=nats-password' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '$(VARNISH_CONTROLLER_NATS_USER):$(VARNISH_CONTROLLER_NATS_PASS)@$(VARNISH_CONTROLLER_NATS_HOST)' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"external-secret","key":"nats-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller-nats.default.svc.cluster.local:4222' ]
}

@test "Deployment/router: inherits nats configuration from internal nats" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'global.natsServer.internal.enabled=-' \
        --set 'nats.enabled=true' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '$(VARNISH_CONTROLLER_NATS_USER):$(VARNISH_CONTROLLER_NATS_PASS)@$(VARNISH_CONTROLLER_NATS_HOST)' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"varnish-controller-credentials","key":"nats-varnish-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller-nats.default.svc.cluster.local:4222' ]
}

@test "Deployment/router: inherits nats configuration from global with overridden values" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'global.natsServer.internal.namespace=varnish-controller' \
        --set 'global.natsServer.internal.releaseName=test' \
        --set 'global.natsServer.internal.clusterDomain=remote.local' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '$(VARNISH_CONTROLLER_NATS_USER):$(VARNISH_CONTROLLER_NATS_PASS)@$(VARNISH_CONTROLLER_NATS_HOST)' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"varnish-controller-credentials","key":"nats-varnish-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'test-nats.varnish-controller.svc.remote.local:4222' ]
}

@test "Deployment/router: inherits nats configuration from global with external nats" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'global.natsServer.externalAddress=nats.local:4222' \
        --set 'global.natsServer.internal.enabled=false' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'nats.local:4222' ]
}

@test "Deployment/router: cannot disable both external and internal nats" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'global.natsServer.externalAddress=' \
        --set 'global.natsServer.internal.enabled=false' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"Either 'global.natsServer.internal.enabled' or 'global.natsServer.externalAddress' must be set"* ]]
}

@test "Deployment/router: test initContainer image and tag" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set 'router.asn.enabled=false' \
        --set 'router.geoIp.enabled=true' \
        --set 'router.geoIp.mmdb_url=http://example.com/test.mmdb' \
        --set 'global.initContainer.image=ubuntu' \
        --set 'global.initContainer.tag=24.04' \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.initContainers[]? | select(.name == "router-download-geoip-asn") | .image' | tee -a /dev/stderr)

    [ "${actual}" == 'ubuntu:24.04' ]
}

@test "Deployment/router/image: inherits tag from appVersion" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.image' |
            tee -a /dev/stderr)
    [ "${actual}" = "quay.io/varnish-software/varnish-controller-router:$(app_version)" ]

    local actual=$(echo "$container" |
        yq -r -c '.imagePullPolicy' |
            tee -a /dev/stderr)
    [ "${actual}" = "IfNotPresent" ]
}

@test "Deployment/router/image: inherits tag and pullPolicy from global" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'global.controller.image.tag=latest' \
        --set 'global.controller.image.pullPolicy=Always' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.image' |
            tee -a /dev/stderr)
    [ "${actual}" == "quay.io/varnish-software/varnish-controller-router:latest" ]

    local actual=$(echo "$container" |
        yq -r -c '.imagePullPolicy' |
            tee -a /dev/stderr)
    [ "${actual}" == "Always" ]
}

@test "Deployment/router/image: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'router.image.repository=docker-repo.local/varnish-software/varnish-controller-router' \
        --set 'router.image.tag=latest' \
        --set 'router.image.pullPolicy=Always' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.image' |
            tee -a /dev/stderr)
    [ "${actual}" == "docker-repo.local/varnish-software/varnish-controller-router:latest" ]

    local actual=$(echo "$container" |
        yq -r -c '.imagePullPolicy' |
            tee -a /dev/stderr)
    [ "${actual}" == "Always" ]
}

@test "Deployment/router: inherits imagePullSecret from global" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'global.imagePullSecrets[0].name=quay.io-varnish-software' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.imagePullSecrets' | tee -a /dev/stderr)
    [ "${actual}" == '[{"name":"quay.io-varnish-software"}]' ]
}

@test "Deployment/router: can enable serviceAccount" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'serviceAccount.create=true' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.serviceAccountName' | tee -a /dev/stderr)
    [ "${actual}" == "release-name-varnish-controller-router" ]
}

@test "Deployment/router: use default serviceAccount when disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'serviceAccount.create=false' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.serviceAccountName' | tee -a /dev/stderr)
    [ "${actual}" == "default" ]
}

@test "Deployment/router: inherits annotations from router" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.annotations.hello=varnish' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "Deployment/router: inherits annotations from router as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.annotations=hello: {{ .Release.Name }}' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "Deployment/router: inherits podAnnotations from server" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.podAnnotations.hello=varnish' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "Deployment/router: inherits podAnnotations from server as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.podAnnotations=hello: {{ .Release.Name }}' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "Deployment/router: inherits podLabels from global and router" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'global.podLabels.foo=bar' \
        --set 'router.podLabels.hello=varnish' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-controller-router","foo":"bar","hello":"varnish"}' ]
}

@test "Deployment/router: inherits podLabels from global and router with global as templated string" {
    cd "$(chart_dir)"

    local labels="
release-name: {{ .Release.Name }}
release-namespace: to-be-override
"

    local object=$((helm template \
        --set "global.podLabels=${labels}" \
        --set 'router.podLabels.release-namespace=varnish' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-controller-router","release-name":"release-name","release-namespace":"varnish"}' ]
}

@test "Deployment/router: inherits podLabels from global and router with router as templated string" {
    cd "$(chart_dir)"

    local labels="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local object=$((helm template \
        --set 'global.podLabels.release-namespace=to-be-override' \
        --set "router.podLabels=${labels}" \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-controller-router","release-name":"release-name","release-namespace":"default"}' ]
}

@test "Deployment/router: inherits default selector labels" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    # .metadata.labels

    local actual=$(echo "$object" |
        yq -r -c '.metadata.labels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish-controller-router" ]

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
    [ "${actual}" == "varnish-controller-router" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.selector.matchLabels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]

    # .spec.template.metadata.labels

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish-controller-router" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "Deployment/router/nodeSelector: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.nodeSelector.tier=edge' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == '{"tier":"edge"}' ]
}

@test "Deployment/router/nodeSelector: can be as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.nodeSelector=tier: {{ .Release.Name }}-edge' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == '{"tier":"release-name-edge"}' ]
}

@test "Deployment/router/nodeSelector: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/router/tolerations: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.tolerations[0].key=far-network-disk' \
        --set 'router.tolerations[0].operator=Exists' \
        --set 'router.tolerations[0].effect=NoSchedule' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == '[{"effect":"NoSchedule","key":"far-network-disk","operator":"Exists"}]' ]
}

@test "Deployment/router/tolerations: can be configured as templated string" {
    cd "$(chart_dir)"

    local tolerations='
- key: ban-{{ .Release.Name }}
  operator: Exists
  effect: NoSchedule
'

    local actual=$((helm template \
        --set "router.tolerations=${tolerations}" \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == '[{"key":"ban-release-name","operator":"Exists","effect":"NoSchedule"}]' ]
}

@test "Deployment/router/tolerations: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/router/affinity: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchLabels.foo=bar' \
        --set 'router.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey=kubernetes.io/hostname' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.affinity' | tee -a /dev/stderr)

    [ "${actual}" == '{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"foo":"bar"}},"topologyKey":"kubernetes.io/hostname"}]}}' ]
}

@test "Deployment/router/affinity: can be configured as templated string" {
    cd "$(chart_dir)"

    local affinity='
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels:
          app.kubernetes.io/name: {{ include "varnish-controller-router.name" . }}
          app.kubernetes.io/instance: {{ .Release.Name }}
      topologyKey: kubernetes.io/hostname
'

    local actual=$((helm template \
        --set "router.affinity=${affinity}" \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.affinity' | tee -a /dev/stderr)

    [ "${actual}" == '{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"app.kubernetes.io/name":"varnish-controller-router","app.kubernetes.io/instance":"release-name"}},"topologyKey":"kubernetes.io/hostname"}]}}' ]
}

@test "Deployment/router/strategy: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.strategy=' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Deployment/router/strategy: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.strategy.type=RollingUpdate' \
        --set 'router.strategy.rollingUpdate.maxUnavailable=1' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"rollingUpdate":{"maxUnavailable":1},"type":"RollingUpdate"}' ]
}

@test "Deployment/router/strategy: can be configured as templated string" {
    cd "$(chart_dir)"

    local strategy='
type: RollingUpdate
rollingUpdate:
  maxUnavailable: {{ 1 }}
'

    local actual=$((helm template \
        --set "router.strategy=$strategy" \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":1}}' ]
}

@test "Deployment/router/http: enabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_HTTP_ROUTING") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'true' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_HTTP_PORT") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '6081' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_HTTP_HOST") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"fieldRef":{"fieldPath":"status.podIP"}}' ]
}

@test "Deployment/router/http: can be disabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'router.http.enabled=false' \
        --set 'router.livenessProbe=' \
        --set 'router.readinessProbe=' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_HTTP_ROUTING") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'false' ]
}

@test "Deployment/router/http: can be configured with a custom port" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'router.http.port=9090' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_HTTP_PORT") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '9090' ]
}

@test "Deployment/router/https: disabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_HTTPS_ROUTING") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'false' ]
}

@test "Deployment/router/https: can be enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'router.https.enabled=true' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_HTTPS_ROUTING") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'true' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_HTTPS_PORT") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '6443' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_HTTPS_HOST") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"fieldRef":{"fieldPath":"status.podIP"}}' ]
}

@test "Deployment/router/https: can be configured with a custom port" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'router.https.enabled=true' \
        --set 'router.https.port=9443' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_HTTPS_PORT") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '9443' ]
}

@test "Deployment/router/dns: disabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DNS_ROUTING") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'false' ]
}

@test "Deployment/router/dns: can be enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'router.dns.enabled=true' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DNS_ROUTING") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'true' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DNS_PORT") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '8091' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DNS_HOST") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"fieldRef":{"fieldPath":"status.podIP"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DNS_TLS") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'false' ]
}

@test "Deployment/router/dns: inherits value from powerdns" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'router.dns.enabled=-' \
        --set 'powerdns.enabled=true' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DNS_ROUTING") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'true' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DNS_PORT") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '8091' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DNS_HOST") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"fieldRef":{"fieldPath":"status.podIP"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DNS_TLS") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'false' ]
}

@test "Deployment/router/dns: can be configured with a custom port" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'router.dns.enabled=true' \
        --set 'router.dns.port=9053' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DNS_PORT") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '9053' ]
}

@test "Deployment/router/dns: can be configured with tls" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'router.dns.enabled=true' \
        --set 'router.dns.tls=true' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DNS_TLS") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'true' ]
}

@test "Deployment/router/extraArgs: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/usr/bin/varnish-controller-router"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .args' |
            tee -a /dev/stderr)
    [ "${actual}" == 'null' ]
}

@test "Deployment/router/extraArgs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set "router.extraArgs[0]=-help" \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/usr/bin/varnish-controller-router"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .args' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-help"]' ]
}

@test "Deployment/router/extraEnvs: can be configured with extra envs" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'router.extraEnvs[0].name=EXTRA_ENV' \
        --set 'router.extraEnvs[0].value=1' \
        --set 'router.extraEnvs[1].name=ANOTHER_EXTRA_ENV' \
        --set 'router.extraEnvs[1].value=2' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "EXTRA_ENV") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '1' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "ANOTHER_EXTRA_ENV") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '2' ]
}

@test "Deployment/router/extraEnvs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'router.enabled=true' \
        --set 'router.extraEnvs.FOO=bar' \
        --set 'router.extraEnvs.BAZ=bax' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "Deployment/router/extraEnvs: can be configured as a templated string" {
    cd "$(chart_dir)"

    local extraEnvs="
- name: RELEASE_NAME
  value: {{ .Release.Name }}
- name: RELEASE_NAMESPACE
  value: {{ .Release.Namespace }}"

    local object=$((helm template \
        --set 'router.enabled=true' \
        --set "router.extraEnvs=${extraEnvs}" \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "RELEASE_NAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAME","value":"release-name"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "RELEASE_NAMESPACE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAMESPACE","value":"default"}' ]
}

@test "Deployment/router/extraEnvs: can be configured as a list" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'router.enabled=true' \
        --set 'router.extraEnvs[0].name=FOO' \
        --set 'router.extraEnvs[0].value=bar' \
        --set 'router.extraEnvs[1].name=BAZ' \
        --set 'router.extraEnvs[1].value=bax' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "Deployment/router/extraEnvs: can be configured as a list of non-value literalFrom" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'router.enabled=true' \
        --set 'router.extraEnvs[0].name=FROM_CONFIGMAP' \
        --set 'router.extraEnvs[0].valueFrom.configMapKeyRef.name=my-configmap' \
        --set 'router.extraEnvs[0].valueFrom.configMapKeyRef.key=my-key' \
        --set 'router.extraEnvs[1].name=FROM_SECRET' \
        --set 'router.extraEnvs[1].valueFrom.secretKeyRef.name=my-secret' \
        --set 'router.extraEnvs[1].valueFrom.secretKeyRef.key=my-key' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "FROM_CONFIGMAP")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_CONFIGMAP","valueFrom":{"configMapKeyRef":{"key":"my-key","name":"my-configmap"}}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .env[]? | select(.name == "FROM_SECRET")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_SECRET","valueFrom":{"secretKeyRef":{"key":"my-key","name":"my-secret"}}}' ]
}

@test "Deployment/router/resources: inherits resources from global and router" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.enabled=true' \
        --set 'global.resources.limits.cpu=100m' \
        --set 'global.resources.requests.cpu=100m' \
        --set 'router.resources.limits.cpu=500m' \
        --set 'router.resources.limits.memory=512Mi' \
        --set 'router.resources.requests.memory=128Mi' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/router/resources: inherits resources from global and router with global as a templated string" {
    cd "$(chart_dir)"

    local resources="
limits:
  cpu: 500m
  memory: 512Mi
requests:
  memory: 128Mi
"

    local actual=$((helm template \
        --set 'router.enabled=true' \
        --set 'global.resources.limits.cpu=100m' \
        --set 'global.resources.requests.cpu=100m' \
        --set "router.resources=${resources}" \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/router/resources: inherits resources from global and router with router as a templated string" {
    cd "$(chart_dir)"

    local resources="
limits:
  cpu: 100m
requests:
  cpu: 100m
"

    local actual=$((helm template \
        --set 'router.enabled=true' \
        --set "global.resources=${resources}" \
        --set 'router.resources.limits.cpu=500m' \
        --set 'router.resources.limits.memory=512Mi' \
        --set 'router.resources.requests.memory=128Mi' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/router/resources: inherits resources from global and router with both as a templated string" {
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
        --set 'router.enabled=true' \
        --set "global.resources=${globalResources}" \
        --set "router.resources=${resources}" \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/router/resources: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.enabled=true' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/router/geoIp: disabled by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.initContainers' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/router/geoIp: disabled, but initContainers still exist when asn is enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set 'router.geoIp.enabled=false' \
        --set 'router.asn.enabled=true' \
        --set 'router.asn.mmdb_url=http://example.com/test.mmdb' \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.initContainers[]? | select(.name == "router-download-geoip-asn") | .command' | tee -a /dev/stderr)

    [ "${actual}" == '["sh","-c","wget -O /etc/varnish-controller-router/asn.mmdb http://example.com/test.mmdb\n"]' ]
}

@test "Deployment/router/geoIp: check initContainers with both geoIp and ASN enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set 'router.geoIp.enabled=true' \
        --set 'router.geoIp.mmdb_url=http://example.com/test.mmdb' \
        --set 'router.asn.enabled=true' \
        --set 'router.asn.mmdb_url=http://example.com/test.mmdb' \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.initContainers[]? | select(.name == "router-download-geoip-asn") | .command' | tee -a /dev/stderr)

    [ "${actual}" == '["sh","-c","wget -O /etc/varnish-controller-router/geoip.mmdb http://example.com/test.mmdb\nwget -O /etc/varnish-controller-router/asn.mmdb http://example.com/test.mmdb\n"]' ]
}

@test "Deployment/router/geoIp: disable explicitly" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.geoIp.enabled=false' \
        --set 'router.geoIp.mmdb_url=http://example.com/test.mmdb' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.initContainers' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/router/geoIp: fail with empty mmdb_url URL" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.geoIp.enabled=true' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"Invalid URL for .Values.router.geoIp.mmdb_url"* ]]
}

@test "Deployment/router/geoIp: fail with invalid mmdb_url URL" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.geoIp.enabled=true' \
        --set 'router.geoIp.mmdb_url=test.mmdb' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"Invalid URL for .Values.router.geoIp.mmdb_url"* ]]
}

@test "Deployment/router/geoIp: test initContainers" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.geoIp.enabled=true' \
        --set 'router.geoIp.mmdb_url=http://example.com/test.mmdb' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.initContainers[]? | select(.name == "router-download-geoip-asn")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"name":"router-download-geoip-asn","image":"busybox:1.36","command":["sh","-c","wget -O /etc/varnish-controller-router/geoip.mmdb http://example.com/test.mmdb\n"],"volumeMounts":[{"name":"release-name-data","mountPath":"/etc/varnish-controller-router"}]}' ]
}

@test "Deployment/router/geoIp: test VARNISH_CONTROLLER_MMDB_FILE environment variable" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.geoIp.enabled=true' \
        --set 'router.geoIp.mmdb_url=http://example.com/test.mmdb' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") | .env[]?|
            select(.name == "VARNISH_CONTROLLER_MMDB_FILE")' | tee -a /dev/stderr)

    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_MMDB_FILE","value":"/etc/varnish-controller-router/geoip.mmdb"}' ]
}

@test "Deployment/router/geoIp: test geoIp volumeMount" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.geoIp.enabled=true' \
        --set 'router.geoIp.mmdb_url=http://example.com/test.mmdb' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") | .volumeMounts[]?| select(.name == "release-name-data")' | tee -a /dev/stderr)

    [ "${actual}" == '{"name":"release-name-data","mountPath":"/etc/varnish-controller-router"}' ]
}

@test "Deployment/router/geoIp: test geoIp volume" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.geoIp.enabled=true' \
        --set 'router.geoIp.mmdb_url=http://example.com/test.mmdb' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.volumes[]? | select(.name == "release-name-data")' | tee -a /dev/stderr)

    [ "${actual}" == '{"name":"release-name-data","emptyDir":{}}' ]
}

@test "Deployment/router/asn: disabled by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.initContainers' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/router/asn: disable explicitly" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.asn.enabled=false' \
        --set 'router.asn.mmdb_url=http://example.com/test.mmdb' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.initContainers' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/router/asn: disabled, but initContainers still exist when geoIp is enabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --set 'router.asn.enabled=false' \
        --set 'router.geoIp.enabled=true' \
        --set 'router.geoIp.mmdb_url=http://example.com/test.mmdb' \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.initContainers[]? | select(.name == "router-download-geoip-asn") | .command' | tee -a /dev/stderr)

    [ "${actual}" == '["sh","-c","wget -O /etc/varnish-controller-router/geoip.mmdb http://example.com/test.mmdb\n"]' ]
}

@test "Deployment/router/asn: fail with empty mmdb_url URL" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.asn.enabled=true' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"Invalid URL for .Values.router.asn.mmdb_url"* ]]
}

@test "Deployment/router/asn: fail with invalid mmdb_url URL" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.asn.enabled=true' \
        --set 'router.asn.mmdb_url=test.mmdb' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"Invalid URL for .Values.router.asn.mmdb_url"* ]]
}

@test "Deployment/router/asn: test initContainers" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.asn.enabled=true' \
        --set 'router.asn.mmdb_url=http://example.com/test.mmdb' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.initContainers[]? | select(.name == "router-download-geoip-asn")' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"name":"router-download-geoip-asn","image":"busybox:1.36","command":["sh","-c","wget -O /etc/varnish-controller-router/asn.mmdb http://example.com/test.mmdb\n"],"volumeMounts":[{"name":"release-name-data","mountPath":"/etc/varnish-controller-router"}]}' ]
}

@test "Deployment/router/asn: test VARNISH_CONTROLLER_MMDB_ASN_FILE environment variable" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.asn.enabled=true' \
        --set 'router.asn.mmdb_url=http://example.com/test.mmdb' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") | .env[]?|
            select(.name == "VARNISH_CONTROLLER_MMDB_ASN_FILE")' | tee -a /dev/stderr)

    [ "${actual}" == '{"name":"VARNISH_CONTROLLER_MMDB_ASN_FILE","value":"/etc/varnish-controller-router/asn.mmdb"}' ]
}

@test "Deployment/router/asn: test asn volumeMount" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.asn.enabled=true' \
        --set 'router.asn.mmdb_url=http://example.com/test.mmdb' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "router") | .volumeMounts[]?| select(.name == "release-name-data")' | tee -a /dev/stderr)

    [ "${actual}" == '{"name":"release-name-data","mountPath":"/etc/varnish-controller-router"}' ]
}

@test "Deployment/router/asn: test asn volume" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'router.asn.enabled=true' \
        --set 'router.asn.mmdb_url=http://example.com/test.mmdb' \
        --namespace default \
        --show-only templates/deployment-router.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.volumes[]? | select(.name == "release-name-data")' | tee -a /dev/stderr)

    [ "${actual}" == '{"name":"release-name-data","emptyDir":{}}' ]
}