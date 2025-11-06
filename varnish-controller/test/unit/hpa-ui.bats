#!/usr/bin/env bats

load _helpers

@test "ui/HorizontalPodAutoscaler: disabled by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/hpa-ui.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" == "false" ]
}

@test "ui/HorizontalPodAutoscaler: can be enabled with minReplicas and maxReplicas" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'ui.autoscaling.enabled=true' \
        --set 'ui.autoscaling.minReplicas=2' \
        --set 'ui.autoscaling.maxReplicas=10' \
        --namespace default \
        --show-only templates/hpa-ui.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c 'length > 0' |
        tee -a /dev/stderr)
    [ "${actual}" == "true" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.minReplicas' |
        tee -a /dev/stderr)
    [ "${actual}" == "2" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.maxReplicas' |
        tee -a /dev/stderr)
    [ "${actual}" == "10" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.maxReplicas | type' |
        tee -a /dev/stderr)
    [ "${actual}" == "number" ]
}

@test "ui/HorizontalPodAutoscaler/behavior: can be set" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'ui.autoscaling.enabled=true' \
        --set "ui.autoscaling.behavior.scaleDown.policies[0].type=Pods" \
        --set "ui.autoscaling.behavior.scaleDown.policies[0].value=4" \
        --set "ui.autoscaling.behavior.scaleDown.policies[0].periodSeconds=60" \
        --namespace default \
        --show-only templates/hpa-ui.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.behavior' |
        tee -a /dev/stderr)
    [ "${actual}" == '{"scaleDown":{"policies":[{"periodSeconds":60,"type":"Pods","value":4}]}}' ]
}

@test "ui/HorizontalPodAutoscaler/behavior: can be set as templated string" {
    cd "$(chart_dir)"

    local behavior="
scaleDown:
  policies:
    - type: Pods
      value: {{ 4 }}
      periodSeconds: {{ 60 }}"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'ui.autoscaling.enabled=true' \
        --set "ui.autoscaling.behavior=$behavior" \
        --namespace default \
        --show-only templates/hpa-ui.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.behavior' |
        tee -a /dev/stderr)
    [ "${actual}" == '{"scaleDown":{"policies":[{"type":"Pods","value":4,"periodSeconds":60}]}}' ]
}

@test "ui/HorizontalPodAutoscaler/metrics: can be set" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'ui.autoscaling.enabled=true' \
        --set "ui.autoscaling.metrics[0].type=Resource" \
        --set "ui.autoscaling.metrics[0].resource.name=cpu" \
        --set "ui.autoscaling.metrics[0].resource.target.type=Utilization" \
        --set "ui.autoscaling.metrics[0].resource.target.averageUtilization=50" \
        --namespace default \
        --show-only templates/hpa-ui.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.metrics' |
        tee -a /dev/stderr)
    [ "${actual}" == '[{"resource":{"name":"cpu","target":{"averageUtilization":50,"type":"Utilization"}},"type":"Resource"}]' ]
}

@test "ui/HorizontalPodAutoscaler/metrics: can be set as templated string" {
    cd "$(chart_dir)"

    local metrics="
- type: Resources
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: {{ 50 }}"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'ui.autoscaling.enabled=true' \
        --set "ui.autoscaling.metrics=$metrics" \
        --namespace default \
        --show-only templates/hpa-ui.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.metrics' |
        tee -a /dev/stderr)
    [ "${actual}" == '[{"type":"Resources","resource":{"name":"cpu","target":{"type":"Utilization","averageUtilization":50}}}]' ]
}
