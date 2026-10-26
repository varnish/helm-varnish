{{/* vim: set filetype=mustache: */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "varnish-enterprise.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "varnish-enterprise.fullname" -}}
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
{{- define "varnish-enterprise.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Sets up the Varnish Enterprise image and its overrides (if any)
*/}}
{{- define "varnish-enterprise.image" }}
{{- $base := .base | default dict }}
{{- $image := .image | default dict }}
image: "{{- if eq $image.repository "-" -}}{{ $base.repository }}{{ else }}{{ $image.repository }}{{ end }}:{{- if eq $image.tag "-" }}{{ default .Chart.AppVersion $base.tag }}{{ else }}{{ default $.Chart.AppVersion $image.tag }}{{ end }}"
imagePullPolicy: {{ if eq $image.pullPolicy "-" }}{{ $base.pullPolicy }}{{ else }}{{ $image.pullPolicy }}{{ end }}
{{- end }}

{{/*
Converts size string (e.g. 10Mi or 10M) to a number
*/}}
{{- define "varnish-enterprise.sizeStrToNumber" -}}
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
{{- define "varnish-enterprise.sizeStrPercentToNumber" -}}
{{- $sizeStr := toString .sizeStr -}}
{{- if hasSuffix "%" $sizeStr -}}
{{- $percent := atoi (mustRegexFind "[0-9]+" $sizeStr) }}
{{- $baseSize := .baseSize -}}
{{- if not $percent -}}
{{- fail (print "Failed to parse the storage size: " $sizeStr " -> " $percent) }}
{{- end -}}
{{- div (mul $baseSize $percent) 100 -}}
{{- else -}}
{{- include "varnish-enterprise.sizeStrToNumber" (merge (dict "sizeStr" $sizeStr)) -}}
{{- end -}}
{{- end }}

{{/*
Sets up the NATS server
*/}}
{{- define "varnish-enterprise.natsServer" }}
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
{{- define "varnish-enterprise.toEnv" }}
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
{{- define "varnish-enterprise.toYamlField" }}
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

{{/*
Stringifies a number, without the float notation YAML integers get (1000000 -> "1000000", not "1e+06").
*/}}
{{- define "varnish-enterprise.intString" }}
{{- if and (kindIs "float64" .) (eq . (floor .)) }}
{{- int64 . }}
{{- else }}
{{- . }}
{{- end }}
{{- end }}

{{/*
Validates the cluster configuration and declares the environment variables
consumed by cluster_auto_dns.vcl.
*/}}
{{- define "varnish-enterprise.clusterEnv" }}
{{- $cluster := .Values.cluster }}
{{- if not .Values.server.http.enabled }}
{{- fail "'server.http.enabled' must be true for clustering to work" }}
{{- end }}
{{- if not (kindIs "bool" $cluster.trace) }}
{{- fail (printf "cluster.trace must be a boolean, got '%v'" $cluster.trace) }}
{{- end }}
{{- $primaries := "" }}
{{- if not (kindIs "invalid" $cluster.primaries) }}
{{- $primaries = include "varnish-enterprise.intString" $cluster.primaries }}
{{- end }}
{{- if and (ne $primaries "") (or (not (regexMatch "^[0-9]+$" $primaries)) (lt (atoi $primaries) 1)) }}
{{- fail (printf "cluster.primaries must be a strictly positive integer, got '%s'" $primaries) }}
{{- end }}
{{- $fallback := "" }}
{{- if not (kindIs "invalid" $cluster.fallback) }}
{{- $fallback = include "varnish-enterprise.intString" $cluster.fallback }}
{{- end }}
{{- if and (ne $fallback "") (not (regexMatch "^[0-9]+$" $fallback)) }}
{{- fail (printf "cluster.fallback must be a positive integer, got '%s'" $fallback) }}
{{- end }}
{{- $extraEnvNames := list }}
{{- if kindIs "map" .Values.server.extraEnvs }}
{{- $extraEnvNames = keys .Values.server.extraEnvs }}
{{- else if kindIs "slice" .Values.server.extraEnvs }}
{{- range .Values.server.extraEnvs }}
{{- $extraEnvNames = append $extraEnvNames .name }}
{{- end }}
{{- end }}
{{- range $extraEnvNames }}
{{- if hasPrefix "VARNISH_CLUSTER_" . }}
{{- fail (printf "server.extraEnvs: '%s' is managed by the chart when cluster.enabled is true, use the cluster.* values instead" .) }}
{{- end }}
{{- end }}
- name: VARNISH_CLUSTER_TOKEN
  valueFrom:
    secretKeyRef:
      {{- if $cluster.secretName }}
      name: {{ $cluster.secretName }}
      {{- else }}
      name: {{ include "varnish-enterprise.fullname" . }}-cluster-secret
      {{- end }}
      key: token
- name: VARNISH_CLUSTER_PEER_DOMAIN
  {{- if $cluster.headlessServiceName }}
  value: "{{ $cluster.headlessServiceName }}:{{ .Values.server.http.port }}"
  {{- else }}
  value: "{{ include "varnish-enterprise.fullname" . }}-peers:{{ .Values.server.http.port }}"
  {{- end }}
{{- if $cluster.trace }}
- name: VARNISH_CLUSTER_TRACE
  value: "true"
{{- end }}
{{- if ne $primaries "" }}
- name: VARNISH_CLUSTER_PRIMARIES
  value: {{ $primaries | quote }}
{{- end }}
{{- if ne $fallback "" }}
- name: VARNISH_CLUSTER_FALLBACK
  value: {{ $fallback | quote }}
{{- end }}
{{- end }}
