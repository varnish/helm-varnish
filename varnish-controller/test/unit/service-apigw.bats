#!/usr/bin/env bats

load _helpers

@test "Service/apigw/annotations: not configured by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/service-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.metadata.annotations' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]
}

@test "Service/apigw/annotations: can be configured" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set "apigw.service.annotations.hello=world" \
        --namespace default \
        --show-only templates/service-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.metadata.annotations' | tee -a /dev/stderr)
    [ "${actual}" == '{"hello":"world"}' ]
}

@test "Service/apigw/annotations: can be configured as a templated string" {
    cd "$(chart_dir)"

    local annotations='
release-name: {{ .Release.Name }}
'

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set "apigw.service.annotations=${annotations}" \
        --namespace default \
        --show-only templates/service-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.metadata.annotations' | tee -a /dev/stderr)
    [ "${actual}" == '{"release-name":"release-name"}' ]
}
