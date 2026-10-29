#!/usr/bin/env bats

load _helpers

# The Varnish Cache chart shares its templates with the Varnish Enterprise
# chart. These check that no Enterprise-only feature leaks into it.
ENTERPRISE_ONLY='mse|license|cluster[-_.]|activedns|varnish-controller'

@test "Flavor: Cache chart is flagged as cache" {
    cd "$(chart_dir)"
    local actual=$(yq -r '.annotations.flavor' Chart.yaml)
    [ "${actual}" == "cache" ]
}

@test "Flavor: does not render Enterprise-only resources and arguments" {
    cd "$(chart_dir)"

    for kind in Deployment StatefulSet DaemonSet; do
        local object
        object=$(helm template \
            --set "server.kind=${kind}" \
            --namespace default \
            . 2>/dev/null)
        echo "$object" >&2

        local matches=$(echo "$object" | grep -iE "${ENTERPRISE_ONLY}" || true)
        [ -z "${matches}" ]

        # No storage (-s) argument, Varnish Cache uses its default storage
        local actual=$(echo "$object" |
            yq -r -o=json -I=0 "select(.kind == \"${kind}\") | .spec.template.spec.containers[0].command | contains([\"-s\"])" |
            tee -a /dev/stderr)
        [ "${actual}" == "false" ]
    done
}

@test "Flavor: rejects Enterprise-only values" {
    cd "$(chart_dir)"

    for value in \
        'cluster.enabled=true' \
        'server.mse.enabled=true' \
        'server.mse4.enabled=true' \
        'server.agent.enabled=true' \
        'server.initAgent.enabled=true' \
        'server.licenseSecret=license' \
        'server.baseUrl=http://example.com'; do
        run helm template --set "${value}" --namespace default .
        [ "$status" -ne 0 ]
        [[ "$output" == *"false schema"* ]]
    done
}

@test "Flavor: shutdown_delay delayed shutdown is rejected" {
    cd "$(chart_dir)"

    run helm template \
        --set 'server.delayedShutdown.method=shutdown_delay' \
        --namespace default \
        .
    [ "$status" -ne 0 ]
    [[ "$output" == *"'shutdown_delay' requires Varnish Enterprise"* ]]
}
