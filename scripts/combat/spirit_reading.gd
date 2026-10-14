class_name SpiritReading
extends RefCounted
## SS-4 (ADR 0041 section 4): reading a soul. Pure rules for the reading panel: what a
## focused being's seven lights tell the hero at his awareness depth, and which being the
## hero is looking at. No scene, RNG or saved state; the panel (SpiritReadingPanel) draws it.

## Seconds the focus must rest on one being before the panel opens.
const FOCUS_DELAY := 0.5
## Seconds the panel stays after focus is lost, so a sweep across a crowd does not flicker.
const LOST_GRACE := 0.3
## Screen distance (px) from the focus point to a being's chest that still counts as looking.
const FOCUS_RADIUS_PX := 96.0
## Height of the chest above the body origin, scaled by the aura's body scale.
const CHEST_HEIGHT := 1.25

## Awareness depth: the hero's awareness light level unlocks each extra line.
const DEPTH_BASE := 2
const DEPTH_TEMPERAMENT := 3
const DEPTH_REVEAL_CLOSED := 4
const DEPTH_TOPIC := 5

const CLARITY_CALM := 0.67
const CLARITY_UNEASY := 0.34
const TOPIC_HINT_TAGS := 3
## The duel any resident can be challenged to (R-1889); its topic is everyone's hint.
const STRANGER_DUEL_ID := &"dialogue.city.spirit_duel"

## Drawn glyph per light, bottom-up; shape tells the light apart without colour.
const GLYPHS: Dictionary = {
	&"aspect.nature": &"square", &"aspect.affection": &"triangle_down",
	&"aspect.tenacity": &"triangle_up", &"aspect.unity": &"diamond",
	&"aspect.resonance": &"circle", &"aspect.awareness": &"eye", &"aspect.light": &"star",
}
const ELEMENT_NAMES: Dictionary = {
	&"fear": "Fear", &"coin": "Coin", &"duty": "Duty", &"love": "Love",
	&"shame": "Shame", &"sight": "Sight", &"faith": "Faith",
}


## Effective depth: awareness below the base still reads the base panel.
static func depth_for(awareness_level: int) -> int:
	return clampi(awareness_level, DEPTH_BASE, DEPTH_TOPIC)


static func clarity_word(clarity: float) -> String:
	if clarity >= CLARITY_CALM:
		return "calm"
	if clarity >= CLARITY_UNEASY:
		return "uneasy"
	return "torn"


## The reading of `profile` at the hero's `awareness_level`. `context` keys (all optional):
## name (String), temperament (Array of tags), topic_tags (Array), absent_closed (bool:
## an animal whose level-0 lights do not exist, so they are never weak points).
## Returns {name, depth, lights[], strongest[], closed[], absent[], veiled_count, clarity,
## clarity_word, temperament[], topic_hint}. Lights run bottom-up; each is {id, name,
## element, element_name, level (-1 when veiled), state, strongest, color, glyph}.
static func read(profile: SpiritAuraProfile, awareness_level: int, context: Dictionary = {}) -> Dictionary:  # gdlint: ignore=max-line-length
	var depth := depth_for(awareness_level)
	var absent_closed := bool(context.get("absent_closed", false))
	var lights: Array[Dictionary] = []
	var best := 0
	for i in SpiritAuraProfile.LIGHT_IDS.size():
		var id: StringName = SpiritAuraProfile.LIGHT_IDS[i]
		var level := int(profile.levels.get(id, 0)) if profile != null else 0
		var state := &"lit"
		if level == 0:
			state = &"absent" if absent_closed else &"closed"
		# Closed lights in the mask are concealed from a shallow reader (SS-2 contract).
		if (
			state == &"closed" and profile != null and profile.closed_mask.has(id)
			and depth < DEPTH_REVEAL_CLOSED
		):
			state = &"veiled"
			level = -1
		if state == &"lit":
			best = maxi(best, level)
		var element: StringName = SpiritAuraProfile.ELEMENTS[id]
		lights.append({
			"id": id,
			"name": String(GameState.NATURAL_ASPECT_DISPLAY_NAMES.get(id, String(id))),
			"element": element,
			"element_name": ELEMENT_NAMES.get(element, String(element)),
			"level": level,
			"state": state,
			"strongest": false,
			"color": SpiritAuraView.COLORS[i],
			"glyph": GLYPHS[id],
		})
	var strongest: Array[String] = []
	var closed: Array[String] = []
	var absent: Array[String] = []
	var veiled := 0
	for light in lights:
		match light["state"]:
			&"lit":
				if int(light["level"]) == best:
					light["strongest"] = true
					strongest.append(light["name"])
			&"closed":
				closed.append(light["name"])
			&"absent":
				absent.append(light["name"])
			&"veiled":
				veiled += 1
	var clarity := clampf(profile.clarity, 0.0, 1.0) if profile != null else 1.0
	var temperament: Array[String] = []
	if depth >= DEPTH_TEMPERAMENT:
		for tag: Variant in context.get("temperament", []):
			var text := String(tag)
			if not text.is_empty() and not temperament.has(text):
				temperament.append(text)
		temperament.sort()
	var topic_hint := ""
	if depth >= DEPTH_TOPIC:
		var tags: Array[String] = []
		for tag: Variant in context.get("topic_tags", []):
			if tags.size() < TOPIC_HINT_TAGS and not tags.has(String(tag)):
				tags.append(String(tag))
		topic_hint = ", ".join(tags)
	return {
		"name": String(context.get("name", "")),
		"depth": depth,
		"lights": lights,
		"strongest": strongest,
		"closed": closed,
		"absent": absent,
		"veiled_count": veiled,
		"clarity": clarity,
		"clarity_word": clarity_word(clarity),
		"temperament": temperament,
		"topic_hint": topic_hint,
	}


## Who a being is: `char.<actor>` from the rig name (MapViewRuntimeActors, as the aura
## manager resolves profiles) or an explicit `char_id` meta on the body.
static func char_id_for(body: Node) -> StringName:
	if body == null:
		return &""
	if body.has_meta(&"char_id"):
		return StringName(String(body.get_meta(&"char_id")))
	var actor := String(body.name).trim_suffix("Rig").to_snake_case()
	return StringName("char." + actor) if not actor.is_empty() else &""


## Name, temperament and topic tags for a person from content. `duel_id` is the person's own
## duel (SpiritSight.duel_for), empty for a stranger, who shares the stranger duel's topic.
static func context_for(char_id: StringName, db: ContentDB, duel_id: StringName = &"") -> Dictionary:  # gdlint: ignore=max-line-length
	var context := {"name": "", "temperament": [], "topic_tags": []}
	if db == null:
		return context
	var record: Dictionary = {}
	if char_id != &"" and db.has_record(char_id):
		record = db.get_character(char_id)
	context["name"] = String(record.get("name", ""))
	var duel: Dictionary = {}
	for id: StringName in [duel_id, STRANGER_DUEL_ID]:
		if id != &"" and db.has_record(id):
			var block: Variant = db.get_dialogue(id).get("duel", {})
			if block is Dictionary and not (block as Dictionary).is_empty():
				duel = block
				break
	var temperament: Variant = record.get("temperament", duel.get("temperament", []))
	context["temperament"] = temperament if temperament is Array else []
	var topic: Variant = duel.get("topic", {})
	if topic is Dictionary:
		context["topic_tags"] = (topic as Dictionary).get("tags", [])
	return context


## The being the hero looks at: the nearest projected chest within `radius_px` of `point`,
## in front of the camera. Ties keep the candidate order, so the pick is deterministic.
static func pick_focus(
	camera: Camera3D, point: Vector2, bodies: Array, radius_px: float = FOCUS_RADIUS_PX,
	heights: Dictionary = {}
) -> Node3D:
	if camera == null:
		return null
	var best: Node3D = null
	var best_distance := radius_px
	for body: Variant in bodies:
		var node := body as Node3D
		if node == null or not node.is_inside_tree():
			continue
		var chest := node.global_position + Vector3.UP * float(heights.get(node, CHEST_HEIGHT))
		if camera.is_position_behind(chest):
			continue
		var distance := camera.unproject_position(chest).distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best
