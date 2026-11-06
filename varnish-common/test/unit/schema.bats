#!/usr/bin/env bats

load _helpers

@test "Schema: generated files are up to date" {
  run "$(chart_dir)/../varnish-common/schema/generate.py" --check
  echo "$output" >&2
  [ "$status" -eq 0 ]
}

@test "Schema: rejects unknown root keys" {
  schema_rejects "additional properties 'sever' not allowed" --set sever.replicas=2
}

@test "Schema: accepts global and enabled" {
  schema_accepts --set global.anything=1 --set enabled=true
}

@test "Schema: renders as a dependency with a condition and parent globals" {
  local name=$(chart_name)
  local version=$(yq -r '.version' "$(chart_dir)/Chart.yaml")
  local parent="${BATS_TEST_TMPDIR}/parent"

  mkdir -p "${parent}/charts"
  cp -rL "$(chart_dir)" "${parent}/charts/${name}"
  cat > "${parent}/Chart.yaml" <<EOT
apiVersion: v2
name: parent
version: 0.1.0
dependencies:
  - name: ${name}
    version: ${version}
    condition: ${name}.enabled
EOT
  cat > "${parent}/values.yaml" <<EOT
${name}:
  enabled: true
global:
  parentOnly: x
EOT

  run helm template p "${parent}" --namespace default
  echo "$output" >&2
  [ "$status" -eq 0 ]
  [[ "$output" == *"kind: Deployment"* ]]
}

@test "Schema: rejects unknown serviceAccount keys" {
  schema_rejects "additional properties 'crate' not allowed" --set serviceAccount.crate=false
}

@test "Schema: rejects a non-boolean serviceAccount.create" {
  schema_rejects "at '/serviceAccount/create'" --set serviceAccount.create=yes
}

@test "Schema: rejects unknown extraManifests item keys" {
  schema_rejects "at '/extraManifests/0'" --set extraManifests[0].name=a --set extraManifests[0].dat=x
}

@test "Schema: global accepts unknown keys from parent charts" {
  schema_accepts --set global.foo.bar=1
}

@test "Schema: rejects a string global.imagePullSecrets" {
  schema_rejects "at '/global/imagePullSecrets'" --set global.imagePullSecrets=foo
}

@test "Schema: rejects an unknown server.kind" {
  schema_rejects "at '/server/kind'" --set server.kind=Pod
}

@test "Schema: rejects a non-numeric server.replicas" {
  schema_rejects "at '/server/replicas'" --set server.replicas=abc
}

@test "Schema: rejects unknown server.http keys" {
  schema_rejects "additional properties 'prot' not allowed" --set server.http.prot=1
}

@test "Schema: accepts numeric and string image tags" {
  # --set makes 7 an integer, which the image helper must compare as a string
  schema_accepts --set server.image.tag=7
  [[ "$output" == *'image: "'*':7"'* ]]

  schema_accepts --set server.image.tag=7.6
  [[ "$output" == *'image: "'*':7.6"'* ]]
}

@test "Schema: accepts null on keys without a default" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  cat > "${values}" <<EOT
server:
  http:
    hostPort: null
  delayedHaltSeconds: null
EOT
  schema_accepts -f "${values}"
}

@test "Schema: accepts a quoted port" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  cat > "${values}" <<EOT
server:
  http:
    port: "8080"
EOT
  schema_accepts -f "${values}"
}

@test "Schema: extraListens items need a name" {
  schema_rejects "at '/server/extraListens/0'" --set server.extraListens[0].port=8088
}

@test "Schema: rejects an unknown delayedShutdown.method" {
  schema_rejects "at '/server/delayedShutdown/method'" --set server.delayedShutdown.method=wait
}
