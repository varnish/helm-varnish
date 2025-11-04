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
 --set "service.port=81"
```

Or simply add `-f values.yaml` to override load the configuration overrides from a `values.yaml` file:

```sh
helm install -f values.yaml varnish-orca oci://docker.io/varnish/orca-chart
```

Here's an example `values.yaml` file:

```yaml
service:
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
| `livenessProbe.httpGet.path` | string | `"/"` |  |
| `livenessProbe.httpGet.port` | string | `"http"` |  |
| `nameOverride` | string | `""` |  |
| `nodeSelector` | object | `{}` |  |
| `podAnnotations` | object | `{}` |  |
| `podLabels` | object | `{}` |  |
| `podSecurityContext` | object | `{}` |  |
| `readinessProbe.httpGet.path` | string | `"/"` |  |
| `readinessProbe.httpGet.port` | string | `"http"` |  |
| `replicaCount` | int | `1` | Pod replicas |
| `resources` | object | `{}` | CPU and memory resources to allocate to the pod |
| `securityContext` | object | `{}` |  |
| `service.type` | string | `"ClusterIP"` |  |
| `service.http.enabled` | bool | `true` | Enable or disable the HTTP service |
| `service.http.port` | int | `80` | The service port for HTTP traffic |
| `service.https.enabled` | bool | `false` | Enable or disable the HTTPS service |
| `service.https.port` | int | `443` | The service port for HTTPS traffic |
| `serviceAccount.annotations` | object | `{}` | |
| `serviceAccount.automount` | bool | `true` |  |
| `serviceAccount.create` | bool | `true` |  |
| `serviceAccount.name` | string | `""` |  |
| `orca.acme` | object | `{}` | Generate [ACME TLS certificates](https://github.com/varnish/orca/blob/main/docs/configuration/acme.md) inside the *Varnish Orca* pod.
| `orca.virtual_registry` | object | See below | Orca virtual registry settings | [Virtual Registry configuration](https://github.com/varnish/orca/blob/main/docs/configuration/virtual-registry.md)
| `orca.git_mirror` | object | `{}` | Deploy a Git mirror alongside Orca for Git caching |
| `orca.license.secret` | string | `""` | The Kubernetes secret where the license for Orca is stored. The secret will be mounted into the pod.
| `orca.otel` | object | `{}` | Orca [OpenTelemetry configuration](https://github.com/varnish/orca/blob/main/docs/configuration/otel.md)
| `orca.supervisor` | object | `{}` | Orca [supervisor settings](https://github.com/varnish/orca/blob/main/docs/configuration/supervisor.md)
| `orca.varnish` | object | `{}` | Orca's underlying [Varnish configuration](https://github.com/varnish/orca/blob/main/docs/configuration/varnish.md)
| `orca.varnish.http[0].port` | int | `80` | On what port(s) should Varnish listen for HTTP requests
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

## Undeploying Varnish Orca

Run the following command to undeploy *Varnish Orca* from your Kubernetes cluster using Helm:

```sh
helm uninstall varnish-orca
```