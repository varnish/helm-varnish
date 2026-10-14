# The Varnish Broadcaster Helm Chart

This Helm Chart deploys *Varnish Broadcaster* on a Kubernetes cluster, giving
you a single endpoint to send invalidation requests (`PURGE`, `BAN`, etc.) to
all your Varnish pods.

The pod runs two processes from the `varnish/varnish-enterprise` image:
- `varnish-discovery` watches the endpoints of the Services listed in
  `discovery.groups` and writes them to a `nodes.conf` file
- `broadcaster` reads that file and relays every request it receives to all
  the Varnish pods

## Deploying Varnish Broadcaster using Helm

Point the chart at the Service(s) in front of your Varnish pods, in the same
namespace:

```sh
helm install broadcaster oci://docker.io/varnish/varnish-broadcaster \
 --set "discovery.groups={varnish-enterprise}"
```

Then, from inside the cluster:

```sh
# invalidate on all groups
curl -X PURGE http://broadcaster-varnish-broadcaster/path/to/object
# only on one group
curl -X PURGE -H "X-Broadcast-Group: varnish-enterprise" http://broadcaster-varnish-broadcaster/path/to/object
```

## Ports

- `80`: broadcaster, plain HTTP (container port 8088), used unless TLS is
  enabled
- `443`: broadcaster over HTTPS (container port 8443), used instead of port 80 if
  `broadcaster.tls.enabled` is set; `broadcaster.tls.secret` must name a
  `kubernetes.io/tls` Secret
- `8089`: management interface (over HTTPS if TLS is enabled), always running
  but only listening on localhost (it's used by the probes via `/api/ping`)
  unless `broadcaster.mgmt.enabled` is set, in which case it is also exposed by
  the Service

Discovery talks to the API server at `https://kubernetes.default.svc/` so it
works from any namespace; the service account needs read access to the
endpoints, which the chart grants by default (`rbac.create`).

## Customizing Helm Chart Values

See [values.yaml](values.yaml) for all the options. Arguments not covered by
the values can be passed through `broadcaster.extraArgs` and
`discovery.extraArgs`, for example:

```sh
helm install broadcaster oci://docker.io/varnish/varnish-broadcaster \
 --set "discovery.groups={varnish-enterprise}" \
 --set "discovery.extraArgs={-every,10s}" \
 --set "broadcaster.extraArgs={-tls-verify,NONE}"
```
