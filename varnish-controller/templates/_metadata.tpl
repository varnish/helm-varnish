{{/* vim: set filetype=mustache: */}}

{{/*
Common labels
*/}}
{{- define "varnish-controller.labels" }}
helm.sh/chart: {{ include "varnish-controller.chart" . }}
{{ include "varnish-controller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Sets up the common server extra annotations
*/}}
{{- define "varnish-controller.serverAnnotations" }}
{{- $section := default "server" .section }}
{{- include "varnish-controller.toYamlField"
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
{{- define "varnish-controller.serverLabels" -}}
{{- $section := default "server" .section }}
{{- $nameSuffix := .nameSuffix }}
{{- if not (eq $nameSuffix "") }}
{{- $nameSuffix = .section }}
{{- end }}
{{- $defaultLabel := (fromYaml (include "varnish-controller.labels" (merge (dict "nameSuffix" $nameSuffix) .))) }}
{{- $extraLabels := default dict .extraLabels }}
{{- include "varnish-controller.toYamlField"
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
{{- define "varnish-controller.serviceAnnotations" -}}
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
{{- define "varnish-controller.selectorLabels" }}
{{- if .nameSuffix }}
app.kubernetes.io/name: {{ include "varnish-controller.name" . }}-{{ .nameSuffix }}
{{- else }}
app.kubernetes.io/name: {{ include "varnish-controller.name" . }}
{{- end }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "varnish-controller.serviceAccountName" }}
{{- if .Values.serviceAccount.create }}
{{- default (include "varnish-controller.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Sets up the common service extra labels
*/}}
{{- define "varnish-controller.serviceLabels" }}
{{- $section := default "server" .section }}
{{- $service := (get .Values $section).service }}
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
Sets up the common ingress extra annotations
*/}}
{{- define "varnish-controller.ingressAnnotations" }}
{{- $section := default "server" .section }}
{{- $ingress := (get .Values $section).ingress }}
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
{{- define "varnish-controller.ingressLabels" }}
{{- $section := default "server" .section }}
{{- $ingress := (get .Values $section).ingress }}
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
Declares the Varnish Controller deployment strategy
*/}}
{{- define "varnish-controller.strategy" -}}
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
{{- define "varnish-controller.securityContext" }}
{{- include "varnish-controller.toYamlField"
  (merge
    (dict
      "section" .section
      "fieldName" "securityContext")
    .) }}
{{- end }}

{{/*
Declares the container resource.
*/}}
{{- define "varnish-controller.resources" }}
{{- include "varnish-controller.toYamlField"
  (merge
    (dict
      "section" .section
      "fieldName" "resources")
    .) }}
{{- end }}

{{/*
Sets up Pod annotations
*/}}
{{- define "varnish-controller.podAnnotations" }}
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
{{- include "varnish-controller.toYamlField"
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
{{- define "varnish-controller.podLabels" }}
{{- $section := default "server" .section }}
{{- $nameSuffix := .nameSuffix }}
{{- if not (eq $nameSuffix "") }}
{{- $nameSuffix = .section }}
{{- end }}
{{- $defaultLabel := (fromYaml (include "varnish-controller.selectorLabels" (merge (dict "nameSuffix" $nameSuffix) .))) }}
{{- $extraLabels := default dict .extraLabels }}
{{- include "varnish-controller.toYamlField"
  (merge
    (dict
      "section" $section
      "fieldName" "labels"
      "fieldKey" "podLabels"
      "extraFieldValues" (merge $extraLabels $defaultLabel))
    .) }}
{{- end }}
