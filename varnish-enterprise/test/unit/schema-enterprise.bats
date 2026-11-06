#!/usr/bin/env bats

load _helpers

@test "Schema: accepts shutdown_delay" {
  schema_accepts --set server.delayedShutdown.method=shutdown_delay --set server.terminationGracePeriodSeconds=120
}

@test "Schema: rejects the removed server.agent.licenseSecret" {
  skip "closed in Task 9"
  schema_rejects "additional properties 'licenseSecret' not allowed" --set server.agent.licenseSecret=x
}

@test "Schema: rejects a numeric mse storageSize" {
  schema_rejects "at '/server/mse/persistence/storageSize'" --set server.mse.persistence.storageSize=10
}

@test "Schema: mse.enabled accepts '-' only as a string" {
  schema_accepts --set server.mse.enabled=-
  schema_rejects "at '/server/mse/enabled'" --set server.mse.enabled=yes
}

@test "Schema: rejects unknown cluster keys" {
  schema_rejects "additional properties 'primary' not allowed" --set cluster.primary=1
}

@test "Schema: accepts digit-string cluster.primaries" {
  schema_accepts --set cluster.enabled=true --set-string cluster.primaries=2
}
