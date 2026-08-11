class_name VerticalSliceBranchConsequenceModel
extends RefCounted

## Authored major-choice consequence fingerprints for P3-005.
## WHY: slice validation needs one matrix proving every retained player choice
## changes GameState in a way that is unique within its decision group.

const FlowModel := preload("res://scripts/slice/vertical_slice_flow_model.gd")
const ReflectionModel := preload("res://scripts/reflection/reflection_model.gd")

const GROUP_MAKERS_MARK_LEDGER := "makers_mark.ledger"
const GROUP_WATCH_BUCKLE_FORGE := "watch_buckle.forge"
const GROUP_BITTER_BREW_FORGE := "bitter_brew.forge"
const GROUP_REFLECTION_CONVICTION := "reflection.conviction"

## Each retained major choice exposes a stable signature of state deltas. Two choices
## in the same group must not share a signature or they are wording-only duplicates.
const CHOICE_GROUPS: Array[Dictionary] = [
	{
		"id": "makers_mark.ledger",
		"choices":
		[
			{
				"id": "preserve_ledger",
				"signature":
				[
					"flag:flag.forge_ledger_preserved",
					"rel:rel.henning_trust:+1",
				],
			},
			{
				"id": "alter_ledger",
				"signature":
				[
					"flag:flag.forge_ledger_altered",
					"rel:rel.mart_trust:+1",
				],
			},
			{
				"id": "destroy_ledger",
				"signature":
				[
					"flag:flag.forge_ledger_destroyed",
					"pressure:pressure.suspicion:+1",
				],
			},
		],
	},
	{
		"id": "watch_buckle.forge",
		"choices":
		[
			{
				"id": "honest_work",
				"signature": ["forged:forged.watch_buckle_repair.honest_work"],
			},
			{
				"id": "subtle_defect",
				"signature":
				[
					"forged:forged.watch_buckle_repair.subtle_defect",
					"flag:flag.watch_buckle_weakened",
				],
			},
			{
				"id": "secret_feature",
				"signature":
				[
					"forged:forged.watch_buckle_repair.secret_feature",
					"flag:flag.watch_buckle_hidden_release",
				],
			},
		],
	},
	{
		"id": "bitter_brew.forge",
		"choices":
		[
			{
				"id": "honest_work",
				"signature":
				[
					"forged:forged.bitter_brew.honest_work",
					"night:night_surrendered",
					"aftermath:exonerated",
				],
			},
			{
				"id": "subtle_defect",
				"signature":
				[
					"forged:forged.bitter_brew.subtle_defect",
					"night:night_bypassed",
					"aftermath:monopolized",
				],
			},
			{
				"id": "secret_feature",
				"signature":
				[
					"forged:forged.bitter_brew.secret_feature",
					"night:night_escaped",
					"aftermath:escaped",
				],
			},
		],
	},
	{
		"id": "reflection.conviction",
		"choices":
		[
			{
				"id": "duty",
				"signature":
				[
					"flag:flag.reflection.duty",
					"rel:rel.henning_trust:+1",
				],
			},
			{
				"id": "fury",
				"signature":
				[
					"flag:flag.reflection.fury",
					"pressure:pressure.solidarity:+1",
				],
			},
			{
				"id": "mercy",
				"signature":
				[
					"flag:flag.reflection.mercy",
					"pressure:pressure.suspicion:-1",
				],
			},
		],
	},
]


static func choice_group_ids() -> Array[String]:
	var ids: Array[String] = []
	for group: Dictionary in CHOICE_GROUPS:
		ids.append(String(group["id"]))
	return ids


static func choice_count() -> int:
	var total := 0
	for group: Dictionary in CHOICE_GROUPS:
		total += (group["choices"] as Array).size()
	return total


static func validate_choice_groups() -> Dictionary:
	var errors: Array[String] = []
	for group: Dictionary in CHOICE_GROUPS:
		var seen: Dictionary = {}
		for choice: Dictionary in group["choices"]:
			var choice_id := String(choice["id"])
			var signature: PackedStringArray = PackedStringArray(choice["signature"])
			signature.sort()
			var key := "|".join(signature)
			if seen.has(key):
				errors.append(
					(
						"%s: choices %s and %s share consequence signature %s"
						% [String(group["id"]), String(seen[key]), choice_id, key]
					)
				)
			else:
				seen[key] = choice_id
	return {
		"choice_group_count": CHOICE_GROUPS.size(),
		"choice_count": choice_count(),
		"errors": errors,
		"all_choices_distinct": errors.is_empty(),
	}


static func build_report() -> Dictionary:
	var validation := validate_choice_groups()
	return {
		"choice_groups": choice_group_ids(),
		"choice_count": choice_count(),
		"errors": validation["errors"],
		"all_choices_distinct": validation["all_choices_distinct"],
	}
