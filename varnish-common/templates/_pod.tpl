{{/*
Sets up Pod annotations
*/}}
{{- define "varnish-common.podAnnotations" }}
{{- $section := default "server" .section }}
{{- $mse4Config := include "varnish-common.mse4Config" . }}
{{- $tlsConfig := include "varnish-common.tlsConfig" . }}
{{- $vclConfig := include "varnish-common.vclConfig" . }}
{{- $extraManifests := .Values.extraManifests }}
{{- $checksum := dict }}
{{- if not (eq $mse4Config "") }}
{{- $checksum = (merge (dict (print "checksum/" $.Release.Name "-mse4") (sha256sum $mse4Config)) $checksum) }}
{{- end }}
{{- if not (eq $tlsConfig "") }}
{{- $checksum = (merge (dict (print "checksum/" $.Release.Name "-tls") (sha256sum $tlsConfig)) $checksum) }}
{{- end }}
{{- if not (eq $vclConfig "") }}
{{- $checksum = (merge (dict (print "checksum/" $.Release.Name "-vcl") (sha256sum $vclConfig)) $checksum) }}
{{- end }}
{{- if or (not (empty .Values.server.vcls.routes)) (not (empty .Values.server.vcls.includes)) }}
{{- $bundleData := dict
    "routes" .Values.server.vcls.routes
    "includes" .Values.server.vcls.includes
}}
{{- if include "varnish-common.isEnterprise" . }}
{{- $_ := set $bundleData "clusterEnabled" .Values.cluster.enabled }}
{{- end }}
{{- $checksum = (merge (dict (print "checksum/" $.Release.Name "-vcl-bundle") (sha256sum (toJson $bundleData))) $checksum) }}
{{- end }}
{{- if not (empty $extraManifests) }}
{{- range $v := $extraManifests }}
{{- if default false $v.checksum }}
{{- $tp := kindOf $v.data }}
{{- if eq $tp "string" }}
{{- $checksum = (merge (dict (print "checksum/" $.Release.Name "-extra-" $v.name) (sha256sum (tpl $v.data $))) $checksum) }}
{{- else }}
{{- $checksum = (merge (dict (print "checksum/" $.Release.Name "-extra-" $v.name) (sha256sum (toJson $v.data))) $checksum) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- include "varnish-common.toYamlField"
  (merge
    (dict
      "section" $section
      "fieldName" "annotations"
      "fieldKey" "podAnnotations"
      "extraFieldValues" $checksum)
    .) }}
{{- end }}

{{/*
Sets up Pod affinity depending on whether a YAML map or a string is given.
*/}}
{{- define "varnish-common.affinity" -}}
{{- if .Values.server.affinity }}
affinity:
  {{- $tp := kindOf .Values.server.affinity }}
  {{- if eq $tp "string" }}
    {{- tpl .Values.server.affinity . | trim | nindent 2 }}
  {{- else }}
    {{- toYaml .Values.server.affinity | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Sets up Pod tolerations depending on whether a YAML map or a string is given.
*/}}
{{- define "varnish-common.tolerations" -}}
{{- if .Values.server.tolerations }}
tolerations:
  {{- $tp := kindOf .Values.server.tolerations }}
  {{- if eq $tp "string" }}
    {{- tpl .Values.server.tolerations . | trim | nindent 2 }}
  {{- else }}
    {{- toYaml .Values.server.tolerations | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Sets up Pod topology spread constraints depending on whether a YAML list or a
string is given. A constraint without a labelSelector counts no pods and so
spreads nothing, so a missing or null one defaults to the pods of this release.
*/}}
{{- define "varnish-common.topologySpreadConstraints" -}}
{{- $constraints := .Values.server.topologySpreadConstraints | default list }}
{{- if kindIs "string" $constraints }}
{{- $constraints = tpl $constraints . | fromYamlArray }}
{{- end }}
{{- if not (kindIs "slice" $constraints) }}
{{- fail (printf "'server.topologySpreadConstraints' must be a list, got: %v" $constraints) }}
{{- end }}
{{- $out := list }}
{{- range $constraints }}
{{- /* fromYamlArray reports a parse error as a string entry, so this also
surfaces YAML errors from the template string form. */}}
{{- if not (kindIs "map" .) }}
{{- fail (printf "'server.topologySpreadConstraints' entries must be objects, got: %v" .) }}
{{- end }}
{{- $constraint := deepCopy . }}
{{- if kindIs "invalid" (index $constraint "labelSelector") }}
{{- $_ := set $constraint "labelSelector" (dict "matchLabels" (include "varnish-common.selectorLabels" $ | fromYaml)) }}
{{- end }}
{{- $out = append $out $constraint }}
{{- end }}
{{- if $out }}
topologySpreadConstraints:
  {{- toYaml $out | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Sets up terminationGracePeriodSeconds if set explicitly.
*/}}
{{- define "varnish-common.terminationGracePeriodSeconds" -}}
{{- if not (empty .Values.server.terminationGracePeriodSeconds) }}
terminationGracePeriodSeconds: {{ .Values.server.terminationGracePeriodSeconds }}
{{- end }}
{{- end }}

{{/*
Declares the Pod's imagePullSecrets
*/}}
{{- define "varnish-common.podImagePullSecrets" }}
{{- with .Values.global.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Declares the Pod's volume mounts.
*/}}
{{- define "varnish-common.podVolumes" }}
volumes:
- name: {{ .Release.Name }}-varnish-vsm
  emptyDir:
    medium: "Memory"
- name: {{ .Release.Name }}-config-shared
  emptyDir:
    medium: "Memory"
{{- if and (include "varnish-common.isEnterprise" .) .Values.server.licenseSecret }}
- name: varnish-license-volume
  secret:
    secretName: {{ .Values.server.licenseSecret }}
{{- end}}
{{- if not (eq (include "varnish-common.mse4Config" .) "") }}
- name: {{ .Release.Name }}-config-mse4
  configMap:
    name: {{ include "varnish-common.fullname" . }}-mse4
{{- end }}
{{- if not (eq (include "varnish-common.tlsConfig" .) "") }}
- name: {{ .Release.Name }}-config-tls
  configMap:
    name: {{ include "varnish-common.fullname" . }}-tls
{{- end }}
{{- if not (empty .Values.server.vcls.routes) }}
- name: {{ .Release.Name }}-config-vcl-bundle-router
  configMap:
    name: {{ include "varnish-common.fullname" . }}-vcl-bundle-router
- name: {{ .Release.Name }}-config-vcl-bundle-cmds
  configMap:
    name: {{ include "varnish-common.fullname" . }}-vcl-bundle-cmds
{{- range .Values.server.vcls.routes }}
{{- $name := include "varnish-common.vclBundleNormalizeName" . }}
- name: {{ $.Release.Name }}-config-vcl-bundle-{{ include "varnish-common.vclBundleK8sName" $name }}
  configMap:
    name: {{ include "varnish-common.fullname" $ }}-vcl-bundle-{{ include "varnish-common.vclBundleK8sName" $name }}
{{- end }}
{{- else }}
{{- if not (eq (include "varnish-common.vclConfig" .) "") }}
- name: {{ .Release.Name }}-config-vcl
  configMap:
    name: {{ include "varnish-common.fullname" . }}-vcl
{{- end }}
{{- if (include "varnish-common.clusterEnabled" .) }}
- name: {{ .Release.Name }}-config-vcl-wrapped-default-vcl
  configMap:
    name: {{ include "varnish-common.fullname" . }}-vcl-wrapped-default-vcl
{{- end }}
{{- end }}
{{- range $filename, $_ := .Values.server.vcls.includes }}
- name: {{ $.Release.Name }}-config-vcl-bundle-include-{{ include "varnish-common.vclBundleK8sName" $filename }}
  configMap:
    name: {{ include "varnish-common.fullname" $ }}-vcl-bundle-include-{{ include "varnish-common.vclBundleK8sName" $filename }}
{{- end }}
{{- if and (include "varnish-common.agentEnabled" .) (not .Values.server.agent.persistence.enabled) (eq .Values.server.agent.persistence.enableWithVolumeName "") }}
- name: {{ .Release.Name }}-varnish-controller
  emptyDir: {}
{{- end }}
{{- if .Values.server.extraVolumes }}
  {{- $tp := kindOf .Values.server.extraVolumes }}
  {{- if eq $tp "string" }}
    {{- tpl .Values.server.extraVolumes . | trim | nindent 0 }}
  {{- else }}
    {{- toYaml .Values.server.extraVolumes | nindent 0 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Declares the probe for Varnish pod
*/}}
{{- define "varnish-common.varnishPodProbe" }}
{{- $section := default "server" .section }}
{{- $probeName := .probeName }}
{{- $probe := (get (get .Values $section) $probeName) }}
{{- if and $probe (not (empty $probe)) }}
{{- if not .Values.server.http.enabled }}
{{- fail (print "HTTP support must be enabled to enable " $probeName ": 'server.http.enabled'") }}
{{- end }}
{{- $probeName }}:
  {{- if or (hasKey $probe "tcpSocket") (and (not (hasKey $probe "tcpSocket")) (not (hasKey $probe "httpGet"))) }}
  tcpSocket:
    port: {{ .Values.server.http.port }}
  {{- else if hasKey $probe "httpGet" }}
  httpGet:
    port: {{ .Values.server.http.port }}
    {{- if or (empty $probe.httpGet) (not (hasKey $probe.httpGet "path")) }}
    path: /
    {{- else }}
    {{- toYaml (omit $probe.httpGet "port") | nindent 4 -}}
    {{ end }}
  {{- end }}
  {{- toYaml (omit (omit $probe "httpGet") "tcpSocket") | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Mounts server.vcls.includes under /etc/varnish/vcls/
*/}}
{{- define "varnish-common.vclIncludeMounts" }}
{{- range $filename, $_ := .Values.server.vcls.includes }}
    - name: {{ $.Release.Name }}-config-vcl-bundle-include-{{ include "varnish-common.vclBundleK8sName" $filename }}
      mountPath: /etc/varnish/vcls/{{ clean $filename }}
      subPath: {{ base $filename }}
{{- end }}
{{- end }}

{{/*
Declares the Varnish container
*/}}
{{- define "varnish-common.serverContainer" -}}
{{- $mse4Config := include "varnish-common.mse4Config" . }}
{{- $tlsConfig := include "varnish-common.tlsConfig" . -}}
{{/*
Composing the $varnishArgs list or arguments
*/}}
{{- $varnishArgs := list "/usr/sbin/varnishd" "-F" "-T" "127.0.0.1:6082" }}
{{- if not (empty .Values.server.vcls.routes) }}
  {{- $varnishArgs = concat $varnishArgs (list "-I" "/etc/varnish/vcls/cmds.cli" "-f" "") }}
{{- else }}
  {{- if (include "varnish-common.agentEnabled" .) }}
    {{- $varnishArgs = concat $varnishArgs (list "-I" "/var/lib/varnish-controller/varnish-controller-agent/$(VARNISH_CONTROLLER_AGENT_NAME)/cmds.cli") }}
  {{- end }}
  {{- if (include "varnish-common.clusterEnabled" .) }}
    {{- $varnishArgs = concat $varnishArgs (list "-f" "/etc/varnish/wrapped-default.vcl") }}
  {{- else }}
    {{- $varnishArgs = concat $varnishArgs (list "-f" "/etc/varnish/default.vcl") }}
  {{- end }}
{{- end -}}
{{/*
    Parameter list
*/}}
{{- $userParams := .Values.server.parameters | default dict }}
{{- range $pKey, $_ := $userParams }}
  {{- if has (snakecase $pKey) (list "thread_pool_min" "thread_pool_max") }}
    {{- fail "Set thread pool sizes with 'server.minThreads'/'server.maxThreads', not 'server.parameters'" }}
  {{- end }}
{{- end }}
{{- /* min first: varnishd checks min <= max at each -p, and its default min is 100 */}}
{{- if include "varnish-common.isSet" .Values.server.minThreads }}
  {{- $varnishArgs = concat $varnishArgs (list "-p" (print "thread_pool_min=" (toString .Values.server.minThreads))) }}
{{- end }}
{{- if include "varnish-common.isSet" .Values.server.maxThreads }}
  {{- $varnishArgs = concat $varnishArgs (list "-p" (print "thread_pool_max=" (toString .Values.server.maxThreads))) }}
{{- end }}
{{- $varnishParams := merge (dict) $userParams }}
{{- if eq .Values.server.delayedShutdown.method "shutdown_delay" }}
  {{- if not (include "varnish-common.isEnterprise" .) }}
    {{- fail "'server.delayedShutdown.method' 'shutdown_delay' requires Varnish Enterprise, use 'sleep' or 'mempool' instead" }}
  {{- end }}
  {{- $varnishParams = merge (dict
    "shutdown_delay" .Values.server.delayedShutdown.shutdownDelay.seconds
    "shutdown_close" "off") $varnishParams }}
{{- end -}}
{{- range $pKey, $pValue := $varnishParams }}
  {{- $pTp := kindOf $pValue }}
  {{- if eq $pTp "slice" }}
    {{- $varnishArgs = concat $varnishArgs (list "-p" (print (snakecase $pKey) "=" (join "," $pValue))) }}
  {{- else }}
    {{- $varnishArgs = concat $varnishArgs (list "-p" (print (snakecase $pKey) "=" (toString $pValue))) }}
  {{- end }}
{{- end -}}
{{/*
    Listen address
*/}}
{{- if .Values.server.http.enabled }}
    {{- if .Values.server.http.podIP }}
      {{- $varnishArgs = concat $varnishArgs (list "-a" ( print "http=$(POD_IP)" ":" (toString .Values.server.http.port) )) }}
    {{- else }}
      {{- $varnishArgs = concat $varnishArgs (list "-a" ( printf "http=%s:%s" (toString .Values.server.http.address) (toString .Values.server.http.port) )) }}
    {{- end }}
{{- end -}}
{{/*
    Secret, written by the secret init container
*/}}
{{- $varnishArgs = concat $varnishArgs (list "-S" "/etc/varnish/shared/secret" ) }}
{{/*
    MSE4
*/}}
{{- if include "varnish-common.mse4Enabled" . }}
  {{- if and .Values.server.mse4.memoryTarget (not (eq .Values.server.mse4.memoryTarget "")) }}
    {{- $varnishArgs = concat $varnishArgs (list "-p" (print "memory_target=" (toString .Values.server.mse4.memoryTarget))) }}
  {{- end }}
  {{- if (not (empty $mse4Config)) }}
    {{- $varnishArgs = concat $varnishArgs (list "-s" (print "mse4,/etc/varnish/mse4.conf")) }}
  {{- else }}
    {{- $varnishArgs = concat $varnishArgs (list "-s" "mse4") }}
  {{- end }}
{{- end -}}
{{/*
    TLS
*/}}
{{- if .Values.server.tls.enabled }}
  {{- if not (eq $tlsConfig "") }}
    {{- $varnishArgs = concat $varnishArgs (list "-A" "/etc/varnish/tls.conf") }}
  {{- else }}
    {{- $varnishArgs = concat $varnishArgs (list "-a" ( printf "https=%s:%s,https" (toString .Values.server.tls.address) (toString .Values.server.tls.port) )) }}
  {{- end }}
{{- end -}}
{{/*
    Extra arguments
*/}}
{{- if eq (kindOf .Values.server.extraArgs) "string" }}
  {{- $extra := .Values.server.extraArgs | default "" | trim -}}
  {{- if $extra }}
    {{- $varnishArgs = concat $varnishArgs ( regexSplit "\\s+" $extra -1 ) -}}
  {{- end }}
{{- else if eq (kindOf .Values.server.extraArgs) "slice" }}
  {{- range .Values.server.extraArgs }}
    {{- $varnishArgs = append $varnishArgs (toString .) -}}
  {{- end }}
{{- else if .Values.server.extraArgs }}
  {{- fail (printf "Validation failed: .Values.server.extraArgs should be a string or list, not a %s" (kindOf .Values.server.extraArgs)) }}
{{- end }}
{{/*
    Extra Listeners
*/}}
{{- range .Values.server.extraListens }}
  {{- $extraArg := "" }}
  {{- if .name }}
    {{- $extraArg = print $extraArg .name "=" }}
  {{- end }}
  {{- if and .address .port }}
    {{- $extraArg = print $extraArg .address ":" .port }}
  {{- else if .port }}
    {{- $extraArg = print $extraArg ":" .port }}
  {{- else if .path }}
    {{- $extraArg = print $extraArg .path }}
    {{- if .user }}
      {{- $extraArg = print $extraArg ",user=" .user }}
    {{- end }}
    {{- if .group }}
      {{- $extraArg = print $extraArg ",group=" .group }}
    {{- end }}
    {{- if .mode }}
      {{- $extraArg = print $extraArg ",mode=" .mode }}
    {{- end }}
  {{- else }}
    {{ fail "Extra listens require either port or path: 'server.extraListens[].port' or 'server.extraListens[].path'" }}
  {{- end }}
  {{- if .proto }}
    {{- $extraArg = print $extraArg "," .proto }}
  {{- end }}
  {{- $varnishArgs = concat $varnishArgs (list "-a" $extraArg) }}
{{- end -}}
- name: {{ .Chart.Name }}
  {{- include "varnish-common.securityContext" (merge (dict "section" "server") .) | nindent 2 }}
  {{- include "varnish-common.image" (merge (dict "image" .Values.server.image) .) | nindent 2 }}
  ports:
    {{- if .Values.server.http.enabled }}
    - name: http
      containerPort: {{ .Values.server.http.port }}
      protocol: TCP
      {{- if and .Values.server.http.hostPort (not (empty .Values.server.http.hostPort)) }}
      hostPort: {{ .Values.server.http.hostPort }}
      {{- end }}
    {{- end }}
    {{- if .Values.server.tls.enabled }}
    - name: https
      containerPort: {{ .Values.server.tls.port }}
      protocol: TCP
      {{- if and .Values.server.tls.hostPort (not (empty .Values.server.tls.hostPort)) }}
      hostPort: {{ .Values.server.tls.hostPort }}
      {{- end }}
    {{- end }}
    {{- range .Values.server.extraListens }}
    {{- if not .name }}
    {{- fail "Name must be set in extraListens: 'server.extraListens[].name'" }}
    {{- end }}
    - name: extra-{{ .name }}
      containerPort: {{ .port }}
      protocol: TCP
      {{- if and .hostPort (not (empty .hostPort)) }}
      hostPort: {{ .hostPort }}
      {{- end }}
    {{- end }}
  {{- include "varnish-common.varnishPodProbe" (merge (dict "probeName" "startupProbe") .) | nindent 2 }}
  {{- include "varnish-common.varnishPodProbe" (merge (dict "probeName" "livenessProbe") .) | nindent 2 }}
  {{- include "varnish-common.varnishPodProbe" (merge (dict "probeName" "readinessProbe") .) | nindent 2 }}
  {{- include "varnish-common.resources" (merge (dict "section" "server") .) | nindent 2 }}
  env:
    {{- if and .Values.server.http.enabled .Values.server.http.podIP }}
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    {{- end }}
    {{- if include "varnish-common.mse4Enabled" . }}
    {{- if and .Values.server.mse4.memoryTarget (not (eq .Values.server.mse4.memoryTarget "")) }}
    - name: MSE_MEMORY_TARGET
      value: {{ .Values.server.mse4.memoryTarget | quote }}
    {{- end }}
    {{- if (not (empty $mse4Config)) }}
    - name: MSE4_CONFIG
      value: /etc/varnish/mse4.conf
    {{- else }}
    - name: VARNISH_STORAGE_BACKEND
      value: "mse4"
    {{- end }}
    {{- end }}

    {{- if .Values.server.tls.enabled }}
    {{- if not (eq $tlsConfig "") }}
    - name: VARNISH_TLS_CFG
      value: /etc/varnish/tls.conf
    {{- else }}
    - name: VARNISH_TLS_CFG
      value: "true"
    {{- end }}
    {{- end }}
    {{- if (include "varnish-common.agentEnabled" .) }}
    {{- if and (eq (toString .Values.server.replicas) "1") .Values.server.agent.useReleaseName }}
    - name: VARNISH_CONTROLLER_AGENT_NAME
      value: "{{ .Release.Name }}"
    {{- else }}
    - name: VARNISH_CONTROLLER_AGENT_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    {{- end }}
    {{- end }}
    {{- if (include "varnish-common.clusterEnabled" .) }}
    {{- include "varnish-common.clusterEnv" . | nindent 4 }}
    {{- end }}
    {{- include "varnish-common.toEnv" (merge (dict "envs" .Values.server.extraEnvs) .) | nindent 4 }}
  {{- if .Values.server.command }}
  command:
    {{- .Values.server.command | toYaml | nindent 4 }}
  {{- else }}
  command:
    {{- $varnishArgs | toYaml | nindent 4 }}
  {{- end }}
  volumeMounts:
    - name: {{ .Release.Name }}-varnish-vsm
      mountPath: /var/lib/varnish
    - name: {{ .Release.Name }}-config-shared
      mountPath: /etc/varnish/shared
    {{- if and (include "varnish-common.isEnterprise" .) .Values.server.licenseSecret }}
    - name: varnish-license-volume
      mountPath: /etc/varnish/varnish-enterprise.lic
      readOnly: true
      subPath: varnish-enterprise.lic
    {{- end}}
    {{- if not (eq (include "varnish-common.mse4Config" .) "") }}
    - name: {{ .Release.Name }}-config-mse4
      mountPath: /etc/varnish/mse4.conf
      subPath: mse4.conf
    {{- end }}
    {{- if not (eq $tlsConfig "") }}
    - name: {{ .Release.Name }}-config-tls
      mountPath: /etc/varnish/tls.conf
      subPath: tls.conf
    {{- end }}
    {{- if not (empty .Values.server.vcls.routes) }}
    - name: {{ .Release.Name }}-config-vcl-bundle-router
      mountPath: /etc/varnish/vcls/router.vcl
      subPath: router.vcl
    - name: {{ .Release.Name }}-config-vcl-bundle-cmds
      mountPath: /etc/varnish/vcls/cmds.cli
      subPath: cmds.cli
    {{- range .Values.server.vcls.routes }}
    {{- $name := include "varnish-common.vclBundleNormalizeName" . }}
    - name: {{ $.Release.Name }}-config-vcl-bundle-{{ include "varnish-common.vclBundleK8sName" $name }}
      mountPath: /etc/varnish/vcls/{{ $name }}.vcl
      subPath: {{ $name }}.vcl
    {{- end }}
    {{- else }}
    {{- if not (eq (include "varnish-common.vclConfig" .) "") }}
    - name: {{ .Release.Name }}-config-vcl
      mountPath: "/etc/varnish/default.vcl"
      subPath: default.vcl
    {{- end }}
    {{- if (include "varnish-common.clusterEnabled" .) }}
    - name: {{ .Release.Name }}-config-vcl-wrapped-default-vcl
      mountPath: "/etc/varnish/wrapped-default.vcl"
      subPath: "wrapped-default.vcl"
    {{- end }}
    {{- end }}
    {{- include "varnish-common.vclIncludeMounts" . }}
    {{- if and (eq .Values.server.kind "StatefulSet") (and (include "varnish-common.mse4Enabled" .) .Values.server.mse4.persistence.enabled) }}
    - name: {{ .Release.Name }}-mse4
      mountPath: /var/lib/mse4
    {{- end }}
    {{- if (include "varnish-common.agentEnabled" .) }}
    {{- if not (eq .Values.server.agent.persistence.enableWithVolumeName "") }}
    - name: {{ .Values.server.agent.persistence.enableWithVolumeName }}
      mountPath: /var/lib/varnish-controller
    {{- else }}
    - name: {{ .Release.Name }}-varnish-controller
      mountPath: /var/lib/varnish-controller
    {{- end }}
    {{- end }}
    {{- if .Values.server.extraVolumeMounts }}
      {{- $tp := kindOf .Values.server.extraVolumeMounts }}
      {{- if eq $tp "string" }}
        {{- tpl .Values.server.extraVolumeMounts . | trim | nindent 4 }}
      {{- else }}
        {{- toYaml .Values.server.extraVolumeMounts | nindent 4 }}
      {{- end }}
    {{- end }}
  {{- if eq .Values.server.delayedShutdown.method "sleep" }}
  lifecycle:
    preStop:
      exec:
        command: ["/bin/sleep", {{ .Values.server.delayedShutdown.sleep.seconds | quote }}]
  {{- else if eq .Values.server.delayedShutdown.method "mempool" }}
  lifecycle:
    preStop:
      exec:
        command:
        - /bin/sh
        - -c
        - |
          set -e
          while [ "$(varnishstat -1 | awk '/MEMPOOL.sess[0-9]+.live/ { a+=$2 } END { print a }')" -ne 0 ]; do
            echo >&2 "Waiting for Varnish to drain connections..."
            sleep {{ .Values.server.delayedShutdown.mempool.pollSeconds }}
          done
          sleep {{ .Values.server.delayedShutdown.mempool.waitSeconds }}
  {{- end }}
{{- end }}

{{/*
Declares the Varnish NCSA container
*/}}
{{- define "varnish-common.ncsaContainer" -}}
{{- if .Values.server.varnishncsa.enabled }}
- name: {{ .Chart.Name }}-ncsa
  {{- /* varnishncsa has no securityContext of its own: global only */}}
  {{- include "varnish-common.securityContext" (merge (dict "section" "global") .) | nindent 2 }}
  {{- include "varnish-common.image" (merge (dict "image" .Values.server.image) .) | nindent 2 }}
  {{- include "varnish-common.resources" (merge (dict "section" "server.varnishncsa") .) | nindent 2 }}
  command: ["/usr/bin/varnishncsa"]
  {{- $ncsaArgs := list }}
  {{- if eq (kindOf .Values.server.varnishncsa.extraArgs) "string" }}
    {{- $extra := .Values.server.varnishncsa.extraArgs | trim }}
    {{- if $extra }}
      {{- $ncsaArgs = concat $ncsaArgs (regexSplit "\\s+" $extra -1) }}
    {{- end }}
  {{- else if .Values.server.varnishncsa.extraArgs }}
    {{- range .Values.server.varnishncsa.extraArgs }}
      {{- $ncsaArgs = append $ncsaArgs (toString .) }}
    {{- end }}
  {{- end }}
  {{- if $ncsaArgs }}
  args: {{- toYaml $ncsaArgs | nindent 4 }}
  {{- end }}
  env:
    - name: VSM_NOPID
      value: "1"
  {{- if .Values.server.varnishncsa.extraEnvs }}
    {{- include "varnish-common.toEnv" (merge (dict "envs" .Values.server.varnishncsa.extraEnvs) .) | trim | nindent 4 }}
  {{- end }}
  volumeMounts:
    - name: {{ .Release.Name }}-varnish-vsm
      mountPath: /var/lib/varnish
    - name: {{ .Release.Name }}-config-shared
      mountPath: /etc/varnish/shared
    {{- if .Values.server.varnishncsa.extraVolumeMounts }}
    {{- $tp := kindOf .Values.server.varnishncsa.extraVolumeMounts }}
    {{- if eq $tp "string" }}
    {{- tpl .Values.server.varnishncsa.extraVolumeMounts . | trim | nindent 4 }}
    {{- else }}
    {{- toYaml .Values.server.varnishncsa.extraVolumeMounts | nindent 4 }}
    {{- end }}
    {{- end }}
{{- end }}
{{- end }}


{{/*
Declares the Varnish Otel container
*/}}
{{- define "varnish-common.otelContainer" -}}
{{- if .Values.server.otel.enabled }}
- name: {{ .Chart.Name }}-otel
  {{- include "varnish-common.securityContext" (merge (dict "section" "server.otel") .) | nindent 2 }}
  {{- include "varnish-common.image" (merge (dict "image" .Values.server.image) .) | nindent 2 }}
  {{- include "varnish-common.resources" (merge (dict "section" "server.otel") .) | nindent 2 }}
  command: ["/usr/bin/varnish-otel"]
  {{- if .Values.server.otel.env }}
  env:
    {{- include "varnish-common.toEnv" (merge (dict "envs" .Values.server.otel.env) .) | nindent 4 }}
  {{- end }}
  volumeMounts:
    - name: {{ .Release.Name }}-varnish-vsm
      mountPath: /var/lib/varnish
    - name: {{ .Release.Name }}-config-shared
      mountPath: /etc/varnish/shared
{{- end }}
{{- end }}

{{/*
Declares the Varnish Controller Agent container
*/}}
{{- define "varnish-common.agentContainer" -}}
{{- if (include "varnish-common.agentEnabled" .) }}
- name: {{ .Chart.Name }}-agent
  {{- include "varnish-common.securityContext" (merge (dict "section" "server.agent") .) | nindent 2 }}
  {{- include "varnish-common.image" (merge (dict "image" .Values.server.agent.image) .) | nindent 2 }}
  env:
    - name: VARNISH_CONTROLLER_VARNISH_HOST
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: VARNISH_CONTROLLER_VARNISH_ADMIN_HOST
      value: "127.0.0.1"
    - name: VARNISH_CONTROLLER_VARNISH_ADMIN_PORT
      value: "6082"
    - name: VARNISH_CONTROLLER_VARNISH_SECRET
      value: /etc/varnish/shared/secret
    {{- if .Values.server.http.enabled }}
    - name: VARNISH_CONTROLLER_VARNISH_PORT
      value: {{ .Values.server.http.port | quote }}
    {{- else }}
    {{- fail "HTTP support must be enabled to enable Varnish Controller Agent: 'server.http.enabled'" }}
    {{- end }}
    {{- if and (eq (toString .Values.server.replicas) "1") .Values.server.agent.useReleaseName }}
    - name: VARNISH_CONTROLLER_AGENT_NAME
      value: "{{ .Release.Name }}"
    {{- else }}
    - name: VARNISH_CONTROLLER_AGENT_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    {{- end }}
    {{- if and .Values.server.agent.logLevel (not (eq .Values.server.agent.logLevel "")) }}
    - name: VARNISH_CONTROLLER_LOG
      value: {{ .Values.server.agent.logLevel | quote }}
    {{- end }}
    {{- include "varnish-common.natsServer" . | indent 4 }}
    {{- if and .Values.server.agent.tags (not (empty .Values.server.agent.tags)) }}
    - name: VARNISH_CONTROLLER_TAGS
      value: {{ .Values.server.agent.tags | join "," | quote }}
    {{- end }}
    {{- if and .Values.server.agent.location .Values.server.agent.location.longitude (not (eq .Values.server.agent.location.longitude "")) }}
    - name: VARNISH_CONTROLLER_LONGITUDE
      value: {{ .Values.server.agent.location.longitude | quote }}
    {{- end }}
    {{- if and .Values.server.agent.location .Values.server.agent.location.latitude (not (eq .Values.server.agent.location.latitude "")) }}
    - name: VARNISH_CONTROLLER_LATITUDE
      value: {{ .Values.server.agent.location.latitude | quote }}
    {{- end }}
    {{- if not (empty .Values.server.baseUrl) }}
    - name: VARNISH_CONTROLLER_BASE_URL
      value: "{{ .Values.server.baseUrl }}"
    {{- else }}
    - name: VARNISH_CONTROLLER_BASE_URL
      value: "http://$(VARNISH_CONTROLLER_VARNISH_HOST){{ if ne (toString .Values.server.http.port) "80" }}:{{ .Values.server.http.port }}{{ end }}"
    {{- end }}
    {{- if not (empty .Values.server.agent.privateToken) }}
    - name: VARNISH_CONTROLLER_PRIVATE_TOKEN
      value: {{ .Values.server.agent.privateToken | quote }}
    {{- end }}
    {{- include "varnish-common.toEnv" (merge (dict "envs" .Values.server.agent.extraEnvs) .) | nindent 4 }}
  {{- include "varnish-common.resources" (merge (dict "section" "server.agent") .) | nindent 2 }}
  command: ["/usr/bin/varnish-controller-agent"]
  {{- if and .Values.server.agent.extraArgs (not (empty .Values.server.agent.extraArgs)) }}
  {{- $agentArgs := list }}
  {{- range .Values.server.agent.extraArgs }}
    {{- $agentArgs = append $agentArgs (toString .) }}
  {{- end }}
  args: {{- toYaml $agentArgs | nindent 4 }}
  {{- end }}
  volumeMounts:
    - name: {{ .Release.Name }}-varnish-vsm
      mountPath: /var/lib/varnish
    - name: {{ .Release.Name }}-config-shared
      mountPath: /etc/varnish/shared
    {{- if not (eq (include "varnish-common.vclConfig" .) "") }}
    - name: {{ .Release.Name }}-config-vcl
      mountPath: "/etc/varnish/default.vcl"
      subPath: default.vcl
    {{- end }}
    {{- include "varnish-common.vclIncludeMounts" . }}
    {{- if not (eq .Values.server.agent.persistence.enableWithVolumeName "") }}
    - name: {{ .Values.server.agent.persistence.enableWithVolumeName }}
      mountPath: /var/lib/varnish-controller
    {{- else }}
    - name: {{ .Release.Name }}-varnish-controller
      mountPath: /var/lib/varnish-controller
    {{- end }}
    {{- if .Values.server.agent.extraVolumeMounts }}
    {{- $tp := kindOf .Values.server.agent.extraVolumeMounts }}
    {{- if eq $tp "string" }}
    {{- tpl .Values.server.agent.extraVolumeMounts . | trim | nindent 4 }}
    {{- else }}
    {{- toYaml .Values.server.agent.extraVolumeMounts | nindent 4 }}
    {{- end }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
Declares the Varnish Controller VCLI container for agent auto-removal
*/}}
{{- define "varnish-common.vcliContainer" -}}
{{- if and (include "varnish-common.agentEnabled" .) (eq .Values.server.agent.autoRemove.method "vcli") }}
- name: {{ .Chart.Name }}-vcli
  {{- include "varnish-common.securityContext" (merge (dict "section" "server.agent.autoRemove.vcli") .) | nindent 2 }}
  {{- include "varnish-common.image" (merge (dict "image" .Values.server.agent.autoRemove.vcli.image) .) | nindent 2 }}
  command:
    - /bin/sh
    - -c
    - |
      {{/* Force login to make sure VCLI fail early when misconfigured */}}
      vcli login || exit 1
      sleep inf
  env:
    {{- if .Values.server.agent.autoRemove.vcli.internal.enabled }}
    {{- $vcNamespace := .Release.Namespace }}
    {{- $vcReleaseName := "varnish-controller" }}
    {{- $vcClusterDomain := .Values.server.agent.autoRemove.vcli.internal.clusterDomain }}
    {{- if not (empty .Values.server.agent.autoRemove.vcli.internal.namespace) }}
    {{- $vcNamespace = .Values.server.agent.autoRemove.vcli.internal.namespace }}
    {{- end }}
    {{- if not (empty .Values.server.agent.autoRemove.vcli.internal.releaseName) }}
    {{- $vcReleaseName = .Values.server.agent.autoRemove.vcli.internal.releaseName }}
    {{- end }}
    - name: VARNISH_CONTROLLER_CLI_ENDPOINT
      value: "http{{ if .Values.server.agent.autoRemove.vcli.internal.https }}s{{ end }}://{{ $vcReleaseName }}-apigw.{{ $vcNamespace }}.svc.{{ $vcClusterDomain }}{{ if or (and .Values.server.agent.autoRemove.vcli.internal.https (not (eq (toString .Values.server.agent.autoRemove.vcli.internal.port) "443"))) (and (not .Values.server.agent.autoRemove.vcli.internal.https) (not (eq (toString .Values.server.agent.autoRemove.vcli.internal.port) "80"))) }}:{{ .Values.server.agent.autoRemove.vcli.internal.port }}{{ end }}"
    {{- else if and (not .Values.server.agent.autoRemove.vcli.internal.enabled) (not (empty .Values.server.agent.autoRemove.vcli.externalAddress)) }}
    - name: VARNISH_CONTROLLER_CLI_ENDPOINT
      value: {{ .Values.server.agent.autoRemove.vcli.externalAddress | quote }}
    {{- else }}
    {{- fail "Either 'server.agent.autoRemove.vcli.internal.enabled' or 'server.agent.autoRemove.vcli.externalAddress' must be set" }}
    {{- end }}
    {{- if .Values.server.agent.autoRemove.vcli.insecure }}
    - name: VARNISH_CONTROLLER_CLI_INSECURE
      value: "true"
    {{- end }}
    - name: VARNISH_CONTROLLER_CLI_USERNAME
      value: {{ .Values.server.agent.autoRemove.vcli.username | quote }}
    {{- if not (empty .Values.server.agent.autoRemove.vcli.password) }}
    - name: VARNISH_CONTROLLER_CLI_PASSWORD
      value: {{ .Values.server.agent.autoRemove.vcli.password | quote }}
    {{- else if not (empty .Values.server.agent.autoRemove.vcli.passwordFrom) }}
    - name: VARNISH_CONTROLLER_CLI_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ .Values.server.agent.autoRemove.vcli.passwordFrom.name | quote }}
          key: {{ .Values.server.agent.autoRemove.vcli.passwordFrom.key | quote }}
    {{- else }}
    {{- fail "Either 'server.agent.autoRemove.vcli.password' or 'server.agent.autoRemove.vcli.passwordFrom' must be set" }}
    {{- end }}
    {{- if (include "varnish-common.agentEnabled" .) }}
    {{- if and (eq (toString .Values.server.replicas) "1") .Values.server.agent.useReleaseName }}
    - name: VARNISH_CONTROLLER_AGENT_NAME
      value: "{{ .Release.Name }}"
    {{- else }}
    - name: VARNISH_CONTROLLER_AGENT_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    {{- end }}
    {{- end }}
    {{- if .Values.server.agent.autoRemove.vcli.extraEnvs }}
    {{- include "varnish-common.toEnv" (merge (dict "envs" .Values.server.agent.autoRemove.vcli.extraEnvs) .) | nindent 4 }}
    {{- end }}
  {{- include "varnish-common.resources" (merge (dict "section" "server.agent.autoRemove.vcli") .) | nindent 2 }}
  volumeMounts:
    - name: {{ .Release.Name }}-config-shared
      mountPath: /etc/varnish/shared
    {{- if .Values.server.agent.autoRemove.vcli.extraVolumeMounts }}
    {{- $tp := kindOf .Values.server.agent.autoRemove.vcli.extraVolumeMounts }}
    {{- if eq $tp "string" }}
    {{- tpl .Values.server.agent.autoRemove.vcli.extraVolumeMounts . | trim | nindent 4 }}
    {{- else }}
    {{- toYaml .Values.server.agent.autoRemove.vcli.extraVolumeMounts | nindent 4 }}
    {{- end }}
    {{- end }}
  lifecycle:
    preStop:
      exec:
        command:
          - /bin/sh
          - -c
          - |
            vcli login
            while true; do
              echo >&2 "Waiting for Varnish Controller Agent to shutdown..."
              if vcli agent list -f "name=${VARNISH_CONTROLLER_AGENT_NAME},state=3" 2>/dev/null; then
                agentId=$(vcli agent list --csv -f "name=${VARNISH_CONTROLLER_AGENT_NAME},state=3" | tail -n1 | cut -d, -f1)
                echo "Removing ${VARNISH_CONTROLLER_AGENT_NAME} from Varnish Controller"
                vcli agent delete -y "${agentId}"
                break
              fi
              sleep 1
            done
{{- end }}
{{- end }}

{{/*
Declares the Varnish extra container
*/}}
{{- define "varnish-common.extraContainers" -}}
{{- if .Values.server.extraContainers }}
{{- $tp := kindOf .Values.server.extraContainers }}
{{- if eq $tp "string" }}
  {{- tpl .Values.server.extraContainers . | trim | nindent 0 }}
{{- else }}
  {{- toYaml .Values.server.extraContainers | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Declares the Varnish init containers
*/}}
{{- define "varnish-common.initContainers" -}}
{{- $mse4PersistenceEnabled := and (include "varnish-common.mse4Enabled" .) .Values.server.mse4.persistence.enabled }}
initContainers:
  - name: {{ .Chart.Name }}-secret
    {{- include "varnish-common.securityContext" (merge (dict "section" "server") .) | nindent 4 }}
    {{- include "varnish-common.image" (merge (dict "image" .Values.server.image) .) | nindent 4 }}
    {{- include "varnish-common.resources" (merge (dict "section" "server") .) | nindent 4 }}
    command:
      - sh
      - -c
      - umask 077; test -s /etc/varnish/shared/secret || head -c 32 /dev/urandom > /etc/varnish/shared/secret
    volumeMounts:
      - name: {{ .Release.Name }}-config-shared
        mountPath: /etc/varnish/shared
{{- if $mse4PersistenceEnabled }}
  - name: mse4-config
    {{- include "varnish-common.image" (merge (dict "image" .Values.server.image) .) | nindent 4 }}
    command:
     - mkfs.mse4
     - -c
     - /etc/varnish/mse4.conf
     - configure
    volumeMounts:
     - name: {{ .Release.Name }}-mse4
       mountPath: /var/lib/mse4
     - name: {{ .Release.Name }}-config-mse4
       mountPath: /etc/varnish/mse4.conf
       subPath: mse4.conf
{{- end }}
{{- if .Values.server.extraInitContainers }}
  {{- $tp := kindOf .Values.server.extraInitContainers }}
  {{- if eq $tp "string" }}
    {{- tpl .Values.server.extraInitContainers . | trim | nindent 2 }}
  {{- else }}
    {{- toYaml .Values.server.extraInitContainers | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}
