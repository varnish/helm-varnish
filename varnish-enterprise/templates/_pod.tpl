{{/*
Sets up Pod annotations
*/}}
{{- define "varnish-enterprise.podAnnotations" }}
{{- $section := default "server" .section }}
{{- $defaultVcl := osBase .Values.server.vclConfigPath }}
{{- $mseConfig := include "varnish-enterprise.mseConfig" . }}
{{- $mse4Config := include "varnish-enterprise.mse4Config" . }}
{{- $tlsConfig := include "varnish-enterprise.tlsConfig" . }}
{{- $vclConfig := include "varnish-enterprise.vclConfig" . }}
{{- $vclConfigs := omit .Values.server.vclConfigs $defaultVcl }}
{{- $cmdfileConfig := include "varnish-enterprise.cmdfileConfig" . }}
{{- $secretConfig := include "varnish-enterprise.secretConfig" . }}
{{- $extraManifests := .Values.extraManifests }}
{{- $checksum := dict }}
{{- if not (eq $mseConfig "") }}
{{- $checksum = (merge (dict (print "checksum/" $.Release.Name "-mse") (sha256sum $mseConfig)) $checksum) }}
{{- end }}
{{- if not (eq $mse4Config "") }}
{{- $checksum = (merge (dict (print "checksum/" $.Release.Name "-mse4") (sha256sum $mse4Config)) $checksum) }}
{{- end }}
{{- if not (eq $tlsConfig "") }}
{{- $checksum = (merge (dict (print "checksum/" $.Release.Name "-tls") (sha256sum $tlsConfig)) $checksum) }}
{{- end }}
{{- if not (eq $vclConfig "") }}
{{- $checksum = (merge (dict (print "checksum/" $.Release.Name "-vcl") (sha256sum $vclConfig)) $checksum) }}
{{- end }}
{{- if not (empty $vclConfigs) }}
{{- range $k, $v := $vclConfigs }}
{{- $checksum = (merge (dict (print "checksum/" $.Release.Name "-vcl-" (regexReplaceAll "\\W+" $k "-")) (sha256sum (tpl $v $))) $checksum) }}
{{- end }}
{{- end }}
{{- if not (eq $cmdfileConfig "") }}
{{- $checksum = (merge (dict (print "checksum/" $.Release.Name "-cmdfile") (sha256sum $cmdfileConfig)) $checksum) }}
{{- end }}
{{- if not (eq $secretConfig "") }}
{{- $checksum = (merge (dict (print "checksum/" $.Release.Name "-secret") (sha256sum $secretConfig)) $checksum) }}
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
{{- include "varnish-enterprise.toYamlField"
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
{{- define "varnish-enterprise.affinity" -}}
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
{{- define "varnish-enterprise.tolerations" -}}
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
Sets up terminationGracePeriodSeconds based on whether there's an explicit
terminationGracePeriodSeconds, or 60 seconds after delayedHaltSeconds if
present.
*/}}
{{- define "varnish-enterprise.terminationGracePeriodSeconds" -}}
{{- if not (empty .Values.server.terminationGracePeriodSeconds) }}
terminationGracePeriodSeconds: {{ .Values.server.terminationGracePeriodSeconds }}
{{- else if not (empty .Values.server.delayedHaltSeconds) }}
terminationGracePeriodSeconds: {{ add .Values.server.delayedHaltSeconds 60 }}
{{- end }}
{{- end }}

{{/*
Declares the Pod's imagePullSecrets
*/}}
{{- define "varnish-enterprise.podImagePullSecrets" }}
{{- with .Values.global.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Declares the Pod's volume mounts.
*/}}
{{- define "varnish-enterprise.podVolumes" }}
{{- $defaultVcl := osBase .Values.server.vclConfigPath }}
{{- $wrappedDefaultVCL := "wrapped-default.vcl" }}
volumes:
- name: {{ .Release.Name }}-varnish-vsm
  emptyDir:
    medium: "Memory"
- name: {{ .Release.Name }}-config-shared
  emptyDir:
    medium: "Memory"
{{- if .Values.server.licenseSecret }}
- name: varnish-license-volume
  secret:
    secretName: {{ .Values.server.licenseSecret }}
{{- end}}
{{- if not (eq (include "varnish-enterprise.mseConfig" .) "") }}
- name: {{ .Release.Name }}-config-mse
  configMap:
    name: {{ include "varnish-enterprise.fullname" . }}-mse
{{- end }}
{{- if not (eq (include "varnish-enterprise.mse4Config" .) "") }}
- name: {{ .Release.Name }}-config-mse4
  configMap:
    name: {{ include "varnish-enterprise.fullname" . }}-mse4
{{- end }}
{{- if not (eq (include "varnish-enterprise.tlsConfig" .) "") }}
- name: {{ .Release.Name }}-config-tls
  configMap:
    name: {{ include "varnish-enterprise.fullname" . }}-tls
{{- end }}
{{- if and (not (empty .Values.server.secretFrom)) (not (eq .Values.server.secret "")) }}
{{- fail "Either 'server.secret' or 'server.secretFrom' can be set." }}
{{- else if and (not (empty .Values.server.secretFrom)) }}
{{- if or (not (hasKey .Values.server.secretFrom "name")) (eq .Values.server.secretFrom.name "") }}
{{- fail "'server.secretFrom' must contain a 'name' key." }}
{{- end }}
{{- if or (not (hasKey .Values.server.secretFrom "key")) (eq .Values.server.secretFrom.key "") }}
{{- fail "'server.secretFrom' must contain a 'key' key." }}
{{- end }}
- name: {{ .Release.Name }}-config-secret
  secret:
    secretName: {{ .Values.server.secretFrom.name | quote }}
{{- else if not (eq (include "varnish-enterprise.secretConfig" .) "") }}
- name: {{ .Release.Name }}-config-secret
  secret:
    secretName: {{ include "varnish-enterprise.fullname" . }}-secret
{{- end }}
{{- if not (eq (include "varnish-enterprise.vclConfig" .) "") }}
- name: {{ .Release.Name }}-config-vcl
  configMap:
    name: {{ include "varnish-enterprise.fullname" . }}-vcl
{{- end }}
{{- $vclConfigs := omit .Values.server.vclConfigs $defaultVcl }}
{{- if not (empty $vclConfigs) }}
{{- range $k, $v := $vclConfigs }}
- name: {{ $.Release.Name }}-config-vcl-{{ regexReplaceAll "\\W+" $k "-" }}
  configMap:
    name: {{ include "varnish-enterprise.fullname" $ }}-vcl-{{ regexReplaceAll "\\W+" $k "-" }}
{{- end }}
{{- end }}
{{- if .Values.cluster.enabled }}
- name: {{ $.Release.Name }}-config-vcl-{{ regexReplaceAll "\\W+" $wrappedDefaultVCL "-" }}
  configMap:
    name: {{ include "varnish-enterprise.fullname" $ }}-vcl-{{ regexReplaceAll "\\W+" $wrappedDefaultVCL "-" }}
{{- end }}
{{- if not (eq (include "varnish-enterprise.cmdfileConfig" .) "") }}
- name: {{ .Release.Name }}-config-cmdfile
  configMap:
    name: {{ include "varnish-enterprise.fullname" . }}-cmdfile
{{- end }}
{{- if and .Values.server.agent.enabled (not .Values.server.agent.persistence.enabled) (eq .Values.server.agent.persistence.enableWithVolumeName "") }}
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
Declares the probe for Varnish Enterprise pod
*/}}
{{- define "varnish-enterprise.varnishPodProbe" }}
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
Declares the Varnish Enterprise container
*/}}
{{- define "varnish-enterprise.serverContainer" -}}
{{- $mseConfig := include "varnish-enterprise.mseConfig" . }}
{{- $mse4Config := include "varnish-enterprise.mse4Config" . }}
{{- $cmdfileConfig := include "varnish-enterprise.cmdfileConfig" . }}
{{- $defaultVcl := osBase .Values.server.vclConfigPath }}
{{- $tp := kindOf .Values.server.extraArgs }}
{{- $varnishExtraArgs := list }}
{{- $wrappedDefaultVCL := "wrapped-default.vcl" }}
{{- if eq $tp "string" }}
{{- $varnishExtraArgs = append $varnishExtraArgs .Values.server.extraArgs }}
{{- else }}
{{- $varnishExtraArgs = concat $varnishExtraArgs .Values.server.extraArgs }}
{{- end }}
{{- if and .Values.server.agent.enabled (not (eq $cmdfileConfig "")) }}
{{ fail "Cannot enable both cmdfile and agent, use either: 'server.cmdfileConfig' or 'server.agent.enabled'" }}
{{- else if .Values.server.agent.enabled }}
{{- if .Values.server.initAgent.enabled }}
{{- $varnishExtraArgs = concat $varnishExtraArgs (list "-I" "/etc/varnish/shared/agent/cmds.cli") }}
{{- else }}
{{- $varnishExtraArgs = concat $varnishExtraArgs (list "-I" "/var/lib/varnish-controller/varnish-controller-agent/$(VARNISH_CONTROLLER_AGENT_NAME)/cmds.cli") }}
{{- end }}
{{- else if not (eq $cmdfileConfig "") }}
{{- $varnishExtraArgs = concat $varnishExtraArgs (list "-I" .Values.server.cmdfileConfigPath) }}
{{- end }}
{{- range .Values.server.extraListens }}
{{- $extraArg := "-a " }}
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
{{- $varnishExtraArgs = append $varnishExtraArgs $extraArg }}
{{- end }}
{{- $varnishParams := .Values.server.parameters | default dict }}
{{- if eq .Values.server.delayedShutdown.method "shutdown_delay" }}
{{- $varnishParams = merge (dict
    "shutdown_delay" .Values.server.delayedShutdown.shutdownDelay.seconds
    "shutdown_close" "off") $varnishParams }}
{{- end }}
{{- range $pKey, $pValue := $varnishParams }}
{{- $pTp := kindOf $pValue }}
{{- if eq $pTp "slice" }}
{{- $varnishExtraArgs = append $varnishExtraArgs (print "-p " (snakecase $pKey) "=" (join "," $pValue)) }}
{{- else }}
{{- $varnishExtraArgs = append $varnishExtraArgs (print "-p " (snakecase $pKey) "=" (toString $pValue)) }}
{{- end }}
{{- end }}
- name: {{ .Chart.Name }}
  {{- include "varnish-enterprise.securityContext" (merge (dict "section" "server") .) | nindent 2 }}
  {{- include "varnish-enterprise.image" (merge (dict "image" .Values.server.image) .) | nindent 2 }}
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
  {{- include "varnish-enterprise.varnishPodProbe" (merge (dict "probeName" "startupProbe") .) | nindent 2 }}
  {{- include "varnish-enterprise.varnishPodProbe" (merge (dict "probeName" "livenessProbe") .) | nindent 2 }}
  {{- include "varnish-enterprise.varnishPodProbe" (merge (dict "probeName" "readinessProbe") .) | nindent 2 }}
  {{- include "varnish-enterprise.resources" (merge (dict "section" "server") .) | nindent 2 }}
  env:
    - name: VARNISH_LISTEN_ADDRESS
    {{- if .Values.server.http.podIP }}
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    {{- else }}
      value: {{ .Values.server.http.address | quote }}
    {{- end }}
    {{- if .Values.server.http.enabled }}
    - name: VARNISH_LISTEN_PORT
      value: {{ .Values.server.http.port | quote }}
    {{- end }}
    - name: VARNISH_VCL_CONF
      {{- if .Values.cluster.enabled }}
      value: {{ list (dir .Values.server.vclConfigPath) $wrappedDefaultVCL | join "/" | quote }}
      {{- else }}
      value: {{ .Values.server.vclConfigPath | quote }}
      {{- end}}
    - name: VARNISH_ADMIN_LISTEN_ADDRESS
      value: {{ .Values.server.admin.address | quote }}
    - name: VARNISH_ADMIN_LISTEN_PORT
      value: {{ .Values.server.admin.port | quote }}
    - name: VARNISH_TTL
      value: {{ .Values.server.ttl | quote }}
    - name: VARNISH_MIN_THREADS
      value: {{ .Values.server.minThreads | quote }}
    - name: VARNISH_MAX_THREADS
      value: {{ .Values.server.maxThreads | quote }}
    - name: VARNISH_THREAD_TIMEOUT
      value: {{ .Values.server.threadTimeout | quote }}
    {{- if or (not (eq .Values.server.secret "")) (not (empty .Values.server.secretFrom)) }}
    - name: VARNISH_SECRET_FILE
      value: /etc/varnish/secret
    {{- end }}
    {{- if and (and (eq (kindOf .Values.server.mse.enabled) "bool") .Values.server.mse.enabled) .Values.server.mse4.enabled }}
    {{- fail "Only one of MSE or MSE4 can be enabled at the same time: 'server.mse.enabled' or 'server.mse4.enabled'" }}
    {{- else if or (and (eq (kindOf .Values.server.mse.enabled) "bool") .Values.server.mse.enabled) (and (eq (kindOf .Values.server.mse.enabled) "string") (eq .Values.server.mse.enabled "-") (not .Values.server.mse4.enabled)) }}
    {{- if and .Values.server.mse.memoryTarget (not (eq .Values.server.mse.memoryTarget "")) }}
    - name: MSE_MEMORY_TARGET
      value: {{ .Values.server.mse.memoryTarget | quote }}
    {{- end }}
    {{- if (not (empty $mseConfig)) }}
    - name: MSE_CONFIG
      value: /etc/varnish/mse.conf
    {{- end }}
    {{- else if .Values.server.mse4.enabled }}
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
    {{- else }}
    {{- fail "Either MSE or MSE4 must be enabled: 'server.mse.enabled' or 'server.mse4.enabled'" }}
    {{- end }}
    {{- if .Values.server.tls.enabled }}
    {{- if and .Values.server.tls.config (not (eq .Values.server.tls.config "")) }}
    - name: VARNISH_TLS_CFG
      value: /etc/varnish/tls.conf
    {{- else }}
    - name: VARNISH_TLS_CFG
      value: "true"
    {{- end }}
    {{- end }}
    {{- if and .Values.server.agent.enabled (not .Values.server.initAgent.enabled) }}
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
    {{- if (not (empty $varnishExtraArgs)) }}
    - name: VARNISH_EXTRA
      value: {{ $varnishExtraArgs | join " " | quote }}
    {{- end }}
    {{- if .Values.cluster.enabled }}
    - name: VARNISH_CLUSTER_TOKEN
      valueFrom:
        secretKeyRef:
          {{- if .Values.cluster.secretName }}
          name: {{ .Values.cluster.secretName }}
          {{- else }}
          name: {{ include "varnish-enterprise.fullname" . }}-cluster-secret
          {{- end }}
          key: token
    {{- end }}
    {{- include "varnish-enterprise.toEnv" (merge (dict "envs" .Values.server.extraEnvs) .) | nindent 4 }}
  volumeMounts:
    - name: {{ .Release.Name }}-varnish-vsm
      mountPath: /var/lib/varnish
    - name: {{ .Release.Name }}-config-shared
      mountPath: /etc/varnish/shared
    {{- if .Values.server.licenseSecret }}
    - name: varnish-license-volume
      mountPath: /etc/varnish/varnish-enterprise.lic
      readOnly: true
      subPath: varnish-enterprise.lic
    {{- end}}
    {{- if not (eq (include "varnish-enterprise.mseConfig" .) "") }}
    - name: {{ .Release.Name }}-config-mse
      mountPath: /etc/varnish/mse.conf
      subPath: mse.conf
    {{- end }}
    {{- if not (eq (include "varnish-enterprise.mse4Config" .) "") }}
    - name: {{ .Release.Name }}-config-mse4
      mountPath: /etc/varnish/mse4.conf
      subPath: mse4.conf
    {{- end }}
    {{- if not (eq (include "varnish-enterprise.tlsConfig" .) "") }}
    - name: {{ .Release.Name }}-config-tls
      mountPath: /etc/varnish/tls.conf
      subPath: tls.conf
    {{- end }}
    {{- if and (not (empty .Values.server.secretFrom)) (hasKey .Values.server.secretFrom "name") (hasKey .Values.server.secretFrom "key") }}
    - name: {{ .Release.Name }}-config-secret
      mountPath: /etc/varnish/secret
      subPath: {{ .Values.server.secretFrom.key | quote }}
    {{- else if not (eq (include "varnish-enterprise.secretConfig" .) "") }}
    - name: {{ .Release.Name }}-config-secret
      mountPath: /etc/varnish/secret
      subPath: secret
    {{- end }}
    {{- if not (eq (include "varnish-enterprise.vclConfig" .) "") }}
    - name: {{ .Release.Name }}-config-vcl
      mountPath: {{ .Values.server.vclConfigPath | quote }}
      subPath: {{ $defaultVcl }}
    {{- end }}
    {{- $vclConfigs := omit .Values.server.vclConfigs $defaultVcl }}
    {{- if not (empty $vclConfigs) }}
    {{- range $k, $v := $vclConfigs }}
    - name: {{ $.Release.Name }}-config-vcl-{{ regexReplaceAll "\\W+" $k "-" }}
      mountPath: {{ list (dir $.Values.server.vclConfigPath) $k | join "/" | quote }}
      subPath: {{ $k | quote }}
    {{- end }}
    {{- end }}
    {{- if .Values.cluster.enabled }}
    - name: {{ $.Release.Name }}-config-vcl-{{ regexReplaceAll "\\W+" $wrappedDefaultVCL "-" }}
      mountPath: {{ list (dir $.Values.server.vclConfigPath) $wrappedDefaultVCL | join "/" | quote }}
      subPath: {{ $wrappedDefaultVCL | quote }}
    {{- end }}
    {{- if not (eq (include "varnish-enterprise.cmdfileConfig" .) "") }}
    - name: {{ .Release.Name }}-config-cmdfile
      mountPath: {{ .Values.server.cmdfileConfigPath | quote }}
      subPath: cmds.cli
    {{- end }}
    {{- if and (eq .Values.server.kind "StatefulSet") (and (or (and (eq (kindOf .Values.server.mse.enabled) "bool") .Values.server.mse.enabled) (and (eq (kindOf .Values.server.mse.enabled) "string") (eq .Values.server.mse.enabled "-") (not .Values.server.mse4.enabled))) .Values.server.mse.persistence.enabled) }}
    - name: {{ .Release.Name }}-mse
      mountPath: {{ .Values.server.mse.persistence.mountPath }}
    {{- end }}
    {{- if and (eq .Values.server.kind "StatefulSet") (and .Values.server.mse4.enabled .Values.server.mse4.persistence.enabled) }}
    - name: {{ .Release.Name }}-mse4
      mountPath: {{ .Values.server.mse4.persistence.mountPath }}
    {{- end }}
    {{- if .Values.server.agent.enabled }}
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
  {{- if or .Values.server.delayedHaltSeconds (eq .Values.server.delayedShutdown.method "sleep") }}
  {{ $haltSeconds := 0 }}
  {{- if .Values.server.delayedHaltSeconds }}
  {{ $haltSeconds = .Values.server.delayedHaltSeconds }}
  {{- else }}
  {{ $haltSeconds = .Values.server.delayedShutdown.sleep.seconds }}
  {{- end }}
  lifecycle:
    preStop:
      exec:
        command: ["/bin/sleep", {{ $haltSeconds | quote }}]
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
{{- define "varnish-enterprise.ncsaContainer" -}}
{{- if .Values.server.varnishncsa.enabled }}
- name: {{ .Chart.Name }}-ncsa
  {{- include "varnish-enterprise.securityContext" (merge (dict "section" "server.varnishncsa") .) | nindent 2 }}
  {{- include "varnish-enterprise.image" (merge (dict "base" .Values.server.image "image" .Values.server.varnishncsa.image) .) | nindent 2 }}
  {{- include "varnish-enterprise.resources" (merge (dict "section" "server.varnishncsa") .) | nindent 2 }}
  command: ["/usr/bin/varnishncsa"]
  {{- if and .Values.server.varnishncsa.extraArgs (not (empty .Values.server.varnishncsa.extraArgs)) }}
  args: {{- toYaml .Values.server.varnishncsa.extraArgs | nindent 4 }}
  {{- end }}
  {{- if and .Values.server.varnishncsa.extraEnvs (not (empty .Values.server.varnishncsa.extraEnvs)) }}
  env:
  {{- range $k, $v := .Values.server.varnishncsa.extraEnvs }}
    - name: {{ $k | quote }}
      value: {{ $v | quote }}
  {{- end }}
  {{- end }}
  {{- if and .Values.server.varnishncsa.startupProbe (not (empty .Values.server.varnishncsa.startupProbe)) }}
  startupProbe:
    exec:
      command:
        - /usr/bin/varnishncsa
        - -d
        - -t 3
    {{- toYaml .Values.server.varnishncsa.startupProbe | nindent 4 }}
  {{- end }}
  {{- if and .Values.server.varnishncsa.readinessProbe (not (empty .Values.server.varnishncsa.readinessProbe)) }}
  readinessProbe:
    exec:
      command:
        - /usr/bin/varnishncsa
        - -d
        - -t 3
    {{- toYaml .Values.server.varnishncsa.readinessProbe | nindent 4 }}
  {{- end }}
  {{- if and .Values.server.varnishncsa.livenessProbe (not (empty .Values.server.varnishncsa.livenessProbe)) }}
  livenessProbe:
    exec:
      command:
        - /usr/bin/varnishncsa
        - -d
        - -t 3
    {{- toYaml .Values.server.varnishncsa.livenessProbe | nindent 4 }}
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
{{- define "varnish-enterprise.otelContainer" -}}
{{- if .Values.server.otel.enabled }}
- name: {{ .Chart.Name }}-otel
  {{- include "varnish-enterprise.securityContext" (merge (dict "section" "server.otel") .) | nindent 2 }}
  {{- include "varnish-enterprise.image" (merge (dict "base" .Values.server.image "image" .Values.server.otel.image) .) | nindent 2 }}
  {{- include "varnish-enterprise.resources" (merge (dict "section" "server.otel") .) | nindent 2 }}
  command: ["/usr/bin/varnish-otel"]
  {{- if .Values.server.otel.env }}
  env:
    {{- include "varnish-enterprise.toEnv" (merge (dict "envs" .Values.server.otel.env) .) | nindent 4 }}
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
{{- define "varnish-enterprise.agentContainer" -}}
{{- if .Values.server.agent.enabled }}
- name: {{ .Chart.Name }}-agent
  {{- include "varnish-enterprise.securityContext" (merge (dict "section" "server.agent") .) | nindent 2 }}
  {{- include "varnish-enterprise.image" (merge (dict "image" .Values.server.agent.image) .) | nindent 2 }}
  env:
    - name: VARNISH_CONTROLLER_VARNISH_HOST
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: VARNISH_CONTROLLER_VARNISH_ADMIN_HOST
      value: {{ .Values.server.admin.address | quote }}
    - name: VARNISH_CONTROLLER_VARNISH_ADMIN_PORT
      value: {{ .Values.server.admin.port | quote }}
    {{- if .Values.server.http.enabled }}
    - name: VARNISH_CONTROLLER_VARNISH_PORT
      value: {{ .Values.server.http.port | quote }}
    {{- else }}
    {{- fail "HTTP support must be enabled to enable Varnish Controller Agent: 'server.http.enabled'" }}
    {{- end }}
    {{- if not (eq .Values.server.secret "") }}
    - name: VARNISH_CONTROLLER_VARNISH_SECRET
      value: /etc/varnish/secret
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
    {{- include "varnish-enterprise.natsServer" . | indent 4 }}
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
    {{- include "varnish-enterprise.toEnv" (merge (dict "envs" .Values.server.agent.extraEnvs) .) | nindent 4 }}
  {{- include "varnish-enterprise.resources" (merge (dict "section" "server.agent") .) | nindent 2 }}
  command: ["/usr/bin/varnish-controller-agent"]
  {{- if and .Values.server.agent.extraArgs (not (empty .Values.server.agent.extraArgs)) }}
  args: {{- toYaml .Values.server.agent.extraArgs | nindent 4 }}
  {{- end }}
  volumeMounts:
    - name: {{ .Release.Name }}-varnish-vsm
      mountPath: /var/lib/varnish
    - name: {{ .Release.Name }}-config-shared
      mountPath: /etc/varnish/shared
    {{- if and (not (empty .Values.server.secretFrom)) (hasKey .Values.server.secretFrom "name") (hasKey .Values.server.secretFrom "key") }}
    - name: {{ .Release.Name }}-config-secret
      mountPath: /etc/varnish/secret
      subPath: {{ .Values.server.secretFrom.key | quote }}
    {{- else if not (eq (include "varnish-enterprise.secretConfig" .) "") }}
    - name: {{ .Release.Name }}-config-secret
      mountPath: /etc/varnish/secret
      subPath: secret
    {{- else }}
    {{ fail "Secret must be set to enable Varnish Controller agent: 'server.secret' or 'secret.secretFrom'" }}
    {{- end }}
    {{- if not (eq (include "varnish-enterprise.vclConfig" .) "") }}
    - name: {{ .Release.Name }}-config-vcl
      mountPath: {{ .Values.server.vclConfigPath | quote }}
      subPath: {{ osBase .Values.server.vclConfigPath }}
    {{- end }}
    {{- $vclConfigs := omit .Values.server.vclConfigs (osBase .Values.server.vclConfigPath) }}
    {{- if not (empty $vclConfigs) }}
    {{- range $k, $v := $vclConfigs }}
    - name: {{ $.Release.Name }}-config-vcl-{{ regexReplaceAll "\\W+" $k "-" }}
      mountPath: {{ list (dir $.Values.server.vclConfigPath) $k | join "/" | quote }}
      subPath: {{ $k | quote }}
    {{- end }}
    {{- end }}
    {{- if not (eq (include "varnish-enterprise.cmdfileConfig" .) "") }}
    - name: {{ .Release.Name }}-config-cmdfile
      mountPath: {{ .Values.server.cmdfileConfigPath | quote }}
      subPath: cmds.cli
    {{- end }}
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
{{- define "varnish-enterprise.vcliContainer" -}}
{{- if and .Values.server.agent.enabled (eq .Values.server.agent.autoRemove.method "vcli") }}
- name: {{ .Chart.Name }}-vcli
  {{- include "varnish-enterprise.securityContext" (merge (dict "section" "server.agent.autoRemove.vcli") .) | nindent 2 }}
  {{- include "varnish-enterprise.image" (merge (dict "image" .Values.server.agent.autoRemove.vcli.image) .) | nindent 2 }}
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
    {{- if .Values.server.agent.enabled }}
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
    {{- include "varnish-enterprise.toEnv" (merge (dict "envs" .Values.server.agent.autoRemove.vcli.extraEnvs) .) | nindent 4 }}
    {{- end }}
  {{- include "varnish-enterprise.resources" (merge (dict "section" "server.agent.autoRemove.vcli") .) | nindent 2 }}
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
{{- define "varnish-enterprise.extraContainers" -}}
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
{{- define "varnish-enterprise.initContainers" -}}
{{- if or (and .Values.server.agent.enabled .Values.server.initAgent.enabled) .Values.server.extraInitContainers }}
initContainers:
{{- if and .Values.server.agent.enabled .Values.server.initAgent.enabled }}
  - name: init-agent
    image: {{ .Values.global.initContainer.image | default "busybox"}}:{{ .Values.global.initContainer.tag | default "1.36"}}
    command:
      - /bin/sh
      - -c
      - |
        set -e
        ln -sf \
            /var/lib/varnish-controller/varnish-controller-agent/"${VARNISH_CONTROLLER_AGENT_NAME}" \
            /etc/varnish/shared/agent
    {{- include "varnish-enterprise.securityContext" (merge (dict "section" "server.initAgent") .) | nindent 4 }}
    {{- include "varnish-enterprise.resources" (merge (dict "section" "server.initAgent") .) | nindent 4 }}
    env:
    {{- if and (eq (toString .Values.server.replicas) "1") .Values.server.agent.useReleaseName }}
      - name: VARNISH_CONTROLLER_AGENT_NAME
        value: "{{ .Release.Name }}"
    {{- else }}
      - name: VARNISH_CONTROLLER_AGENT_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
    {{- end }}
    volumeMounts:
      - name: {{ .Release.Name }}-config-shared
        mountPath: /etc/varnish/shared
      {{- if .Values.server.initAgent.extraVolumeMounts }}
      {{- $tp := kindOf .Values.server.initAgent.extraVolumeMounts }}
      {{- if eq $tp "string" }}
      {{- tpl .Values.server.initAgent.extraVolumeMounts . | trim | nindent 6 }}
      {{- else }}
      {{- toYaml .Values.server.initAgent.extraVolumeMounts | nindent 6 }}
      {{- end }}
      {{- end }}
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
{{- end }}
