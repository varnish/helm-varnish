#!/usr/bin/env bats

load _helpers

@test "Cluster: disabled by default, no secret" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/secret.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "false" ]
}

@test "Cluster: disabled by default, no service" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/service.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '. |
               select(.metadata.name != "release-name-varnish-enterprise")' | tee -a /dev/stderr)
    [ "${actual}" = "" ]
}

@test "Cluster: disabled by default, no configmap-vcl.yaml" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "false" ]
}

@test "Cluster: disabled by default, no VARNISH_CLUSTER_TOKEN" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -o=json -I=0 -r '.spec.template.spec.containers[] |
                select(.name == "varnish-enterprise").env[] |
                select(.name == "VARNISH_CLUSTER_TOKEN")' | tee -a /dev/stderr)
    [ "${actual}" = "" ]
}


@test "Cluster: check VARNISH_CLUSTER_TOKEN in default case" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -o=json -I=0 -r '.spec.template.spec.containers[] |
                select(.name == "varnish-enterprise").env[] |
                select(.name == "VARNISH_CLUSTER_TOKEN")' | tee -a /dev/stderr)
    [ "${actual}" = '{"name":"VARNISH_CLUSTER_TOKEN","valueFrom":{"secretKeyRef":{"name":"release-name-varnish-enterprise-cluster-secret","key":"token"}}}' ]
}

@test "Cluster: check configmap in default case" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --namespace default \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -o=json -I=0 -r '.data["wrapped-default.vcl"]' | tee -a /dev/stderr)
    echo "${actual}" | grep 'include "cluster_auto_dns.vcl";'
    echo "${actual}" | grep 'include "/etc/varnish/default.vcl";'
}

@test "Cluster: check VARNISH_CLUSTER_PEER_DOMAIN in default case" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -o=json -I=0 -r '.spec.template.spec.containers[] |
                select(.name == "varnish-enterprise").env[] |
                select(.name == "VARNISH_CLUSTER_PEER_DOMAIN")' | tee -a /dev/stderr)
    [ "${actual}" = '{"name":"VARNISH_CLUSTER_PEER_DOMAIN","value":"release-name-varnish-enterprise-peers:6081"}' ]
}

@test "Cluster: no VARNISH_CLUSTER_TRACE by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -o=json -I=0 -r '.spec.template.spec.containers[] |
                select(.name == "varnish-enterprise").env[] |
                select(.name == "VARNISH_CLUSTER_TRACE")' | tee -a /dev/stderr)
    [ "${actual}" = "" ]
}

@test "Cluster: VARNISH_CLUSTER_TRACE set when trace is enabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'cluster.trace=true' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -o=json -I=0 -r '.spec.template.spec.containers[] |
                select(.name == "varnish-enterprise").env[] |
                select(.name == "VARNISH_CLUSTER_TRACE")' | tee -a /dev/stderr)
    [ "${actual}" = '{"name":"VARNISH_CLUSTER_TRACE","value":"true"}' ]
}

@test "Cluster: check headless service in default case" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --namespace default \
        --show-only templates/service.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -o=json -I=0 -r 'select(.metadata.name == "release-name-varnish-enterprise-peers").spec.ports' | tee -a /dev/stderr)
    [ "${actual}" = '[{"name":"http","port":6081,"targetPort":6081}]' ]
}

@test "Cluster: check secret in default case" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --namespace default \
        --show-only templates/secret.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -o=json -I=0 -r '.data.token' | tee -a /dev/stderr)
    [ "${actual}" != 'null' ]
}

@test "Cluster: check port if using non-default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'server.http.port=9999' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -o=json -I=0 -r '.spec.template.spec.containers[] |
                select(.name == "varnish-enterprise").env[] |
                select(.name == "VARNISH_CLUSTER_PEER_DOMAIN").value' | tee -a /dev/stderr)
    [ "${actual}" = "release-name-varnish-enterprise-peers:9999" ]
}

@test "Cluster: include path changes with vclConfigPath" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'server.vclConfigPath=/etc/varnish/non-default.vcl' \
        --namespace default \
        --show-only templates/configmap-vcl.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -o=json -I=0 -r '.data["wrapped-default.vcl"]' | tee -a /dev/stderr)
    echo "${actual}" | grep 'include "/etc/varnish/non-default.vcl";'
}

@test "Cluster: no headless service if headlessServiceName is set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'cluster.headlessServiceName=foo-service' \
        --namespace default \
        --show-only templates/service.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '. |
               select(.metadata.name != "release-name-varnish-enterprise")' | tee -a /dev/stderr)
    [ "${actual}" = "" ]

    # VARNISH_CLUSTER_PEER_DOMAIN should use foo-service though
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'cluster.headlessServiceName=foo-service' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -o=json -I=0 -r '.spec.template.spec.containers[] |
                select(.name == "varnish-enterprise").env[] |
                select(.name == "VARNISH_CLUSTER_PEER_DOMAIN").value' | tee -a /dev/stderr)
    [ "${actual}" = "foo-service:6081" ]

}

@test "Cluster: no secret if secretName is set" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'cluster.secretName=foo-secret' \
        --namespace default \
        --show-only templates/secret.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "false" ]

    # wrapped-default.vcl should use foo-service though
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'cluster.secretName=foo-secret' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -o=json -I=0 -r '.spec.template.spec.containers[] |
                select(.name == "varnish-enterprise").env[] |
                select(.name == "VARNISH_CLUSTER_TOKEN")' | tee -a /dev/stderr)
    [ "${actual}" = '{"name":"VARNISH_CLUSTER_TOKEN","valueFrom":{"secretKeyRef":{"name":"foo-secret","key":"token"}}}' ]
}

@test "Cluster: server.http.enabled must be true" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'server.http.enabled=false' \
        --namespace default \
        --show-only templates/service.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "false" ]
}



@test "Cluster: no VARNISH_CLUSTER_PRIMARIES/FALLBACK by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -o=json -I=0 -r '.spec.template.spec.containers[] |
                select(.name == "varnish-enterprise").env[] |
                select(.name == "VARNISH_CLUSTER_PRIMARIES" or .name == "VARNISH_CLUSTER_FALLBACK")' | tee -a /dev/stderr)
    [ "${actual}" = "" ]
}

@test "Cluster: VARNISH_CLUSTER_PRIMARIES/FALLBACK set from values" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --set 'cluster.primaries=1000000' \
        --set 'cluster.fallback=0' \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -o=json -I=0 -r '[.spec.template.spec.containers[] |
                select(.name == "varnish-enterprise").env[] |
                select(.name == "VARNISH_CLUSTER_PRIMARIES" or .name == "VARNISH_CLUSTER_FALLBACK")]' | tee -a /dev/stderr)
    [ "${actual}" = '[{"name":"VARNISH_CLUSTER_PRIMARIES","value":"1000000"},{"name":"VARNISH_CLUSTER_FALLBACK","value":"0"}]' ]
}

@test "Cluster: integers from values files are not rendered in float notation" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set 'cluster.enabled=true' \
        --values <(printf 'cluster:\n  primaries: 1000000\n') \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.spec.template.spec.containers[] |
                select(.name == "varnish-enterprise").env[] |
                select(.name == "VARNISH_CLUSTER_PRIMARIES").value' | tee -a /dev/stderr)
    [ "${actual}" = "1000000" ]
}

@test "Cluster: render fails on invalid values" {
    cd "$(chart_dir)"
    for args in \
        "--set cluster.primaries=0" \
        "--set cluster.primaries=-1" \
        "--set cluster.primaries=abc" \
        "--set-json cluster.primaries=2.5" \
        "--set cluster.fallback=-1" \
        "--set cluster.fallback=abc" \
        "--set cluster.trace=yes"; do
        echo "${args}" >&2
        run helm template --set 'cluster.enabled=true' ${args} --namespace default --show-only templates/deployment.yaml .
        [ "${status}" -ne 0 ]
        [[ "${output}" == *"cluster."* ]]
    done
}

@test "Cluster: render fails if extraEnvs sets VARNISH_CLUSTER_* variables" {
    cd "$(chart_dir)"
    run helm template \
        --set 'cluster.enabled=true' \
        --set 'server.extraEnvs.VARNISH_CLUSTER_PRIMARIES=2' \
        --namespace default \
        --show-only templates/deployment.yaml \
        .
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"'VARNISH_CLUSTER_PRIMARIES' is managed by the chart"* ]]

    run helm template \
        --set 'cluster.enabled=true' \
        --set 'server.extraEnvs[0].name=VARNISH_CLUSTER_TOKEN' \
        --set 'server.extraEnvs[0].value=foo' \
        --namespace default \
        --show-only templates/deployment.yaml \
        .
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"'VARNISH_CLUSTER_TOKEN' is managed by the chart"* ]]
}

@test "Cluster: extraEnvs VARNISH_CLUSTER_* allowed when cluster is disabled" {
    cd "$(chart_dir)"
    run helm template \
        --set 'server.extraEnvs.VARNISH_CLUSTER_PRIMARIES=2' \
        --namespace default \
        --show-only templates/deployment.yaml \
        .
    [ "${status}" -eq 0 ]
}
