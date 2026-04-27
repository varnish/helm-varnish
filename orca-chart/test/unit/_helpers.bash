chart_dir() {
    echo "${BATS_TEST_DIRNAME}"/../..
}

app_version() {
    yq -r '.appVersion' < "${BATS_TEST_DIRNAME}"/../../Chart.yaml
}

# yqj: emit a query result as compact JSON. Wraps the two `yq` variants seen
# in CI environments: Go yq (mikefarah) needs `-o=json -I=0`, while Python yq
# (kislyuk) uses `-c` (passed through to jq).
yqj() {
    if yq --version 2>&1 | grep -qi mikefarah; then
        yq -o=json -I=0 "$@"
    else
        yq -c "$@"
    fi
}
