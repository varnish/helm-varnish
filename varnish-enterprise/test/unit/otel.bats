#!/usr/bin/env bats

load _helpers

@test "Deployment/otel: disabled by default" {
    cd "$(chart_dir)"
    local object=$((helm template \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r '.spec.template.spec.containers[]? | select(.name == "varnish-enterprise-otel") | .name' |
        tee -a /dev/stderr)

    [ "${actual}" == "" ]
}

@test "Deployment/otel: can be enabled" {
    cd "$(chart_dir)"
    local object=$((helm template \
        --set 'server.otel.enabled=true' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r '.spec.template.spec.containers[]? | select(.name == "varnish-enterprise-otel") | .name' |
        tee -a /dev/stderr)

    [ "${actual}" == "varnish-enterprise-otel" ]
}

@test "Deployment/otel: uses correct command" {
    cd "$(chart_dir)"
    local object=$((helm template \
        --set 'server.otel.enabled=true' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r '.spec.template.spec.containers[]? | select(.name == "varnish-enterprise-otel") | .command[0]' |
        tee -a /dev/stderr)

    [ "${actual}" == "/usr/bin/varnish-otel" ]
}

@test "Deployment/otel: can configure environment variables" {
    cd "$(chart_dir)"
    local object=$((helm template \
        --set 'server.otel.enabled=true' \
        --set 'server.otel.env.OTEL_EXPORTER_OTLP_ENDPOINT=http://datadog:4317' \
        --set 'server.otel.env.OTEL_SERVICE_NAME=varnish' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local endpoint=$(echo "$object" |
        yq -r '.spec.template.spec.containers[]? | select(.name == "varnish-enterprise-otel") | .env[]? | select(.name == "OTEL_EXPORTER_OTLP_ENDPOINT") | .value' |
        tee -a /dev/stderr)

    local service=$(echo "$object" |
        yq -r '.spec.template.spec.containers[]? | select(.name == "varnish-enterprise-otel") | .env[]? | select(.name == "OTEL_SERVICE_NAME") | .value' |
        tee -a /dev/stderr)

    [ "${endpoint}" == "http://datadog:4317" ]
    [ "${service}" == "varnish" ]
}

@test "Deployment/otel: mounts varnish vsm volume" {
    cd "$(chart_dir)"
    local object=$((helm template \
        --set 'server.otel.enabled=true' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r '.spec.template.spec.containers[] | select(.name == "varnish-enterprise-otel") | .volumeMounts[] | select(.mountPath == "/var/lib/varnish") | .mountPath' |
        tee -a /dev/stderr)

    [ "${actual}" = "/var/lib/varnish" ]
}

@test "Deployment/otel: mounts config-shared volume" {
    cd "$(chart_dir)"
    local object=$((helm template \
        --set 'server.otel.enabled=true' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r '.spec.template.spec.containers[] | select(.name == "varnish-enterprise-otel") | .volumeMounts[] | select(.mountPath == "/etc/varnish/shared") | .mountPath' |
        tee -a /dev/stderr)

    [ "${actual}" = "/etc/varnish/shared" ]
}

@test "Deployment/otel: can configure custom image" {
    cd "$(chart_dir)"
    local object=$((helm template \
        --set 'server.otel.enabled=true' \
        --set 'server.otel.image.repository=custom/varnish-otel' \
        --set 'server.otel.image.tag=custom-tag' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r '.spec.template.spec.containers[]? | select(.name == "varnish-enterprise-otel") | .image' |
        tee -a /dev/stderr)

    [ "${actual}" == "custom/varnish-otel:custom-tag" ]
}

@test "Deployment/otel: inherits image from server by default" {
    cd "$(chart_dir)"
    local object=$((helm template \
        --set 'server.otel.enabled=true' \
        --set 'server.image.repository=quay.io/varnish-software/varnish-plus' \
        --set 'server.image.tag=6.0.16r3' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r '.spec.template.spec.containers[]? | select(.name == "varnish-enterprise-otel") | .image' |
        tee -a /dev/stderr)

    [ "${actual}" == "quay.io/varnish-software/varnish-plus:6.0.16r3" ]
}

@test "Deployment/otel: can configure resources" {
    cd "$(chart_dir)"
    local object=$((helm template \
        --set 'server.otel.enabled=true' \
        --set 'server.otel.resources.limits.cpu=200m' \
        --set 'server.otel.resources.limits.memory=256Mi' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local cpu=$(echo "$object" |
        yq -r '.spec.template.spec.containers[]? | select(.name == "varnish-enterprise-otel") | .resources.limits.cpu' |
        tee -a /dev/stderr)

    local memory=$(echo "$object" |
        yq -r '.spec.template.spec.containers[]? | select(.name == "varnish-enterprise-otel") | .resources.limits.memory' |
        tee -a /dev/stderr)

    [ "${cpu}" == "200m" ]
    [ "${memory}" == "256Mi" ]
}

@test "StatefulSet/otel: can be enabled" {
    cd "$(chart_dir)"
    local object=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.otel.enabled=true' \
        --namespace default \
        --show-only templates/statefulset.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r '.spec.template.spec.containers[]? | select(.name == "varnish-enterprise-otel") | .name' |
        tee -a /dev/stderr)

    [ "${actual}" == "varnish-enterprise-otel" ]
}

@test "DaemonSet/otel: can be enabled" {
    cd "$(chart_dir)"
    local object=$((helm template \
        --set 'server.kind=DaemonSet' \
        --set 'server.otel.enabled=true' \
        --namespace default \
        --show-only templates/daemonset.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r '.spec.template.spec.containers[]? | select(.name == "varnish-enterprise-otel") | .name' |
        tee -a /dev/stderr)

    [ "${actual}" == "varnish-enterprise-otel" ]
}
