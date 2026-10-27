{{/*
Aliases for the named templates that used to be prefixed with "varnish-cache.", kept
so that templated strings in existing user values (e.g. server.affinity)
keep working.
*/}}
{{- define "varnish-cache.name" -}}{{ include "varnish-common.name" . }}{{- end }}
{{- define "varnish-cache.fullname" -}}{{ include "varnish-common.fullname" . }}{{- end }}
{{- define "varnish-cache.chart" -}}{{ include "varnish-common.chart" . }}{{- end }}
{{- define "varnish-cache.labels" -}}{{ include "varnish-common.labels" . }}{{- end }}
{{- define "varnish-cache.selectorLabels" -}}{{ include "varnish-common.selectorLabels" . }}{{- end }}
{{- define "varnish-cache.serviceAccountName" -}}{{ include "varnish-common.serviceAccountName" . }}{{- end }}
