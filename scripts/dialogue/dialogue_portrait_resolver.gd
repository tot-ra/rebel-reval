class_name DialoguePortraitResolver
extends RefCounted

## Resolves optional portrait textures for dialogue speakers. Approved portraits
## land in P2-004; until then we reuse existing reference art where available.

const KNOWN_PORTRAITS := {
	&"char.mart": "res://assets/characters/portraits/mart.png",
	&"char.kalev": "res://assets/characters/portraits/kalev.png",
	&"char.henning": "res://assets/characters/portraits/henning.png",
	&"char.aita": "res://assets/characters/portraits/aita.png",
}
## Named NPCs (R-1566): speaker `char.<slug>` maps to a portrait cropped from
## characters/**/img/<slug>.jpg by tools/assets/import_npc_portraits.py.
## Convention-based until NamedNpcRegistry (R-1562) lands and carries a portrait field.
const NPC_PORTRAIT_DIR := "res://assets/characters/portraits/npc/"
const CHAR_PREFIX := "char."


static func portrait_path(speaker_id: StringName) -> String:
	if speaker_id.is_empty():
		return ""
	var known := String(KNOWN_PORTRAITS.get(speaker_id, ""))
	if not known.is_empty():
		return known
	var id := String(speaker_id)
	if not id.begins_with(CHAR_PREFIX) or id.length() == CHAR_PREFIX.length():
		return ""
	return NPC_PORTRAIT_DIR + id.substr(CHAR_PREFIX.length()) + ".png"


static func resolve_texture(speaker_id: StringName) -> Texture2D:
	var path := portrait_path(speaker_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var texture := load(path)
	return texture as Texture2D
