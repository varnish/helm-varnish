#!/usr/bin/env bash
#
# Renders the chart once per values file in values/ and compares the output
# against the matching file in expected/. Chart version and appVersion are
# replaced with placeholders so version bumps do not churn the expected output,
# and trailing whitespace and blank lines are dropped as Helm 3 and Helm 4 do
# not agree on them.
#
# Usage: run.sh [--update]
#   --update  regenerate expected/ instead of comparing against it
set -euo pipefail

GOLDEN_DIR=$(
  cd "$(dirname "$0")" || exit 1
  pwd -P
)
CHART_DIR=$(
  cd "$GOLDEN_DIR/../.." || exit 1
  pwd -P
)

KUBE_VERSION=1.33.0

update=0
if [ "${1:-}" = "--update" ]; then
  update=1
fi

version=$(yq -r '.version' "$CHART_DIR/Chart.yaml")
app_version=$(yq -r '.appVersion' "$CHART_DIR/Chart.yaml")

render() {
  helm template golden "$CHART_DIR" \
    --namespace default \
    --kube-version "$KUBE_VERSION" \
    --values "$1" 2> >(grep -v 'symbolic link' >&2) |
    sed -e "s/${version//./\\.}/CHART_VERSION/g" \
      -e "s/${app_version//./\\.}/APP_VERSION/g" \
      -e 's/[[:space:]]*$//' \
      -e '/^$/d'
}

mkdir -p "$GOLDEN_DIR/expected"

failed=0
for values in "$GOLDEN_DIR"/values/*.yaml; do
  name=$(basename "$values")
  expected="$GOLDEN_DIR/expected/$name"

  if ! actual=$(render "$values"); then
    echo "FAIL $name: helm template failed"
    failed=1
    continue
  fi

  if [ "$update" -eq 1 ]; then
    printf '%s\n' "$actual" >"$expected"
    echo "updated $name"
  elif diff -u "$expected" <(printf '%s\n' "$actual"); then
    echo "ok $name"
  else
    echo "FAIL $name: rendered output differs from expected/$name"
    failed=1
  fi
done

exit $failed
