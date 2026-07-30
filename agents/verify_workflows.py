#!/usr/bin/env python3
"""Validate invariants that keep the asynchronous agent loops from silently stalling."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AGENTS_DIR = ROOT / "agents"
EXPECTED_AGENTS = {
    "rebel-art",
    "rebel-canon-keeper",
    "rebel-character",
    "rebel-dev",
    "rebel-dialogue",
    "rebel-map",
    "rebel-narrative",
    "rebel-producer",
    "rebel-qa",
    "rebel-quest",
    "rebel-researcher",
}
DOCKER_LLM_TARGETS = {
    "rebel-art": ("openai_codex", "gpt-5.6-sol"),
    "rebel-producer": ("openai_codex", "gpt-5.6-sol"),
    "rebel-researcher": ("openrouter", "xiaomi/mimo-v2.5"),
}


def error(errors: list[str], path: Path, message: str) -> None:
    errors.append(f"{path.relative_to(ROOT)}: {message}")


def tool_items(yaml_text: str, key: str) -> set[str]:
    """Read the simple flow or block list used by tools.enabled/disabled."""
    lines = yaml_text.splitlines()
    marker = f"  {key}:"
    for index, line in enumerate(lines):
        if not line.startswith(marker):
            continue
        tail = line[len(marker) :].strip()
        if tail.startswith("[") and tail.endswith("]"):
            return {
                item.strip().strip("'\"")
                for item in tail[1:-1].split(",")
                if item.strip()
            }

        items: set[str] = set()
        for candidate in lines[index + 1 :]:
            if candidate.startswith("    - "):
                item = candidate[6:].split("#", 1)[0].strip().strip("'\"")
                if item:
                    items.add(item)
                continue
            if candidate.strip() and not candidate.startswith("    "):
                break
        return items
    return set()


def section_scalar(yaml_text: str, section: str, key: str) -> str:
    """Read a scalar from a simple top-level YAML mapping without key-order assumptions."""
    in_section = False
    marker = f"{section}:"
    key_pattern = re.compile(rf"^  {re.escape(key)}:\s*([^#]+?)(?:\s+#.*)?$")
    for line in yaml_text.splitlines():
        if line == marker:
            in_section = True
            continue
        if in_section and line and not line.startswith(" "):
            break
        if not in_section:
            continue
        match = key_pattern.match(line)
        if match:
            return match.group(1).strip().strip("'\"")
    return ""


def llm_target(yaml_text: str) -> tuple[str, str]:
    """Read the direct provider/model pair from the top-level llm section."""
    return section_scalar(yaml_text, "llm", "provider"), section_scalar(yaml_text, "llm", "model")


def validate() -> list[str]:
    errors: list[str] = []
    found = {path.parent.name for path in AGENTS_DIR.glob("rebel-*/agent.yaml")}
    if found != EXPECTED_AGENTS:
        missing = sorted(EXPECTED_AGENTS - found)
        extra = sorted(found - EXPECTED_AGENTS)
        errors.append(f"agents: definition set mismatch; missing={missing}, extra={extra}")

    protocol_path = AGENTS_DIR / "WORK_PROTOCOL.md"
    protocol = protocol_path.read_text(encoding="utf-8")
    for required in (
        "## Definition of Ready",
        "## One tick: Orient, Recover, Deliver, Improve, Report",
        "## Claims, leases, and state transitions",
        "## Blockers and work requests",
        "## Vertical slice contract",
        "## Deadlock prevention",
    ):
        if required not in protocol:
            error(errors, protocol_path, f"missing required section {required!r}")

    for agent_id in sorted(EXPECTED_AGENTS):
        directory = AGENTS_DIR / agent_id
        yaml_path = directory / "agent.yaml"
        yaml_text = yaml_path.read_text(encoding="utf-8")
        match = re.search(r"^\s{2}id:\s*([^\s]+)\s*$", yaml_text, re.MULTILINE)
        if not match or match.group(1) != agent_id:
            error(errors, yaml_path, "agent.id must match its directory")
        if agent_id in DOCKER_LLM_TARGETS:
            expected_target = DOCKER_LLM_TARGETS[agent_id]
            actual_target = llm_target(yaml_text)
            if actual_target != expected_target:
                error(
                    errors,
                    yaml_path,
                    f"Docker LLM target must be {expected_target!r}, got {actual_target!r}",
                )
            if section_scalar(yaml_text, "networking", "internet_access") != "true":
                error(errors, yaml_path, "Docker LLM routing through the parent proxy requires internet_access: true")
        for key, value in (("type", "docker"), ("mount", "rw"), ("mode", "allow")):
            setting = f"  {key}: {value}"
            if setting not in yaml_text.splitlines():
                error(errors, yaml_path, f"missing runtime safety setting {key + ': ' + value!r}")

        enabled = tool_items(yaml_text, "enabled")
        disabled = tool_items(yaml_text, "disabled")
        required_core = {"read", "edit", "write", "grep", "find_files", "glob", "content_search"}
        missing_core = required_core - enabled
        if missing_core:
            error(errors, yaml_path, f"missing core tools {sorted(missing_core)}")
        delegation_tools = {"delegate_to_agent", "delegate_to_subagent", "delegate_to_external_agent"}
        if not delegation_tools <= disabled or delegation_tools & enabled:
            error(errors, yaml_path, "delegation tools must be explicitly disabled and not enabled")
        command_roles = EXPECTED_AGENTS - {"rebel-canon-keeper", "rebel-narrative"}
        if agent_id in command_roles and "bash" not in enabled:
            error(errors, yaml_path, "role verification requires the bash tool")

        system_match = re.search(r"^\s{2}system_file:\s*(\S+)\s*$", yaml_text, re.MULTILINE)
        if system_match:
            system_path = directory / system_match.group(1)
            if not system_path.is_file():
                error(errors, yaml_path, f"missing system_file {system_match.group(1)!r}")
                system_text = ""
            else:
                system_text = system_path.read_text(encoding="utf-8")
        else:
            system_path = yaml_path
            system_text = yaml_text
        if "agents/WORK_PROTOCOL.md" not in system_text:
            error(errors, system_path, "system instructions must load agents/WORK_PROTOCOL.md")

        loop_path = directory / "skills" / "work-loop" / "SKILL.md"
        if not loop_path.is_file():
            error(errors, directory, "missing work-loop skill")
            continue
        loop = loop_path.read_text(encoding="utf-8")
        if "agents/WORK_PROTOCOL.md" not in loop:
            error(errors, loop_path, "work loop must load the shared protocol")
        if agent_id == "rebel-producer":
            for required in ("Orient and reconcile", "Validate queue integrity", "Plan a thin playable checkpoint", "Exit report"):
                if required not in loop:
                    error(errors, loop_path, f"missing Producer phase {required!r}")
        else:
            for required in ("Deliver mode", "Improve mode", "Completion standard"):
                if required not in loop:
                    error(errors, loop_path, f"missing worker phase {required!r}")
        if re.search(r"if (?:none|no row).{0,40}\bstop\b", loop, re.IGNORECASE):
            error(errors, loop_path, "legacy empty-queue stop instruction bypasses Improve mode")

    request_dir = ROOT / "docs" / "reports" / "work_requests"
    for name in ("README.md", "TEMPLATE.md"):
        if not (request_dir / name).is_file():
            error(errors, request_dir, f"missing request inbox file {name}")

    art_yaml = (AGENTS_DIR / "rebel-art" / "agent.yaml").read_text(encoding="utf-8")
    if "image: a2gent-rebel-art:blender-4.3" not in art_yaml:
        error(errors, AGENTS_DIR / "rebel-art" / "agent.yaml", "Art must use the Blender-capable image")

    return errors


def main() -> int:
    errors = validate()
    if errors:
        print("Agent workflow validation failed:")
        for item in errors:
            print(f"- {item}")
        return 1
    print(f"Agent workflow validation passed ({len(EXPECTED_AGENTS)} definitions).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
