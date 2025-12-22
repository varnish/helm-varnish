#!/usr/bin/env bats

load _helpers

@test "Deployment: enabled by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" = "true" ]
}

@test "Config: can set http port" {
    cd "$(chart_dir)"

    run helm template --set=orca.varnish.http[0].port=123  . --show-only templates/deployment.yaml

    [ $status -eq 0 ]

    echo "$output"

    [ "$(echo "$output" | yq '.spec.template.spec.containers[0].ports[] | select(.name == "http") | .containerPort' -r)" == "123" ] # Deployment port

    run helm template --set=orca.varnish.http[0].port=123  . --show-only templates/configmap.yaml

    echo "$output"

    [ $status -eq 0 ]

    [ "$(echo "$output" | yq '.data["config.yaml"]' -r | yq '.varnish.http[0].port' -r)" == "123" ] # Configmap port
}
