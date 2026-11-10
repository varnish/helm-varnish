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

@test "Schema: rejects an unknown server.kind" {
  schema_rejects "at '/server/kind'" --set server.kind=Pod
}

@test "Schema: rejects a non-numeric server.replicas" {
  schema_rejects "at '/server/replicas'" --set server.replicas=abc
}

@test "Schema: rejects unknown server.http keys" {
  schema_rejects "additional properties 'prot' not allowed" --set server.http.prot=1
}

@test "Schema: accepts numeric and string image tags" {
  # --set makes 7 an integer, which the image helper must compare as a string
  schema_accepts --set server.image.tag=7
  [[ "$output" == *'image: "'*':7"'* ]]

  schema_accepts --set server.image.tag=7.6
  [[ "$output" == *'image: "'*':7.6"'* ]]
}

@test "Schema: accepts null on keys without a default" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  cat > "${values}" <<EOT
server:
  http:
    hostPort: null
  delayedHaltSeconds: null
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

@test "Schema: rejects an unknown delayedShutdown.method" {
  schema_rejects "at '/server/delayedShutdown/method'" --set server.delayedShutdown.method=wait
}

@test "Schema: rejects a string server.vclConfigs" {
  schema_rejects "at '/server/vclConfigs'" --set server.vclConfigs=foo
}

@test "Schema: rejects a numeric server.secret" {
  schema_rejects "at '/server/secret'" --set server.secret=1234
}

@test "Schema: rejects unknown secretFrom keys" {
  schema_rejects "additional properties 'nme' not allowed" --set server.secretFrom.nme=a
}

@test "Schema: vcls routes need vclContent" {
  schema_rejects "at '/server/vcls/routes/0'" --set server.vcls.routes[0].name=a
}

@test "Schema: rejects unknown server.vcls keys" {
  schema_rejects "additional properties 'route' not allowed" --set server.vcls.route=x
}

@test "Schema: rejects invalid include filenames" {
  # Helm 4 reports a wrong location for propertyNames errors, so match the
  # error itself.
  schema_rejects "invalid propertyName 'sub!helpers.vcl'" --set "server.vcls.routes[0].vclContent=vcl 4.1;" --set "server.vcls.includes.sub!helpers\\.vcl=x"
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

@test "Schema: rejects unknown otel keys" {
  schema_rejects "additional properties 'envs' not allowed" --set server.otel.envs.A=b
}

@test "Schema: rejects unknown server keys" {
  schema_rejects "additional properties 'replicsa' not allowed" --set server.replicsa=2
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

@test "Schema: accepts fractional seconds" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  printf 'server:\n  ttl: 0.5\n  threadTimeout: 1.5\n  delayedHaltSeconds: 2.5\n' > "${values}"
  schema_accepts -f "${values}"
  printf 'server:\n  terminationGracePeriodSeconds: 30\n  delayedShutdown:\n    method: sleep\n    sleep:\n      seconds: 2.5\n' > "${values}"
  schema_accepts -f "${values}"
  schema_accepts --set server.delayedHaltSeconds=2.5
}

@test "Schema: still rejects fractional thread counts" {
  local values="${BATS_TEST_TMPDIR}/values.yaml"
  printf 'server:\n  minThreads: 1.5\n' > "${values}"
  schema_rejects "at '/server/minThreads'" -f "${values}"
}
