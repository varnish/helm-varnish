{{/* vim: set filetype=mustache: */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "varnish.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "varnish.fullname" -}}
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
{{- define "varnish.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Sets up the Varnish Cache image and its overrides (if any)
*/}}
{{- define "varnish.image" }}
{{- $base := .base | default dict }}
{{- $image := .image | default dict }}
image: "{{- if eq $image.repository "-" -}}{{ $base.repository }}{{ else }}{{ $image.repository }}{{ end }}:{{- if eq $image.tag "-" }}{{ default .Chart.AppVersion $base.tag }}{{ else }}{{ default $.Chart.AppVersion $image.tag }}{{ end }}"
imagePullPolicy: {{ if eq $image.pullPolicy "-" }}{{ $base.pullPolicy }}{{ else }}{{ $image.pullPolicy }}{{ end }}
{{- end }}

{{/*
Sets extra envs from either an array, an object, or a string.
*/}}
{{- define "varnish.toEnv" }}
{{- $tp := kindOf .envs }}
{{- if eq $tp "string" }}
{{- tpl .envs . | trim | nindent 0 }}
{{- else if eq $tp "map" }}
{{- range $k, $v := .envs }}
- name: {{ $k | quote }}
  value: {{ $v | quote }}
{{- end }}
{{- else if eq $tp "slice" }}
{{- .envs | toYaml }}
{{- end }}
{{- end }}

{{/*
Declares the YAML field.
*/}}
{{- define "varnish.toYamlField" }}
{{- $section := default "server" .section }}
{{- $fieldName := .fieldName }}
{{- $fieldKey := default $fieldName .fieldKey }}
{{- $fieldValue := (get .Values $section) }}
{{- if (not (empty .subsection)) }}
{{- $fieldValue = (get $fieldValue .subsection) }}
{{- end }}
{{- $fieldValue = (get $fieldValue $fieldKey) }}
{{- if (empty $fieldValue) }}
{{- $fieldValue = (dict) }}
{{- else if eq (kindOf $fieldValue) "string" }}
{{- $fieldValue = (fromYaml (tpl $fieldValue .)) }}
{{- end }}
{{- $globalFieldValue := (get .Values.global $fieldKey) }}
{{- if eq (kindOf $globalFieldValue) "string" }}
{{- $globalFieldValue = (fromYaml (tpl $globalFieldValue .)) }}
{{- end }}
{{- if not (empty $globalFieldValue) }}
{{- $fieldValue = (merge $fieldValue $globalFieldValue) }}
{{- end }}
{{- $extraFieldValues := .extraFieldValues }}
{{- if eq (kindOf $extraFieldValues) "string" }}
{{- $extraFieldValues = (fromYaml (tpl $extraFieldValues .)) }}
{{- end }}
{{- if not (empty $extraFieldValues) }}
{{- $fieldValue = (merge $fieldValue $extraFieldValues) }}
{{- end }}
{{- if not (empty $fieldValue) }}
{{- (dict $fieldName $fieldValue) | toYaml }}
{{- end }}
{{- end }}
