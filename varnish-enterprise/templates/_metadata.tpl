{{/* vim: set filetype=mustache: */}}

{{/*
Common labels
*/}}
{{- define "varnish-enterprise.labels" -}}
helm.sh/chart: {{ include "varnish-enterprise.chart" . }}
{{ include "varnish-enterprise.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "varnish-enterprise.selectorLabels" -}}
app.kubernetes.io/name: {{ include "varnish-enterprise.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "varnish-enterprise.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "varnish-enterprise.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Sets up the common server extra annotations
*/}}
{{- define "varnish-enterprise.serverAnnotations" -}}
{{- $section := default "server" .section }}
{{- include "varnish-enterprise.toYamlField"
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
{{- define "varnish-enterprise.serverLabels" -}}
{{- $section := default "server" .section }}
{{- $nameSuffix := .nameSuffix }}
{{- if not (eq $nameSuffix "") }}
{{- $nameSuffix = .section }}
{{- end }}
{{- $defaultLabel := (fromYaml (include "varnish-enterprise.labels" (merge (dict "nameSuffix" $nameSuffix) .))) }}
{{- $extraLabels := default dict .extraLabels }}
{{- include "varnish-enterprise.toYamlField"
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
{{- define "varnish-enterprise.serviceAnnotations" -}}
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
{{- define "varnish-enterprise.serviceLabels" -}}
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
{{- define "varnish-enterprise.ingressAnnotations" -}}
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
{{- define "varnish-enterprise.ingressLabels" -}}
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
{{- define "varnish-enterprise.mseAnnotations" -}}
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
{{- define "varnish-enterprise.msePvcLabels" -}}
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
{{- define "varnish-enterprise.mse4Annotations" -}}
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
{{- define "varnish-enterprise.mse4PvcLabels" -}}
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
{{- define "varnish-enterprise.agentPvcLabels" -}}
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
{{- define "varnish-enterprise.serviceAccountAnnotations" -}}
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
{{- define "varnish-enterprise.serviceAccountLabels" -}}
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
{{- define "varnish-enterprise.podServiceAccount" }}
serviceAccountName: {{ include "varnish-enterprise.serviceAccountName" . }}
{{- end }}

{{/*
Declares the Pod's securityContext.
*/}}
{{- define "varnish-enterprise.podSecurityContext" }}
{{- if not (empty .Values.global.podSecurityContext) }}
securityContext:
  {{- toYaml .Values.global.podSecurityContext | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Sets up Pod labels
*/}}
{{- define "varnish-enterprise.podLabels" }}
{{- $section := default "server" .section }}
{{- $nameSuffix := .nameSuffix }}
{{- if not (eq $nameSuffix "") }}
{{- $nameSuffix = .section }}
{{- end }}
{{- $defaultLabel := (fromYaml (include "varnish-enterprise.selectorLabels" (merge (dict "nameSuffix" $nameSuffix) .))) }}
{{- $extraLabels := default dict .extraLabels }}
{{- include "varnish-enterprise.toYamlField"
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
{{- define "varnish-enterprise.strategy" -}}
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
{{- define "varnish-enterprise.updateStrategy" -}}
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
{{- define "varnish-enterprise.nodeSelector" -}}
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
{{- define "varnish-enterprise.securityContext" }}
{{- include "varnish-enterprise.toYamlField"
  (merge
    (dict
      "section" .section
      "fieldName" "securityContext")
    .) }}
{{- end }}

{{/*
Declares the container resource.
*/}}
{{- define "varnish-enterprise.resources" }}
{{- include "varnish-enterprise.toYamlField"
  (merge
    (dict
      "section" .section
      "fieldName" "resources")
    .) }}
{{- end }}
