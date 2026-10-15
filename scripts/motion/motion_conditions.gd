extends RefCounted

## Situations as data (ADR 0051): each condition only says how it changes physical channels. Port of
## skeleto-nn `adapt/conditions.py`; the registry itself is the exported JSON, so the game and the
## trainer share one list. A new ground, weather or injury is a new JSON entry; if it only uses
## existing channels the network needs no retraining.
##
## Items are condition names, `[name, intensity, options]`, or a Dictionary of measured channel
## values.
## `channels_from([&"ice", [&"bleeding", 1.0, {"region": "thigh", "side": "L"}], [&"gale", 0.8,
## {"dir": PI / 2}]])`

const DEFAULT_PATH := "res://assets/motion/motion_conditions.json"

static var _shared: Dictionary = {}

var conditions: Dictionary = {}
var regions: Dictionary = {}
var region_pain: Dictionary = {}
## Channel specs from the network file: name -> {lo, hi, neutral}.
var _channel_specs: Dictionary = {}
var _memo: Dictionary = {}


static func shared(net: RefCounted, path: String = DEFAULT_PATH) -> RefCounted:
	if not _shared.has(path):
		var reg := new()
		if not reg.load_file(path, net):
			return null
		_shared[path] = reg
	return _shared[path]


func load_file(path: String, net: RefCounted) -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("MotionConditions: cannot read %s" % path)
		return false
	conditions = data.get("conditions", {})
	regions = data.get("regions", {})
	region_pain = data.get("region_pain", {})
	for c: Dictionary in net.channels:
		_channel_specs[c["name"]] = c
	return not conditions.is_empty()


func has_condition(name: String) -> bool:
	return conditions.has(name)


func neutral() -> Dictionary:
	var out := {}
	for name: String in _channel_specs:
		out[name] = float(_channel_specs[name]["neutral"])
	return out


## `channels_from` memoised by the condition list (situations repeat across creatures and frames).
## The returned dictionary is shared: callers must not modify it.
func channels_cached(active: Array) -> Dictionary:
	var key := active.hash()
	if not _memo.has(key):
		if _memo.size() > 256:
			_memo.clear()
		_memo[key] = channels_from(active)
	return _memo[key]


## Full channel dict for a list of active conditions; `base` (optional) is the starting point.
func channels_from(active: Array, base: Dictionary = {}) -> Dictionary:
	var ch := neutral() if base.is_empty() else base.duplicate()
	for item: Variant in active:
		if item is Dictionary:
			# Measured values straight from the world ({"air_temp": -6.0, "insulation": 0.7}).
			for key: String in item:
				if _channel_specs.has(key):
					ch[key] = float(item[key])
			continue
		var name := ""
		var k := 1.0
		var opt: Dictionary = {}
		if item is Array:
			name = String(item[0])
			if item.size() > 1:
				k = float(item[1])
			if item.size() > 2:
				opt = item[2]
		else:
			name = String(item)
		if not conditions.has(name):
			push_warning("MotionConditions: unknown condition %s" % name)
			continue
		var spec: Dictionary = conditions[name]
		var side: String = opt.get("side", "L")
		var effects: Dictionary = spec["effects"]
		for key: String in effects:
			var op: String = effects[key][0]
			var val := float(effects[key][1])
			if key == "wind":
				var d := float(opt.get("dir", 0.0))
				ch["wind_fwd"] = float(ch["wind_fwd"]) + val * k * cos(d)
				ch["wind_lat"] = float(ch["wind_lat"]) + val * k * sin(d)
				continue
			var channel := key
			if key == "pain@":
				channel = region_pain.get(opt.get("region", "thigh"), "pain_torso")
				if channel == "pain_leg" or channel == "pain_arm":
					channel += "_" + side
			channel = channel.replace("_S", "_" + side)
			if not _channel_specs.has(channel):
				continue
			var neutral_value := float(_channel_specs[channel]["neutral"])
			var cur := float(ch[channel])
			var tgt := val * k if op == "add" else neutral_value + (val - neutral_value) * k
			match op:
				"min":
					ch[channel] = minf(cur, tgt)
				"max":
					ch[channel] = maxf(cur, tgt)
				"add":
					ch[channel] = cur + tgt
				_:
					ch[channel] = tgt
		if bool(spec.get("region", false)):
			var point := region_point(opt.get("region", "thigh"), side)
			ch["wound_x"] = point.x
			ch["wound_y"] = point.y
			ch["wound_z"] = point.z
	for name: String in _channel_specs:
		var s: Dictionary = _channel_specs[name]
		ch[name] = clampf(float(ch[name]), float(s["lo"]), float(s["hi"]))
	return ch


## Body-frame point (x front, y left, z height 0..1) of a region such as "thigh" on a side.
func region_point(region: String, side: String = "L") -> Vector3:
	var key := region + "_S"
	var sided := regions.has(key)
	if not sided:
		key = region
	if not regions.has(key):
		return Vector3(0.0, 0.0, 0.5)
	var p: Array = regions[key]
	var y := float(p[1])
	if sided and side == "R":
		y = -y
	return Vector3(float(p[0]), y, float(p[2]))
