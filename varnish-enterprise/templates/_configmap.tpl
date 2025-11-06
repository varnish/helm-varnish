{{- define "varnish-enterprise.msePersistenceConfig" -}}
{{- $reqSizeStr := .Values.server.mse.persistence.storageSize }}
{{- $bookSizeStr := .Values.server.mse.persistence.bookSize }}
{{- $storeSizeStr := .Values.server.mse.persistence.storeSize }}
{{- if not $reqSizeStr -}}
{{- fail "Storage size must be set in values to configure MSE persistence: 'server.mse.persistence.storageSize'" -}}
{{- else if not $bookSizeStr -}}
{{- fail "Book size must be set in values to configure MSE persistence: 'server.mse.persistence.bookSize'" -}}
{{- else if not $storeSizeStr -}}
{{- fail "Store size must be set in values to configure MSE persistence: 'server.mse.persistence.storeSize'" -}}
{{- end -}}
{{- $reqSize := include "varnish-enterprise.sizeStrToNumber" (merge (dict "sizeStr" $reqSizeStr)) -}}
{{- $bookSize := include "varnish-enterprise.sizeStrPercentToNumber" (merge (dict "sizeStr" $bookSizeStr "baseSize" $reqSize)) -}}
{{- $storeSize := include "varnish-enterprise.sizeStrPercentToNumber" (merge (dict "sizeStr" $storeSizeStr "baseSize" $reqSize)) -}}
{{- if gt (add $bookSize $storeSize) (atoi $reqSize) -}}
{{- fail (printf "'server.mse.persistence.bookSize' and 'server.mse.persistence.storeSize' cannot exceed 'server.mse.persistence.storageSize' (%s + %s > %s)" $bookSize $storeSize $reqSize) -}}
{{- end -}}
env: {
  id = "mse";
  memcache_size = "auto";

  books = ( {
    id = "book";
    directory = "{{ .Values.server.mse.persistence.mountPath }}/book";
    database_size = "{{ $bookSize }}";

    stores = ( {
      id = "store";
      filename = "{{ .Values.server.mse.persistence.mountPath }}/store.dat";
      size = "{{ $storeSize }}";
    } );
  } );
};
{{- end }}

{{- define "varnish-enterprise.mseConfig" -}}
{{- if or (and (eq (kindOf .Values.server.mse.enabled) "bool") .Values.server.mse.enabled) (and (eq (kindOf .Values.server.mse.enabled) "string") (eq .Values.server.mse.enabled "-") (not .Values.server.mse4.enabled)) }}
{{- if (not (eq .Values.server.mse.configFile "")) -}}
{{- $mseConfigFile := (.Files.Get .Values.server.mse.configFile) }}
{{- if (eq $mseConfigFile "") }}
{{ fail "'server.mse.configFile' was set but the file was empty or not found" }}
{{- end }}
{{- tpl $mseConfigFile . }}
{{- else if (not (eq .Values.server.mse.config "")) -}}
{{- tpl .Values.server.mse.config . }}
{{- else if .Values.server.mse.persistence.enabled }}
{{- include "varnish-enterprise.msePersistenceConfig" . }}
{{- end }}
{{- end }}
{{- end }}

{{- define "varnish-enterprise.mse4PersistenceConfig" -}}
{{- $reqSizeStr := .Values.server.mse4.persistence.storageSize }}
{{- $bookSizeStr := .Values.server.mse4.persistence.bookSize }}
{{- $storeSizeStr := .Values.server.mse4.persistence.storeSize }}
{{- if not $reqSizeStr -}}
{{- fail "Storage size must be set in values to configure MSE4 persistence: 'server.mse4.persistence.storageSize'" -}}
{{- else if not $bookSizeStr -}}
{{- fail "Book size must be set in values to configure MSE4 persistence: 'server.mse4.persistence.bookSize'" -}}
{{- else if not $storeSizeStr -}}
{{- fail "Store size must be set in values to configure MSE4 persistence: 'server.mse4.persistence.storeSize'" -}}
{{- end -}}
{{- $reqSize := include "varnish-enterprise.sizeStrToNumber" (merge (dict "sizeStr" $reqSizeStr)) -}}
{{- $bookSize := include "varnish-enterprise.sizeStrPercentToNumber" (merge (dict "sizeStr" $bookSizeStr "baseSize" $reqSize)) -}}
{{- $storeSize := include "varnish-enterprise.sizeStrPercentToNumber" (merge (dict "sizeStr" $storeSizeStr "baseSize" $reqSize)) -}}
{{- if gt (add $bookSize $storeSize) (atoi $reqSize) -}}
{{- fail (printf "'server.mse4.persistence.bookSize' and 'server.mse4.persistence.storeSize' cannot exceed 'server.mse4.persistence.storageSize' (%s + %s > %s)" $bookSize $storeSize $reqSize) -}}
{{- end -}}
env: {
  books = ( {
    id = "book";
    filename = "{{ .Values.server.mse4.persistence.mountPath }}/book";
    size = "{{ $bookSize }}";

    stores = ( {
      id = "store";
      filename = "{{ .Values.server.mse4.persistence.mountPath }}/store";
      size = "{{ $storeSize }}";
    } );
  } );
};
{{- end }}

{{- define "varnish-enterprise.mse4Config" -}}
{{- if .Values.server.mse4.enabled }}
{{- if (not (eq .Values.server.mse4.configFile "")) -}}
{{- $mse4ConfigFile := (.Files.Get .Values.server.mse4.configFile) }}
{{- if (eq $mse4ConfigFile "") }}
{{ fail "'server.mse4.configFile' was set but the file was empty or not found" }}
{{- end }}
{{- tpl $mse4ConfigFile . }}
{{- else if (not (eq .Values.server.mse4.config "")) -}}
{{- tpl .Values.server.mse4.config . }}
{{- else if .Values.server.mse4.persistence.enabled }}
{{- include "varnish-enterprise.mse4PersistenceConfig" . }}
{{- end }}
{{- end }}
{{- end }}

{{- define "varnish-enterprise.tlsConfig" -}}
{{- if (not (eq .Values.server.tls.configFile "")) -}}
{{- $tlsConfigFile := (.Files.Get .Values.server.tls.configFile) }}
{{- if (eq $tlsConfigFile "") }}
{{ fail "'server.tls.configFile' was set but the file was empty or not found" }}
{{- end }}
{{- tpl $tlsConfigFile . }}
{{- else if (not (eq .Values.server.tls.config "")) -}}
{{- tpl .Values.server.tls.config . }}
{{- end }}
{{- end }}

{{- define "varnish-enterprise.vclConfig" -}}
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

{{- define "varnish-enterprise.cmdfileConfig" -}}
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

{{- define "varnish-enterprise.secretConfig" -}}
{{- if empty .Values.server.secretFrom }}
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
{{- end }}
