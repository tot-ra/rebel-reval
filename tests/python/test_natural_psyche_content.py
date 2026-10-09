"""R-1454: authored NATURAL/psyche effects match their runtime contracts."""

from __future__ import annotations

import copy
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from validate_content import validate_corpus
from validate_content_common import EFFECT_OPS
from validate_content_examples import SchemaStore, SchemaValidationError, validate_value
from validate_content_semantics import validate_effect_semantics
from tests.python.test_validate_content import _minimal_quest, _write


VALID_EFFECTS = [
    {"op": "natural.grant_points", "amount": 10},
    {"op": "natural.spend_point", "key": "aspect.awareness"},
    {"op": "psyche.apply_state", "key": "psyche.state.pride", "intensity": 1},
    {"op": "psyche.apply_state", "key": "psyche.state.obsession", "intensity": 3,
     "source_beat": "beat.reflection"},
]


class NaturalPsycheContentTests(unittest.TestCase):
    def setUp(self):
        self.store = SchemaStore(ROOT / "schemas")
        self.effect_schema = self.store.resolve("common.schema.json#/$defs/effect")

    def _schema(self, effect):
        validate_value(effect, self.effect_schema, self.store)

    def _semantics(self, effect):
        diagnostics = []
        validate_effect_semantics(
            diagnostics, path=ROOT / "fixture.json", pointer="$.effects[0]",
            effect=effect, index={}, root=ROOT,
        )
        return diagnostics

    def test_valid_effects_pass_schema_semantics_and_corpus(self):
        for effect in VALID_EFFECTS:
            with self.subTest(effect=effect):
                self._schema(effect)
                self.assertEqual(self._semantics(effect), [])
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            quest = _minimal_quest()
            quest["transitions"][0]["effects"] = copy.deepcopy(VALID_EFFECTS)
            _write(root / "quest.json", quest)
            self.assertEqual(validate_corpus([root], project_root=root), [])

    def test_ranges_shapes_and_known_ids_fail_closed(self):
        invalid = []
        for amount in [0, -1, 11, True, 1.5, "1"]:
            invalid.append({"op": "natural.grant_points", "amount": amount})
        for intensity in [0, -1, 4, True, 1.5, "1"]:
            invalid.append({"op": "psyche.apply_state", "key": "psyche.state.pride",
                            "intensity": intensity})
        invalid.extend([
            {"op": "natural.spend_point", "key": "aspect.missing"},
            {"op": "natural.spend_point", "key": ["aspect.light"]},
            {"op": "natural.spend_point", "key": {}},
            {"op": "natural.spend_point", "key": "flag.awareness"},
            {"op": "psyche.apply_state", "key": "psyche.state.missing", "intensity": 1},
            {"op": "psyche.apply_state", "key": "aspect.light", "intensity": 1},
        ])
        for valid in VALID_EFFECTS:
            for key in valid:
                if key == "source_beat":
                    continue  # Optional at runtime; deleting it must remain valid.
                broken = copy.deepcopy(valid)
                del broken[key]
                invalid.append(broken)
            for key, value in [("value", True), ("summary", "Not accepted at runtime"),
                               ("unsupported", 1)]:
                broken = {**valid, key: value}
                invalid.append(broken)
        for source in ["", None, 1, False]:
            invalid.append({**VALID_EFFECTS[2], "source_beat": source})
        for effect in invalid:
            with self.subTest(effect=effect):
                with self.assertRaises(SchemaValidationError):
                    self._schema(effect)
                self.assertTrue(self._semantics(effect))

    def test_legacy_effect_contract_is_not_relaxed(self):
        self._schema({"op": "adjust_pressure", "key": "pressure.authority", "amount": 3})
        for effect in [
            {"op": "adjust_pressure", "key": "pressure.authority", "amount": 10},
            {"op": "set_flag", "value": True},
            {"op": "set_flag", "key": "flag.test", "value": True, "intensity": 1},
            {"op": "set_flag", "key": "flag.test", "value": True, "source_beat": "beat.test"},
        ]:
            with self.subTest(effect=effect), self.assertRaises(SchemaValidationError):
                self._schema(effect)

    def test_clear_confront_and_speculative_ops_remain_unsupported(self):
        for op in ["psyche.clear_state", "psyche.confront_state", "natural.set_rank",
                   "natural.lock_aspect"]:
            effect = {"op": op, "key": "psyche.state.pride"}
            self.assertNotIn(op, EFFECT_OPS)
            with self.assertRaises(SchemaValidationError):
                self._schema(effect)
            self.assertEqual(self._semantics(effect)[0].code, "UNSUPPORTED_EFFECT")

    def test_schema_ids_and_bounds_match_game_state(self):
        # Pin authored allowlists to the runtime authority, not another fixture copy.
        text = (ROOT / "scripts/state/game_state.gd").read_text()
        for constant, definition in [("NATURAL_ASPECT_IDS", "natural_spend_effect"),
                                     ("PSYCHE_STATE_IDS", "psyche_apply_effect")]:
            block = re.search(rf"const {constant}[^=]*= \[(.*?)\]", text, re.S).group(1)
            runtime_ids = set(re.findall(r'&"([^"]+)"', block))
            schema = self.store.resolve(f"common.schema.json#/$defs/{definition}")
            self.assertEqual(runtime_ids, set(schema["properties"]["key"]["enum"]))
        points = int(re.search(r"const NATURAL_INITIAL_POINTS := (\d+)", text).group(1))
        grant = self.store.resolve("common.schema.json#/$defs/natural_grant_effect")
        self.assertEqual(grant["properties"]["amount"]["maximum"], points)
        evaluator = (ROOT / "scripts/state/state_rule_evaluator.gd").read_text()
        for effect in VALID_EFFECTS:
            self.assertIn(f'"{effect["op"]}"', evaluator)

    def test_all_runtime_ids_and_grant_endpoints_validate(self):
        for definition, op in [("natural_spend_effect", "natural.spend_point"),
                               ("psyche_apply_effect", "psyche.apply_state")]:
            schema = self.store.resolve(f"common.schema.json#/$defs/{definition}")
            for key in schema["properties"]["key"]["enum"]:
                effect = {"op": op, "key": key}
                if op == "psyche.apply_state":
                    effect["intensity"] = 3
                self._schema(effect)
                self.assertEqual(self._semantics(effect), [])
        for amount in [1, 10]:
            effect = {"op": "natural.grant_points", "amount": amount}
            self._schema(effect)
            self.assertEqual(self._semantics(effect), [])

    def test_invalid_effects_produce_corpus_diagnostics(self):
        for effect in [
            {"op": "natural.grant_points", "amount": 11},
            {"op": "natural.spend_point", "key": "aspect.missing"},
            {"op": "psyche.apply_state", "key": "psyche.state.pride", "intensity": 4},
            {"op": "psyche.clear_state", "key": "psyche.state.pride"},
        ]:
            with self.subTest(effect=effect), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                quest = _minimal_quest()
                quest["transitions"][0]["effects"] = [effect]
                _write(root / "quest.json", quest)
                diagnostics = validate_corpus([root], project_root=root)
                self.assertTrue(diagnostics)
                if effect["op"] == "psyche.clear_state":
                    self.assertIn("UNSUPPORTED_EFFECT", [d.code for d in diagnostics])

    def test_committed_example_passes_corpus(self):
        path = ROOT / "content/examples/valid/quest.natural_psyche.json"
        self.assertEqual(validate_corpus([path], project_root=ROOT), [])
        effects = json.loads(path.read_text())["transitions"][0]["effects"]
        self.assertEqual({effect["op"] for effect in effects},
                         {effect["op"] for effect in VALID_EFFECTS})


if __name__ == "__main__":
    unittest.main()
