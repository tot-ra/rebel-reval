"""Submit original image references to the local Hunyuan multi-view model.

No previous character mesh or screenshot is an input. Server setup is recorded
in the task report; this script never installs or calls a paid generation API.
"""
import argparse
import json
from pathlib import Path
import shutil
import urllib.request

ROOT=Path(__file__).resolve().parents[3]


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--server',default='http://127.0.0.1:8190');opts=parser.parse_args()
    folder=ROOT/'build/kalev_fresh';inputs=folder/'comfy_input';inputs.mkdir(parents=True,exist_ok=True)
    for view in ('front','back'):
        shutil.copy2(ROOT/f'assets/characters/kalev_fresh/reference/{view}.png', inputs/f'{view}.png')
    graph={
        '1':{'class_type':'ImageOnlyCheckpointLoader','inputs':{'ckpt_name':'hunyuan3d-dit-v2-mv_fp16.safetensors'}},
        '2':{'class_type':'LoadImage','inputs':{'image':'front.png'}},
        '3':{'class_type':'LoadImage','inputs':{'image':'back.png'}},
        '4':{'class_type':'ImagePadForOutpaint','inputs':{'image':['2',0],'left':256,'right':256,'top':0,'bottom':0,'feathering':0}},
        '5':{'class_type':'ImagePadForOutpaint','inputs':{'image':['3',0],'left':256,'right':256,'top':0,'bottom':0,'feathering':0}},
        '6':{'class_type':'CLIPVisionEncode','inputs':{'clip_vision':['1',1],'image':['4',0],'crop':'none'}},
        '7':{'class_type':'CLIPVisionEncode','inputs':{'clip_vision':['1',1],'image':['5',0],'crop':'none'}},
        '8':{'class_type':'Hunyuan3Dv2ConditioningMultiView','inputs':{'front':['6',0],'back':['7',0]}},
        '9':{'class_type':'EmptyLatentHunyuan3Dv2','inputs':{'resolution':3072,'batch_size':1}},
        '10':{'class_type':'KSampler','inputs':{'model':['1',0],'seed':2121343,'steps':24,'cfg':5.5,'sampler_name':'euler','scheduler':'simple','positive':['8',0],'negative':['8',1],'latent_image':['9',0],'denoise':1.0}},
        '11':{'class_type':'VAEDecodeHunyuan3D','inputs':{'samples':['10',0],'vae':['1',2],'num_chunks':64000,'octree_resolution':512}},
        '12':{'class_type':'VoxelToMesh','inputs':{'voxel':['11',0],'algorithm':'surface net','threshold':0.6}},
        '13':{'class_type':'SaveGLB','inputs':{'mesh':['12',0],'filename_prefix':'fresh_kalev_base'}},
    }
    (folder/'workflow.json').write_text(json.dumps(graph,indent=2))
    request=urllib.request.Request(opts.server+'/prompt',data=json.dumps({'prompt':graph}).encode(),headers={'Content-Type':'application/json'})
    response=json.load(urllib.request.urlopen(request))
    (folder/'generation_job.json').write_text(json.dumps(response,indent=2))
    print(json.dumps(response))


if __name__=='__main__':main()
