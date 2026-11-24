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
set by the "flavor" annotation in Chart.yaml. Enterprise-only values (those
marked "x-flavor: enterprise" in varnish-common/schema/values.schema.yaml, such
as cluster, server.mse4, server.agent, server.licenseSecret, server.baseUrl,
server.delayedShutdown.shutdownDelay and global.natsServer) are absent from the
Varnish Cache values, so they must only be read behind this check or one of the
predicates below.
*/}}
{{- define "varnish-common.isEnterprise" -}}
{{- if eq (index (.Chart.Annotations | default dict) "flavor") "enterprise" }}true{{ end }}
{{- end }}

{{- define "varnish-common.clusterEnabled" -}}
{{- if and (include "varnish-common.isEnterprise" .) .Values.cluster.enabled }}true{{ end }}
{{- end }}

{{- define "varnish-common.agentEnabled" -}}
{{- if and (include "varnish-common.isEnterprise" .) .Values.server.agent.enabled }}true{{ end }}
{{- end }}

{{- define "varnish-common.mse4Enabled" -}}
{{- if and (include "varnish-common.isEnterprise" .) .Values.server.mse4.enabled }}true{{ end }}
{{- end }}

{{/*
Returns "true" when the value given as context is neither null nor an empty
string. Unlike a plain "if", zero and false count as set.
*/}}
{{- define "varnish-common.isSet" -}}
{{- if and (not (kindIs "invalid" .)) (ne (toString .) "") }}true{{ end }}
{{- end }}

{{/*
Renders an image tag as a string. The schema only accepts string tags, but
renders with --skip-schema-validation can pass float64 numbers, which
toString prints in scientific notation (2.0241129e+07); toJson does not.
*/}}
{{- define "varnish-common.imageTag" -}}
{{- if kindIs "float64" . }}{{ toJson . }}{{ else }}{{ toString . }}{{ end }}
{{- end }}

{{/*
Renders the image and imagePullPolicy of a container. An empty tag falls back
to the chart's appVersion.
*/}}
{{- define "varnish-common.image" }}
{{- $image := .image | default dict }}
{{- $tag := $image.tag }}
{{- /* not "default": it would also replace a numeric tag 0 */}}
{{- if or (kindIs "invalid" $tag) (eq (toString $tag) "") }}{{ $tag = .Chart.AppVersion }}{{ end }}
image: "{{ $image.repository }}:{{ include "varnish-common.imageTag" $tag }}"
imagePullPolicy: {{ $image.pullPolicy }}
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
The in-cluster host name of a Varnish Controller service ("nats", "apigw"),
located with global.natsServer.internal.{releaseName,namespace,clusterDomain}.
*/}}
{{- define "varnish-common.controllerHost" -}}
{{- $internal := .Values.global.natsServer.internal }}
{{- $releaseName := $internal.releaseName | default "varnish-controller" }}
{{- $namespace := $internal.namespace | default .Release.Namespace }}
{{- printf "%s-%s.%s.svc.%s" $releaseName .service $namespace $internal.clusterDomain }}
{{- end }}

{{/*
Sets up the NATS server
*/}}
{{- define "varnish-common.natsServer" }}
{{- $natsAddress := "" }}
{{- $internalNats := false }}
{{- $tp := kindOf .Values.global.natsServer.internal.enabled }}
{{- if .Values.global.natsServer.internal.enabled }}
{{- $internalNats = true }}
{{- $natsAddress = printf "%s:4222" (include "varnish-common.controllerHost" (merge (dict "service" "nats") .)) }}
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
Renders `<fieldName>: <map>`: <section>.<fieldName> merged with global.<fieldName>
(each an object or a template string), <section> winning. Renders nothing when empty.
*/}}
{{- define "varnish-common.toYamlField" }}
{{- $fieldName := .fieldName }}
{{- $fieldValue := .Values }}
{{- range $s := (splitList "." .section) }}
{{- $fieldValue = (get $fieldValue $s) }}
{{- end }}
{{- $fieldValue = (get $fieldValue $fieldName) }}
{{- if (empty $fieldValue) }}
{{- $fieldValue = (dict) }}
{{- else if eq (kindOf $fieldValue) "string" }}
{{- $fieldValue = (fromYaml (tpl $fieldValue .)) }}
{{- end }}
{{- $globalFieldValue := (get .Values.global $fieldName) }}
{{- if eq (kindOf $globalFieldValue) "string" }}
{{- $globalFieldValue = (fromYaml (tpl $globalFieldValue .)) }}
{{- end }}
{{- if not (empty $globalFieldValue) }}
{{- $fieldValue = (merge $fieldValue $globalFieldValue) }}
{{- end }}
{{- if not (empty $fieldValue) }}
{{- (dict $fieldName $fieldValue) | toYaml }}
{{- end }}
{{- end }}

{{/*
Stringifies a number, without the float notation YAML integers get (1000000 -> "1000000", not "1e+06").
*/}}
{{- define "varnish-common.intString" }}
{{- if and (kindIs "float64" .) (eq . (floor .)) }}
{{- int64 . }}
{{- else }}
{{- . }}
{{- end }}
{{- end }}

{{/*
Validates the cluster configuration and declares the environment variables
consumed by cluster_auto_dns.vcl. Varnish Enterprise only.
*/}}
{{- define "varnish-common.clusterEnv" }}
{{- $cluster := .Values.cluster }}
{{- if not .Values.server.http.enabled }}
{{- fail "'server.http.enabled' must be true for clustering to work" }}
{{- end }}
{{- if not (kindIs "bool" $cluster.trace) }}
{{- fail (printf "cluster.trace must be a boolean, got '%v'" $cluster.trace) }}
{{- end }}
{{- $primaries := "" }}
{{- if not (kindIs "invalid" $cluster.primaries) }}
{{- $primaries = include "varnish-common.intString" $cluster.primaries }}
{{- end }}
{{- if and (ne $primaries "") (or (not (regexMatch "^[0-9]+$" $primaries)) (lt (atoi $primaries) 1)) }}
{{- fail (printf "cluster.primaries must be a strictly positive integer, got '%s'" $primaries) }}
{{- end }}
{{- $fallback := "" }}
{{- if not (kindIs "invalid" $cluster.fallback) }}
{{- $fallback = include "varnish-common.intString" $cluster.fallback }}
{{- end }}
{{- if and (ne $fallback "") (not (regexMatch "^[0-9]+$" $fallback)) }}
{{- fail (printf "cluster.fallback must be a positive integer, got '%s'" $fallback) }}
{{- end }}
{{- $extraEnvs := .Values.server.extraEnvs }}
{{- if kindIs "string" $extraEnvs }}
{{- $extraEnvs = fromYamlArray (tpl $extraEnvs .) }}
{{- end }}
{{- $extraEnvNames := list }}
{{- if kindIs "map" $extraEnvs }}
{{- $extraEnvNames = keys $extraEnvs }}
{{- else if kindIs "slice" $extraEnvs }}
{{- range $extraEnvs }}
{{- if kindIs "map" . }}
{{- $extraEnvNames = append $extraEnvNames (toString .name) }}
{{- end }}
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
      name: {{ include "varnish-common.fullname" . }}-cluster-secret
      {{- end }}
      key: token
- name: VARNISH_CLUSTER_PEER_DOMAIN
  {{- if $cluster.headlessServiceName }}
  value: "{{ $cluster.headlessServiceName }}:{{ .Values.server.http.port }}"
  {{- else }}
  value: "{{ include "varnish-common.fullname" . }}-peers:{{ .Values.server.http.port }}"
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
