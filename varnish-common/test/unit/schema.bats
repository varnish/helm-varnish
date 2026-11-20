#!/usr/bin/env bats

load _helpers

@test "Schema: rejects unknown root keys" {
  schema_rejects "additional properties 'sever' not allowed" --set sever.replicas=2
}

@test "Schema: accepts global and enabled" {
  schema_accepts --set global.anything=1 --set enabled=true
}

@test "Schema: renders as a dependency with a condition and parent globals" {
  local name=$(chart_name)
  local version=$(yq -r '.version' "$(chart_dir)/Chart.yaml")
  local parent="${BATS_TEST_TMPDIR}/parent"

  mkdir -p "${parent}/charts"
  cp -rL "$(chart_dir)" "${parent}/charts/${name}"
  cat > "${parent}/Chart.yaml" <<EOT
apiVersion: v2
name: parent
version: 0.1.0
dependencies:
  - name: ${name}
    version: ${version}
    condition: ${name}.enabled
EOT
  cat > "${parent}/values.yaml" <<EOT
${name}:
  enabled: true
global:
  parentOnly: x
  initContainer:
    parentOnly: x
  natsServer:
    parentOnly: x
    internal:
      parentOnly: x
      passwordFrom:
        parentOnly: x
EOT

  run helm template p "${parent}" --namespace default
  echo "$output" >&2
  [ "$status" -eq 0 ]
  [[ "$output" == *"kind: Deployment"* ]]
}

@test "Schema: rejects unknown serviceAccount keys" {
  schema_rejects "additional properties 'crate' not allowed" --set serviceAccount.crate=false
}

@test "Schema: rejects a non-boolean serviceAccount.create" {
  schema_rejects "at '/serviceAccount/create'" --set serviceAccount.create=yes
}

@test "Schema: rejects unknown extraManifests item keys" {
  schema_rejects "at '/extraManifests/0'" --set extraManifests[0].name=a --set extraManifests[0].dat=x
}

@test "Schema: global accepts unknown keys from parent charts" {
  schema_accepts --set global.foo.bar=1
}

@test "Schema: rejects a string global.imagePullSecrets" {
  schema_rejects "at '/global/imagePullSecrets'" --set global.imagePullSecrets=foo
}

@test "Schema: rejects non-object items in Kubernetes object arrays" {
  schema_rejects "at '/server/extraVolumes/0'" --set server.extraVolumes[0]=foo
  schema_rejects "at '/server/tolerations/0'" --set server.tolerations[0]=foo
  schema_rejects "at '/server/topologySpreadConstraints/0'" --set-json 'server.topologySpreadConstraints=[null]'
  schema_rejects "at '/server/extraEnvs/0'" --set server.extraEnvs[0]=foo
}

@test "Schema: rejects malformed global.imagePullSecrets items" {
  schema_rejects "at '/global/imagePullSecrets/0'" --set global.imagePullSecrets[0]=regcred
  schema_rejects "at '/global/imagePullSecrets/0/name'" --set global.imagePullSecrets[0].name=1
}

@test "Schema: accepts global.imagePullSecrets items with a name" {
  schema_accepts --set global.imagePullSecrets[0].name=regcred
  [[ "$output" == *'- name: regcred'* ]]
}

@test "Schema: rejects an unknown server.kind" {
  schema_rejects "at '/server/kind'" --set server.kind=Pod
}

@test "Schema: rejects a non-numeric server.replicas" {
  schema_rejects "at '/server/replicas'" --set server.replicas=abc
}

@test "Schema: rejects unknown server.http keys" {
  schema_rejects "additional properties 'prot' not allowed" --set server.http.prot=1
}

@test "Schema: rejects numeric image tags" {
  # YAML turns 8.0 into 8 and 1.10 into 1.1 before the chart sees them, and
  # --set turns 7 into an integer
  schema_rejects "at '/server/image/tag'" --set server.image.tag=7
  schema_rejects "at '/server/varnishncsa/image/tag'" --set server.varnishncsa.image.tag=7

  local values="${BATS_TEST_TMPDIR}/values.yaml"
  printf 'server:\n  image:\n    tag: 8.0\n' > "${values}"
  schema_rejects "at '/server/image/tag'" -f "${values}"
  printf 'server:\n  image:\n    tag: 7.6\n' > "${values}"
  schema_rejects "at '/server/image/tag'" -f "${values}"
}

@test "Schema: rejects a numeric global.initContainer.tag" {
  skip_unless_enterprise
  schema_rejects "at '/global/initContainer/tag'" --set global.initContainer.tag=1
}

@test "Schema: accepts string image tags that look like numbers" {
  # --set only converts integers and booleans, so 7.6 stays a string
  schema_accepts --set server.image.tag=7.6
  [[ "$output" == *'image: "'*':7.6"'* ]]

  schema_accepts --set-string server.image.tag=7
  [[ "$output" == *'image: "'*':7"'* ]]

  local values="${BATS_TEST_TMPDIR}/values.yaml"
  printf 'server:\n  image:\n    tag: "8.0"\n' > "${values}"
  schema_accepts -f "${values}"
  [[ "$output" == *'image: "'*':8.0"'* ]]
}

@test "Templates: numeric image tags render without scientific notation when the schema is skipped" {
  # numbers from values files and --set-json reach the templates as float64
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  printf 'server:\n  image:\n    tag: 20241129\n' > "${values}"
  schema_accepts --skip-schema-validation -f "${values}"
  [[ "$output" == *'image: "'*':20241129"'* ]]

  schema_accepts --skip-schema-validation --set-json server.image.tag=20241129.5
  [[ "$output" == *'image: "'*':20241129.5"'* ]]
  [[ "$output" != *'e+07'* ]]
}

@test "Schema: rejects out-of-range string ports" {
  schema_rejects "at '/server/http/port'" --set-string server.http.port=65536
  schema_rejects "at '/server/http/port'" --set-string server.http.port=99999
}

@test "Schema: accepts in-range string ports" {
  schema_accepts --set-string server.http.port=65535
  schema_accepts --set-string server.http.port=0
}

@test "Schema: accepts null on keys without a default" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  cat > "${values}" <<EOT
server:
  http:
    hostPort: null
  tls:
    hostPort: null
EOT
  schema_accepts -f "${values}"
}

@test "Schema: accepts a quoted port" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  cat > "${values}" <<EOT
server:
  http:
    port: "8080"
EOT
  schema_accepts -f "${values}"
}

@test "Schema: extraListens items need a name" {
  schema_rejects "at '/server/extraListens/0'" --set server.extraListens[0].port=8088
}

@test "Schema: extraListens user and group accept numeric ids" {
  schema_accepts --set 'server.extraListens[0].name=sock' --set 'server.extraListens[0].path=/tmp/a.sock' \
    --set 'server.extraListens[0].user=1000' --set 'server.extraListens[0].group=1000' --set 'server.extraListens[0].mode=0700'
  [[ "$output" == *"sock=/tmp/a.sock,user=1000,group=1000,mode=0700"* ]]
}

@test "Schema: accepts fractional seconds" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  printf 'server:\n  ttl: 0.5\n  threadTimeout: 1.5\n' > "${values}"
  schema_accepts -f "${values}"
  printf 'server:\n  terminationGracePeriodSeconds: 30\n  delayedShutdown:\n    method: sleep\n    sleep:\n      seconds: 2.5\n' > "${values}"
  schema_accepts -f "${values}"
}

@test "Schema: accepts a null nodePort on an extra service" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  printf 'server:\n  service:\n    extraServices:\n      - name: foo\n        targetPort: 8080\n        port: 8080\n        nodePort: null\n' > "${values}"
  schema_accepts -f "${values}"
  [[ "$output" != *"nodePort"* ]]
}

@test "Schema: still rejects fractional thread counts" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  printf 'server:\n  minThreads: 1.5\n' > "${values}"
  schema_rejects "at '/server/minThreads'" -f "${values}"
}

@test "Schema: rejects non-integer thread count strings" {
  # passed to varnishd as is, which refuses to start on "1.5" or "two"
  schema_rejects "at '/server/minThreads'" --set-string server.minThreads=1.5
  schema_rejects "at '/server/minThreads'" --set-string server.minThreads=two
  schema_rejects "at '/server/maxThreads'" --set-string server.maxThreads=1.5
  schema_rejects "at '/server/maxThreads'" --set-string server.maxThreads=two
}

@test "Schema: accepts integer and empty thread count strings" {
  schema_accepts --set-string server.minThreads=10 --set-string server.maxThreads=100
  [[ "$output" == *'thread_pool_min=10'* ]]
  [[ "$output" == *'thread_pool_max=100'* ]]

  schema_accepts --set-string server.minThreads= --set-string server.maxThreads=
  [[ "$output" != *'thread_pool_min'* ]]
  [[ "$output" != *'thread_pool_max'* ]]
}

@test "Schema: rejects an unknown delayedShutdown.method" {
  schema_rejects "at '/server/delayedShutdown/method'" --set server.delayedShutdown.method=wait
}

@test "Schema: rejects the removed server.vclConfigPath" {
  schema_rejects "additional properties 'vclConfigPath' not allowed" --set server.vclConfigPath=x
}

@test "Schema: rejects the removed server.vclConfigs" {
  schema_rejects "additional properties 'vclConfigs' not allowed" --set server.vclConfigs.x=y
}

@test "Schema: rejects the removed server.secret" {
  schema_rejects "additional properties 'secret' not allowed" --set server.secret=x
}

@test "Schema: rejects the removed server.secretFrom" {
  schema_rejects "additional properties 'secretFrom' not allowed" --set server.secretFrom.name=x
}

@test "Schema: rejects the removed server.secretFile" {
  schema_rejects "additional properties 'secretFile' not allowed" --set server.secretFile=x
}

@test "Schema: rejects the removed server.admin" {
  schema_rejects "additional properties 'admin' not allowed" --set server.admin.port=1
}

@test "Schema: rejects the removed server.workDir" {
  schema_rejects "additional properties 'workDir' not allowed" --set server.workDir=x
}

@test "Schema: rejects the removed server.vclConfigFile" {
  schema_rejects "additional properties 'vclConfigFile' not allowed" --set server.vclConfigFile=x
}

@test "Schema: rejects the removed server.cmdfileConfig" {
  schema_rejects "additional properties 'cmdfileConfig' not allowed" --set server.cmdfileConfig=x
}

@test "Schema: rejects the removed server.cmdfileConfigFile" {
  schema_rejects "additional properties 'cmdfileConfigFile' not allowed" --set server.cmdfileConfigFile=x
}

@test "Schema: rejects the removed server.cmdfileConfigPath" {
  schema_rejects "additional properties 'cmdfileConfigPath' not allowed" --set server.cmdfileConfigPath=x
}

@test "Schema: rejects the removed server.delayedHaltSeconds" {
  schema_rejects "additional properties 'delayedHaltSeconds' not allowed" --set server.delayedHaltSeconds=120
}

@test "Schema: rejects the removed server.service.http.enabled" {
  schema_rejects "additional properties 'enabled' not allowed" --set server.service.http.enabled=false
}

@test "Schema: rejects the removed server.service.https.enabled" {
  schema_rejects "additional properties 'enabled' not allowed" --set server.service.https.enabled=true
}

@test "Schema: rejects the removed server.tls.configFile" {
  schema_rejects "additional properties 'configFile' not allowed" --set server.tls.configFile=x
}

@test "Schema: vcls routes need vclContent" {
  schema_rejects "at '/server/vcls/routes/0'" --set server.vcls.routes[0].name=a
}

@test "Schema: rejects invalid include filenames" {
  # Helm 4 reports a wrong location for propertyNames errors, so match the
  # error itself.
  schema_rejects "invalid propertyName 'sub!helpers.vcl'" --set "server.vcls.routes[0].vclContent=vcl 4.1;" --set "server.vcls.includes.sub!helpers\\.vcl=x"
}

@test "Schema: rejects unknown server.vcls keys" {
  schema_rejects "additional properties 'route' not allowed" --set server.vcls.route=x
}

@test "Schema: rejects a list server.labels" {
  schema_rejects "at '/server/labels'" --set server.labels[0]=a
}

@test "Schema: accepts template-string labels" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  cat > "${values}" <<'EOT'
server:
  labels: "foo: {{ .Release.Name }}"
EOT
  schema_accepts -f "${values}"
}

@test "Schema: accepts arbitrary keys in passthrough objects" {
  schema_accepts --set server.resources.ignore-this=1 --set server.securityContext.foo=bar
}

@test "Schema: probes can be disabled with false" {
  schema_accepts --set server.varnishncsa.enabled=false \
    --set server.readinessProbe=false --set server.livenessProbe=false --set server.startupProbe=false
  run ! grep -qE '^ *(readiness|liveness|startup)Probe:' <<< "$output"
}

@test "Schema: rejects a true probe and a false httpGet" {
  schema_rejects "at '/server/livenessProbe'" --set server.livenessProbe=true
  schema_rejects "at '/server/livenessProbe/httpGet'" --set server.livenessProbe.httpGet=false
}

@test "Schema: affinity can be disabled with false" {
  schema_accepts --set server.affinity=false
  run ! grep -q 'affinity:' <<< "$output"
  schema_rejects "at '/server/affinity'" --set server.affinity=true
}

@test "Schema: topologySpreadConstraints accepts a list or a template string, rejects an object" {
  schema_accepts --set 'server.topologySpreadConstraints[0].maxSkew=1' \
    --set 'server.topologySpreadConstraints[0].topologyKey=topology.kubernetes.io/zone' \
    --set 'server.topologySpreadConstraints[0].whenUnsatisfiable=DoNotSchedule'
  schema_accepts --set 'server.topologySpreadConstraints=- maxSkew: 1'
  schema_rejects "at '/server/topologySpreadConstraints'" --set server.topologySpreadConstraints.maxSkew=1
}

@test "Schema: accepts an empty-string probe" {
  schema_accepts --set server.livenessProbe=
}

@test "Schema: rejects a numeric probe" {
  schema_rejects "at '/server/livenessProbe'" --set server.livenessProbe=5
}

@test "Schema: rejects unknown server.service keys" {
  schema_rejects "additional properties 'tpye' not allowed" --set server.service.tpye=NodePort
}

@test "Schema: rejects object ingress paths" {
  schema_rejects "at '/server/ingress/hosts/0/paths/0'" --set server.ingress.hosts[0].host=a --set server.ingress.hosts[0].paths[0].path=/
}

@test "Schema: autoscaling.minReplicas accepts '-' and integers only" {
  schema_accepts --set server.autoscaling.minReplicas=-
  schema_rejects "at '/server/autoscaling/minReplicas'" --set server.autoscaling.minReplicas=auto
}

@test "Schema: pdb accepts integers and percentages" {
  schema_accepts --set server.pdb.enabled=true --set server.pdb.minAvailable=50%
}

@test "Schema: extraServices targetPort accepts a port name" {
  schema_accepts --set 'server.extraListens[0].name=proxy' --set 'server.extraListens[0].port=8088' \
    --set 'server.service.extraServices[0].name=proxy' --set 'server.service.extraServices[0].targetPort=extra-proxy' \
    --set 'server.service.extraServices[0].port=8088'
  schema_accepts --set 'server.service.extraServices[0].name=proxy' --set 'server.service.extraServices[0].targetPort=8088' \
    --set 'server.service.extraServices[0].port=8088'
  schema_rejects "at '/server/service/extraServices/0/targetPort'" \
    --set 'server.service.extraServices[0].name=proxy' --set 'server.service.extraServices[0].targetPort=Extra_Proxy'
  # an all-digit string is a port number, not a name, so the port range applies
  schema_rejects "at '/server/service/extraServices/0/targetPort'" \
    --set 'server.service.extraServices[0].name=proxy' --set-string 'server.service.extraServices[0].targetPort=65536' \
    --set 'server.service.extraServices[0].port=8088'
  schema_accepts --set 'server.service.extraServices[0].name=proxy' --set-string 'server.service.extraServices[0].targetPort=8088' \
    --set 'server.service.extraServices[0].port=8088'
}

@test "Schema: accepts a template-string autoscaling.behavior" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  cat > "${values}" <<'EOT'
server:
  autoscaling:
    behavior: "scaleDown: {}"
EOT
  schema_accepts -f "${values}"
}

@test "Schema: rejects unknown varnishncsa keys" {
  schema_rejects "additional properties 'extraArg' not allowed" --set server.varnishncsa.extraArg=x
}

@test "Schema: varnishncsa image accepts '-'" {
  schema_accepts --set server.varnishncsa.image.tag=-
}

@test "Schema: accepts a list varnishncsa.extraEnvs" {
  schema_accepts --set server.varnishncsa.extraEnvs[0].name=A --set server.varnishncsa.extraEnvs[0].value=b
}

@test "Schema: varnishncsa probes can be disabled with false" {
  schema_accepts --set server.varnishncsa.enabled=true --set server.varnishncsa.readinessProbe=false --set server.varnishncsa.livenessProbe=false
  # only the varnish container probes are left
  [ "$(grep -cE '^ *readinessProbe:' <<< "$output")" -eq 1 ]
  [ "$(grep -cE '^ *livenessProbe:' <<< "$output")" -eq 1 ]
}

@test "Schema: rejects unknown otel keys" {
  schema_rejects "additional properties 'envs' not allowed" --set server.otel.envs.A=b
}

@test "Schema: rejects unknown server keys" {
  schema_rejects "additional properties 'replicsa' not allowed" --set server.replicsa=2
}

@test "Schema: rejects the misspelled server.hostNetworking from older values.yaml" {
  schema_rejects "additional properties 'hostNetworking' not allowed" --set server.hostNetworking=false
}

@test "Schema: server.vcls cannot be nulled" {
  schema_rejects "missing property 'vcls'" --set server.vcls=null
}

@test "Schema: values.yaml is generated" {
  run head -n 2 "$(chart_dir)/values.yaml"
  [ "${lines[0]}" = "---" ]
  [[ "${lines[1]}" == "# Generated from varnish-common/schema/values.schema.yaml by generate.py. Do not edit." ]]
}

@test "Schema: uncommented examples pass the schema" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  # Uncomment every `#key:` line, and the commented lines indented deeper that follow it.
  awk '
    function indent(l) { match(l, /^ */); return RLENGTH }
    {
      if (match($0, /^ *#[A-Za-z][A-Za-z0-9]*:/)) {
        n = indent($0); active = 1; sub(/#/, ""); print; next
      }
      if (active && match($0, /^ *#/) && indent($0) > n) { sub(/#/, ""); print; next }
      active = 0; print
    }' "$(chart_dir)/values.yaml" > "${values}"
  schema_accepts -f "${values}"
}
