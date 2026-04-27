{{/*
Pod template (metadata + spec).
Caller is responsible for indenting the result (e.g. `nindent 4` to embed it
under `spec.template`).
*/}}
{{- define "orca.podTemplate" -}}
{{- $cfg := include "orca.config" . | fromYaml -}}
metadata:
  {{- with .Values.podAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  labels:
    {{- include "helm.labels" . | nindent 4 }}
    {{- with .Values.podLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- with .Values.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  serviceAccountName: {{ include "helm.serviceAccountName" . }}
  securityContext:
    {{- toYaml .Values.podSecurityContext | nindent 4 }}
  containers:
    - name: {{ .Chart.Name }}
      securityContext:
        {{- toYaml .Values.securityContext | nindent 8 }}
      image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      command: ["/usr/bin/varnish-supervisor","--config","/etc/varnish-supervisor/config.yaml"]
      ports:
        {{- $httpPorts := .Values.orca.varnish.http }}
        {{- $numHttpPorts := len $httpPorts }}
        {{- range $index, $portConfig := $httpPorts }}
        - name: {{- if eq $numHttpPorts 1 }} http {{- else }} http-{{ $portConfig.port }} {{- end }}
          containerPort: {{ $portConfig.port | default 80 }}
          protocol: TCP
        {{- end }}
        {{- if .Values.orca.varnish.https }}
        {{- $httpsPorts := .Values.orca.varnish.https }}
        {{- $numHttpsPorts := len $httpsPorts }}
        {{- range $index, $portConfig := $httpsPorts }}
        - name: {{- if eq $numHttpsPorts 1 }} https {{- else }} https-{{ $portConfig.port }} {{- end }}
          containerPort: {{ $portConfig.port | default 443 }}
          protocol: TCP
        {{- end }}
        {{- end }}
      resources:
        {{- toYaml .Values.resources | nindent 8 }}
      {{- if and .Values.extraEnvs (not (empty .Values.extraEnvs)) }}
      env:
        {{- include "orca.toEnv" (merge (dict "envs" .Values.extraEnvs) .) | nindent 8 }}
      {{- end }}
      volumeMounts:
      - name: orca-config
        mountPath: /etc/varnish-supervisor/config.yaml
        subPath: config.yaml
      {{- if and (not (empty $cfg.license.secret)) (not (empty $cfg.license.file)) }}
      - name: orca-license
        readOnly: true
        mountPath: "{{ $cfg.license.file }}"
        subPath: "{{ base $cfg.license.file }}"
      {{- end }}
      {{- range $httpId, $https := $cfg.varnish.https -}}
        {{- range $certId, $cert := $https.certificates -}}
          {{- if not (empty $cert.cert) }}
      - name: orca-https-{{ $httpId }}-cert-{{ $certId }}
        readOnly: true
        mountPath: "{{ $cert.cert }}"
        subPath: "{{ base $cert.cert }}"
          {{- end -}}
          {{- if not (empty $cert.cert) }}
      - name: orca-https-{{ $httpId }}-private-key-{{ $certId }}
        readOnly: true
        mountPath: "{{ $cert.private_key }}"
        subPath: "{{ base $cert.private_key }}"
          {{- end -}}
        {{- end -}}
      {{- end }}
      {{- with .Values.volumeMounts }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
  volumes:
  - name: orca-config
    configMap:
      name: {{ include "helm.fullname" . }}-orca-config
  {{- if and (not (empty $cfg.license.secret)) (not (empty $cfg.license.file)) }}
  - name: orca-license
    secret:
      secretName: {{ $cfg.license.secret }}
      items:
      - key: license.lic
        path: {{ base $cfg.license.file }}
  {{- end }}
  {{- range $httpId, $https := $cfg.varnish.https -}}
    {{- range $certId, $cert := $https.certificates -}}
      {{- if not (empty $cert.secret) }}
  - name: orca-https-{{ $httpId }}-cert-{{ $certId }}
    secret:
      secretName: {{ $cert.secret }}
      items:
      - key: tls.crt
        path: {{ base $cert.cert }}
  - name: orca-https-{{ $httpId }}-private-key-{{ $certId }}
    secret:
      secretName: {{ $cert.secret }}
      items:
      - key: tls.key
        path: {{ base $cert.private_key }}
      {{- end -}}
    {{- end -}}
  {{- end }}
  {{- with .Values.volumes }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- with .Values.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
