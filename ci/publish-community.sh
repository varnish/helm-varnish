#!/bin/sh
# Builds the varnish-cache community chart from the varnish-enterprise source.
#
# The enterprise chart is the single source of truth. This script transforms it
# into the community chart by switching the edition, changing the default image,
# and stripping enterprise-only values so they never appear in the published chart.
#
# Usage:
#   ./ci/publish-community.sh <oss-version> [output-dir]
#
# oss-version: the Varnish Cache release to target, e.g. "9.0.3"
#              This sets Chart.yaml appVersion and the default image tag.
# output-dir:  defaults to ./dist/varnish-cache
#
# Requires yq (kislyuk/yq) and helm.

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <oss-version> [output-dir]" >&2
    echo "  e.g. $0 9.0.3" >&2
    exit 1
fi

OSS_VERSION="$1"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/varnish-enterprise"
OUT="${2:-$REPO_ROOT/dist/varnish-cache}"

if ! command -v yq > /dev/null 2>&1; then
    echo "Error: yq is required (https://github.com/mikefarah/yq)" >&2
    exit 1
fi

if ! command -v helm > /dev/null 2>&1; then
    echo "Error: helm is required" >&2
    exit 1
fi

echo "Building community chart from $SRC -> $OUT (Varnish Cache $OSS_VERSION)"

rm -rf "$OUT"
mkdir -p "$(dirname "$OUT")"
cp -r "$SRC" "$OUT"

# Patch Chart.yaml: rename, update description, and set the OSS appVersion
yq -Y --in-place \
    --arg version "$OSS_VERSION" '
    .name = "varnish-cache" |
    .description = "Varnish Cache Helm Chart" |
    .appVersion = $version
' "$OUT/Chart.yaml"

# Switch edition and image defaults, enable malloc, strip enterprise sections
yq -Y --in-place '
    .global.edition = "community" |
    .server.image.repository = "docker.io/varnish" |
    .server.malloc.enabled = true |
    del(.server.mse) |
    del(.server.mse4) |
    del(.server.agent) |
    del(.server.initAgent) |
    del(.server.otel) |
    del(.server.baseUrl) |
    del(.server.licenseSecret) |
    del(.cluster) |
    del(.natsServer)
' "$OUT/values.yaml"

helm lint "$OUT"

echo "Community chart written to $OUT"
echo "  appVersion: $OSS_VERSION (default image: docker.io/varnish:$OSS_VERSION)"
echo "To package: helm package $OUT --destination ./dist/packages"
