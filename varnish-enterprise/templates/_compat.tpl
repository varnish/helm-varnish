{{/*
Aliases for the named templates that used to be prefixed with "varnish-enterprise.", kept
so that templated strings in existing user values (e.g. server.affinity)
keep working.
*/}}
{{- define "varnish-enterprise.name" -}}{{ include "varnish.name" . }}{{- end }}
{{- define "varnish-enterprise.fullname" -}}{{ include "varnish.fullname" . }}{{- end }}
{{- define "varnish-enterprise.chart" -}}{{ include "varnish.chart" . }}{{- end }}
{{- define "varnish-enterprise.labels" -}}{{ include "varnish.labels" . }}{{- end }}
{{- define "varnish-enterprise.selectorLabels" -}}{{ include "varnish.selectorLabels" . }}{{- end }}
{{- define "varnish-enterprise.serviceAccountName" -}}{{ include "varnish.serviceAccountName" . }}{{- end }}
