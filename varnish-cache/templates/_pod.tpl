{{/*
Sets up Pod annotations
*/}}
{{- define "varnish-cache.podAnnotations" }}
{{- $section := default "server" .section }}
{{- $defaultVcl := osBase .Values.server.vclConfigPath }}
{{- $vclConfig := include "varnish-cache.vclConfig" . }}
{{- $vclConfigs := omit .Values.server.vclConfigs $defaultVcl }}
{{- $cmdfileConfig := include "varnish-cache.cmdfileConfig" . }}
{{- $secretConfig := include "varnish-cache.secretConfig" . }}
{{- $extraManifests := .Values.extraManifests }}
{{- $checksum := dict }}
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
{{- include "varnish-cache.toYamlField"
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
{{- define "varnish-cache.affinity" -}}
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
{{- define "varnish-cache.tolerations" -}}
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
{{- define "varnish-cache.terminationGracePeriodSeconds" -}}
{{- if not (empty .Values.server.terminationGracePeriodSeconds) }}
terminationGracePeriodSeconds: {{ .Values.server.terminationGracePeriodSeconds }}
{{- else if not (empty .Values.server.delayedHaltSeconds) }}
terminationGracePeriodSeconds: {{ add .Values.server.delayedHaltSeconds 60 }}
{{- end }}
{{- end }}

{{/*
Declares the Pod's imagePullSecrets
*/}}
{{- define "varnish-cache.podImagePullSecrets" }}
{{- with .Values.global.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Declares the Pod's volume mounts.
*/}}
{{- define "varnish-cache.podVolumes" }}
{{- $defaultVcl := osBase .Values.server.vclConfigPath }}
volumes:
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
{{- else if not (eq (include "varnish-cache.secretConfig" .) "") }}
- name: {{ .Release.Name }}-config-secret
  secret:
    secretName: {{ include "varnish-cache.fullname" . }}-secret
{{- end }}
{{- if not (eq (include "varnish-cache.vclConfig" .) "") }}
- name: {{ .Release.Name }}-config-vcl
  configMap:
    name: {{ include "varnish-cache.fullname" . }}-vcl
{{- end }}
{{- $vclConfigs := omit .Values.server.vclConfigs $defaultVcl }}
{{- if not (empty $vclConfigs) }}
{{- range $k, $v := $vclConfigs }}
- name: {{ $.Release.Name }}-config-vcl-{{ regexReplaceAll "\\W+" $k "-" }}
  configMap:
    name: {{ include "varnish-cache.fullname" $ }}-vcl-{{ regexReplaceAll "\\W+" $k "-" }}
{{- end }}
{{- end }}
{{- if not (eq (include "varnish-cache.cmdfileConfig" .) "") }}
- name: {{ .Release.Name }}-config-cmdfile
  configMap:
    name: {{ include "varnish-cache.fullname" . }}-cmdfile
{{- end }}
- name: {{ .Release.Name }}-varnish-vsm
  emptyDir:
    medium: "Memory"
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
Declares the probe for Varnish Cache pod
*/}}
{{- define "varnish-cache.varnishPodProbe" }}
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
Declares the Varnish Cache container
*/}}
{{- define "varnish-cache.serverContainer" -}}
{{- $cmdfileConfig := include "varnish-cache.cmdfileConfig" . }}
{{- $defaultVcl := osBase .Values.server.vclConfigPath }}
{{- $tp := kindOf .Values.server.extraArgs }}
{{- $varnishExtraArgs := list }}
{{- if eq $tp "string" }}
{{- $varnishExtraArgs = append $varnishExtraArgs .Values.server.extraArgs }}
{{- else }}
{{- $varnishExtraArgs = concat $varnishExtraArgs .Values.server.extraArgs }}
{{- end }}
{{- if not (eq $cmdfileConfig "") }}
{{- $varnishExtraArgs = concat $varnishExtraArgs (list "-I" .Values.server.cmdfileConfigPath) }}
{{- end }}
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
{{- $varnishExtraArgs = concat $varnishExtraArgs (list "-a" $extraArg) }}
{{- end }}
- name: {{ .Chart.Name }}
  {{- include "varnish-cache.securityContext" (merge (dict "section" "server") .) | nindent 2 }}
  {{- include "varnish-cache.image" (merge (dict "image" .Values.server.image) .) | nindent 2 }}
  ports:
    {{- if .Values.server.http.enabled }}
    - name: http
      containerPort: {{ .Values.server.http.port }}
      protocol: TCP
      {{- if and .Values.server.http.hostPort (not (empty .Values.server.http.hostPort)) }}
      hostPort: {{ .Values.server.http.hostPort }}
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
  {{- include "varnish-cache.varnishPodProbe" (merge (dict "probeName" "startupProbe") .) | nindent 2 }}
  {{- include "varnish-cache.varnishPodProbe" (merge (dict "probeName" "livenessProbe") .) | nindent 2 }}
  {{- include "varnish-cache.varnishPodProbe" (merge (dict "probeName" "readinessProbe") .) | nindent 2 }}
  {{- include "varnish-cache.resources" (merge (dict "section" "server") .) | nindent 2 }}
  command:
    {{- if .Values.server.command }}
    {{- toYaml .Values.server.command | nindent 4 }}
    {{- else }}
    - /usr/sbin/varnishd
    {{- end }}
  args:
    {{- if hasKey .Values.server "args" }}
    {{- toYaml .Values.server.args | nindent 4 }}
    {{- else }}
    - -F
    {{- if .Values.server.http.enabled }}
    - -a
    - http=$(VARNISH_HTTP_ADDRESS):{{ .Values.server.http.port }},HTTP
    {{- end }}
    - -f
    - {{ .Values.server.vclConfigPath }}
    {{- if .Values.server.admin.port }}
    - -T
    - {{ .Values.server.admin.address }}:{{ .Values.server.admin.port }}
    {{- end }}
    {{- if .Values.server.ttl }}
    - -t
    - {{ .Values.server.ttl | quote }}
    {{- end }}
    {{- if .Values.server.minThreads }}
    - -p
    - thread_pool_min={{ .Values.server.minThreads }}
    {{- end }}
    {{- if .Values.server.maxThreads }}
    - -p
    - thread_pool_max={{ .Values.server.maxThreads }}
    {{- end }}
    {{- if .Values.server.threadTimeout }}
    - -p
    - thread_pool_timeout={{ .Values.server.threadTimeout }}
    {{- end }}
    {{- if or (not (eq .Values.server.secret "")) (not (empty .Values.server.secretFrom)) }}
    - -S
    - /etc/varnish/secret
    {{- end }}
    {{- if (not (empty $varnishExtraArgs)) }}
    {{- range $v := $varnishExtraArgs }}
    - {{ $v | quote }}
    {{- end }}
    {{- end }}
    {{- end }}
  env:
    - name: VARNISH_HTTP_ADDRESS
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    {{- include "varnish-cache.toEnv" (merge (dict "envs" .Values.server.extraEnvs) .) | nindent 4 }}
  volumeMounts:
    {{- if and (not (empty .Values.server.secretFrom)) (hasKey .Values.server.secretFrom "name") (hasKey .Values.server.secretFrom "key") }}
    - name: {{ .Release.Name }}-config-secret
      mountPath: /etc/varnish/secret
      subPath: {{ .Values.server.secretFrom.key | quote }}
    {{- else if not (eq (include "varnish-cache.secretConfig" .) "") }}
    - name: {{ .Release.Name }}-config-secret
      mountPath: /etc/varnish/secret
      subPath: secret
    {{- end }}
    {{- if not (eq (include "varnish-cache.vclConfig" .) "") }}
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
    {{- if not (eq (include "varnish-cache.cmdfileConfig" .) "") }}
    - name: {{ .Release.Name }}-config-cmdfile
      mountPath: {{ .Values.server.cmdfileConfigPath | quote }}
      subPath: cmds.cli
    {{- end }}
    - name: {{ .Release.Name }}-varnish-vsm
      mountPath: /var/lib/varnish
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
{{- define "varnish-cache.ncsaContainer" -}}
{{- if .Values.server.varnishncsa.enabled }}
- name: {{ .Chart.Name }}-ncsa
  {{- include "varnish-cache.securityContext" (merge (dict "section" "server" "subsection" "varnishncsa") .) | nindent 2 }}
  {{- include "varnish-cache.image" (merge (dict "base" .Values.server.image "image" .Values.server.varnishncsa.image) .) | nindent 2 }}
  {{- include "varnish-cache.resources" (merge (dict "section" "server" "subsection" "varnishncsa") .) | nindent 2 }}
  command: ["varnishncsa"]
  {{- if and .Values.server.varnishncsa.extraArgs (not (empty .Values.server.varnishncsa.extraArgs)) }}
  args: {{- toYaml .Values.server.varnishncsa.extraArgs | nindent 4 }}
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
Declares the Varnish extra container
*/}}
{{- define "varnish-cache.extraContainers" -}}
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
{{- define "varnish-cache.initContainers" -}}
{{- if .Values.server.extraInitContainers }}
initContainers:
  {{- $tp := kindOf .Values.server.extraInitContainers }}
  {{- if eq $tp "string" }}
    {{- tpl .Values.server.extraInitContainers . | trim | nindent 2 }}
  {{- else }}
    {{- toYaml .Values.server.extraInitContainers | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}
