#!/usr/bin/env bats

load _helpers

@test "Schema: accepts shutdown_delay" {
  schema_accepts --set server.delayedShutdown.method=shutdown_delay --set server.terminationGracePeriodSeconds=120
}
