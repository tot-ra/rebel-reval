class_name PhaseProfileModel
extends RefCounted

## Resolves authored slice phase profiles from ContentDB.

const TYPE_PHASE_PROFILE := "phase_profile"


static func resolve_profile(phase_id: StringName, content_db: ContentDB) -> Dictionary:
	if content_db == null or not content_db.is_loaded() or phase_id.is_empty():
		return {}
	for profile_id in content_db.get_ids_by_type(TYPE_PHASE_PROFILE):
		var profile := content_db.get_phase_profile(profile_id)
		if profile.is_empty():
			continue
		if StringName(String(profile.get("phase_id", ""))) == phase_id:
			return profile
	return {}


static func location_rules(profile: Dictionary, location_id: StringName) -> Dictionary:
	if profile.is_empty() or location_id.is_empty():
		return {}
	for value in profile.get("locations", []) as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry := value as Dictionary
		if StringName(String(entry.get("location_id", ""))) == location_id:
			return entry
	return {}


static func presentation(profile: Dictionary) -> Dictionary:
	var value: Variant = profile.get("presentation", {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value as Dictionary


static func ordered_profiles(content_db: ContentDB) -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	if content_db == null or not content_db.is_loaded():
		return profiles
	for profile_id in content_db.get_ids_by_type(TYPE_PHASE_PROFILE):
		var profile := content_db.get_phase_profile(profile_id)
		if not profile.is_empty():
			profiles.append(profile)
	profiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("sequence_index", 0)) < int(b.get("sequence_index", 0))
	)
	return profiles


static func next_phase_id(current: StringName, content_db: ContentDB) -> StringName:
	var profiles := ordered_profiles(content_db)
	for index in profiles.size():
		if StringName(String(profiles[index].get("phase_id", ""))) != current:
			continue
		if index + 1 >= profiles.size():
			return &""
		return StringName(String(profiles[index + 1].get("phase_id", "")))
	return &""
