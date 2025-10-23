#!/usr/bin/env bats

load _helpers

@test "extraManifests: disabled by default" {
    cd "$(chart_dir)"
    local actual=$((helm template \
        --show-only templates/extra.yaml \
        --namespace default \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)
    [ "${actual}" == "false" ]
}

@test "extraManifests: can be enabled as templated string" {
    cd "$(chart_dir)"

    cat <<EOF > "$BATS_RUN_TMPDIR"/values.yaml
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
        -f "$BATS_RUN_TMPDIR"/values.yaml \
        --set 'brainz.licenseSecret=brainz-license-secret' \
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

    local objects=$((helm template \
        -f "$BATS_RUN_TMPDIR"/values.yaml \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        --show-only templates/deployment-brainz.yaml \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    for n in apigw brainz ui; do
        local object=$(echo "$objects" |
            tee -a /dev/stderr |
            yq "select(.metadata.name == \"release-name-varnish-controller-$n\")" |
            tee -a /dev/stderr)

        local actual=$(echo "$object" |
            yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrole"' |
                tee -a /dev/stderr)
        [ "${actual}" = 'null' ]

        local actual=$(echo "$object" |
            yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrolebinding"' |
                tee -a /dev/stderr)
        [ "${actual}" = 'null' ]
    done
}

@test "extraManifests: can be enabled as templated string with checksum" {
    cd "$(chart_dir)"

    cat <<EOF > "$BATS_RUN_TMPDIR"/values.yaml
extraManifests:
  - name: clusterrole
    checksum: true
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
    checksum: true
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
        -f "$BATS_RUN_TMPDIR"/values.yaml \
        --set 'brainz.licenseSecret=brainz-license-secret' \
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

    local objects=$((helm template \
        -f "$BATS_RUN_TMPDIR"/values.yaml \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        --show-only templates/deployment-brainz.yaml \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    for n in apigw brainz ui; do
        local object=$(echo "$objects" |
            tee -a /dev/stderr |
            yq "select(.metadata.name == \"release-name-varnish-controller-$n\")" |
            tee -a /dev/stderr)

        local actual=$(echo "$object" |
            yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrole"' |
                tee -a /dev/stderr)
        [ "${actual}" = 'b341e3a03d6bb568e16c2ccbfdc281924ad1a771b73fd2c4198a54a6ce568ebe' ]

        local actual=$(echo "$object" |
            yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrolebinding"' |
                tee -a /dev/stderr)
        [ "${actual}" = 'ba049cef23c6407b1c3866a543d8b6cb6b52e01cc40b18774021761b3560424e' ]
    done
}

@test "extraManifests: can be enabled as yaml object" {
    cd "$(chart_dir)"

    cat <<EOF > "$BATS_RUN_TMPDIR"/values.yaml
extraManifests:
  - name: clusterrole
    data:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: varnish-controller-clusterrole
      rules:
        - apiGroups: [""]
          resources: ["endpoints"]
          verbs: ["get", "list", "watch"]
  - name: clusterrolebinding
    data:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: varnish-controller-clusterrolebinding
      roleRef:
        kind: ClusterRole
        name: varnish-controller-clusterrole
        apiGroup: rbac.authorization.k8s.io
      subjects:
        - kind: ServiceAccount
          name: varnish-controller
          namespace: default
EOF

    local object=$((helm template \
        -f "$BATS_RUN_TMPDIR"/values.yaml \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/extra.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -c | wc -l | tee -a /dev/stderr)
    [ "${actual}" == "2" ]

    local actual=$(echo "$object" | yq -r -c 'select(.metadata.name == "varnish-controller-clusterrole")' | tee -a /dev/stderr)
    [ "${actual}" == '{"apiVersion":"rbac.authorization.k8s.io/v1","kind":"ClusterRole","metadata":{"name":"varnish-controller-clusterrole"},"rules":[{"apiGroups":[""],"resources":["endpoints"],"verbs":["get","list","watch"]}]}' ]

    local actual=$(echo "$object" | yq -r -c 'select(.metadata.name == "varnish-controller-clusterrolebinding")' | tee -a /dev/stderr)
    [ "${actual}" == '{"apiVersion":"rbac.authorization.k8s.io/v1","kind":"ClusterRoleBinding","metadata":{"name":"varnish-controller-clusterrolebinding"},"roleRef":{"apiGroup":"rbac.authorization.k8s.io","kind":"ClusterRole","name":"varnish-controller-clusterrole"},"subjects":[{"kind":"ServiceAccount","name":"varnish-controller","namespace":"default"}]}' ]

    local objects=$((helm template \
        -f "$BATS_RUN_TMPDIR"/values.yaml \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        --show-only templates/deployment-brainz.yaml \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    for n in apigw brainz ui; do
        local object=$(echo "$objects" |
            tee -a /dev/stderr |
            yq "select(.metadata.name == \"release-name-varnish-controller-$n\")" |
            tee -a /dev/stderr)

        local actual=$(echo "$object" |
            yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrole"' |
                tee -a /dev/stderr)
        [ "${actual}" = 'null' ]

        local actual=$(echo "$object" |
            yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrolebinding"' |
                tee -a /dev/stderr)
        [ "${actual}" = 'null' ]
    done
}

@test "extraManifests: can be enabled as yaml object with checksum" {
    cd "$(chart_dir)"

    cat <<EOF > "$BATS_RUN_TMPDIR"/values.yaml
extraManifests:
  - name: clusterrole
    checksum: true
    data:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: varnish-controller-clusterrole
      rules:
        - apiGroups: [""]
          resources: ["endpoints"]
          verbs: ["get", "list", "watch"]
  - name: clusterrolebinding
    checksum: true
    data:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: varnish-controller-clusterrolebinding
      roleRef:
        kind: ClusterRole
        name: varnish-controller-clusterrole
        apiGroup: rbac.authorization.k8s.io
      subjects:
        - kind: ServiceAccount
          name: varnish-controller
          namespace: default
EOF

    local object=$((helm template \
        -f "$BATS_RUN_TMPDIR"/values.yaml \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/extra.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    local actual=$(echo "$object" | yq -c | wc -l | tee -a /dev/stderr)
    [ "${actual}" = "2" ]

    local actual=$(echo "$object" | yq -r -c 'select(.metadata.name == "varnish-controller-clusterrole")' | tee -a /dev/stderr)
    [ "${actual}" == '{"apiVersion":"rbac.authorization.k8s.io/v1","kind":"ClusterRole","metadata":{"name":"varnish-controller-clusterrole"},"rules":[{"apiGroups":[""],"resources":["endpoints"],"verbs":["get","list","watch"]}]}' ]

    local actual=$(echo "$object" | yq -r -c 'select(.metadata.name == "varnish-controller-clusterrolebinding")' | tee -a /dev/stderr)
    [ "${actual}" == '{"apiVersion":"rbac.authorization.k8s.io/v1","kind":"ClusterRoleBinding","metadata":{"name":"varnish-controller-clusterrolebinding"},"roleRef":{"apiGroup":"rbac.authorization.k8s.io","kind":"ClusterRole","name":"varnish-controller-clusterrole"},"subjects":[{"kind":"ServiceAccount","name":"varnish-controller","namespace":"default"}]}' ]

    local objects=$((helm template \
        -f "$BATS_RUN_TMPDIR"/values.yaml \
        --set 'brainz.licenseSecret=brainz-license-secret' \
        --namespace default \
        --show-only templates/deployment-apigw.yaml \
        --show-only templates/deployment-brainz.yaml \
        --show-only templates/deployment-ui.yaml \
        . || echo "---") |
        tee -a /dev/stderr)

    for n in apigw brainz ui; do
        local object=$(echo "$objects" |
            tee -a /dev/stderr |
            yq "select(.metadata.name == \"release-name-varnish-controller-$n\")" |
            tee -a /dev/stderr)

        local actual=$(echo "$object" |
            yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrole"' |
                tee -a /dev/stderr)
        [ "${actual}" = '61d0a598be6c41dded6fd8cfbf3f272331f50ebda6db505b6726f2e4f10aae48' ]
        local actual=$(echo "$object" |
            yq -r -c '.spec.template.metadata.annotations."checksum/release-name-extra-clusterrolebinding"' |
                tee -a /dev/stderr)
        [ "${actual}" = '4ad4a4ebf47c7cc895886ab0dd01e43217f9a7aa7a9c91038f020af4a89cd038' ]
    done
}