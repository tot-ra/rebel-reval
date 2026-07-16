#!/usr/bin/env python3
"""Tests for tools/validate_content.py (P1-004)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from validate_content import main, validate_corpus  # noqa: E402


def _codes(diagnostics) -> list[str]:
    return [item.code for item in diagnostics]


def _write(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def _minimal_character(char_id: str = "char.test_a", **overrides) -> dict:
    record = {
        "type": "character",
        "id": char_id,
        "name": "Test",
        "role": "fixture",
        "confidence": "invented",
        "canon_status": "draft",
        "approval": {"status": "draft"},
        "pronunciation": "TEST",
        "brief": {
            "want": "want",
            "fear": "fear",
            "contradiction": "contradiction",
            "secret_or_withheld_fact": "secret",
        },
        "relationships": [],
        "voice": {"summary": "voice", "diction": "diction"},
        "outcomes": [{"id": "end", "summary": "outcome"}],
        "source_notes": [{"confidence": "invented", "summary": "fixture"}],
    }
    record.update(overrides)
    return record


def _minimal_location(loc_id: str = "loc.test_a", scene_path: str | None = None, **overrides) -> dict:
    record = {
        "type": "location",
        "id": loc_id,
        "name": "Test Location",
        "district": "Lower Town",
        "confidence": "invented",
        "canon_status": "draft",
        "approval": {"status": "draft"},
        "description": "fixture",
        "gameplay_space": True,
        "pressure_tags": ["Community"],
        "phase_states": [{"id": "start", "description": "start"}],
        "source_notes": [{"confidence": "invented", "summary": "fixture"}],
    }
    if scene_path is not None:
        record["scene_path"] = scene_path
    record.update(overrides)
    return record


def _minimal_item(item_id: str = "item.test_a", **overrides) -> dict:
    record = {
        "type": "item",
        "id": item_id,
        "name": "Test Item",
        "category": "supply",
        "confidence": "invented",
        "canon_status": "draft",
        "approval": {"status": "draft"},
        "gameplay": {"visible_in_pouch": True, "stackable": False, "uses": ["fixture"]},
        "source_notes": [{"confidence": "invented", "summary": "fixture"}],
    }
    record.update(overrides)
    return record


def _minimal_quest(quest_id: str = "quest.test_a", **overrides) -> dict:
    record = {
        "type": "quest",
        "id": quest_id,
        "title": "Test Quest",
        "summary": "fixture",
        "confidence": "invented",
        "canon_status": "draft",
        "approval": {"status": "draft"},
        "entry_conditions": [],
        "states": [{"id": "open", "label": "Open"}],
        "objectives": [{"id": "obj", "text": "Do thing", "state_id": "open"}],
        "outcomes": [
            {
                "id": "done",
                "summary": "Done",
                "effects": [{"op": "set_flag", "key": "flag.quest_done", "value": True}],
            }
        ],
        "content_links": {},
        "source_notes": [{"confidence": "invented", "summary": "fixture"}],
    }
    record.update(overrides)
    return record


def _minimal_dialogue(dialogue_id: str = "dialogue.test_a", **overrides) -> dict:
    record = {
        "type": "dialogue",
        "id": dialogue_id,
        "title": "Test Dialogue",
        "confidence": "invented",
        "canon_status": "draft",
        "approval": {"status": "draft"},
        "deterministic_offline": {
            "authored": True,
            "runtime_llm_allowed": False,
            "free_text_input_allowed": False,
            "selection": "explicit_node_id",
        },
        "participants": ["char.test_a"],
        "start_node_id": "start",
        "nodes": [
            {"id": "start", "speaker_id": "char.test_a", "text": "Hello.", "next_node_id": "end"},
            {"id": "end", "speaker_id": "char.test_a", "text": "Goodbye."},
        ],
        "source_notes": [{"confidence": "invented", "summary": "fixture"}],
    }
    record.update(overrides)
    return record


def _minimal_commission(**overrides) -> dict:
    record = {
        "type": "commission",
        "id": "commission.test_a",
        "title": "Test Commission",
        "client_id": "char.test_a",
        "quest_id": "quest.test_a",
        "object_item_id": "item.test_a",
        "location_id": "loc.test_a",
        "confidence": "invented",
        "canon_status": "draft",
        "approval": {"status": "draft"},
        "concrete_order": "Make a fixture.",
        "hidden_contradiction": "The fixture hides a test case.",
        "investigation_clues": [{"id": "clue", "summary": "Fixture clue"}],
        "forging_options": [
            {"id": "honest_work", "label": "Honest", "effects": []},
            {"id": "subtle_defect", "label": "Defect", "effects": []},
        ],
        "night_consequence": "Fixture consequence.",
        "source_notes": [{"confidence": "invented", "summary": "fixture"}],
    }
    record.update(overrides)
    return record


class ValidateContentTests(unittest.TestCase):
    def test_valid_minimal_corpus_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            scene = root / "scenes" / "room.tscn"
            scene.parent.mkdir(parents=True)
            scene.write_text("[gd_scene]\n", encoding="utf-8")
            content = root / "content"
            _write(content / "char.a.json", _minimal_character())
            _write(
                content / "loc.a.json",
                _minimal_location(scene_path="res://scenes/room.tscn"),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertEqual(diagnostics, [])

    def test_valid_conditions_and_effects_are_classified_separately(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(content / "char.json", _minimal_character())
            _write(
                content / "dialogue.json",
                _minimal_dialogue(
                    nodes=[
                        {
                            "id": "start",
                            "speaker_id": "char.test_a",
                            "text": "Mixed operations.",
                            "conditions": [{"op": "flag_is", "key": "flag.open", "value": True}],
                            "effects": [{"op": "set_flag", "key": "flag.seen", "value": True}],
                        }
                    ]
                ),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertEqual(diagnostics, [])

    def test_json_parse_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bad = root / "bad.json"
            bad.write_text("{not json", encoding="utf-8")
            diagnostics = validate_corpus([bad], project_root=root)
            self.assertIn("JSON_PARSE", _codes(diagnostics))

    def test_schema_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bad = root / "bad.json"
            _write(bad, {"type": "character", "id": "char.bad"})
            diagnostics = validate_corpus([bad], project_root=root)
            self.assertIn("SCHEMA", _codes(diagnostics))

    def test_duplicate_global_id(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(content / "a.json", _minimal_character())
            _write(content / "b.json", _minimal_character())
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("DUPLICATE_ID", _codes(diagnostics))

    def test_reference_missing_character(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(
                content / "dialogue.json",
                _minimal_dialogue(participants=["char.missing"]),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("REFERENCE", _codes(diagnostics))

    def test_dialogue_unreachable_node(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(content / "char.json", _minimal_character())
            _write(
                content / "dialogue.json",
                _minimal_dialogue(
                    nodes=[
                        {"id": "start", "speaker_id": "char.test_a", "text": "Hi."},
                        {"id": "orphan", "speaker_id": "char.test_a", "text": "Never reached."},
                    ]
                ),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("REACHABILITY", _codes(diagnostics))

    def test_dialogue_bad_edge_reference(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(content / "char.json", _minimal_character())
            _write(
                content / "dialogue.json",
                _minimal_dialogue(
                    nodes=[
                        {
                            "id": "start",
                            "speaker_id": "char.test_a",
                            "text": "Hi.",
                            "choices": [
                                {"id": "go", "text": "Go", "target_node_id": "missing"},
                            ],
                        }
                    ]
                ),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("REFERENCE", _codes(diagnostics))

    def test_unsupported_condition_bad_key_namespace(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(
                content / "quest.json",
                _minimal_quest(
                    entry_conditions=[{"op": "flag_is", "key": "quest.wrong", "value": True}]
                ),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("UNSUPPORTED_CONDITION", _codes(diagnostics))

    def test_unsupported_condition_quest_state_value(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(content / "quest.json", _minimal_quest())
            _write(
                content / "dialogue.json",
                _minimal_dialogue(
                    participants=["char.test_a"],
                    nodes=[
                        {
                            "id": "start",
                            "speaker_id": "char.test_a",
                            "text": "Gate",
                            "conditions": [
                                {
                                    "op": "quest_state_is",
                                    "key": "quest.test_a",
                                    "value": "missing_state",
                                }
                            ],
                        }
                    ],
                ),
            )
            _write(content / "char.json", _minimal_character())
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("UNSUPPORTED_CONDITION", _codes(diagnostics))

    def test_unsupported_effect_bad_key_namespace(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(
                content / "quest.json",
                _minimal_quest(
                    outcomes=[
                        {
                            "id": "done",
                            "summary": "Done",
                            "effects": [{"op": "set_flag", "key": "char.bad", "value": True}],
                        }
                    ]
                ),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("UNSUPPORTED_EFFECT", _codes(diagnostics))

    def test_missing_asset_scene_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(
                content / "loc.json",
                _minimal_location(scene_path="res://scenes/does_not_exist.tscn"),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("MISSING_ASSET", _codes(diagnostics))

    def test_local_duplicate_dialogue_node_ids(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(content / "char.json", _minimal_character())
            _write(
                content / "dialogue.json",
                _minimal_dialogue(
                    nodes=[
                        {"id": "start", "speaker_id": "char.test_a", "text": "One"},
                        {"id": "start", "speaker_id": "char.test_a", "text": "Duplicate"},
                    ]
                ),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("DUPLICATE_ID", _codes(diagnostics))

    def test_reference_missing_quest_for_quest_state_is(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(content / "char.json", _minimal_character())
            _write(
                content / "dialogue.json",
                _minimal_dialogue(
                    nodes=[
                        {
                            "id": "start",
                            "speaker_id": "char.test_a",
                            "text": "Gate",
                            "conditions": [
                                {
                                    "op": "quest_state_is",
                                    "key": "quest.missing",
                                    "value": "open",
                                }
                            ],
                        }
                    ],
                ),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("REFERENCE", _codes(diagnostics))

    def test_commission_requires_use_condition_semantics(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(content / "char.json", _minimal_character())
            _write(content / "quest.json", _minimal_quest())
            _write(content / "item.json", _minimal_item())
            _write(content / "loc.json", _minimal_location())
            _write(
                content / "commission.json",
                _minimal_commission(
                    forging_options=[
                        {
                            "id": "honest_work",
                            "label": "Honest",
                            "requires": [{"op": "flag_is", "key": "quest.wrong", "value": True}],
                            "effects": [],
                        },
                        {"id": "subtle_defect", "label": "Defect", "effects": []},
                    ]
                ),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("UNSUPPORTED_CONDITION", _codes(diagnostics))

    def test_duplicate_commission_forging_option_ids(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(content / "char.json", _minimal_character())
            _write(content / "quest.json", _minimal_quest())
            _write(content / "item.json", _minimal_item())
            _write(content / "loc.json", _minimal_location())
            _write(
                content / "commission.json",
                _minimal_commission(
                    forging_options=[
                        {"id": "honest_work", "label": "One", "effects": []},
                        {"id": "honest_work", "label": "Duplicate", "effects": []},
                    ]
                ),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("DUPLICATE_ID", _codes(diagnostics))

    def test_reference_missing_quest_for_set_quest_state(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(
                content / "quest.json",
                _minimal_quest(
                    outcomes=[
                        {
                            "id": "done",
                            "summary": "Done",
                            "effects": [
                                {
                                    "op": "set_quest_state",
                                    "key": "quest.missing",
                                    "value": "open",
                                }
                            ],
                        }
                    ]
                ),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("REFERENCE", _codes(diagnostics))

    def test_reference_missing_location_for_set_location_state(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(
                content / "quest.json",
                _minimal_quest(
                    outcomes=[
                        {
                            "id": "done",
                            "summary": "Done",
                            "effects": [
                                {
                                    "op": "set_location_state",
                                    "key": "loc.missing",
                                    "value": "start",
                                }
                            ],
                        }
                    ]
                ),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("REFERENCE", _codes(diagnostics))

    def test_unknown_condition_op(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(
                content / "quest.json",
                _minimal_quest(
                    entry_conditions=[{"op": "totally_unknown_condition", "key": "flag.x", "value": True}]
                ),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("UNSUPPORTED_CONDITION", _codes(diagnostics))
            self.assertNotIn("SCHEMA", _codes(diagnostics))

    def test_unknown_effect_op(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            content = root / "content"
            _write(
                content / "quest.json",
                _minimal_quest(
                    outcomes=[
                        {
                            "id": "done",
                            "summary": "Done",
                            "effects": [{"op": "totally_unknown_effect", "key": "flag.x"}],
                        }
                    ]
                ),
            )
            diagnostics = validate_corpus([content], project_root=root)
            self.assertIn("UNSUPPORTED_EFFECT", _codes(diagnostics))
            self.assertNotIn("SCHEMA", _codes(diagnostics))

    def test_nonexistent_path_input(self) -> None:
        missing = Path(tempfile.gettempdir()) / "validate_content_missing_path"
        diagnostics = validate_corpus([missing], project_root=ROOT)
        self.assertIn("INPUT", _codes(diagnostics))

    def test_empty_corpus_input(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            diagnostics = validate_corpus([Path(tmp)], project_root=ROOT)
            self.assertIn("INPUT", _codes(diagnostics))

    def test_cli_fails_on_nonexistent_path(self) -> None:
        missing = Path(tempfile.gettempdir()) / "validate_content_cli_missing_path"
        self.assertEqual(main([str(missing)]), 1)

    def test_cli_fails_on_empty_corpus(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(main([tmp]), 1)

    def test_res_path_traversal_blocked(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            outside = root.parent / f"{root.name}_outside_room.tscn"
            outside.write_text("[gd_scene]\n", encoding="utf-8")
            try:
                content = root / "content"
                _write(
                    content / "loc.json",
                    _minimal_location(scene_path=f"res://../{outside.name}"),
                )
                diagnostics = validate_corpus([content], project_root=root)
                self.assertIn("INPUT", _codes(diagnostics))
            finally:
                outside.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
