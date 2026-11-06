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
