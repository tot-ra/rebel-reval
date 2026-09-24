"""Read only CC0 motion/skeleton metadata, never character visual geometry."""
import json,struct
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[3]
raw=(ROOT/'assets/characters/shared/kaykit_barbarian.glb').read_bytes()
n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);binary=raw[28+n:]
for node in doc['nodes']:
    node.pop('mesh',None);node.pop('skin',None)
for key in ('meshes','materials','textures','images','samplers'):doc.pop(key,None)
s=json.dumps(doc).encode();s+=b' '*((-len(s))%4)
new=struct.pack('<4sII',b'glTF',2,28+len(s)+len(binary))+struct.pack('<II',len(s),0x4e4f534a)+s+struct.pack('<II',len(binary),0x004e4942)+binary
p=ROOT/'build/kalev_fresh/motion_only.glb';p.write_bytes(new)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(p),bone_heuristic='BLENDER')
print('OBJECTS',[(o.name,o.type) for o in bpy.data.objects])
# Keep skin declarations in final extraction; needed to identify joint nodes.
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for o in list(bpy.data.objects):
    if o!=rig:bpy.data.objects.remove(o,do_unlink=True)
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:track.mute=True
print('BONES',[(b.name,tuple(round(x,4) for x in b.head_local),tuple(round(x,4) for x in b.tail_local)) for b in rig.data.bones])
print('ACTIONS',[(a.name,tuple(a.frame_range)) for a in bpy.data.actions])
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'build/kalev_fresh/motion.blend'))
