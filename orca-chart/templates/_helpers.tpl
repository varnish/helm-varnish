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
Returns "true" when a store has a book volume to render. book_path alone
decides that, since the claim follows the setting.

This is not the same question as whether the supervisor will treat the book as
separate. That is settled at runtime by the two device IDs, and a render cannot
see those: a provisioner that hands out directories on one node filesystem,
local-path among them, gives two claims the same device. So nothing here may
relax a size rule on the strength of it.
*/}}
{{- define "orca.storeHasBookVolume" -}}
{{- if .book_path -}}true{{- end -}}
{{- end -}}

{{/*
Returns the space to hold back from a volume for filesystem metadata: 3% of its
size, with a 1G floor. Mirrors the supervisor's filesystemOverheadFor, in the
same order of operations so the two agree at the boundary.
*/}}
{{- define "orca.filesystemOverhead" -}}
{{- $oneGB := 1073741824 -}}
{{- $overhead := mul (div (atoi (toString .)) 100) 3 -}}
{{- if lt $overhead $oneGB -}}{{- $oneGB -}}{{- else -}}{{- $overhead -}}{{- end -}}
{{- end -}}

{{/*
Validates each store's size: it is required (a PVC with no storage request is
rejected by dynamic provisioners) and must be strictly greater than book_size
plus filesystem overhead. Mirrors the supervisor's runtime check and surfaces
the failure during helm render instead of as a CrashLoopBackOff.

book_size stays in the minimum even when book_path sends the book elsewhere.
The supervisor drops it only once the two paths report different devices, which
separate claims do not promise, so counting it keeps the chart from accepting a
store the supervisor then refuses. The cost of being wrong this way is a store
asked to be larger than it had to be; the other way is a pod that will not
start.
*/}}
{{- define "orca.validateStoreSizes" -}}
{{- range $i, $store := dig "varnish" "storage" "stores" (list) (default (dict) .Values.orca) -}}
  {{- if not $store.size -}}
  {{- fail (printf "store %q: 'size' is required; each store renders a PVC that needs a storage request" $store.name) -}}
  {{- end -}}
  {{- $bookSizeStr := default "5G" $store.book_size -}}
  {{- $size := include "orca.parseSizeToBytes" $store.size | atoi -}}
  {{- $bookSize := include "orca.parseSizeToBytes" $bookSizeStr | atoi -}}
  {{- $overhead := include "orca.filesystemOverhead" $size | atoi -}}
  {{- if le $size (add $bookSize $overhead) -}}
  {{- fail (printf "store %q: size %q must be greater than book_size plus filesystem overhead, which is 3%% of size with a 1G floor (book_size=%q)" $store.name (toString $store.size) $bookSizeStr) -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Validates that no two mount paths collide. Every store path, and every book_path
beside it, becomes a volumeMount on the one container, and Kubernetes refuses a
pod whose mount paths are not unique. A book under a store's path is refused
too, since its volume would mount inside the other's.
*/}}
{{- define "orca.validateStorePaths" -}}
{{- $seen := dict -}}
{{- range $i, $store := dig "varnish" "storage" "stores" (list) (default (dict) .Values.orca) -}}
  {{- if not $store.path -}}
  {{- fail (printf "store %q: 'path' is required; it is where the store's volume mounts" $store.name) -}}
  {{- end -}}
  {{- $paths := list (dict "key" "path" "value" $store.path) -}}
  {{- if $store.book_path -}}
  {{- $paths = append $paths (dict "key" "book_path" "value" $store.book_path) -}}
  {{- end -}}
  {{- range $entry := $paths -}}
    {{- $path := clean $entry.value -}}
    {{- if hasKey $seen $path -}}
    {{- fail (printf "store %q: '%s' %q is already mounted by store %q; every store path and book_path becomes a volume mount, and a pod's mount paths have to be unique" $store.name $entry.key (toString $entry.value) (get $seen $path)) -}}
    {{- end -}}
    {{- range $other, $owner := $seen -}}
      {{- if or (hasPrefix (printf "%s/" $other) $path) (hasPrefix (printf "%s/" $path) $other) -}}
      {{- fail (printf "store %q: '%s' %q nests with %q from store %q, so one volume would mount inside the other; give each a path of its own" $store.name $entry.key (toString $entry.value) $other $owner) -}}
      {{- end -}}
    {{- end -}}
    {{- $_ := set $seen $path $store.name -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Validates each store's book volume. book_path only means anything if the chart
gives it a claim, so book_volume.size comes with it, and the claim has to hold
the book plus the filesystem's own metadata: a volume formatted to exactly
book_size leaves less than that free, and allocating the book then fails for
want of space.
*/}}
{{- define "orca.validateBookVolumes" -}}
{{- range $i, $store := dig "varnish" "storage" "stores" (list) (default (dict) .Values.orca) -}}
  {{- $bookVolume := default (dict) $store.book_volume -}}
  {{- if not $store.book_path -}}
    {{- if not (empty $bookVolume) -}}
    {{- fail (printf "store %q: 'book_volume' needs 'book_path'; drop both to bring the book back onto the store's volume, where it is sized out of 'size'" $store.name) -}}
    {{- end -}}
  {{- else -}}
    {{- if not $bookVolume.size -}}
    {{- fail (printf "store %q: 'book_volume.size' is required when 'book_path' is set; it renders a PVC that needs a storage request" $store.name) -}}
    {{- end -}}
    {{- $bookSizeStr := default "5G" $store.book_size -}}
    {{- $bookSize := include "orca.parseSizeToBytes" $bookSizeStr | atoi -}}
    {{- $volumeSize := include "orca.parseSizeToBytes" $bookVolume.size | atoi -}}
    {{- $overhead := include "orca.filesystemOverhead" $volumeSize | atoi -}}
    {{- if le $volumeSize (add $bookSize $overhead) -}}
    {{- fail (printf "store %q: 'book_volume.size' %q must be greater than book_size plus filesystem overhead, which is 3%% of it with a 1G floor (book_size=%q)" $store.name (toString $bookVolume.size) $bookSizeStr) -}}
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
{{- include "orca.validateStorePaths" . -}}
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