# Varnish Helm Charts

This repository hosts Helm charts for Varnish Cache and related projects.

## Charts

### Varnish Enterprise

The `varnish-enterprise/` chart is the **single source of truth** for both the enterprise and community charts. It targets the Varnish Enterprise image from `quay.io/varnish-software/varnish-plus` by default.

For full documentation see the [Varnish Enterprise Helm Chart docs](https://docs.varnish-software.com/varnish-helm/varnish-enterprise/).

### Varnish Cache (Community)

The community chart is **generated** from the enterprise chart at publish time. It is not maintained separately. Do not edit the `varnish-cache/` directory by hand.

To build the community chart:

```sh
./ci/publish-community.sh <oss-version> [output-dir]
```

- `oss-version`: the Varnish Cache OSS release to target, e.g. `9.0.3`. This sets the `appVersion` in `Chart.yaml` and the default image tag (`docker.io/varnish:<oss-version>`).
- `output-dir`: where to write the generated chart. Defaults to `./dist/varnish-cache`.

Example:

```sh
./ci/publish-community.sh 9.0.3
helm package dist/varnish-cache --destination dist/packages
```

The script requires `yq` (kislyuk/yq) and `helm`.

### Other Charts

- [orca-chart](orca-chart/README.md)

## Enterprise Customers

For Varnish Enterprise customers, please see [Varnish Helm Chart for Varnish Enterprise](https://docs.varnish-software.com/varnish-helm/varnish-enterprise/).

## License

2-Clause BSD
