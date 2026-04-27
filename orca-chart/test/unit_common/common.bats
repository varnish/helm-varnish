#!/usr/bin/env bats

# These tests run against both Deployment and StatefulSet via run.sh, which
# sets `kind` and `template` env vars per iteration.

load _helpers

@test "${kind}: rendered with kind=${kind}" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --namespace default \
        --show-only "${template}" \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "${kind}: image uses values" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'image.repository=docker.io/varnish/orca-test' \
        --set 'image.tag=v1.2.3' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -r '.spec.template.spec.containers[0].image')
    [ "${actual}" = "docker.io/varnish/orca-test:v1.2.3" ]
}

@test "${kind}: image tag falls back to AppVersion" {
    cd "$(chart_dir)"
    local app_ver
    app_ver=$(app_version)
    local actual=$((helm template \
        --set "kind=${kind}" \
        --namespace default \
        --show-only "${template}" \
        .) | yq -r '.spec.template.spec.containers[0].image')
    [ "${actual}" = "docker.io/varnish/orca:${app_ver}" ]
}

@test "${kind}: imagePullPolicy is configurable" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'image.pullPolicy=Always' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -r '.spec.template.spec.containers[0].imagePullPolicy')
    [ "${actual}" = "Always" ]
}

@test "${kind}: imagePullSecrets applied" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'imagePullSecrets[0].name=my-pull-secret' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '.spec.template.spec.imagePullSecrets')
    [ "${actual}" = '[{"name":"my-pull-secret"}]' ]
}

@test "${kind}: serviceAccountName uses default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --namespace default \
        --show-only "${template}" \
        .) | yq -r '.spec.template.spec.serviceAccountName')
    [ "${actual}" = "release-name-orca-chart" ]
}

@test "${kind}: serviceAccountName uses custom name" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'serviceAccount.name=my-sa' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -r '.spec.template.spec.serviceAccountName')
    [ "${actual}" = "my-sa" ]
}

@test "${kind}: HTTP port renders" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '.spec.template.spec.containers[0].ports[] | select(.name == "http")')
    [ "${actual}" = '{"name":"http","containerPort":80,"protocol":"TCP"}' ]
}

@test "${kind}: HTTP port configurable" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'orca.varnish.http[0].port=8080' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -r '.spec.template.spec.containers[0].ports[] | select(.name == "http") | .containerPort')
    [ "${actual}" = "8080" ]
}

@test "${kind}: multiple HTTP ports get suffixed names" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'orca.varnish.http[0].port=80' \
        --set 'orca.varnish.http[1].port=8080' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '[.spec.template.spec.containers[0].ports[].name]')
    [ "${actual}" = '["http-80","http-8080"]' ]
}

@test "${kind}: HTTPS port renders when configured" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'orca.varnish.https[0].port=443' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '.spec.template.spec.containers[0].ports[] | select(.name == "https")')
    [ "${actual}" = '{"name":"https","containerPort":443,"protocol":"TCP"}' ]
}

@test "${kind}: resources applied" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'resources.limits.cpu=500m' \
        --set 'resources.requests.memory=256Mi' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '.spec.template.spec.containers[0].resources')
    [ "${actual}" = '{"limits":{"cpu":"500m"},"requests":{"memory":"256Mi"}}' ]
}

@test "${kind}: securityContext applied" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'securityContext.runAsUser=1000' \
        --set 'securityContext.runAsNonRoot=true' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '.spec.template.spec.containers[0].securityContext')
    [ "${actual}" = '{"runAsNonRoot":true,"runAsUser":1000}' ]
}

@test "${kind}: podSecurityContext applied" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'podSecurityContext.fsGroup=2000' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '.spec.template.spec.securityContext')
    [ "${actual}" = '{"fsGroup":2000}' ]
}

@test "${kind}: podAnnotations applied" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'podAnnotations.foo=bar' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -r '.spec.template.metadata.annotations.foo')
    [ "${actual}" = "bar" ]
}

@test "${kind}: podLabels applied" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'podLabels.tier=cache' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -r '.spec.template.metadata.labels.tier')
    [ "${actual}" = "cache" ]
}

@test "${kind}: nodeSelector applied" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'nodeSelector.disktype=ssd' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '.spec.template.spec.nodeSelector')
    [ "${actual}" = '{"disktype":"ssd"}' ]
}

@test "${kind}: tolerations applied" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'tolerations[0].key=role' \
        --set 'tolerations[0].operator=Equal' \
        --set 'tolerations[0].value=cache' \
        --set 'tolerations[0].effect=NoSchedule' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '.spec.template.spec.tolerations')
    [ "${actual}" = '[{"effect":"NoSchedule","key":"role","operator":"Equal","value":"cache"}]' ]
}

@test "${kind}: affinity applied" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey=kubernetes.io/hostname' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -r '.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey')
    [ "${actual}" = "kubernetes.io/hostname" ]
}

@test "${kind}: extraEnvs as map" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'extraEnvs.MY_VAR=my-value' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '.spec.template.spec.containers[0].env[] | select(.name == "MY_VAR")')
    [ "${actual}" = '{"name":"MY_VAR","value":"my-value"}' ]
}

@test "${kind}: extraEnvs as list" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'extraEnvs[0].name=MY_VAR' \
        --set 'extraEnvs[0].value=my-value' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '.spec.template.spec.containers[0].env[] | select(.name == "MY_VAR")')
    [ "${actual}" = '{"name":"MY_VAR","value":"my-value"}' ]
}

@test "${kind}: user volumeMounts applied" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'volumeMounts[0].name=my-vol' \
        --set 'volumeMounts[0].mountPath=/mount/path' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "my-vol")')
    [ "${actual}" = '{"mountPath":"/mount/path","name":"my-vol"}' ]
}

@test "${kind}: user volumes applied" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'volumes[0].name=my-vol' \
        --set 'volumes[0].persistentVolumeClaim.claimName=my-pvc' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '.spec.template.spec.volumes[] | select(.name == "my-vol")')
    [ "${actual}" = '{"name":"my-vol","persistentVolumeClaim":{"claimName":"my-pvc"}}' ]
}

@test "${kind}: orca-config volume always mounted" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "orca-config")')
    [ "${actual}" = '{"name":"orca-config","mountPath":"/etc/varnish-supervisor/config.yaml","subPath":"config.yaml"}' ]
}

@test "${kind}: command points at supervisor" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '.spec.template.spec.containers[0].command')
    [ "${actual}" = '["/usr/bin/varnish-supervisor","--config","/etc/varnish-supervisor/config.yaml"]' ]
}

@test "${kind}: license secret mounts orca-license" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set "kind=${kind}" \
        --set 'orca.license.secret=my-license-secret' \
        --namespace default \
        --show-only "${template}" \
        .) | yq -o=json -I=0 '.spec.template.spec.volumes[] | select(.name == "orca-license")')
    [ "${actual}" = '{"name":"orca-license","secret":{"secretName":"my-license-secret","items":[{"key":"license.lic","path":"license.lic"}]}}' ]
}
