{{/*
Aliases for the named templates that used to be prefixed with "varnish-enterprise.", kept
so that templated strings in existing user values (e.g. server.affinity)
keep working.
*/}}
{{- define "varnish-enterprise.name" -}}{{ include "varnish-common.name" . }}{{- end }}
{{- define "varnish-enterprise.fullname" -}}{{ include "varnish-common.fullname" . }}{{- end }}
{{- define "varnish-enterprise.chart" -}}{{ include "varnish-common.chart" . }}{{- end }}
{{- define "varnish-enterprise.labels" -}}{{ include "varnish-common.labels" . }}{{- end }}
{{- define "varnish-enterprise.selectorLabels" -}}{{ include "varnish-common.selectorLabels" . }}{{- end }}
{{- define "varnish-enterprise.serviceAccountName" -}}{{ include "varnish-common.serviceAccountName" . }}{{- end }}
