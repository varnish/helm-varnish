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
