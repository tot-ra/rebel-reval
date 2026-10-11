extends SceneTree

## WR-6 probe: where does the sandbox spray fire and how often (headless, no GPU).
##   godot --headless --path . --script tools/water_sandbox/spray_probe.gd [-- --wind=0.95]
## Prints, per case, the active slots (spot, breaking) and the bursts fired over 27 s
## of ocean time (three wave periods) at the case's close camera.

const SANDBOX_PATH := "res://tools/water_sandbox/water_sandbox.gd"


func _init() -> void:
	var wind := 0.95
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--wind="):
			wind = float(arg.get_slice("=", 1))
	var sandbox: Node3D = load(SANDBOX_PATH).create()
	root.add_child(sandbox)
	var spray: Node3D = sandbox.world.spray
	spray.set_wind(wind)
	for id: String in sandbox.case_ids():
		var eye: Vector3 = sandbox.shots_for(id)["close"][0]
		spray.place_slots(Vector2(eye.x, eye.z))
		var active := 0
		var line := PackedStringArray()
		for slot in spray._slots:
			if slot.active:
				active += 1
				line.append("(%.0f,%.0f b%.2f)" % [slot.spot.x, slot.spot.y, slot.breaking])
		var bursts := 0
		for step in 55:
			bursts += spray.update_events(float(step) * 0.5)
		print("%s: %d/%d slots active, %d bursts in 27 s %s" % [
			id, active, spray._slots.size(), bursts, " ".join(line)
		])
	quit()
