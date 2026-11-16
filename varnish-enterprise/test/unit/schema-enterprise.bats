#!/usr/bin/env bats

load _helpers

@test "Schema: accepts shutdown_delay" {
  schema_accepts --set server.delayedShutdown.method=shutdown_delay --set server.terminationGracePeriodSeconds=120
}

@test "Schema: accepts fractional shutdownDelay seconds" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  printf 'server:\n  terminationGracePeriodSeconds: 30\n  delayedShutdown:\n    method: shutdown_delay\n    shutdownDelay:\n      seconds: 2.5\n' > "${values}"
  schema_accepts -f "${values}"
}
