{{- define "varnish.vclConfig" -}}
{{- $defaultVcl := osBase .Values.server.vclConfigPath }}
{{- if and (hasKey .Values.server.vclConfigs $defaultVcl) (not (eq (get .Values.server.vclConfigs $defaultVcl) "")) }}
{{- if (not (eq .Values.server.vclConfig "")) }}
{{ fail (print "Cannot enable both 'server.vclConfigs.\"" $defaultVcl "\"' and 'server.vclConfig'") }}
{{- end }}
{{- if (not (eq .Values.server.vclConfigFile "")) }}
{{ fail (print "Cannot enable both 'server.vclConfigs.\"" $defaultVcl "\"' and 'server.vclConfigFile'") }}
{{- end }}
{{- tpl (get .Values.server.vclConfigs $defaultVcl) . }}
{{- else if (not (eq .Values.server.vclConfigFile "")) -}}
{{- $vclConfigFile := (.Files.Get .Values.server.vclConfigFile) }}
{{- if (eq $vclConfigFile "") }}
{{ fail "'server.vclConfigFile' was set but the file was empty or not found" }}
{{- end }}
{{- tpl $vclConfigFile . }}
{{- else if (not (eq .Values.server.vclConfig "")) }}
{{- tpl .Values.server.vclConfig . }}
{{- end }}
{{- end }}

{{- define "varnish.cmdfileConfig" -}}
{{- if (not (eq .Values.server.cmdfileConfigFile "")) -}}
{{- $cmdfileConfigFile := (.Files.Get .Values.server.cmdfileConfigFile) }}
{{- if (eq $cmdfileConfigFile "") }}
{{ fail "'server.cmdfileConfigFile' was set but the file was empty or not found" }}
{{- end }}
{{- tpl $cmdfileConfigFile . }}
{{- else if (not (eq .Values.server.cmdfileConfig "")) }}
{{- tpl .Values.server.cmdfileConfig . }}
{{- end }}
{{- end }}

{{- define "varnish.secretConfig" -}}
{{- if (not (eq .Values.server.secretFile "")) -}}
{{- $secretFile := (.Files.Get .Values.server.secretFile) }}
{{- if (eq $secretFile "") }}
{{ fail "'server.secretFile' was set but the file was empty or not found" }}
{{- end }}
{{- tpl $secretFile . }}
{{- else if (not (eq .Values.server.secret "")) }}
{{- tpl .Values.server.secret . }}
{{- end }}
{{- end }}
