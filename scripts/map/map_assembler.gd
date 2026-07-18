class_name MapAssembler
extends RefCounted

## Wires one immutable definition through chunked terrain and stable-ID object
## residency while keeping the existing render factories and global transforms.


static func assemble(
	parent: Node2D,
	definition: MapDefinition,
	grid: MapTerrainGrid,
	y_sort_parent: Node2D = null,
	visual_target: StringName = MapVisualStyle.TARGET_CLEAN_PAINTED,
	time_of_day: StringName = MapVisualStyle.TIME_DAY
) -> Dictionary:
	assert(MapVisualStyle.is_valid_target(visual_target))
	assert(MapVisualStyle.is_valid_time(time_of_day))

	var terrain := MapTerrainRenderer.new(grid, visual_target, time_of_day)
	terrain.name = "Terrain"
	terrain.update_active_chunks(definition.player_spawn)
	parent.add_child(terrain)

	var entities := y_sort_parent if y_sort_parent != null else parent
	if entities != parent:
		entities.y_sort_enabled = true

	var streamed_root := Node2D.new()
	streamed_root.name = "StreamedMapObjects"
	entities.add_child(streamed_root)
	var buildings_root := Node2D.new()
	buildings_root.name = "Buildings"
	buildings_root.y_sort_enabled = true
	streamed_root.add_child(buildings_root)
	var props_root := Node2D.new()
	props_root.name = "Props"
	props_root.y_sort_enabled = true
	streamed_root.add_child(props_root)

	var index := MapChunkRuntimeIndex.build(definition, grid.chunk_size_cells)
	var streamer := MapObjectChunkStreamer.new()
	streamer.name = "ObjectStreamer"
	streamed_root.add_child(streamer)
	var factory := func(record: Dictionary) -> Node:
		var source := record["source"] as Dictionary
		match record["kind"] as StringName:
			&"building":
				return MapBuildingRenderer.create_building(source, visual_target, time_of_day)
			&"prop":
				return MapPropRenderer.create_prop(source, visual_target, time_of_day)
		return null
	streamer.configure(index, factory, {
		&"building": buildings_root,
		&"prop": props_root,
	})
	streamer.update_active_chunks(terrain.loaded_chunk_coordinates())
	terrain.active_chunks_changed.connect(streamer.update_active_chunks)
	var building_nodes: Array[StaticBody2D] = []
	for building in definition.buildings:
		var body := streamer.loaded_instance(building["id"]) as StaticBody2D
		if body != null:
			building_nodes.append(body)
	var prop_nodes: Array[Node2D] = []
	for prop in definition.props:
		var prop_node := streamer.loaded_instance(prop["id"]) as Node2D
		if prop_node != null:
			prop_nodes.append(prop_node)

	return {
		"terrain": terrain,
		"buildings": building_nodes,
		"props": prop_nodes,
		"building_root": buildings_root,
		"prop_root": props_root,
		"object_index": index,
		"object_streamer": streamer,
		"grid": grid,
		"definition": definition,
		"visual_target": visual_target,
		"time_of_day": time_of_day,
	}
