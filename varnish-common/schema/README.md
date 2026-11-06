# Values schema

`values.schema.yaml` describes every value of the varnish-cache and varnish-enterprise charts. `generate.py` turns it into:

- `varnish-cache/values.schema.json` and `varnish-enterprise/values.schema.json`, which Helm uses to reject typos, wrong types and Enterprise-only keys on Varnish Cache before rendering;
- `varnish-cache/values.yaml` and `varnish-enterprise/values.yaml`, once the source root has `x-generate-values: true`;
- the values reference: the block between `<!-- BEGIN GENERATED VALUES -->` and `<!-- END GENERATED VALUES -->` in `varnish-cache/README.md`, and `varnish-enterprise/VALUES.md`.

Don't edit the generated files: change `values.schema.yaml`, then run the generator.

## Running

```sh
varnish-common/schema/generate.py                       # write the generated files
varnish-common/schema/generate.py --check               # exit 1 if any generated file is stale (CI)
varnish-common/schema/generate.py --compare-values      # compare the source defaults with values.yaml
varnish-common/schema/generate.py --compare-values server.http  # ... under a dotted path only
```

`--compare-values` lists, for both charts, the keys whose source default differs from the committed `values.yaml`, the `values.yaml` keys the source doesn't declare (or declares without a default), and the source defaults missing from `values.yaml`. It exits 1 if there is any.

The generator needs Python 3 (standard library only) and [yq](https://github.com/mikefarah/yq) v4. Its tests are in `test/`: `bats varnish-common/schema/test`.

## Source format

The source is a draft-07 JSON Schema written in YAML. These standard keywords are passed through to the generated schemas: `type`, `properties`, `additionalProperties`, `items`, `enum`, `const`, `anyOf`, `allOf`, `pattern`, `minimum`, `maximum`, `required`, `propertyNames`, `definitions`, `$ref`, `description`, `default`.

The `x-` keywords:

| Keyword | Where | Meaning |
|---|---|---|
| `x-flavor: enterprise` | any property node | **Enterprise schema:** kept. **Cache schema:** outside `global`, replaced by `{type: "null", description: "Varnish Enterprise only."}`, so null is still accepted for unsetting. Under `global`, omitted, since global stays open for parent charts. **Cache docs and values.yaml:** omitted. `cache` is accepted for symmetry. |
| `x-enum-flavor: {<value>: enterprise}` | node with `enum` | The listed enum values are dropped from the Cache schema and docs. |
| `x-examples: [{description: <md>, value: <any>}]` | any node | Generated schemas get the standard `examples: [<value>...]`. Docs render each description followed by a YAML block that nests `value` under the node's full path. values.yaml shows each as `Example:`. |
| `x-type-label: <text>` | definitions and nodes | Docs and values.yaml "Type". Without it, the label is derived from `type`/`anyOf`/`$ref`, joined with " or ", and a node with `enum` adds the values for the flavor ("string, one of `a` or `b`"). |
| `default: <value>` | any node | The default written to both charts' values.yaml, kept in the generated schemas (editors show it; Helm doesn't apply it). |
| `x-default: {cache: <value>, enterprise: <value>}` | any node | Per-flavor default, for keys whose defaults differ. Becomes `default` in each generated schema. Can't be combined with `default`. |
| `x-values-example: <value>` | node with no default | Written to values.yaml as a commented-out key (`#hostPort: 8080`). A node with neither a default nor this keyword is left out of values.yaml (it is still in the schema and docs). |
| `x-default-comments: {<relative.path>: <text>}` | node whose default is a nested passthrough object | Comments for keys inside the default value, e.g. `{runAsUser: "The user ID to run the container as."}`. |
| `x-values-skip: true` | any node | Not written to values.yaml (e.g. `enabled`). |
| `x-default-text: <md>` | any node | Docs "Default" line, overriding the rendered default (e.g. "name of the chart"). |
| `x-since: {cache: <ver>, enterprise: <ver>}` | any node | "Availability" line for that flavor. |
| `x-deprecated: <md>` | any node | Docs and values.yaml prefix "Deprecated: …". The schema still accepts the key. |
| `x-docs-section: <title>` | property node | The docs start a `###` heading with this title before this node. |
| `x-docs-skip: true` | any node | No docs entry for the node or its children. |
| `x-links: {<ref>: <url>}` | root only | Reference-style link definitions, appended to each generated docs block when the block uses them. |
| `x-generate-values: true` | root only | Also generate both charts' values.yaml. |

Any other `x-` keyword, or one in the wrong place, is an error.

Text:

- `{product}` in descriptions, example descriptions, `x-default-text` and `x-deprecated` becomes "Varnish Cache" or "Varnish Enterprise".
- A docs entry is written for every node with a `description`: a `**path**` line, then `- Type:`, `- Default:` (left out when the default is empty or multi-line, unless `x-default-text` is set) and `- Availability:`, then the description, then the examples. Array items are documented as `path[].key`.
- values.yaml comments: the description wrapped to 90 columns (code blocks and lists are kept as written), `Type:`, `Availability:`, then the examples.

## Adding or changing a key

1. Declare the key where it belongs, in values.yaml order. Mark Enterprise-only keys with `x-flavor: enterprise`.
2. Type it from what the templates accept. Strings that the templates compare with `eq x ""` are `string` only. Include `null` only if the default is null, or the key has no default and the templates tolerate null. Strings evaluated with `tpl` never get a `pattern`. Reuse the shapes under `definitions` (ports are `#/definitions/port`, image tags are `[string, integer, number]`), and never put constraints next to a `$ref`: use `allOf: [{$ref: ...}, {...}]`.
3. Close chart-owned objects with `additionalProperties: false`. Kubernetes passthroughs, `global`, `server.parameters` and filename-keyed maps stay open.
4. Set `default` (or `x-default`), or `x-values-example` for optional keys.
5. Write the `description`, with `{product}` for the product name, and move examples to `x-examples`.
6. Run `generate.py`, and commit the source with the generated files.
