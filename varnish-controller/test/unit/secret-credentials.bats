#!/usr/bin/env bats

load _helpers

@test "secretCredentials: created by default" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --show-only templates/secret-credentials.yaml \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.data."nats-varnish-password"' | tee -a /dev/stderr)
    [ "${actual}" != "" ]

    local actual=$(echo "$object" | yq -r -c '.data."postgresql-admin-password"' | tee -a /dev/stderr)
    [ "${actual}" != "" ]

    local actual=$(echo "$object" | yq -r -c '.data."postgresql-varnish-password"' | tee -a /dev/stderr)
    [ "${actual}" != "" ]

    local actual=$(echo "$object" | yq -r -c '.data."varnish-admin-password"' | tee -a /dev/stderr)
    [ "${actual}" != "" ]
}

@test "secretCredentials: can be disabled" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --show-only templates/secret-credentials.yaml \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'secretCredentials.create=false' \
        --namespace default \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)

    [ "${actual}" == "false" ]
}

@test "secretCredentials: nats-varnish-password is disabled when internal nats is disabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --show-only templates/secret-credentials.yaml \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'nats.enabled=false' \
        --namespace default \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.data."nats-varnish-password"' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]
}

@test "secretCredentials: postgresql-admin-password and postgresql-varnish-password are disabled when internal postgresql is disabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --show-only templates/secret-credentials.yaml \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'postgresql.enabled=false' \
        --namespace default \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.data."postgresql-admin-password"' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]

    local actual=$(echo "$object" | yq -r -c '.data."postgresql-varnish-password"' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]
}

@test "secretCredentials: postgresql-admin-password and postgresql-varnish-password are disabled when postgresql.auth.existingSecret is set" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --show-only templates/secret-credentials.yaml \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'postgresql.auth.existingSecret=something-else' \
        --namespace default \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.data."postgresql-admin-password"' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]

    local actual=$(echo "$object" | yq -r -c '.data."postgresql-varnish-password"' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]
}

@test "secretCredentials: varnish-admin-password is disabled when brainz.modAdminUser.password is set" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --show-only templates/secret-credentials.yaml \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --set 'brainz.modAdminUser.password=Passw0rd!' \
        --namespace default \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -r -c '.data."varnish-admin-password"' | tee -a /dev/stderr)
    [ "${actual}" == "null" ]
}
