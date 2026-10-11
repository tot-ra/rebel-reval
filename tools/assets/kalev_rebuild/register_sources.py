"""Refresh only this task's provenance rows, preserving all other bytes."""
import csv,hashlib,io,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'assets/characters/kalev_fresh';MANIFEST=ROOT/'assets/SOURCES.csv';PREFIX='assets.characters.kalev_fresh.'

def main():
    rows=[]
    for path in sorted(OUT.rglob('*')):
        if path.suffix.lower() not in ('.glb','.blend','.png','.jpg','.jpeg'):continue
        relative=path.relative_to(ROOT).as_posix();identifier=relative.lower().replace('/','.').replace(' ','_')
        rows.append([identifier,relative,'OpenAI ImageGen; local Hunyuan3D; original Blender authoring','ImageGen revision unexposed; Hunyuan3D v2 MV fp16; Blender 5.2; CC0 KayKit motion metadata','docs/reports/kalev_rebuild_2026-09-12.md; reference/prompts.json; SHA-256 '+hashlib.sha256(path.read_bytes()).hexdigest(),'2121343 (mesh); image seed unexposed','Original AI-generated art; project AGPL-3.0-or-later; reused skeleton/motion CC0 1.0','New original references and reconstructed geometry; no previous character visual input; separate fitted wardrobe and shared motion bindings.','review candidate - maintainer-requested P0-214 original character; production visual approval pending'])
    buf=io.StringIO(newline='');csv.writer(buf,lineterminator='\n').writerows(rows)
    for attempt in range(5):
        original=MANIFEST.read_bytes();lines=original.decode().splitlines(keepends=True)
        retained=''.join(line for line in lines if not line.startswith(PREFIX))
        result=(retained+('' if retained.endswith('\n') else '\n')+buf.getvalue()).encode()
        if MANIFEST.read_bytes()!=original:continue
        tmp=MANIFEST.with_name('SOURCES.kalev_fresh.tmp');tmp.write_bytes(result)
        if MANIFEST.read_bytes()!=original:tmp.unlink();continue
        os.replace(tmp,MANIFEST);print('Registered',len(rows),'fresh character source rows; unrelated lines preserved.');return
    raise RuntimeError('Concurrent provenance edits; retry after other writer finishes')

if __name__=='__main__':main()
