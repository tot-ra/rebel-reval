extends RefCounted

## Forward pass and decision of the skeleto-nn leap network (ADR 0053, docs/SYSTEMS/LEAPING.md).
##
## What lies ahead is a profile: every quarter leg length, the height of whatever is solid there
## (ground, a wall top, a bank) relative to the feet, and the depth of water standing on it. One
## small MLP is evaluated for every sample as a landing place, with the body, the situation channels
## of the style network (ice, a sore leg, a load, darkness, wet, cold ...) and a few numbers about
## that place (its height and water, the highest and lowest thing passed over, where the first edge
## is, how much room there is after landing). It answers a score against staying put and the jump
## program for landing there: where to take off, the arc, hands on the obstacle, tucked legs, how
## deep the landing gives, a roll, lowering oneself from an edge first, arms out, trunk lean. The
## best place wins, or staying. Hop, vault, pull-up, jump down, hang-drop, into the water and
## refusing are what comes out; nothing here names them except `label` for logs and tests.
## Weights: `assets/motion/leap_net.json` (`python -m adapt.export_engine assets/motion`).

const DEFAULT_PATH := "res://assets/motion/leap_net.json"
const G := 9.81

static var _shared: Dictionary = {}

var n_samples := 20
var spacing := 0.25
var hang := 2.1
var z_clip := 12.0
var margin := 0.15
## Channel specs in input order: {name, lo, hi, neutral, scale, log}.
var channels: Array[Dictionary] = []
## Knob specs in output order after the score: {name, lo, hi, neutral, kinds}.
var knobs: Array[Dictionary] = []
var body_spec: Dictionary = {}

var _weights: Array[PackedFloat32Array] = []
var _biases: Array[PackedFloat32Array] = []
var _sizes: PackedInt32Array = []


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
		push_error("MotionLeapNet: cannot read %s" % path)
		return false
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("MotionLeapNet: %s is not a JSON object" % path)
		return false
	return load_dict(data)


func load_dict(data: Dictionary) -> bool:
	var samples: Dictionary = data.get("samples", {})
	n_samples = int(samples.get("n", 20))
	spacing = float(samples.get("spacing", 0.25))
	hang = float(data.get("hang", 2.1))
	z_clip = float(data.get("z_clip", 12.0))
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
	var n_in := (data.get("inputs", []) as Array).size()
	_sizes = PackedInt32Array([n_in])
	for layer: Dictionary in data.get("layers", []):
		var rows: Array = layer["W"]
		var flat := PackedFloat32Array()
		for row: Array in rows:
			flat.append_array(PackedFloat32Array(row))
		_weights.append(flat)
		_biases.append(PackedFloat32Array(layer["b"]))
		_sizes.append(rows.size())
	return not _weights.is_empty() and _sizes[_sizes.size() - 1] == 1 + knobs.size()


## Distance of sample `i` ahead of the feet, in leg lengths.
func sample_x(i: int) -> float:
	return spacing * float(i + 1)


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


func encode_shared(
	kind: StringName,
	mass: float,
	leg: float,
	speed_norm: float,
	gain: float,
	urgency: float,
	ch: Dictionary
) -> PackedFloat32Array:
	var v := PackedFloat32Array(
		[
			1.0 if kind == &"biped" else 0.0,
			1.0 if kind == &"quadruped" else 0.0,
			(
				log(maxf(mass, 1e-4) / float(body_spec.get("mass_ref", 30.0)))
				/ float(body_spec.get("mass_div", 2.0))
			),
			log(maxf(leg, 1e-4) / float(body_spec.get("leg_ref", 0.5))),
			clampf(speed_norm, 0.0, float(body_spec.get("speed_max", 3.0))),
			log(maxf(gain, 1e-3)),
			urgency,
		]
	)
	for c in channels:
		var value := float(ch.get(c["name"], c["neutral"]))
		var e := 0.0
		if bool(c.get("log", false)):
			e = log(maxf(value, 1e-3) / float(c["neutral"])) / float(c["scale"])
		else:
			e = (value - float(c["neutral"])) / float(c["scale"])
		v.append(clampf(e, -3.0, 3.0))
	return v


## Geometry of every landing place from a profile in leg lengths (heights `z`, water `w`), the
## same ten numbers for any scene (skeleto-nn `adapt.leap.cand_features`).
func candidate_features(z: PackedFloat32Array, w: PackedFloat32Array) -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	var n := n_samples
	for k in n:
		var top := 0.0
		var low := 0.0
		var arg := 0
		var wmax := 0.0
		for i in k:
			if z[i] > top:
				top = z[i]
				arg = i + 1
			low = minf(low, z[i])
			wmax = maxf(wmax, w[i])
		var x_top := 0.0
		if top > 0.3 and arg > 0:
			x_top = sample_x(arg - 1)
		var first := sample_x(k)
		for i in k + 1:
			if absf(z[i]) > 0.3 or w[i] > 0.3:
				first = sample_x(i)
				break
		var run := 0
		for j in range(k + 1, n):
			if absf(z[j] - z[k]) < 0.3:
				run += 1
			else:
				break
		var room := float(run) * spacing + (1.0 if run == n - 1 - k else 0.0)
		var nxt := (z[k + 1] if k + 1 < n else z[k]) - z[k]
		(
			out
			. append(
				PackedFloat32Array(
					[
						sample_x(k) / 5.0,
						clampf(z[k] / 3.0, -3.0, 3.0),
						clampf(w[k] / 2.0, 0.0, 3.0),
						clampf(top / 3.0, -3.0, 3.0),
						clampf(low / 3.0, -3.0, 3.0),
						clampf(wmax / 2.0, 0.0, 3.0),
						first / 5.0,
						clampf(room / 5.0, 0.0, 1.5),
						clampf(nxt / 3.0, -3.0, 3.0),
						x_top / 5.0,
					]
				)
			)
		)
	return out


## Decide for a body facing a profile in metres: `z_m` heights relative to the feet, `w_m` water
## depths, both sampled every `spacing * leg` ahead; `standable` false where nothing can be stood
## on (a thin wall top). Speed in m/s. Returns {action: "refuse"|"jump", label, knobs, cell,
## take_m, land_m, land_z_m, start_z_m, apex_m, flight_s, rise_s, water_m}.
func decide(
	kind: StringName,
	mass: float,
	leg: float,
	speed_mps: float,
	gain: float,
	urgency: float,
	ch: Dictionary,
	z_m: PackedFloat32Array,
	w_m: PackedFloat32Array,
	standable: Array = []
) -> Dictionary:
	var zn := PackedFloat32Array()
	var wn := PackedFloat32Array()
	for i in n_samples:
		zn.append(z_m[i] / leg)
		wn.append(w_m[i] / leg)
	var shared_in := encode_shared(kind, mass, leg, speed_mps / sqrt(G * leg), gain, urgency, ch)
	var feats := candidate_features(zn, wn)
	var best := -1
	var best_score := 0.0
	var outs: Array[PackedFloat32Array] = []
	for k in n_samples:
		var x := shared_in.duplicate()
		x.append_array(feats[k])
		var o := forward(x)
		outs.append(o)
		if not standable.is_empty() and not bool(standable[k]):
			continue
		if o[0] > best_score:
			best_score = o[0]
			best = k
	if best < 0:
		return {"action": "refuse", "label": "refuse", "knobs": neutral_knobs()}
	var kn := {}
	var kz := outs[best]
	for j in knobs.size():
		var k: Dictionary = knobs[j]
		var lo := float(k["lo"])
		var hi := float(k["hi"])
		var m := margin * (hi - lo)
		var s := 1.0 / (1.0 + exp(-kz[1 + j]))
		var v := clampf(lo - m + (hi - lo + 2.0 * m) * s, lo, hi)
		kn[k["name"]] = v if String(kind) in k["kinds"] else float(k["neutral"])
	var res := arc(kn, best, zn, wn, leg, kind)
	res["action"] = "jump"
	res["cell"] = best
	res["knobs"] = kn
	res["label"] = label(best, zn, wn, kn)
	return res


func neutral_knobs() -> Dictionary:
	var out := {}
	for k: Dictionary in knobs:
		out[k["name"]] = float(k["neutral"])
	return out


## The flight the knobs describe, in metres and seconds (skeleto-nn `adapt.leap.arc`).
func arc(
	kn: Dictionary,
	cell: int,
	zn: PackedFloat32Array,
	wn: PackedFloat32Array,
	leg: float,
	kind: StringName
) -> Dictionary:
	var x_land := sample_x(cell)
	var z_land := maxf(zn[cell], -z_clip)
	var take := float(kn["take"])
	var low := float(kn["lower"]) if kind == &"biped" else 0.0
	var drop := maxf(-z_land, 0.0)
	low = low / (1.0 + exp(-(drop - 0.3) / 0.08))
	var z_start := -low * minf(drop, hang)
	var top := -20.0
	for i in cell:
		if sample_x(i) > take + 0.1:
			top = maxf(top, zn[i])
	var za := maxf(maxf(z_start, z_land), top) + float(kn["apex"])
	var t_up := sqrt(2.0 * maxf(za - z_start, 0.0) + 1e-4)
	var t_down := sqrt(2.0 * maxf(za - z_land, 0.0) + 1e-4)
	var s := sqrt(leg / G)
	return {
		"take_m": take * leg,
		"land_m": x_land * leg,
		"land_z_m": z_land * leg,
		"start_z_m": z_start * leg,
		"apex_m": za * leg,
		"flight_s": (t_up + t_down) * s,
		"rise_s": t_up * s,
		"water_m": wn[cell] * leg,
	}


## A word for the result, for logs, tests and the docs (skeleto-nn `adapt.leap.label`).
func label(cell: int, zn: PackedFloat32Array, wn: PackedFloat32Array, kn: Dictionary) -> String:
	var z_land := zn[cell]
	var top := z_land
	var low := 0.0
	for i in cell:
		if sample_x(i) > float(kn["take"]) + 0.1:
			top = maxf(top, zn[i])
			low = minf(low, zn[i])
	if float(kn["lower"]) > 0.5 and z_land < -0.5:
		return "hang-drop"
	if wn[cell] > 0.8 and z_land < -0.3:
		return "jump into water"
	if float(kn["hands"]) > 0.5 and z_land > 0.4:
		return "pull up onto"
	if float(kn["hands"]) > 0.5 and top > 0.25:
		return "vault"
	if z_land > 0.3:
		return "jump up onto"
	if z_land < -0.5:
		return "jump down"
	if top > 0.25:
		return "hop over"
	if low < -0.3:
		return "leap the gap"
	return "hop"
