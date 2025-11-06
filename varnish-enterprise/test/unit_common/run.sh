#!/bin/sh
set -e

COMMON_TESTS_DIR=$(
  cd "$(dirname "$0")" || exit 1
  pwd -P
)

run() {
  for t in \
    DaemonSet:daemonset.yaml \
    Deployment:deployment.yaml \
    StatefulSet:statefulset.yaml; do
    kind=${t%%:*}
    template=templates/${t##"$kind":}
    kind="${kind}" template="${template}" bats "$@" "$COMMON_TESTS_DIR" || exit 1
  done
}

run "$@"
