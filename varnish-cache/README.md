# Varnish Cache Helm Chart

[Varnish Cache](https://varnish-cache.org/intro/index.html) is a high-performance web application accelerator (also known as a caching HTTP reverse proxy).

This repository provides an easy way to install Varnish Cache on Kubernetes using [Helm](https://helm.sh/).

For Varnish Enterprise customers, please see [Varnish Enterprise Helm Chart](https://docs.varnish-software.com/varnish-helm/varnish-enterprise/).

## Usage

To install the chart as `release-name` in the current namespace:

```
helm install release-name oci://registry-1.docker.io/varnish/varnish-cache
```

### Configuring

To configure a Helm chart, create `values.yaml` to override the default values:

```yaml
---
server:
  replicas: 3
```

Then install or upgrade using the overridden values, e.g.:

```
helm upgrade -f values.yaml release-name oci://registry-1.docker.io/varnish/varnish-cache
```

Varnish Cache Helm Chart is designed to be highly configurable while requiring minimal configuration for common operations. Listed below are the common configurations for a Varnish Cache deployment. For a full list of configurations, see the **Configurations** section below.

#### Changing the default VCL

Varnish Cache Helm Chart does not provide any VCL by default. Instead, it uses the default VCL located at `/etc/varnish/default.vcl` provided within the Docker image. From varnish:7.5.0 onward, it is possible to configure the default backend via an environment variable:

```yaml
server:
  extraEnvs:
    VARNISH_BACKEND_HOST: "localhost"
    VARNISH_BACKEND_PORT: "8080"
```

If a more advanced customization is required, it is also possible to override the default VCL with `server.vclConfig`:

```yaml
---
server:
  vclConfig: |
    vcl 4.1;

    backend default {
      .host = "example.default.svc.cluster.local";
      .port = "8080";
    }

    sub vcl_backend_fetch {
      set bereq.http.Host = "www.example.com";
    }
```

#### Workload types

Varnish Cache Helm Chart supports deploying with the following workload types by modifying `server.kind` variable with the respective values:

- `Deployment` for general use-case of Varnish Cache
- `StatefulSet` for Varnish Cache deployment where persistency is needed
- `DaemonSet` for ensuring Varnish Cache is run on every node

#### Extra listens and extra services

Varnish Cache Helm Chart supports deploying Varnish Cache with custom ports. For example, opening another HTTP port with `PROXY` protocol support for integration with an upstream Load Balancer. To do so, configures `server.extraListens` and `server.service.extraServices` respectively:

```yaml
---
server:
  extraListens:
    - name: proxy
      port: 8088
      proto: "PROXY"

  service:
    extraServices:
      - name: proxy
        targetPort: 8088
        port: 8088
```

Setting `server.extraListens` will configure both the Varnish Cache and the Pod template to expose the given ports.

#### Using external ConfigMap

Often, it may be preferable to have VCL deployed as a ConfigMap in a separate Kubernetes deployment. In this case, configure `server.vclConfig`, `server.extraVolumes`, and `server.extraVolumeMounts` accordingly:

```yaml
---
server:
  vclConfig: ""  # It is necessary to unset this value to override default.vcl

  extraVolumes:
    - name: external
      configMap:
        name: external-vcl

  extraVolumeMounts:
    - name: external
      mountPath: /etc/varnish/default.vcl
      subPath: default.vcl
```

In the case where `server.vclConfigPath` was configured to any value apart from the default, `mountPath` also needed to be changed to match that value.

#### Serving multiple domains

To serve multiple domains with Varnish Cache, it is highly recommended to [use multiple VCL files and use cmdfile to load them](https://varnish-cache.org/docs/trunk/users-guide/vcl-separate.html). To do this with Varnish Cache Helm Chart, set `server.cmdfileConfig`, and `server.vclConfigs` accordingly:

```yaml
---
server:
  vclConfigs:
    # We need an entrypoint VCL separately from default.vcl (which is now used as a fallback VCL)
    main.vcl: |
      vcl 4.1

      import std;

      sub vcl_recv {
        set req.http.host = std.tolower(req.http.host);
        if (req.http.host ~ "(^|\.)example\.com(\:[0-9]+)?$") {
          return (vcl(label_example));
        } elseif (req.http.host ~ "(^|\.)home\.arpa(\:[0-9]+)?$") {
          return (vcl(label_home));
        }
      }

    # Define VCL for each domains
    example.vcl: |
      # ...

    home.vcl: |
      # ...

  cmdfileConfig: |
    vcl.load vcl_example /etc/varnish/example.vcl
    vcl.label label_example
    vcl.load vcl_home /etc/varnish/home.vcl
    vcl.label label_home
    vcl.load vcl_main /etc/varnish/main.vcl
    vcl.use vcl_main
```

Instead of using `server.vclConfigs`, it is also possible to use external VCL for each domains by adapting the configuration from _Using external ConfigMap_ section:

```yaml
---
server:
  # ...omit...

  extraVolumes:
    - name: example
      configMap:
        name: example-vcl

    - name: home
      configMap:
        name: home-vcl

  extraVolumeMounts:
    - name: example
      mountPath: /etc/varnish/example.vcl
      subPath: example.vcl

    - name: home
      mountPath: /etc/varnish/home.vcl
      subPath: home.vcl
```

## Support

Community support for Varnish Helm Chart is provided via [GitHub](https://github.com/varnish/helm-varnish-cache).

Please contact [Varnish Software](https://www.varnish-software.com/contact-us/) for a commercial support.

## Configurations

### Data types

**string**

A string. While the YAML spec does not require strings to be quoted, it is highly recommended to quote strings to prevent YAML type coercion (e.g., values such as `country: NO` are treated as `country: false` by YAML).

Example:

```yaml
key1: "value"

## or multi-line
key2: |
  value
```

**number**

A number.

```yaml
key1: 42

## or float
key2: 3.14
```

**boolean**

A true or false. While the YAML spec also treats keywords such as "yes" and "no" as true and false, respectively, it is highly recommended to use explicit true and false as the value for maintainability.

```yaml
key1: true
```

**object**

A pair of key value.

```yaml
key1:
  subkey1: "string"
  subkey2: 3.14
  subkey3: true

## alternatively, using JSON syntax
key2: { "subkey1": "string", "subkey2": 3.14, "subkey3": true }
```

**array of objects**

An array of objects.

```yaml
key1:
  - name: "value1"
    subkey: "value"
  - name: "value2"
    subkey: "value"
```

**array of strings**

An array of strings.

```yaml
key1:
  - "string1"
  - "string2"
  - "string3"

## alternatively, using JSON syntax
key1: ["string1", "string2", "string3"]
```

**template string**

A pair of key value as a string. Template functions exposed by Helm are available in this type.

```yaml
key1: |
  subkey1: {{ .Release.Name | quote }}
  subkey2: "hello, world"

## in array of objects
key2: |
  - name: {{ .Release.Name | quote }}
    subkey1: "hello, world"
```

### Chart configurations

**nameOverride**

- Type: string
- Default: name of the cart (e.g., `varnish-cache`)

Overrides the name of the chart (without the release name). For example, setting `nameOverride` to "hello" would produce a deployment named "release-name-hello". Containers within a pod derive their name from this setting.

By default, the name of the chart is used (i.e., "varnish-cache")

**fullnameOverride**

- Type: string
- Default: composition of a release name and name of the chart (e.g., "release-name-varnish-cache")

Overrides the full name of the chart (with the release name). This setting allows overriding both the release name and the deployment name altogether. For example, setting `fullnameOverride` to "hello" would produce a deployment named "hello".

### Global configurations

**global.imagePullSecrets**

- Type: array of object

An array of objects that conforms to the Kubernetes [imagePullSecrets][k8s-pod-v1-containers] definition. When set, each item in an array must consist of an object with a key `name` referencing the Kubernetes secret

For example:

```yaml
global:
  imagePullSecrets:
    - name: registry-quay-k7c2f4m2d5
```

**global.podSecurityContext**

- Type: object

An object that conforms to the Kubernetes [securityContext][k8s-pod-v1-pods] definition of a Pod

For example:

```yaml
global:
  podSecurityContext:
    fsGroup: 999
```

This securityContext will be set on all Pods within this chart. For setting securityContext on all containers, see `global.securityContext`.

**global.securityContext**

- Type: object

An object that conforms to the Kubernetes [securityContext][k8s-pod-v1-containers] definition of a Container

For example:

```yaml
global:
  securityContext:
    runAsUser: 999
    runAsNonRoot: true
```

This securityContext will be set on all containers within this chart. For setting securityContext on the Pod itself, see `global.podSecurityContext`.

### Service Account configurations

**serviceAccount.create**

- Type: boolean
- Default: `true`

Create a Kubernetes service account to use with the deployment.

**serviceAccount.labels**

- Type: object or template string

Applies extra labels to the service account. The value can be set as either an object or a template string.

**serviceAccount.annotations**

- Type: object or template string

Applies extra annotations to the service account. The value can be set as either an object or a template string.

**serviceAccount.name**

- Type: string

Overrides the name of the service account. By default, the full name of the chart is used.

### Server configurations

**server.replicas**

- Type: number
- Default: `1`

Specifies the number of replicas to deploy Varnish Cache server. The value is ignored if `server.autoscaling.enabled` is set to true, or `server.kind` is "DaemonSet".

**server.kind**

- Type: string
- Default: `Deployment`

Specifies the type of deployment to deploy Varnish Cache server. The value can be one of `Deployment`, `DaemonSet`, or `StatefulSet` depending on usage scenarios (see examples).

**server.labels**

- Type: object or template string

Applies extra labels to the deployment. The value can be set as either an object or a template string. Labels specified here will be applied to the deployment itself. To apply labels on the Pod, use `server.podLabels`.

**server.annotations**

- Type: object or template string

Applies extra annotations to the deployment. The value can be set as either an object or a template string. Deployment annotations can be used to for applying additional metadata or for integrating with external tooling. The annotations specified here will be applied to the deployment itself. To apply labels on the Pod, use `server.podAnnotations`.

**server.strategy**

- Type: object or template string

Configures [deployment strategy][k8s-deployment-strategy] to replace existing Pod with a new one. This configuration is only available when `server.kind` is set to Deployment. For StatefulSet and DaemonSet, see `server.updateStrategy`.

**server.updateStrategy**

- Type: object or template string

Configures update strategy for updating Pods when a change is made to the manifest. This configuration is only available when `server.kind` is set to StatefulSet or DaemonSet. For Deployment, see `server.strategy`.

*Note: While both StatefulSet and DaemonSet share the same `updateStrategy` configuration key, its applicable values are different. See [updateStrategy on StatefulSet][k8s-statefulset-updatestrategy] and [updateStrategy on DaemonSet][k8s-daemonset-updatestrategy].*

**server.shareProcessNamespace**

- Type: boolean

Whether to enable shared PID namespace between all containers in a Pod. This is useful for a scenario where it is necessary to send a signal to a process across a container.

**server.http.enabled**

- Type: boolean
- Default: `true`

Configures Varnish to listen for HTTP traffic.

**server.http.port**

- Type: number
- Default: `6081`

Configures the TCP port on which Varnish will listen for HTTP traffic. This port is used for Varnish to bind to within a container. To change the port exposed via service to other applications, see `server.service.http.port`.

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
extraListens:
  - name: proxy
    address: "0.0.0.0"
    port: 6888
    proto: "PROXY"

  - name: proxy-sock
    path: "/tmp/varnish-proxy.sock"
    user: "www"
    group: "www"
    mode: "0700"
    proto: "PROXY"
```

**server.extraListens[].name**

- Type: string

The name of the listen. This name will be accessible in VCLs via `local.socket`.

**server.extraListens[].proto**

- Type: string

The protocol of the listen. Must be one of `PROXY` or `HTTP`. Default to HTTP if not set.

**server.extraListens[].port**

- Type: number
- Required: yes, unless `server.extraListens[].path` is set

The port to listens to. Only applicable for TCP listens.

**server.extraListens[].address**

- Type: string

The address to listens to. Only applicable for TCP listens.

**server.extraListens[].path**

- Type: string
- Required: yes, unless `server.extraListens[].port` is set

The path of UNIX domain socket to listens as. Only applicable for UNIX domain socket.

**server.extraListens[].user**

- Type: string

The user owning the UNIX domain socket. Only applicable for UNIX domain socket.

**server.extraListens[].group**

- Type: string

The group owning the UNIX domain socket. Only applicable for UNIX domain socket.

**server.extraListens[].mode**

- Type: string

The file mode octet for the UNIX domain socket. Only applicable for UNIX domain socket.

**server.ttl**

- Type: number
- Default: `120`

Sets the default Time To Live (in seconds) for a cached object.

**server.minThreads**

- Type: number
- Default: `50`

Sets the minimum number of worker threads in each pool. See also [varnishd documentation][varnishd].

**server.maxThreads**

- Type: number
- Default: `1000`

Sets the maximum number of worker threads in each pool. See also [varnishd documentation][varnishd].

**server.threadTimeout**

- Type: number
- Default: `120`

Sets the threshold in seconds where idle threads are destroyed after least this duration.

**server.extraArgs**

- Type: array of strings
- Default: `[]`

Sets the extra arguments to the varnishd.

**server.extraInitContainers**

- Type: array of objects or template string
- Default: `[]`

An array of objects that conform to the Kubernetes [initContainers][k8s-pod-v1-pods] definition of a Pod. This can be used to run initialization tasks before varnishd starts. Note that `initContainers` cannot be changed once it is applied. To update this value after the initial deploy, uninstall Varnish Cache Helm Chart from the cluster and reinstall. The value can be set as either an array of objects or a template string.

**server.extraContainers**

- Type: array of objects or template string
- Default: `[]`

An array of objects that conforms to the Kubernetes [containers][k8s-pod-v1-pods] definition of a Pod. This can be used to add a sidecar container to varnishd. The value can be set as either an array of objects or a template string.

**server.extraVolumeClaimTemplates**

- Type: array of objects or template string

An array of objects that conforms to the Kubernetes [VolumeClaimTemplates][k8s-volume-claim-templates] definition of a StatefulSet workload. This configuration is only available when `server.kind` is set to StatefulSet.

**server.extraVolumeMounts**

- Type: array of objects or template string

An array of objects that conforms to the Kubernetes [volumeMounts][k8s-pod-v1-containers] definition of a Container. This configuration is used to mount extra volumes defined in `server.extraVolumes` into the Varnish Cache container. The value can be set as either an array of objects or a template string.

**server.extraVolumes**

- Type: array of objects or template string

An array of objects that conforms to the Kubernetes [volumes][k8s-pod-v1-pods] definition of a Pod. This configuration is used to define volumes to be used in `server.extraVolumeMounts`, or within `server.extraContainers`, or within `server.extraInitContainers`. The value can be set as either an array of objects or a template string.

**server.secret**

- Type: string
- Required: no

Sets the Varnish secret for accessing the varnishd admin interface. Either this value or `server.secretFrom` can be set.

**server.secretFrom**

- Type: object
- Required: no

Sets the Varnish secret from external Kubernetes secret for accessing the varnishd admin interface. Either this value or `server.secret` can be set.

For example:

```yaml
server:
  secretFrom:
    name: secret-name
    key: varnish-secret
```

**server.command**

- Type: array of strings
- Default: `[]`

Sets the command executable to use. If provided, the default executable path will be overridden. See also `server.args`.

**server.args**

- Type: array of strings
- Required: no

Sets the command arguments to use. If not set, the generated command arguments will be used. To prevent any generated arguments from being passed, set `server.args` to `[]`.

**server.vclConfig**

- Type: template string
- Required: yes

A VCL configuration for Varnish Cache.

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

**server.vclConfigs**

- Type: object of template string

Extra VCL configuration where a filename as a key and template string as a value. The path to store `server.vclConfigs` will be relative to that of `server.vclConfigPath`. For example, given the following configuration:

```yaml
server:
  vclConfigPath: "/etc/varnish/default.vcl"

  vclConfigs:
    extra.vcl: |
      vcl 4.1;

      backend default {
        .host = "127.0.0.1";
        .port = "8090";
      }
```

The file will be saved as `/etc/varnish/extra.vcl`.

If the filename in `server.vclConfigs` matches the name in `server.vclConfigPath`, it will be treated in the same way as `server.vclConfig`. In this case, `server.vclConfig` must not be set. For example:

```yaml
server:
  vclConfigPath: "/etc/varnish/default.vcl"

  # This is effectively the same as setting server.vclConfig: "..."
  vclConfigs:
    default.vcl: |
      vcl 4.1;

      backend default {
        .host = "127.0.0.1";
        .port = "8090";
      }

  # In this case, vclConfig must be unset.
  vclConfig: ""
```

**server.vclConfigPath**

- Type: string
- Default: `/etc/varnish/default.vcl`

A path to the main VCL configuration. This configuration affects the location where `server.vclConfig` will be saved to, as well as the `VARNISH_VCL_CONF` environment variable in the Varnish Cache container.

**server.cmdfileConfig**

- Type: template string

A [CLI command file][varnish-cmdfile] for running management commands when `varnishd` is launched. For example, when loading extra VCL in multi-tenancy mode.

For example:

```yaml
server:
  cmdfileConfig: |
    vcl.load vcl_tenant1 /etc/varnish/tenant1.vcl
    vcl.label label_tenant1 vcl_tenant1
    vcl.load vcl_main /etc/varnish/main.vcl
    vcl.use vcl_main
```

**server.cmdfileConfigPath**

- Type: string
- Default: `/etc/varnish/cmds.cli`

A path to the [CLI command file][varnish-cmdfile]. This configuration affects the location where `server.cmdfileConfig` will be saved to, as well as the `-I` argument in the Varnish Cache container when `server.cmdfileConfig` is not empty.

**server.image.repository**

- Type: string
- Default: `quay.io/varnish-software/varnish-plus`

Sets the repository for Varnish Cache image.

**server.image.pullPolicy**

- Type: string
- Default: `IfNotPresent`

Sets the [imagePullPolicy][k8s-pod-v1-containers] for the Varnish Cache image. This can be one of Always, Never, or IfNotPreset.

**server.image.tag**

- Type: string
- Default: _same as appVersion_

Sets the tag for the Varnish Cache image. By default, this is set to the same application version as in the Varnish Cache Helm Chart. If the tag is set to non-exact versions (such as "latest", or "6.0"), make sure to set `server.image.pullPolicy` to "Always" to make sure the image is always updated.

**server.podAnnotations**

- Type: object or template string

Applies extra annotations to the Pod. The value can be set as either an object or a template string. Pod annotations can be used to for applying additional metadata or for integrating with external tooling. Annotations specified here will be applied to the Pod. To apply labels on the deployment, use `server.annotations`.

**server.podLabels**

- Type: object or template string

Applies extra labels to the Pod. The value can be set as either an object or a template string. Labels specified here will be applied to the Pod itself. To apply labels on the deployment, use `server.labels`.

**server.securityContext**

- Type: object

An object that conforms to the Kubernetes [securityContext][k8s-pod-v1-containers] definition of a Container

For example:

```yaml
server:
  securityContext:
    runAsUser: 999
```

This securityContext will be set on the Varnish Cache container. For setting securityContext on the Pod itself, see `global.podSecurityContext`. For setting securityContext to all containers, see `global.securityContext`.

**server.startupProbe**

- Type: object

An object that conforms to the Kubernetes [startupProbe][k8s-pod-v1-containers] definition of a Container.

For example:

```yaml
server:
  startupProbe:
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
```

**server.startupProbe.httpGet**

- Type: object

Uses Kubernetes [httpGet probe][k8s-probes] instead of TCP probe. Port will be automatically injected. It is possible to provide extra configuration options that conforms to the Kubernetes httpGet probe definition.

For example, to enable httpGet probe mode:

```yaml
server:
  startupProbe:
    httpGet:
```

To specify path and add extra headers:

```yaml
server:
  startupProbe:
    httpGet:
      path: "/healthz"
      httpHeaders:
        - name: X-Health-Check
          value: k8s
```

Varnish Helm Chart doesn't provide a default health check endpoint, so it is necessary to configure Varnish to return 200 OK for this endpoint via a VCL. For example:

```yaml
server:
  vclConfig: |
    vcl 4.1

    backend default {
      .host = "www.example.com";
      .port = "80";
    }

    sub vcl_recv {
      if (req.url ~ "^/healthz(/.*)?$") {
        # or pass to backend, etc.
        return synth(200, "OK");
      }
    }
```

**server.readinessProbe**

- Type: object

An object that confirms to the Kubernetes [readienssProbe][k8s-pod-v1-containers] definition of a Container.

**server.readinessProbe.httpGet**

- Type: object

Uses Kubernetes [httpGet probe][k8s-probes] instead of TCP probe. Port will be automatically injected. It is possible to provide extra configuration options that conforms to the Kubernetes httpGet probe definition.

**server.readinessProbe.initialDelaySeconds**

- Type: number
- Default: `5`

Sets the initial delay before the first probe is sent to determine if the Varnish Cache Pod is ready to accept an incoming connection.

**server.readinessProbe.periodSeconds**

- Type: number
- Default: `10`

Sets the delay between each probe to determine if the Varnish Cache Pod is ready to accept an incoming connection after the initial probe.

**server.readinessProbe.timeoutSeconds**

- Type: number
- Default: `1`

Sets the timeout for the probe to wait for a response from the Varnish Cache Pod.

**server.readinessProbe.successThreshold**

- Type: number
- Default: `1`

Sets the number of times when a consecutive successful response is considered a success and the Varnish Cache Pod is considered ready to accept an incoming connection.

**server.readinessProbe.failureThreshold**

- Type: number
- Default: `3`

Sets the number of times when a consecutive failure response is considered a failure and the Varnish Cache Pod is considered unhealthy.

**server.livenessProbe**

- Type: object

An object that confirms to the Kubernetes [readienssProbe][k8s-pod-v1-containers] definition of a Container.

**server.livenessProbe.httpGet**

- Type: object

Uses Kubernetes [httpGet probe][k8s-probes] instead of TCP probe. Port will be automatically injected. It is possible to provide extra configuration options that conforms to the Kubernetes httpGet probe definition.

See also `server.startupProbe.httpGet`.

**server.livenessProbe.initialDelaySeconds**

- Type: number
- Default: `30`

Sets the initial delay before the first probe is sent to determine if the Varnish Cache Pod is still ready to accept an incoming connection (i.e., live).

**server.livenessProbe.periodSeconds**

- Type: number
- Default: `10`

Sets the delay between each probe to determine if the Varnish Cache Pod is still ready to accept an incoming connection after the initial probe.

**server.livenessProbe.timeoutSeconds**

- Type: number
- Default: `5`

Sets the timeout for the probe to wait for a response from the Varnish Cache Pod.

**server.livenessProbe.successThreshold**

- Type: number
- Default: `1`

Sets the number of times when a consecutive successful response is considered a success and the Varnish Cache Pod is considered still ready to accept an incoming connection.

**server.livenessProbe.failureThreshold**

- Type: number
- Default: `3`

Sets the number of times when a consecutive failure response is considered a failure and the Varnish Cache Pod is considered unhealthy (i.e., down).

**server.resources**

- Type: object

An object that conforms to the Kubernetes [resources][k8s-pod-v1-containers] definition of a Container. This configuration can be used to limit resources consumed by the Varnish Cache container.

**server.nodeSelector**

- Type: object or template string

An object that conforms to the Kubernetes [nodeSelector][k8s-pod-v1-pods] definition of a Pod. This configuration is used to select a node to schedule a Pod to. The value can be set as either an object or a template string.

**server.tolerations**

- Type: array of strings or template string

An object that conforms to the Kubernetes [tolerations][k8s-pod-v1-pods] definition of a Pod. This configuration is used to allow the Pod to be scheduled to nodes with specific taints. The value can be set as either an array of strings or a template string.

**server.affinity**

- Type: object or template string
- Default (template string):
    ```string
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app.kubernetes.io/name: {{ include "varnish-cache.name" . }}
              app.kubernetes.io/instance: {{ .Release.Name }}
          topologyKey: kubernetes.io/hostname
    ```

This configuration is used to fine-grain control the scheduling of the Pod. By default, this is set to ensure all Varnish Cache Pods are always run in a different node. To disable this behavior, set to empty string (""). The value can be set as either an object or a template string.

**server.delayedShutdown.method**

- Type: string, one of `none`, `sleep`, or `mempool`
- Availability: v1.1.0

Sets the method for Kubernetes to delay sending a SIGHUP to Varnish Cache. This is useful for rolling updates or when scaling down, where the load balancer component may still attempt to forward requests to Varnish Cache instance when Varnish Cache has already received a SIGHUP, leading to HTTP 502 errors.

Multiple methods are provided here:

- `sleep` will simply sleep in the `preStop` for `server.delayedShutdown.sleep.seconds` seconds. This is the simplest way to delay the shutdown of Varnish Cache when the time taken for the load balancer component to stop forwarding traffic to Varnish Cache is largely fixed.
- `mempool` polls varnishstat for `MEMPOOL.sess` to go down to zero. This allows for the quickest shutdown but requires tuning `server.delayedShutdown.mempool.pollSeconds` to traffic patterns (as `MEMPOOL.sess` may become 0 momentary).

When `server.delayedShutdown.method` is set to a value other than "none", `server.terminationGracePeriodSeconds` **must** also be set.

**server.delayedShutdown.sleep.seconds**

- Type: number
- Default: `90`
- Availability: v1.1.0

Sets the number of seconds to sleep before SIGHUP is sent to Varnish Cache. Only applicable when `server.delayedShutdown.method` is set to "sleep".

**server.delayedShutdown.mempool.pollSeconds**

- Type: number
- Default: `1`
- Availability: v1.1.0

Sets the number of seconds to poll for `MEMPOOL.sess` stats. Only applicable when `server.delayedShutdown.method` is set to "mempool".

This value requires tuning to traffic patterns. If the time between each traffic took more than `server.delayedShutdown.mempool.pollSeconds`, then Varnish Cache could be signaled to SIGHUP too early, leading to an HTTP 502 error on the load balancer (as Varnish Cache already stopped accepting connection).

**server.delayedShutdown.mempool.waitSeconds**

- Type: number
- Default: `5`
- Availability: v1.1.0

Sets the number of seconds to wait after `MEMPOOL.sess` turned zero. Only applicable when `server.delayedShutdown.method` is set to "mempool".

**server.terminationGracePeriodSeconds**

- Type: number

Sets the termination grace period seconds for Varnish Cache to shut down until Kubernetes sends the process a SIGKILL. When `server.delayedShutdown` is used, this value should be set to the **maximum** time it took for Varnish Cache to fully shutdown.

The value to set here depends on the cluster setup. For example, an AWS Load Balancer may still forward requests to Varnish for `deregistration_delay.timeout_seconds` which is set to 300 seconds by default. If `server.delayedShutdown` took 30 seconds, then `server.terminationGracePeriodSeconds` should be set to _at least_ 330 seconds in order to have a zero-downtime during a rolling update or scaling down.

**server.autoscaling**

- Type: object

An object for configuring [HorizontalPodAutoscaling][k8s-hpa].

**server.autoscaling.enabled**

- Type: boolean
- Default: `false`

Enables the [HorizontalPodAutoscaling][k8s-hpa] with the Varnish Cache Pod. `server.replicas` is ignored if autoscaling is enabled.

**server.autoscaling.minReplicas**

- Type: number
- Default: `1`

Sets the minimum number of replicas to always keep running.

**server.autoscaling.maxReplicas**

- Type: number
- Default: `100`

Sets the maximum number of replicas to run at most.

**server.autoscaling.behavior**

- Type: object or template string
- Availability: v1.1.0

Sets the [HorizontalPodAutoscaling][k8s-hpa] behavior. The value can be set as either an object or a template string.

**server.autoscaling.metrics**

- Type: object or template string

Sets the [HorizontalPodAutoscaling][k8s-hpa] metrics. The value can be set as either an object or a template string.

**server.pdb**

- Type: object

An object for configuring [PodDisruptionBudget][k8s-pdb].

**server.pdb.enabled**

- Type: boolean
- Default: `false`

Enables PodDisruptionBudget.

**server.pdb.minAvailable**

- Type: string or number
- Required: yes, if `server.pdb.enabled` is true and `server.pdb.maxUnavailable` is not set

Sets the number or percentage of pods that must be available after the eviction.

**server.pdb.maxUnavailable**

- Type: string or number
- Required: yes, if `server.pdb.enabled` is true and `server.pdb.minAvailable` is not set

Sets the number or percentage of pods that can be unavailable after the eviction.

**server.varnishncsa**

- Type: object

An object for configuring [varnishncsa][varnishncsa].

**server.varnishncsa.enabled**

- Type: boolean
- Default: `true`

Enables HTTP request logging via [varnishncsa][varnishncsa].

**server.varnishncsa.image.repository**

- Type: string
- Default: `-`

Sets the repository for Varnish Cache image for use with varnishncsa. The Varnish image used here must be the same version as the Varnish Cache server. Set this to "-" to inherit the value of `server.image.repository`.

**server.varnishncsa.image.pullPolicy**

- Type: string
- Default: `-`

Sets the [imagePullPolicy][k8s-pod-v1-containers] for the Varnish Cache image for use with varnishncsa. This can be one of Always, Never, or IfNotPreset. Set this to "-" to inherit the value of `server.image.pullPolicy`.

**server.varnishncsa.image.tag**

- Type: string
- Default: `-`

Sets the tag for the Varnish Cache image for use with varnishncsa. The Varnish image used here must be the same version as the Varnish Cache server. Set this to "-" to inherit the value of `server.image.tag`.

**server.varnishncsa.securityContext**

- Type: object

An object that conforms to the Kubernetes [securityContext][k8s-pod-v1-containers] definition of a Container.

For example:

```yaml
server:
  securityContext:
    runAsUser: 999
```

This securityContext will be set on the varnishncsa container. For setting securityContext on the Pod itself, see `global.podSecurityContext`. For setting securityContext to all containers, see `global.securityContext`.

**server.varnishncsa.extraArgs**

- Type: array of strings

Sets the extra arguments to varnishncsa.

**server.varnishncsa.startupProbe**

- Type: object

An object that conforms to the Kubernetes [startupProbe][k8s-pod-v1-containers] definition of a Container.

**server.varnishncsa.readinessProbe**

- Type: object

An object that confirms to the Kubernetes [readinessProbe][k8s-pod-v1-containers] definition of a Container.

**server.varnishncsa.readinessProbe.initialDelaySeconds**

- Type: number
- Default: `5`

Sets the initial delay before the first probe is sent to determine if the varnishncsa Pod is ready to handle the logs.

**server.varnishncsa.readinessProbe.periodSeconds**

- Type: number
- Default: `10`

Sets the delay between each probe to determine if the varnishncsa Pod is ready to handle the logs after the initial probe.

**server.varnishncsa.readinessProbe.timeoutSeconds**

- Type: number
- Default: `1`

Sets the timeout for the probe to wait for a response from the varnishncsa Pod.

**server.varnishncsa.readinessProbe.successThreshold**

- Type: number
- Default: `1`

Sets the number of times when a consecutive successful response is considered a success and the varnishncsa Pod is considered ready to handle the logs.

**server.varnishncsa.readinessProbe.failureThreshold**

- Type: number
- Default: `3`

Sets the number of times when a consecutive failure response is considered a failure and the varnishncsa Pod is considered unhealthy.

**server.varnishncsa.livenessProbe**

- Type: object

An object that confirms to the Kubernetes [livenessProbe][k8s-pod-v1-containers] definition of a Container.

**server.varnishncsa.livenessProbe.initialDelaySeconds**

- Type: number
- Default: `30`

Sets the initial delay before the first probe is sent to determine if the varnishncsa Pod is still ready to handle the logs.

**server.varnishncsa.livenessProbe.periodSeconds**

- Type: number
- Default: `10`

Sets the delay between each probe to determine if the varnishncsa Pod is still ready to handle the logs after the initial probe.

**server.varnishncsa.livenessProbe.timeoutSeconds**

- Type: number
- Default: `5`

Sets the timeout for the probe to wait for a response from the varnishncsa Pod.

**server.varnishncsa.livenessProbe.successThreshold**

- Type: number
- Default: `1`

Sets the number of times when a consecutive successful response is considered a success and the varnishncsa Pod is considered still ready to handle the logs.

**server.varnishncsa.livenessProbe.failureThreshold**

- Type: number
- Default: `3`

Sets the number of times when a consecutive failure response is considered a failure and the varnishncsa Pod is considered unhealthy.

**server.varnishncsa.resources**

- Type: object

An object that conforms to the Kubernetes [resources][k8s-pod-v1-containers] definition of a Container. This configuration can be used to limit resources consumed by the varnishncsa container.

**server.service**

- Type: object

An object for configuring [Service][k8s-service].

**server.service.enabled**

- Type: boolean
- Default: `true`

Enables the [Service][k8s-service] for Varnish Enterprise.

**server.service.labels**

- Type: object or template string

Applies extra labels to the Service. The value can be set as either an object or a template string.

**server.service.annotations**

- Type: object or template string

Applies extra annotations to the Service. The value can be set as either an object or a template string.

**server.service.type**

- Type: string
- Default: `NodePort`

Sets the type of the Service. Can be either `CluterIP`, `LoadBalancer`, or `NodePort`.

**server.service.internalTrafficPolicy**

- Type: string
- Default: `Cluster`

Sets the internal traffic policy for this service. InternalTrafficPolicy describes how nodes distribute service
 traffic they receive on the ClusterIP. Can be set to `Local` or `Cluster`

**server.service.externalTrafficPolicy**

- Type: string
- Default: `Cluster`

Sets the external traffic policy for this service. externalTrafficPolicy describes how nodes distribute service
 traffic they receive on one of the Service's "externally-facing" addresses (NodePorts, ExternalIPs, and
 LoadBalancer IPs). Can be set to `Local` or `Cluster`

**server.service.clusterIP**

- Type: string

Sets a custom [Service ClusterIP][k8s-service-clusterip]. This value can be set as either an IP address, or a literal string "None". Only applicable when `server.service.type` is set to ClusterIP. When set to "None", Kubernetes will create a Headless Service, skipping the Kubernetes proxying mechanism.

**server.service.http.enabled**

- Type: boolean
- Default: `true`

Enables HTTP service.

**server.service.http.port**

- Type: number
- Default: `80`

Sets the port to expose HTTP service.

**server.service.http.nodePort**

- Type: number

Sets the port to expose HTTP service directly on the node itself. Only applicable when `server.service.type` is set to NodePort. This value must be within the Kubernetes service-node-port-range (default: 30000-32767).

**server.service.extraServices**

- Type: array of object

An array of extra services to expose to as a Service.

For example:

```yaml
extraServices:
  - name: "varnish-proxy"
    targetPort: 6888
    port: 88
```

**server.service.extraServices[].name**

- Type: string
- Required: yes

Sets the name of the Service.

**server.service.extraServices[].targetPort**

- Type: number
- Required: yes

Sets the target ports that are exposed via `server.extraListens`.

**server.service.extraServices[].port**

- Type: number

Sets the port to expose this extra service.

**server.service.extraServices[].nodePort**

- Type: number

Sets the port to expose this extra service on the node itself. Only applicable when `server.service.type` is set to NodePort. This value must be within the Kubernetes service-node-port-range (default: 30000-32767).

**server.ingress**

- Type: object

An object for configuring [Ingress][k8s-ingress].

**server.ingress.enabled**

- Type: boolean
- Default: `false`

Enables the [Ingress][k8s-ingress] for Varnish Enterprise.

**server.ingress.labels**

- Type: object or template string

Applies extra labels to the Ingress. The value can be set as either an object or a template string.

**server.ingress.annotations**

- Type: object or template string

Applies extra annotations to the Ingress. The value can be set as either an object or a template string.

**server.ingress.ingressClassName**

- Type: string

Sets the [Ingress Class][k8s-ingress-class] for selecting Ingress controller to use.

**server.ingress.pathType**

- Type: string
- Default: `Prefix`

Sets the [Ingress Path Type][k8s-ingress-path-type] for the Varnish Enterprise endpoint. The value can be either `Prefix`, `Exact`, or `ImplementationSpecific`. The value to use here depends on the Ingress controller.

**server.ingress.hosts**

- Type: array of object

Sets the hostname for the Ingress. This hostname is used for routing traffic.

**server.ingress.tls**

- Type: array of objects

An array of objects that conforms to [Ingress TLS][k8s-ingress-tls].

### extraManifests

- Type: array of object

An array of objects to attach Kubernetes manifests to the deployment.

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

The name of the manifest. Only used if extraManifests[].checksum is `true`.

**extraManifests[].checksum**

- Type: boolean

Whether to attach the manifest's checksum to that of the workload in order to force an automatic rollout when the manifest is updated.

**extraManifests[].data**

- Type: object or template string

The full content of the manifest.

[k8s-daemonset-updatestrategy]: https://kubernetes.io/docs/tasks/manage-daemon/update-daemon-set/
[k8s-deployment-strategy]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy
[k8s-hpa]: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
[k8s-ingress-class]: https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-class
[k8s-ingress-path-type]: https://kubernetes.io/docs/concepts/services-networking/ingress/#path-types
[k8s-ingress-tls]: https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
[k8s-ingress]: https://kubernetes.io/docs/concepts/services-networking/ingress/
[k8s-pdb]: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/
[k8s-pod-v1-containers]: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#containers
[k8s-pod-v1-pods]: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#PodSpec
[k8s-probes]: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
[k8s-service-clusterip]: https://kubernetes.io/docs/concepts/services-networking/service/#type-clusterip
[k8s-service]: https://kubernetes.io/docs/concepts/services-networking/service/
[k8s-statefulset-updatestrategy]: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#update-strategies
[k8s-volume-claim-templates]: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#volume-claim-templates
[varnish-cmdfile]: https://varnish-cache.org/docs/trunk/reference/varnishd.html#cli-command-file
[varnishd]: https://varnish-cache.org/docs/6.0/reference/varnishd.html
[varnishncsa]: https://varnish-cache.org/docs/6.0/reference/varnishncsa.html
