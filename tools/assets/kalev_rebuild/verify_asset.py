"""Structural verification of the independent reconstruction and fitted layers."""
import json,struct,math,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'assets/characters/kalev_rebuild'


def glb(path):
    raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0]
    return json.loads(raw[20:20+n]),raw[28+n:]


def values(doc,data,index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];formats={5126:'f',5125:'I',5123:'H',5121:'B'};count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    fmt='<'+formats[a['componentType']]*count;size=struct.calcsize(fmt);stride=v.get('byteStride',size);start=v.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from(fmt,data,start+i*stride) for i in range(a['count'])]


def skeleton(doc):
    return [(doc['nodes'][i]['name'],doc['nodes'][i].get('translation'),doc['nodes'][i].get('rotation')) for i in doc['skins'][0]['joints']]


def longest_edge(doc,data,primitive):
    positions=values(doc,data,primitive['attributes']['POSITION'])
    indices=[row[0] for row in values(doc,data,primitive['indices'])]
    return max(math.dist(positions[indices[start+a]],positions[indices[start+b]]) for start in range(0,len(indices),3) for a,b in ((0,1),(1,2),(2,0)))


def main():
    body,data=glb(OUT/'kalev_fresh.glb');triangles=0;regions=set()
    for mesh in body['meshes']:
        regions.add(mesh.get('name',''))
        for p in mesh['primitives']:
            triangles+=body['accessors'][p['indices']]['count']//3
            assert longest_edge(body,data,p)<.10,('Body binding stretch',mesh['name'],longest_edge(body,data,p))
            for attr in ('POSITION','NORMAL','TEXCOORD_0','WEIGHTS_0'):
                assert attr in p['attributes'],(mesh['name'],attr)
                assert all(math.isfinite(x) for row in values(body,data,p['attributes'][attr]) for x in row)
            for weights in values(body,data,p['attributes']['WEIGHTS_0']):assert abs(sum(weights)-1)<.002
    assert triangles<=60000,triangles
    assert len(regions)==8,regions
    animations=body.get('animations',[]);assert len(animations)==76,len(animations)
    for name in ('Walking_A','Running_B','1H_Melee_Attack_Chop'):
        animation=next(a for a in animations if a['name']==name)
        moving=0
        for sampler in animation['samplers']:
            points=values(body,data,sampler['output'])
            if len(points)>1 and any(max(row[i] for row in points)-min(row[i] for row in points)>.002 for i in range(len(points[0]))):moving+=1
        assert moving>=4,(name,moving)
    garments={}
    for name in ('linen_shirt','wool_tunic','mail_shirt','smith_apron','hose','boots'):
        d,b=glb(OUT/f'{name}.glb');assert skeleton(d)==skeleton(body),name
        count=0
        for mesh in d['meshes']:
            for p in mesh['primitives']:
                assert 'JOINTS_0' in p['attributes'] and 'WEIGHTS_0' in p['attributes']
                count+=d['accessors'][p['indices']]['count']//3
                assert longest_edge(d,b,p)<.16,('Garment binding stretch',name,mesh['name'],longest_edge(d,b,p))
                if name=='hose':assert max(abs(v[0]) for v in values(d,b,p['attributes']['POSITION']))<.30,'Hose must not include arms/hands'
        garments[name]=count
    for file in OUT.rglob('*'):
        if file.suffix in ('.glb','.blend','.png','.jpg'):assert file.stat().st_size<10*1024*1024,('Storage threshold',str(file),file.stat().st_size)
    result={'body_triangles':triangles,'body_regions':sorted(regions),'animations':len(animations),'garments':garments,'body_sha256':hashlib.sha256((OUT/'kalev_fresh.glb').read_bytes()).hexdigest()}
    print(json.dumps(result,indent=2));return result

if __name__=='__main__':main()
