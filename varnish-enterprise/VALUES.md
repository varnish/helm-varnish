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

[k8s-pod-v1-containers]: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#containers
[k8s-pod-v1-pods]: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#PodSpec
