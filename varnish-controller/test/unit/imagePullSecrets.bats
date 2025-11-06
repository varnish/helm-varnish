#!/usr/bin/env bats

load _helpers

@test "Valid imagepullsecret: Postgres subchart" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --set 'global.imagePullSecrets[0].name=pullSecretValue' \
        --show-only=charts/postgresql/templates/primary/statefulset.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.spec.template.spec.imagePullSecrets[0].name' | tee -a /dev/stderr)
    [ "${actual}" == "pullSecretValue" ]
}

@test "Valid imagepullsecret: API-GW" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --set 'global.imagePullSecrets[0].name=pullSecretValue' \
        --show-only templates/deployment-apigw.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.spec.template.spec.imagePullSecrets[0].name' | tee -a /dev/stderr)
    [ "${actual}" == "pullSecretValue" ]
}

@test "Valid imagepullsecret: Brainz" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --set 'global.imagePullSecrets[0].name=pullSecretValue' \
        --show-only templates/deployment-brainz.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.spec.template.spec.imagePullSecrets[0].name' | tee -a /dev/stderr)
    [ "${actual}" == "pullSecretValue" ]
}

@test "Valid imagepullsecret: UI" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --set 'global.imagePullSecrets[0].name=pullSecretValue' \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.spec.template.spec.imagePullSecrets[0].name' | tee -a /dev/stderr)
    [ "${actual}" == "pullSecretValue" ]
}

