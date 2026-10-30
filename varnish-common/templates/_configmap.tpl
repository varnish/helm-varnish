{{- define "varnish.msePersistenceConfig" -}}
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
{{- $reqSize := include "varnish.sizeStrToNumber" (merge (dict "sizeStr" $reqSizeStr)) -}}
{{- $bookSize := include "varnish.sizeStrPercentToNumber" (merge (dict "sizeStr" $bookSizeStr "baseSize" $reqSize)) -}}
{{- $storeSize := include "varnish.sizeStrPercentToNumber" (merge (dict "sizeStr" $storeSizeStr "baseSize" $reqSize)) -}}
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

{{- define "varnish.mseConfig" -}}
{{- if include "varnish.mseEnabled" . }}
{{- if (not (eq .Values.server.mse.configFile "")) -}}
{{- $mseConfigFile := (.Files.Get .Values.server.mse.configFile) }}
{{- if (eq $mseConfigFile "") }}
{{ fail "'server.mse.configFile' was set but the file was empty or not found" }}
{{- end }}
{{- tpl $mseConfigFile . }}
{{- else if (not (eq .Values.server.mse.config "")) -}}
{{- tpl .Values.server.mse.config . }}
{{- else if .Values.server.mse.persistence.enabled }}
{{- include "varnish.msePersistenceConfig" . }}
{{- end }}
{{- end }}
{{- end }}

{{- define "varnish.mse4PersistenceConfig" -}}
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
{{- $reqSize := include "varnish.sizeStrToNumber" (merge (dict "sizeStr" $reqSizeStr)) -}}
{{- $bookSize := include "varnish.sizeStrPercentToNumber" (merge (dict "sizeStr" $bookSizeStr "baseSize" $reqSize)) -}}
{{- $storeSize := include "varnish.sizeStrPercentToNumber" (merge (dict "sizeStr" $storeSizeStr "baseSize" $reqSize)) -}}
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

{{- define "varnish.mse4Config" -}}
{{- if include "varnish.mse4Enabled" . }}
{{- if (not (eq .Values.server.mse4.configFile "")) -}}
{{- $mse4ConfigFile := (.Files.Get .Values.server.mse4.configFile) }}
{{- if (eq $mse4ConfigFile "") }}
{{ fail "'server.mse4.configFile' was set but the file was empty or not found" }}
{{- end }}
{{- tpl $mse4ConfigFile . }}
{{- else if (not (eq .Values.server.mse4.config "")) -}}
{{- tpl .Values.server.mse4.config . }}
{{- else if .Values.server.mse4.persistence.enabled }}
{{- include "varnish.mse4PersistenceConfig" . }}
{{- end }}
{{- end }}
{{- end }}

{{- define "varnish.tlsConfig" -}}
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

{{- define "varnish.vclConfig" -}}
{{- include "varnish.vclBundleConflictCheck" . }}
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

{{/*
Normalizes a route object's name for use as a VCL filename and Varnish label.
Takes a route object as context. Replaces non-alphanumeric characters with underscores.
*/}}
{{- define "varnish.vclBundleK8sName" -}}
{{- $s := regexReplaceAll "[^a-z0-9]" (. | lower) "-" -}}
{{- regexReplaceAll "^-+|-+$" $s "" -}}
{{- end -}}

{{- define "varnish.vclBundleNormalizeName" -}}
{{- if .name -}}
{{- if regexMatch "(^/)|(^\\.\\./)|(/\\.\\.)" .name -}}
{{- fail (printf "server.vcls.routes: name '%s' contains path traversal sequence" .name) -}}
{{- end -}}
{{- regexReplaceAll "[^a-zA-Z0-9]" .name "_" -}}
{{- else if .hostnames -}}
{{- regexReplaceAll "[^a-zA-Z0-9]" (first .hostnames) "_" -}}
{{- else -}}
any
{{- end -}}
{{- end -}}

{{/*
Fails if server.vcls.routes conflicts with legacy VCL or cmdfile config settings.
*/}}
{{- define "varnish.vclBundleConflictCheck" -}}
  {{- if empty .Values.server.vcls.routes -}}
    {{- if not (empty .Values.server.vcls.includes) -}}
      {{- fail "'server.vcls.includes' requires 'server.vcls.routes' to be set" -}}
    {{- end -}}
  {{- else -}}
    {{- if (include "varnish.agentEnabled" .) -}}
      {{- fail "Cannot use both 'server.vcls.routes' and 'server.agent.enabled'" -}}
    {{- end -}}
    {{- if not (eq .Values.server.vclConfigPath "/etc/varnish/default.vcl") -}}
      {{- fail "Cannot use both 'server.vcls.routes' and 'server.vclConfigPath'" -}}
    {{- end -}}
    {{- if not (eq .Values.server.vclConfig "") -}}
      {{- fail "Cannot use both 'server.vcls.routes' and 'server.vclConfig'" -}}
    {{- end -}}
    {{- if not (eq .Values.server.vclConfigFile "") -}}
      {{- fail "Cannot use both 'server.vcls.routes' and 'server.vclConfigFile'" -}}
    {{- end -}}
    {{- if not (empty .Values.server.vclConfigs) -}}
      {{- fail "Cannot use both 'server.vcls.routes' and 'server.vclConfigs'" -}}
    {{- end -}}
    {{- if not (eq (include "varnish.cmdfileConfig" .) "") -}}
      {{- fail "Cannot use both 'server.vcls.routes' and 'server.cmdfileConfig'/'server.cmdfileConfigFile'" -}}
    {{- end -}}
    {{- if not (eq .Values.server.cmdfileConfigPath "/etc/varnish/cmds.cli") -}}
      {{- fail "Cannot customize 'server.cmdfileConfigPath' when 'server.vcls.routes' is set" -}}
    {{- end -}}
    {{- $routerVolName := printf "%s-config-vcl-bundle-router" $.Release.Name -}}
    {{- if gt (len $routerVolName) 63 -}}
      {{- fail (printf "server.vcls.routes: volume name '%s' exceeds 63 characters, use a shorter release name" $routerVolName) -}}
    {{- end -}}
    {{- $seen := dict -}}
    {{- $seenK8s := dict -}}
    {{- $seenMountPaths := dict "router.vcl" "reserved" "cmds.cli" "reserved" -}}
    {{- $catchAllSeen := false -}}
    {{- range .Values.server.vcls.routes -}}
      {{- if $catchAllSeen -}}
        {{- fail "server.vcls.routes: catch-all route (no hostnames) must be the last route" -}}
      {{- end -}}
      {{- if empty .hostnames -}}
        {{- $catchAllSeen = true -}}
      {{- end -}}
      {{- $name := include "varnish.vclBundleNormalizeName" . -}}
      {{- if hasKey $seen $name -}}
        {{- fail (printf "server.vcls.routes: duplicate normalized name '%s' — routes must produce unique names" $name) -}}
      {{- end -}}
      {{- $_ := set $seen $name true -}}
      {{- $k8sName := include "varnish.vclBundleK8sName" $name -}}
      {{- if eq $k8sName "" -}}
        {{- fail (printf "server.vcls.routes: name '%s' produces an empty k8s name" $name) -}}
      {{- end -}}
      {{- $volName := printf "%s-config-vcl-bundle-%s" $.Release.Name $k8sName -}}
      {{- if gt (len $volName) 63 -}}
        {{- fail (printf "server.vcls.routes: volume name '%s' exceeds 63 characters, shorten the route name or set 'name'" $volName) -}}
      {{- end -}}
      {{- if has $k8sName (list "router" "cmds") -}}
        {{- fail (printf "server.vcls.routes: k8s name '%s' is reserved for the built-in router and cmds ConfigMaps" $k8sName) -}}
      {{- end -}}
      {{- if hasKey $seenK8s $k8sName -}}
        {{- fail (printf "server.vcls.routes: duplicate k8s name '%s' — routes must produce unique k8s-safe names" $k8sName) -}}
      {{- end -}}
      {{- $_ := set $seenK8s $k8sName true -}}
      {{- $_ := set $seenMountPaths (printf "%s.vcl" $name) "route" -}}
    {{- end -}}
    {{- $seenIncludeK8s := dict -}}
    {{- range $filename, $_ := .Values.server.vcls.includes -}}
      {{- if regexMatch "(^/)|(^\\.\\./)|(/\\.\\.)" $filename -}}
        {{- fail (printf "server.vcls.includes: filename '%s' contains path traversal sequence" $filename) -}}
      {{- end -}}
      {{- $k8sName := include "varnish.vclBundleK8sName" $filename -}}
      {{- if eq $k8sName "" -}}
        {{- fail (printf "server.vcls.includes: filename '%s' produces an empty k8s name" $filename) -}}
      {{- end -}}
      {{- $volName := printf "%s-config-vcl-bundle-include-%s" $.Release.Name $k8sName -}}
      {{- if gt (len $volName) 63 -}}
        {{- fail (printf "server.vcls.includes: volume name '%s' exceeds 63 characters, shorten the filename" $volName) -}}
      {{- end -}}
      {{- if hasKey $seenIncludeK8s $k8sName -}}
        {{- fail (printf "server.vcls.includes: duplicate k8s name '%s' — include filenames must produce unique k8s-safe names" $k8sName) -}}
      {{- end -}}
      {{- $_ := set $seenIncludeK8s $k8sName true -}}
      {{- if hasKey $seenK8s (printf "include-%s" $k8sName) -}}
        {{- fail (printf "server.vcls.includes: filename '%s' collides with the k8s name of route 'include-%s'" $filename $k8sName) -}}
      {{- end -}}
      {{- if hasKey $seenMountPaths $filename -}}
        {{- fail (printf "server.vcls.includes: filename '%s' collides with a route mounted at the same path" $filename) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

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
