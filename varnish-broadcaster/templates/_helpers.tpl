{{/*
Expand the name of the chart.
*/}}
{{- define "helm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "helm.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "helm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "helm.labels" -}}
helm.sh/chart: {{ include "helm.chart" . }}
{{ include "helm.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "helm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "helm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "helm.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "helm.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Arguments shared by the varnish-discovery init and sidecar containers.
*/}}
{{- define "broadcaster.discoveryArgs" -}}
- k8s
{{- /* the default (https://kubernetes/) only resolves in the default namespace */}}
- -server
- https://kubernetes.default.svc/
- -nodefile
- /etc/broadcaster/nodes.conf
- -port
- {{ .Values.discovery.port | quote }}
- -proto
- {{ .Values.discovery.proto | quote }}
{{- range .Values.discovery.groups }}
- -group
- {{ . | quote }}
{{- end }}
{{- with .Values.discovery.extraArgs }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Default probe: ping the management interface on localhost. It's served over
HTTPS when TLS is enabled, and the image has no curl/wget, so use either bash
or openssl.
*/}}
{{- define "broadcaster.defaultProbe" -}}
exec:
  command:
    - bash
    - -c
    {{- if .Values.broadcaster.tls.enabled }}
    - 'printf "GET /api/ping HTTP/1.0\r\n\r\n" | openssl s_client -quiet -connect 127.0.0.1:8089 2>/dev/null | head -n1 | grep -q " 200 "'
    {{- else }}
    - 'exec 3<>/dev/tcp/127.0.0.1/8089 && printf "GET /api/ping HTTP/1.0\r\n\r\n" >&3 && head -n1 <&3 | grep -q " 200 "'
    {{- end }}
{{- end }}

{{/*
Validates the chart values.
*/}}
{{- define "broadcaster.validate" -}}
{{- if not .Values.discovery.groups }}
{{- fail "discovery.groups must list at least one Service to broadcast to" }}
{{- end }}
{{- if and .Values.broadcaster.tls.enabled (not .Values.broadcaster.tls.secret) }}
{{- fail "broadcaster.tls.secret is required when broadcaster.tls.enabled is true" }}
{{- end }}
{{- end }}

{{- define "broadcaster.toEnv" }}
{{- $tp := kindOf .envs }}
{{- if eq $tp "string" }}
{{- tpl .envs . | trim | nindent 0 }}
{{- else if eq $tp "map" }}
{{- range $k, $v := .envs -}}
- name: {{ $k | quote }}
  value: {{ $v | quote }}
{{- end }}
{{- else if eq $tp "slice" }}
{{- .envs | toYaml }}
{{- end }}
{{- end }}
