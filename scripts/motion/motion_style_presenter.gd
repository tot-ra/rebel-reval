extends RefCounted

## Connects world, style agent and presentation for people, animals and birds (ADR 0051).
##
## One `MotionStyleAgent` per creature lives in the creature node's metadata. Every presenter call
## gathers the conditions at the creature (MotionEnvironment), updates the agent and hands the style
## to the creature's layer: `MotionStyleModifier` on a humanoid rig, `AnimalStyleModifier` on a
## skinned animal, the wingbeat of a flying bird. Positions and the logic plane are never moved by
## the style except for ambient wandering animals, whose speed is presentation only.

const MotionStyleAgent := preload("res://scripts/motion/motion_style_agent.gd")
const MotionEnvironment := preload("res://scripts/motion/motion_environment.gd")
const HumanModifier := preload("res://scripts/characters/motion_style_modifier.gd")
const AnimalModifier := preload("res://scripts/characters/animal_style_modifier.gd")

const AGENT_META := &"motion_style_agent"
const MODIFIER_META := &"motion_style_modifier"
const ENABLED_SETTING := "rebel/motion/style_network"

## Body of each animal species: kind, mass (kg), leg length (m), fur or plumage insulation.
const ANIMAL_BODIES: Dictionary = {
	&"dog": [&"quadruped", 25.0, 0.5, 0.55],
	&"cat": [&"quadruped", 4.0, 0.25, 0.5],
	&"horse": [&"quadruped", 500.0, 1.0, 0.5],
	&"cow": [&"quadruped", 600.0, 0.9, 0.55],
	&"pig": [&"quadruped", 100.0, 0.5, 0.3],
	&"sheep": [&"quadruped", 60.0, 0.55, 0.9],
	&"goat": [&"quadruped", 45.0, 0.55, 0.6],
	&"fox": [&"quadruped", 7.0, 0.35, 0.7],
	&"hare": [&"quadruped", 3.5, 0.3, 0.65],
	&"rat": [&"quadruped", 0.3, 0.06, 0.5],
	&"chicken": [&"bird", 2.0, 0.15, 0.75],
	&"goose": [&"bird", 4.0, 0.25, 0.85],
	&"duck": [&"bird", 1.2, 0.12, 0.85],
}
const DEFAULT_ANIMAL: Array = [&"quadruped", 20.0, 0.45, 0.55]


static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(ENABLED_SETTING, true))


static func agent_for(node: Object, kind: StringName, mass: float, leg: float) -> RefCounted:
	if node.has_meta(AGENT_META):
		return node.get_meta(AGENT_META)
	var phase := float(node.get_instance_id() % 997) / 997.0
	var agent: RefCounted = MotionStyleAgent.new(kind, mass, leg, phase)
	if not agent.is_ready():
		return null
	node.set_meta(AGENT_META, agent)
	return agent


## Hit points and stamina as channels: missing health is pain in the trunk, spent stamina is
## fatigue.
static func vitals_conditions(node: Object) -> Array:
	if node == null:
		return []
	var source: Object = node
	var brawler: Variant = node.get(&"brawler")
	if brawler is Object and brawler.get(&"vitals") is Object:
		source = brawler.get(&"vitals")
	var out := {}
	var max_h: Variant = source.get(&"max_health")
	var h: Variant = source.get(&"health")
	if max_h != null and h != null and float(max_h) > 0.0:
		out["pain_torso"] = clampf(1.0 - float(h) / float(max_h), 0.0, 1.0) * 0.8
	var max_s: Variant = source.get(&"max_stamina")
	var s: Variant = source.get(&"stamina")
	if max_s != null and s != null and float(max_s) > 0.0:
		out["fatigue"] = clampf(1.0 - float(s) / float(max_s), 0.0, 1.0)
	return [out] if not out.is_empty() else []


## People: every SharedCharacterRig, the hero included. Call after `set_locomotion_speed`.
static func humanoid(rig: Node3D, delta: float, world_speed: float, extra: Array = []) -> void:
	if not enabled() or rig == null or not rig.is_node_ready():
		return
	var skeleton := rig.call(&"skeleton") as Skeleton3D
	var model := rig.get_node_or_null("Model") as Node3D
	if skeleton == null or model == null:
		return
	var scale := model.scale.y if model.scale.y > 0.0 else 1.0
	var agent := agent_for(rig, &"biped", 70.0 * scale * scale * scale, 0.9 * scale)
	if agent == null:
		return
	var modifier: Object = rig.get_meta(MODIFIER_META) if rig.has_meta(MODIFIER_META) else null
	if modifier == null:
		modifier = HumanModifier.new()
		modifier.name = "MotionStyle"
		modifier.rig = model
		skeleton.add_child(modifier)
		# Muscles respond to the final pose, so the style runs before them (as the idle foot lock).
		var muscles := skeleton.get_node_or_null("AnatomicalMuscles")
		if muscles != null:
			skeleton.move_child(modifier, muscles.get_index())
		rig.set_meta(MODIFIER_META, modifier)
	var forward := model.global_transform.basis.z
	var facing := Vector2(forward.x, forward.z)
	var env: RefCounted = MotionEnvironment.current()
	var pos := Vector2(rig.global_position.x, rig.global_position.z)
	var conds: Array = env.conditions_at(pos, facing)
	conds.append_array(extra)
	agent.update(delta, conds, env.exposure(), world_speed)
	modifier.style = agent.style
	var ch: Dictionary = agent.channels
	modifier.wound = Vector3(
		float(ch.get("wound_x", 0.0)), float(ch.get("wound_y", 0.0)), float(ch.get("wound_z", 0.5))
	)
	# Shorter steps at the same speed mean a quicker cadence of the walk clip.
	if world_speed > 0.2:
		var player := rig.call(&"animation_player") as AnimationPlayer
		if player != null:
			player.speed_scale = clampf(
				player.speed_scale / maxf(float(agent.style.get("stride", 1.0)), 0.5), 0.5, 3.2
			)


## Skinned city animals (CityFauna). Call after `MedievalAnimalModels.sync_animation`.
static func animal(actor: Node3D, delta: float, species: StringName, extra: Array = []) -> void:
	if not enabled() or actor == null:
		return
	var body: Array = ANIMAL_BODIES.get(species, DEFAULT_ANIMAL)
	var agent := agent_for(actor, body[0], body[1], body[2])
	if agent == null:
		return
	var speed := float(actor.get_meta(&"motion_last_speed", 0.0))
	var forward := -actor.global_transform.basis.z
	var env: RefCounted = MotionEnvironment.current()
	var conds: Array = env.conditions_at(
		Vector2(actor.global_position.x, actor.global_position.z),
		Vector2(forward.x, forward.z),
		body[3]
	)
	conds.append_array(extra)
	agent.update(delta, conds, env.exposure(), speed)
	actor.set_meta(&"motion_speed_factor", agent.speed_factor(maxf(speed, 0.3)))
	var modifier: Variant = actor.get_meta(MODIFIER_META) if actor.has_meta(MODIFIER_META) else null
	if modifier == null:
		var found := actor.find_children("*", "Skeleton3D", true, false)
		if found.is_empty():
			actor.set_meta(MODIFIER_META, false)
			return
		modifier = AnimalModifier.new()
		modifier.name = "MotionStyle"
		modifier.frame_node = actor
		(found[0] as Skeleton3D).add_child(modifier)
		actor.set_meta(MODIFIER_META, modifier)
	if modifier is Object:
		modifier.style = agent.style


## Flying birds: a species-wide style (all birds of a species in view share the weather). Returns
## the
## flap profile with rate, amplitude and gliding adapted; `fluff` is in the returned "fluff" key.
static func bird_profile(
	host: Object, species: StringName, profile: Dictionary, delta: float, mass: float
) -> Dictionary:
	if not enabled() or host == null:
		return profile
	var agents: Dictionary = host.get_meta(AGENT_META) if host.has_meta(AGENT_META) else {}
	if not agents.has(species):
		var agent: RefCounted = MotionStyleAgent.new(
			&"bird", mass, 0.03 + 0.08 * pow(mass, 1.0 / 3.0), float(agents.size()) * 0.37
		)
		if not agent.is_ready():
			return profile
		agent.airborne = true
		agents[species] = agent
		host.set_meta(AGENT_META, agents)
	var a: RefCounted = agents[species]
	var env: RefCounted = MotionEnvironment.current()
	var frame := Engine.get_process_frames()
	if delta > 0.0 and int(a.get_meta(&"frame", -1)) != frame:
		# Several birds of a species share one agent: advance it once per frame.
		a.set_meta(&"frame", frame)
		var conds: Array = env.conditions_at(Vector2.ZERO, Vector2.ZERO, 0.8)
		a.update(delta, conds, env.exposure(), 3.0)
	var st: Dictionary = a.style
	var out := profile.duplicate()
	out["hz"] = float(profile["hz"]) * float(st.get("flap_rate", 1.0))
	out["up"] = float(profile["up"]) * float(st.get("flap_amp", 1.0))
	out["down"] = float(profile["down"]) * float(st.get("flap_amp", 1.0))
	var glide := float(st.get("glide", 0.0))
	if glide > 0.02 and int(profile.get("burst", 0)) > 0:
		out["pause"] = float(profile["pause"]) * (1.0 + 2.0 * glide)
	out["fluff"] = float(st.get("fluff", 0.0))
	return out
