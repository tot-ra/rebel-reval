class_name CityTrailFeed
extends RefCounted

## Feeds the ground trail (CityGroundTrail) with everything that walks, grazes
## or rolls near Kalev, once a frame: residents on foot (CityCitizens), hoofed
## animals (CityFauna) and wheeled vehicles. A vehicle is any node in the group
## WHEELED_GROUP with `world_xz() -> Vector2` and `trail_vehicle_class() ->
## StringName` (a CartTransportModel class). The trail itself ignores whoever is
## outside its window or beyond TRACK_RADIUS, so no distance test is needed here.

const WHEELED_GROUP := &"city_wheeled"


static func feed(
	trail: CityGroundTrail, citizens: CityCitizens, fauna: CityFauna, tree: SceneTree
) -> void:
	if trail == null:
		return
	if citizens != null:
		for actor in citizens.live_actors():
			# Residents shown at home inside a house or out of sight leave nothing.
			if actor.outdoors and not actor.at_home and actor.view_animation() == &"walk":
				trail.track_walker(actor.get_instance_id(), actor.world_xz())
	if fauna != null:
		for animal in fauna.live_animals():
			var species := StringName(animal.get_meta(&"species", &""))
			trail.track_hooves(
				animal.get_instance_id(), Vector2(animal.position.x, animal.position.z), species
			)
	if tree != null:
		for node in tree.get_nodes_in_group(WHEELED_GROUP):
			trail.track_cart(
				node.get_instance_id(), node.world_xz(), node.trail_vehicle_class()
			)
