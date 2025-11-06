#!/bin/sh
set -e

TESTS_DIR=$(cd "$(dirname "$0")" || exit 1; pwd -P)

run() {
    bats -j $(nproc) "$@" "$TESTS_DIR" || exit 1
}

run "$@"