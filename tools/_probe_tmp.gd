extends SceneTree
func _init() -> void:
	var plan := CityPlan.load_default()
	var at := CityTravel.spawn_position(plan, "poi.granary.pikk")
	print("spawn ", at, " bldg ", plan.building_at(at), " site ", plan.site_at(at))
	var i := plan.building_at(Vector2(120,-400))
	print("granary house ", plan.buildings[i]["id"], " door ", plan.buildings[i]["door"])
	for j in plan.buildings_near(at, 6.0):
		print(" near ", plan.buildings[j]["id"], " enterable ", plan.buildings[j].get("enterable"))
	print("street ", CityTravel._street_near(plan, Vector2(120,-400)))
	quit()
