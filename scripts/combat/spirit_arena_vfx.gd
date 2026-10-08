class_name SpiritArenaVfx
extends Control
## Presentation-only effects for the spirit arena (R-1332). Listens to
## `SpiritDuel.exchange_resolved` and draws what the exchange did: a fireball flying
## to the opponent, a tremor ring with a ground shake, an iron shimmer on the hero, a
## heal pulse, a strike flash for a landed reply, and for a telegraphed blow a hit
## (shake + red vignette), parry spark, guard spark or dodge whoosh. Floating numbers
## and bar flashes show every composure/pressure change. Looks follow `arena_effect`
## and hit outcome, never a spell id. Procedural only (CPUParticles2D, `_draw`,
## generated gradients; no texture assets, P0-040). The duel model is never touched.
## Accessibility: screen shake follows `allows_screenshake(reduced_motion)`, reduced
## motion skips travel/drift tweens, reduced flashing dims flashes and the vignette.

## Emitted once per visual piece (see the EFFECT_* ids) so tests and captures can
## observe the presentation without reading pixels.
signal effect_spawned(effect_id: StringName)

const Parts := preload("res://scripts/map/view3d/map_view_magic_vfx_parts.gd")

const EFFECT_FIREBALL := &"fireball"
const EFFECT_IMPACT := &"impact"
const EFFECT_TREMOR := &"tremor"
const EFFECT_SHIELD := &"shield"
const EFFECT_HEAL := &"heal"
const EFFECT_STRIKE := &"strike"
const EFFECT_HIT := &"hit"
const EFFECT_VIGNETTE := &"vignette"
const EFFECT_PARRY := &"parry"
const EFFECT_GUARD := &"guard"
const EFFECT_DODGE := &"dodge"
const EFFECT_SHAKE := &"shake"
const EFFECT_NUMBER := &"number"
const EFFECT_BAR_FLASH := &"bar_flash"

## Arena anchors as fractions of the screen: the opponent speaks from the top, the
## hero answers from below. Both sit in the empty band between the spoken line and
## the reply wheel so effects never cover text or buttons.
const OPPONENT_ANCHOR := Vector2(0.5, 0.30)
const HERO_ANCHOR := Vector2(0.5, 0.62)
const FIREBALL_FLIGHT_SEC := 0.38
const SHAKE_DECAY_PER_SEC := 2.4
const SHAKE_MAX_OFFSET_PX := 18.0
const SHAKE_HIT := 0.55
const SHAKE_TREMOR := 0.8
const SHAKE_FIREBALL := 0.3
const VIGNETTE_SEC := 0.55
const VIGNETTE_PEAK_ALPHA := 0.75
## Reduced flashing scales every flash and the vignette by this factor.
const REDUCED_FLASH_SCALE := 0.3
const NUMBER_RISE_PX := 54.0
const NUMBER_SEC := 0.9
const IRON_COLOR := Color(0.70, 0.80, 0.95)
const HEAL_COLOR := Color(0.55, 0.95, 0.60)
const SPARK_COLOR := Color(1.0, 0.86, 0.40)
const HIT_COLOR := Color(0.95, 0.22, 0.18)

var allow_shake := true
var reduced_motion := false
var reduced_flashing := false
## Every effect id spawned since `bind`, in order (diagnostics and tests).
var spawned: Array[StringName] = []

var _duel: SpiritDuel
var _shake_target: CanvasLayer
var _composure_bar: Control
var _pressure_bar: Control
var _vignette: TextureRect
var _vignette_tween: Tween
var _last_pressure := 0.0
var _shake_trauma := 0.0
var _shake_phase := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vignette = TextureRect.new()
	_vignette.name = "HitVignette"
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.texture = _vignette_texture()
	_vignette.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_vignette)


## Follow `duel`; `shake_target` is the layer whose offset shakes, the bars flash.
func bind(duel: SpiritDuel, shake_target: CanvasLayer, composure_bar: Control, pressure_bar: Control) -> void:  # gdlint: ignore=max-line-length
	unbind()
	_duel = duel
	_shake_target = shake_target
	_composure_bar = composure_bar
	_pressure_bar = pressure_bar
	_last_pressure = duel.opponent.health
	spawned.clear()
	refresh_accessibility()
	duel.exchange_resolved.connect(_on_exchange)


func unbind() -> void:
	if _duel != null and _duel.exchange_resolved.is_connected(_on_exchange):
		_duel.exchange_resolved.disconnect(_on_exchange)
	_duel = null
	clear()


## After a retry: forget the old pressure baseline and drop the old effects.
func resync() -> void:
	clear()
	if _duel != null:
		_last_pressure = _duel.opponent.health


## Drop every live effect and settle the shake (closing or retrying the arena).
func clear() -> void:
	for child in get_children():
		if child != _vignette:
			remove_child(child)
			child.queue_free()
	if _vignette_tween != null:
		_vignette_tween.kill()
	_vignette.modulate.a = 0.0
	_shake_trauma = 0.0
	if _shake_target != null:
		_shake_target.offset = Vector2.ZERO


## Re-read the player's accessibility settings (UserSettings autoload when present).
func refresh_accessibility() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node(^"/root/UserSettings"):
		return
	var settings: Node = tree.root.get_node(^"/root/UserSettings")
	var gameplay: Variant = settings.get("gameplay")
	var dialogue: Variant = settings.get("dialogue")
	reduced_motion = dialogue != null and bool(dialogue.reduced_motion)
	if gameplay != null and gameplay.has_method("allows_screenshake"):
		allow_shake = bool(gameplay.allows_screenshake(reduced_motion))
		reduced_flashing = bool(gameplay.reduced_flashing)
	else:
		allow_shake = not reduced_motion


func shake_trauma() -> float:
	return _shake_trauma


func _process(delta: float) -> void:
	# Only touch the layer offset while shaking, then settle it once at zero.
	if _shake_target == null or _shake_trauma <= 0.0:
		return
	_shake_trauma = maxf(0.0, _shake_trauma - SHAKE_DECAY_PER_SEC * delta)
	if _shake_trauma <= 0.0:
		_shake_target.offset = Vector2.ZERO
		return
	_shake_phase += delta * 40.0
	var amount := _shake_trauma * _shake_trauma * SHAKE_MAX_OFFSET_PX
	_shake_target.offset = Vector2(sin(_shake_phase * 1.7), cos(_shake_phase * 2.3) * 0.6) * amount


func _on_exchange(result: Dictionary) -> void:
	var pressure_left := float(result.get("pressure_left", _last_pressure))
	var pressure_gain := maxf(0.0, _last_pressure - pressure_left)
	_last_pressure = pressure_left
	match String(result.get("kind", "")):
		"spell":
			_on_spell(StringName(String(result.get("arena_effect", ""))), pressure_gain)
		"reply":
			if float(result.get("damage", 0.0)) > 0.0:
				_strike(_opponent_point(), pressure_gain)
		"incoming":
			_on_incoming(result, pressure_gain)


func _on_spell(arena_effect: StringName, pressure_gain: float) -> void:
	match arena_effect:
		&"pressure":
			_fireball(pressure_gain)
		&"stagger":
			_tremor()
		&"buff":
			_shield()
		&"heal":
			_heal()


func _on_incoming(result: Dictionary, pressure_gain: float) -> void:
	var hero_point := _hero_point()
	var lost := float(result.get("composure_lost", 0.0))
	match StringName(String(result.get("outcome", ""))):
		CombatHitResult.OUTCOME_HIT:
			_spawn(_burst(hero_point, 26, HIT_COLOR, 160.0, 0.35), EFFECT_HIT)
			_hit_vignette()
			_shake(SHAKE_HIT)
		CombatHitResult.OUTCOME_PARRIED:
			var sparks := _burst(hero_point.lerp(_opponent_point(), 0.25), 64, SPARK_COLOR, 620.0, 0.5)
			sparks.scale_amount_min = 0.1
			sparks.scale_amount_max = 0.28
			sparks.damping_min = 300.0
			sparks.damping_max = 700.0
			sparks.gravity = Vector2(0.0, 600.0)
			_spawn(sparks, EFFECT_PARRY)
			_flash(hero_point.lerp(_opponent_point(), 0.25), SPARK_COLOR, 70.0)
			if pressure_gain > 0.0:
				_number(_opponent_point(), pressure_gain, SPARK_COLOR, _pressure_bar)
		CombatHitResult.OUTCOME_GUARDED:
			_spawn(_burst(hero_point + Vector2(0.0, -40.0), 16, IRON_COLOR, 200.0, 0.3), EFFECT_GUARD)
		CombatHitResult.OUTCOME_INVULNERABLE:
			_spawn(_whoosh(hero_point), EFFECT_DODGE)
	if lost > 0.0:
		_number(hero_point, lost, HIT_COLOR, _composure_bar)


func _fireball(pressure_gain: float) -> void:
	var from := _hero_point()
	var to := _opponent_point()
	var land := func() -> void:
		_spawn(_burst(to, 48, Color(1.0, 0.55, 0.15), 260.0, 0.55, Parts.explosion_ramp().gradient), EFFECT_IMPACT)  # gdlint: ignore=max-line-length
		_flash(to, Color(1.0, 0.7, 0.3), 110.0)
		_shake(SHAKE_FIREBALL)
		if pressure_gain > 0.0:
			_number(to, pressure_gain, Color(1.0, 0.6, 0.25), _pressure_bar)
	var orb := Node2D.new()
	orb.name = "Fireball"
	orb.position = from
	var trail := _particles(70, 0.5, Parts.flame_ramp().gradient)
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 14.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 60.0
	trail.scale_amount_min = 0.9
	trail.scale_amount_max = 1.6
	trail.local_coords = false
	orb.add_child(trail)
	var core := _glow_sprite(Color(1.0, 0.9, 0.6), 1.3)
	orb.add_child(core)
	_spawn(orb, EFFECT_FIREBALL)
	if reduced_motion:
		orb.position = to
		land.call()
		get_tree().create_timer(0.3, true).timeout.connect(orb.queue_free)
		return
	var tween := orb.create_tween()
	tween.tween_property(orb, "position", to, FIREBALL_FLIGHT_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)  # gdlint: ignore=max-line-length
	tween.tween_callback(land)
	tween.tween_callback(
		func() -> void:
			trail.emitting = false
			core.visible = false
	)
	tween.tween_interval(0.6)
	tween.tween_callback(orb.queue_free)


func _tremor() -> void:
	var at := _opponent_point() + Vector2(0.0, 60.0)
	var ring := _RingEffect.new()
	ring.position = at
	ring.color = Color(0.62, 0.52, 0.38, 0.9)
	ring.max_radius = minf(size.x, 900.0) * 0.32
	ring.duration = 0.8
	_spawn(ring, EFFECT_TREMOR)
	var dust := _burst(at, 40, Color(0.6, 0.52, 0.42), 150.0, 0.9, Parts.dust_ramp(0.8).gradient)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(ring.max_radius * 0.6, 6.0)
	dust.direction = Vector2.UP
	dust.spread = 50.0
	dust.gravity = Vector2(0.0, 220.0)
	add_child(dust)
	_shake(SHAKE_TREMOR)


func _shield() -> void:
	var ring := _RingEffect.new()
	ring.position = _hero_point()
	ring.color = IRON_COLOR
	ring.max_radius = 140.0
	ring.duration = 1.6
	ring.shimmer = true
	_spawn(ring, EFFECT_SHIELD)
	_flash(_hero_point(), IRON_COLOR, 120.0)
	var glints := _burst(_hero_point(), 40, IRON_COLOR.lightened(0.3), 40.0, 1.2)
	glints.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	glints.emission_sphere_radius = 130.0
	glints.explosiveness = 0.3
	add_child(glints)


func _heal() -> void:
	var glow := _burst(_hero_point(), 30, HEAL_COLOR, 60.0, 1.0)
	glow.direction = Vector2.UP
	glow.gravity = Vector2(0.0, -40.0)
	glow.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	glow.emission_sphere_radius = 70.0
	_spawn(glow, EFFECT_HEAL)
	_flash(_hero_point(), HEAL_COLOR, 90.0)
	_number(_hero_point(), float(SpiritDuel.SPELL_HEAL_COMPOSURE), HEAL_COLOR, _composure_bar, "+")


func _strike(at: Vector2, pressure_gain: float) -> void:
	_spawn(_burst(at, 22, Color(0.95, 0.92, 0.85), 220.0, 0.35), EFFECT_STRIKE)
	_flash(at, Color(1.0, 0.95, 0.85), 60.0)
	if pressure_gain > 0.0:
		_number(at, pressure_gain, Color(0.95, 0.85, 0.7), _pressure_bar)


func _hit_vignette() -> void:
	var peak := VIGNETTE_PEAK_ALPHA * (REDUCED_FLASH_SCALE if reduced_flashing else 1.0)
	_vignette.modulate.a = peak
	move_child(_vignette, get_child_count() - 1)
	if _vignette_tween != null:
		_vignette_tween.kill()
	_vignette_tween = _vignette.create_tween()
	_vignette_tween.tween_property(_vignette, "modulate:a", 0.0, VIGNETTE_SEC)
	_note(EFFECT_VIGNETTE)


func _shake(amount: float) -> void:
	if not allow_shake or _shake_target == null:
		return
	_shake_trauma = clampf(_shake_trauma + amount, 0.0, 1.0)
	_note(EFFECT_SHAKE)


func _number(at: Vector2, amount: float, color: Color, bar: Control, prefix: String = "-") -> void:
	var label := Label.new()
	label.text = "%s%d" % [prefix, roundi(amount)]
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.03))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = at + Vector2(46.0, -24.0)
	_spawn(label, EFFECT_NUMBER)
	var tween := label.create_tween()
	if not reduced_motion:
		tween.tween_property(label, "position:y", label.position.y - NUMBER_RISE_PX, NUMBER_SEC)
		tween.parallel().tween_property(label, "modulate:a", 0.0, NUMBER_SEC).set_delay(NUMBER_SEC * 0.4)  # gdlint: ignore=max-line-length
	else:
		tween.tween_interval(NUMBER_SEC)
		tween.tween_property(label, "modulate:a", 0.0, 0.2)
	tween.tween_callback(label.queue_free)
	if bar != null:
		bar.modulate = Color(1.0, 1.0, 1.0) + Color(color.r, color.g, color.b, 0.0) * (0.3 if reduced_flashing else 1.0)  # gdlint: ignore=max-line-length
		bar.create_tween().tween_property(bar, "modulate", Color.WHITE, 0.4)
		_note(EFFECT_BAR_FLASH)


func _flash(at: Vector2, color: Color, radius: float) -> void:
	var sprite := _glow_sprite(color, radius / 32.0)
	sprite.position = at
	sprite.modulate.a = REDUCED_FLASH_SCALE if reduced_flashing else 1.0
	add_child(sprite)
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(sprite.queue_free)


func _whoosh(at: Vector2) -> CPUParticles2D:
	var streaks := _burst(at, 18, Color(0.85, 0.9, 1.0, 0.7), 420.0, 0.3)
	streaks.direction = Vector2.LEFT
	streaks.spread = 8.0
	streaks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	streaks.emission_rect_extents = Vector2(10.0, 50.0)
	streaks.scale_amount_min = 0.2
	streaks.scale_amount_max = 0.4
	return streaks


## One-shot radial burst that frees itself.
func _burst(at: Vector2, amount: int, color: Color, speed: float, lifetime: float, ramp: Gradient = null) -> CPUParticles2D:  # gdlint: ignore=max-line-length
	var burst := _particles(amount, lifetime, ramp)
	burst.position = at
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = speed * 0.4
	burst.initial_velocity_max = speed
	burst.damping_min = speed * 0.8
	burst.damping_max = speed * 1.6
	burst.scale_amount_min = 0.25
	burst.scale_amount_max = 0.6
	if ramp == null:
		burst.color = color
		var fade := Gradient.new()
		fade.set_color(0, Color.WHITE)
		fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		burst.color_ramp = fade
	burst.finished.connect(burst.queue_free)
	return burst


func _particles(amount: int, lifetime: float, ramp: Gradient) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.texture = Parts.soft_dot_texture()
	particles.material = _additive()
	if ramp != null:
		particles.color_ramp = ramp
	particles.emitting = true
	return particles


func _glow_sprite(color: Color, scale_factor: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = Parts.soft_dot_texture()
	sprite.modulate = color
	sprite.scale = Vector2.ONE * scale_factor
	sprite.material = _additive()
	return sprite


func _additive() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


func _spawn(node: Node, effect_id: StringName) -> void:
	add_child(node)
	_note(effect_id)


func _note(effect_id: StringName) -> void:
	spawned.append(effect_id)
	effect_spawned.emit(effect_id)


func _arena_size() -> Vector2:
	var arena := size
	if arena.x <= 0.0 or arena.y <= 0.0:
		arena = get_viewport_rect().size if is_inside_tree() else Vector2(1280.0, 720.0)
	return arena


func _hero_point() -> Vector2:
	return _arena_size() * HERO_ANCHOR


func _opponent_point() -> Vector2:
	return _arena_size() * OPPONENT_ANCHOR


## Transparent centre, blood-red edges; generated, no texture asset.
static func _vignette_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.6, 0.0, 0.0, 0.0))
	gradient.set_color(1, Color(0.65, 0.02, 0.02, 0.9))
	gradient.add_point(0.55, Color(0.6, 0.0, 0.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 1.0)
	texture.width = 256
	texture.height = 256
	return texture


## Expanding ring (tremor) or a pulsing shimmer ellipse (iron skin) drawn with `_draw`.
class _RingEffect:
	extends Node2D

	var color := Color.WHITE
	var max_radius := 100.0
	var duration := 0.8
	var shimmer := false
	var _age := 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		_age += delta
		if _age >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := clampf(_age / maxf(duration, 0.001), 0.0, 1.0)
		if shimmer:
			var pulse := 0.55 + 0.45 * sin(_age * 18.0)
			var fade := 1.0 - t * t
			var tint := Color(color.r, color.g, color.b, 0.55 * pulse * fade)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.75, 1.0))
			draw_circle(Vector2.ZERO, max_radius, Color(color.r, color.g, color.b, 0.22 * fade))
			draw_arc(Vector2.ZERO, max_radius, 0.0, TAU, 64, tint, 8.0, true)
			draw_arc(Vector2.ZERO, max_radius * 1.06, 0.0, TAU, 64, Color(tint, tint.a * 0.4), 3.0, true)
			draw_arc(Vector2.ZERO, max_radius * 0.86, _age * 3.0, _age * 3.0 + PI * 0.7, 24, tint, 3.0, true)  # gdlint: ignore=max-line-length
			return
		var radius := max_radius * (1.0 - pow(1.0 - t, 3.0))
		var alpha := color.a * (1.0 - t)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(color.r, color.g, color.b, alpha), 10.0 * (1.0 - t) + 2.0, true)  # gdlint: ignore=max-line-length
		draw_arc(Vector2.ZERO, radius * 0.7, 0.0, TAU, 72, Color(color.r, color.g, color.b, alpha * 0.5), 4.0, true)  # gdlint: ignore=max-line-length
