#!/usr/bin/env bats

load _helpers

VCL_CONTENT='vcl 4.1;\nbackend default none;\nsub vcl_recv { return (synth(200)); }'

# ── ConfigMap existence ────────────────────────────────────────────────────────

@test "vcl-bundle: not created when server.vcls.routes is empty" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/configmap-vcl-bundle.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "false" ]
}

@test "vcl-bundle: created when server.vcls.routes is non-empty" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "vcl-bundle: name is fullname-vcl-bundle" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.metadata.name' | tee -a /dev/stderr)
    [ "${actual}" = "release-name-varnish-enterprise-vcl-bundle" ]
}

# ── Route VCL keys ─────────────────────────────────────────────────────────────

@test "vcl-bundle: route key uses route- prefix with normalized hostname" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.data | has("route-foo_com.vcl")' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "vcl-bundle: route key uses explicit name when provided" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].name=my-site" \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.data | has("route-my_site.vcl")' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "vcl-bundle: route key uses 'any' when no name and no hostnames" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.data | has("route-any.vcl")' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "vcl-bundle: non-alnum chars in hostname normalized to underscore" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=*.api.bar.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.data | has("route-__api_bar_com.vcl")' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

# ── Routing VCL ───────────────────────────────────────────────────────────────

@test "vcl-bundle: routing VCL contains hostname if-block" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '."data"."router.vcl"' | tee -a /dev/stderr)
    [[ "${actual}" == *'req.http.host == "foo.com"'* ]]
    [[ "${actual}" == *'return(vcl(foo_com))'* ]]
}

@test "vcl-bundle: routing VCL contains catch-all return for route without hostnames" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vcls.routes[1].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '."data"."router.vcl"' | tee -a /dev/stderr)
    [[ "${actual}" == *'return(vcl(any))'* ]]
}

@test "vcl-bundle: routing VCL handles multiple hostnames with OR" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].hostnames[1]=www.foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '."data"."router.vcl"' | tee -a /dev/stderr)
    [[ "${actual}" == *'req.http.host == "foo.com" || req.http.host == "www.foo.com"'* ]]
}

# ── Cmdfile ───────────────────────────────────────────────────────────────────

@test "vcl-bundle: cmdfile contains vcl.load and vcl.label for each route" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.data."cmds.cli"' | tee -a /dev/stderr)
    [[ "${actual}" == *'vcl.load route_foo_com_0 /etc/varnish/vcls/route-foo_com.vcl'* ]]
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
        --show-only templates/configmap-vcl-bundle.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.data | has("helpers.vcl")' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

# ── Conflict checks ───────────────────────────────────────────────────────────

@test "vcl-bundle: error when server.vcls.routes and server.vclConfigPath both set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vclConfigPath=/etc/varnish/custom.vcl" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"Cannot use both 'server.vcls.routes' and 'server.vclConfigPath'"* ]]
}

@test "vcl-bundle: error when server.vcls.routes and server.vclConfig both set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vclConfig=vcl 4.1;" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"Cannot use both 'server.vcls.routes' and 'server.vclConfig'"* ]]
}

@test "vcl-bundle: error when server.vcls.routes and server.vclConfigFile both set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vclConfigFile=files/default.vcl" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"Cannot use both 'server.vcls.routes' and 'server.vclConfigFile'"* ]]
}

@test "vcl-bundle: error when server.vcls.routes and server.vclConfigs both set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vclConfigs.default\\.vcl=vcl 4.1;" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"Cannot use both 'server.vcls.routes' and 'server.vclConfigs'"* ]]
}

@test "vcl-bundle: error when server.vcls.routes and server.cmdfileConfig both set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.cmdfileConfig=vcl.use boot;" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"Cannot use both 'server.vcls.routes' and 'server.cmdfileConfig'"* ]]
}

@test "vcl-bundle: error when server.vcls.routes and server.cmdfileConfigPath both set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.cmdfileConfigPath=/etc/varnish/custom.cli" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"Cannot customize 'server.cmdfileConfigPath' when 'server.vcls.routes' is set"* ]]
}

@test "vcl-bundle: error when server.vcls.includes set without server.vcls.routes" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.includes.helpers\\.vcl=sub common_recv {}" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"'server.vcls.includes' requires 'server.vcls.routes' to be set"* ]]
}

@test "vcl-bundle: error when route has no vclContent" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"must set vclContent"* ]]
}

# ── Deployment: volumes and mounts ────────────────────────────────────────────

@test "vcl-bundle: deployment has volume for vcl-bundle" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.spec.template.spec.volumes[] | select(.name == "release-name-config-vcl-bundle") | .configMap.name' \
        | tee -a /dev/stderr)
    [ "${actual}" = "release-name-varnish-enterprise-vcl-bundle" ]
}

@test "vcl-bundle: deployment has single directory mount for bundle (no subPath)" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '
            .spec.template.spec.containers[] | select(.name == "varnish-enterprise") |
            .volumeMounts[] | select(.name == "release-name-config-vcl-bundle") |
            [.mountPath, (.subPath // "none")] | join(":")' | tee -a /dev/stderr)
    [ "${actual}" = "/etc/varnish/vcls:none" ]
}

@test "vcl-bundle: volume has no items (flat mount)" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '
            .spec.template.spec.volumes[] | select(.name == "release-name-config-vcl-bundle") |
            .configMap.items // "none"' | tee -a /dev/stderr)
    [ "${actual}" = "none" ]
}

@test "vcl-bundle: ConfigMap has cmds.cli key" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.data | has("cmds.cli")' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "vcl-bundle: ConfigMap has router.vcl key" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].hostnames[0]=foo.com" \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.data | has("router.vcl")' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
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

@test "vcl-bundle: error when include filename starts with route-" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vcls.includes.route-helpers\\.vcl=sub common_recv {}" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"must not start with 'route-'"* ]]
}

@test "vcl-bundle: error when include filename contains invalid characters" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set "server.vcls.routes[0].vclContent=${VCL_CONTENT}" \
        --set "server.vcls.includes.sub/helpers\\.vcl=sub common_recv {}" \
        --show-only templates/configmap-vcl-bundle.yaml \
        . 2>&1 || true) | tee -a /dev/stderr)
    [[ "${actual}" == *"contains invalid characters"* ]]
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
