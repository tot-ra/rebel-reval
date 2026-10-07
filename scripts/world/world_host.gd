class_name WorldHost
extends Node

## Additive-residency host for one contiguous outdoor world group (ADR 0019).
## Phase 2 (configure): the host owns location-package roots and references global
## owners created elsewhere. Phase 3 (create_globals, WB-06 / R-978): the host itself
## creates and owns the single player, player rig, gameplay camera, WorldEnvironment,
## sun, sky/weather, day/night clock, HUD, and one 2D navigation map; location
## packages that create any of those are rejected with a named diagnostic.
## It never performs scene swaps; everything ships behind the default-off flag.

signal location_mounted(location_id: StringName)
signal location_unmounted(location_id: StringName)
signal seam_activation_changed(seam_id: String, active: bool)
## A mount was refused. Each diagnostic is {code, location_id, node_path, detail}.
signal package_rejected(location_id: StringName, diagnostics: Array)
## WB-08: the player crossed a streamed seam. Nothing is re-created; only the
## owning location (save identity, ambience, quest scope) changes.
signal owning_location_changed(previous_id: StringName, location_id: StringName)
## WB-08: the player reached a location that could not be mounted. A launch
## adapter answers with today's DoorNavigator scene swap through `transition_id`.
signal scene_swap_fallback_requested(location_id: StringName, seam: Dictionary)

const ADDITIVE_RESIDENCY_SETTING := "world_host/additive_residency_enabled"
const SCENE_SWAP_FALLBACK_SETTING := "world_host/scene_swap_fallback_enabled"
## WB-08 streaming policy. Derivation (docs/SEAMLESS_STREAMING_PLAN.md): the
## slowest staged location mount measured by R-979/R-1005 is ~4.7 s wall time
## (lower_town_slice at a 4 ms budget); a running player covers 240 px/s = 7.5
## cells/s, so 7.5 x 4.7 x ~1.35 safety = 48 cells of warning before the seam.
const STREAMING_PREFETCH_BAND_SETTING := "world_host/streaming_prefetch_band_cells"
## Eviction band = prefetch + 16 cells (about 2 s of running) of hysteresis so
## pacing along the prefetch line cannot mount/evict the same neighbour per frame.
const STREAMING_EVICTION_BAND_SETTING := "world_host/streaming_eviction_band_cells"
## Owner plus the two neighbours of a seam corner. Lower Town alone is already
## over the ADR 0019 node/memory caps, so a larger cap would only hide that.
const STREAMING_RESIDENCY_CAP_SETTING := "world_host/streaming_residency_cap"
const DEFAULT_PREFETCH_BAND_CELLS := 48.0
const DEFAULT_EVICTION_BAND_CELLS := 64.0
const DEFAULT_RESIDENCY_CAP := 3
const LOGIC_LOCATIONS_NAME := "LogicLocations"
const VIEW_LOCATIONS_NAME := "ViewLocations"
const SEAM_LINKS_NAME := "SeamLinks"
const GLOBALS_NAME := "Globals"
const LOGIC_GLOBALS_NAME := "LogicGlobals"
const VIEW_GLOBALS_NAME := "ViewGlobals"
const HUD_NAME := "HUD"
## WB-06b: node name a launch adapter gives the host under its scene root.
const HOST_NODE_NAME := "WorldHost"
const PLAYER_SCENE_PATH := "res://player.tscn"
const PLAYER_RIG_SCENE_PATH := "res://assets/characters/kalev/kalev.tscn"
const MINIMAP_HUD_SCENE_PATH := "res://scenes/elements/minimap_hud.tscn"
## Stable diagnostic codes (tests and tooling match on them).
const DIAG_PACKAGE_CREATES_GLOBAL := "WORLD_HOST_PACKAGE_CREATES_GLOBAL"
const DIAG_DUPLICATE_STABLE_HANDLE := "WORLD_HOST_DUPLICATE_STABLE_HANDLE"
const DIAG_MISSING_OBJECT_ID := "WORLD_HOST_STABLE_HANDLE_MISSING_OBJECT_ID"
const DIAG_UNKNOWN_LOCATION := "WORLD_HOST_UNKNOWN_LOCATION"
const DIAG_ALREADY_MOUNTED := "WORLD_HOST_LOCATION_ALREADY_MOUNTED"
const DIAG_RESIDENCY_INACTIVE := "WORLD_HOST_RESIDENCY_INACTIVE"

var additive_residency_enabled: bool
var scene_swap_fallback_enabled: bool
var player_owner: Node
var camera_owner: Camera3D
var session_owner: Node
var world_layout: Dictionary = {}
## Phase 3 globals. Null until create_globals(); phase 2 callers never set them.
var player_rig: Node3D
var sun: DirectionalLight3D
var environment: Environment
var world_environment: WorldEnvironment
var sky_weather: SkyWeather3D
var hud_layer: CanvasLayer
var minimap_hud: MinimapHud
var music_director: Node
## Host-owned save binding. Identity stays {location_id, object_id} plus global
## cell/sub-cell exactly as MapStableStateStore defines it; the host adds no field.
var stable_state_store: MapStableStateStore
## Host-owned day/night clock (DayNightCycle fraction plus whole days crossed).
var clock_progress: float = DayNightCycle.system_progress()
var clock_completed_days := 0
## WB-08 streaming policy (project settings; tests may override per host).
var prefetch_band_cells: float
var eviction_band_cells: float
var residency_cap: int
## Callable(location_id: StringName) -> bool that builds and mounts a location.
## Falls back to `definition_provider` + enter_location() when unset.
var location_loader: Callable
## Callable(location_id: StringName) -> MapDefinition.
var definition_provider: Callable
## Never evicted while listed. R-1054 clears this after owner-scoped rebind.
var pinned_location_ids: Array[StringName] = []

var _logic_locations: Node
var _view_locations: Node3D
var _locations_by_id: Dictionary = {}
var _mounted_locations: Dictionary = {}
var _stable_handle_owners: Dictionary = {}
var _duplicate_stable_handles: Array[Dictionary] = []
var _last_global_logic_position := Vector2.ZERO
var _last_location_id: StringName = &""
var _configured := false
var _owns_globals := false
var _globals_root: Node
var _navigation_map := RID()
var _seam_links: Node2D
var _last_rejection: Array[Dictionary] = []
var _owning_location_id: StringName = &""
var _mount_failures: Dictionary = {}
var _fallback_request: Dictionary = {}


func _init() -> void:
	# Project settings provide the shipping default. Tests and a future launch
	# adapter may explicitly opt into the prototype without changing that default.
	additive_residency_enabled = bool(
		ProjectSettings.get_setting(ADDITIVE_RESIDENCY_SETTING, false)
	)
	scene_swap_fallback_enabled = bool(
		ProjectSettings.get_setting(SCENE_SWAP_FALLBACK_SETTING, false)
	)
	prefetch_band_cells = float(
		ProjectSettings.get_setting(STREAMING_PREFETCH_BAND_SETTING, DEFAULT_PREFETCH_BAND_CELLS)
	)
	eviction_band_cells = float(
		ProjectSettings.get_setting(STREAMING_EVICTION_BAND_SETTING, DEFAULT_EVICTION_BAND_CELLS)
	)
	residency_cap = int(
		ProjectSettings.get_setting(STREAMING_RESIDENCY_CAP_SETTING, DEFAULT_RESIDENCY_CAP)
	)


## Bind global owners and a pre-built MapWorldLayout. No package is mounted when
## the additive feature is disabled, so existing scene entry points remain inert.
func configure(layout: Dictionary, player: Node, camera: Camera3D, session: Node) -> bool:
	if not bool(layout.get("valid", false)):
		return false
	if player == null or camera == null or session == null:
		return false
	if (
		_configured
		and (player_owner != player or camera_owner != camera or session_owner != session)
	):
		return false

	world_layout = layout.duplicate(true)
	player_owner = player
	camera_owner = camera
	session_owner = session
	_locations_by_id.clear()
	for entry_value in world_layout.get("locations", []):
		var entry: Dictionary = entry_value as Dictionary
		var location_id := StringName(entry.get("location_id", ""))
		if location_id.is_empty():
			continue
		_locations_by_id[location_id] = entry.duplicate(true)
	_configured = true
	_ensure_mount_roots()
	return true


## WB-06 phase 3: create the one global set under `Globals`, then bind it exactly
## like configure(). Options (all optional, for tests and launch adapters):
## `player_scene` / `player_rig_scene` (PackedScene), `session` (Node, defaults to
## the SessionState autoload), `music_director` (Node, defaults to the autoload).
## Returns false without creating anything when the layout is invalid or the host
## is already configured.
func create_globals(layout: Dictionary, options: Dictionary = {}) -> bool:
	if _configured or not bool(layout.get("valid", false)):
		return false
	var root := _scene_root()
	var session := options.get("session") as Node
	if session == null and root != null:
		session = root.get_node_or_null("SessionState")
	if session == null:
		return false
	music_director = options.get("music_director") as Node
	if music_director == null and root != null:
		music_director = root.get_node_or_null("MusicDirector")

	_globals_root = Node.new()
	_globals_root.name = GLOBALS_NAME
	add_child(_globals_root)
	var logic_globals := Node2D.new()
	logic_globals.name = LOGIC_GLOBALS_NAME
	_globals_root.add_child(logic_globals)
	var view_globals_root := Node3D.new()
	view_globals_root.name = VIEW_GLOBALS_NAME
	_globals_root.add_child(view_globals_root)

	var player_scene := options.get("player_scene", load(PLAYER_SCENE_PATH)) as PackedScene
	var player := player_scene.instantiate()
	player.name = "Player"
	logic_globals.add_child(player)

	var rig_scene := options.get("player_rig_scene", load(PLAYER_RIG_SCENE_PATH)) as PackedScene
	player_rig = rig_scene.instantiate() as Node3D
	player_rig.name = "PlayerRig"
	player_rig.add_to_group(&"player_view_rig")
	view_globals_root.add_child(player_rig)

	# Same builder as a self-contained MapView3D, so hosted lighting cannot drift.
	var lighting := MapView3D.create_global_lighting()
	sun = lighting["sun"] as DirectionalLight3D
	view_globals_root.add_child(sun)
	environment = lighting["environment"] as Environment
	world_environment = lighting["world_environment"] as WorldEnvironment
	view_globals_root.add_child(world_environment)
	var camera := Camera3D.new()
	camera.name = "GameplayCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(
		MapView3D.CAMERA_PITCH_DEGREES, MapView3D.CAMERA_YAW_DEGREES, 0.0
	)
	camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
	camera.far = MapView3D.CAMERA_FAR
	camera.current = true
	view_globals_root.add_child(camera)
	sky_weather = SkyWeather3D.new()
	sky_weather.name = "SkyWeather"
	view_globals_root.add_child(sky_weather)
	sky_weather.configure(camera, environment)

	hud_layer = CanvasLayer.new()
	hud_layer.name = HUD_NAME
	_globals_root.add_child(hud_layer)
	minimap_hud = (load(MINIMAP_HUD_SCENE_PATH) as PackedScene).instantiate() as MinimapHud
	hud_layer.add_child(minimap_hud)

	stable_state_store = MapStableStateStore.new()
	_owns_globals = configure(layout, player, camera, session)
	if not _owns_globals:
		_release_globals()
	return _owns_globals


func owns_globals() -> bool:
	return _owns_globals


## The keys MapView3D.create_hosted() binds instead of creating its own nodes.
func view_globals() -> Dictionary:
	if not _owns_globals:
		return {}
	return {
		"sun": sun,
		"environment": environment,
		"world_environment": world_environment,
		"camera": camera_owner,
		"sky_weather": sky_weather,
	}


## The single authoritative 2D navigation map. Every mounted location region is
## attached here, so one query can route across a seam. Created lazily so a
## phase 2 host that never mounts navigation allocates nothing.
func navigation_map() -> RID:
	if not _navigation_map.is_valid():
		_navigation_map = NavigationServer2D.map_create()
		NavigationServer2D.map_set_cell_size(
			_navigation_map,
			float(ProjectSettings.get_setting("navigation/2d/default_cell_size", 1.0))
		)
		NavigationServer2D.map_set_edge_connection_margin(
			_navigation_map,
			float(ProjectSettings.get_setting("navigation/2d/default_edge_connection_margin", 1.0))
		)
		NavigationServer2D.map_set_active(_navigation_map, true)
	return _navigation_map


## Build both disposable packages for a location from its compiled definition and
## mount them. The logic package holds collision, navigation and gameplay nodes;
## the view package is a hosted MapView3D bound to the host's globals.
func enter_location(
	location_id: StringName,
	definition: MapDefinition,
	grid: MapTerrainGrid = null,
	initial_time: StringName = MapView3D.TIME_DAY
) -> bool:
	if not _owns_globals or definition == null:
		return false
	var built_grid := grid if grid != null else MapBuilder.build(definition)
	var logic_package := MapSceneBootstrap.assemble_location_package(definition, built_grid)
	var view_package := MapView3D.create_hosted(definition, built_grid, view_globals(), initial_time)
	view_package.apply_cycle_progress(clock_progress)
	if mount_location(location_id, logic_package, view_package):
		# WB-06b: hosted_bootstrap() hands scene scripts the same definition and
		# grid the packages were built from (never rebuilt, never persisted).
		_mounted_locations[location_id]["definition"] = definition
		_mounted_locations[location_id]["grid"] = built_grid
		return true
	logic_package.free()
	view_package.free()
	return false


## WB-06b: true when `scenes/` entry points must launch through a host. Read
## per call (not cached) so the flag-off path never allocates a host.
static func launch_enabled() -> bool:
	return bool(ProjectSettings.get_setting(ADDITIVE_RESIDENCY_SETTING, false))


## WB-06b launch adapter: the host owns Player, camera and HUD; the scene is a
## thin entry. Retires the baked `scene_player`. Returns null on failure so the
## caller can run today's path. `scene_root` is the tree DoorNavigator walks.
static func launch_scene_location(
	scene_root: Node, definition: MapDefinition, scene_player: Node = null, options: Dictionary = {}
) -> WorldHost:
	if scene_root == null or definition == null or String(definition.map_id).is_empty():
		return null
	var host := WorldHost.new()
	host.name = HOST_NODE_NAME
	host.set_additive_residency_enabled(true)
	scene_root.add_child(host)
	var location_id := definition.map_id
	var grid := MapBuilder.build(definition)
	var layout: Dictionary = options.get("layout", {}) as Dictionary
	if not bool(layout.get("valid", false)):
		layout = launch_layout(definition)
	if not (
		host.create_globals(layout, options)
		and host._seed_clock_from_music_director()
		and host.enter_location(location_id, definition, grid)
	):
		push_warning("WorldHost launch failed for %s; using the scene-owned path" % location_id)
		scene_root.remove_child(host)
		host.free()
		return null
	host.set_owning_location(location_id)
	WorldHostStreamingDriver.attach(host)  # WB-08b: no-op for a solo (interior) layout.
	if host.minimap_hud != null:
		host.minimap_hud.configure(definition, grid, host.player_owner as Node2D)
	if scene_player != null and scene_player != host.player_owner:
		# The .tscn still bakes a Player for the flag-off path. Under a host it
		# would be a second player, so it leaves the tree before anything binds it.
		if scene_player.get_parent() != null:
			scene_player.get_parent().remove_child(scene_player)
		scene_player.queue_free()
	# WB-06d: keep Actors under the scene; offset it onto the package origin.
	var scene_actors := scene_root.get_node_or_null("Actors") as Node2D
	if scene_actors != null:
		scene_actors.position = host.location_origin_logic_position(location_id)
	return host


## The layout a launch adapter enters: the checked-in reval_outdoor manifest when
## it lists this location, otherwise a one-location group (interiors such as the
## forge are not streamed, but still get host-owned globals).
static func launch_layout(definition: MapDefinition) -> Dictionary:
	var manifest_layout := MapWorldLayout.layout_from_manifest(MapWorldLayout.load_manifest())
	if bool(manifest_layout.get("valid", false)):
		for entry_value in manifest_layout.get("locations", []):
			if StringName((entry_value as Dictionary).get("location_id", "")) == definition.map_id:
				return manifest_layout
	var definitions: Array[MapDefinition] = [definition]
	return MapWorldLayout.build(
		definitions, definition.map_id, StringName("%s_solo" % String(definition.map_id))
	)


## The bootstrap dictionary scene scripts already read (`definition`, `grid`,
## `navigation`, `doors`, `anchors`, `fades`, `minimap_hud`), built from the
## mounted logic package so flag-on and flag-off scene code share one shape.
## `world_host` marks it hosted; `assembled` is absent because a hosted location
## draws no flat 2D map.
func hosted_bootstrap(location_id: StringName) -> Dictionary:
	var mounted: Dictionary = _mounted_locations.get(location_id, {}) as Dictionary
	var logic_root := mounted.get("logic_root") as Node
	if logic_root == null:
		return {}
	var navigation: NavigationRegion2D = null
	var doors: Array[Area2D] = []
	var anchors: Array[Marker2D] = []
	var fades: Array[Area2D] = []
	for node in logic_root.find_children("*", "", true, false):
		# Classified by the package's own stable handles, not by class: naming the
		# Door script here would compile door.gd (and its DoorNavigator autoload
		# reference) whenever WorldHost is parsed.
		var object_id := String((node.get_meta(&"stable_handle", {}) as Dictionary).get("object_id", ""))
		if node is NavigationRegion2D and navigation == null:
			navigation = node as NavigationRegion2D
		elif node is Area2D and object_id.begins_with("transition:"):
			doors.append(node as Area2D)
		elif node is Marker2D and object_id.begins_with("anchor:"):
			anchors.append(node as Marker2D)
		elif node is Area2D and node.get_parent().name == &"FadeVolumes":
			fades.append(node as Area2D)
	return {
		"world_host": self,
		"location_id": location_id,
		"definition": mounted.get("definition"),
		"grid": mounted.get("grid"),
		"navigation": navigation,
		"doors": doors,
		"anchors": anchors,
		"fades": fades,
		"location_hud": minimap_hud,
		"minimap_hud": minimap_hud,
	}


## The hosted MapView3D mounted for `location_id`, or null.
func hosted_view(location_id: StringName) -> MapView3D:
	var view_root := mounted_location_root(location_id, true)
	if view_root == null:
		return null
	for child in view_root.get_children():
		if child is MapView3D:
			return child as MapView3D
	return null


## Only launch_scene_location() calls this, once, before the first mount, so a
## hosted scene continues the day/date the previous (possibly flag-off) scene
## left in MusicDirector. After that the host clock is the authority and runtimes
## only mirror it back for music.
func _seed_clock_from_music_director() -> bool:
	if music_director == null:
		return true
	if (
		music_director.has_method(&"is_cycle_active")
		and not bool(music_director.call(&"is_cycle_active"))
	):
		return true
	if music_director.has_method(&"get_cycle_progress"):
		clock_progress = wrapf(float(music_director.call(&"get_cycle_progress")), 0.0, 1.0)
	if music_director.has_method(&"get_cycle_elapsed_days"):
		clock_completed_days = int(music_director.call(&"get_cycle_elapsed_days"))
	return true


## Diagnostics for every node in `package` that a location may not create. A
## location package is disposable; the listed kinds are host globals (ADR 0019 s.2).
func validate_location_package(location_id: StringName, package: Node) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if package != null:
		_collect_global_violations(location_id, package, package, diagnostics)
	return diagnostics


func last_rejection() -> Array[Dictionary]:
	return _last_rejection.duplicate(true)


## Counts of global kinds anywhere under the host. Phase 3 requires exactly one of
## each no matter how many locations are mounted.
func global_census() -> Dictionary:
	var census := {
		"player": 0,
		"player_rig": 0,
		"camera": 0,
		"world_environment": 0,
		"sun": 0,
		"sky_weather": 0,
		"hud": 0,
	}
	_count_globals(self, census)
	return census


## Advance the host clock and push it to every mounted hosted view. Views never
## run their own clock under a host, so two mounted locations cannot disagree.
func advance_clock(delta_seconds: float) -> void:
	var clock := DayNightCycle.advance_clock(clock_progress, delta_seconds)
	clock_completed_days += int(clock["completed_days"])
	set_clock_progress(float(clock["progress"]))


func set_clock_progress(progress: float) -> void:
	clock_progress = wrapf(progress, 0.0, 1.0)
	for location_id in mounted_location_ids():
		var view := mounted_location_root(location_id, true)
		if view == null:
			continue
		for child in view.get_children():
			if child is MapView3D:
				(child as MapView3D).apply_cycle_progress(clock_progress)


func is_configured() -> bool:
	return _configured


func is_additive_residency_active() -> bool:
	return _configured and additive_residency_enabled


func set_additive_residency_enabled(enabled: bool) -> void:
	additive_residency_enabled = enabled


func is_scene_swap_fallback_enabled() -> bool:
	# WB-08: failed seam mounts emit scene_swap_fallback_requested. Off by default.
	return scene_swap_fallback_enabled


func mounted_location_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for location_id_value in _mounted_locations.keys():
		ids.append(StringName(location_id_value))
	# StringName sorts by interned pointer, not text; compare as String so the
	# order is deterministic.
	ids.sort_custom(
		func(left: StringName, right: StringName) -> bool: return String(left) < String(right)
	)
	return ids


func mounted_location_root(location_id: StringName, view_layer: bool = true) -> Node:
	var mounted: Dictionary = _mounted_locations.get(location_id, {}) as Dictionary
	return mounted.get("view_root" if view_layer else "logic_root") as Node


func location_entry(location_id: StringName) -> Dictionary:
	return (_locations_by_id.get(location_id, {}) as Dictionary).duplicate(true)


func location_origin_world_position(location_id: StringName) -> Vector3:
	var entry := location_entry(location_id)
	if entry.is_empty():
		return Vector3.ZERO
	var origin := Vector2i(entry.get("origin_cell", Vector2i.ZERO))
	# MapViewBridge uses one world unit per authored cell. The package root is
	# therefore offset in global cells, not in authored pixel coordinates.
	return Vector3(float(origin.x), 0.0, float(origin.y))


func location_origin_logic_position(location_id: StringName) -> Vector2:
	var entry := location_entry(location_id)
	if entry.is_empty():
		return Vector2.ZERO
	var origin := Vector2i(entry.get("origin_cell", Vector2i.ZERO))
	var cell_size := int(entry.get("cell_size", 0))
	return Vector2(origin) * float(cell_size)


func global_logic_position(location_id: StringName, local_position: Vector2) -> Vector2:
	return location_origin_logic_position(location_id) + local_position


## Mount a disposable package under both location layers. Packages may be null for
## a data-only proof, but any stable handle present in a package must be unique in
## the entire mounted host.
func mount_location(
	location_id: StringName, logic_package: Node = null, view_package: Node = null
) -> bool:
	_last_rejection.clear()
	if not is_additive_residency_active():
		return _reject(location_id, DIAG_RESIDENCY_INACTIVE, "", "additive residency is off")
	if not _locations_by_id.has(location_id):
		return _reject(location_id, DIAG_UNKNOWN_LOCATION, "", "not in the world layout")
	if _mounted_locations.has(location_id):
		return _reject(location_id, DIAG_ALREADY_MOUNTED, "", "")
	var violations := validate_location_package(location_id, logic_package)
	violations.append_array(validate_location_package(location_id, view_package))
	if not violations.is_empty():
		# WB-06: a package that creates a global is a hard error, never a silent
		# second camera or player.
		_last_rejection = violations
		package_rejected.emit(location_id, violations.duplicate(true))
		return false
	if not _packages_have_unique_handles(location_id, logic_package, view_package):
		package_rejected.emit(location_id, _last_rejection.duplicate(true))
		return false

	_ensure_mount_roots()
	var entry := location_entry(location_id)
	var logic_root := Node2D.new()
	logic_root.name = String(location_id)
	logic_root.position = location_origin_logic_position(location_id)
	# The two package layers share a location ID while retaining their own
	# coordinate systems: logic uses authored pixels, view uses global cells.
	_logic_locations.add_child(logic_root)
	if logic_package != null:
		logic_root.add_child(logic_package)
		_attach_navigation_regions(logic_package)

	var view_root := Node3D.new()
	view_root.name = String(location_id)
	view_root.position = location_origin_world_position(location_id)
	_view_locations.add_child(view_root)
	if view_package != null:
		view_root.add_child(view_package)

	_mounted_locations[location_id] = {
		"location_id": location_id,
		"origin_cell": Vector2i(entry.get("origin_cell", Vector2i.ZERO)),
		"logic_root": logic_root,
		"view_root": view_root,
	}
	_register_package_handles(location_id, logic_package)
	_register_package_handles(location_id, view_package)
	location_mounted.emit(location_id)
	_refresh_seam_activation()
	return true


func unmount_location(location_id: StringName) -> bool:
	if not _mounted_locations.has(location_id):
		return false
	var mounted: Dictionary = _mounted_locations[location_id] as Dictionary
	var logic_root := mounted.get("logic_root") as Node
	var view_root := mounted.get("view_root") as Node
	# Detach before freeing: leaving the tree removes navigation regions from the
	# host map and stops physics immediately, not at the end of the frame.
	for root in [logic_root, view_root]:
		var node := root as Node
		if node == null:
			continue
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()
	_mounted_locations.erase(location_id)
	_rebuild_stable_handle_registry()
	location_unmounted.emit(location_id)
	_refresh_seam_activation()
	return true


func unmount_all() -> void:
	for location_id in mounted_location_ids():
		unmount_location(location_id)


func active_seams() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for seam_value in world_layout.get("seams", []):
		var seam: Dictionary = seam_value as Dictionary
		if _seam_is_active(seam):
			result.append(seam.duplicate(true))
	result.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return String(left.get("id", "")) < String(right.get("id", ""))
	)
	return result


func is_seam_active(seam_id: String) -> bool:
	for seam_value in world_layout.get("seams", []):
		var seam: Dictionary = seam_value as Dictionary
		if String(seam.get("id", "")) == seam_id:
			return _seam_is_active(seam)
	return false


func is_seam_active_between(first_id: StringName, second_id: StringName) -> bool:
	var seam := seam_between(first_id, second_id)
	return not seam.is_empty() and _seam_is_active(seam)


func duplicate_stable_handles() -> Array[Dictionary]:
	return _duplicate_stable_handles.duplicate(true)


func stable_handle_owner(handle: Dictionary) -> Node:
	var found := _stable_handle_owners.get(_handle_key(handle)) as Node
	return found if found != null else _stable_handle_owners.get(_world_key(handle)) as Node


func stable_handle_count() -> int:
	return _stable_handle_owners.size()


## Observe the canonical logic position without writing to the player. This lets a
## seam probe cross the boundary while the one player owner retains its identity.
func observe_global_logic_position(global_position: Vector2) -> StringName:
	_last_global_logic_position = global_position
	var cell_size := _layout_cell_size()
	if cell_size <= 0:
		_last_location_id = &""
		return _last_location_id
	var global_cell := Vector2i(
		floori(global_position.x / float(cell_size)), floori(global_position.y / float(cell_size))
	)
	_last_location_id = MapWorldLayout.location_at_global_cell(world_layout, global_cell)
	return _last_location_id


func observed_global_logic_position() -> Vector2:
	return _last_global_logic_position


func observed_location_id() -> StringName:
	return _last_location_id


func owner_snapshot() -> Dictionary:
	return {
		"player": player_owner,
		"camera": camera_owner,
		"session": session_owner,
	}


## WB-08 pure residency policy. Returns {owner, desired, mount, evict, distances}
## where distances maps each seam neighbour of `owner_id` to the player's distance
## (cells) from the shared seam edge. Only layout seams (streamable by
## construction) are considered, so a travel or interior transition never streams.
static func plan_residency(
	layout: Dictionary,
	owner_id: StringName,
	global_position: Vector2,
	resident_ids: Array,
	prefetch_cells: float,
	eviction_cells: float,
	cap: int
) -> Dictionary:
	var distances := seam_neighbor_distances(layout, owner_id, global_position)
	var candidates: Array[StringName] = []
	for neighbor_value in distances.keys():
		var neighbor_id := StringName(neighbor_value)
		var distance := float(distances[neighbor_id])
		# Hysteresis: an already resident neighbour survives until the wider band.
		var band := eviction_cells if resident_ids.has(neighbor_id) else prefetch_cells
		if distance <= band:
			candidates.append(neighbor_id)
	candidates.sort_custom(
		func(left: StringName, right: StringName) -> bool:
			var left_distance := float(distances[left])
			var right_distance := float(distances[right])
			if not is_equal_approx(left_distance, right_distance):
				return left_distance < right_distance
			return String(left) < String(right)
	)
	var desired: Array[StringName] = []
	if not owner_id.is_empty():
		desired.append(owner_id)
	for neighbor_id in candidates:
		if desired.size() >= maxi(cap, 1):
			break
		desired.append(neighbor_id)
	var mount: Array[StringName] = []
	for location_id in desired:
		if not resident_ids.has(location_id):
			mount.append(location_id)
	var evict: Array[StringName] = []
	for resident_value in resident_ids:
		var resident_id := StringName(resident_value)
		if not desired.has(resident_id):
			evict.append(resident_id)
	evict.sort_custom(
		func(left: StringName, right: StringName) -> bool: return String(left) < String(right)
	)
	return {
		"owner": owner_id,
		"desired": desired,
		"mount": mount,
		"evict": evict,
		"distances": distances,
	}


## Distance in cells from `global_position` to each seam edge `owner_id` shares
## with a neighbour (the closest edge when two locations share several seams).
static func seam_neighbor_distances(
	layout: Dictionary, owner_id: StringName, global_position: Vector2
) -> Dictionary:
	var bounds_by_id: Dictionary = {}
	var cell_size := 0
	for entry_value in layout.get("locations", []):
		var entry: Dictionary = entry_value as Dictionary
		bounds_by_id[StringName(entry.get("location_id", ""))] = entry.get("global_bounds", Rect2())
		cell_size = int(entry.get("cell_size", cell_size))
	var distances: Dictionary = {}
	if cell_size <= 0 or not bounds_by_id.has(owner_id):
		return distances
	for seam_value in layout.get("seams", []):
		var seam: Dictionary = seam_value as Dictionary
		var neighbor_id: StringName = &""
		if seam.get("base_map_id", &"") == owner_id:
			neighbor_id = StringName(seam.get("neighbor_map_id", &""))
		elif seam.get("neighbor_map_id", &"") == owner_id:
			neighbor_id = StringName(seam.get("base_map_id", &""))
		if neighbor_id.is_empty() or not bounds_by_id.has(neighbor_id):
			continue
		# The two rects touch along the seam; growing both by a pixel turns that
		# shared edge into a thin rect, whatever the side.
		var edge := (bounds_by_id[owner_id] as Rect2).grow(1.0).intersection(
			(bounds_by_id[neighbor_id] as Rect2).grow(1.0)
		)
		if edge.size == Vector2.ZERO:
			continue
		var closest := global_position.clamp(edge.position, edge.end)
		var distance := global_position.distance_to(closest) / float(cell_size)
		if not distances.has(neighbor_id) or distance < float(distances[neighbor_id]):
			distances[neighbor_id] = distance
	return distances


## WB-08 streaming tick. Call with the player's global logic position (the host
## never writes the player). Crossing a seam changes only the owning location;
## prefetch mounts neighbours inside the band and eviction honours hysteresis and
## the residency cap. Returns the applied plan plus `mounted`, `evicted`,
## `failed` and `fallback` (the seam handed to the scene-swap path, or {}).
func update_streaming(global_position: Vector2) -> Dictionary:
	var applied := {
		"owner": _owning_location_id,
		"mounted": [] as Array[StringName],
		"evicted": [] as Array[StringName],
		"failed": [] as Array[StringName],
		"fallback": {},
	}
	if not is_additive_residency_active():
		return applied
	var observed := observe_global_logic_position(global_position)
	if observed.is_empty():
		# Off every location (outside the city edge): keep the last owner.
		observed = _owning_location_id
	if observed != _owning_location_id and not observed.is_empty():
		if not _owning_location_id.is_empty() and seam_between(_owning_location_id, observed).is_empty():
			# Blocked seam or no seam: that edge keeps its explicit transition.
			applied["fallback"] = request_scene_swap_fallback(observed)
			return applied
		if not _mounted_locations.has(observed) and not _load_location(observed):
			applied["failed"].append(observed)
			applied["fallback"] = request_scene_swap_fallback(observed)
			return applied
		var previous := _owning_location_id
		_owning_location_id = observed
		_fallback_request = {}
		if not previous.is_empty():
			owning_location_changed.emit(previous, observed)
	applied["owner"] = _owning_location_id
	if observed == _owning_location_id:
		_fallback_request = {}

	var plan := plan_residency(
		world_layout,
		_owning_location_id,
		global_position,
		mounted_location_ids(),
		prefetch_band_cells,
		eviction_band_cells,
		residency_cap
	)
	# Evict first so a full cap has room for the new neighbour.
	for location_id in plan["evict"]:
		if not pinned_location_ids.has(location_id) and unmount_location(location_id):
			applied["evicted"].append(location_id)
	for location_id in plan["mount"]:
		if _load_location(location_id):
			applied["mounted"].append(location_id)
		else:
			applied["failed"].append(location_id)
	applied.merge(plan)
	return applied


func owning_location_id() -> StringName:
	return _owning_location_id


## Seed the owner (for example the location the launch adapter entered through).
func set_owning_location(location_id: StringName) -> void:
	_owning_location_id = location_id


func mount_failure_count(location_id: StringName) -> int:
	return int(_mount_failures.get(location_id, 0))


## The streamable seam between two locations, or {} (blocked seams are absent
## from a manifest layout, so they always use the explicit transition).
func seam_between(first_id: StringName, second_id: StringName) -> Dictionary:
	for seam_value in world_layout.get("seams", []):
		var seam: Dictionary = seam_value as Dictionary
		if (
			(seam.get("base_map_id", &"") == first_id and seam.get("neighbor_map_id", &"") == second_id)
			or (
				seam.get("base_map_id", &"") == second_id
				and seam.get("neighbor_map_id", &"") == first_id
			)
		):
			return seam.duplicate(true)
	return {}


## True when `transition_id` in `location_id` is a streamed seam, so a launch
## adapter must not run its scene swap while both sides can be resident.
func is_transition_streamed(location_id: StringName, transition_id: StringName) -> bool:
	for seam_value in world_layout.get("seams", []):
		var seam: Dictionary = seam_value as Dictionary
		if (
			seam.get("base_map_id", &"") == location_id
			and StringName(seam.get("base_transition_id", &"")) == transition_id
		):
			return true
		if (
			seam.get("neighbor_map_id", &"") == location_id
			and StringName(seam.get("neighbor_transition_id", &"")) == transition_id
		):
			return true
	return false


func _load_location(location_id: StringName) -> bool:
	if _mounted_locations.has(location_id):
		return true
	var ok := false
	if location_loader.is_valid():
		ok = bool(location_loader.call(location_id))
	elif definition_provider.is_valid():
		var definition := definition_provider.call(location_id) as MapDefinition
		ok = definition != null and enter_location(location_id, definition)
	ok = ok and _mounted_locations.has(location_id)
	if not ok:
		_mount_failures[location_id] = mount_failure_count(location_id) + 1
	return ok


## Public so a launch adapter can hand over an unresident seam the player touches.
func request_scene_swap_fallback(location_id: StringName) -> Dictionary:
	if String(_fallback_request.get("location_id", "")) == String(location_id):
		# One request per edge visit; the adapter is already swapping scenes.
		return _fallback_request.duplicate(true)
	if not scene_swap_fallback_enabled:
		# No degrade path: the player stays owned by the current location, which
		# is never evicted, so they are not dropped into unloaded space.
		return {}
	var seam := seam_between(_owning_location_id, location_id)
	if seam.is_empty():
		for blocked_value in world_layout.get("blocked_seams", []):
			var blocked: Dictionary = blocked_value as Dictionary
			var ends := [blocked.get("base_map_id", &""), blocked.get("neighbor_map_id", &"")]
			if ends.has(_owning_location_id) and ends.has(location_id):
				seam = blocked.duplicate(true)
				break
	var request := {
		"from_location_id": _owning_location_id,
		"location_id": location_id,
		"seam_id": String(seam.get("id", "")),
		"transition_id": _transition_toward(seam, location_id),
	}
	_fallback_request = request.duplicate(true)
	scene_swap_fallback_requested.emit(location_id, request.duplicate(true))
	return request


func _transition_toward(seam: Dictionary, location_id: StringName) -> StringName:
	if seam.is_empty():
		return &""
	if seam.get("neighbor_map_id", &"") == location_id:
		return StringName(seam.get("base_transition_id", &""))
	return StringName(seam.get("neighbor_transition_id", &""))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _navigation_map.is_valid():
		NavigationServer2D.free_rid(_navigation_map)
		_navigation_map = RID()


func _scene_root() -> Node:
	if is_inside_tree():
		return get_tree().root
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


func _release_globals() -> void:
	if _globals_root != null:
		_globals_root.free()
	_globals_root = null
	player_rig = null
	sun = null
	environment = null
	world_environment = null
	sky_weather = null
	hud_layer = null
	minimap_hud = null
	stable_state_store = null


func _reject(location_id: StringName, code: String, node_path: String, detail: String) -> bool:
	var diagnostic := _diagnostic(code, location_id, node_path, detail)
	_last_rejection = [diagnostic]
	package_rejected.emit(location_id, [diagnostic.duplicate(true)])
	return false


static func _diagnostic(
	code: String, location_id: StringName, node_path: String, detail: String
) -> Dictionary:
	return {
		"code": code,
		"location_id": String(location_id),
		"node_path": node_path,
		"detail": detail,
	}


## The global kind a node represents, or "" for ordinary location content. The
## rig group is checked because a rig scene's root class is not unique to players.
static func _global_kind(node: Node) -> String:
	if node is Player:
		return "player"
	if node.is_in_group(&"player_view_rig"):
		return "player_rig"
	if node is Camera3D:
		return "camera"
	if node is WorldEnvironment:
		return "world_environment"
	if node is DirectionalLight3D:
		return "sun"
	if node is SkyWeather3D:
		return "sky_weather"
	if node is CanvasLayer:
		return "hud"
	if node is MapViewRuntime:
		return "runtime"
	return ""


func _collect_global_violations(
	location_id: StringName, package: Node, node: Node, diagnostics: Array[Dictionary]
) -> void:
	var kind := _global_kind(node)
	if not kind.is_empty():
		diagnostics.append(
			_diagnostic(
				DIAG_PACKAGE_CREATES_GLOBAL,
				location_id,
				String(package.get_path_to(node)) if node != package else ".",
				kind
			)
		)
		# The whole subtree belongs to that global; one diagnostic is enough.
		return
	for child in node.get_children():
		_collect_global_violations(location_id, package, child, diagnostics)


func _count_globals(node: Node, census: Dictionary) -> void:
	var kind := _global_kind(node)
	if census.has(kind):
		census[kind] = int(census[kind]) + 1
		# A rig or HUD may nest cameras or layers of its own; count the owner only.
		return
	for child in node.get_children():
		_count_globals(child, census)


func _ensure_mount_roots() -> void:
	if _logic_locations == null:
		_logic_locations = Node.new()
		_logic_locations.name = LOGIC_LOCATIONS_NAME
		add_child(_logic_locations)
	if _view_locations == null:
		_view_locations = Node3D.new()
		_view_locations.name = VIEW_LOCATIONS_NAME
		add_child(_view_locations)


func _layout_cell_size() -> int:
	for entry_value in world_layout.get("locations", []):
		var entry: Dictionary = entry_value as Dictionary
		return int(entry.get("cell_size", 0))
	return 0


func _seam_is_active(seam: Dictionary) -> bool:
	return (
		_mounted_locations.has(seam.get("base_map_id", &""))
		and _mounted_locations.has(seam.get("neighbor_map_id", &""))
	)


func _refresh_seam_activation() -> void:
	for seam_value in world_layout.get("seams", []):
		var seam: Dictionary = seam_value as Dictionary
		var seam_id := String(seam.get("id", ""))
		var active := _seam_is_active(seam)
		if not seam_id.is_empty():
			seam_activation_changed.emit(seam_id, active)
	_rebuild_seam_links()


func _attach_navigation_regions(node: Node) -> void:
	if node is NavigationRegion2D:
		(node as NavigationRegion2D).set_navigation_map(navigation_map())
	for child in node.get_children():
		_attach_navigation_regions(child)


## Shared by phase-2 configure() and phase-3 create_globals() because both
## mount through mount_location() -> _refresh_seam_activation().
func _rebuild_seam_links() -> void:
	if _seam_links == null:
		_seam_links = Node2D.new()
		_seam_links.name = SEAM_LINKS_NAME
		add_child(_seam_links)
	for child in _seam_links.get_children():
		_seam_links.remove_child(child)
		child.free()
	var map_rid := navigation_map()
	for seam in active_seams():
		var points := MapWorldLayout.seam_navigation_link_points(
			world_layout, seam, MapNavBuilder.AGENT_RADIUS, _seam_aperture_center(seam)
		)
		if points.size() < 2:
			continue
		var seam_id := String(seam.get("id", "seam"))
		MapNavBuilder.install_seam_link(
			_seam_links,
			map_rid,
			points[0],
			points[1],
			"link_%s" % seam_id.replace("/", "_").replace("|", "_")
		)


## WB-08b: centre of the seam's base transition door along the edge, so the
## link sits in the street aperture, not mid-edge. NAN without a logic package.
func _seam_aperture_center(seam: Dictionary) -> float:
	var root := mounted_location_root(StringName(seam.get("base_map_id", &"")), false)
	var object_id := "transition:%s" % String(seam.get("base_transition_id", ""))
	for node in root.find_children("*", "Area2D", true, false) if root != null else []:
		var handle: Dictionary = node.get_meta(&"stable_handle", {}) as Dictionary
		if String(handle.get("object_id", "")) == object_id:
			var center := (node as Node2D).global_position
			var east_west := [&"east", &"west"].has(StringName(seam.get("base_side", &"")))
			return center.y if east_west else center.x
	return NAN


func _packages_have_unique_handles(
	location_id: StringName, logic_package: Node, view_package: Node
) -> bool:
	var candidate_keys: Dictionary = {}
	for package in [logic_package, view_package]:
		if package == null:
			continue
		for entry in _stable_handles_in(package as Node, location_id):
			var handle: Dictionary = entry["handle"]
			var key := String(entry["key"])
			if String(handle.get("object_id", "")).is_empty():
				_last_rejection = [_diagnostic(DIAG_MISSING_OBJECT_ID, location_id, "", key)]
				return false
			if candidate_keys.has(key) or _stable_handle_owners.has(key):
				_duplicate_stable_handles.append(handle.duplicate(true))
				_last_rejection = [_diagnostic(DIAG_DUPLICATE_STABLE_HANDLE, location_id, "", key)]
				return false
			candidate_keys[key] = true
	return true


func _register_package_handles(location_id: StringName, package: Node) -> void:
	if package == null:
		return
	for entry in _stable_handles_in(package, location_id):
		_stable_handle_owners[String(entry["key"])] = entry["node"]


func _rebuild_stable_handle_registry() -> void:
	_stable_handle_owners.clear()
	_duplicate_stable_handles.clear()
	for location_id in mounted_location_ids():
		var mounted: Dictionary = _mounted_locations[location_id] as Dictionary
		_register_package_handles(location_id, mounted.get("logic_root") as Node)
		_register_package_handles(location_id, mounted.get("view_root") as Node)


## Entries {handle, key, node}. A `stable_handle` dictionary is location-scoped
## ({location_id, object_id}, the MapStableStateStore identity). A bare
## `stable_id` is a world-unique content id (for example `char.aita`), so it
## must exist at most once across every mounted location (ADR 0019 gate).
func _stable_handles_in(package: Node, location_id: StringName) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	_collect_stable_handles(package, location_id, entries)
	return entries


func _collect_stable_handles(
	node: Node, location_id: StringName, entries: Array[Dictionary]
) -> void:
	if node.has_meta(&"stable_handle"):
		var raw_handle: Variant = node.get_meta(&"stable_handle")
		if raw_handle is Dictionary:
			var handle := _normalize_handle(raw_handle as Dictionary, location_id)
			entries.append({"handle": handle, "key": _handle_key(handle), "node": node})
	elif node.has_meta(&"stable_id"):
		var handle := _normalize_handle({"object_id": node.get_meta(&"stable_id")}, location_id)
		entries.append({"handle": handle, "key": _world_key(handle), "node": node})
	for child in node.get_children():
		_collect_stable_handles(child, location_id, entries)


func _normalize_handle(raw_handle: Dictionary, location_id: StringName) -> Dictionary:
	return {
		"location_id": String(raw_handle.get("location_id", location_id)),
		"object_id": String(raw_handle.get("object_id", "")),
	}


func _handle_key(handle: Dictionary) -> String:
	return "%s/%s" % [String(handle.get("location_id", "")), String(handle.get("object_id", ""))]


func _world_key(handle: Dictionary) -> String:
	return "*/%s" % String(handle.get("object_id", ""))
