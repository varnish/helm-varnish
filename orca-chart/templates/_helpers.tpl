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
Returns a modified version of the Varnish Supervisor configuration.
We use this to secure the license loading it from a secret before mounting it into the
It also supports storing TLS certificates in secrets before mounting them into the pod.
*/}}
{{- define "orca.config" -}}
  {{- $cfg := deepCopy (default dict .Values.orca) -}}
  {{- if not (empty $cfg.license.secret) -}}
  {{- $_ := set $cfg.license "file" "/etc/varnish-supervisor/license.lic" -}}
  {{- end -}}
  {{- range $httpId, $https := $cfg.varnish.https -}}
    {{- range $certId, $cert := $https.certificates -}}
      {{- if not (empty $cert.secret) -}}
      {{- $_ := set $cert "cert" (printf "/etc/varnish-supervisor/cert-%d-%d.crt" $httpId $certId) -}}
      {{- $_ := set $cert "private_key" (printf "/etc/varnish-supervisor/cert-%d-%d.key" $httpId $certId) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- toYaml $cfg -}}
{{- end -}}

{{/*
Validates the chart values. Called from every workload template so that an
invalid configuration fails the render regardless of which workload is gated
on the chosen kind.
*/}}
{{- define "orca.validate" -}}
{{- if not (eq .Values.kind "Deployment") -}}
{{- fail (printf "kind must be 'Deployment', got %q" .Values.kind) -}}
{{- end -}}
{{- end -}}

{{/*
Sets extra envs from either an array, an object, or a string.
*/}}
{{- define "orca.toEnv" }}
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