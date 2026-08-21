# The Varnish Orca Helm Chart

This Helm Chart deploys *Varnish Orca* on a Kubernetes cluster.

## Deploying Varnish Orca using Helm

Run the following `helm install` command to deploy *Varnish Orca* to your Kubernetes cluster:

```sh
helm install varnish-orca oci://docker.io/varnish/orca-chart
```

## Customizing Helm Chart Values

You can customize your Helm deployment by overriding the default configuration values.

The `--set` argument can be used to add configuration values on the command line:

```sh
helm install varnish-orca oci://docker.io/varnish/orca-chart \
 --set "orca.varnish.http[0].port=81" \
 --set "service.http.port=81"
```

Or simply add `-f values.yaml` to override load the configuration overrides from a `values.yaml` file:

```sh
helm install -f values.yaml varnish-orca oci://docker.io/varnish/orca-chart
```

Here's an example `values.yaml` file:

```yaml
service:
  http:
    port: 81
orca:
  varnish:
    http:
    - port: 81
```

### Here's the complete list of configuration values you can override:

| Key | Type | Default | Description |
|---|---|---|---|
| `affinity` | object | `{}` |  |
| `autoscaling.enabled` | bool | `false` |  |
| `autoscaling.maxReplicas` | int | `100` |  |
| `autoscaling.minReplicas` | int | `1` |  |
| `autoscaling.targetCPUUtilizationPercentage` | int | `80` |  |
| `extraEnvs` | object | `{}` | Set extra environment variables |
| `fullnameOverride` | string | `""` |  |
| `image.pullPolicy` | string | `"IfNotPresent"` |  |
| `image.repository` | string | `"docker.io/varnish/orca"` | |
| `image.tag` | string | `latest` | |
| `imagePullSecrets` | list | `[]` |  |
| `ingress.annotations` | object | `{}` | |
| `ingress.className` | string | `""` | The name of the Ingress Controller to use. Typically `nginx` or `traefik`  |
| `ingress.enabled` | bool | `false` | Enable ingress |
| `ingress.hosts[0].host` | string | `"varnish-orca.local"` | The default ingress hostname  |
| `ingress.hosts[0].paths[0]` | string | `"/"` |  |
| `ingress.hosts[0].paths[0].pathType` | string | `"Prefix"` |  |
| `ingress.tls` | list | `[]` |  |
| `kind` | string | `"Deployment"` | Workload kind, either `"Deployment"` or `"StatefulSet"`. `StatefulSet` provides stable per-pod DNS via a headless companion service and is the safe choice for horizontally scaling a persistent cache. |
| `livenessProbe` | object | `{"httpGet":{"path":"/healthz","port":"http"}}` | Liveness probe for the Orca container. Set to `null` to drop it. Suspended while the startup probe is still failing. |
| `nameOverride` | string | `""` |  |
| `nodeSelector` | object | `{}` |  |
| `podAnnotations` | object | `{}` |  |
| `podLabels` | object | `{}` |  |
| `podSecurityContext` | object | `{}` |  |
| `readinessProbe` | object | `{"httpGet":{"path":"/readyz","port":"http"}}` | Readiness probe for the Orca container. Set to `null` to drop it. Suspended while the startup probe is still failing. |
| `replicaCount` | int | `1` | Pod replicas |
| `resources` | object | `{}` | CPU and memory resources to allocate to the pod |
| `securityContext` | object | `{}` |  |
| `service.type` | string | `"ClusterIP"` |  |
| `service.http.enabled` | bool | `true` | Enable or disable the HTTP service |
| `service.http.port` | int | `80` | The service port for HTTP traffic |
| `service.http.nodePort` | int | empty | The service port to assign on the node in case of a `"NodePort"` service type. Leave empty for a random port number. |
| `service.https.enabled` | bool | `false` | Enable or disable the HTTPS service |
| `service.https.port` | int | `443` | The service port for HTTPS traffic |
| `serviceAccount.annotations` | object | `{}` | |
| `serviceAccount.automount` | bool | `true` |  |
| `serviceAccount.create` | bool | `true` |  |
| `serviceAccount.name` | string | `""` |  |
| `startupProbe` | object | See [values.yaml](values.yaml) | Startup probe for the Orca container, with a 5 minute budget (`failureThreshold` times `periodSeconds`). Raise `failureThreshold` if you add virtual registries or run on a slow or contended node. Set to `null` to drop it. |
| `storage.accessModes` | list | `["ReadWriteOnce"]` | Access modes applied to every cache PVC the chart creates |
| `storage.annotations` | object | `{}` | Extra annotations applied to every cache PVC the chart creates |
| `storage.labels` | object | `{}` | Extra labels applied to every cache PVC the chart creates |
| `storage.storageClassName` | string | `""` | StorageClass applied to every cache PVC the chart creates. Empty uses the cluster default. |
| `orca.acme` | object | `{}` | Generate [ACME TLS certificates](https://github.com/varnish/orca/blob/main/docs/configuration/acme.md) inside the *Varnish Orca* pod.
| `orca.virtual_registry` | object | See below | Orca virtual registry settings | [Virtual Registry configuration](https://github.com/varnish/orca/blob/main/docs/configuration/virtual-registry.md)
| `orca.git_mirror` | object | `{}` | Deploy a Git mirror alongside Orca for Git caching |
| `orca.license.secret` | string | `""` | The Kubernetes secret where the license for Orca is stored. The secret will be mounted into the pod.
| `orca.otel` | object | `{}` | Orca [OpenTelemetry configuration](https://github.com/varnish/orca/blob/main/docs/configuration/otel.md)
| `orca.supervisor` | object | `{}` | Orca [supervisor settings](https://github.com/varnish/orca/blob/main/docs/configuration/supervisor.md)
| `orca.varnish` | object | `{}` | Orca's underlying [Varnish configuration](https://github.com/varnish/orca/blob/main/docs/configuration/varnish.md)
| `orca.varnish.http[0].port` | int | `80` | On what port(s) should Varnish listen for HTTP requests
| `orca.varnish.storage.stores` | list | `[]` | Persistent cache stores. Each entry gets a PVC sized to `size` and mounted at `path`. See [Deploying with persistent storage](#deploying-with-persistent-storage). |
| `tolerations` | list | `[]` |  |
| `volumeMounts` | list | `[]` |  |
| `volumes` | list | `[]` |  |

This is the standard `orca` configuration in `values.yaml`:

```yaml
orca:
  acme: {}
  git_mirror: {}
  license:
    secret: ""
  otel: {}
  supervisor: {}
  varnish:
    http:
    - port: 80
  virtual_registry:
    registries:
    - name: dockerhub
      default: true
      remotes:
      - url: https://docker.io
    - name: quay
      remotes:
      - url: https://quay.io
    - name: ghcr
      remotes:
      - url: https://ghcr.io
    - name: k8s
      remotes:
      - url: https://registry.k8s.io
    - name: npmjs
      remotes:
      - url: https://registry.npmjs.org
    - name: go
      remotes:
      - url: https://proxy.golang.org
    - name: github
      remotes:
      - url: https://github.com
    - name: gitlab
      remotes:
      - url: https://gitlab.com
```

## Startup time and probes

A cold *Varnish Orca* pod is not ready the moment the container starts. It compiles one VCL group per entry in `orca.virtual_registry.registries`, roughly 4 seconds each, and the artifact firewall performs an initial ruleset sync that blocks startup. That sync takes seconds against a warm cache, but it can take several minutes on a cold one, longer still when several replicas compete for the same CPU.

The chart handles this with a startup probe rather than by padding the liveness and readiness probes. Kubernetes suspends both of those for as long as a startup probe is still failing, so a slow first boot never trips a restart, and readiness keeps the pod out of the main Service until it can actually serve.

The headless companion Service that `kind: StatefulSet` creates is deliberately exempt: it sets `publishNotReadyAddresses: true`, so each pod's stable DNS name resolves throughout startup. That is what makes a pod addressable before it is ready, which is the point of the headless Service. Only the main Service gates on readiness.

The default budget is 5 minutes, `failureThreshold: 60` at `periodSeconds: 5`. If your pods are killed mid-boot with `Startup probe failed`, raise `failureThreshold`:

```sh
helm install varnish-orca oci://docker.io/varnish/orca-chart \
 --set "startupProbe.failureThreshold=180"
```

The liveness probe asks `/healthz`, which reports that the process is up. The readiness and startup probes ask `/readyz`, which reports that the pod can actually serve traffic. Keeping the startup probe on `/readyz` also means a pod that never finishes booting is eventually restarted, rather than sitting live but useless because `/healthz` keeps answering.

All three probes address the listener by name as `http`, which always refers to the first entry in `orca.varnish.http`. Any probe can be dropped by setting it to `null`.

## Deploying a custom license

To deploy a custom license to *Varnish Orca*, you first need to create a secret in Kubernetes which contains the license file.

Run the following command to store the license file as a secret:

```sh
kubectl create secret generic varnish-orca-license \
--from-file=./license.lic
```

You can now configure the Helm Chart to load that license file into *Varnish Orca*. This can either be done in `values.yaml`:

```yaml
orca:
  license:
    secret: varnish-orca-license
```

Or you can use `--set "orca.license.secret=varnish-orca-license"` directly in your `helm install` command.

## Deploying LetsEncrypt certificates

The Orca Helm Chart supports [LetsEncrypt](https://letsencrypt.org/) certificates. These are mutually exclusive with the regular certificate configuration. Using LetsEncrypt in Orca requires an `acme` configuration definition and an adjustment to the listening ports.

Here's an example configuration in `values.yaml` that uses LetsEncrypt:

```yaml
orca:
  varnish:
    https:
    - port: 443
  acme:
    email: user@domain.com
    domains:
      - your-domain.com
      - www.your-domain.com
      - sub.your-domain.com
    ca_server: production
```

* Make sure that all domains in the `domains` configuration property resolve to the IP address of your Orca cluster.
* The `http` port of the `varnish` section needs to be removed, because the AMCE implementation needs it for HTTP validation and HTTPS redirection.
* The `email` property should contain a valid e-mail address.
* The `domains` property contains a list of domains for which a TLS certificate needs to be generated.
* The `ca_server` property should either be `production` or `staging`.

When you deploy the Orca Helm Chart with these values, the TLS certificates are automatically generated and made available on port `443` for HTTPS access. Although not explicitly defined, port `80` is managed by the ACME service and will redirect all plain HTTP requests to their HTTPS equivalent.

## Deploying a custom TLS certificate

While you could leverage Ingress to offload TLS, you can also deploy a custom TLS certificate to *Varnish Orca*.

Run the following command to store the certificate file as a secret:

```sh
kubectl create secret tls varnish-orca-certificate \
--cert=cert.crt --key=private.key
```

You can now configure the Helm Chart to load that license file into *Varnish Orca* by adding the following config to your `values.yaml`:

```yaml
service:
  https:
    enabled: true
orca:
  varnish:
    https:
    - port: 443
      certificates:
      - secret: varnish-orca-certificate
```

Not only does this config mount the certificate into the pod from the `varnish-orca-certificate`, it also exposes port `443` as a service within your Kubernetes cluster.

## Deploying with persistent cache

By default Orca uses a memory-only cache. Adding entries to `orca.varnish.storage.stores` enables MSE4 persistent cache in addition to the memory cache. Persistent cache requires `kind: StatefulSet`. Each replica gets its own PVC (one per ordinal) via `volumeClaimTemplates`, plus a stable per-pod DNS name from a headless companion service.

For each store:

* The StatefulSet creates a PVC per replica, sized to `size`.
* The PVC is mounted at `path` inside the pod. Orca treats `path` as a directory and creates the MSE4 book/store files (`<store-name>_book`, `<store-name>_store`) inside it.
* Defaults like `storageClassName` and `accessModes` come from the top-level `storage:` block and apply to every store.

Each store's `size` must be strictly greater than `book_size` + 1G filesystem overhead. `book_size` defaults to 5G, so `size` must be greater than 6G unless `book_size` is overridden.

`size` is interpreted in Varnish format (binary `K`/`M`/`G`/`T`, e.g. `100G` is 100 * 2^30 bytes). The chart translates this to the equivalent Kubernetes binary quantity for the PVC (`100G` becomes `100Gi`), so the PVC and the cache files always agree on size.

```yaml
kind: StatefulSet
replicaCount: 3
orca:
  varnish:
    http:
    - port: 80
    storage:
      stores:
      - name: store1
        path: /var/lib/varnish-supervisor/storage/store1
        size: 100G
```

Scaling up creates a new empty PVC for the new replica (which cold-starts while the existing replicas keep their warm cache). Scaling down does *not* delete PVCs by default.

### Cache data survives `helm upgrade` and `helm uninstall`

The StatefulSet's `persistentVolumeClaimRetentionPolicy` defaults to `Retain`, so PVCs created from `volumeClaimTemplates` are preserved across `helm upgrade` and `helm uninstall`. If you no longer need the cache data, delete the PVCs manually:

```sh
kubectl delete pvc -l app.kubernetes.io/instance=varnish-orca
```

## Undeploying Varnish Orca

Run the following command to undeploy *Varnish Orca* from your Kubernetes cluster using Helm:

```sh
helm uninstall varnish-orca
```
