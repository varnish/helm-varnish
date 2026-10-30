bats_require_minimum_version 1.5.0

chart_dir() {
  echo "${BATS_TEST_DIRNAME}"/../..
}

chart_name() {
  yq -r '.name' < "$(chart_dir)/Chart.yaml"
}

app_version() {
  yq -r '.appVersion' < "$(chart_dir)/Chart.yaml"
}

is_enterprise() {
  [ "$(yq -r '.annotations.flavor' < "$(chart_dir)/Chart.yaml")" == "enterprise" ]
}

skip_unless_enterprise() {
  is_enterprise || skip "Varnish Enterprise only"
}

# Stands in for "helm template" output when it fails ('helm template ... ||
# render_failed'), and records the failure so that teardown fails the test
# instead of letting assertions on missing fields pass.
render_failed() {
  touch "${BATS_TEST_TMPDIR}/render-failed"
  echo "---"
}

check_render() {
  if [ -e "${BATS_TEST_TMPDIR}/render-failed" ]; then
    echo "helm template failed" >&2
    return 1
  fi
}

teardown() {
  check_render
}
