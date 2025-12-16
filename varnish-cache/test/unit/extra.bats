#!/usr/bin/env bats

load _helpers

@test "extraManifests: disabled by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --namespace default \
        --show-only templates/extra.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" == "false" ]
}

@test "extraManifests: can be enabled as templated string" {
    cd "$(chart_dir)"

    cat <<EOF > "$BATS_RUN_TMPDIR"/values-"$BATS_TEST_NUMBER".yaml
extraManifests:
  - name: clusterrole
    data: |
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: {{ .Release.Name }}-clusterrole
      rules:
        - apiGroups: [""]
          resources: ["endpoints"]
          verbs: ["get", "list", "watch"]
  - name: clusterrolebinding
    data: |
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: {{ .Release.Name }}-clusterrolebinding
      roleRef:
        kind: ClusterRole
        name: {{ .Release.Name }}-clusterrole
        apiGroup: rbac.authorization.k8s.io
      subjects:
        - kind: ServiceAccount
          name: {{ .Release.Name }}
          namespace: {{ .Release.Namespace }}
EOF

    local object=$((helm template \
        -f "$BATS_RUN_TMPDIR"/values-"$BATS_TEST_NUMBER".yaml \
        --set "server.kind=Deployment" \
        --namespace default \
        --show-only templates/extra.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -c | wc -l | tee -a /dev/stderr)
    [ "${actual}" == "2" ]

    local actual=$(echo "$object" | yq -r -c 'select(.metadata.name == "release-name-clusterrole")' | tee -a /dev/stderr)
    [ "${actual}" == '{"apiVersion":"rbac.authorization.k8s.io/v1","kind":"ClusterRole","metadata":{"name":"release-name-clusterrole"},"rules":[{"apiGroups":[""],"resources":["endpoints"],"verbs":["get","list","watch"]}]}' ]

    local actual=$(echo "$object" | yq -r -c 'select(.metadata.name == "release-name-clusterrolebinding")' | tee -a /dev/stderr)
    [ "${actual}" == '{"apiVersion":"rbac.authorization.k8s.io/v1","kind":"ClusterRoleBinding","metadata":{"name":"release-name-clusterrolebinding"},"roleRef":{"kind":"ClusterRole","name":"release-name-clusterrole","apiGroup":"rbac.authorization.k8s.io"},"subjects":[{"kind":"ServiceAccount","name":"release-name","namespace":"default"}]}' ]
}

@test "extraManifests: can be enabled as yaml object" {
    cd "$(chart_dir)"

    cat <<EOF > "$BATS_RUN_TMPDIR"/values-"$BATS_TEST_NUMBER".yaml
extraManifests:
  - name: clusterrole
    data:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: varnish-cache-clusterrole
      rules:
        - apiGroups: [""]
          resources: ["endpoints"]
          verbs: ["get", "list", "watch"]
  - name: clusterrolebinding
    data:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: varnish-cache-clusterrolebinding
      roleRef:
        kind: ClusterRole
        name: varnish-cache-clusterrole
        apiGroup: rbac.authorization.k8s.io
      subjects:
        - kind: ServiceAccount
          name: varnish-cache
          namespace: default
EOF

    local object=$((helm template \
        -f "$BATS_RUN_TMPDIR"/values-"$BATS_TEST_NUMBER".yaml \
        --set "server.kind=Deployment" \
        --namespace default \
        --show-only templates/extra.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -c | wc -l | tee -a /dev/stderr)
    [ "${actual}" == "2" ]

    local actual=$(echo "$object" | yq -r -c 'select(.metadata.name == "varnish-cache-clusterrole")' | tee -a /dev/stderr)
    [ "${actual}" == '{"apiVersion":"rbac.authorization.k8s.io/v1","kind":"ClusterRole","metadata":{"name":"varnish-cache-clusterrole"},"rules":[{"apiGroups":[""],"resources":["endpoints"],"verbs":["get","list","watch"]}]}' ]

    local actual=$(echo "$object" | yq -r -c 'select(.metadata.name == "varnish-cache-clusterrolebinding")' | tee -a /dev/stderr)
    [ "${actual}" == '{"apiVersion":"rbac.authorization.k8s.io/v1","kind":"ClusterRoleBinding","metadata":{"name":"varnish-cache-clusterrolebinding"},"roleRef":{"apiGroup":"rbac.authorization.k8s.io","kind":"ClusterRole","name":"varnish-cache-clusterrole"},"subjects":[{"kind":"ServiceAccount","name":"varnish-cache","namespace":"default"}]}' ]
}
