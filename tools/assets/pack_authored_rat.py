"""Preserve and adapt Nestaeric’s CC BY 4.0 rat source; see mammal_sources.json."""
import sys,json,struct,copy,io
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'));from verify_storybook_models import read_glb,accessor
p=ROOT/'build/animal_redo/candidates/rat.glb';d,raw=read_glb(p);raw=bytearray(raw);seams={}
def append_accessor(vals,typ):
 global raw
 vals=np.array(vals,dtype='<f4');raw.extend(b'\0'*((-len(raw))%4));offset=len(raw);data=vals.tobytes();raw.extend(data);vi=len(d['bufferViews']);d['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(data)})
 ai=len(d['accessors']);a={'bufferView':vi,'componentType':5126,'count':len(vals),'type':typ}
 if typ=='SCALAR':a['min']=[float(vals.min())];a['max']=[float(vals.max())]
 d['accessors'].append(a);return ai
for anim in d['animations']:
 maximum=0
 for s in anim['samplers']:
  ts=accessor(d,raw,s['input']);a=d['accessors'][s['output']];v=np.array(accessor(d,raw,s['output']),dtype=np.float32)
  if a['type']=='VEC4':
   v/=np.maximum(np.linalg.norm(v,axis=1)[:,None],1e-12)
   for i in range(1,len(v)):
    if np.dot(v[i-1],v[i])<0:v[i]*=-1
  seam=float(np.max(np.abs(v[0]-v[-1])));maximum=max(maximum,seam)
  assert seam<.0002,(anim['name'],seam)
  v[-1]=v[0]
  if np.max(np.abs(v-v[0]))<1e-6:
   s['input']=append_accessor([ts[0],ts[-1]],'SCALAR');v=v[[0,-1]]
  s['output']=append_accessor(v,a['type'])
 seams[anim['name']]=maximum
 anim.setdefault('extras',{})['loop']=True
# Compact only referenced accessors, then only referenced views; preserve all geometry/UV/weights.
used=set()
for m in d['meshes']:
 for prim in m['primitives']:
  used.update(prim['attributes'].values());used.add(prim['indices'])
for skin in d['skins']:used.add(skin['inverseBindMatrices'])
for a in d['animations']:
 for s in a['samplers']:used.update([s['input'],s['output']])
remap={old:new for new,old in enumerate(sorted(used))};d['accessors']=[d['accessors'][i] for i in sorted(used)]
for m in d['meshes']:
 for prim in m['primitives']:
  prim['attributes']={k:remap[v] for k,v in prim['attributes'].items()};prim['indices']=remap[prim['indices']]
for skin in d['skins']:skin['inverseBindMatrices']=remap[skin['inverseBindMatrices']]
for a in d['animations']:
 for s in a['samplers']:s['input']=remap[s['input']];s['output']=remap[s['output']]
views=sorted({a['bufferView'] for a in d['accessors']}|{im['bufferView'] for im in d['images']});vmap={old:new for new,old in enumerate(views)};binary=bytearray();newviews=[]
for index in views:
 view=d['bufferViews'][index].copy();chunk=bytes(raw[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]);im=next((im for im in d['images'] if im['bufferView']==index),None)
 if im:
  image=Image.open(io.BytesIO(chunk));buf=io.BytesIO();image.save(buf,format='PNG',optimize=True,compress_level=9);chunk=buf.getvalue()
 binary.extend(b'\0'*((-len(binary))%4));view['byteOffset']=len(binary);view['byteLength']=len(chunk);binary.extend(chunk);newviews.append(view)
for a in d['accessors']:a['bufferView']=vmap[a['bufferView']]
for im in d['images']:im['bufferView']=vmap[im['bufferView']]
d['bufferViews']=newviews;d['buffers']=[{'byteLength':len(binary)}];d['asset']['extras']={'author':'Nestaeric','license':'CC-BY-4.0','source':'https://sketchfab.com/3d-models/black-rat-free-download-3db3acb4140d4de8bd62a171212bad9c','source_path':'build/animal_redo/sources/rat.glb','adaptations':'Original geometry preserved; unused bones pruned; 1024px textures; scaled 0.42m; six looping aliases. Blender bind-pose import corrected.'}
# Store source-unit speeds on the scaled wrapper; runtime reads glTF extras
# and multiplies its transform exactly once.
source=next(n for n in d['nodes'] if n.get('name')=='Rat_Source')
for k in ('walk_reference_speed','run_reference_speed'):
 source['extras'][k]=source['extras'][k+'_mps']/source['scale'][0]
js=json.dumps(d,separators=(',',':')).encode();js+=b' '*((-len(js))%4);binary+=b'\0'*((-len(binary))%4);p.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(js)+len(binary))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(binary),0x004e4942)+binary)
print(json.dumps({'bytes':p.stat().st_size,'pre_normalization_seams':seams},indent=2));assert p.stat().st_size<10*1024**2
