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
Returns "true" if any varnish.storage.stores entry is defined. Each store
gets a PVC backed by the chart-level `storage` defaults.
*/}}
{{- define "orca.hasStores" -}}
{{- $stores := dig "varnish" "storage" "stores" (list) (default (dict) .Values.orca) -}}
{{- if not (empty $stores) -}}true{{- end -}}
{{- end -}}

{{/*
Returns "true" if the chart should render a headless companion Service.
Currently driven by `kind: StatefulSet`;
*/}}
{{- define "orca.needsHeadlessService" -}}
{{- if eq .Values.kind "StatefulSet" -}}true{{- end -}}
{{- end -}}

{{/*
Translates a Varnish size string into a Kubernetes resource.Quantity. The
supervisor accepts K/M/G/T (case-insensitive) as binary multipliers (2^10,
2^20, ...) and bare integers as bytes. Kubernetes treats bare K/M/G as
decimal (10^3, 10^6, ...) and uses Ki/Mi/Gi for binary, so we uppercase and
append "i" to the suffix. Bare integers pass through unchanged.
Examples: "100G" -> "100Gi", "100k" -> "100Ki", "100" -> "100".
*/}}
{{- define "orca.varnishSizeToK8sQuantity" -}}
{{- $s := upper (toString .) -}}
{{- regexReplaceAll "([KMGT])$" $s "${1}i" -}}
{{- end -}}

{{/*
Parses a Varnish size string into a byte count (decimal integer). Mirrors
the supervisor's parser: K/M/G/T as binary multipliers (2^10, 2^20, 2^30,
2^40), case-insensitive, and bare integers as bytes. Returns 0 on unknown
input (the supervisor would reject those at runtime anyway).
*/}}
{{- define "orca.parseSizeToBytes" -}}
{{- $s := upper (toString .) -}}
{{- $unit := regexFind "[KMGT]$" $s -}}
{{- $num := atoi (regexReplaceAll "[KMGT]$" $s "") -}}
{{- $mult := 1 -}}
{{- if eq $unit "K" -}}{{- $mult = 1024 -}}{{- end -}}
{{- if eq $unit "M" -}}{{- $mult = 1048576 -}}{{- end -}}
{{- if eq $unit "G" -}}{{- $mult = 1073741824 -}}{{- end -}}
{{- if eq $unit "T" -}}{{- $mult = 1099511627776 -}}{{- end -}}
{{- mul $num $mult -}}
{{- end -}}

{{/*
Validates that each store's size is strictly greater than book_size + 1G
filesystem overhead. Mirrors the supervisor's runtime check so the failure
surfaces during helm render instead of as a CrashLoopBackOff.
*/}}
{{- define "orca.validateStoreSizes" -}}
{{- $oneGB := 1073741824 -}}
{{- range $i, $store := dig "varnish" "storage" "stores" (list) (default (dict) .Values.orca) -}}
  {{- if $store.size -}}
    {{- $bookSizeStr := default "5G" $store.book_size -}}
    {{- $size := include "orca.parseSizeToBytes" $store.size | atoi -}}
    {{- $bookSize := include "orca.parseSizeToBytes" $bookSizeStr | atoi -}}
    {{- $minSize := add $bookSize $oneGB -}}
    {{- if le $size $minSize -}}
    {{- fail (printf "store %q: size %q must be greater than book_size + 1G filesystem overhead (book_size=%q)" $store.name (toString $store.size) $bookSizeStr) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Validates the chart values. Called from every workload template so that an
invalid configuration fails the render regardless of which workload is gated
on the chosen kind.
*/}}
{{- define "orca.validate" -}}
{{- if not (or (eq .Values.kind "Deployment") (eq .Values.kind "StatefulSet")) -}}
{{- fail (printf "kind must be 'Deployment' or 'StatefulSet', got %q" .Values.kind) -}}
{{- end -}}
{{- if and (eq (include "orca.needsHeadlessService" .) "true") (not .Values.service.http.enabled) (not .Values.service.https.enabled) -}}
{{- fail "the headless service needs at least one port: enable 'service.http.enabled' or 'service.https.enabled'" -}}
{{- end -}}
{{- if and (eq .Values.kind "Deployment") (eq (include "orca.hasStores" .) "true") -}}
{{- fail "persistent storage requires 'kind: StatefulSet'; 'kind: Deployment' is for memory-only caches" -}}
{{- end -}}
{{- include "orca.validateStoreSizes" . -}}
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