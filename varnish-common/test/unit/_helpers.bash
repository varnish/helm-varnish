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
  [ "$(yq -r '.annotations."varnish.com/flavor"' < "$(chart_dir)/Chart.yaml")" == "enterprise" ]
}

skip_unless_enterprise() {
  is_enterprise || skip "Varnish Enterprise only"
}
