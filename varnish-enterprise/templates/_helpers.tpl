{{/* vim: set filetype=mustache: */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "varnish-common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "varnish-common.fullname" -}}
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
{{- define "varnish-common.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Returns "true" when rendering the Varnish Enterprise flavor of the chart, as
set by the "varnish.com/flavor" annotation in Chart.yaml. Enterprise-only
values (cluster, mse, mse4, agent, initAgent, licenseSecret, baseUrl,
global.natsServer) are absent from the Varnish Cache values, so they must only
be read behind this check or one of the predicates below.
*/}}
{{- define "varnish-common.isEnterprise" -}}
{{- if eq (index (.Chart.Annotations | default dict) "varnish.com/flavor") "enterprise" }}true{{ end }}
{{- end }}

{{- define "varnish-common.clusterEnabled" -}}
{{- if and (include "varnish-common.isEnterprise" .) .Values.cluster.enabled }}true{{ end }}
{{- end }}

{{- define "varnish-common.agentEnabled" -}}
{{- if and (include "varnish-common.isEnterprise" .) .Values.server.agent.enabled }}true{{ end }}
{{- end }}

{{/*
MSE is enabled by default ("-") unless MSE4 is enabled.
*/}}
{{- define "varnish-common.mseEnabled" -}}
{{- if include "varnish-common.isEnterprise" . }}
{{- if or (and (eq (kindOf .Values.server.mse.enabled) "bool") .Values.server.mse.enabled) (and (eq (kindOf .Values.server.mse.enabled) "string") (eq .Values.server.mse.enabled "-") (not .Values.server.mse4.enabled)) }}true{{ end }}
{{- end }}
{{- end }}

{{- define "varnish-common.mse4Enabled" -}}
{{- if and (include "varnish-common.isEnterprise" .) .Values.server.mse4.enabled }}true{{ end }}
{{- end }}

{{/*
Sets up the Varnish Enterprise image and its overrides (if any)
*/}}
{{- define "varnish-common.image" }}
{{- $base := .base | default dict }}
{{- $image := .image | default dict }}
image: "{{- if eq $image.repository "-" -}}{{ $base.repository }}{{ else }}{{ $image.repository }}{{ end }}:{{- if eq $image.tag "-" }}{{ default .Chart.AppVersion $base.tag }}{{ else }}{{ default $.Chart.AppVersion $image.tag }}{{ end }}"
imagePullPolicy: {{ if eq $image.pullPolicy "-" }}{{ $base.pullPolicy }}{{ else }}{{ $image.pullPolicy }}{{ end }}
{{- end }}

{{/*
Converts size string (e.g. 10Mi or 10M) to a number
*/}}
{{- define "varnish-common.sizeStrToNumber" -}}
{{- $sizeStr := toString .sizeStr -}}
{{- $size := atoi (mustRegexFind "[0-9]+" $sizeStr) }}
{{- if not $size -}}
{{- fail (print "Failed to parse the storage size: " $sizeStr " -> " $size) }}
{{- end -}}
{{- $multiplier := 1 -}}
{{- if hasSuffix "Pi" $sizeStr -}}
{{- $multiplier = mul 1024 1024 1024 1024 1024 -}}
{{- else if hasSuffix "P" $sizeStr -}}
{{- $multiplier = mul 1000 1000 1000 1000 1000 -}}
{{- else if hasSuffix "Ti" $sizeStr -}}
{{- $multiplier = mul 1024 1024 1024 1024 -}}
{{- else if hasSuffix "T" $sizeStr -}}
{{- $multiplier = mul 1000 1000 1000 1000 -}}
{{- else if hasSuffix "Gi" $sizeStr -}}
{{- $multiplier = mul 1024 1024 1024 -}}
{{- else if hasSuffix "G" $sizeStr -}}
{{- $multiplier = mul 1000 1000 1000 -}}
{{- else if hasSuffix "Mi" $sizeStr -}}
{{- $multiplier = mul 1024 1024 -}}
{{- else if hasSuffix "M" $sizeStr -}}
{{- $multiplier = mul 1000 1000 -}}
{{- else if hasSuffix "Ki" $sizeStr -}}
{{- $multiplier = mul 1024 -}}
{{- else if hasSuffix "K" $sizeStr -}}
{{- $multiplier = mul 1000 -}}
{{- else if not (mustRegexFind "^[0-9]+$" $sizeStr) -}}
{{- fail (print "Unknown storage size suffix: " $sizeStr) -}}
{{- end -}}
{{- mul $size $multiplier -}}
{{- end }}

{{/*
Converts size string (e.g. 10Mi or 10M) or a percentage to a number.
*/}}
{{- define "varnish-common.sizeStrPercentToNumber" -}}
{{- $sizeStr := toString .sizeStr -}}
{{- if hasSuffix "%" $sizeStr -}}
{{- $percent := atoi (mustRegexFind "[0-9]+" $sizeStr) }}
{{- $baseSize := .baseSize -}}
{{- if not $percent -}}
{{- fail (print "Failed to parse the storage size: " $sizeStr " -> " $percent) }}
{{- end -}}
{{- div (mul $baseSize $percent) 100 -}}
{{- else -}}
{{- include "varnish-common.sizeStrToNumber" (merge (dict "sizeStr" $sizeStr)) -}}
{{- end -}}
{{- end }}

{{/*
Sets up the NATS server
*/}}
{{- define "varnish-common.natsServer" }}
{{- $natsAddress := "" }}
{{- $internalNats := false }}
{{- $tp := kindOf .Values.global.natsServer.internal.enabled }}
{{- if .Values.global.natsServer.internal.enabled }}
{{- $natsNamespace := .Release.Namespace }}
{{- $natsReleaseName := "varnish-controller" }}
{{- $internalNats = true }}
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
{{- define "varnish-common.toEnv" }}
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
{{- define "varnish-common.toYamlField" }}
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
