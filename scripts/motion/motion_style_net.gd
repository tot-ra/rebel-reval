extends RefCounted

## Forward pass of the skeleto-nn style network (ADR 0051, docs/SYSTEMS/MOTION_STYLE.md).
##
## A small MLP maps a body (biped, quadruped or bird; mass; leg length; flying; speed as a Froude
## number) and situation channels (friction, sink, wetness, temperature, wind, wounds, pain,
## fatigue,
## ...) to motor-style knobs (stride, crouch, trunk lean, arms hugged or out, a hand on a wound,
## shiver, limp, tail tuck, wingbeat ...). The weights and both schemas come from one JSON file
## exported by skeleto-nn (`python -m adapt.export_engine assets/motion`); nothing here names a
## situation. Results are cached by quantised input, because most creatures in view share the same
## ground and weather and the situation changes slowly.

const DEFAULT_PATH := "res://assets/motion/style_net.json"
const KINDS: Array[StringName] = [&"biped", &"quadruped", &"bird"]
const CACHE_LIMIT := 512

static var _shared: Dictionary = {}

var inputs: PackedStringArray = []
var outputs: PackedStringArray = []
## Channel specs in input order: {name, lo, hi, neutral, scale, log}.
var channels: Array[Dictionary] = []
## Knob specs in output order: {name, lo, hi, neutral, kinds, air}.
var knobs: Array[Dictionary] = []
var margin := 0.15
var body_spec: Dictionary = {}

var _weights: Array[PackedFloat32Array] = []
var _biases: Array[PackedFloat32Array] = []
var _sizes: PackedInt32Array = []
var _cache: Dictionary = {}
var _cache_order: Array = []


static func shared(path: String = DEFAULT_PATH) -> RefCounted:
	if not _shared.has(path):
		var net := new()
		if not net.load_file(path):
			return null
		_shared[path] = net
	return _shared[path]


func load_file(path: String) -> bool:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("MotionStyleNet: cannot read %s" % path)
		return false
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("MotionStyleNet: %s is not a JSON object" % path)
		return false
	return load_dict(data)


func load_dict(data: Dictionary) -> bool:
	inputs = PackedStringArray(data.get("inputs", []))
	outputs = PackedStringArray(data.get("outputs", []))
	margin = float(data.get("margin", 0.15))
	body_spec = data.get("body", {})
	channels.clear()
	for c: Dictionary in data.get("channels", []):
		channels.append(c)
	knobs.clear()
	for k: Dictionary in data.get("knobs", []):
		knobs.append(k)
	_weights.clear()
	_biases.clear()
	_sizes = PackedInt32Array([inputs.size()])
	for layer: Dictionary in data.get("layers", []):
		var rows: Array = layer["W"]
		var flat := PackedFloat32Array()
		for row: Array in rows:
			flat.append_array(PackedFloat32Array(row))
		_weights.append(flat)
		_biases.append(PackedFloat32Array(layer["b"]))
		_sizes.append(rows.size())
	return not _weights.is_empty() and _sizes[_sizes.size() - 1] == outputs.size()


func neutral_channels() -> Dictionary:
	var out := {}
	for c in channels:
		out[c["name"]] = float(c["neutral"])
	return out


func encode_body(
	kind: StringName, mass: float, leg: float, airborne: bool, froude: float
) -> PackedFloat32Array:
	var v := PackedFloat32Array()
	for k in KINDS:
		v.append(1.0 if k == kind else 0.0)
	v.append(
		(
			log(maxf(mass, 1e-4) / float(body_spec.get("mass_ref", 30.0)))
			/ float(body_spec.get("mass_div", 2.0))
		)
	)
	v.append(
		(
			log(maxf(leg, 1e-4) / float(body_spec.get("leg_ref", 0.5)))
			/ float(body_spec.get("leg_div", 1.0))
		)
	)
	v.append(1.0 if airborne else 0.0)
	v.append(minf(froude, float(body_spec.get("froude_max", 3.0))))
	return v


func encode_channels(ch: Dictionary) -> PackedFloat32Array:
	var v := PackedFloat32Array()
	for c in channels:
		var value := float(ch.get(c["name"], c["neutral"]))
		var e := 0.0
		if bool(c.get("log", false)):
			e = log(maxf(value, 1e-3) / float(c["neutral"])) / float(c["scale"])
		else:
			e = (value - float(c["neutral"])) / float(c["scale"])
		v.append(clampf(e, -3.0, 3.0))
	return v


func forward(x: PackedFloat32Array) -> PackedFloat32Array:
	var h := x
	var last := _weights.size() - 1
	for li in _weights.size():
		var w := _weights[li]
		var b := _biases[li]
		var n_in := _sizes[li]
		var n_out := _sizes[li + 1]
		var out := PackedFloat32Array()
		out.resize(n_out)
		for o in n_out:
			var s := b[o]
			var base := o * n_in
			for i in n_in:
				s += w[base + i] * h[i]
			out[o] = tanh(s) if li < last else s
		h = out
	return h


## Raw style for a body in a situation: {knob name: value}.
func style(
	kind: StringName, mass: float, leg: float, airborne: bool, froude: float, ch: Dictionary
) -> Dictionary:
	var x := encode_body(kind, mass, leg, airborne, froude)
	x.append_array(encode_channels(ch))
	var key := _key(x)
	if _cache.has(key):
		return _cache[key]
	var z := forward(x)
	var out := {}
	for j in knobs.size():
		var k: Dictionary = knobs[j]
		var lo := float(k["lo"])
		var hi := float(k["hi"])
		var m := margin * (hi - lo)
		var sig := 1.0 / (1.0 + exp(-z[j]))
		out[k["name"]] = clampf(lo - m + (hi - lo + 2.0 * m) * sig, lo, hi)
	_remember(key, out)
	return out


## The style applied to a creature: neutral + style(situation) - style(no situation), so a creature
## in
## a normal situation moves exactly as its clips and planner already make it move. Knobs this body
## cannot express (a dog has no hands to press a wound) stay neutral.
func calibrated(
	kind: StringName, mass: float, leg: float, airborne: bool, froude: float, ch: Dictionary
) -> Dictionary:
	var st := style(kind, mass, leg, airborne, froude, ch)
	var base := style(kind, mass, leg, airborne, froude, neutral_channels())
	var out := {}
	for k: Dictionary in knobs:
		var name: String = k["name"]
		if knob_active(k, kind, airborne):
			out[name] = clampf(
				float(k["neutral"]) + st[name] - base[name], float(k["lo"]), float(k["hi"])
			)
		else:
			out[name] = float(k["neutral"])
	return out


func neutral_style() -> Dictionary:
	var out := {}
	for k: Dictionary in knobs:
		out[k["name"]] = float(k["neutral"])
	return out


static func knob_active(k: Dictionary, kind: StringName, airborne: bool) -> bool:
	if not String(kind) in k["kinds"]:
		return false
	var air: String = k.get("air", "ground")
	if air == "both":
		return true
	return (air == "air") == airborne


func cache_size() -> int:
	return _cache.size()


func _key(x: PackedFloat32Array) -> String:
	# Quantised to 1/50 of an encoded unit: finer than any visible change of style.
	var parts := PackedStringArray()
	for v in x:
		parts.append(str(roundi(v * 50.0)))
	return ",".join(parts)


func _remember(key: String, value: Dictionary) -> void:
	_cache[key] = value
	_cache_order.append(key)
	if _cache_order.size() > CACHE_LIMIT:
		_cache.erase(_cache_order.pop_front())
