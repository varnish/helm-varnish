#!/usr/bin/env bats

load _helpers

@test "NetworkPolicy: disabled by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/networkpolicy.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" == "false" ]
}

@test "NetworkPolicy: allows all ingress and egress by default when enabled" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.networkPolicy.enabled=true' \
        --namespace default \
        --show-only templates/networkpolicy.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.podSelector.matchLabels' |
        tee -a /dev/stderr)
    [ "${actual}" == '{"app.kubernetes.io/name":"'"$(chart_name)"'","app.kubernetes.io/instance":"release-name"}' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.policyTypes' |
        tee -a /dev/stderr)
    [ "${actual}" == '["Ingress","Egress"]' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.ingress' |
        tee -a /dev/stderr)
    [ "${actual}" == '[{}]' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.egress' |
        tee -a /dev/stderr)
    [ "${actual}" == '[{}]' ]
}

@test "NetworkPolicy: can be configured with extraIngress and extraEgress" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.networkPolicy.enabled=true' \
        --set 'server.networkPolicy.allowIngress=false' \
        --set 'server.networkPolicy.allowEgress=false' \
        --set 'server.networkPolicy.extraIngress[0].from[0].podSelector.matchLabels.component=frontend' \
        --set 'server.networkPolicy.extraEgress[0].to[0].podSelector.matchLabels.component=backend' \
        --set 'server.networkPolicy.extraEgress[0].ports[0].port=80' \
        --namespace default \
        --show-only templates/networkpolicy.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.ingress' |
        tee -a /dev/stderr)
    [ "${actual}" == '[{"from":[{"podSelector":{"matchLabels":{"component":"frontend"}}}]}]' ]

    local actual=$(echo "$object" |
        yq -r -o=json -I=0 '.spec.egress' |
        tee -a /dev/stderr)
    [ "${actual}" == '[{"ports":[{"port":80}],"to":[{"podSelector":{"matchLabels":{"component":"backend"}}}]}]' ]
}
