<!-- Generated from varnish-common/schema/values.schema.yaml by generate.py. Do not edit. -->

# Varnish Enterprise Helm chart values

## Configurations

### Chart configurations

**nameOverride**

- Type: string
- Default: name of the chart

Overrides the name of the chart (without the release name). For example, setting `nameOverride` to "hello" would produce a workload named "release-name-hello". Containers within a pod derive their name from this setting.

By default, the name of the chart is used.

**fullnameOverride**

- Type: string
- Default: composition of a release name and name of the chart

Overrides the full name of the chart (with the release name). This setting allows overriding both the release name and the workload name altogether. For example, setting `fullnameOverride` to "hello" would produce a workload named "hello".

### Global configurations

**global.imagePullSecrets**

- Type: array of objects

An array of objects that conforms to the Kubernetes [imagePullSecrets][k8s-pod-v1-containers] definition. When set, each item in an array must consist of an object with a key `name` referencing the Kubernetes secret.

For example:

```yaml
global:
  imagePullSecrets:
    - name: registry-quay-k7c2f4m2d5
```

**global.podSecurityContext**

- Type: object
- Default: `{"fsGroup": 999}`

An object that conforms to the Kubernetes [securityContext][k8s-pod-v1-pods] definition of a Pod.

This securityContext will be set on all Pods within this chart. For setting securityContext on all containers, see `global.securityContext`.

For example:

```yaml
global:
  podSecurityContext:
    fsGroup: 1000
```

**global.securityContext**

- Type: object or template string
- Default: `{"runAsUser": 999, "runAsNonRoot": true}`

An object that conforms to the Kubernetes [securityContext][k8s-pod-v1-containers] definition of a Container.

This securityContext will be set on all containers within this chart. For setting securityContext on the Pod itself, see `global.podSecurityContext`.

For example:

```yaml
global:
  securityContext:
    runAsUser: 1000
    runAsNonRoot: true
```

**global.annotations**

- Type: object or template string
- Availability: v1.5.0

Applies extra annotations to all workloads. The value can be set as either an object or a template string. Workload annotations can be used for applying additional metadata or for integrating with external tooling. The annotations specified here will be applied to the workload itself.

To apply annotations on a Pod, use `global.podAnnotations`. To apply annotations on a specific workload, use `server.annotations`.

**global.podAnnotations**

- Type: object or template string
- Availability: v1.5.0

Applies extra annotations to all Pods. The value can be set as either an object or a template string. Pod annotations can be used for applying additional metadata or for integrating with external tooling. Annotations specified here will be applied to a Pod itself.

To apply annotations on a workload, use `global.annotations`. To apply annotations on a specific Pod, use `server.podAnnotations`.

**global.labels**

- Type: object or template string
- Availability: v1.5.0

Applies extra labels to all workloads. The value can be set as either an object or a template string. Workload labels can be used for applying additional metadata or for integrating with external tooling. The labels specified here will be applied to the workload itself.

To apply labels on a Pod, use `global.podLabels`. To apply labels on a specific workload, use `server.labels`.

**global.podLabels**

- Type: object or template string
- Availability: v1.5.0

Applies extra labels to all Pods. The value can be set as either an object or a template string. Pod labels can be used for applying additional metadata or for integrating with external tooling. Labels specified here will be applied to a Pod itself.

To apply labels on a workload, use `global.labels`. To apply labels on a specific Pod, use `server.podLabels`.

**global.resources**

- Type: object or template string
- Availability: v1.5.0

An object that conforms to the Kubernetes resources definition of a Container. This configuration will apply resource constraints to all containers. To specify resources on a single container, use `server.resources`, `server.varnishncsa.resources`, and `server.otel.resources`.

For example:

```yaml
global:
  resources:
    limits:
      cpu: "100m"
      memory: "128Mi"
    requests:
      cpu: "100m"
      memory: "128Mi"
```

### Service Account configurations

**serviceAccount.create**

- Type: boolean
- Default: `true`

Create a Kubernetes service account to use with the workload.

**serviceAccount.labels**

- Type: object or template string

Applies extra labels to the service account. The value can be set as either an object or a template string.

**serviceAccount.annotations**

- Type: object or template string

Applies extra annotations to the service account. The value can be set as either an object or a template string.

**serviceAccount.name**

- Type: string

Overrides the name of the service account. By default, the full name of the chart is used when `serviceAccount.create` is `true`, and `default` otherwise.

### Server configurations

**server.replicas**

- Type: number
- Default: `1`

Specifies the number of replicas to deploy Varnish Enterprise server. The value is ignored if `server.kind` is "DaemonSet".

When `server.autoscaling.enabled` is set to `true`, and `server.autoscaling.minReplicas` is `-`, the value of `server.replicas` will be used. `server.replicas` is ignored if `server.autoscaling.minReplicas` is set to a number.

**server.kind**

- Type: string, one of `Deployment`, `DaemonSet`, or `StatefulSet`
- Default: `Deployment`

Specifies the type of workload to deploy Varnish Enterprise server. The value can be one of `Deployment`, `DaemonSet`, or `StatefulSet` depending on usage scenarios.

**server.strategy**

- Type: object or template string
- Availability: v1.1.0

Configures [deployment strategy][k8s-deployment-strategy] to replace existing Pod with a new one. This configuration is only available when `server.kind` is set to Deployment. For StatefulSet and DaemonSet, see `server.updateStrategy`.

**server.updateStrategy**

- Type: object or template string
- Availability: v1.1.0

Configures update strategy for updating Pods when a change is made to the manifest. This configuration is only available when `server.kind` is set to StatefulSet or DaemonSet. For Deployment, see `server.strategy`.

*Note: While both StatefulSet and DaemonSet share the same `updateStrategy` configuration key, its applicable values are different. See [updateStrategy on StatefulSet][k8s-statefulset-updatestrategy] and [updateStrategy on DaemonSet][k8s-daemonset-updatestrategy].*

**server.hostNetwork**

- Type: boolean
- Default: `false`

Whether to enable hostNetwork for the Varnish Enterprise Pod. This will make the Varnish Enterprise Pod bind to the port of the host instead of using a container network provided by Kubernetes.

Setting this will also set the DNS policy to `ClusterFirstWithHostNet` to allow the Pod to communicate with Kubernetes DNS.

**server.shareProcessNamespace**

- Type: boolean
- Default: `false`
- Availability: v1.2.1

Whether to enable shared PID namespace between all containers in a Pod. This is useful for a scenario where it is necessary to send a signal to a process across a container.

**server.workDir**

- Type: string or number
- Default: `-`

Sets the Varnish working directory (the `-n` argument of varnishd), relative to `/var/lib/varnish`. When set to "-", the Pod name is used. When empty, varnishd runs without `-n` and uses the Varnish default, so `varnishstat`, `varnishadm` and `varnishlog` work without `-n` in `kubectl exec` and in extra containers.

**server.http.enabled**

- Type: boolean
- Default: `true`

Configures Varnish to listen for HTTP traffic.

**server.http.port**

- Type: number
- Default: `6081`

Configures the TCP port on which Varnish will listen for HTTP traffic. This port is used for Varnish to bind to within a container. To change the port exposed via service to other applications, see `server.service.http.port`.

**server.http.address**

- Type: string
- Default: `0.0.0.0`
- Availability: v1.7.4

Configures the address on which Varnish will listen for HTTP traffic. Ignored when `server.http.podIP` is `true`.

**server.http.podIP**

- Type: boolean
- Default: `false`
- Availability: v1.7.4

Configures Varnish to listen for HTTP traffic on the Pod IP address instead of `server.http.address`. Note that this makes port forwarding with kubectl harder.

**server.http.hostPort**

- Type: number

Sets the port to expose HTTP traffic directly on the node the Pod runs on, as the container's [hostPort][k8s-pod-v1-containers].

**server.tls.enabled**

- Type: boolean
- Default: `false`

Configures Varnish to listen for HTTPS traffic using native TLS. When enabled, `server.tls.config` should also be set. Certificates may be mounted into the Pod using `server.extraVolumeMounts` and `server.extraVolumes`.

**server.tls.port**

- Type: number
- Default: `6443`

Configures the TCP port on which Varnish will listen for HTTPS traffic. This port is used for Varnish to bind to within a container. To change the port exposed via service to other applications, see `server.service.https.port`.

This port is used by the HTTPS service as a targetPort.

**server.tls.hostPort**

- Type: number

Sets the port to expose HTTPS traffic directly on the node the Pod runs on, as the container's [hostPort][k8s-pod-v1-containers].

**server.tls.address**

- Type: string
- Default: `0.0.0.0`

Configures the address on which Varnish will listen for HTTPS traffic. Only applicable when neither `server.tls.config` nor `server.tls.configFile` is set.

**server.tls.config**

- Type: template string

The TLS configuration, passed to varnishd with `-A`. It is recommended to reference the port with the `{{ .Values.server.tls.port }}` template string to keep the configuration in sync with the service.

For example:

```yaml
server:
  tls:
    config: |
      frontend = {
        host = ""
        port = "{{ .Values.server.tls.port }}"
      }

      pem-file = "/etc/varnish/certs/example.pem"
```

**server.tls.configFile**

- Type: string

Uses the content of the given file as `server.tls.config`. The file is parsed as a template string and must be placed inside the `files/` directory of the Helm chart. Overrides `server.tls.config` if set.

For example:

```yaml
server:
  tls:
    configFile: files/tls.cfg
```

**server.admin.address**

- Type: string
- Default: `127.0.0.1`

Configures the address for Varnish management interface.

**server.admin.port**

- Type: number
- Default: `6082`

Configures the port for Varnish management interface.

**server.extraListens**

- Type: array of objects

An array of extra ports for Varnish to listen to.

For example:

```yaml
server:
  extraListens:
    - name: proxy
      address: "0.0.0.0"
      port: 6888
      proto: PROXY
    - name: proxy-sock
      path: /tmp/varnish-proxy.sock
      user: www
      group: www
      mode: "0700"
      proto: PROXY
```

**server.extraListens[].name**

- Type: string

The name of the listen. This name will be accessible in VCLs via `local.socket`.

**server.extraListens[].proto**

- Type: string

The protocol of the listen. Must be one of `PROXY` or `HTTP`. Default to HTTP if not set.

**server.extraListens[].port**

- Type: number

The port to listen to. Required unless `server.extraListens[].path` is set. Only applicable for TCP listens.

**server.extraListens[].address**

- Type: string

The address to listen to. Only applicable for TCP listens.

**server.extraListens[].hostPort**

- Type: number

The port to expose this listen directly on the node the Pod runs on, as the container's [hostPort][k8s-pod-v1-containers]. Only applicable for TCP listens.

**server.extraListens[].path**

- Type: string

The path of the UNIX domain socket to listen to. Required unless `server.extraListens[].port` is set. Only applicable for UNIX domain sockets.

**server.extraListens[].user**

- Type: string

The user owning the UNIX domain socket. Only applicable for UNIX domain sockets.

**server.extraListens[].group**

- Type: string

The group owning the UNIX domain socket. Only applicable for UNIX domain sockets.

**server.extraListens[].mode**

- Type: string

The file mode octet for the UNIX domain socket, as a quoted string (e.g. "0700"). Only applicable for UNIX domain sockets.

**server.extraEnvs**

- Type: array of objects, object, or template string
- Availability: v1.5.0

Sets additional environment variables for the Varnish Enterprise container. The value can be set as an object, an array of objects, or a template string.

For example, as an object:

```yaml
server:
  extraEnvs:
    MY_ENV_VAR: value
    MY_OTHER_ENV_VAR: other_value
```

As an array of objects:

```yaml
server:
  extraEnvs:
    - name: MY_ENV_VAR
      value: value
    - name: MY_OTHER_ENV_VAR
      valueFrom:
        configMapKeyRef:
          name: my-config-map
          key: my-key
```

As a template string:

```yaml
server:
  extraEnvs: |
    - name: RELEASE_NAMESPACE
      value: {{ .Release.Namespace }}
```

**server.ttl**

- Type: number or string
- Default: `120`

Sets the default Time To Live (in seconds) for a cached object.

**server.minThreads**

- Type: number or string
- Default: `50`

Sets the minimum number of worker threads in each pool. See also [varnishd documentation][varnishd].

**server.maxThreads**

- Type: number or string
- Default: `1000`

Sets the maximum number of worker threads in each pool. See also [varnishd documentation][varnishd].

**server.threadTimeout**

- Type: number or string
- Default: `120`

Sets the number of seconds after which idle threads are destroyed.

**server.command**

- Type: array of strings

Sets the command for Varnish Enterprise. Note that by overriding this, you will also override parameters, listening ports, etc. See also [varnishd documentation][varnishd].

**server.extraArgs**

- Type: string or array of strings

Sets the extra arguments to varnishd. A string is split on whitespace into separate arguments, while each item of a list is passed as a single argument, so use a list for values containing spaces.

**server.parameters**

- Type: object

Sets Varnish Enterprise parameters (the `-p` argument of varnishd). Parameter names are converted from camelCase to snake_case, and arrays are joined with a comma.

For example, the following results in `-p backend_idle_timeout=60 -p feature=+http2`:

```yaml
server:
  parameters:
    backendIdleTimeout: "60"
    feature:
      - "+http2"
```

**server.secret**

- Type: string

Sets the Varnish secret for accessing the varnishd admin interface. Either this value or `server.secretFrom` can be set. If unset, Varnish will generate one on every Pod start.

**server.secretFrom**

- Type: object
- Availability: v1.3.0

Sets the Varnish secret from an external Kubernetes secret for accessing the varnishd admin interface. Either this value or `server.secret` can be set.

For example:

```yaml
server:
  secretFrom:
    name: secret-name
    key: varnish-secret
```

**server.secretFrom.name**

- Type: string

The name of the Kubernetes secret. Required when `server.secretFrom` is set.

**server.secretFrom.key**

- Type: string

The key of the Kubernetes secret holding the Varnish secret. Required when `server.secretFrom` is set.

**server.secretFile**

- Type: string

Use the content of the given file path as Varnish secret. The file will be parsed as templated string. Will override `server.secret` if set. Note that the file must be placed inside the files/ directory in the Helm chart itself.

For example:

```yaml
server:
  secretFile: files/secret
```

**server.vclConfigPath**

- Type: string
- Default: `/etc/varnish/default.vcl`
- Availability: v1.2.0

A path to the main VCL configuration. This configuration affects the location where `server.vclConfig` will be saved to, as well as the `VARNISH_VCL_CONF` environment variable in the Varnish Enterprise container.

**server.vclConfig**

- Type: template string

A VCL configuration for Varnish Enterprise.

For example:

```yaml
server:
  vclConfig: |
    vcl 4.1;

    backend default {
      .host = "www.example.com";
      .port = "80";
    }

    sub vcl_backend_fetch {
      set bereq.http.Host = "www.example.com";
    }
```

**server.vclConfigFile**

- Type: string

Use the content of the given file path as VCL configuration. The file will be parsed as templated string. Will override `server.vclConfig` if set. Note that the file must be placed inside the files/ directory in the Helm chart itself.

For example:

```yaml
server:
  vclConfigFile: files/default.vcl
```

**server.vclConfigs**

- Type: object of template strings
- Availability: v1.2.0

Extra VCL configuration where a filename as a key and template string as a value. The path to store `server.vclConfigs` will be relative to that of `server.vclConfigPath`.

If the filename in `server.vclConfigs` matches the name in `server.vclConfigPath`, it will be treated in the same way as `server.vclConfig`. In this case, `server.vclConfig` must not be set.

For example, with `server.vclConfigPath` set to `/etc/varnish/default.vcl`, the following configuration saves the file as `/etc/varnish/extra.vcl`:

```yaml
server:
  vclConfigs:
    extra.vcl: |
      vcl 4.1;

      backend default {
        .host = "127.0.0.1";
        .port = "8090";
      }
```

With `server.vclConfigPath` set to `/etc/varnish/default.vcl`, the following is effectively the same as setting `server.vclConfig`, which must then be unset:

```yaml
server:
  vclConfigs:
    default.vcl: |
      vcl 4.1;

      backend default {
        .host = "127.0.0.1";
        .port = "8090";
      }
```

**server.vcls**

- Type: object
- Availability: v1.8.0

Per-domain VCL routing (multi-tenant). When `server.vcls.routes` is set, the chart generates a routing VCL and a cmdfile from these settings, superseding the `server.vclConfig*` fields. `server.cmdfileConfig` and `server.cmdfileConfigFile` must not be set when `server.vcls.routes` is non-empty.

**server.vcls.routes**

- Type: array of objects

Per-domain VCL routing. When set, the chart generates a routing VCL and a cmdfile that load each route as a separate VCL and select it based on the Host header, superseding `server.vclConfig`, `server.vclConfigFile`, `server.vclConfigs` and `server.cmdfileConfig` (which must not be set). Each route must set `vclContent`, and can set `name` (defaults to the first hostname, prefixed with `route_` if it does not start with a letter) and `hostnames`. As it is used as a VCL label, `name` must start with a letter. A route without hostnames is a catch-all and must be the last one.

For example:

```yaml
server:
  vcls:
    routes:
      - name: foo-site
        hostnames:
          - foo.com
          - www.foo.com
        vclContent: |
          vcl 4.1;
          backend default { .host = "foo-backend"; }
      - vclContent: |
          vcl 4.1;
          backend default none;
          sub vcl_recv { return (synth(404)); }
```

**server.vcls.routes[].name**

- Type: string

The name of the route, used as a VCL label, so it must start with a letter. Defaults to the first hostname, prefixed with `route_` if it does not start with a letter, or to `any` for a route without hostnames.

**server.vcls.routes[].hostnames**

- Type: array of strings

The hostnames to match for this route. A route without hostnames is a catch-all and must be the last one.

**server.vcls.routes[].vclContent**

- Type: template string

The VCL of the route. Required.

**server.vcls.includes**

- Type: object of template strings

Shared VCL files placed in `/etc/varnish/vcls/`, next to the route VCLs. Each key is a filename and each value a template string. Requires `server.vcls.routes`. Route VCLs include them with a relative path (`include "./helpers.vcl";`), as plain filenames are looked up in `vcl_path` instead.

For example, a route VCL can use the following with `include "./helpers.vcl";` and `call common_recv;`:

```yaml
server:
  vcls:
    includes:
      helpers.vcl: |
        sub common_recv {
        }
```

**server.cmdfileConfigPath**

- Type: string
- Default: `/etc/varnish/cmds.cli`
- Availability: v1.2.0

A path to the [CLI command file][varnish-cmdfile]. This configuration affects the location where `server.cmdfileConfig` will be saved to, as well as the `-I` argument in the Varnish Enterprise container when `server.cmdfileConfig` is not empty.

**server.cmdfileConfig**

- Type: template string
- Availability: v1.2.0

A [CLI command file][varnish-cmdfile] for running management commands when `varnishd` is launched. For example, when loading extra VCL in multi-tenancy mode. See also [External VCL ConfigMap](https://docs.varnish-software.com/varnish-helm/guides/using-external-vcl-configmap/#configmap-for-multiple-vcl-files).

For example:

```yaml
server:
  cmdfileConfig: |
    vcl.load vcl_tenant1 /etc/varnish/tenant1.vcl
    vcl.label label_tenant1 vcl_tenant1
    vcl.load vcl_main /etc/varnish/main.vcl
    vcl.use vcl_main
```

**server.cmdfileConfigFile**

- Type: string

Use the content of the given file path as a cmdfile. The file will be parsed as templated string. Will override `server.cmdfileConfig` if set. Note that the file must be placed inside the files/ directory in the Helm chart itself.

For example:

```yaml
server:
  cmdfileConfigFile: files/cmds.cli
```

**server.terminationGracePeriodSeconds**

- Type: number
- Default: `0`
- Availability: v1.6.0

Sets the termination grace period seconds to wait for Varnish Enterprise to shut down. Once this number of seconds is reached without the Varnish Enterprise Pod shutting down, Kubernetes will send SIGKILL to the Pod. When `server.delayedShutdown` is used, this value should be set to a higher value than the **maximum** time (in seconds) it took for Varnish Enterprise to fully shut down after a delayed shutdown.

The value to set here depends on the cluster setup. For example, an AWS Load Balancer may still forward requests to Varnish for `deregistration_delay.timeout_seconds` which is set to 300 seconds by default. If `server.delayedShutdown` took 30 seconds, then `server.terminationGracePeriodSeconds` should be set to _at least_ 330 seconds in order to have a zero-downtime during a rolling update or scaling down.

**server.delayedHaltSeconds**

- Type: number

Deprecated: use `server.delayedShutdown` instead.

Delays stopping of the Varnish Enterprise container by the given seconds.

**server.delayedShutdown**

- Type: object

Configures delayed shutdown for zero-downtime downscaling.

**server.delayedShutdown.method**

- Type: string, one of `none`, `sleep`, `mempool`, or `shutdown_delay`
- Default: `none`
- Availability: v1.6.0

Sets the method for delaying the shutdown of Varnish Enterprise. This is useful for rolling updates or when scaling down, where the load balancer component may still attempt to forward requests to the Varnish Enterprise instance when Varnish Enterprise has already received a SIGHUP, leading to HTTP 502 errors.

Multiple methods are provided here:

- `sleep` will simply sleep in the `preStop` for `server.delayedShutdown.sleep.seconds` seconds. This is the simplest way to delay the shutdown of Varnish Enterprise when the time taken for the load balancer component to stop forwarding traffic to Varnish Enterprise is largely fixed.
- `mempool` polls varnishstat for `MEMPOOL.sess` to go down to zero. This allows for the quickest shutdown but requires tuning `server.delayedShutdown.mempool.pollSeconds` to traffic patterns (as `MEMPOOL.sess` may become 0 momentarily, resulting in an early shutdown).

When `server.delayedShutdown.method` is set to a value other than "none", `server.terminationGracePeriodSeconds` **must** also be set.

**server.delayedShutdown.sleep**

- Type: object

Configures the "sleep" delayed shutdown method.

**server.delayedShutdown.sleep.seconds**

- Type: number or string
- Default: `90`

Sets the number of seconds to sleep before SIGHUP is sent to Varnish Enterprise. Only applicable when `server.delayedShutdown.method` is set to "sleep".

**server.delayedShutdown.mempool**

- Type: object

Configures the "mempool" delayed shutdown method.

**server.delayedShutdown.mempool.pollSeconds**

- Type: number or string
- Default: `1`

Sets the number of seconds to poll for `MEMPOOL.sess` stats. Only applicable when `server.delayedShutdown.method` is set to "mempool".

This value requires tuning to traffic patterns. If the time between each traffic took more than `server.delayedShutdown.mempool.pollSeconds`, then Varnish Enterprise could be signaled to SIGHUP too early, leading to an HTTP 502 error on the load balancer (as Varnish Enterprise already stopped accepting connection).

**server.delayedShutdown.mempool.waitSeconds**

- Type: number or string
- Default: `5`

Sets the number of seconds to wait after `MEMPOOL.sess` turned zero. Only applicable when `server.delayedShutdown.method` is set to "mempool".

**server.delayedShutdown.shutdownDelay**

- Type: object

Configures the "shutdown_delay" delayed shutdown method. It is similar to `sleep`, but uses the `shutdown_delay` feature of Varnish Enterprise (6.0.13r2 and newer) to perform the wait in-engine instead of relying on `preStop` and an external command.

**server.delayedShutdown.shutdownDelay.seconds**

- Type: number or string
- Default: `90`

Sets the number of seconds to delay the shutdown in-engine. Only applicable when `server.delayedShutdown.method` is set to "shutdown_delay".

**server.image**

- Type: object

Sets the image and tag to use to deploy Varnish Enterprise.

**server.image.repository**

- Type: string
- Default: `quay.io/varnish-software/varnish-plus`

Sets the repository for Varnish Enterprise image.

**server.image.pullPolicy**

- Type: string
- Default: `IfNotPresent`

Sets the [imagePullPolicy][k8s-pod-v1-containers] for the Varnish Enterprise image. This can be one of Always, Never, or IfNotPresent.

**server.image.tag**

- Type: string or number
- Default: _same as appVersion_

Sets the tag for the Varnish Enterprise image. By default, this is set to the same application version as in the Varnish Enterprise Helm Chart. If the tag is set to non-exact versions (such as "latest"), make sure to set `server.image.pullPolicy` to "Always" to make sure the image is always updated.

### extraManifests

**extraManifests**

- Type: array of objects

An array of objects to attach Kubernetes manifests to the workload.

For example:

```yaml
extraManifests:
  - name: clusterrole
    data: |
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: {{ .Release.Name }}-clusterrole
      # ...
```

**extraManifests[].name**

- Type: string

The name of the manifest. Only used if `extraManifests[].checksum` is `true`.

**extraManifests[].checksum**

- Type: boolean

Whether to attach the manifest's checksum to that of the workload in order to force an automatic rollout when the manifest is updated.

**extraManifests[].data**

- Type: object or template string

The full content of the manifest.

[k8s-daemonset-updatestrategy]: https://kubernetes.io/docs/tasks/manage-daemon/update-daemon-set/
[k8s-deployment-strategy]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy
[k8s-pod-v1-containers]: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#containers
[k8s-pod-v1-pods]: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#PodSpec
[k8s-statefulset-updatestrategy]: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#update-strategies
[varnish-cmdfile]: https://varnish-cache.org/docs/trunk/reference/varnishd.html#cli-command-file
[varnishd]: https://varnish-cache.org/docs/6.0/reference/varnishd.html
