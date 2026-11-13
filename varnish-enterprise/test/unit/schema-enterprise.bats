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

@test "Schema: accepts and ignores a set server.agent.licenseSecret from older values.yaml" {
  schema_accepts --set server.agent.licenseSecret=x
  run ! grep -q 'secretName: x$' <<< "$output"
}

@test "Schema: global.natsServer.internal.enabled accepts the varnish-controller '-'" {
  schema_accepts --set server.secret=abc --set server.agent.enabled=true --set global.natsServer.internal.enabled=-
  [[ "$output" == *"varnish-controller-nats.default.svc.cluster.local:4222"* ]]
  schema_rejects "at '/global/natsServer/internal/enabled'" --set global.natsServer.internal.enabled=yes
}

@test "Schema: agent credentials and tags accept numbers from --set" {
  schema_accepts --set server.secret=abc --set server.agent.enabled=true \
    --set server.agent.privateToken=123456 --set 'server.agent.tags={1,2}' \
    --set server.agent.autoRemove.method=vcli --set server.agent.autoRemove.vcli.username=1000 \
    --set server.agent.autoRemove.vcli.password=123456 --set server.agent.autoRemove.vcli.externalAddress=https://c.example
  [[ "$output" == *'value: "123456"'* ]]
  [[ "$output" == *'value: "1,2"'* ]]
  [[ "$output" == *'value: "1000"'* ]]
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

@test "Schema: rejects invalid cluster values" {
  for args in \
    "--set cluster.primaries=0" \
    "--set cluster.primaries=-1" \
    "--set cluster.primaries=abc" \
    "--set-json cluster.primaries=2.5" \
    "--set cluster.fallback=-1" \
    "--set cluster.fallback=abc" \
    "--set cluster.trace=yes"; do
    echo "${args}" >&2
    schema_rejects "at '/cluster/" --set cluster.enabled=true ${args}
  done
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

@test "Schema: accepts fractional shutdownDelay seconds" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  printf 'server:\n  terminationGracePeriodSeconds: 30\n  delayedShutdown:\n    method: shutdown_delay\n    shutdownDelay:\n      seconds: 2.5\n' > "${values}"
  schema_accepts -f "${values}"
}

@test "Schema: agent storageSize accepts Kubernetes quantities" {
  schema_accepts --set server.agent.persistence.storageSize=0.5Gi
  schema_accepts --set server.agent.persistence.storageSize=1e9
  schema_accepts --set server.agent.persistence.storageSize=
  schema_rejects "at '/server/agent/persistence/storageSize'" --set server.agent.persistence.storageSize=lots
}
