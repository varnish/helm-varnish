#!/usr/bin/env bats

load _helpers

@test "Deployment/brainz: enabled by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.containers[]? | select(.name == "brainz")' |
            tee -a /dev/stderr)
    [ "${actual}" != "" ]
}

@test "Deployment/brainz: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.enabled=false' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.containers[]? | select(.name == "brainz")' |
            tee -a /dev/stderr)
    [ "${actual}" == "" ]
}

@test "Deployment/brainz: inherits securityContext from global and brainz with global as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set "global.securityContext=${securityContext}" \
        --set 'brainz.securityContext.runAsUser=1000' \
        --set 'brainz.securityContext.foo=bar' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .securityContext' | tee -a /dev/stderr)

    [ "${actual}" == '{"foo":"bar","release-name":"release-name","release-namespace":"default","runAsUser":1000}' ]
}

@test "Deployment/brainz: inherits securityContext from global and brainz with brainz as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local actual=$((helm template \
        --set 'global.securityContext.hello=world' \
        --set "brainz.securityContext=${securityContext}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"hello":"world","release-name":"release-name","release-namespace":"default","runAsNonRoot":true,"runAsUser":999}' ]
}

@test "Deployment/brainz: inherits securityContext from global and brainz with both as a templated string" {
    cd "$(chart_dir)"

    local securityContext="
release-name: {{ .Release.Name }}
release-namespace: to-be-override
"

    local actual=$((helm template \
        --set "global.securityContext=${securityContext}" \
        --set 'brainz.securityContext=release-namespace: {{ .Release.Namespace }}' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .securityContext' | tee -a /dev/stderr)

    # Note: values.yaml has 'global.securityContext.runAsNonRoot=true' as the default;
    # we're testing that the values are merged and not replaced.
    [ "${actual}" == '{"release-name":"release-name","release-namespace":"default"}' ]
}

@test "Deployment/brainz: inherits nats configuration from global" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '$(VARNISH_CONTROLLER_NATS_USER):$(VARNISH_CONTROLLER_NATS_PASS)@$(VARNISH_CONTROLLER_NATS_HOST)' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"varnish-controller-credentials","key":"nats-varnish-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'release-name-nats.default.svc.cluster.local:4222' ]
}

@test "Deployment/brainz: inherits nats configuration from global with external secret" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'global.natsServer.internal.passwordFrom.name=external-secret' \
        --set 'global.natsServer.internal.passwordFrom.key=nats-password' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '$(VARNISH_CONTROLLER_NATS_USER):$(VARNISH_CONTROLLER_NATS_PASS)@$(VARNISH_CONTROLLER_NATS_HOST)' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"external-secret","key":"nats-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'release-name-nats.default.svc.cluster.local:4222' ]
}

@test "Deployment/brainz: inherits nats configuration from internal nats" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'global.natsServer.internal.enabled=-' \
        --set 'nats.enabled=true' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '$(VARNISH_CONTROLLER_NATS_USER):$(VARNISH_CONTROLLER_NATS_PASS)@$(VARNISH_CONTROLLER_NATS_HOST)' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"varnish-controller-credentials","key":"nats-varnish-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'release-name-nats.default.svc.cluster.local:4222' ]
}

@test "Deployment/brainz: inherits nats configuration from global with overridden values" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'global.natsServer.internal.namespace=varnish-controller' \
        --set 'global.natsServer.internal.releaseName=test' \
        --set 'global.natsServer.internal.clusterDomain=remote.local' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == '$(VARNISH_CONTROLLER_NATS_USER):$(VARNISH_CONTROLLER_NATS_PASS)@$(VARNISH_CONTROLLER_NATS_HOST)' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"varnish-controller-credentials","key":"nats-varnish-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'test-nats.varnish-controller.svc.remote.local:4222' ]
}

@test "Deployment/brainz: inherits nats configuration from global with external nats" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'global.natsServer.externalAddress=nats.local:4222' \
        --set 'global.natsServer.internal.enabled=false' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_HOST")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_USER")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_PASS")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_NATS_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'nats.local:4222' ]
}

@test "Deployment/brainz: cannot disable both external and internal nats" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'global.natsServer.externalAddress=' \
        --set 'global.natsServer.internal.enabled=false' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"Either 'global.natsServer.internal.enabled' or 'global.natsServer.externalAddress' must be set"* ]]
}

@test "Deployment/brainz: cannot disable both external and internal nats with inherited value" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'global.natsServer.externalAddress=' \
        --set 'global.natsServer.internal.enabled=-' \
        --set 'nats.enabled=false' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"Either 'global.natsServer.internal.enabled' or 'global.natsServer.externalAddress' must be set"* ]]
}

@test "Deployment/brainz/image: inherits tag from appVersion" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.image' |
            tee -a /dev/stderr)
    [ "${actual}" = "quay.io/varnish-software/varnish-controller-brainz:$(app_version)" ]

    local actual=$(echo "$container" |
        yq -r -c '.imagePullPolicy' |
            tee -a /dev/stderr)
    [ "${actual}" = "IfNotPresent" ]
}

@test "Deployment/brainz/image: inherits tag and pullPolicy from global" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'global.controller.image.tag=latest' \
        --set 'global.controller.image.pullPolicy=Always' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.image' |
            tee -a /dev/stderr)
    [ "${actual}" == "quay.io/varnish-software/varnish-controller-brainz:latest" ]

    local actual=$(echo "$container" |
        yq -r -c '.imagePullPolicy' |
            tee -a /dev/stderr)
    [ "${actual}" == "Always" ]
}

@test "Deployment/brainz/image: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.image.repository=docker-repo.local/varnish-software/varnish-controller-brainz' \
        --set 'brainz.image.tag=latest' \
        --set 'brainz.image.pullPolicy=Always' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local container=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz")' |
            tee -a /dev/stderr)

    local actual=$(echo "$container" |
        yq -r -c '.image' |
            tee -a /dev/stderr)
    [ "${actual}" == "docker-repo.local/varnish-software/varnish-controller-brainz:latest" ]

    local actual=$(echo "$container" |
        yq -r -c '.imagePullPolicy' |
            tee -a /dev/stderr)
    [ "${actual}" == "Always" ]
}

@test "Deployment/brainz: inherits imagePullSecret from global" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'global.imagePullSecrets[0].name=quay.io-varnish-software' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.imagePullSecrets' | tee -a /dev/stderr)
    [ "${actual}" == '[{"name":"quay.io-varnish-software"}]' ]
}

@test "Deployment/brainz: can enable serviceAccount" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'serviceAccount.create=true' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.serviceAccountName' | tee -a /dev/stderr)
    [ "${actual}" == "release-name-varnish-controller" ]
}

@test "Deployment/brainz: use default serviceAccount when disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'serviceAccount.create=false' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.serviceAccountName' | tee -a /dev/stderr)
    [ "${actual}" == "default" ]
}

@test "Deployment/brainz: inherits annotations from brainz" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.annotations.hello=varnish' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "Deployment/brainz: inherits annotations from brainz as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.annotations=hello: {{ .Release.Name }}' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "Deployment/brainz: inherits podAnnotations from server" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.podAnnotations.hello=varnish' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish" ]
}

@test "Deployment/brainz: inherits podAnnotations from server as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.podAnnotations=hello: {{ .Release.Name }}' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.metadata.annotations.hello' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "Deployment/brainz: inherits podLabels from global and brainz" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'global.podLabels.foo=bar' \
        --set 'brainz.podLabels.hello=varnish' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-controller-brainz","foo":"bar","hello":"varnish"}' ]
}

@test "Deployment/brainz: inherits podLabels from global and brainz with global as templated string" {
    cd "$(chart_dir)"

    local labels="
release-name: {{ .Release.Name }}
release-namespace: to-be-override
"

    local object=$((helm template \
        --set "global.podLabels=${labels}" \
        --set 'brainz.podLabels.release-namespace=varnish' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-controller-brainz","release-name":"release-name","release-namespace":"varnish"}' ]
}

@test "Deployment/brainz: inherits podLabels from global and brainz with brainz as templated string" {
    cd "$(chart_dir)"

    local labels="
release-name: {{ .Release.Name }}
release-namespace: {{ .Release.Namespace }}
"

    local object=$((helm template \
        --set 'global.podLabels.release-namespace=to-be-override' \
        --set "brainz.podLabels=${labels}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels' |
            tee -a /dev/stderr)

    [ "${actual}" == '{"app.kubernetes.io/instance":"release-name","app.kubernetes.io/name":"varnish-controller-brainz","release-name":"release-name","release-namespace":"default"}' ]
}

@test "Deployment/brainz: inherits default selector labels" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    # .metadata.labels

    local actual=$(echo "$object" |
        yq -r -c '.metadata.labels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish-controller-brainz" ]

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
    [ "${actual}" == "varnish-controller-brainz" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.selector.matchLabels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]

    # .spec.template.metadata.labels

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels."app.kubernetes.io/name"' |
            tee -a /dev/stderr)
    [ "${actual}" == "varnish-controller-brainz" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.template.metadata.labels."app.kubernetes.io/instance"' |
            tee -a /dev/stderr)
    [ "${actual}" == "release-name" ]
}

@test "Deployment/brainz/nodeSelector: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.nodeSelector.tier=edge' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == '{"tier":"edge"}' ]
}

@test "Deployment/brainz/nodeSelector: can be as templated string" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.nodeSelector=tier: {{ .Release.Name }}-edge' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == '{"tier":"release-name-edge"}' ]
}

@test "Deployment/brainz/nodeSelector: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.nodeSelector' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/brainz/tolerations: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.tolerations[0].key=far-network-disk' \
        --set 'brainz.tolerations[0].operator=Exists' \
        --set 'brainz.tolerations[0].effect=NoSchedule' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == '[{"effect":"NoSchedule","key":"far-network-disk","operator":"Exists"}]' ]
}

@test "Deployment/brainz/tolerations: can be configured as templated string" {
    cd "$(chart_dir)"

    local tolerations='
- key: ban-{{ .Release.Name }}
  operator: Exists
  effect: NoSchedule
'

    local actual=$((helm template \
        --set "brainz.tolerations=${tolerations}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == '[{"key":"ban-release-name","operator":"Exists","effect":"NoSchedule"}]' ]
}

@test "Deployment/brainz/tolerations: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.tolerations' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}

@test "Deployment/brainz/affinity: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchLabels.foo=bar' \
        --set 'brainz.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey=kubernetes.io/hostname' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.affinity' | tee -a /dev/stderr)

    [ "${actual}" == '{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"foo":"bar"}},"topologyKey":"kubernetes.io/hostname"}]}}' ]
}

@test "Deployment/brainz/affinity: can be configured as templated string" {
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
        --set "brainz.affinity=${affinity}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.template.spec.affinity' | tee -a /dev/stderr)

    [ "${actual}" == '{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"app.kubernetes.io/name":"varnish-controller","app.kubernetes.io/instance":"release-name"}},"topologyKey":"kubernetes.io/hostname"}]}}' ]
}

@test "Deployment/brainz/strategy: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.strategy=' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == "null" ]
}

@test "Deployment/brainz/strategy: can be configured" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.strategy.type=RollingUpdate' \
        --set 'brainz.strategy.rollingUpdate.maxUnavailable=1' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"rollingUpdate":{"maxUnavailable":1},"type":"RollingUpdate"}' ]
}

@test "Deployment/brainz/strategy: can be configured as templated string" {
    cd "$(chart_dir)"

    local strategy='
type: RollingUpdate
rollingUpdate:
  maxUnavailable: {{ 1 }}
'

    local actual=$((helm template \
        --set "brainz.strategy=$strategy" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '.spec.strategy' | tee -a /dev/stderr)

    [ "${actual}" == '{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":1}}' ]
}

@test "Deployment/brainz/modAdminUser: enabled by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.modAdminUser.enabled=true' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") | .args' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-mod-admin-user"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_SYSTEM_ADMIN_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'admin' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_SYSTEM_ADMIN_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"varnish-controller-credentials","key":"varnish-admin-password"}}' ]
}

@test "Deployment/brainz/modAdminUser: can be configured with custom password" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.modAdminUser.enabled=true' \
        --set 'brainz.modAdminUser.username=admin' \
        --set 'brainz.modAdminUser.password=passw0rd' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") | .args' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-mod-admin-user"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_SYSTEM_ADMIN_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'admin' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_SYSTEM_ADMIN_PASS") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'passw0rd' ]
}

@test "Deployment/brainz/modAdminUser: can be configured with external secret" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.modAdminUser.enabled=true' \
        --set 'brainz.modAdminUser.username=admin' \
        --set 'brainz.modAdminUser.passwordFrom.name=external-secret' \
        --set 'brainz.modAdminUser.passwordFrom.key=varnish-controller-password' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") | .args' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-mod-admin-user"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_SYSTEM_ADMIN_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'admin' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_SYSTEM_ADMIN_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"external-secret","key":"varnish-controller-password"}}' ]
}

@test "Deployment/brainz/modAdminUser: cannot be configured with both custom password and external secret" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.modAdminUser.enabled=true' \
        --set 'brainz.modAdminUser.username=admin' \
        --set 'brainz.modAdminUser.password=passw0rd' \
        --set 'brainz.modAdminUser.passwordFrom.name=external-secret' \
        --set 'brainz.modAdminUser.passwordFrom.key=varnish-controller-password' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"Either 'brainz.modAdminUser.password' or 'brainz.modAdminUser.passwordFrom' can be set"* ]]
}

@test "Deployment/brainz/modAdminUser: cannot be configured with external secret without name" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.modAdminUser.enabled=true' \
        --set 'brainz.modAdminUser.username=admin' \
        --set 'brainz.modAdminUser.passwordFrom.key=varnish-controller-password' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"'brainz.modAdminUser.passwordFrom' must contain a 'name' key"* ]]
}

@test "Deployment/brainz/modAdminUser: cannot be configured with external secret without key" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.modAdminUser.enabled=true' \
        --set 'brainz.modAdminUser.username=admin' \
        --set 'brainz.modAdminUser.passwordFrom.name=external-secret' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"'brainz.modAdminUser.passwordFrom' must contain a 'key' key"* ]]
}

@test "Deployment/brainz/modAdminUser: can be disabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.modAdminUser.enabled=false' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") | .args' |
            tee -a /dev/stderr)
    [ "${actual}" == 'null' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_SYSTEM_ADMIN_USER")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_SYSTEM_ADMIN_PASS")' |
            tee -a /dev/stderr)
    [ "${actual}" == '' ]
}

@test "Deployment/brainz/internalPostgres: can be enabled with external secret" {
   cd "$(chart_dir)"

    local object=$((helm template \
        --set 'postgresql.auth.existingSecret=external-secret' \
        --set 'postgresql.auth.secretKeys.userPasswordKey=postgresql-password' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_NAME") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish_controller' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'release-name-postgresql.default.svc.cluster.local' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"external-secret","key":"postgresql-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_SSL") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'disable' ]
}

@test "Deployment/brainz/externalPostgres: can be enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'postgresql.enabled=false' \
        --set 'brainz.externalPostgresql.database=varnish-controller' \
        --set 'brainz.externalPostgresql.host=vc-postgresql:5432' \
        --set 'brainz.externalPostgresql.user=varnish' \
        --set 'brainz.externalPostgresql.password=passw0rd' \
        --set 'brainz.externalPostgresql.tls=false' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_NAME") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'vc-postgresql:5432' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_PASS") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'passw0rd' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_SSL") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'disable' ]
}

@test "Deployment/brainz/externalPostgres: can be enabled with tls" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'postgresql.enabled=false' \
        --set 'brainz.externalPostgresql.database=varnish-controller' \
        --set 'brainz.externalPostgresql.host=vc-postgresql:5432' \
        --set 'brainz.externalPostgresql.user=varnish' \
        --set 'brainz.externalPostgresql.password=passw0rd' \
        --set 'brainz.externalPostgresql.tls=true' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_SSL") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'require' ]
}

@test "Deployment/brainz/externalPostgres: can be enabled without tls" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'postgresql.enabled=false' \
        --set 'brainz.externalPostgresql.database=varnish-controller' \
        --set 'brainz.externalPostgresql.host=vc-postgresql:5432' \
        --set 'brainz.externalPostgresql.user=varnish' \
        --set 'brainz.externalPostgresql.password=passw0rd' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_SSL") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'disable' ]
}

@test "Deployment/brainz/externalPostgres: can be enabled with external secret" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'postgresql.enabled=false' \
        --set 'brainz.externalPostgresql.database=varnish-controller' \
        --set 'brainz.externalPostgresql.host=vc-postgresql:5432' \
        --set 'brainz.externalPostgresql.user=varnish' \
        --set 'brainz.externalPostgresql.passwordFrom.name=external-secret' \
        --set 'brainz.externalPostgresql.passwordFrom.key=postgresql-password' \
        --set 'brainz.externalPostgresql.tls=true' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_NAME") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish-controller' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_SERVER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'vc-postgresql:5432' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_USER") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'varnish' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_PASS") | .valueFrom' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"secretKeyRef":{"name":"external-secret","key":"postgresql-password"}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "VARNISH_CONTROLLER_DB_SSL") | .value' |
            tee -a /dev/stderr)
    [ "${actual}" == 'require' ]
}

@test "Deployment/brainz/externalPostgresql: cannot be configured with password and external secret" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'postgresql.enabled=false' \
        --set 'brainz.externalPostgresql.database=varnish-controller' \
        --set 'brainz.externalPostgresql.host=vc-postgresql:5432' \
        --set 'brainz.externalPostgresql.user=varnish' \
        --set 'brainz.externalPostgresql.password=passw0rd' \
        --set 'brainz.externalPostgresql.passwordFrom.name=external-secret' \
        --set 'brainz.externalPostgresql.passwordFrom.key=postgresql-password' \
        --set 'brainz.externalPostgresql.tls=true' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"Either 'brainz.externalPostgresql.password' or 'brainz.externalPostgresql.passwordFrom' can be set"* ]]
}

@test "Deployment/brainz/externalPostgresql: cannot be configured without database" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'postgresql.enabled=false' \
        --set 'brainz.externalPostgresql.host=vc-postgresql:5432' \
        --set 'brainz.externalPostgresql.user=varnish' \
        --set 'brainz.externalPostgresql.password=passw0rd' \
        --set 'brainz.externalPostgresql.tls=true' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"External PostgreSQL database name must be set: 'brainz.externalPostgresql.database'"* ]]
}

@test "Deployment/brainz/externalPostgresql: cannot be configured without host" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'postgresql.enabled=false' \
        --set 'brainz.externalPostgresql.database=varnish-controller' \
        --set 'brainz.externalPostgresql.user=varnish' \
        --set 'brainz.externalPostgresql.password=passw0rd' \
        --set 'brainz.externalPostgresql.tls=true' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"External PostgreSQL host must be set: 'brainz.externalPostgresql.host'"* ]]
}

@test "Deployment/brainz/externalPostgresql: cannot be configured without user" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'postgresql.enabled=false' \
        --set 'brainz.externalPostgresql.database=varnish-controller' \
        --set 'brainz.externalPostgresql.host=vc-postgresql:5432' \
        --set 'brainz.externalPostgresql.password=passw0rd' \
        --set 'brainz.externalPostgresql.tls=true' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"External PostgreSQL user must be set: 'brainz.externalPostgresql.user'"* ]]
}

@test "Deployment/brainz/externalPostgresql: cannot be configured with external secret without key" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'postgresql.enabled=false' \
        --set 'brainz.externalPostgresql.database=varnish-controller' \
        --set 'brainz.externalPostgresql.host=vc-postgresql:5432' \
        --set 'brainz.externalPostgresql.user=varnish' \
        --set 'brainz.externalPostgresql.passwordFrom.name=external-secret' \
        --set 'brainz.externalPostgresql.tls=true' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"'brainz.externalPostgresql.passwordFrom' must contain a 'key' key"* ]]
}

@test "Deployment/brainz/externalPostgresql: cannot be configured with external secret without name" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'postgresql.enabled=false' \
        --set 'brainz.externalPostgresql.database=varnish-controller' \
        --set 'brainz.externalPostgresql.host=vc-postgresql:5432' \
        --set 'brainz.externalPostgresql.user=varnish' \
        --set 'brainz.externalPostgresql.passwordFrom.key=postgresql-password' \
        --set 'brainz.externalPostgresql.tls=true' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"'brainz.externalPostgresql.passwordFrom' must contain a 'name' key"* ]]
}

@test "Deployment/brainz/extraEnvs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'brainz.extraEnvs.FOO=bar' \
        --set 'brainz.extraEnvs.BAZ=bax' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "Deployment/brainz/extraArgs: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'brainz.modAdminUser.enabled=false' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/usr/bin/varnish-controller-brainz"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .args' |
            tee -a /dev/stderr)
    [ "${actual}" == 'null' ]
}

@test "Deployment/brainz/extraArgs: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'brainz.modAdminUser.enabled=false' \
        --set "brainz.extraArgs[0]=-help" \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/usr/bin/varnish-controller-brainz"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .args' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-help"]' ]
}

@test "Deployment/brainz/extraArgs: can be configured with modAdminUser" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'brainz.modAdminUser.enabled=true' \
        --set "brainz.extraArgs[0]=-help" \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .command' |
            tee -a /dev/stderr)
    [ "${actual}" == '["/usr/bin/varnish-controller-brainz"]' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .args' |
            tee -a /dev/stderr)
    [ "${actual}" == '["-mod-admin-user","-help"]' ]
}

@test "Deployment/brainz/extraEnvs: can be configured as a templated string" {
    cd "$(chart_dir)"

    local extraEnvs="
- name: RELEASE_NAME
  value: {{ .Release.Name }}
- name: RELEASE_NAMESPACE
  value: {{ .Release.Namespace }}"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set "brainz.extraEnvs=${extraEnvs}" \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "RELEASE_NAME")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAME","value":"release-name"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "RELEASE_NAMESPACE")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"RELEASE_NAMESPACE","value":"default"}' ]
}

@test "Deployment/brainz/extraEnvs: can be configured as a list" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'brainz.extraEnvs[0].name=FOO' \
        --set 'brainz.extraEnvs[0].value=bar' \
        --set 'brainz.extraEnvs[1].name=BAZ' \
        --set 'brainz.extraEnvs[1].value=bax' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "FOO")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FOO","value":"bar"}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "BAZ")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"BAZ","value":"bax"}' ]
}

@test "Deployment/brainz/extraEnvs: can be configured as a list of non-value literalFrom" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'brainz.extraEnvs[0].name=FROM_CONFIGMAP' \
        --set 'brainz.extraEnvs[0].valueFrom.configMapKeyRef.name=my-configmap' \
        --set 'brainz.extraEnvs[0].valueFrom.configMapKeyRef.key=my-key' \
        --set 'brainz.extraEnvs[1].name=FROM_SECRET' \
        --set 'brainz.extraEnvs[1].valueFrom.secretKeyRef.name=my-secret' \
        --set 'brainz.extraEnvs[1].valueFrom.secretKeyRef.key=my-key' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "FROM_CONFIGMAP")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_CONFIGMAP","valueFrom":{"configMapKeyRef":{"key":"my-key","name":"my-configmap"}}}' ]

    local actual=$(echo "$object" |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .env[]? | select(.name == "FROM_SECRET")' |
            tee -a /dev/stderr)
    [ "${actual}" == '{"name":"FROM_SECRET","valueFrom":{"secretKeyRef":{"key":"my-key","name":"my-secret"}}}' ]
}

@test "Deployment/brainz/resources: inherits resources from global and brainz" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'global.resources.limits.cpu=100m' \
        --set 'global.resources.requests.cpu=100m' \
        --set 'brainz.resources.limits.cpu=500m' \
        --set 'brainz.resources.limits.memory=512Mi' \
        --set 'brainz.resources.requests.memory=128Mi' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/brainz/resources: inherits resources from global and brainz with global as a templated string" {
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
        --set "brainz.resources=${resources}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/brainz/resources: inherits resources from global and brainz with brainz as a templated string" {
    cd "$(chart_dir)"

    local resources="
limits:
  cpu: 100m
requests:
  cpu: 100m
"

    local actual=$((helm template \
        --set "global.resources=${resources}" \
        --set 'brainz.resources.limits.cpu=500m' \
        --set 'brainz.resources.limits.memory=512Mi' \
        --set 'brainz.resources.requests.memory=128Mi' \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/brainz/resources: inherits resources from global and brainz with both as a templated string" {
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
        --set "brainz.resources=${resources}" \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}' ]
}

@test "Deployment/brainz/resources: not configured by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r -c '
            .spec.template.spec.containers[]? | select(.name == "brainz") |
            .resources' | tee -a /dev/stderr)

    [ "${actual}" == 'null' ]
}
