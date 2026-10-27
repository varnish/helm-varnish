{{/* vim: set filetype=mustache: */}}

{{/*
Common labels
*/}}
{{- define "varnish-common.labels" -}}
helm.sh/chart: {{ include "varnish-common.chart" . }}
{{ include "varnish-common.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "varnish-common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "varnish-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "varnish-common.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "varnish-common.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Sets up the common server extra annotations
*/}}
{{- define "varnish-common.serverAnnotations" -}}
{{- $section := default "server" .section }}
{{- include "varnish-common.toYamlField"
  (merge
    (dict
      "section" $section
      "fieldName" "annotations"
      "extraFieldValues" .extraAnnotations)
    .) }}
{{- end }}

{{/*
Sets up the common server extra labels
*/}}
{{- define "varnish-common.serverLabels" -}}
{{- $section := default "server" .section }}
{{- $nameSuffix := .nameSuffix }}
{{- if not (eq $nameSuffix "") }}
{{- $nameSuffix = .section }}
{{- end }}
{{- $defaultLabel := (fromYaml (include "varnish-common.labels" (merge (dict "nameSuffix" $nameSuffix) .))) }}
{{- $extraLabels := default dict .extraLabels }}
{{- include "varnish-common.toYamlField"
  (merge
    (dict
      "section" $section
      "fieldName" "labels"
      "extraFieldValues" (merge $extraLabels $defaultLabel))
    .) }}
{{- end }}

{{/*
Sets up the common service extra annotations
*/}}
{{- define "varnish-common.serviceAnnotations" -}}
{{- if .Values.server.service.annotations }}
annotations:
  {{- $tp := kindOf .Values.server.service.annotations }}
  {{- if eq $tp "string" }}
    {{- tpl .Values.server.service.annotations . | trim | nindent 2 }}
  {{- else }}
    {{- toYaml .Values.server.service.annotations | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Sets up the common service extra labels
*/}}
{{- define "varnish-common.serviceLabels" -}}
{{- $section := default "server" .section -}}
{{- $service := (get .Values $section).service -}}
{{- if $service.labels -}}
{{- $tp := kindOf $service.labels -}}
{{- if eq $tp "string" -}}
{{- tpl $service.labels . | trim | nindent 0 }}
{{- else -}}
{{- toYaml $service.labels | trim | nindent 0 }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Sets up the common ingress extra annotations
*/}}
{{- define "varnish-common.ingressAnnotations" -}}
{{- $section := default "server" .section -}}
{{- $ingress := (get .Values $section).ingress -}}
{{- if $ingress.annotations }}
annotations:
  {{- $tp := kindOf $ingress.annotations }}
  {{- if eq $tp "string" }}
    {{- tpl $ingress.annotations . | trim | nindent 2 }}
  {{- else }}
    {{- toYaml $ingress.annotations | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Sets up the common ingress extra labels
*/}}
{{- define "varnish-common.ingressLabels" -}}
{{- $section := default "server" .section -}}
{{- $ingress := (get .Values $section).ingress -}}
{{- if $ingress.labels }}
{{- $tp := kindOf $ingress.labels }}
{{- if eq $tp "string" }}
  {{- tpl $ingress.labels . | trim | nindent 0 }}
{{- else }}
  {{- toYaml $ingress.labels | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Sets up the common service account annotations
*/}}
{{- define "varnish-common.serviceAccountAnnotations" -}}
{{- if .Values.serviceAccount.annotations }}
annotations:
  {{- $tp := kindOf .Values.serviceAccount.annotations }}
  {{- if eq $tp "string" }}
    {{- tpl .Values.serviceAccount.annotations . | trim | nindent 2 }}
  {{- else }}
    {{- toYaml .Values.serviceAccount.annotations | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Sets up the common service account extra labels
*/}}
{{- define "varnish-common.serviceAccountLabels" -}}
{{- if .Values.serviceAccount.labels }}
{{- $tp := kindOf .Values.serviceAccount.labels }}
{{- if eq $tp "string" }}
  {{- tpl .Values.serviceAccount.labels . | trim | nindent 0 }}
{{- else }}
  {{- toYaml .Values.serviceAccount.labels | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}


{{/*
Declares the Pod's serviceAccount.
*/}}
{{- define "varnish-common.podServiceAccount" }}
serviceAccountName: {{ include "varnish-common.serviceAccountName" . }}
{{- end }}
{{/*
Declares the Pod's securityContext.
*/}}
{{- define "varnish-common.podSecurityContext" }}
{{- if not (empty .Values.global.podSecurityContext) }}
securityContext:
  {{- toYaml .Values.global.podSecurityContext | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Sets up Pod labels
*/}}
{{- define "varnish-common.podLabels" }}
{{- $section := default "server" .section }}
{{- $nameSuffix := .nameSuffix }}
{{- if not (eq $nameSuffix "") }}
{{- $nameSuffix = .section }}
{{- end }}
{{- $defaultLabel := (fromYaml (include "varnish-common.selectorLabels" (merge (dict "nameSuffix" $nameSuffix) .))) }}
{{- $extraLabels := default dict .extraLabels }}
{{- include "varnish-common.toYamlField"
  (merge
    (dict
      "section" $section
      "fieldName" "labels"
      "fieldKey" "podLabels"
      "extraFieldValues" (merge $extraLabels $defaultLabel))
    .) }}
{{- end }}

{{/*
Declares the Varnish deployment strategy
*/}}
{{- define "varnish-common.strategy" -}}
{{- if .Values.server.strategy }}
{{- $tp := kindOf .Values.server.strategy }}
strategy:
{{- if eq $tp "string" }}
  {{- tpl .Values.server.strategy . | trim | nindent 2 }}
{{- else }}
  {{- toYaml .Values.server.strategy | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Declares the Varnish DaemonSet and StatefulSet updateStrategy
*/}}
{{- define "varnish-common.updateStrategy" -}}
{{- if .Values.server.updateStrategy }}
{{- $tp := kindOf .Values.server.updateStrategy }}
updateStrategy:
{{- if eq $tp "string" }}
  {{- tpl .Values.server.updateStrategy . | trim | nindent 2 }}
{{- else }}
  {{- toYaml .Values.server.updateStrategy | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Sets up nodeSelector depending on whether a YAML map or a string is given.
*/}}
{{- define "varnish-common.nodeSelector" -}}
{{- if .Values.server.nodeSelector }}
nodeSelector:
  {{- $tp := kindOf .Values.server.nodeSelector }}
  {{- if eq $tp "string" }}
    {{- tpl .Values.server.nodeSelector . | trim | nindent 2 }}
  {{- else }}
    {{- toYaml .Values.server.nodeSelector | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Declares the container securityContext.
*/}}
{{- define "varnish-common.securityContext" }}
{{- include "varnish-common.toYamlField"
  (merge
    (dict
      "section" .section
      "subsection" .subsection
      "fieldName" "securityContext")
    .) }}
{{- end }}

{{/*
Declares the container resource.
*/}}
{{- define "varnish-common.resources" }}
{{- include "varnish-common.toYamlField"
  (merge
    (dict
      "section" .section
      "subsection" .subsection
      "fieldName" "resources")
    .) }}
{{- end }}
