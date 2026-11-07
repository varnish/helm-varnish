#!/usr/bin/env bats

load _helpers

@test "Schema: accepts shutdown_delay" {
  schema_accepts --set server.delayedShutdown.method=shutdown_delay --set server.terminationGracePeriodSeconds=120
}

@test "Schema: accepts the null server.agent.licenseSecret from older values.yaml" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  printf 'server:\n  agent:\n    licenseSecret:\n' > "${values}"
  schema_accepts -f "${values}"
}

@test "Schema: rejects a set server.agent.licenseSecret" {
  schema_rejects "at '/server/agent/licenseSecret'" --set server.agent.licenseSecret=x
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

@test "Schema: rejects unknown agent keys" {
  schema_rejects "additional properties 'enable' not allowed" --set server.agent.enable=true
}

@test "Schema: rejects a numeric agent latitude" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  cat > "${values}" <<'EOT'
server:
  agent:
    location:
      latitude: 37.35
EOT
  schema_rejects "at '/server/agent/location/latitude'" -f "${values}"
}
