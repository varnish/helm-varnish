#!/usr/bin/env bats

load _helpers

# Renders the chart, for the schema checks below.
schema_template() {
  cd "$(chart_dir)"
  run helm template t . --namespace default "$@"
  echo "$output" >&2
}

# schema_rejects <substring> <helm args...>: the values fail the schema, with
# an error containing <substring>.
schema_rejects() {
  local expected="$1"
  shift
  schema_template "$@"
  [ "$status" -ne 0 ]
  [[ "$output" == *"values don't meet the specifications"* ]]
  [[ "$output" == *"${expected}"* ]]
}

# schema_accepts <helm args...>: the values pass the schema and render.
schema_accepts() {
  schema_template "$@"
  [ "$status" -eq 0 ]
}

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
