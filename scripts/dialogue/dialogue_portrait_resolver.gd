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


static func resolve_texture(speaker_id: StringName) -> Texture2D:
	if speaker_id.is_empty():
		return null
	var path := String(KNOWN_PORTRAITS.get(speaker_id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var texture := load(path)
	return texture as Texture2D
