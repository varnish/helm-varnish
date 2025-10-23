chart_dir() {
  echo "${BATS_TEST_DIRNAME}"/../..
}

app_version() {
  yq -r '.appVersion' < "${BATS_TEST_DIRNAME}"/../../Chart.yaml
}
