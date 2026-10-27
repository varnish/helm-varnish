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
  {{- /* book_volume describes the PVC the chart renders for a book_path, which
  the supervisor knows nothing about. Its decoding rejects unknown keys, so the
  key is dropped here rather than passed through. */ -}}
  {{- range $i, $store := dig "varnish" "storage" "stores" (list) $cfg -}}
    {{- $_ := unset $store "book_volume" -}}
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
Validates each store's name: it is required (it forms the PVC name
"orca-storage-<name>") and must be unique across stores so the generated PVCs
do not collide.
*/}}
{{- define "orca.validateStoreNames" -}}
{{- $seen := dict -}}
{{- range $i, $store := dig "varnish" "storage" "stores" (list) (default (dict) .Values.orca) -}}
  {{- if not $store.name -}}
  {{- fail (printf "store at index %d: 'name' is required; it forms the PVC name \"orca-storage-<name>\"" $i) -}}
  {{- end -}}
  {{- if hasKey $seen $store.name -}}
  {{- fail (printf "store %q: duplicate name; each store name must be unique" $store.name) -}}
  {{- end -}}
  {{- $_ := set $seen $store.name true -}}
{{- end -}}
{{- end -}}

{{/*
Returns "true" when a store keeps its book on a volume of its own. The
supervisor decides that by comparing the two device IDs at runtime, which a
render cannot see, but book_path settles it here: the chart gives that path a
PVC of its own, so the two are never the same device.
*/}}
{{- define "orca.storeHasBookVolume" -}}
{{- if .book_path -}}true{{- end -}}
{{- end -}}

{{/*
Validates each store's size: it is required (a PVC with no storage request is
rejected by dynamic provisioners) and must be strictly greater than book_size
plus filesystem overhead, which the supervisor takes as 3% of size with a 1G
floor. A store with its own book volume drops book_size from that minimum,
since size then covers the store alone. Mirrors the supervisor's runtime check,
in the same order of operations so the two agree at the boundary, and surfaces
the failure during helm render instead of as a CrashLoopBackOff.
*/}}
{{- define "orca.validateStoreSizes" -}}
{{- $oneGB := 1073741824 -}}
{{- range $i, $store := dig "varnish" "storage" "stores" (list) (default (dict) .Values.orca) -}}
  {{- if not $store.size -}}
  {{- fail (printf "store %q: 'size' is required; each store renders a PVC that needs a storage request" $store.name) -}}
  {{- end -}}
  {{- $bookSizeStr := default "5G" $store.book_size -}}
  {{- $size := include "orca.parseSizeToBytes" $store.size | atoi -}}
  {{- $bookSize := include "orca.parseSizeToBytes" $bookSizeStr | atoi -}}
  {{- $overhead := mul (div $size 100) 3 -}}
  {{- if lt $overhead $oneGB -}}{{- $overhead = $oneGB -}}{{- end -}}
  {{- if eq (include "orca.storeHasBookVolume" $store) "true" -}}
    {{- if le $size $overhead -}}
    {{- fail (printf "store %q: size %q must be greater than the filesystem overhead, which is 3%% of size with a 1G floor; book_size is not counted because book_path puts the book on its own volume" $store.name (toString $store.size)) -}}
    {{- end -}}
  {{- else -}}
    {{- if le $size (add $bookSize $overhead) -}}
    {{- fail (printf "store %q: size %q must be greater than book_size plus filesystem overhead, which is 3%% of size with a 1G floor (book_size=%q)" $store.name (toString $store.size) $bookSizeStr) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Validates each store's book volume. book_path puts the book on a device of its
own, which only means something if the chart gives it a PVC, so book_volume.size
is required alongside it and has to hold book_size. The path has to be outside
the store's own, since a book under it would be a second volume mounted inside
the first.
*/}}
{{- define "orca.validateBookVolumes" -}}
{{- range $i, $store := dig "varnish" "storage" "stores" (list) (default (dict) .Values.orca) -}}
  {{- $bookVolume := default (dict) $store.book_volume -}}
  {{- if not $store.book_path -}}
    {{- if not (empty $bookVolume) -}}
    {{- fail (printf "store %q: 'book_volume' needs 'book_path'; without it the book stays on the store's volume and is sized out of 'size'" $store.name) -}}
    {{- end -}}
  {{- else -}}
    {{- $path := clean $store.path -}}
    {{- $bookPath := clean $store.book_path -}}
    {{- if eq $bookPath $path -}}
    {{- fail (printf "store %q: 'book_path' %q is the store's own path; leave it unset to keep the book on the store's volume" $store.name (toString $store.book_path)) -}}
    {{- end -}}
    {{- if hasPrefix (printf "%s/" $path) $bookPath -}}
    {{- fail (printf "store %q: 'book_path' %q is inside the store's path %q, so its volume would mount inside the store's; give it a path of its own" $store.name (toString $store.book_path) (toString $store.path)) -}}
    {{- end -}}
    {{- if not $bookVolume.size -}}
    {{- fail (printf "store %q: 'book_volume.size' is required when 'book_path' is set; it renders a PVC that needs a storage request" $store.name) -}}
    {{- end -}}
    {{- $bookSizeStr := default "5G" $store.book_size -}}
    {{- $bookSize := include "orca.parseSizeToBytes" $bookSizeStr | atoi -}}
    {{- $volumeSize := include "orca.parseSizeToBytes" $bookVolume.size | atoi -}}
    {{- if lt $volumeSize $bookSize -}}
    {{- fail (printf "store %q: 'book_volume.size' %q is smaller than book_size %q, so the book would not fit on it" $store.name (toString $bookVolume.size) $bookSizeStr) -}}
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
{{- include "orca.validateStoreNames" . -}}
{{- include "orca.validateBookVolumes" . -}}
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