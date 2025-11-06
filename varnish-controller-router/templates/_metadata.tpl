{{/* vim: set filetype=mustache: */}}

{{/*
Common labels
*/}}
{{- define "varnish-controller-router.labels" -}}
helm.sh/chart: {{ include "varnish-controller-router.chart" . }}
{{ include "varnish-controller-router.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Sets up the common server extra annotations
*/}}
{{- define "varnish-controller-router.serverAnnotations" }}
{{- $section := default "server" .section }}
{{- include "varnish-controller-router.toYamlField"
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
{{- define "varnish-controller-router.serverLabels" }}
{{- $section := default "server" .section }}
{{- $nameSuffix := .nameSuffix }}
{{- if not (eq $nameSuffix "") }}
{{- $nameSuffix = .section }}
{{- end }}
{{- $defaultLabel := (fromYaml (include "varnish-controller-router.labels" (merge (dict "nameSuffix" $nameSuffix) .))) }}
{{- $extraLabels := default dict .extraLabels }}
{{- include "varnish-controller-router.toYamlField"
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
{{- define "varnish-controller-router.serviceAnnotations" -}}
{{- $section := default "server" .section }}
{{- $service := .Values }}
{{- range $s := (splitList "." $section) }}
{{- $service = (get $service $s) }}
{{- end }}
{{- if $service.annotations }}
annotations:
  {{- $tp := kindOf $service.annotations }}
  {{- if eq $tp "string" }}
    {{- tpl $service.annotations . | trim | nindent 2 }}
  {{- else }}
    {{- toYaml $service.annotations | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "varnish-controller-router.selectorLabels" }}
{{- if .nameSuffix }}
app.kubernetes.io/name: {{ include "varnish-controller-router.name" . }}-{{ .nameSuffix }}
{{- else }}
app.kubernetes.io/name: {{ include "varnish-controller-router.name" . }}
{{- end }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "varnish-controller-router.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "varnish-controller-router.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Sets up the common service extra labels
*/}}
{{- define "varnish-controller-router.serviceLabels" }}
{{- $section := default "server" .section }}
{{- $service := .Values }}
{{- range $s := (splitList "." $section) }}
{{- $service = (get $service $s) }}
{{- end }}
{{- if $service.labels }}
{{- $tp := kindOf $service.labels }}
{{- if eq $tp "string" }}
{{- tpl $service.labels . | trim | nindent 0 }}
{{- else }}
{{- toYaml $service.labels | trim | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Sets up the common service account annotations
*/}}
{{- define "varnish-controller-router.serviceAccountAnnotations" -}}
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
{{- define "varnish-controller-router.serviceAccountLabels" -}}
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
Declares the Varnish Controller Router deployment strategy
*/}}
{{- define "varnish-controller-router.strategy" -}}
{{- $section := default "server" .section }}
{{- $strategy := (get .Values $section).strategy }}
{{- if $strategy }}
{{- $tp := kindOf $strategy }}
strategy:
{{- if eq $tp "string" }}
  {{- tpl $strategy . | trim | nindent 2 }}
{{- else }}
  {{- toYaml $strategy | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Declares the container securityContext.
*/}}
{{- define "varnish-controller-router.securityContext" }}
{{- include "varnish-controller-router.toYamlField"
  (merge
    (dict
      "section" .section
      "fieldName" "securityContext")
    .) }}
{{- end }}

{{/*
Declares the container resource.
*/}}
{{- define "varnish-controller-router.resources" }}
{{- include "varnish-controller-router.toYamlField"
  (merge
    (dict
      "section" .section
      "fieldName" "resources")
    .) }}
{{- end }}

{{/*
Sets up Pod annotations
*/}}
{{- define "varnish-controller-router.podAnnotations" }}
{{- $section := default "server" .section }}
{{- $extraAnnotations := default dict .extraAnnotations }}
{{- $extraManifests := .Values.extraManifests }}
{{- $checksum := dict }}
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
{{- include "varnish-controller-router.toYamlField"
  (merge
    (dict
      "section" $section
      "fieldName" "annotations"
      "fieldKey" "podAnnotations"
      "extraFieldValues" (merge $extraAnnotations $checksum))
    .) }}
{{- end }}

{{/*
Sets up Pod labels
*/}}
{{- define "varnish-controller-router.podLabels" }}
{{- $section := default "server" .section }}
{{- $nameSuffix := .nameSuffix }}
{{- if not (eq $nameSuffix "") }}
{{- $nameSuffix = .section }}
{{- end }}
{{- $defaultLabel := (fromYaml (include "varnish-controller-router.selectorLabels" (merge (dict "nameSuffix" $nameSuffix) .))) }}
{{- $extraLabels := default dict .extraLabels }}
{{- include "varnish-controller-router.toYamlField"
  (merge
    (dict
      "section" $section
      "fieldName" "labels"
      "fieldKey" "podLabels"
      "extraFieldValues" (merge $extraLabels $defaultLabel))
    .) }}
{{- end }}
