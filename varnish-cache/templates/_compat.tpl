{{/*
Aliases for the named templates that used to be prefixed with "varnish-cache.", kept
so that templated strings in existing user values (e.g. server.affinity)
keep working.
*/}}
{{- define "varnish-cache.name" -}}{{ include "varnish.name" . }}{{- end }}
{{- define "varnish-cache.fullname" -}}{{ include "varnish.fullname" . }}{{- end }}
{{- define "varnish-cache.chart" -}}{{ include "varnish.chart" . }}{{- end }}
{{- define "varnish-cache.labels" -}}{{ include "varnish.labels" . }}{{- end }}
{{- define "varnish-cache.selectorLabels" -}}{{ include "varnish.selectorLabels" . }}{{- end }}
{{- define "varnish-cache.serviceAccountName" -}}{{ include "varnish.serviceAccountName" . }}{{- end }}
