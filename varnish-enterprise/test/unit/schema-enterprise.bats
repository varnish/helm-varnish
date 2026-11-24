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

@test "Schema: rejects server.agent.licenseSecret from older values.yaml, even null" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  printf 'server:\n  agent:\n    licenseSecret:\n' > "${values}"
  schema_rejects "additional properties 'licenseSecret' not allowed" -f "${values}"
  schema_rejects "additional properties 'licenseSecret' not allowed" --set server.agent.licenseSecret=x
}

@test "Schema: rejects a numeric mse4 storageSize" {
  schema_rejects "at '/server/mse4/persistence/storageSize'" --set server.mse4.persistence.storageSize=10
}

@test "Schema: rejects the removed MSE3 server.mse key" {
  schema_rejects "additional properties 'mse' not allowed" --set server.mse.enabled=true
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

@test "Schema: global.natsServer.internal.enabled accepts the varnish-controller '-'" {
  schema_accepts --set server.agent.enabled=true --set global.natsServer.internal.enabled=-
  [[ "$output" == *"varnish-controller-nats.default.svc.cluster.local:4222"* ]]
  schema_rejects "at '/global/natsServer/internal/enabled'" --set global.natsServer.internal.enabled=yes
}

@test "Schema: rejects unknown agent keys" {
  schema_rejects "additional properties 'enable' not allowed" --set server.agent.enable=true
}

@test "Schema: vcli credentials accept numbers from --set" {
  schema_accepts --set server.agent.enabled=true \
    --set server.agent.autoRemove.method=vcli --set server.agent.autoRemove.vcli.username=1000 \
    --set server.agent.autoRemove.vcli.password=123456 --set server.agent.autoRemove.vcli.internal.enabled=false \
    --set server.agent.autoRemove.vcli.externalAddress=https://c.example
  [[ "$output" == *'value: "123456"'* ]]
  [[ "$output" == *'value: "1000"'* ]]
}

@test "Schema: agent storageSize accepts Kubernetes quantities" {
  schema_accepts --set server.agent.persistence.storageSize=0.5Gi
  schema_accepts --set server.agent.persistence.storageSize=1e9
  schema_accepts --set server.agent.persistence.storageSize=
  schema_rejects "at '/server/agent/persistence/storageSize'" --set server.agent.persistence.storageSize=lots
}

@test "Schema: rejects the removed agent keys" {
  local key
  for key in logLevel=info privateToken=x 'tags={a}' location.latitude=1 useReleaseName=true; do
    schema_rejects "additional properties '${key%%[.=]*}' not allowed" --set "server.agent.${key}"
  done
}

@test "Schema: rejects the removed vcli.internal location keys" {
  local key
  for key in namespace releaseName clusterDomain; do
    schema_rejects "additional properties '${key}' not allowed" --set "server.agent.autoRemove.vcli.internal.${key}=x"
  done
}

@test "Schema: rejects the removed server.mse4.configFile" {
  schema_rejects "additional properties 'configFile' not allowed" --set server.mse4.configFile=x
}

@test "Schema: rejects the removed server.mse4.persistence.mountPath" {
  schema_rejects "additional properties 'mountPath' not allowed" --set server.mse4.persistence.mountPath=/data1/mse4
}
