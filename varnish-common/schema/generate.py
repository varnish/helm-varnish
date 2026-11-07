#!/usr/bin/env python3
"""Generate the charts' values.schema.json, values.yaml and values docs.

The single source is varnish-common/schema/values.schema.yaml, a draft-07
JSON Schema written in YAML with a few x- keywords (see README.md next to this
file). From it, for each flavor (varnish-cache, varnish-enterprise):

- values.schema.json: the source filtered for the flavor, x- keywords stripped;
- values.yaml: the defaults, commented from the descriptions (only when the
  source root has x-generate-values: true);
- the values reference: the marked block of varnish-cache/README.md, and the
  whole of varnish-enterprise/VALUES.md.

Usage: generate.py [--check] [--compare-values [PATH]] [--root DIR]

  --check                 write nothing, exit 1 if any output is stale
  --compare-values [PATH] write nothing, list where the source defaults and the
                          committed values.yaml files disagree (under PATH, a
                          dotted path), exit 1 if there is any
  --root DIR              repository root (default: this file's repository)

Python 3 standard library only; mikefarah yq v4 reads the YAML.
"""

import argparse
import copy
import json
import re
import subprocess
import sys
import textwrap
from pathlib import Path

SOURCE = "varnish-common/schema/values.schema.yaml"
GENERATED = f"Generated from {SOURCE} by generate.py. Do not edit."
BEGIN_MARKER = "<!-- BEGIN GENERATED VALUES -->"
END_MARKER = "<!-- END GENERATED VALUES -->"
WIDTH = 90

FLAVORS = {
    "cache": {"chart": "varnish-cache", "product": "Varnish Cache"},
    "enterprise": {"chart": "varnish-enterprise", "product": "Varnish Enterprise"},
}

# x- keywords, and the node kinds they may appear on.
NODE_KEYWORDS = {
    "x-enum-flavor",
    "x-examples",
    "x-type-label",
    "x-default",
    "x-values-example",
    "x-default-comments",
    "x-values-skip",
    "x-default-text",
    "x-since",
    "x-deprecated",
    "x-docs-skip",
}
PROPERTY_KEYWORDS = {"x-flavor", "x-docs-section"}
ROOT_KEYWORDS = {"x-links", "x-generate-values"}

# Keywords whose value is a schema, a list of schemas or a map of schemas.
SCHEMA_KEYWORDS = {"items", "additionalProperties", "propertyNames", "not"}
SCHEMA_LIST_KEYWORDS = {"anyOf", "allOf", "oneOf"}
SCHEMA_MAP_KEYWORDS = {"properties", "definitions", "patternProperties"}

NO_VALUE = object()


class SourceError(Exception):
    pass


# --- Loading and validation -------------------------------------------------


def load_yaml(path):
    """Parses a YAML file with yq, keeping the key order."""
    result = subprocess.run(
        ["yq", "-o", "json", ".", str(path)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SourceError(f"{path}: {result.stderr.strip()}")
    return json.loads(result.stdout) if result.stdout.strip() else None


def validate(node, path, kind):
    """Rejects unknown x- keywords and malformed x- values.

    kind is "root", "property" or "schema" (any other subschema).
    """
    if not isinstance(node, dict):
        if isinstance(node, bool):
            return
        raise SourceError(f"{path}: a schema must be an object")
    allowed = set(NODE_KEYWORDS)
    if kind in ("root", "property"):
        allowed |= PROPERTY_KEYWORDS
    if kind == "root":
        allowed |= ROOT_KEYWORDS
    for key, value in node.items():
        if key.startswith("x-") and key not in allowed:
            raise SourceError(f"{path}: unknown or misplaced keyword {key}")
    if "x-flavor" in node and node["x-flavor"] not in FLAVORS:
        raise SourceError(f"{path}: x-flavor must be one of {', '.join(FLAVORS)}, not {node['x-flavor']!r}")
    if "x-enum-flavor" in node:
        enum_flavor = node["x-enum-flavor"]
        if "enum" not in node or not isinstance(enum_flavor, dict):
            raise SourceError(f"{path}: x-enum-flavor must map values of enum to a flavor")
        for value, flavor in enum_flavor.items():
            if flavor not in FLAVORS:
                raise SourceError(
                    f"{path}: x-enum-flavor: {value}: flavor must be one of {', '.join(FLAVORS)}, not {flavor!r}"
                )
            if value not in [str(v) for v in node["enum"]]:
                raise SourceError(f"{path}: x-enum-flavor: {value} is not in enum")
    if "x-examples" in node:
        examples = node["x-examples"]
        if not isinstance(examples, list) or not all(
            isinstance(e, dict) and set(e) == {"description", "value"} for e in examples
        ):
            raise SourceError(f"{path}: each x-examples item needs a description and a value, and nothing else")
    if "x-default" in node:
        if "default" in node:
            raise SourceError(f"{path}: default and x-default can't be combined")
        if not isinstance(node["x-default"], dict) or not set(node["x-default"]) <= set(FLAVORS):
            raise SourceError(f"{path}: x-default must map flavors to a value")
    if "x-since" in node and (not isinstance(node["x-since"], dict) or not set(node["x-since"]) <= set(FLAVORS)):
        raise SourceError(f"{path}: x-since must map flavors to a version")
    if "x-default-comments" in node and not isinstance(node["x-default-comments"], dict):
        raise SourceError(f"{path}: x-default-comments must map relative paths to text")
    if "x-links" in node and not isinstance(node["x-links"], dict):
        raise SourceError(f"{path}: x-links must map references to URLs")

    for key, value in node.items():
        if key in SCHEMA_KEYWORDS and isinstance(value, dict):
            validate(value, f"{path}.{key}", "schema")
        elif key in SCHEMA_LIST_KEYWORDS:
            for i, item in enumerate(value):
                validate(item, f"{path}.{key}[{i}]", "schema")
        elif key in SCHEMA_MAP_KEYWORDS:
            for name, item in value.items():
                validate(item, f"{path}.{key}.{name}", "property" if key == "properties" else "schema")


# --- Flavor helpers ----------------------------------------------------------


def substitute(text, flavor):
    return text.replace("{product}", FLAVORS[flavor]["product"])


def visible(node, flavor):
    return node.get("x-flavor", flavor) == flavor


def flavor_default(node, flavor):
    """The node's own default for the flavor, or NO_VALUE."""
    if "default" in node:
        return node["default"]
    if "x-default" in node:
        return node["x-default"].get(flavor, NO_VALUE)
    return NO_VALUE


def enum_values(node, flavor):
    enum_flavor = node.get("x-enum-flavor", {})
    return [v for v in node["enum"] if enum_flavor.get(str(v), flavor) == flavor]


def resolve(node, definitions):
    """Follows $ref and allOf to the subschemas whose properties and items
    describe the node, the node first."""
    nodes = [node]
    i = 0
    while i < len(nodes):
        current = nodes[i]
        if "$ref" in current:
            name = current["$ref"].removeprefix("#/definitions/")
            if name not in definitions:
                raise SourceError(f"unknown $ref {current['$ref']}")
            nodes.append(definitions[name])
        nodes.extend(current.get("allOf", []))
        i += 1
    return nodes


def children(node, definitions, flavor):
    """The visible properties of a node, in source order."""
    result = {}
    for part in resolve(node, definitions):
        for name, child in part.get("properties", {}).items():
            if name not in result and visible(child, flavor):
                result[name] = child
    return result


def items_of(node, definitions):
    for part in resolve(node, definitions):
        if isinstance(part.get("items"), dict):
            return part["items"]
    return None


# --- values.schema.json ------------------------------------------------------


def schema_for(node, flavor, under_global=False, root=False):
    """Filters a schema node for the flavor and strips the x- keywords.

    under_global is true for global and the nodes under it: global stays open
    for parent charts, so other-flavor keys are left out there rather than
    denied."""
    if not isinstance(node, dict):
        return node
    result = {}
    for key, value in node.items():
        if key.startswith("x-"):
            continue
        if key == "properties":
            properties = {}
            for name, child in value.items():
                if visible(child, flavor):
                    properties[name] = schema_for(child, flavor, under_global or (root and name == "global"))
                elif not under_global:
                    owner = FLAVORS[child["x-flavor"]]["product"]
                    properties[name] = {"type": "null", "description": f"{owner} only."}
            result[key] = properties
        elif key == "required":
            omitted = {
                name
                for name, child in node.get("properties", {}).items()
                if under_global and not visible(child, flavor)
            }
            result[key] = [name for name in value if name not in omitted]
        elif key == "enum":
            result[key] = enum_values(node, flavor)
        elif key == "description":
            result[key] = substitute(value, flavor)
        elif key in SCHEMA_KEYWORDS:
            result[key] = schema_for(value, flavor, under_global)
        elif key in SCHEMA_LIST_KEYWORDS:
            result[key] = [schema_for(item, flavor, under_global) for item in value]
        elif key in SCHEMA_MAP_KEYWORDS:
            result[key] = {name: schema_for(item, flavor, under_global) for name, item in value.items()}
        else:
            result[key] = value
    default = flavor_default(node, flavor)
    if "x-default" in node and default is not NO_VALUE:
        result["default"] = default
    if "x-examples" in node:
        result["examples"] = [example["value"] for example in node["x-examples"]]
    return result


def render_schema(source, flavor):
    body = schema_for(source, flavor, root=True)
    body.pop("$schema", None)
    body.pop("$comment", None)
    schema = {"$schema": "http://json-schema.org/draft-07/schema#", "$comment": GENERATED, **body}
    return json.dumps(schema, indent=2, ensure_ascii=False) + "\n"


# --- Defaults ----------------------------------------------------------------


def defaults_for(node, definitions, flavor):
    """The values.yaml data of a node: its own default, else the defaults of its
    children, else NO_VALUE."""
    if node.get("x-values-skip"):
        return NO_VALUE
    own = flavor_default(node, flavor)
    if own is not NO_VALUE:
        return own
    result = {}
    for name, child in children(node, definitions, flavor).items():
        value = defaults_for(child, definitions, flavor)
        if value is not NO_VALUE:
            result[name] = value
    return result if result else NO_VALUE


# --- YAML emitter --------------------------------------------------------------

PLAIN_STRING = re.compile(r"[A-Za-z_/][A-Za-z0-9_./-]*")
PLAIN_KEY = re.compile(r"[A-Za-z_][A-Za-z0-9_./-]*")
RESERVED = {"true", "false", "null", "yes", "no", "on", "off", "y", "n", "~"}


def scalar(value, plain=False):
    """A YAML-safe JSON scalar. With plain, simple strings are left unquoted."""
    if plain and isinstance(value, str) and PLAIN_STRING.fullmatch(value) and value.lower() not in RESERVED:
        return value
    return json.dumps(value, ensure_ascii=False)


def key_text(key):
    if PLAIN_KEY.fullmatch(key) and key.lower() not in RESERVED:
        return key
    return json.dumps(key, ensure_ascii=False)


def is_block_string(value):
    return (
        isinstance(value, str)
        and "\n" in value.rstrip("\n")
        and not re.search(r"[\x00-\x08\x0b-\x1f\x7f\ufeff]", value)
        and not any(line != line.rstrip() for line in value.split("\n"))
    )


def block_string(value, indent):
    """A literal block scalar: the header and the indented lines."""
    if value.endswith("\n\n"):
        chomp = "+"
    elif value.endswith("\n"):
        chomp = ""
    else:
        chomp = "-"
    content = value[:-1] if value.endswith("\n") else value
    indicator = "2" if content.startswith(" ") else ""
    pad = " " * indent
    lines = [pad + line if line else "" for line in content.split("\n")]
    return f"|{indicator}{chomp}", lines


def emit_value(key, value, indent, plain, comments=None, context=None):
    """Lines for `key: value` at the indentation (key None for list items).

    With plain, simple strings are left unquoted. comments(key, context)
    returns the comment lines above a key of a mapping, context being the
    keys leading to that mapping.
    """
    pad = " " * indent
    prefix = f"{pad}{key_text(key)}:" if key is not None else None
    if isinstance(value, dict) and value:
        lines = [prefix] if prefix else []
        lines += emit_mapping(value, indent + (2 if prefix else 0), plain, comments, context)
        return lines
    if isinstance(value, list) and value:
        lines = [prefix] if prefix else []
        item_indent = indent + (2 if prefix else 0)
        for item in value:
            item_lines = emit_value(None, item, item_indent + 2, plain)
            first = item_lines[0]
            item_lines[0] = " " * item_indent + "- " + first[item_indent + 2 :]
            lines += item_lines
        return lines
    if is_block_string(value):
        header, body = block_string(value, indent + (2 if prefix else 0))
        return [f"{prefix} {header}" if prefix else f"{pad}{header}"] + body
    text = "{}" if value == {} else "[]" if value == [] else scalar(value, plain)
    return [f"{prefix} {text}" if prefix else f"{pad}{text}"]


def emit_mapping(mapping, indent, plain, comments=None, context=None):
    lines = []
    for key, value in mapping.items():
        lines += comments(key, context) if comments else []
        child_context = context + [key] if context is not None else None
        lines += emit_value(key, value, indent, plain, comments, child_context)
    return lines


def to_yaml(value, plain=True):
    return "\n".join(emit_value(None, value, 0, plain)) + "\n"


def nest(path, value):
    """Nests a value under a dotted path, where name[] stands for a list item."""
    for part in reversed(path.split(".")):
        if part.endswith("[]"):
            value = {part[:-2]: [value]}
        else:
            value = {part: value}
    return value


# --- values.yaml ---------------------------------------------------------------


LINKS = {}


def inline_links(text):
    """values.yaml has no link definitions, so reference links become inline ones."""
    return re.sub(
        r"\[([^\]]+)\]\[([^\]]+)\]",
        lambda m: f"[{m.group(1)}]({LINKS[m.group(2)]})" if m.group(2) in LINKS else m.group(0),
        text,
    )


def wrap(text, indent):
    """Comment lines for a markdown text: paragraphs are rewrapped to fit WIDTH,
    except code blocks and lists, which are kept as they are."""
    text = inline_links(text)
    pad = " " * indent
    lines = []
    for paragraph in text.strip("\n").split("\n\n"):
        if lines:
            lines.append(f"{pad}#")
        raw = paragraph.split("\n")
        if any(line.startswith(("```", "- ", "* ", "  ", "|")) for line in raw):
            lines += [f"{pad}# {line}".rstrip() for line in raw]
        else:
            lines += textwrap.wrap(
                " ".join(raw),
                width=WIDTH,
                initial_indent=f"{pad}# ",
                subsequent_indent=f"{pad}# ",
                break_long_words=False,
                break_on_hyphens=False,
            )
    return lines


def type_label(node, definitions):
    if "x-type-label" in node:
        return node["x-type-label"]
    if "$ref" in node:
        return type_label(resolve(node, definitions)[1], definitions)
    for part in node.get("allOf", []):
        label = type_label(part, definitions)
        if label:
            return label
    labels = []
    if "anyOf" in node:
        for part in node["anyOf"]:
            labels.append(type_label(part, definitions))
    elif "type" in node:
        types = node["type"] if isinstance(node["type"], list) else [node["type"]]
        for t in types:
            if t == "null" and len(types) > 1:
                continue
            if t == "array":
                items = node.get("items") or {}
                item_label = type_label(items, definitions) if items else ""
                labels.append(f"array of {item_label}s" if item_label in ("object", "string") else "array")
            else:
                labels.append({"integer": "number"}.get(t, t))
    elif "enum" in node or "const" in node:
        for v in node.get("enum", [node.get("const")]):
            labels.append(json_type(v))
    unique = []
    for label in labels:
        if label and label not in unique:
            unique.append(label)
    return " or ".join(unique)


def type_text(node, definitions, flavor):
    """The "Type" of a node in the docs and values.yaml: its label, followed
    by its enum values for the flavor unless x-type-label is set."""
    label = type_label(node, definitions)
    if "enum" not in node or "x-type-label" in node:
        return label
    values = [f"`{v}`" for v in enum_values(node, flavor)]
    if len(values) > 2:
        values = [", ".join(values[:-1]) + ","] + values[-1:]
    return f"{label}, one of {' or '.join(values)}"


def json_type(value):
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, (int, float)):
        return "number"
    if value is None:
        return "null"
    return {str: "string", list: "array", dict: "object"}[type(value)]


def comment_lines(node, name, indent, definitions, flavor):
    """The comment block above a key in values.yaml."""
    pad = " " * indent
    lines = []
    text = description_text(node, flavor)
    if text:
        lines += wrap(text, indent)
    label = type_text(node, definitions, flavor)
    if label and text:
        lines.append(f"{pad}# Type: {label}")
    since = node.get("x-since", {}).get(flavor)
    if since:
        lines.append(f"{pad}# Availability: {since}")
    examples = node.get("x-examples", [])
    for example in examples:
        if len(examples) > 1:
            lines += wrap(substitute(example["description"], flavor), indent)
        lines.append(f"{pad}# Example:")
        lines += [f"{pad}#   {line}".rstrip() for line in emit_value(name, example["value"], 0, True)]
    return lines


def description_text(node, flavor):
    parts = []
    if "x-deprecated" in node:
        parts.append("Deprecated: " + substitute(node["x-deprecated"], flavor).strip())
    if "description" in node:
        parts.append(substitute(node["description"], flavor).strip())
    return "\n\n".join(parts)


def render_values(source, flavor):
    definitions = source.get("definitions", {})
    LINKS.clear()
    LINKS.update(source.get("x-links", {}))
    lines = ["---", f"# {GENERATED}", ""]
    lines += values_mapping(source, 0, definitions, flavor)
    return "\n".join(lines) + "\n"


def values_mapping(node, indent, definitions, flavor):
    """Lines for the children of a schema node with properties."""
    lines = []
    previous_commented = False
    for name, child in children(node, definitions, flavor).items():
        if child.get("x-values-skip"):
            continue
        value = defaults_for(child, definitions, flavor)
        if value is NO_VALUE and "x-values-example" not in child:
            continue
        before = comment_lines(child, name, indent, definitions, flavor)
        if lines and (before or previous_commented):
            lines.append("")
        lines += before
        start = len(lines)
        pad = " " * indent
        if value is NO_VALUE:
            lines += [f"{pad}#{line[indent:]}" for line in emit_value(name, child["x-values-example"], indent, True)]
        elif flavor_default(child, flavor) is NO_VALUE:
            lines.append(f"{pad}{key_text(name)}:")
            lines += values_mapping(child, indent + 2, definitions, flavor)
        else:
            notes = child.get("x-default-comments", {})

            def comments(key, context, notes=notes, indent=indent):
                text = notes.get(".".join(context + [key]))
                return wrap(substitute(text, flavor), indent + 2 * (len(context) + 1)) if text else []

            lines += emit_value(name, value, indent, False, comments, [])
        # A blank line after a commented or multi-line key
        previous_commented = bool(before) or len(lines) - start > 1
    return lines


# --- Docs ----------------------------------------------------------------------


def render_docs(source, flavor):
    definitions = source.get("definitions", {})
    blocks = docs_entries(source, "", definitions, flavor)
    text = "\n\n".join(blocks)
    links = source.get("x-links", {})
    used = sorted(ref for ref in links if f"][{ref}]" in text)
    if used:
        text += "\n\n" + "\n".join(f"[{ref}]: {links[ref]}" for ref in used)
    return text


def docs_entries(node, prefix, definitions, flavor):
    blocks = []
    for name, child in children(node, definitions, flavor).items():
        if child.get("x-docs-skip"):
            continue
        path = f"{prefix}{name}"
        if "x-docs-section" in child:
            blocks.append(f"### {substitute(child['x-docs-section'], flavor)}")
        if "description" in child:
            blocks.append(docs_entry(child, path, definitions, flavor))
        blocks += docs_entries(child, f"{path}.", definitions, flavor)
        items = items_of(child, definitions)
        if items is not None:
            blocks += docs_entries(items, f"{path}[].", definitions, flavor)
    return blocks


def docs_entry(node, path, definitions, flavor):
    facts = []
    label = type_text(node, definitions, flavor)
    if label:
        facts.append(f"- Type: {label}")
    default = docs_default(node, flavor)
    if default:
        facts.append(f"- Default: {default}")
    since = node.get("x-since", {}).get(flavor)
    if since:
        facts.append(f"- Availability: {since}")
    parts = [f"**{path}**"]
    if facts:
        parts.append("\n".join(facts))
    parts.append(description_text(node, flavor))
    for example in node.get("x-examples", []):
        parts.append(substitute(example["description"], flavor).strip())
        parts.append("```yaml\n" + to_yaml(nest(path, example["value"])) + "```")
    return "\n\n".join(parts)


def docs_default(node, flavor):
    if "x-default-text" in node:
        return substitute(node["x-default-text"], flavor)
    value = flavor_default(node, flavor)
    if value is NO_VALUE or value is None or value == "" or value == {} or value == []:
        return None
    if isinstance(value, str) and "\n" in value:
        # Doesn't fit on the line; x-default-text can summarize it.
        return None
    if isinstance(value, str):
        return f"`{value}`"
    return f"`{json.dumps(value, ensure_ascii=False)}`"


def render_readme(current, docs):
    begin = current.find(BEGIN_MARKER)
    end = current.find(END_MARKER)
    if begin < 0 or end < begin:
        raise SourceError(f"varnish-cache/README.md: missing {BEGIN_MARKER} or {END_MARKER}")
    return f"{current[:begin]}{BEGIN_MARKER}\n<!-- {GENERATED} -->\n\n{docs}\n\n{current[end:]}"


def render_values_md(docs, source):
    title = f"# {FLAVORS['enterprise']['product']} Helm chart values"
    intro = f"{source['description']}\n\n" if "description" in source else ""
    return f"<!-- {GENERATED} -->\n\n{title}\n\n{intro}## Configurations\n\n{docs}\n"


# --- Outputs -------------------------------------------------------------------


def outputs(root, source):
    """The generated files, by path relative to root."""
    result = {}
    for flavor, info in FLAVORS.items():
        result[f"{info['chart']}/values.schema.json"] = render_schema(source, flavor)
        if source.get("x-generate-values"):
            result[f"{info['chart']}/values.yaml"] = render_values(source, flavor)
    readme = root / "varnish-cache/README.md"
    result["varnish-cache/README.md"] = render_readme(readme.read_text(), render_docs(source, "cache"))
    result["varnish-enterprise/VALUES.md"] = render_values_md(render_docs(source, "enterprise"), source)
    return result


def verify_values(source, files):
    """Parses the generated values.yaml files back and checks their data."""
    definitions = source.get("definitions", {})
    for flavor, info in FLAVORS.items():
        path = f"{info['chart']}/values.yaml"
        if path not in files:
            continue
        result = subprocess.run(["yq", "-o", "json", "."], input=files[path], capture_output=True, text=True)
        if result.returncode != 0:
            raise SourceError(f"{path}: the generated YAML does not parse: {result.stderr.strip()}")
        expected = defaults_for(source, definitions, flavor)
        if json.loads(result.stdout) != (None if expected is NO_VALUE else expected):
            raise SourceError(f"{path}: the generated YAML does not parse back to the source defaults")


# --- --compare-values ------------------------------------------------------------


def compare_values(root, source, scope):
    definitions = source.get("definitions", {})
    problems = []

    def in_scope(path):
        return not scope or path == scope or path.startswith(scope + ".") or scope.startswith(path + ".")

    def report(chart, path, message):
        if not scope or path == scope or path.startswith(scope + "."):
            problems.append(f"{chart}/values.yaml: {path}: {message}")

    def walk(node, values, prefix, chart, flavor):
        """node: source node with properties; values: the values.yaml mapping."""
        declared = children(node, definitions, flavor)
        for name, child in declared.items():
            path = f"{prefix}{name}"
            if child.get("x-values-skip") or not in_scope(path):
                continue
            present = isinstance(values, dict) and name in values
            own = flavor_default(child, flavor)
            if own is not NO_VALUE:
                if not present:
                    report(chart, path, "missing from values.yaml")
                elif values[name] != own:
                    report(
                        chart,
                        path,
                        f"source default {json.dumps(own)} != values.yaml {json.dumps(values[name])}",
                    )
            elif present:
                if not children(child, definitions, flavor):
                    report(chart, path, "has no default in the source")
                elif isinstance(values[name], dict):
                    walk(child, values[name], f"{path}.", chart, flavor)
                else:
                    built = defaults_for(child, definitions, flavor)
                    built = None if built is NO_VALUE else built
                    report(
                        chart,
                        path,
                        f"source default {json.dumps(built)} != values.yaml {json.dumps(values[name])}",
                    )
            elif defaults_for(child, definitions, flavor) is not NO_VALUE:
                report(chart, path, "missing from values.yaml")
        if isinstance(values, dict):
            for name in values:
                path = f"{prefix}{name}"
                if name not in declared and in_scope(path):
                    report(chart, path, "not in the source")

    for flavor, info in FLAVORS.items():
        values = load_yaml(root / info["chart"] / "values.yaml") or {}
        walk(source, values, "", info["chart"], flavor)
    return problems


# --- Main --------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="exit 1 if any output is stale")
    parser.add_argument(
        "--compare-values", nargs="?", const="", metavar="PATH", help="compare the source defaults with values.yaml"
    )
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2], help="repository root")
    args = parser.parse_args()
    root = args.root

    try:
        source = load_yaml(root / SOURCE)
        validate(source, "values.schema.yaml", "root")
        if args.compare_values is not None:
            problems = compare_values(root, source, args.compare_values)
            for problem in problems:
                print(problem)
            return 1 if problems else 0
        files = outputs(root, source)
        verify_values(source, files)
    except SourceError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    stale = []
    for path, content in files.items():
        target = root / path
        current = target.read_text() if target.exists() else None
        if current == content:
            continue
        stale.append(path)
        if not args.check:
            target.write_text(content)
    if args.check and stale:
        for path in stale:
            print(f"{path} is out of date", file=sys.stderr)
        print("run varnish-common/schema/generate.py", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
