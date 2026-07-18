extends SceneTree
func _initialize():
 var d = preload("res://scripts/map/definitions/lower_town/kalev_smithy_rrmap_factory.gd").create()
 var i = MapChunkRuntimeIndex.build(d, 32)
 print("IDS ", i.object_ids())
 for r in i.records_consumed_by(Vector2i.ZERO):
  if r.kind == &"landmark": print("LANDMARK ", r.id, " ", r.consumer_chunks, " ", r.residency)
 print("DIAG ", i.diagnostics())
 quit()
