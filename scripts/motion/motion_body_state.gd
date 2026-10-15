extends RefCounted

## A creature's own state over time (ADR 0051): wetness, core cooling, blood lost, fatigue, pain and
## open wounds. Port of skeleto-nn `adapt/physiology.py` (same equations; golden values in
## tests/godot/fixtures/motion/style_net_golden.json). Rain soaks the body unless sheltered, water
## soaks it at once, warmth, wind and a fire dry it; the core cools by the same heat balance the
## network was trained on, so the style in use (hugging, hunching, shivering) changes how fast; a
## hand
## on a wound slows the blood loss and the clotting is faster under pressure. Times are seconds.

const PAIN_CHANNELS: Array[String] = [
	"pain_leg_L",
	"pain_leg_R",
	"pain_arm_L",
	"pain_arm_R",
	"pain_torso",
	"pain_head",
]

var mass := 70.0
var wet := 0.0
var core_cold := 0.0
var blood_lost := 0.0
var fatigue := 0.0
var pain: Dictionary = {}
## Each wound: {region, side, rate, pain, point: Vector3 (body frame), pain_channel}.
var wounds: Array[Dictionary] = []


func _init(body_mass: float = 70.0) -> void:
	mass = body_mass
	for k in PAIN_CHANNELS:
		pain[k] = 0.0


func add_wound(
	region: String, side: String, rate: float, wound_pain: float, conditions: RefCounted
) -> void:
	var channel: String = conditions.region_pain.get(region, "pain_torso")
	if channel == "pain_leg" or channel == "pain_arm":
		channel += "_" + side
	(
		wounds
		. append(
			{
				"region": region,
				"side": side,
				"rate": rate,
				"pain": wound_pain,
				"point": conditions.region_point(region, side),
				"pain_channel": channel,
			}
		)
	)


func bleed_rate() -> float:
	var worst := 0.0
	for w in wounds:
		worst = maxf(worst, float(w["rate"]))
	return worst


## The body's channels, to be merged over the surroundings.
func channels() -> Dictionary:
	var ch := {
		"wet": wet,
		"core_cold": core_cold,
		"blood_lost": blood_lost,
		"fatigue": fatigue,
		"bleed": 0.0
	}
	for k: String in pain:
		ch[k] = pain[k]
	var worst: Dictionary = {}
	for w in wounds:
		var c: String = w["pain_channel"]
		ch[c] = maxf(float(ch.get(c, 0.0)), float(w["pain"]))
		if worst.is_empty() or float(w["rate"]) > float(worst["rate"]):
			worst = w
	if not worst.is_empty():
		ch["bleed"] = float(worst["rate"])
		var p: Vector3 = worst["point"]
		ch["wound_x"] = p.x
		ch["wound_y"] = p.y
		ch["wound_z"] = p.z
	return ch


## (loss, production) of heat, same formula as the network's teacher (model.py).
static func heat_balance(
	ch: Dictionary, st: Dictionary, kind: StringName, airborne: bool, power: float
) -> Vector2:
	var fur := 1.0 if kind == &"quadruped" or kind == &"bird" else 0.0
	var gnd := 0.0 if airborne else 1.0
	var d_t := maxf(0.0, 37.0 - float(ch["air_temp"])) / 40.0
	var wind := (
		Vector2(float(ch["wind_fwd"]), float(ch["wind_lat"])).length() + (0.5 if airborne else 0.0)
	)
	var w := float(ch["wet"])
	var insul_fluff := float(st.get("fluff", 0.0)) * fur * (0.4 - 0.3 * w)
	var pitch := clampf(float(st.get("trunk_pitch", 0.0)), 0.0, 0.7) / 0.7
	var exposed := (
		1.0
		- 0.16 * (float(st.get("hug_L", 0.0)) + float(st.get("hug_R", 0.0))) * gnd
		- 0.12 * pitch
		- 0.07 * float(st.get("head_down", 0.0))
		- 0.08 * float(st.get("shrug", 0.0))
		- 0.1 * float(st.get("crouch", 0.0))
		- 0.05 * float(st.get("tail_tuck", 0.0))
		- insul_fluff
		+ 0.12 * float(st.get("arm_out", 0.0))
	)
	exposed = clampf(exposed, 0.2, 1.3)
	var insulation := float(ch["insulation"]) * (1.0 - 0.6 * w)
	var loss := (
		d_t * (1.0 + 2.2 * w) * (1.0 + 0.6 * sqrt(wind + 1e-6)) * exposed * (1.3 - insulation)
	)
	var prod := (
		0.38 + 0.5 * power + 1.3 * float(st.get("tremor", 0.0)) * (1.0 - 0.4 * float(ch["fatigue"]))
	)
	return Vector2(loss, prod)


## Advance by dt seconds. `env`: surroundings channels; `exposure`: {rain, shelter, immersion, fire}
## (0..1 each); `st`: the style in use; `power`: normalised effort; `press_eff`: how well a hand
## presses.
func step(
	dt: float,
	env: Dictionary,
	exposure: Dictionary,
	st: Dictionary,
	kind: StringName,
	airborne: bool,
	power: float,
	press_eff: float = 0.0
) -> void:
	var size := pow(mass / 70.0, 1.0 / 3.0)
	var rain := float(exposure.get("rain", 0.0))
	var shelter := float(exposure.get("shelter", 0.0))
	var immersion := float(exposure.get("immersion", 0.0))
	var fire := float(exposure.get("fire", 0.0))
	var wind := Vector2(float(env["wind_fwd"]), float(env["wind_lat"])).length()
	var dry := (
		0.0012
		* (1.0 + maxf(float(env["air_temp"]), 0.0) / 12.0)
		* (1.0 + 2.0 * wind)
		* (1.0 + 4.0 * fire)
	)
	wet += (rain * (1.0 - shelter) * 0.012 + immersion * 0.5) * (1.0 - wet) * dt - dry * wet * dt
	wet = clampf(wet, 0.0, 1.0)
	var ch := env.duplicate()
	ch["wet"] = wet
	ch["fatigue"] = fatigue
	if fire > 0.0:
		ch["air_temp"] = float(ch["air_temp"]) + 30.0 * fire
	var heat := heat_balance(ch, st, kind, airborne, power)
	core_cold = clampf(core_cold + (heat.x - heat.y - 0.12) / (420.0 * size) * dt, 0.0, 1.0)
	var heart := 0.55 + 0.45 * power / 0.3
	var kept: Array[Dictionary] = []
	for w in wounds:
		blood_lost += float(w["rate"]) * (1.0 - 0.8 * press_eff) * heart * dt / 900.0
		w["rate"] = float(w["rate"]) * exp(-dt / (240.0 / (1.0 + 2.0 * press_eff)))
		w["pain"] = float(w["pain"]) * exp(-dt / 1800.0)
		if float(w["rate"]) > 0.02 or float(w["pain"]) > 0.05:
			kept.append(w)
	wounds = kept
	blood_lost = minf(1.0, blood_lost)
	if power > 0.45:
		fatigue = clampf(fatigue + (power - 0.45) / 300.0 * dt, 0.0, 1.0)
	else:
		fatigue = clampf(fatigue - 0.004 * dt, 0.0, 1.0)
	for k: String in pain:
		pain[k] = float(pain[k]) * exp(-dt / 600.0)


func to_dict() -> Dictionary:
	var ws: Array = []
	for w in wounds:
		ws.append({"region": w["region"], "side": w["side"], "rate": w["rate"], "pain": w["pain"]})
	return {
		"wet": wet,
		"core_cold": core_cold,
		"blood_lost": blood_lost,
		"fatigue": fatigue,
		"pain": pain.duplicate(),
		"wounds": ws
	}
