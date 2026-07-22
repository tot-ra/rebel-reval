#!/usr/bin/env python3
"""Validate P1-003 content schema examples without external dependencies.

This is intentionally a small validator for the JSON Schema subset used by the
repository schemas. P1-004 will add deeper content checks such as cross-file
references, reachability, duplicate IDs, unsupported conditions, and missing
assets.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SCHEMAS_DIR = ROOT / "schemas"
VALID_DIR = ROOT / "content" / "examples" / "valid"
INVALID_DIR = ROOT / "content" / "examples" / "invalid"

SCHEMA_BY_TYPE = {
    "character": "character.schema.json",
    "dialogue": "dialogue.schema.json",
    "bark_pool": "bark.schema.json",
    "quest": "quest.schema.json",
    "item": "item.schema.json",
    "commission": "commission.schema.json",
    "location": "location.schema.json",
    "mechanism": "mechanism.schema.json",
    "encounter": "encounter.schema.json",
    "phase_profile": "phase_profile.schema.json",
    "quest_package": "quest_package.schema.json",
}

TYPE_MAP = {
    "object": dict,
    "array": list,
    "string": str,
    "integer": int,
    # WHY: combat attack_profile fields use JSON Schema "number" (int or float).
    "number": (int, float),
    "boolean": bool,
}


class SchemaValidationError(ValueError):
    """Raised when a content example violates the schema subset."""


class SchemaStore:
    def __init__(self, schemas_dir: Path) -> None:
        self.schemas_dir = schemas_dir
        self.schemas: dict[str, dict[str, Any]] = {}
        for path in sorted(schemas_dir.glob("*.schema.json")):
            with path.open(encoding="utf-8") as handle:
                schema = json.load(handle)
            self.schemas[path.name] = schema
            if "$id" in schema:
                self.schemas[schema["$id"]] = schema

    def resolve(self, ref: str) -> Any:
        if "#" in ref:
            schema_name, pointer = ref.split("#", 1)
        else:
            schema_name, pointer = ref, ""
        schema = self.schemas.get(schema_name)
        if schema is None:
            raise SchemaValidationError(f"unknown schema reference {ref!r}")
        target: Any = schema
        if pointer:
            if not pointer.startswith("/"):
                raise SchemaValidationError(f"unsupported JSON pointer in {ref!r}")
            for raw_part in pointer.strip("/").split("/"):
                part = raw_part.replace("~1", "/").replace("~0", "~")
                try:
                    target = target[part]
                except (KeyError, TypeError) as exc:
                    raise SchemaValidationError(f"unresolved schema reference {ref!r}") from exc
        return target


def json_type_name(value: Any) -> str:
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, int):
        return "integer"
    if isinstance(value, float):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    if value is None:
        return "null"
    return type(value).__name__


def validate_type(value: Any, expected: str | list[str], path: str) -> None:
    expected_types = expected if isinstance(expected, list) else [expected]
    for expected_type in expected_types:
        if expected_type == "null" and value is None:
            return
        py_type = TYPE_MAP.get(expected_type)
        if py_type is None:
            raise SchemaValidationError(f"{path}: unsupported schema type {expected_type!r}")
        if expected_type == "integer":
            if isinstance(value, int) and not isinstance(value, bool):
                return
        elif expected_type == "number":
            # JSON numbers are int or float; bool must not satisfy number.
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                return
        elif isinstance(value, py_type):
            # bool is a subclass of int, but the integer branch above already
            # excludes it. The boolean branch intentionally accepts bool only.
            return
    joined = ", ".join(expected_types)
    raise SchemaValidationError(f"{path}: expected {joined}, got {json_type_name(value)}")


def validate_value(value: Any, schema: dict[str, Any], store: SchemaStore, path: str = "$") -> None:
    if "$ref" in schema:
        validate_value(value, store.resolve(schema["$ref"]), store, path)
        return

    if "const" in schema and value != schema["const"]:
        raise SchemaValidationError(f"{path}: expected const {schema['const']!r}, got {value!r}")

    if "enum" in schema and value not in schema["enum"]:
        raise SchemaValidationError(f"{path}: value {value!r} is not one of {schema['enum']!r}")

    if "type" in schema:
        validate_type(value, schema["type"], path)

    if isinstance(value, str):
        if "minLength" in schema and len(value) < schema["minLength"]:
            raise SchemaValidationError(f"{path}: string is shorter than {schema['minLength']}")
        if "maxLength" in schema and len(value) > schema["maxLength"]:
            raise SchemaValidationError(f"{path}: string is longer than {schema['maxLength']}")
        if "pattern" in schema and re.search(schema["pattern"], value) is None:
            raise SchemaValidationError(f"{path}: string {value!r} does not match {schema['pattern']!r}")

    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            raise SchemaValidationError(f"{path}: {value} is less than minimum {schema['minimum']}")
        if "exclusiveMinimum" in schema and value <= schema["exclusiveMinimum"]:
            raise SchemaValidationError(
                f"{path}: {value} is not greater than exclusiveMinimum {schema['exclusiveMinimum']}"
            )
        if "maximum" in schema and value > schema["maximum"]:
            raise SchemaValidationError(f"{path}: {value} is greater than maximum {schema['maximum']}")
        if "exclusiveMaximum" in schema and value >= schema["exclusiveMaximum"]:
            raise SchemaValidationError(
                f"{path}: {value} is not less than exclusiveMaximum {schema['exclusiveMaximum']}"
            )

    if isinstance(value, list):
        if "minItems" in schema and len(value) < schema["minItems"]:
            raise SchemaValidationError(f"{path}: array has fewer than {schema['minItems']} items")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            raise SchemaValidationError(f"{path}: array has more than {schema['maxItems']} items")
        item_schema = schema.get("items")
        if item_schema is not None:
            for index, item in enumerate(value):
                validate_value(item, item_schema, store, f"{path}[{index}]")

    if isinstance(value, dict):
        required = schema.get("required", [])
        for key in required:
            if key not in value:
                raise SchemaValidationError(f"{path}: missing required property {key!r}")

        properties = schema.get("properties", {})
        for key, item in value.items():
            if key in properties:
                validate_value(item, properties[key], store, f"{path}.{key}")
            elif schema.get("additionalProperties") is False:
                raise SchemaValidationError(f"{path}: additional property {key!r} is not allowed")
            elif isinstance(schema.get("additionalProperties"), dict):
                validate_value(item, schema["additionalProperties"], store, f"{path}.{key}")


def load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def schema_for_example(example: dict[str, Any]) -> str:
    record_type = example.get("type")
    schema_name = SCHEMA_BY_TYPE.get(record_type)
    if schema_name is None:
        raise SchemaValidationError(f"unknown or missing content type {record_type!r}")
    return schema_name


def validate_file(path: Path, store: SchemaStore) -> None:
    example = load_json(path)
    if not isinstance(example, dict):
        raise SchemaValidationError("top-level JSON value must be an object")
    schema = store.resolve(schema_for_example(example))
    validate_value(example, schema, store)


def iter_json_files(path: Path) -> list[Path]:
    return sorted(path.glob("*.json"), key=lambda p: p.name.casefold())


def run(check_invalid: bool = True) -> tuple[list[str], list[str]]:
    store = SchemaStore(SCHEMAS_DIR)
    ok: list[str] = []
    errors: list[str] = []

    for path in iter_json_files(VALID_DIR):
        try:
            validate_file(path, store)
            ok.append(f"PASS valid {path.relative_to(ROOT)}")
        except SchemaValidationError as exc:
            errors.append(f"FAIL valid {path.relative_to(ROOT)}: {exc}")

    if check_invalid:
        for path in iter_json_files(INVALID_DIR):
            try:
                validate_file(path, store)
            except SchemaValidationError as exc:
                ok.append(f"PASS invalid rejected {path.relative_to(ROOT)}: {exc}")
            else:
                errors.append(f"FAIL invalid accepted {path.relative_to(ROOT)}")

    return ok, errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--valid-only",
        action="store_true",
        help="Only require valid examples to pass; skip seeded invalid fixtures.",
    )
    args = parser.parse_args(argv)

    ok, errors = run(check_invalid=not args.valid_only)
    for line in ok:
        print(line)
    for line in errors:
        print(line, file=sys.stderr)
    if errors:
        return 1
    print(f"content examples schema validation ok: {len(ok)} checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
