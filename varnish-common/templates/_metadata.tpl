{{/* vim: set filetype=mustache: */}}

{{/*
Common labels
*/}}
{{- define "varnish.labels" -}}
helm.sh/chart: {{ include "varnish.chart" . }}
{{ include "varnish.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "varnish.selectorLabels" -}}
app.kubernetes.io/name: {{ include "varnish.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "varnish.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "varnish.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Sets up the common server extra annotations
*/}}
{{- define "varnish.serverAnnotations" -}}
{{- $section := default "server" .section }}
{{- include "varnish.toYamlField"
  (merge
    (dict
      "section" $section
      "fieldName" "annotations"
      "extraFieldValues" .extraAnnotations)
    .) }}
{{- end }}

{{/*
Sets up the common server extra labels
*/}}
{{- define "varnish.serverLabels" -}}
{{- $section := default "server" .section }}
{{- $nameSuffix := .nameSuffix }}
{{- if not (eq $nameSuffix "") }}
{{- $nameSuffix = .section }}
{{- end }}
{{- $defaultLabel := (fromYaml (include "varnish.labels" (merge (dict "nameSuffix" $nameSuffix) .))) }}
{{- $extraLabels := default dict .extraLabels }}
{{- include "varnish.toYamlField"
  (merge
    (dict
      "section" $section
      "fieldName" "labels"
      "extraFieldValues" (merge $extraLabels $defaultLabel))
    .) }}
{{- end }}

{{/*
Sets up the common service extra annotations
*/}}
{{- define "varnish.serviceAnnotations" -}}
{{- if .Values.server.service.annotations }}
annotations:
  {{- $tp := kindOf .Values.server.service.annotations }}
  {{- if eq $tp "string" }}
    {{- tpl .Values.server.service.annotations . | trim | nindent 2 }}
  {{- else }}
    {{- toYaml .Values.server.service.annotations | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Sets up the common service extra labels
*/}}
{{- define "varnish.serviceLabels" -}}
{{- $section := default "server" .section -}}
{{- $service := (get .Values $section).service -}}
{{- if $service.labels -}}
{{- $tp := kindOf $service.labels -}}
{{- if eq $tp "string" -}}
{{- tpl $service.labels . | trim | nindent 0 }}
{{- else -}}
{{- toYaml $service.labels | trim | nindent 0 }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Sets up the common ingress extra annotations
*/}}
{{- define "varnish.ingressAnnotations" -}}
{{- $section := default "server" .section -}}
{{- $ingress := (get .Values $section).ingress -}}
{{- if $ingress.annotations }}
annotations:
  {{- $tp := kindOf $ingress.annotations }}
  {{- if eq $tp "string" }}
    {{- tpl $ingress.annotations . | trim | nindent 2 }}
  {{- else }}
    {{- toYaml $ingress.annotations | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Sets up the common ingress extra labels
*/}}
{{- define "varnish.ingressLabels" -}}
{{- $section := default "server" .section -}}
{{- $ingress := (get .Values $section).ingress -}}
{{- if $ingress.labels }}
{{- $tp := kindOf $ingress.labels }}
{{- if eq $tp "string" }}
  {{- tpl $ingress.labels . | trim | nindent 0 }}
{{- else }}
  {{- toYaml $ingress.labels | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Sets up the common MSE extra annotations
*/}}
{{- define "varnish.mseAnnotations" -}}
{{- if .Values.server.mse.persistence.annotations }}
annotations:
  {{- $tp := kindOf .Values.server.mse.persistence.annotations }}
  {{- if eq $tp "string" }}
    {{- tpl .Values.server.mse.persistence.annotations . | trim | nindent 2 }}
  {{- else }}
    {{- toYaml .Values.server.mse.persistence.annotations | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Sets up the common MSE PVC labels
*/}}
{{- define "varnish.msePvcLabels" -}}
{{- if .Values.server.mse.persistence.labels }}
{{- $tp := kindOf .Values.server.mse.persistence.labels }}
{{- if eq $tp "string" }}
  {{- tpl .Values.server.mse.persistence.labels . | trim | nindent 0 }}
{{- else }}
  {{- toYaml .Values.server.mse.persistence.labels | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Sets up the common MSE4 extra annotations
*/}}
{{- define "varnish.mse4Annotations" -}}
{{- if .Values.server.mse4.persistence.annotations }}
annotations:
  {{- $tp := kindOf .Values.server.mse4.persistence.annotations }}
  {{- if eq $tp "string" }}
    {{- tpl .Values.server.mse4.persistence.annotations . | trim | nindent 2 }}
  {{- else }}
    {{- toYaml .Values.server.mse4.persistence.annotations | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Sets up the common MSE4 PVC labels
*/}}
{{- define "varnish.mse4PvcLabels" -}}
{{- if .Values.server.mse4.persistence.labels }}
{{- $tp := kindOf .Values.server.mse4.persistence.labels }}
{{- if eq $tp "string" }}
  {{- tpl .Values.server.mse4.persistence.labels . | trim | nindent 0 }}
{{- else }}
  {{- toYaml .Values.server.mse4.persistence.labels | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Sets up the common Agent PVC labels
*/}}
{{- define "varnish.agentPvcLabels" -}}
{{- if .Values.server.agent.persistence.labels }}
{{- $tp := kindOf .Values.server.agent.persistence.labels }}
{{- if eq $tp "string" }}
  {{- tpl .Values.server.agent.persistence.labels . | trim | nindent 0 }}
{{- else }}
  {{- toYaml .Values.server.agent.persistence.labels | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Sets up the common service account annotations
*/}}
{{- define "varnish.serviceAccountAnnotations" -}}
{{- if .Values.serviceAccount.annotations }}
annotations:
  {{- $tp := kindOf .Values.serviceAccount.annotations }}
  {{- if eq $tp "string" }}
    {{- tpl .Values.serviceAccount.annotations . | trim | nindent 2 }}
  {{- else }}
    {{- toYaml .Values.serviceAccount.annotations | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Sets up the common service account extra labels
*/}}
{{- define "varnish.serviceAccountLabels" -}}
{{- if .Values.serviceAccount.labels }}
{{- $tp := kindOf .Values.serviceAccount.labels }}
{{- if eq $tp "string" }}
  {{- tpl .Values.serviceAccount.labels . | trim | nindent 0 }}
{{- else }}
  {{- toYaml .Values.serviceAccount.labels | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Declares the Pod's serviceAccount.
*/}}
{{- define "varnish.podServiceAccount" }}
serviceAccountName: {{ include "varnish.serviceAccountName" . }}
{{- end }}

{{/*
Declares the Pod's securityContext.
*/}}
{{- define "varnish.podSecurityContext" }}
{{- if not (empty .Values.global.podSecurityContext) }}
securityContext:
  {{- toYaml .Values.global.podSecurityContext | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Sets up Pod labels
*/}}
{{- define "varnish.podLabels" }}
{{- $section := default "server" .section }}
{{- $nameSuffix := .nameSuffix }}
{{- if not (eq $nameSuffix "") }}
{{- $nameSuffix = .section }}
{{- end }}
{{- $defaultLabel := (fromYaml (include "varnish.selectorLabels" (merge (dict "nameSuffix" $nameSuffix) .))) }}
{{- $extraLabels := default dict .extraLabels }}
{{- include "varnish.toYamlField"
  (merge
    (dict
      "section" $section
      "fieldName" "labels"
      "fieldKey" "podLabels"
      "extraFieldValues" (merge $extraLabels $defaultLabel))
    .) }}
{{- end }}

{{/*
Declares the Varnish deployment strategy
*/}}
{{- define "varnish.strategy" -}}
{{- if .Values.server.strategy }}
{{- $tp := kindOf .Values.server.strategy }}
strategy:
{{- if eq $tp "string" }}
  {{- tpl .Values.server.strategy . | trim | nindent 2 }}
{{- else }}
  {{- toYaml .Values.server.strategy | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Declares the Varnish DaemonSet and StatefulSet updateStrategy
*/}}
{{- define "varnish.updateStrategy" -}}
{{- if .Values.server.updateStrategy }}
{{- $tp := kindOf .Values.server.updateStrategy }}
updateStrategy:
{{- if eq $tp "string" }}
  {{- tpl .Values.server.updateStrategy . | trim | nindent 2 }}
{{- else }}
  {{- toYaml .Values.server.updateStrategy | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Sets up nodeSelector depending on whether a YAML map or a string is given.
*/}}
{{- define "varnish.nodeSelector" -}}
{{- if .Values.server.nodeSelector }}
nodeSelector:
  {{- $tp := kindOf .Values.server.nodeSelector }}
  {{- if eq $tp "string" }}
    {{- tpl .Values.server.nodeSelector . | trim | nindent 2 }}
  {{- else }}
    {{- toYaml .Values.server.nodeSelector | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Declares the container securityContext.
*/}}
{{- define "varnish.securityContext" }}
{{- include "varnish.toYamlField"
  (merge
    (dict
      "section" .section
      "fieldName" "securityContext")
    .) }}
{{- end }}

{{/*
Declares the container resource.
*/}}
{{- define "varnish.resources" }}
{{- include "varnish.toYamlField"
  (merge
    (dict
      "section" .section
      "fieldName" "resources")
    .) }}
{{- end }}
