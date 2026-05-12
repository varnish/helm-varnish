#!/usr/bin/env bats

load _helpers

VCL_CONTENT='vcl 4.1;\nbackend default none;\nsub vcl_recv { return (synth(200)); }'

# ── ConfigMap existence ────────────────────────────────────────────────────────

@test "vcl-bundle: not created when server.vcls.routes is empty" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.metadata.name | test("-vcl-bundle-")) | .metadata.name' \
        | tee -a /dev/stderr | wc -l | tr -d ' ')
    [ "${actual}" = "0" ]
}

@test "vcl-bundle: created when server.vcls.routes is non-empty" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.metadata.name | test("-vcl-bundle-")) | .metadata.name' \
        | tee -a /dev/stderr | wc -l | tr -d ' ')
    [ "${actual}" != "0" ]
}

@test "vcl-bundle: router ConfigMap name is fullname-vcl-bundle-router" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.metadata.name | test("-vcl-bundle-router$")) | .metadata.name' \
        | tee -a /dev/stderr)
    [ "${actual}" = "release-name-varnish-enterprise-vcl-bundle-router" ]
}

# ── Route VCL keys ─────────────────────────────────────────────────────────────

@test "vcl-bundle: route ConfigMap key uses normalized hostname" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("foo_com.vcl")) | .data | has("foo_com.vcl")' \
        | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "vcl-bundle: route key uses explicit name when provided" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].name=my-site" \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("my_site.vcl")) | .data | has("my_site.vcl")' \
        | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "vcl-bundle: route key uses 'any' when no name and no hostnames" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("any.vcl")) | .data | has("any.vcl")' \
        | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "vcl-bundle: non-alnum chars in hostname normalized to underscore" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=*.api.bar.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("__api_bar_com.vcl")) | .data | has("__api_bar_com.vcl")' \
        | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

# ── Routing VCL ───────────────────────────────────────────────────────────────

@test "vcl-bundle: routing VCL contains hostname if-block" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("router.vcl")) | .data."router.vcl"' \
        | tee -a /dev/stderr)
    [[ "${actual}" == *'req.http.No-Port-Host == "foo.com"'* ]]
    [[ "${actual}" == *'return(vcl(foo_com))'* ]]
}

@test "vcl-bundle: routing VCL contains catch-all return for route without hostnames" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vcls.routes[1].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("router.vcl")) | .data."router.vcl"' \
        | tee -a /dev/stderr)
    [[ "${actual}" == *'return(vcl(any))'* ]]
}

@test "vcl-bundle: routing VCL handles multiple hostnames with OR" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].hostnames[1]=www.foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("router.vcl")) | .data."router.vcl"' \
        | tee -a /dev/stderr)
    [[ "${actual}" == *'req.http.No-Port-Host == "foo.com" || req.http.No-Port-Host == "www.foo.com"'* ]]
}

# ── Cmdfile ───────────────────────────────────────────────────────────────────

@test "vcl-bundle: cmdfile contains vcl.load and vcl.label for each route" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("cmds.cli")) | .data."cmds.cli"' \
        | tee -a /dev/stderr)
    [[ "${actual}" == *'vcl.load route_foo_com_0 /etc/varnish/vcls/routes/foo_com.vcl'* ]]
    [[ "${actual}" == *'vcl.label foo_com route_foo_com_0'* ]]
    [[ "${actual}" == *'vcl.load router_0 /etc/varnish/vcls/router.vcl'* ]]
    [[ "${actual}" == *'vcl.use router_0'* ]]
}

# ── Includes ──────────────────────────────────────────────────────────────────

@test "vcl-bundle: include key is plain filename with no prefix" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vcls.includes.helpers\\.vcl=sub common_recv {}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("helpers.vcl")) | .data | has("helpers.vcl")' \
        | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

# ── Conflict checks ───────────────────────────────────────────────────────────

@test "vcl-bundle: error when server.vcls.routes and server.vclConfigPath both set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vclConfigPath=/etc/varnish/custom.vcl" \
        --show-only templates/configmap-vcl.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"Cannot use both 'server.vcls.routes' and 'server.vclConfigPath'"* ]]
}

@test "vcl-bundle: error when server.vcls.routes and server.vclConfig both set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vclConfig=vcl 4.1;" \
        --show-only templates/configmap-vcl.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"Cannot use both 'server.vcls.routes' and 'server.vclConfig'"* ]]
}

@test "vcl-bundle: error when server.vcls.routes and server.vclConfigFile both set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vclConfigFile=files/default.vcl" \
        --show-only templates/configmap-vcl.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"Cannot use both 'server.vcls.routes' and 'server.vclConfigFile'"* ]]
}

@test "vcl-bundle: error when server.vcls.routes and server.vclConfigs both set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vclConfigs.default\\.vcl=vcl 4.1;" \
        --show-only templates/configmap-vcl.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"Cannot use both 'server.vcls.routes' and 'server.vclConfigs'"* ]]
}

@test "vcl-bundle: error when server.vcls.routes and server.cmdfileConfig both set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.cmdfileConfig=vcl.use boot;" \
        --show-only templates/configmap-vcl.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"Cannot use both 'server.vcls.routes' and 'server.cmdfileConfig'"* ]]
}

@test "vcl-bundle: error when server.vcls.routes and server.cmdfileConfigPath both set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.cmdfileConfigPath=/etc/varnish/custom.cli" \
        --show-only templates/configmap-vcl.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"Cannot customize 'server.cmdfileConfigPath' when 'server.vcls.routes' is set"* ]]
}

@test "vcl-bundle: error when server.vcls.includes set without server.vcls.routes" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.includes.helpers\\.vcl=sub common_recv {}" \
        --show-only templates/configmap-vcl.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"'server.vcls.includes' requires 'server.vcls.routes' to be set"* ]]
}

@test "vcl-bundle: error when two routes produce the same normalized name" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vcls.routes[1].hostnames[0]=foo_com" \
        --set "server.vcls.routes[1].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"duplicate normalized name"* ]]
}

@test "vcl-bundle: error when catch-all route is not last" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vcls.routes[1].hostnames[0]=foo.com" \
        --set "server.vcls.routes[1].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"catch-all route (no hostnames) must be the last route"* ]]
}

@test "vcl-bundle: error when route has no vclContent" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --show-only templates/configmap-vcl.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"must set vclContent"* ]]
}

# ── Cluster ───────────────────────────────────────────────────────────────────

@test "vcl-bundle: router.vcl has no cluster code when cluster disabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("router.vcl")) | .data."router.vcl"' | tee -a /dev/stderr)
    [[ "${actual}" != *"import activedns"* ]]
    [[ "${actual}" != *"cluster.vcl"* ]]
    [[ "${actual}" != *"vcl_init"* ]]
}

@test "vcl-bundle: router.vcl imports activedns when cluster enabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "cluster.enabled=true" \
        --set "server.http.enabled=true" \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("router.vcl")) | .data."router.vcl"' | tee -a /dev/stderr)
    [[ "${actual}" == *"import activedns;"* ]]
    [[ "${actual}" == *'include "cluster.vcl";'* ]]
}

@test "vcl-bundle: router.vcl has vcl_init with cluster setup when cluster enabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "cluster.enabled=true" \
        --set "server.http.enabled=true" \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("router.vcl")) | .data."router.vcl"' | tee -a /dev/stderr)
    [[ "${actual}" == *"sub vcl_init {"* ]]
    [[ "${actual}" == *"cluster.subscribe"* ]]
    [[ "${actual}" == *"VARNISH_CLUSTER_TOKEN"* ]]
}

@test "vcl-bundle: router.vcl uses default peers service name when cluster.headlessServiceName unset" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "cluster.enabled=true" \
        --set "server.http.enabled=true" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("router.vcl")) | .data."router.vcl"' | tee -a /dev/stderr)
    [[ "${actual}" == *"-peers:"* ]]
}

@test "vcl-bundle: router.vcl uses cluster.headlessServiceName when set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "cluster.enabled=true" \
        --set "server.http.enabled=true" \
        --set "cluster.headlessServiceName=my-peers-svc" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("router.vcl")) | .data."router.vcl"' | tee -a /dev/stderr)
    [[ "${actual}" == *'"my-peers-svc:'* ]]
}

@test "vcl-bundle: router.vcl includes trace opt when cluster.trace enabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "cluster.enabled=true" \
        --set "server.http.enabled=true" \
        --set "cluster.trace=true" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("router.vcl")) | .data."router.vcl"' | tee -a /dev/stderr)
    [[ "${actual}" == *'cluster_opts.set("trace", "true")'* ]]
}

@test "vcl-bundle: router.vcl has no trace opt when cluster.trace disabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "cluster.enabled=true" \
        --set "server.http.enabled=true" \
        --set "cluster.trace=false" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("router.vcl")) | .data."router.vcl"' | tee -a /dev/stderr)
    [[ "${actual}" != *'"trace"'* ]]
}

# ── Deployment: volumes and mounts ────────────────────────────────────────────

@test "vcl-bundle: deployment has volume for router" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.spec.template.spec.volumes[] | select(.name == "release-name-config-vcl-bundle-router") | .configMap.name' \
        | tee -a /dev/stderr)
    [ "${actual}" = "release-name-varnish-enterprise-vcl-bundle-router" ]
}

@test "vcl-bundle: deployment has volume for cmds" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.spec.template.spec.volumes[] | select(.name == "release-name-config-vcl-bundle-cmds") | .configMap.name' \
        | tee -a /dev/stderr)
    [ "${actual}" = "release-name-varnish-enterprise-vcl-bundle-cmds" ]
}

@test "vcl-bundle: deployment has volume for each route" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.spec.template.spec.volumes[] | select(.name == "release-name-config-vcl-bundle-foo-com") | .configMap.name' \
        | tee -a /dev/stderr)
    [ "${actual}" = "release-name-varnish-enterprise-vcl-bundle-foo-com" ]
}

@test "vcl-bundle: deployment mounts router.vcl with subPath" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '
            .spec.template.spec.containers[] | select(.name == "varnish-enterprise") |
            .volumeMounts[] | select(.name == "release-name-config-vcl-bundle-router") |
            [.mountPath, .subPath] | join(":")' | tee -a /dev/stderr)
    [ "${actual}" = "/etc/varnish/vcls/router.vcl:router.vcl" ]
}

@test "vcl-bundle: deployment mounts cmds.cli with subPath" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '
            .spec.template.spec.containers[] | select(.name == "varnish-enterprise") |
            .volumeMounts[] | select(.name == "release-name-config-vcl-bundle-cmds") |
            [.mountPath, .subPath] | join(":")' | tee -a /dev/stderr)
    [ "${actual}" = "/etc/varnish/vcls/cmds.cli:cmds.cli" ]
}

@test "vcl-bundle: deployment mounts route VCL with subPath" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '
            .spec.template.spec.containers[] | select(.name == "varnish-enterprise") |
            .volumeMounts[] | select(.name == "release-name-config-vcl-bundle-foo-com") |
            [.mountPath, .subPath] | join(":")' | tee -a /dev/stderr)
    [ "${actual}" = "/etc/varnish/vcls/routes/foo_com.vcl:foo_com.vcl" ]
}

@test "vcl-bundle: ConfigMap has cmds.cli key" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("cmds.cli")) | .data | has("cmds.cli")' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "vcl-bundle: ConfigMap has router.vcl key" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("router.vcl")) | .data | has("router.vcl")' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "vcl-bundle: varnishd -f arg is empty string when routes and cluster both set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "cluster.enabled=true" \
        --set "server.http.enabled=true" \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '
            .spec.template.spec.containers[] | select(.name == "varnish-enterprise") |
            .command | join(" ")' | tee -a /dev/stderr)
    [[ "${actual}" == *"-f "* ]]
    [[ "${actual}" != *"wrapped-default"* ]]
}

@test "vcl-bundle: wrapped-default.vcl not mounted when routes and cluster both set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "cluster.enabled=true" \
        --set "server.http.enabled=true" \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '
            .spec.template.spec.containers[] | select(.name == "varnish-enterprise") |
            .volumeMounts[] | select(.name | test("wrapped-default")) | .name' \
        | tee -a /dev/stderr)
    [ "${actual}" = "" ]
}

@test "vcl-bundle: varnishd -f arg is empty string when routes set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '
            .spec.template.spec.containers[] | select(.name == "varnish-enterprise") |
            .command | join(" ")' | tee -a /dev/stderr)
    [[ "${actual}" == *"-f "* ]]
}


@test "vcl-bundle: error when include filename contains invalid characters" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vcls.includes.sub!helpers\\.vcl=sub common_recv {}" \
        --show-only templates/configmap-vcl.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"contains invalid characters"* ]]
}

@test "vcl-bundle: include with subdirectory path mounts under includes/" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vcls.includes.sub/helpers\\.vcl=sub common_recv {}" \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '
            .spec.template.spec.containers[] | select(.name == "varnish-enterprise") |
            .volumeMounts[] | select(.name | test("bundle-include")) |
            [.mountPath, .subPath] | join(":")' | tee -a /dev/stderr)
    [ "${actual}" = "/etc/varnish/vcls/includes/sub/helpers.vcl:helpers.vcl" ]
}

@test "vcl-bundle: include ConfigMap data key uses basename only" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vcls.includes.sub/helpers\\.vcl=sub common_recv {}" \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'select(.data | has("helpers.vcl")) | .data | has("helpers.vcl")' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "vcl-bundle: deployment passes -I flag in varnishd command" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '
            .spec.template.spec.containers[] | select(.name == "varnish-enterprise") |
            .command | join(" ")' | tee -a /dev/stderr)
    [[ "${actual}" == *"-I /etc/varnish/vcls/cmds.cli"* ]]
}

@test "vcl-bundle: deployment includes checksum annotation for bundle" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.spec.template.metadata.annotations | has("checksum/release-name-vcl-bundle")' \
        | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}
