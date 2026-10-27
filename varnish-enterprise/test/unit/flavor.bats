#!/usr/bin/env bats

load _helpers

# Renders this chart as the Varnish Cache flavor: a copy of the chart with the
# flavor annotation switched to "cache" and the Enterprise-only values removed,
# which is what the Varnish Cache chart will look like once it shares these
# templates.
setup_file() {
    export ENTERPRISE_ONLY='mse|license|cluster[-_.]|activedns|varnish-controller'
    export CACHE_FLAVOR_DIR="${BATS_FILE_TMPDIR}/chart"
    cp -r "$(chart_dir)" "${CACHE_FLAVOR_DIR}"
    rm -rf "${CACHE_FLAVOR_DIR}/test"
    yq -i '.annotations."varnish.com/flavor" = "cache"' "${CACHE_FLAVOR_DIR}/Chart.yaml"
    yq -i 'del(.cluster) |
        del(.global.natsServer) |
        del(.server.mse) |
        del(.server.mse4) |
        del(.server.agent) |
        del(.server.initAgent) |
        del(.server.licenseSecret) |
        del(.server.baseUrl)' "${CACHE_FLAVOR_DIR}/values.yaml"
}

@test "Flavor: Enterprise chart is flagged as enterprise" {
    cd "$(chart_dir)"
    local actual=$(yq -r '.annotations."varnish.com/flavor"' Chart.yaml)
    [ "${actual}" == "enterprise" ]
}

@test "Flavor/cache: renders without Enterprise-only values" {
    cd "${CACHE_FLAVOR_DIR}"
    for kind in Deployment StatefulSet DaemonSet; do
        helm template \
            --set "server.kind=${kind}" \
            --namespace default \
            . >/dev/null
    done
}

@test "Flavor/cache: renders the shared features without Enterprise-only values" {
    cd "${CACHE_FLAVOR_DIR}"
    for kind in Deployment StatefulSet DaemonSet; do
        helm template \
            --set "server.kind=${kind}" \
            --set 'server.secret=s3cr3t' \
            --set 'server.tls.enabled=true' \
            --set 'server.otel.enabled=true' \
            --set 'server.vcls.routes[0].vclContent=vcl 4.1;' \
            --namespace default \
            . >/dev/null
    done
}

@test "Flavor/cache: does not render Enterprise-only resources and arguments" {
    cd "${CACHE_FLAVOR_DIR}"

    local object
    object=$(helm template \
        --set 'server.kind=StatefulSet' \
        --namespace default \
        .)
    echo "$object" >&2

    # No MSE, MSE4, license, cluster or agent anywhere
    local matches=$(echo "$object" | grep -iE "${ENTERPRISE_ONLY}" || true)
    [ -z "${matches}" ]

    # No storage (-s) or CLI command file (-I) arguments
    local actual=$(echo "$object" |
        yq -r -o=json -I=0 'select(.kind == "StatefulSet") | .spec.template.spec.containers[0].command | (contains(["-s"]) or contains(["-I"]))' |
        tee -a /dev/stderr)
    [ "${actual}" == "false" ]
}

@test "Flavor/cache: ignores Enterprise-only values" {
    cd "${CACHE_FLAVOR_DIR}"

    local object
    object=$(helm template \
        --set 'server.kind=StatefulSet' \
        --set 'cluster.enabled=true' \
        --set 'server.mse4.enabled=true' \
        --set 'server.mse4.persistence.enabled=true' \
        --set 'server.agent.enabled=true' \
        --set 'server.licenseSecret=license' \
        --namespace default \
        .)
    echo "$object" >&2

    local matches=$(echo "$object" | grep -iE "${ENTERPRISE_ONLY}" || true)
    [ -z "${matches}" ]
}
