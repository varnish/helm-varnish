#!/usr/bin/env bats

load _helpers

@test "brainz/HorizontalPodAutoscaler: disabled by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/hpa-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" == "false" ]
}

@test "brainz/HorizontalPodAutoscaler: can be enabled with minReplicas and maxReplicas" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'brainz.autoscaling.enabled=true' \
        --set 'brainz.autoscaling.minReplicas=2' \
        --set 'brainz.autoscaling.maxReplicas=10' \
        --namespace default \
        --show-only templates/hpa-brainz.yaml \
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

@test "brainz/HorizontalPodAutoscaler/behavior: can be set" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'brainz.autoscaling.enabled=true' \
        --set "brainz.autoscaling.behavior.scaleDown.policies[0].type=Pods" \
        --set "brainz.autoscaling.behavior.scaleDown.policies[0].value=4" \
        --set "brainz.autoscaling.behavior.scaleDown.policies[0].periodSeconds=60" \
        --namespace default \
        --show-only templates/hpa-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.behavior' |
        tee -a /dev/stderr)
    [ "${actual}" == '{"scaleDown":{"policies":[{"periodSeconds":60,"type":"Pods","value":4}]}}' ]
}

@test "brainz/HorizontalPodAutoscaler/behavior: can be set as templated string" {
    cd "$(chart_dir)"

    local behavior="
scaleDown:
  policies:
    - type: Pods
      value: {{ 4 }}
      periodSeconds: {{ 60 }}"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'brainz.autoscaling.enabled=true' \
        --set "brainz.autoscaling.behavior=$behavior" \
        --namespace default \
        --show-only templates/hpa-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.behavior' |
        tee -a /dev/stderr)
    [ "${actual}" == '{"scaleDown":{"policies":[{"type":"Pods","value":4,"periodSeconds":60}]}}' ]
}

@test "brainz/HorizontalPodAutoscaler/metrics: can be set" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'brainz.autoscaling.enabled=true' \
        --set "brainz.autoscaling.metrics[0].type=Resource" \
        --set "brainz.autoscaling.metrics[0].resource.name=cpu" \
        --set "brainz.autoscaling.metrics[0].resource.target.type=Utilization" \
        --set "brainz.autoscaling.metrics[0].resource.target.averageUtilization=50" \
        --namespace default \
        --show-only templates/hpa-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.metrics' |
        tee -a /dev/stderr)
    [ "${actual}" == '[{"resource":{"name":"cpu","target":{"averageUtilization":50,"type":"Utilization"}},"type":"Resource"}]' ]
}

@test "brainz/HorizontalPodAutoscaler/metrics: can be set as templated string" {
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
        --set 'brainz.autoscaling.enabled=true' \
        --set "brainz.autoscaling.metrics=$metrics" \
        --namespace default \
        --show-only templates/hpa-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c '.spec.metrics' |
        tee -a /dev/stderr)
    [ "${actual}" == '[{"type":"Resources","resource":{"name":"cpu","target":{"type":"Utilization","averageUtilization":50}}}]' ]
}
