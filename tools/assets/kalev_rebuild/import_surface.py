"""Convert the new repaired PLY into the preserved Blender/glTF rebuild input."""
import argparse,sys
from pathlib import Path
import bpy

parser=argparse.ArgumentParser();parser.add_argument('ply');args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
root=Path(__file__).resolve().parents[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.ply_import(filepath=str(Path(args.ply).resolve()))
mesh=bpy.context.object
assert mesh is not None and mesh.type=='MESH'
for polygon in mesh.data.polygons:polygon.use_smooth=True
bpy.ops.export_scene.gltf(filepath=str(root/'assets/characters/kalev_rebuild/reference/sculpt.glb'),export_format='GLB',use_selection=True,export_animations=False)
