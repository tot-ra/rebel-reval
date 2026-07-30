import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "agents" / "verify_workflows.py"
SPEC = importlib.util.spec_from_file_location("verify_agent_workflows", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class VerifyAgentWorkflowsTest(unittest.TestCase):
    def test_agent_definitions_satisfy_shared_protocol(self) -> None:
        self.assertEqual([], MODULE.validate())

    def test_tool_items_reads_flow_lists(self) -> None:
        yaml_text = """tools:
  mode: allow
  enabled: [read, edit, write]
  disabled: [delegate_to_agent, delegate_to_subagent]
"""
        self.assertEqual({"read", "edit", "write"}, MODULE.tool_items(yaml_text, "enabled"))
        self.assertEqual(
            {"delegate_to_agent", "delegate_to_subagent"},
            MODULE.tool_items(yaml_text, "disabled"),
        )

    def test_tool_items_reads_block_lists_without_leaking_sections(self) -> None:
        yaml_text = """tools:
  mode: allow
  enabled:
    - read
    - bash
  disabled:
    - delegate_to_agent
    - delegate_to_external_agent
networking:
  internet_access: false
"""
        self.assertEqual({"read", "bash"}, MODULE.tool_items(yaml_text, "enabled"))
        self.assertEqual(
            {"delegate_to_agent", "delegate_to_external_agent"},
            MODULE.tool_items(yaml_text, "disabled"),
        )

    def test_llm_target_reads_explicit_provider_and_model(self) -> None:
        yaml_text = """runtime:
  type: docker
llm:
  model: xiaomi/mimo-v2.5  # Ordering and comments are valid YAML.
  provider: openrouter
instructions:
  system_file: system.md
"""
        self.assertEqual(
            ("openrouter", "xiaomi/mimo-v2.5"),
            MODULE.llm_target(yaml_text),
        )


if __name__ == "__main__":
    unittest.main()
