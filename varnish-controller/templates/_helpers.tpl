{{/*
Expand the name of the chart.
*/}}
{{- define "varnish-controller.name" }}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "varnish-controller.fullname" }}
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
{{- define "varnish-controller.chart" }}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Sets up the Varnish Controller image and its overrides (if any)
*/}}
{{- define "varnish-controller.image" }}
{{- $base := .base | default dict }}
{{- $image := .image | default dict }}
image: "{{- if eq $image.repository "-" }}{{ $base.repository }}{{ else }}{{ $image.repository }}{{ end }}:{{- if eq $image.tag "-" }}{{ default .Chart.AppVersion $base.tag }}{{ else }}{{ default .Chart.AppVersion $image.tag }}{{ end }}"
imagePullPolicy: {{ if eq $image.pullPolicy "-" }}{{ $base.pullPolicy }}{{ else }}{{ $image.pullPolicy }}{{ end }}
{{- end }}

{{/*
Sets up the NATS server
*/}}
{{- define "varnish-controller.natsServer" }}
{{- $natsAddress := "" }}
{{- $internalNats := false }}
{{- $tp := kindOf .Values.global.natsServer.internal.enabled }}
{{- if and (eq $tp "string") (eq .Values.global.natsServer.internal.enabled "-") .Values.nats.enabled }}
{{- $internalNats = true }}
{{- else if and (eq $tp "bool") .Values.global.natsServer.internal.enabled }}
{{- $internalNats = true }}
{{- end }}
{{- if $internalNats }}
{{- $natsNamespace := .Release.Namespace }}
{{- $natsReleaseName := .Release.Name }}
{{- if not (eq .Values.global.natsServer.internal.namespace "") }}
{{- $natsNamespace = .Values.global.natsServer.internal.namespace }}
{{- end }}
{{- if not (eq .Values.global.natsServer.internal.releaseName "") }}
{{- $natsReleaseName = .Values.global.natsServer.internal.releaseName }}
{{- end }}
{{- $natsAddress = printf "%s-nats.%s.svc.%s:4222" $natsReleaseName $natsNamespace .Values.global.natsServer.internal.clusterDomain }}
{{- else }}
{{- $natsAddress = .Values.global.natsServer.externalAddress }}
{{- end }}
{{- if eq $natsAddress "" }}
{{ fail "Either 'global.natsServer.internal.enabled' or 'global.natsServer.externalAddress' must be set" }}
{{- end }}
{{- if $internalNats }}
- name: VARNISH_CONTROLLER_NATS_USER
  value: varnish-controller
- name: VARNISH_CONTROLLER_NATS_HOST
  value: {{ $natsAddress | quote }}
- name: VARNISH_CONTROLLER_NATS_PASS
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.natsServer.internal.passwordFrom.name | quote }}
      key: {{ .Values.global.natsServer.internal.passwordFrom.key | quote }}
- name: VARNISH_CONTROLLER_NATS_SERVER
  value: "$(VARNISH_CONTROLLER_NATS_USER):$(VARNISH_CONTROLLER_NATS_PASS)@$(VARNISH_CONTROLLER_NATS_HOST)"
{{- else }}
- name: VARNISH_CONTROLLER_NATS_SERVER
  value: {{ $natsAddress | quote }}
{{- end }}
{{- end }}

{{/*
Sets extra envs from either an array, an object, or a string.
*/}}
{{- define "varnish-controller.toEnv" }}
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
{{- define "varnish-controller.toYamlField" }}
{{- $section := default "server" .section }}
{{- $fieldName := .fieldName }}
{{- $fieldKey := default $fieldName .fieldKey }}
{{- $fieldValue := .Values }}
{{- range $s := (splitList "." $section) }}
{{- $fieldValue = (get $fieldValue $s) }}
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
