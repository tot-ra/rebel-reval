class_name SpiritAuraManager
extends Node
## SS-3 (ADR 0041): which beings show an aura while spirit sight is on.
## Budget: full auras on the MAX_FULL nearest beings within the sight radius,
## a single soft glow out to GLOW_RANGE, nothing beyond, nothing outside sight.
## Bodies come from the SharedCharacterRig group plus explicit register() calls
## (animals and other non-rig bodies). Views are created on first need, kept
## while the body lives and hidden (not freed) when sight closes.

const MAX_FULL := 12
const GLOW_RANGE := 40.0
## Base sight radius (ADR 0041 section 8). SS-8 (R-1491) widens it with the
## hero's awareness light; until then it is this fixed value.
const DEFAULT_SIGHT_RADIUS := 12.0
const REFRESH_SEC := 0.25
const HERO_RIG_NAME := &"PlayerRig"
const HERO_ID := &"char.apprentice"

var state: GameState
## Spirit-sight controller whose `blend` fades the auras; null = use `fade`.
var sight: Node
var fade := 0.0
var sight_radius := DEFAULT_SIGHT_RADIUS
var reduced_flashing := false
var follow_session := true
## Deterministic fixtures set the hero point directly; otherwise the hero rig.
var center_override: Variant = null
## Optional (body: Node3D) -> SpiritAuraProfile; default reads ContentDB by name.
var profile_resolver: Callable

var _views: Dictionary = {}
var _profiles: Dictionary = {}
var _explicit: Dictionary = {}
var _refresh_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if sight == null and get_parent() != null and &"blend" in get_parent():
		sight = get_parent()


## Show `body` with a fixed profile (animals, scripted figures). A body already
## in the rig group may be registered to override its resolved profile.
func register(body: Node3D, profile: SpiritAuraProfile = null) -> void:
	_explicit[body] = profile
	if profile != null:
		_profiles[body] = profile
		if _views.has(body) and is_instance_valid(_views[body]):
			(_views[body] as SpiritAuraView).set_profile(profile)


func unregister(body: Node3D) -> void:
	_explicit.erase(body)
	_drop(body)


func active() -> bool:
	return current_fade() > 0.001


func current_fade() -> float:
	if is_instance_valid(sight):
		return clampf(float(sight.get(&"blend")), 0.0, 1.0)
	return fade


func view_for(body: Node3D) -> SpiritAuraView:
	var view: Variant = _views.get(body)
	return view as SpiritAuraView if is_instance_valid(view) else null


## Pure budget rule. Returns body -> SpiritAuraView.Tier for every candidate.
## Nearest first; ties keep candidate order so the choice is deterministic.
static func assign_tiers(
	center: Vector3, bodies: Array, radius: float, max_full: int = MAX_FULL,
	glow_range: float = GLOW_RANGE
) -> Dictionary:
	var ranked: Array = []
	for index in bodies.size():
		var body := bodies[index] as Node3D
		if body == null or not body.is_inside_tree():
			continue
		ranked.append([center.distance_to(body.global_position), index, body])
	ranked.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var tiers := {}
	var full := 0
	for entry: Array in ranked:
		var distance := float(entry[0])
		var tier := SpiritAuraView.Tier.NONE
		if distance <= radius and full < max_full:
			tier = SpiritAuraView.Tier.FULL
			full += 1
		elif distance <= glow_range:
			tier = SpiritAuraView.Tier.GLOW
		tiers[entry[2]] = tier
	return tiers


func _process(delta: float) -> void:
	_read_settings()
	if not active():
		_hide_all()
		_refresh_left = 0.0
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_SEC
		refresh()
	var amount := current_fade()
	for body: Variant in _views.keys():
		var view: Variant = _views[body]
		if is_instance_valid(view):
			(view as SpiritAuraView).set_fade(amount)


## Re-rank every candidate and apply tiers. Called on a short timer, not per
## frame: anchors still follow bones every frame inside each visible view.
func refresh() -> void:
	_prune()
	var bodies := candidates()
	var center: Variant = _center()
	if center == null:
		_hide_all()
		return
	var tiers := assign_tiers(center as Vector3, bodies, sight_radius)
	for body: Node3D in bodies:
		var tier: int = tiers.get(body, SpiritAuraView.Tier.NONE)
		var view := view_for(body)
		if tier == SpiritAuraView.Tier.NONE:
			if view != null:
				view.set_tier(SpiritAuraView.Tier.NONE)
			continue
		if view == null:
			view = _create_view(body)
		elif body.name == HERO_RIG_NAME:
			# The hero's clarity follows the live guilt ledger.
			view.set_profile(_resolve_profile(body))
		view.set_reduced_flashing(reduced_flashing)
		view.set_fade(current_fade())
		view.set_tier(tier as SpiritAuraView.Tier)


func candidates() -> Array:
	var bodies: Array = []
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group(SharedCharacterRig.SPIRIT_AURA_GROUP):
			if node is Node3D and not bodies.has(node):
				bodies.append(node)
	for body: Variant in _explicit.keys():
		if is_instance_valid(body) and not bodies.has(body):
			bodies.append(body)
	return bodies


func _center() -> Variant:
	if center_override != null:
		return center_override
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group(SharedCharacterRig.SPIRIT_AURA_GROUP):
			if node.name == HERO_RIG_NAME and node is Node3D:
				return (node as Node3D).global_position
	return null


func _create_view(body: Node3D) -> SpiritAuraView:
	var view := SpiritAuraView.new()
	body.add_child(view)
	view.bind(body, _resolve_profile(body))
	_views[body] = view
	return view


func _resolve_profile(body: Node3D) -> SpiritAuraProfile:
	var explicit: Variant = _explicit.get(body)
	if explicit is SpiritAuraProfile:
		return explicit
	if body.name != HERO_RIG_NAME and _profiles.has(body):
		return _profiles[body]
	var profile: SpiritAuraProfile
	if profile_resolver.is_valid():
		profile = profile_resolver.call(body)
	if profile == null:
		profile = _default_profile(body)
	_profiles[body] = profile
	return profile


## Actor rigs are named "<Actor>Rig" (MapViewRuntimeActors). A matching
## `char.<actor>` record supplies authored data; otherwise the stable id-only
## derivation of SpiritAuraProfile applies.
func _default_profile(body: Node3D) -> SpiritAuraProfile:
	if body.name == HERO_RIG_NAME:
		return SpiritAuraProfile.from_record(HERO_ID, {}, state)
	var actor := String(body.name).trim_suffix("Rig").to_snake_case()
	var db: ContentDB = null
	var session := get_node_or_null("/root/SessionState") if is_inside_tree() else null
	if session != null:
		db = session.get(&"content_db") as ContentDB
	var record_id := StringName("char." + actor)
	if db != null and db.has_record(record_id):
		return SpiritAuraProfile.for_character(record_id, db, state)
	return SpiritAuraProfile.from_record(StringName(actor), {}, state)


func _hide_all() -> void:
	for body: Variant in _views.keys():
		var view: Variant = _views[body]
		if is_instance_valid(view):
			(view as SpiritAuraView).set_tier(SpiritAuraView.Tier.NONE)


func _prune() -> void:
	for body: Variant in _views.keys():
		if not is_instance_valid(body) or not is_instance_valid(_views[body]):
			_views.erase(body)
			_profiles.erase(body)
	for body: Variant in _explicit.keys():
		if not is_instance_valid(body):
			_explicit.erase(body)


func _drop(body: Node3D) -> void:
	var view := view_for(body)
	if view != null:
		view.queue_free()
	_views.erase(body)
	_profiles.erase(body)


func _read_settings() -> void:
	if not follow_session or not is_inside_tree():
		return
	var session := get_node_or_null("/root/SessionState")
	if session != null:
		state = session.get(&"state") as GameState
	var settings := get_node_or_null("/root/UserSettings")
	if settings != null:
		reduced_flashing = settings.gameplay.reduced_flashing
