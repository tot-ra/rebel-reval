class_name RelationshipMemory
extends RefCounted

## Stable memory.* keys for discrete player actions a character can reference later.
## Numeric rel.* trust stays separate; memories are append-only booleans.

const KEY_PREFIX := "memory."


static func is_valid_key(key: StringName) -> bool:
	var parts := String(key).split(".")
	return parts.size() >= 3 and parts[0] == "memory" and not parts[1].is_empty() and not parts[2].is_empty()


static func character_id_for_key(key: StringName) -> StringName:
	if not is_valid_key(key):
		return &""
	var parts := String(key).split(".")
	return StringName("char.%s" % parts[1])
