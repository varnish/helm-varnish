# Varnish Helm Charts

This repository hosts Helm charts for Varnish Cache and related projects.

## Documentation

For documentation, please see README.md in each chart's directory.

- [varnish-cache](varnish-cache/README.md)
- [orca-chart](orca-chart/README.md)

## Enterprise Customers

For Varnish Enterprise customers, please see [Varnish Helm Chart for Varnish Enterprise](https://docs.varnish-software.com/varnish-helm/varnish-enterprise/).

## Shared templates

`varnish-cache` and `varnish-enterprise` share their templates and most of
their tests, which live in `varnish-common/` and are symlinked into each
chart (`helm package` copies the files they point to). Only `values.yaml`,
`Chart.yaml`, the README and the chart-specific tests are per chart.

- The `varnish.com/flavor` annotation in `Chart.yaml` tells the templates
  which chart they render. Code reading Enterprise-only values (cluster, MSE,
  agent, license...) must be gated with `include "varnish.isEnterprise" .`
  or one of the predicates next to it in `_helpers.tpl`, as these values do
  not exist in `varnish-cache`.
- Shared tests that only apply to Varnish Enterprise call
  `skip_unless_enterprise`.
- `test/golden/run.sh` compares the rendered output of each chart against
  snapshots; run it with `--update` after an intended change and review the
  diff for both charts.

## License

2-Clause BSD
