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

@test "Deployment: test volumeMounts" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set=volumeMounts[0].name=volumeName \
        --set=volumeMounts[0].mountPath=/mount/path \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -c '.spec.template.spec.containers[0].volumeMounts[] | select (.name == "volumeName")' | tee -a /dev/stderr)
    [ "${actual}" = '{"mountPath":"/mount/path","name":"volumeName"}' ]
}

@test "Deployment: test volumes" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --set=volumes[0].name=volumeName \
        --set=volumes[0].persistentVolumeClaim.claimName=asd \
        --show-only templates/deployment.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -c '.spec.template.spec.volumes[] | select (.name == "volumeName")' | tee -a /dev/stderr)
    [ "${actual}" = '{"name":"volumeName","persistentVolumeClaim":{"claimName":"asd"}}' ]
}
