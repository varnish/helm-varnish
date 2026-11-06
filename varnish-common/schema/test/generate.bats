#!/usr/bin/env bats

# Runs generate.py against a copy of the fixture tree in fixture/, which holds a
# minimal source using every x- keyword and hand-written values.yaml files
# matching its defaults.

bats_require_minimum_version 1.5.0

setup() {
  GENERATE="${BATS_TEST_DIRNAME}/../generate.py"
  ROOT="${BATS_TEST_TMPDIR}/root"
  cp -r "${BATS_TEST_DIRNAME}/fixture" "${ROOT}"
  SOURCE="${ROOT}/varnish-common/schema/values.schema.yaml"
}

generate() {
  run "${GENERATE}" --root "${ROOT}" "$@"
  echo "$output" >&2
}

cache_schema() {
  echo "${ROOT}/varnish-cache/values.schema.json"
}

enterprise_schema() {
  echo "${ROOT}/varnish-enterprise/values.schema.json"
}

cache_docs() {
  echo "${ROOT}/varnish-cache/README.md"
}

enterprise_docs() {
  echo "${ROOT}/varnish-enterprise/VALUES.md"
}

@test "generate: cache schema denies enterprise-only properties" {
  generate
  [ "$status" -eq 0 ]

  local actual=$(jq -c '.properties.a.properties.ent' "$(cache_schema)")
  [ "${actual}" == '{"type":"null","description":"Varnish Enterprise only."}' ]

  actual=$(jq -c '.properties.a.properties.ent.type' "$(enterprise_schema)")
  [ "${actual}" == '"boolean"' ]
}

@test "generate: cache schema omits enterprise-only globals" {
  generate
  [ "$status" -eq 0 ]

  local actual=$(jq -c '.properties.global.properties.entOnly' "$(cache_schema)")
  [ "${actual}" == 'null' ]

  actual=$(jq -c '.properties.global.properties.entOnly.type' "$(enterprise_schema)")
  [ "${actual}" == '"string"' ]
}

@test "generate: cache schema drops enterprise-only enum values" {
  generate
  [ "$status" -eq 0 ]

  local actual=$(jq -c '.properties.a.properties.mode.enum' "$(cache_schema)")
  [ "${actual}" == '["x"]' ]

  actual=$(jq -c '.properties.a.properties.mode.enum' "$(enterprise_schema)")
  [ "${actual}" == '["x","y"]' ]
}

@test "generate: x- keywords are stripped" {
  generate
  [ "$status" -eq 0 ]

  run grep -c '"x-' "$(cache_schema)" "$(enterprise_schema)"
  echo "$output" >&2
  [ "$output" == "$(cache_schema):0"$'\n'"$(enterprise_schema):0" ]

  local actual=$(jq -c '.properties.a.properties.b.examples[0]' "$(cache_schema)")
  [ "${actual}" == '"fixture-example-value"' ]

  actual=$(jq -c '[.properties.a.properties.dir.default, ."$comment"]' "$(enterprise_schema)")
  [ "${actual}" == '["/enterprise","Generated from varnish-common/schema/values.schema.yaml by generate.py. Do not edit."]' ]
}

@test "generate: docs nest examples under the full path" {
  generate
  [ "$status" -eq 0 ]

  grep -qzF $'```yaml\na:\n  b: fixture-example-value\n```' "$(cache_docs)"
  grep -qzF $'```yaml\na:\n  b: |\n    first line\n    second line\n```' "$(cache_docs)"
}

@test "generate: docs substitute product and omit enterprise-only keys" {
  generate
  [ "$status" -eq 0 ]

  grep -qF 'The b key of Varnish Cache.' "$(cache_docs)"
  run ! grep -qF '**a.ent**' "$(cache_docs)"
  run ! grep -qF '**global.entOnly**' "$(cache_docs)"
  run ! grep -qF '`y`' "$(cache_docs)"

  grep -qF 'The b key of Varnish Enterprise.' "$(enterprise_docs)"
  grep -qF '**a.ent**' "$(enterprise_docs)"
  grep -qF '**global.entOnly**' "$(enterprise_docs)"

  # The generated block replaces the markers' content only
  grep -qF 'Hand-written text before the values.' "$(cache_docs)"
  grep -qF '### Hand-written section' "$(cache_docs)"
  grep -qzF -e $'- Type: string\n- Default: `b`\n- Availability: v1.2.0\n\nThe b key' "$(cache_docs)"
  grep -qzF -e $'- Availability: v1.1.0\n\nThe b key' "$(enterprise_docs)"
  grep -qF '[k8s-pod]: https://kubernetes.io/docs/concepts/workloads/pods/' "$(enterprise_docs)"
  run ! grep -qF 'unused-link' "$(enterprise_docs)"
  run ! grep -qF '**enabled**' "$(cache_docs)"
}

@test "generate: docs list the flavor's enum values in the type" {
  generate
  [ "$status" -eq 0 ]

  # grep -F would take each line as a separate pattern
  [[ "$(cat "$(cache_docs)")" == *$'**a.mode**\n\n- Type: string, one of `x`\n'* ]]
  [[ "$(cat "$(enterprise_docs)")" == *$'**a.mode**\n\n- Type: string, one of `x` or `y`\n'* ]]
}

@test "generate: --check detects drift" {
  generate
  [ "$status" -eq 0 ]

  generate --check
  [ "$status" -eq 0 ]

  echo >> "${ROOT}/varnish-cache/values.schema.json"
  generate --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"varnish-cache/values.schema.json"* ]]
  [[ "$output" == *"run varnish-common/schema/generate.py"* ]]
  [[ "$output" != *"varnish-enterprise/values.schema.json"* ]]
}

@test "generate: rejects unknown x- keywords" {
  yq -i '.properties.a.properties.b.x-flavour = "enterprise"' "${SOURCE}"
  generate
  [ "$status" -eq 1 ]
  [[ "$output" == *"x-flavour"* ]]
}

@test "generate: rejects unknown flavors" {
  yq -i '.properties.a.properties.b.x-flavor = "plus"' "${SOURCE}"
  generate
  [ "$status" -eq 1 ]
  [[ "$output" == *"plus"* ]]
}

@test "generate: rejects examples without a description or a value" {
  yq -i '.properties.a.properties.b.x-examples[0] |= del(.description)' "${SOURCE}"
  generate
  [ "$status" -eq 1 ]
  [[ "$output" == *"x-examples"* ]]
}

@test "generate: values.yaml round-trips" {
  generate
  [ "$status" -eq 0 ]

  local cache='{"name":"","global":{"shared":"s"},"a":{"b":"b","mode":"x","dir":"/cache","securityContext":{"runAsUser":1000,"runAsNonRoot":true},"script":"line one\nline two\n","old":"","list":[{"name":"one"}]}}'
  local enterprise='{"name":"","global":{"shared":"s","entOnly":"e"},"a":{"b":"b","ent":true,"mode":"x","dir":"/enterprise","securityContext":{"runAsUser":1000,"runAsNonRoot":true},"script":"line one\nline two\n","old":"","list":[{"name":"one"}]}}'

  local actual=$(yq -o json -I0 '.' "${ROOT}/varnish-cache/values.yaml")
  [ "${actual}" == "${cache}" ]

  actual=$(yq -o json -I0 '.' "${ROOT}/varnish-enterprise/values.yaml")
  [ "${actual}" == "${enterprise}" ]

  head -2 "${ROOT}/varnish-cache/values.yaml" | grep -qxF '# Generated from varnish-common/schema/values.schema.yaml by generate.py. Do not edit.'
}

@test "generate: values.yaml comments" {
  generate
  [ "$status" -eq 0 ]
  local values="${ROOT}/varnish-cache/values.yaml"
  cat "${values}" >&2

  # The long description is wrapped within 90 columns
  [ -z "$(awk 'length > 90' "${values}")" ]
  grep -qxF '# A second paragraph.' "${values}"
  grep -qzF $'# Overrides the name of the chart.' "${values}"

  # Type, Availability and Example, in that order, each example after its description
  grep -qzF $'  # The b key of Varnish Cache.\n  # Type: string\n  # Availability: v1.2.0\n  # For example:\n  # Example:\n  #   b: fixture-example-value\n  # Or, on several lines:\n  # Example:\n  #   b: |\n  #     first line\n  #     second line\n  b: "b"\n' "${values}"

  # x-values-example is a commented-out key
  grep -qxF '  #hostPort: 8080' "${values}"

  # x-default-comments lands above the nested key
  grep -qzF $'    # The user ID to run the container as.\n    runAsUser: 1000\n' "${values}"

  # A multi-line default is a block scalar
  grep -qzF $'  script: |\n    line one\n    line two\n' "${values}"
}

@test "generate: --compare-values accepts matching values" {
  generate --compare-values
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "generate: --compare-values reports mismatches" {
  yq -i '.a.mode = "y" | .a.extra = 1' "${ROOT}/varnish-enterprise/values.yaml"

  generate --compare-values
  [ "$status" -eq 1 ]
  [[ "$output" == *"varnish-enterprise/values.yaml: a.mode:"* ]]
  [[ "$output" == *"varnish-enterprise/values.yaml: a.extra:"* ]]
  [[ "$output" != *"varnish-cache/values.yaml"* ]]

  # Restricted to a path
  generate --compare-values global
  [ "$status" -eq 0 ]
  generate --compare-values a.mode
  [ "$status" -eq 1 ]
  [[ "$output" == *"a.mode"* ]]
  [[ "$output" != *"a.extra"* ]]
}

@test "generate: --compare-values reports defaults missing from values.yaml" {
  yq -i 'del(.a.dir)' "${ROOT}/varnish-cache/values.yaml"

  generate --compare-values
  [ "$status" -eq 1 ]
  [[ "$output" == *"varnish-cache/values.yaml: a.dir:"* ]]
}
