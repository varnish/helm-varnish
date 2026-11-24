# varnish-enterprise

Please see https://docs.varnish-software.com/varnish-helm/varnish-enterprise/ for documentation.

See [VALUES.md](VALUES.md) for the configuration values of the chart.

## Upgrading to 2.0.0

The following values were removed. As unknown keys are rejected by `values.schema.json`, remove them from your values before upgrading:

- `server.vclConfigs.<file>` → `server.vcls.includes.<file>`, mounted at `/etc/varnish/vcls/<file>`; load it from `server.vclConfig` with `include "./vcls/<file>";`. A `server.vclConfigs` entry named after the main VCL (`default.vcl`) → `server.vclConfig`.
- `server.vclConfigPath` → none, the main VCL is always `/etc/varnish/default.vcl`.
- `server.vclConfigFile: files/x.vcl` → `helm ... --set-file server.vclConfig=x.vcl`.
- `server.tls.configFile: files/x.cfg` → `helm ... --set-file server.tls.config=x.cfg`.
- `server.mse4.configFile: files/x.cfg` → `helm ... --set-file server.mse4.config=x.cfg`.
- `server.cmdfileConfig`, `server.cmdfileConfigFile`, `server.cmdfileConfigPath` → `server.vcls.routes` to load one VCL per domain; there is no replacement for arbitrary CLI commands.
- `server.secret`, `server.secretFrom`, `server.secretFile` → none. An init container generates a secret per Pod at `/etc/varnish/shared/secret`, used by varnishd and, when `server.agent.enabled` is true, by the controller agent. Extra containers that need the varnishd CLI mount the `<release>-config-shared` volume at `/etc/varnish/shared` and run `varnishadm -T 127.0.0.1:6082 -S /etc/varnish/shared/secret`.
- `server.admin.address`, `server.admin.port` → none, the admin interface always listens on `127.0.0.1:6082`.
- `server.workDir` → none, varnishd runs without `-n` and uses its default `/var/lib/varnish/<Pod hostname>`. Tools in the Pod (`kubectl exec`, extra containers mounting the `<release>-varnish-vsm` volume at `/var/lib/varnish`) need no `-n`.
- `server.mse4.persistence.mountPath` → none, the MSE4 volume is always mounted at `/var/lib/mse4`; use that path in `server.mse4.config`.
- `server.ttl: N` → `server.parameters.defaultTtl: N`.
- `server.threadTimeout: N` → `server.parameters.threadPoolTimeout: N`.
- `server.delayedHaltSeconds: N` → `server.delayedShutdown` with `method: sleep` and `sleep.seconds: N`, plus `server.terminationGracePeriodSeconds` (previously defaulted to N + 60).
- `server.service.http.enabled`, `server.service.https.enabled` → none, the Service exposes `http` if and only if `server.http.enabled` is true, and `https` if and only if `server.tls.enabled` is true.
- `server.varnishncsa.image` → none, varnishncsa always runs `server.image`, as it must match the varnishd version.
- `server.varnishncsa.securityContext` → none, the varnishncsa container gets `global.securityContext`.
- `server.varnishncsa.startupProbe`, `server.varnishncsa.readinessProbe`, `server.varnishncsa.livenessProbe` → none, the varnishncsa container has no probes. They ran a separate `varnishncsa -d -t3`, which only checked that the varnishd shared memory log was readable, not that the logging varnishncsa process was healthy; a varnishncsa that exits is still restarted by Kubernetes.

`server.minThreads` and `server.maxThreads` are now passed as `-p thread_pool_min` then `-p thread_pool_max`, before `server.parameters`. Setting `threadPoolMin` or `threadPoolMax` in `server.parameters` now fails rendering; use `server.minThreads` and `server.maxThreads` instead.
