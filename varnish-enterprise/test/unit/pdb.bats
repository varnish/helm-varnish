#!/usr/bin/env bats

load _helpers

@test "PodDisruptionBudget: disabled by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/pdb.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" == "false" ]
}

@test "PodDisruptionBudget: can be enabled with minAvailable" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.pdb.enabled=true' \
        --set 'server.pdb.minAvailable=30%' \
        --namespace default \
        --show-only templates/pdb.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c 'length > 0' |
        tee -a /dev/stderr)
    [ "${actual}" == "true" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.minAvailable' |
        tee -a /dev/stderr)
    [ "${actual}" == "30%" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.minAvailable | type' |
        tee -a /dev/stderr)
    [ "${actual}" == "string" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.maxUnavailable' |
        tee -a /dev/stderr)
    [ "${actual}" == "null" ]
}

# Kubernetes only accept minAvailable as a string only for percent.
@test "PodDisruptionBudget: can be enabled with minAvailable as a number" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.pdb.enabled=true' \
        --set 'server.pdb.minAvailable=5' \
        --namespace default \
        --show-only templates/pdb.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c 'length > 0' |
        tee -a /dev/stderr)
    [ "${actual}" == "true" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.minAvailable' |
        tee -a /dev/stderr)
    [ "${actual}" == "5" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.minAvailable | type' |
        tee -a /dev/stderr)
    [ "${actual}" == "number" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.maxUnavailable' |
        tee -a /dev/stderr)
    [ "${actual}" == "null" ]
}

@test "PodDisruptionBudget: can be enabled with maxUnavailable" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.pdb.enabled=true' \
        --set 'server.pdb.maxUnavailable=30%' \
        --namespace default \
        --show-only templates/pdb.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c 'length > 0' |
        tee -a /dev/stderr)
    [ "${actual}" == "true" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.minAvailable' |
        tee -a /dev/stderr)
    [ "${actual}" == "null" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.maxUnavailable' |
        tee -a /dev/stderr)
    [ "${actual}" == "30%" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.maxUnavailable | type' |
        tee -a /dev/stderr)
    [ "${actual}" == "string" ]
}

# Kubernetes only accept maxUnavailable as a string only for percent.
@test "PodDisruptionBudget: can be enabled with maxUnavailable as a number" {
    cd "$(chart_dir)"

    local object=$((helm template \
        --set 'server.pdb.enabled=true' \
        --set 'server.pdb.maxUnavailable=5' \
        --namespace default \
        --show-only templates/pdb.yaml \
        . || echo "---") | tee -a /dev/stderr)

    local actual=$(echo "$object" |
        yq -r -c 'length > 0' |
        tee -a /dev/stderr)
    [ "${actual}" == "true" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.minAvailable' |
        tee -a /dev/stderr)
    [ "${actual}" == "null" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.maxUnavailable' |
        tee -a /dev/stderr)
    [ "${actual}" == "5" ]

    local actual=$(echo "$object" |
        yq -r -c '.spec.maxUnavailable | type' |
        tee -a /dev/stderr)
    [ "${actual}" == "number" ]
}

@test "PodDisruptionBudget: cannot be enabled without minAvailable or maxUnavailable" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.pdb.enabled=true' \
        --namespace default \
        --show-only templates/pdb.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)
    [[ "${actual}" == *"'server.pdb.minAvailable' or 'server.pdb.maxUnavailable' must be set"* ]]
}
