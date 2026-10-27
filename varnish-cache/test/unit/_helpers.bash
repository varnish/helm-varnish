chart_dir() {
    echo "${BATS_TEST_DIRNAME}"/../..
}

chart_name() {
  yq -r '.name' < "${BATS_TEST_DIRNAME}"/../../Chart.yaml
}
