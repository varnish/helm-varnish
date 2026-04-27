#!/usr/bin/env bats

load _helpers

@test "HPA: not rendered when autoscaling disabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/hpa.yaml \
        . || echo "---") | yq -r 'length > 0')
    [ "${actual}" = "false" ]
}

@test "HPA: rendered when autoscaling enabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set autoscaling.enabled=true \
        --namespace default \
        --show-only templates/hpa.yaml \
        .) | yq -r 'length > 0')
    [ "${actual}" = "true" ]
}

@test "HPA: scaleTargetRef defaults to Deployment" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set autoscaling.enabled=true \
        --namespace default \
        --show-only templates/hpa.yaml \
        .) | yq -r '.spec.scaleTargetRef.kind')
    [ "${actual}" = "Deployment" ]
}

@test "HPA: scaleTargetRef follows kind=StatefulSet" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set kind=StatefulSet \
        --set autoscaling.enabled=true \
        --namespace default \
        --show-only templates/hpa.yaml \
        .) | yq -r '.spec.scaleTargetRef.kind')
    [ "${actual}" = "StatefulSet" ]
}

@test "HPA: scaleTargetRef.name follows fullname" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set autoscaling.enabled=true \
        --namespace default \
        --show-only templates/hpa.yaml \
        .) | yq -r '.spec.scaleTargetRef.name')
    [ "${actual}" = "release-name-orca-chart" ]
}

@test "HPA: minReplicas honored" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set autoscaling.enabled=true \
        --set autoscaling.minReplicas=2 \
        --namespace default \
        --show-only templates/hpa.yaml \
        .) | yq -r '.spec.minReplicas')
    [ "${actual}" = "2" ]
}

@test "HPA: maxReplicas honored" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set autoscaling.enabled=true \
        --set autoscaling.maxReplicas=42 \
        --namespace default \
        --show-only templates/hpa.yaml \
        .) | yq -r '.spec.maxReplicas')
    [ "${actual}" = "42" ]
}

@test "HPA: CPU metric default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set autoscaling.enabled=true \
        --namespace default \
        --show-only templates/hpa.yaml \
        .) | yq -r '.spec.metrics[] | select(.resource.name == "cpu") | .resource.target.averageUtilization')
    [ "${actual}" = "80" ]
}

@test "HPA: memory metric included when set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set autoscaling.enabled=true \
        --set autoscaling.targetMemoryUtilizationPercentage=70 \
        --namespace default \
        --show-only templates/hpa.yaml \
        .) | yq -r '.spec.metrics[] | select(.resource.name == "memory") | .resource.target.averageUtilization')
    [ "${actual}" = "70" ]
}
