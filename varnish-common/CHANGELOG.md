# Changelog

`varnish-cache` and `varnish-enterprise` are released together, with the same version. This file covers both charts; entries marked (Enterprise) only apply to `varnish-enterprise`.

## 2.0.0

Values are now validated against `values.schema.json`, and unknown keys are rejected. Remove the keys listed under "Removed" from your values before upgrading.

### Removed

- `server.vclConfigs.<file>` → `server.vcls.includes.<file>`, mounted at `/etc/varnish/vcls/<file>`; load it from `server.vclConfig` with `include "./vcls/<file>";`. A `server.vclConfigs` entry named after the main VCL (`default.vcl`) → `server.vclConfig`.
- `server.vclConfigPath` → none, the main VCL is always `/etc/varnish/default.vcl`.
- `server.vclConfigFile: files/x.vcl` → `helm ... --set-file server.vclConfig=x.vcl`.
- `server.tls.configFile: files/x.cfg` → `helm ... --set-file server.tls.config=x.cfg`.
- (Enterprise) `server.mse4.configFile: files/x.cfg` → `helm ... --set-file server.mse4.config=x.cfg`.
- `server.cmdfileConfig`, `server.cmdfileConfigFile`, `server.cmdfileConfigPath` → `server.vcls.routes` to load one VCL per domain; there is no replacement for arbitrary CLI commands.
- `server.secret`, `server.secretFrom`, `server.secretFile` → none. An init container generates a secret per Pod at `/etc/varnish/shared/secret`, used by varnishd and, in Enterprise when `server.agent.enabled` is true, by the controller agent. Extra containers that need the varnishd CLI mount the `<release>-config-shared` volume at `/etc/varnish/shared` and run `varnishadm -T 127.0.0.1:6082 -S /etc/varnish/shared/secret`.
- `server.admin.address`, `server.admin.port` → none, the admin interface always listens on `127.0.0.1:6082`.
- `server.workDir` → none, varnishd runs without `-n` and uses its default `/var/lib/varnish/<Pod hostname>`. Tools in the Pod (`kubectl exec`, extra containers mounting the `<release>-varnish-vsm` volume at `/var/lib/varnish`) need no `-n`.
- (Enterprise) `server.mse4.persistence.mountPath` → none, the MSE4 volume is always mounted at `/var/lib/mse4`; use that path in `server.mse4.config`.
- `server.ttl: N` → `server.parameters.defaultTtl: N`.
- `server.threadTimeout: N` → `server.parameters.threadPoolTimeout: N`.
- `server.delayedHaltSeconds: N` → `server.delayedShutdown` with `method: sleep` and `sleep.seconds: N`, plus `server.terminationGracePeriodSeconds` (previously defaulted to N + 60).
- `server.service.http.enabled`, `server.service.https.enabled` → none, the Service exposes `http` if and only if `server.http.enabled` is true, and `https` if and only if `server.tls.enabled` is true.
- `server.varnishncsa.image` → none, varnishncsa always runs `server.image`, as it must match the varnishd version.
- `server.varnishncsa.securityContext` → none, the varnishncsa container gets `global.securityContext`.
- `server.varnishncsa.startupProbe`, `server.varnishncsa.readinessProbe`, `server.varnishncsa.livenessProbe` → none, the varnishncsa container has no probes. They ran a separate `varnishncsa -d -t3`, which only checked that the varnishd shared memory log was readable, not that the logging varnishncsa process was healthy; a varnishncsa that exits is still restarted by Kubernetes.
- `server.otel.image` → none, the OTEL sidecar always runs `server.image`, like varnishncsa. To run `varnish-otel` from another image, add a container to `server.extraContainers`.
- (Enterprise) `server.initAgent` → none, there is no `init-agent` init container. varnishd always loads `/var/lib/varnish-controller/varnish-controller-agent/$(VARNISH_CONTROLLER_AGENT_NAME)/cmds.cli`, as it did with `server.initAgent.enabled: false`. The `/etc/varnish/shared/agent` link no longer exists; read `/var/lib/varnish-controller/varnish-controller-agent/<Pod name>/` instead.
- (Enterprise) `global.initContainer` → none, it only set the image of the `init-agent` container. It is now ignored rather than rejected, since `global` accepts keys from parent charts.
- `server.labels`, `server.annotations` → `global.labels`, `global.annotations`. They apply to the same Deployment, StatefulSet or DaemonSet.
- `server.podLabels`, `server.podAnnotations` → `global.podLabels`, `global.podAnnotations`.
- (Enterprise) `server.agent.logLevel` → `server.agent.extraEnvs` with `VARNISH_CONTROLLER_LOG`. The chart no longer sets it, so the agent uses its own default instead of `debug`; set `VARNISH_CONTROLLER_LOG: debug` to keep the old level.
- (Enterprise) `server.agent.tags: [a, b]` → `server.agent.extraEnvs` with `VARNISH_CONTROLLER_TAGS: a,b`.
- (Enterprise) `server.agent.location.latitude`, `server.agent.location.longitude` → `server.agent.extraEnvs` with `VARNISH_CONTROLLER_LATITUDE`, `VARNISH_CONTROLLER_LONGITUDE`.
- (Enterprise) `server.agent.privateToken` → `server.agent.extraEnvs` with `VARNISH_CONTROLLER_PRIVATE_TOKEN`, preferably read from a Secret with `valueFrom.secretKeyRef`.
- (Enterprise) `server.agent.useReleaseName` → none, the agent name is always the Pod name. An agent that was registered under the release name shows up as a new agent.
- (Enterprise) `server.agent.autoRemove.vcli.internal.namespace`, `releaseName`, `clusterDomain` → `global.natsServer.internal.namespace`, `releaseName`, `clusterDomain`. The VCLI container now finds the APIGW with the same values the agent uses for NATS, so the APIGW and NATS can no longer be in different releases or namespaces.
- (Enterprise) `server.mse4.memoryTarget: X` → `server.parameters.memoryTarget: X`, which renders as `-p memory_target=X`.

### Changed

- `server.minThreads` and `server.maxThreads` are now passed as `-p thread_pool_min` then `-p thread_pool_max`, before `server.parameters`. Setting `threadPoolMin` or `threadPoolMax` in `server.parameters` now fails rendering; use `server.minThreads` and `server.maxThreads` instead.
- (Enterprise) `server.agent.persistence.enabled` is ignored when `server.agent.enabled` is false: a StatefulSet no longer gets the agent PersistentVolumeClaim, and a Deployment or DaemonSet no longer fails rendering. Since `volumeClaimTemplates` can't change on an existing StatefulSet, turning the agent on or off with persistence enabled now requires deleting the StatefulSet (`kubectl delete statefulset --cascade=orphan`) before upgrading.
- The varnish container no longer gets the `VARNISH_TLS_CFG` environment variable, and in Enterprise no longer gets `MSE4_CONFIG`, `VARNISH_STORAGE_BACKEND` or `MSE_MEMORY_TARGET`. The chart sets the varnishd command line itself, with the TLS and MSE4 settings as arguments, so these variables had no effect. Set them in `server.extraEnvs` if your own scripts need them.
- `server.terminationGracePeriodSeconds` defaults to null instead of `0`, and `0` is now rendered. Before, `0` meant unset; set `null` to keep the Kubernetes default (30 seconds).
- Rendering fails when `server.delayedShutdown.method` is not `none` and `server.terminationGracePeriodSeconds` is unset or shorter than the delay: `sleep.seconds` for `sleep`, `mempool.waitSeconds` for `mempool`, `shutdownDelay.seconds` for `shutdown_delay`. Set the grace period above the delay.
- Varnish Cache: `server.autoscaling.minReplicas` defaults to `"-"` instead of `1`, so the HorizontalPodAutoscaler uses `server.replicas` as its minimum, like Varnish Enterprise. Set `minReplicas: 1` to keep the old minimum.
- Varnish Cache: `server.service.internalTrafficPolicy` defaults to `""` instead of `Cluster`, like Varnish Enterprise. The field is no longer rendered, and Kubernetes applies its default, `Cluster`.
- `server.varnishncsa.extraArgs` defaults to `[]` instead of `["-c"]`. varnishncsa logs client requests by default, so the output is the same.
- `server.service.externalTrafficPolicy` is only rendered when `server.service.type` is `NodePort` or `LoadBalancer`. The API server rejects it for other types.
- A `tcpSocket` handler in `server.startupProbe`, `server.readinessProbe` or `server.livenessProbe` is rendered as given. Before, its port was replaced with `server.http.port`; leave `tcpSocket` out to keep that.

### Fixed

- (Enterprise) On a Deployment or DaemonSet, `server.agent.persistence.enableWithVolumeName` now overrides `server.agent.persistence.enabled`, as on a StatefulSet. Before, rendering failed when both were set.
- (Enterprise) The `mse4-config` init container gets `server.securityContext` and `server.resources`, merged with `global.securityContext` and `global.resources`, like the secret init container.
- An `exec` or `grpc` handler in `server.startupProbe`, `server.readinessProbe` or `server.livenessProbe` is rendered as given, and no longer needs `server.http.enabled`. Before, the chart added a `tcpSocket` handler next to it, and the API server rejected the probe.
- An entry of `server.extraListens` with `path` and no `port` no longer gets a container port without a number, which the API server rejected.
