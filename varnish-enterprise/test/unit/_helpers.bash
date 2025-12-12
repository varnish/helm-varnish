chart_dir() {
  echo "${BATS_TEST_DIRNAME}"/../..
}

helm_template_compare {
  local valuefile="${BATS_TMPDIR}/values-${BATS_TEST_NUMBER}"
  echo "$1" > "$valuefile"
  local templatefile="$2"
  local jqpattern="$3"
  local expected_result="$4"
  local result=$(helm template --namespace default\
    --values "$valuefile" \
    --show-only "$templatefile" |
    yq -c "$jqpattern" 
  )"
  [ "$result" == "$expected_result ]
}

app_version() {
  yq -r '.appVersion' < "${BATS_TEST_DIRNAME}"/../../Chart.yaml
}
