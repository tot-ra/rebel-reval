class_name MapViewMeshBuilderHouseStyles
extends RefCounted

## Deterministic house wall and roof style selection plus material resolution.

const _Rural := preload("res://scripts/map/view3d/map_view_rural_dwelling_models.gd")


static func house_style(building: Dictionary) -> StringName:
	if _Rural.is_rural_1343(building):
		return MapViewMeshBuilderConfig.HOUSE_STYLE_LOG
	# WHY: Lower Town tiers are semantic defaults, not a global recolor. Preserve
	# authored material keys first so local stone, plank, and roof variation remains
	# visible even when a frontage is classified as a broader R-003 tier.
	match StringName(building.get("wall_material", &"")):
		&"plaster", &"timber":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER
		&"brick":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK
		&"plank":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_PLANK
		&"log":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_LOG
		&"limestone", &"stone":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_STONE
	# R-003 tier fallback for newly authored houses that do not yet carry a
	# material key. Existing legacy houses continue to use the deterministic hash.
	match StringName(building.get("house_tier", &"")):
		&"merchant_stone":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_STONE
		&"merchant_timber":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER
		&"craft_boda":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_LOG
	var roll := absi(String(building["id"]).hash()) % 20
	# 1343 mix: log dominates, plaster/plank common, limestone emerging, brick rare.
	if roll < 9:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_LOG
	if roll < 13:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER
	if roll < 17:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_PLANK
	if roll < 19:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_STONE
	return MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK


static func house_wall_material(building: Dictionary, wall_color: Color, size: Vector3) -> StandardMaterial3D:
	var surface_id: StringName = building.get("id", &"")
	match house_style(building):
		MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER:
			return MapViewMaterials.wall_surface_for_building(
				surface_id,
				&"plaster",
				wall_color.lerp(MapViewMeshBuilderConfig.PLASTER_TONE, 0.55),
				size
			)
		MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK:
			return MapViewMaterials.wall_surface_for_building(
				surface_id,
				&"brick",
				wall_color.lerp(MapViewMeshBuilderConfig.BRICK_TONE, 0.6),
				size
			)
		MapViewMeshBuilderConfig.HOUSE_STYLE_LOG:
			return MapViewMaterials.wall_surface_for_building(
				surface_id,
				&"log",
				wall_color.lerp(MapViewMeshBuilderConfig.LOG_TONE, 0.45),
				size
			)
		MapViewMeshBuilderConfig.HOUSE_STYLE_STONE:
			return MapViewMaterials.wall_surface_for_building(
				surface_id,
				&"limestone",
				wall_color.lerp(MapViewMeshBuilderConfig.LIMESTONE_TONE, 0.5),
				size
			)
		_:
			return MapViewMaterials.wall_surface_for_building(surface_id, &"plank", wall_color, size)


static func roof_style(building: Dictionary) -> StringName:
	if _Rural.is_rural_1343(building):
		# Split-board cover is retained only as an explicit smoke-cottage option;
		# working barns and barn-dwellings use the conservative thatch lane.
		if (
			StringName(building.get("primitive", &"")) == _Rural.SMOKE_COTTAGE_PRIMITIVE
			and StringName(building.get("roof_material", &"")) == &"shingle"
		):
			return MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE
		return MapViewMeshBuilderConfig.ROOF_STYLE_THATCH
	match StringName(building.get("roof_material", &"")):
		&"tile":
			return MapViewMeshBuilderConfig.ROOF_STYLE_TILE
		&"shingle":
			return MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE
		&"thatch", &"straw":
			return MapViewMeshBuilderConfig.ROOF_STYLE_THATCH
	# R-003 roof bias applies only when no authored cover is present. This keeps
	# merchant stone fronts tile-forward while timber and boda houses stay in the
	# historically safer shingle/thatch lane.
	match StringName(building.get("house_tier", &"")):
		&"merchant_stone":
			return MapViewMeshBuilderConfig.ROOF_STYLE_TILE
		&"merchant_timber":
			return MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE
		&"craft_boda":
			if absi(floori(float(String(building["id"]).hash()) / 10.0)) % 3 < 2:
				return MapViewMeshBuilderConfig.ROOF_STYLE_THATCH
			return MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE
	match house_style(building):
		MapViewMeshBuilderConfig.HOUSE_STYLE_STONE, MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK:
			return MapViewMeshBuilderConfig.ROOF_STYLE_TILE
		MapViewMeshBuilderConfig.HOUSE_STYLE_LOG:
			if absi(String(building["id"]).hash() / 10) % 3 < 2:
				return MapViewMeshBuilderConfig.ROOF_STYLE_THATCH
			return MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE
		_:
			return MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE


static func house_roof_material(building: Dictionary) -> StandardMaterial3D:
	var color := Color(building.get("roof_color", MapViewMeshBuilderConfig.DEFAULT_ROOF_COLOR))
	var style := roof_style(building)
	if style == MapViewMeshBuilderConfig.ROOF_STYLE_THATCH:
		# Pull authored dark browns toward weathered reed so fishing-district
		# thatch stays golden-olive instead of reading as rotten wood.
		color = color.lerp(MapViewMeshBuilderConfig.THATCH_TONE, 0.45 if building.has("roof_material") else 0.55)
	var surface_id: StringName = building.get("id", &"")
	return MapViewMaterials.roof_surface_for_building(surface_id, style, color)
