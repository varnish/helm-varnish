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

#### Values validation

Values are validated against `values.schema.json` when you run `helm install`, `upgrade`, `template` or `lint`. Unknown keys and values of the wrong type are rejected, and the error names the offending path, for example `at '/server': additional properties 'foo' not allowed`. Pass `--skip-schema-validation` to skip this check; the checks done by the chart templates still apply.

#### Using as a subchart

`varnish-cache` and `varnish-enterprise` share their named templates (`varnish-common.*`), and Helm keeps only one definition per template name. When both are dependencies of the same parent chart, depend on the same version of both: the two charts are always released together from the same sources, with the same version.

### Upgrading

#### To 1.9.0: user and group changed from 999 to 1000

The chart version jumps from 0.1.x to 1.9.0, as `varnish-cache` and `varnish-enterprise` are now released together, with the same version.

The containers now run as user 1000 with `fsGroup` 1000, the `varnish` user and group of the official image, instead of 999.

Kubernetes changes the group ownership of most volumes to the new `fsGroup` (`emptyDir`, ConfigMaps, Secrets and most block-backed PersistentVolumeClaims), but not of `hostPath` volumes, in-tree `nfs` volumes or CSI volumes whose driver ignores `fsGroup`. If you mount such volumes with `server.extraVolumes` and they hold files written by user 999, either change their ownership before upgrading (`chown -R 1000:1000 <path>`), or keep the previous IDs:

```yaml
global:
  podSecurityContext:
    fsGroup: 999
  securityContext:
    runAsUser: 999
```

The otel sidecar (`server.otel`) does not start with user 999, as it does not exist in the image.

On large PersistentVolumeClaims, setting `global.podSecurityContext.fsGroupChangePolicy: OnRootMismatch` avoids changing the ownership of every file each time a Pod starts.

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

<!-- BEGIN GENERATED VALUES -->
<!-- Generated from varnish-common/schema/values.schema.yaml by generate.py. Do not edit. -->

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
- Default: `{"fsGroup": 1000}`

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
- Default: `{"runAsUser": 1000, "runAsNonRoot": true}`

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

Applies extra annotations to all workloads. The value can be set as either an object or a template string. Workload annotations can be used for applying additional metadata or for integrating with external tooling. The annotations specified here will be applied to the workload itself.

To apply annotations on a Pod, use `global.podAnnotations`. To apply annotations on a specific workload, use `server.annotations`.

**global.podAnnotations**

- Type: object or template string

Applies extra annotations to all Pods. The value can be set as either an object or a template string. Pod annotations can be used for applying additional metadata or for integrating with external tooling. Annotations specified here will be applied to a Pod itself.

To apply annotations on a workload, use `global.annotations`. To apply annotations on a specific Pod, use `server.podAnnotations`.

**global.labels**

- Type: object or template string

Applies extra labels to all workloads. The value can be set as either an object or a template string. Workload labels can be used for applying additional metadata or for integrating with external tooling. The labels specified here will be applied to the workload itself.

To apply labels on a Pod, use `global.podLabels`. To apply labels on a specific workload, use `server.labels`.

**global.podLabels**

- Type: object or template string

Applies extra labels to all Pods. The value can be set as either an object or a template string. Pod labels can be used for applying additional metadata or for integrating with external tooling. Labels specified here will be applied to a Pod itself.

To apply labels on a workload, use `global.labels`. To apply labels on a specific Pod, use `server.podLabels`.

**global.resources**

- Type: object or template string

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

Specifies the number of replicas to deploy Varnish Cache server. The value is ignored if `server.kind` is "DaemonSet".

When `server.autoscaling.enabled` is set to `true`, and `server.autoscaling.minReplicas` is `-`, the value of `server.replicas` will be used. `server.replicas` is ignored if `server.autoscaling.minReplicas` is set to a number.

**server.kind**

- Type: string, one of `Deployment`, `DaemonSet`, or `StatefulSet`
- Default: `Deployment`

Specifies the type of workload to deploy Varnish Cache server. The value can be one of `Deployment`, `DaemonSet`, or `StatefulSet` depending on usage scenarios.

**server.labels**

- Type: object or template string

Applies extra labels to the workload. The value can be set as either an object or a template string. Labels specified here will be applied to the workload itself. To apply labels on the Pod, use `server.podLabels`.

**server.annotations**

- Type: object or template string

Applies extra annotations to the workload. The value can be set as either an object or a template string. Workload annotations can be used for applying additional metadata or for integrating with external tooling. The annotations specified here will be applied to the workload itself. To apply annotations on the Pod, use `server.podAnnotations`.

**server.strategy**

- Type: object or template string

Configures [deployment strategy][k8s-deployment-strategy] to replace existing Pod with a new one. This configuration is only available when `server.kind` is set to Deployment. For StatefulSet and DaemonSet, see `server.updateStrategy`.

**server.updateStrategy**

- Type: object or template string

Configures update strategy for updating Pods when a change is made to the manifest. This configuration is only available when `server.kind` is set to StatefulSet or DaemonSet. For Deployment, see `server.strategy`.

*Note: While both StatefulSet and DaemonSet share the same `updateStrategy` configuration key, its applicable values are different. See [updateStrategy on StatefulSet][k8s-statefulset-updatestrategy] and [updateStrategy on DaemonSet][k8s-daemonset-updatestrategy].*

**server.hostNetwork**

- Type: boolean
- Default: `false`

Whether to enable hostNetwork for the Varnish Cache Pod. This will make the Varnish Cache Pod bind to the port of the host instead of using a container network provided by Kubernetes.

Setting this will also set the DNS policy to `ClusterFirstWithHostNet` to allow the Pod to communicate with Kubernetes DNS.

**server.shareProcessNamespace**

- Type: boolean
- Default: `false`

Whether to enable shared PID namespace between all containers in a Pod. This is useful for a scenario where it is necessary to send a signal to a process across a container.

**server.workDir**

- Type: string or number

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

Configures the address on which Varnish will listen for HTTP traffic. Ignored when `server.http.podIP` is `true`.

**server.http.podIP**

- Type: boolean
- Default: `true`

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

Sets additional environment variables for the Varnish Cache container. The value can be set as an object, an array of objects, or a template string.

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

Sets the command for Varnish Cache. Note that by overriding this, you will also override parameters, listening ports, etc. See also [varnishd documentation][varnishd].

**server.extraArgs**

- Type: string or array of strings

Sets the extra arguments to varnishd. A string is split on whitespace into separate arguments, while each item of a list is passed as a single argument, so use a list for values containing spaces.

**server.parameters**

- Type: object

Sets Varnish Cache parameters (the `-p` argument of varnishd). Parameter names are converted from camelCase to snake_case, and arrays are joined with a comma.

For example, the following results in `-p backend_idle_timeout=60 -p feature=+http2`:

```yaml
server:
  parameters:
    backendIdleTimeout: "60"
    feature:
      - "+http2"
```

**server.extraInitContainers**

- Type: array or template string

An array of objects that conform to the Kubernetes [initContainers][k8s-pod-v1-pods] definition of a Pod. This can be used to run initialization tasks before varnishd starts. Note that `initContainers` cannot be changed once it is applied. To update this value after the initial deploy, uninstall Varnish Cache Helm Chart from the cluster and reinstall. The value can be set as either an array of objects or a template string.

For example:

```yaml
server:
  extraInitContainers: |
    - name: varnish-setup-tls
      securityContext:
        {{- toYaml .Values.global.securityContext | nindent 4 }}
      image: debian:latest
      command:
        - sh -c "sleep 3600"
```

**server.extraContainers**

- Type: array or template string

An array of objects that conforms to the Kubernetes [containers][k8s-pod-v1-pods] definition of a Pod. This can be used to add a sidecar container to varnishd. The value can be set as either an array of objects or a template string.

For example:

```yaml
server:
  extraContainers: |
    - name: varnish-hello
      securityContext:
        {{- toYaml .Values.global.securityContext | nindent 4 }}
      image: hello-world:latest
      volumeMounts:
        - name: {{ .Release.Name }}-varnish-vsm
          mountPath: /var/lib/varnish
```

**server.extraVolumeClaimTemplates**

- Type: array or template string

An array of objects that conforms to the Kubernetes [VolumeClaimTemplates][k8s-volume-claim-templates] definition of a StatefulSet workload. This configuration is only available when `server.kind` is set to StatefulSet.

For example:

```yaml
server:
  extraVolumeClaimTemplates: |
    - metadata:
        name: {{ .Release.Name }}-pv
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: "10G"
```

**server.extraVolumeMounts**

- Type: array or template string

An array of objects that conforms to the Kubernetes [volumeMounts][k8s-pod-v1-containers] definition of a Container. This configuration is used to mount extra volumes defined in `server.extraVolumes` into the Varnish Cache container. The value can be set as either an array of objects or a template string.

For example:

```yaml
server:
  extraVolumeMounts: |
    - name: {{ .Release.Name }}-local-data
      mountPath: /var/lib/data
```

**server.extraVolumes**

- Type: array or template string

An array of objects that conforms to the Kubernetes [volumes][k8s-pod-v1-pods] definition of a Pod. This configuration is used to define volumes to be used in `server.extraVolumeMounts`, or within `server.extraContainers`, or within `server.extraInitContainers`. The value can be set as either an array of objects or a template string.

For example:

```yaml
server:
  extraVolumes: |
    - name: {{ .Release.Name }}-local-data
      hostPath:
        path: /data
        type: Directory
```

**server.secret**

- Type: string

Sets the Varnish secret for accessing the varnishd admin interface. Either this value or `server.secretFrom` can be set. If unset, Varnish will generate one on every Pod start.

**server.secretFrom**

- Type: object

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

A path to the main VCL configuration. This configuration affects the location where `server.vclConfig` will be saved to, as well as the `VARNISH_VCL_CONF` environment variable in the Varnish Cache container.

**server.vclConfig**

- Type: template string

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

A path to the [CLI command file][varnish-cmdfile]. This configuration affects the location where `server.cmdfileConfig` will be saved to, as well as the `-I` argument in the Varnish Cache container when `server.cmdfileConfig` is not empty.

**server.cmdfileConfig**

- Type: template string

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

Sets the termination grace period seconds to wait for Varnish Cache to shut down. Once this number of seconds is reached without the Varnish Cache Pod shutting down, Kubernetes will send SIGKILL to the Pod. When `server.delayedShutdown` is used, this value should be set to a higher value than the **maximum** time (in seconds) it took for Varnish Cache to fully shut down after a delayed shutdown.

The value to set here depends on the cluster setup. For example, an AWS Load Balancer may still forward requests to Varnish for `deregistration_delay.timeout_seconds` which is set to 300 seconds by default. If `server.delayedShutdown` took 30 seconds, then `server.terminationGracePeriodSeconds` should be set to _at least_ 330 seconds in order to have a zero-downtime during a rolling update or scaling down.

**server.delayedHaltSeconds**

- Type: number

Deprecated: use `server.delayedShutdown` instead.

Delays stopping of the Varnish Cache container by the given seconds.

**server.delayedShutdown**

- Type: object

Configures delayed shutdown for zero-downtime downscaling.

**server.delayedShutdown.method**

- Type: string, one of `none`, `sleep`, or `mempool`
- Default: `none`
- Availability: v1.1.0

Sets the method for delaying the shutdown of Varnish Cache. This is useful for rolling updates or when scaling down, where the load balancer component may still attempt to forward requests to the Varnish Cache instance when Varnish Cache has already received a SIGHUP, leading to HTTP 502 errors.

Multiple methods are provided here:

- `sleep` will simply sleep in the `preStop` for `server.delayedShutdown.sleep.seconds` seconds. This is the simplest way to delay the shutdown of Varnish Cache when the time taken for the load balancer component to stop forwarding traffic to Varnish Cache is largely fixed.
- `mempool` polls varnishstat for `MEMPOOL.sess` to go down to zero. This allows for the quickest shutdown but requires tuning `server.delayedShutdown.mempool.pollSeconds` to traffic patterns (as `MEMPOOL.sess` may become 0 momentarily, resulting in an early shutdown).

When `server.delayedShutdown.method` is set to a value other than "none", `server.terminationGracePeriodSeconds` **must** also be set.

**server.delayedShutdown.sleep**

- Type: object

Configures the "sleep" delayed shutdown method.

**server.delayedShutdown.sleep.seconds**

- Type: number or string
- Default: `90`
- Availability: v1.1.0

Sets the number of seconds to sleep before SIGHUP is sent to Varnish Cache. Only applicable when `server.delayedShutdown.method` is set to "sleep".

**server.delayedShutdown.mempool**

- Type: object

Configures the "mempool" delayed shutdown method.

**server.delayedShutdown.mempool.pollSeconds**

- Type: number or string
- Default: `1`
- Availability: v1.1.0

Sets the number of seconds to poll for `MEMPOOL.sess` stats. Only applicable when `server.delayedShutdown.method` is set to "mempool".

This value requires tuning to traffic patterns. If the time between each traffic took more than `server.delayedShutdown.mempool.pollSeconds`, then Varnish Cache could be signaled to SIGHUP too early, leading to an HTTP 502 error on the load balancer (as Varnish Cache already stopped accepting connection).

**server.delayedShutdown.mempool.waitSeconds**

- Type: number or string
- Default: `5`
- Availability: v1.1.0

Sets the number of seconds to wait after `MEMPOOL.sess` turned zero. Only applicable when `server.delayedShutdown.method` is set to "mempool".

**server.image**

- Type: object

Sets the image and tag to use to deploy Varnish Cache.

**server.image.repository**

- Type: string
- Default: `docker.io/varnish`

Sets the repository for Varnish Cache image.

**server.image.pullPolicy**

- Type: string
- Default: `IfNotPresent`

Sets the [imagePullPolicy][k8s-pod-v1-containers] for the Varnish Cache image. This can be one of Always, Never, or IfNotPresent.

**server.image.tag**

- Type: string or number
- Default: _same as appVersion_

Sets the tag for the Varnish Cache image. By default, this is set to the same application version as in the Varnish Cache Helm Chart. If the tag is set to non-exact versions (such as "latest"), make sure to set `server.image.pullPolicy` to "Always" to make sure the image is always updated.

**server.autoscaling**

- Type: object

An object for configuring [HorizontalPodAutoscaling][k8s-hpa].

**server.autoscaling.enabled**

- Type: boolean
- Default: `false`

Enables the [HorizontalPodAutoscaling][k8s-hpa] with the Varnish Cache Pod. `server.replicas` is ignored if autoscaling is enabled.

**server.autoscaling.minReplicas**

- Type: number or "-"
- Default: `1`

Sets the minimum number of replicas to always keep running. When set to "-", the value of `server.replicas` is used.

**server.autoscaling.maxReplicas**

- Type: number
- Default: `100`

Sets the maximum number of replicas to run at most.

**server.autoscaling.behavior**

- Type: object or template string
- Availability: v1.1.0

Sets the [HorizontalPodAutoscaling][k8s-hpa] behavior. The value can be set as either an object or a template string.

For example:

```yaml
server:
  autoscaling:
    behavior:
      scaleDown:
        stabilizationWindowSeconds: 120
        policies:
          - type: Percent
            value: 50
            periodSeconds: 60
      scaleUp:
        policies:
          - type: Percent
            value: 100
            periodSeconds: 60
          - type: Pods
            value: 4
            periodSeconds: 60
        selectPolicy: Max
```

**server.autoscaling.metrics**

- Type: array or template string

Sets the [HorizontalPodAutoscaling][k8s-hpa] metrics. The value can be set as either an array or a template string.

For example:

```yaml
server:
  autoscaling:
    metrics: |
      - type: Resource
        resource:
          name: cpu
          targetAverageUtilization: 80
```

**server.pdb**

- Type: object

An object for configuring [PodDisruptionBudget][k8s-pdb]. See also [Specifying a Disruption Budget for your Application](https://kubernetes.io/docs/tasks/run-application/configure-pdb/).

**server.pdb.enabled**

- Type: boolean
- Default: `false`

Enables PodDisruptionBudget.

**server.pdb.minAvailable**

- Type: string or number

Sets the number or percentage of pods that must be available after the eviction. Required if `server.pdb.enabled` is true and `server.pdb.maxUnavailable` is not set.

**server.pdb.maxUnavailable**

- Type: string or number

Sets the number or percentage of pods that can be unavailable after the eviction. Required if `server.pdb.enabled` is true and `server.pdb.minAvailable` is not set.

**server.service**

- Type: object

An object for configuring [Service][k8s-service].

**server.service.enabled**

- Type: boolean
- Default: `true`

Enables the [Service][k8s-service] for Varnish Cache.

**server.service.labels**

- Type: object or template string

Applies extra labels to the Service. The value can be set as either an object or a template string.

**server.service.annotations**

- Type: object or template string

Applies extra annotations to the Service. The value can be set as either an object or a template string.

**server.service.type**

- Type: string
- Default: `NodePort`

Sets the type of the Service. Can be either `ClusterIP`, `LoadBalancer`, or `NodePort`.

See also [Accessing Varnish Enterprise in Kubernetes Cluster](https://docs.varnish-software.com/varnish-helm/guides/accessing-varnish-enterprise/).

**server.service.clusterIP**

- Type: string

Sets a custom [Service ClusterIP][k8s-service-clusterip]. This value can be set as either an IP address, or a literal string "None". Only applicable when `server.service.type` is set to ClusterIP. When set to "None", Kubernetes will create a Headless Service, skipping the Kubernetes proxying mechanism. In such case, `server.service.http.port` and `server.service.https.port` are ignored, and `server.http.port` and `server.tls.port` are used instead.

See also [Accessing Varnish Enterprise in Kubernetes Cluster](https://docs.varnish-software.com/varnish-helm/guides/accessing-varnish-enterprise/).

**server.service.loadBalancerIP**

- Type: string

Sets a pre-allocated IP address for use in LoadBalancer.

**server.service.http**

- Type: object

Enables or disables the Varnish HTTP service.

**server.service.http.enabled**

- Type: boolean
- Default: `true`

Enables HTTP service. Requires `server.http.enabled`.

**server.service.http.port**

- Type: number
- Default: `80`

Sets the port to expose HTTP service.

**server.service.http.nodePort**

- Type: number

Sets the port to expose HTTP service directly on the node itself. Only applicable when `server.service.type` is set to NodePort. This value must be within the Kubernetes service-node-port-range (default: 30000-32767).

See also [Accessing Varnish Enterprise in Kubernetes Cluster](https://docs.varnish-software.com/varnish-helm/guides/accessing-varnish-enterprise/).

**server.service.https**

- Type: object

Enables or disables the Varnish HTTPS service.

**server.service.https.enabled**

- Type: boolean
- Default: `false`

Enables HTTPS service. Requires `server.tls.enabled`.

**server.service.https.port**

- Type: number
- Default: `443`

Sets the port to expose HTTPS service.

**server.service.https.nodePort**

- Type: number

Sets the port to expose HTTPS service directly on the node itself. Only applicable when `server.service.type` is set to NodePort. This value must be within the Kubernetes service-node-port-range (default: 30000-32767).

See also [accessing Varnish via NodePort](https://docs.varnish-software.com/varnish-helm/guides/accessing-varnish-enterprise/#nodeport).

**server.service.extraServices**

- Type: array of objects

An array of extra services to expose via the Service. Each extra service adds a port named `extra-<name>` to the Service.

For example:

```yaml
server:
  service:
    extraServices:
      - name: proxy
        targetPort: 8088
        port: 8088
        nodePort: 30888
```

**server.service.extraServices[].name**

- Type: string

Sets the name of the extra service. Required.

**server.service.extraServices[].targetPort**

- Type: number

Sets the port in the Pod to forward requests to. It must also be defined in `server.extraListens`. Required.

**server.service.extraServices[].port**

- Type: number

Sets the port to expose this extra service. Required unless the Service is headless (`server.service.clusterIP` set to "None"), in which case `targetPort` is used instead.

**server.service.extraServices[].nodePort**

- Type: number

Sets the port to expose this extra service on the node itself. Only applicable when `server.service.type` is set to NodePort. This value must be within the Kubernetes service-node-port-range (default: 30000-32767).

**server.service.internalTrafficPolicy**

- Type: string
- Default: `Cluster`

Sets the internal traffic policy for this service. InternalTrafficPolicy describes how nodes distribute service traffic they receive on the ClusterIP. Can be set to `Local` or `Cluster`. If unset, the Kubernetes default (`Cluster`) is used.

**server.service.externalTrafficPolicy**

- Type: string
- Default: `Cluster`

Sets the external traffic policy for this service. externalTrafficPolicy describes how nodes distribute service traffic they receive on one of the Service's "externally-facing" addresses (NodePorts, ExternalIPs, and LoadBalancer IPs). Can be set to `Local` or `Cluster`.

**server.ingress**

- Type: object

An object for configuring [Ingress][k8s-ingress].

**server.ingress.enabled**

- Type: boolean
- Default: `false`

Enables the [Ingress][k8s-ingress] for Varnish Cache. Requires `server.service.http.enabled` and `server.service.http.port`.

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

Sets the [Ingress Path Type][k8s-ingress-path-type] for the Varnish Cache endpoint. The value can be either `Prefix`, `Exact`, or `ImplementationSpecific`. The value to use here depends on the Ingress controller.

**server.ingress.hosts**

- Type: array of objects

Sets the hostnames for the Ingress. These hostnames are used for routing traffic.

For example:

```yaml
server:
  ingress:
    hosts:
      - host: chart-example.local
        paths: []
```

**server.ingress.hosts[].host**

- Type: string

Sets the hostname to route traffic for.

**server.ingress.hosts[].paths**

- Type: array of strings

Sets the paths to route to Varnish Cache for this host, as an array of strings. Defaults to `/` when empty.

**server.ingress.tls**

- Type: array of objects

An array of objects that conforms to [Ingress TLS][k8s-ingress-tls].

For example:

```yaml
server:
  ingress:
    tls:
      - secretName: chart-example-tls
        hosts:
          - chart-example.local
```

**server.podAnnotations**

- Type: object or template string

Applies extra annotations to the Pod. The value can be set as either an object or a template string. Pod annotations can be used for applying additional metadata or for integrating with external tooling. Annotations specified here will be applied to the Pod. To apply annotations on the workload, use `server.annotations`.

For example:

```yaml
server:
  podAnnotations:
    prometheus.io/scrape: "true"
    prometheus.io/path: /metrics
    prometheus.io/port: "9273"
    prometheus.io/scheme: http
```

**server.podLabels**

- Type: object or template string

Applies extra labels to the Pod. The value can be set as either an object or a template string. Labels specified here will be applied to the Pod itself. To apply labels on the workload, use `server.labels`.

For example:

```yaml
server:
  podLabels:
    varnish-software.com/tier: edge
```

**server.securityContext**

- Type: object or template string

An object that conforms to the Kubernetes [securityContext][k8s-pod-v1-containers] definition of a Container.

This securityContext will be set on the Varnish Cache container. For setting securityContext on the Pod itself, see `global.podSecurityContext`. For setting securityContext to all containers, see `global.securityContext`.

For example:

```yaml
server:
  securityContext:
    runAsUser: 1000
```

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
    httpGet:
      path: /health
      httpHeaders:
        - name: Host
          value: example.com
```

**server.startupProbe.httpGet**

- Type: object

Uses Kubernetes [httpGet probe][k8s-probes] instead of TCP probe. Port will be automatically injected. It is possible to provide extra configuration options that conforms to the Kubernetes httpGet probe definition.

The Varnish Cache Helm chart doesn't provide a default health check endpoint, so it is necessary to configure Varnish Cache to return 200 OK for this endpoint via a VCL. For example:

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

For example, to enable httpGet probe mode:

```yaml
server:
  startupProbe:
    httpGet: {}
```

To specify path and add extra headers:

```yaml
server:
  startupProbe:
    httpGet:
      path: /healthz
      httpHeaders:
        - name: X-Health-Check
          value: k8s
```

**server.readinessProbe**

- Type: object

An object that conforms to the Kubernetes [readinessProbe][k8s-pod-v1-containers] definition of a Container.

For example:

```yaml
server:
  readinessProbe:
    httpGet:
      path: /health
      httpHeaders:
        - name: Host
          value: example.com
```

**server.readinessProbe.httpGet**

- Type: object

Uses Kubernetes [httpGet probe][k8s-probes] instead of TCP probe. Port will be automatically injected. It is possible to provide extra configuration options that conforms to the Kubernetes httpGet probe definition.

See also `server.startupProbe.httpGet`.

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

An object that conforms to the Kubernetes [livenessProbe][k8s-pod-v1-containers] definition of a Container.

For example:

```yaml
server:
  livenessProbe:
    httpGet:
      path: /health
      httpHeaders:
        - name: Host
          value: example.com
```

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

- Type: object or template string

An object that conforms to the Kubernetes [resources][k8s-pod-v1-containers] definition of a Container. This configuration can be used to limit resources consumed by the Varnish Cache container.

For example:

```yaml
server:
  resources:
    limits:
      cpu: "100m"
      memory: "128Mi"
    requests:
      cpu: "100m"
      memory: "128Mi"
```

**server.nodeSelector**

- Type: object or template string

An object that conforms to the Kubernetes [nodeSelector][k8s-pod-v1-pods] definition of a Pod. This configuration is used to select a node to schedule a Pod to. The value can be set as either an object or a template string.

For example:

```yaml
server:
  nodeSelector:
    beta.kubernetes.io/arch: amd64
```

**server.tolerations**

- Type: array or template string

An array of objects that conforms to the Kubernetes [tolerations][k8s-pod-v1-pods] definition of a Pod. This configuration is used to allow the Pod to be scheduled to nodes with specific taints. The value can be set as either an array of objects or a template string.

**server.affinity**

- Type: object or template string
- Default: template string:
    ```yaml
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app.kubernetes.io/name: {{ include "varnish-common.name" . }}
              app.kubernetes.io/instance: {{ .Release.Name }}
          topologyKey: kubernetes.io/hostname
    ```

This configuration is used to fine-grain control the scheduling of the Pod. By default, this is set to ensure all Varnish Cache Pods are always run in a different node. To disable this behavior, set to empty string (""). The value can be set as either an object or a template string.

**server.networkPolicy**

- Type: object

An object for configuring the [NetworkPolicy][k8s-networkpolicy] of the Varnish Cache Pods.

**server.networkPolicy.enabled**

- Type: boolean
- Default: `false`

Enables the NetworkPolicy.

**server.networkPolicy.allowIngress**

- Type: boolean
- Default: `true`

Allows all connections from any source. Set to false when using `server.networkPolicy.extraIngress`.

**server.networkPolicy.allowEgress**

- Type: boolean
- Default: `true`

Allows all connections to any destination. Set to false when using `server.networkPolicy.extraEgress`.

**server.networkPolicy.extraIngress**

- Type: array of objects

An array of ingress rules that conforms to the Kubernetes [NetworkPolicyIngressRule][k8s-networkpolicy-v1] definition. Only used when `server.networkPolicy.allowIngress` is false.

For example:

```yaml
server:
  networkPolicy:
    extraIngress:
      - from:
          - podSelector:
              matchLabels:
                component: apache
        ports:
          - port: 8080
            protocol: TCP
```

**server.networkPolicy.extraEgress**

- Type: array of objects

An array of egress rules that conforms to the Kubernetes [NetworkPolicyEgressRule][k8s-networkpolicy-v1] definition. Only used when `server.networkPolicy.allowEgress` is false.

For example:

```yaml
server:
  networkPolicy:
    extraEgress:
      - to:
          - podSelector:
              matchLabels:
                component: apache
        ports:
          - port: 80
            protocol: TCP
```

**server.varnishncsa**

- Type: object

An object for configuring [varnishncsa][varnishncsa].

**server.varnishncsa.enabled**

- Type: boolean
- Default: `true`

Enables HTTP request logging via [varnishncsa][varnishncsa].

**server.varnishncsa.image**

- Type: object

Sets the image and tag to use to deploy the varnishncsa sidecar. Setting a field to "-" inherits it from `server.image`.

**server.varnishncsa.image.repository**

- Default: `-`

Sets the repository for Varnish Cache image for use with varnishncsa. The Varnish image used here must be the same version as the Varnish Cache server. Set this to "-" to inherit the value of `server.image.repository`.

**server.varnishncsa.image.pullPolicy**

- Default: `-`

Sets the [imagePullPolicy][k8s-pod-v1-containers] for the Varnish Cache image for use with varnishncsa. This can be one of Always, Never, or IfNotPresent. Set this to "-" to inherit the value of `server.image.pullPolicy`.

**server.varnishncsa.image.tag**

- Default: `-`

Sets the tag for the Varnish Cache image for use with varnishncsa. The Varnish image used here must be the same version as the Varnish Cache server. Set this to "-" to inherit the value of `server.image.tag`.

**server.varnishncsa.securityContext**

- Type: object or template string

An object that conforms to the Kubernetes [securityContext][k8s-pod-v1-containers] definition of a Container.

This securityContext will be set on the varnishncsa container. For setting securityContext on the Pod itself, see `global.podSecurityContext`. For setting securityContext to all containers, see `global.securityContext`.

For example:

```yaml
server:
  varnishncsa:
    securityContext:
      runAsUser: 1000
```

**server.varnishncsa.extraArgs**

- Type: string or array of strings
- Default: `["-c"]`

Sets the extra arguments to varnishncsa.

**server.varnishncsa.extraEnvs**

- Type: array of objects, object, or template string

Sets additional environment variables for the varnishncsa container. Can be set as an object, an array of objects, or a template string.

For example, as an object:

```yaml
server:
  varnishncsa:
    extraEnvs:
      MY_ENV_VAR: value
      MY_OTHER_ENV_VAR: other_value
```

As an array of objects:

```yaml
server:
  varnishncsa:
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
  varnishncsa:
    extraEnvs: |
      - name: RELEASE_NAMESPACE
        value: {{ .Release.Namespace }}
```

**server.varnishncsa.startupProbe**

- Type: object

An object that conforms to the Kubernetes [startupProbe][k8s-pod-v1-containers] definition of a Container. The probe is disabled when empty. The probe command is set by the chart.

For example:

```yaml
server:
  varnishncsa:
    startupProbe:
      periodSeconds: 5
      failureThreshold: 10
```

**server.varnishncsa.readinessProbe**

- Type: object

An object that conforms to the Kubernetes [readinessProbe][k8s-pod-v1-containers] definition of a Container.

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

An object that conforms to the Kubernetes [livenessProbe][k8s-pod-v1-containers] definition of a Container.

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

- Type: object or template string

An object that conforms to the Kubernetes [resources][k8s-pod-v1-containers] definition of a Container. This configuration can be used to limit resources consumed by the varnishncsa container.

For example:

```yaml
server:
  varnishncsa:
    resources:
      limits:
        cpu: "100m"
        memory: "128Mi"
      requests:
        cpu: "100m"
        memory: "128Mi"
```

**server.varnishncsa.extraVolumeMounts**

- Type: array or template string

An array of objects that conforms to the Kubernetes [volumeMounts][k8s-pod-v1-containers] definition of a Container. This configuration is used to mount extra volumes defined in `server.extraVolumes` into the varnishncsa container. The value can be set as either an array of objects or a template string.

For example:

```yaml
server:
  varnishncsa:
    extraVolumeMounts: |
      - name: {{ .Release.Name }}-logs
        mountPath: /var/log/varnish
```

**server.otel**

- Type: object

An object for configuring the Varnish OTEL sidecar.

**server.otel.enabled**

- Type: boolean
- Default: `false`

Runs `/usr/bin/varnish-otel` in a sidecar container to export Varnish logs and metrics to an OTLP (OpenTelemetry Protocol) endpoint. `varnish-otel` is included in the official `varnish` image since 9.0.3.

**server.otel.image**

- Type: object

Sets the image and tag to use to deploy the Varnish OTEL sidecar. Setting a field to "-" inherits it from `server.image`.

**server.otel.image.repository**

- Default: `-`

Sets the image repository of the OTEL sidecar. The image must be the same Varnish version as the server. When set to "-", `server.image.repository` is used.

**server.otel.image.pullPolicy**

- Default: `-`

Sets the [imagePullPolicy][k8s-pod-v1-containers] of the OTEL sidecar. When set to "-", `server.image.pullPolicy` is used.

**server.otel.image.tag**

- Default: `-`

Sets the image tag of the OTEL sidecar. When set to "-", `server.image.tag` is used.

**server.otel.securityContext**

- Type: object or template string

An object that conforms to the Kubernetes [securityContext][k8s-pod-v1-containers] definition of a Container. This securityContext will be set on the OTEL container. For setting securityContext on the Pod itself, see `global.podSecurityContext`. For setting securityContext to all containers, see `global.securityContext`.

**server.otel.resources**

- Type: object or template string

An object that conforms to the Kubernetes [resources][k8s-pod-v1-containers] definition of a Container. This configuration can be used to limit resources consumed by the OTEL container.

**server.otel.env**

- Type: array of objects, object, or template string

Sets environment variables of the OTEL container, typically to configure the OpenTelemetry exporters. See also the [OpenTelemetry environment variables specification](https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/). Can be set as an object, an array of objects, or a template string.

For example:

```yaml
server:
  otel:
    env:
      OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector:4318"
```

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
[k8s-hpa]: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
[k8s-ingress]: https://kubernetes.io/docs/concepts/services-networking/ingress/
[k8s-ingress-class]: https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-class
[k8s-ingress-path-type]: https://kubernetes.io/docs/concepts/services-networking/ingress/#path-types
[k8s-ingress-tls]: https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
[k8s-networkpolicy]: https://kubernetes.io/docs/concepts/services-networking/network-policies/
[k8s-networkpolicy-v1]: https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/network-policy-v1/#NetworkPolicySpec
[k8s-pdb]: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/
[k8s-pod-v1-containers]: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#containers
[k8s-pod-v1-pods]: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#PodSpec
[k8s-probes]: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
[k8s-service]: https://kubernetes.io/docs/concepts/services-networking/service/
[k8s-service-clusterip]: https://kubernetes.io/docs/concepts/services-networking/service/#type-clusterip
[k8s-statefulset-updatestrategy]: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#update-strategies
[k8s-volume-claim-templates]: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#volume-claim-templates
[varnish-cmdfile]: https://varnish-cache.org/docs/trunk/reference/varnishd.html#cli-command-file
[varnishd]: https://varnish-cache.org/docs/6.0/reference/varnishd.html
[varnishncsa]: https://varnish-cache.org/docs/6.0/reference/varnishncsa.html

<!-- END GENERATED VALUES -->

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
