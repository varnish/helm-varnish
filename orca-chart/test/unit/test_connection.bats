#!/usr/bin/env bats

load _helpers

@test "Test hook: targets the HTTP service port" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/tests/test-connection.yaml \
        .) | yqj '.spec.containers[0].args')
    [ "${actual}" = '["release-name-orca-chart:80"]' ]
}

@test "Test hook: follows a configured HTTP service port" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'service.http.port=8080' \
        --namespace default \
        --show-only templates/tests/test-connection.yaml \
        .) | yqj '.spec.containers[0].args')
    [ "${actual}" = '["release-name-orca-chart:8080"]' ]
}

# Matches the `default 80` the Services apply, so an override that drops the
# port cannot render a bare trailing colon here while the Service says 80.
@test "Test hook: falls back to 80 when the port is unset" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'service.http.port=null' \
        --namespace default \
        --show-only templates/tests/test-connection.yaml \
        .) | yqj '.spec.containers[0].args')
    [ "${actual}" = '["release-name-orca-chart:80"]' ]
}
