class_name DialoguePortraitResolver
extends RefCounted

## Resolves optional portrait textures for dialogue speakers. Approved portraits
## land in P2-004; until then we reuse existing reference art where available.

const KNOWN_PORTRAITS := {
	&"char.mart": "res://characters/rebels/martin.png",
	&"char.kalev": "res://character/image.png",
	&"char.henning": "res://characters/workers_quarter/hendrik/hendrik.png",
	&"char.aita": "res://characters/workers_quarter/elsa/elsa.png",
}


static func resolve_texture(speaker_id: StringName) -> Texture2D:
	if speaker_id.is_empty():
		return null
	var path := String(KNOWN_PORTRAITS.get(speaker_id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var texture := load(path)
	return texture as Texture2D
