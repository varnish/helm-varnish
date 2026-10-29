#!/usr/bin/env bats

load _helpers

@test "RBAC: Role grants read access to endpoints" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --namespace default \
        --show-only templates/role.yaml \
        .) | yqj '.rules[0]')
    [ "${actual}" = '{"apiGroups":[""],"resources":["endpoints","pods"],"verbs":["get","list","watch"]}' ]
}

@test "RBAC: RoleBinding targets the service account" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --set serviceAccount.name=my-sa \
        --namespace my-ns \
        --show-only templates/rolebinding.yaml \
        .) | yqj '.subjects')
    [ "${actual}" = '[{"kind":"ServiceAccount","name":"my-sa","namespace":"my-ns"}]' ]
}

@test "RBAC: can be disabled" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --set rbac.create=false \
        --namespace default \
        . ) | yq -r 'select(.kind == "Role" or .kind == "RoleBinding") | .kind')
    [ -z "${actual}" ]
}

@test "ServiceAccount: used by the pod" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --set discovery.groups={varnish} \
        --set serviceAccount.name=my-sa \
        --namespace default \
        --show-only templates/deployment.yaml \
        .) | yq -r '.spec.template.spec.serviceAccountName')
    [ "${actual}" = "my-sa" ]
}
