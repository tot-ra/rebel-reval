class_name LocalAtmosphere
extends Node3D

## One node per exterior view that owns the local, weather-driven atmosphere layers:
## LocalFogBanks (patchy ground fog near water), HorizonMirage (heat shimmer) and, since
## R-1482, AerialPerspectivePass (distance haze, blur and shimmer of far surfaces). The
## views create it beside the god-ray pass and call update() each frame with the same
## presentation snapshot every other weather consumer reads.

const LocalFogBanksScript := preload("res://scripts/map/view3d/local_fog_banks.gd")
const HorizonMirageScript := preload("res://scripts/map/view3d/horizon_mirage.gd")
const AerialPassScript := preload("res://scripts/map/view3d/aerial_perspective_pass.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")

var fog_banks: LocalFogBanksScript
var mirage: HorizonMirageScript
var aerial: AerialPassScript


static func should_create(indoor: bool) -> bool:
	return not indoor


## `water_surface`: Callable(view XZ) -> water height or NAN on land. `ground`: optional
## Callable(view XZ) -> terrain height (flat ground when empty).
func configure(camera: Camera3D, water_surface: Callable, ground: Callable = Callable()) -> void:
	name = "LocalAtmosphere"
	fog_banks = LocalFogBanksScript.new()
	add_child(fog_banks)
	fog_banks.configure(camera, water_surface, ground)
	mirage = HorizonMirageScript.new()
	add_child(mirage)
	mirage.configure(camera)
	aerial = AerialPassScript.new()
	add_child(aerial)
	aerial.configure(camera)


func update(delta: float, presentation: SkyWeather.WeatherPresentation, clock: float) -> void:
	if fog_banks == null or presentation == null:
		return
	# Roofed rooms keep the weather outside, like rain and ground mist do.
	var enabled := not presentation.rain_suppressed
	fog_banks.update(delta, presentation, clock, enabled)
	mirage.update(presentation, enabled)
	aerial.update(presentation, enabled)
