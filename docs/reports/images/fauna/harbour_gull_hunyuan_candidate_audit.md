# Harbour gull Hunyuan3D candidate audit

Date: 2026-07-31
Task: P2-034a
Route: local ComfyUI Hunyuan3D v2 multiview

## Scope

This is an optional candidate pass only. The production Blender-authored GLBs under
`assets/birds/{herring_gull,common_gull,common_tern}/` were not modified, re-exported,
or replaced.

The local ComfyUI endpoint was healthy during the run (`/system_stats` returned HTTP
200), and the installed `hunyuan3d-dit-v2-mv_fp16.safetensors` checkpoint accepted all
three two-view inputs. Seeds, inputs, and workflow parameters are recorded in
`candidate_workflow.json`.

## Audit results

| species | candidate triangles | largest axis (m) | Z range (m) | materials | animations | verdict |
| --- | ---: | ---: | --- | ---: | ---: | --- |
| herring_gull | 212,932 | 1.961977 | -0.744196..0.752910 | 0 | 0 | reject |
| common_gull | 608,462 | 1.962500 | -0.977150..0.985023 | 0 | 0 | reject |
| common_tern | 617,606 | 1.962947 | -0.977589..0.985358 | 0 | 0 | reject |

Production acceptance requires the authored bird budget (8,000 triangles maximum),
metric/catalog scale, gliding pose coverage, and usable material/provenance data.
The generated meshes fail the triangle budget by 26x-77x, have no imported materials
or animations, and are not grounded for the existing gliding pipeline. Their largest
axes also exceed the catalog scale values (0.60 m, 0.43 m, and 0.35 m respectively)
by a wide margin.

## Decision

**Rejected for production.** Keep the deterministic Blender `harbour_gulls_v1` meshes
as production. The generated GLBs are retained only as candidate evidence for a future
cleanup pass; no production asset or runtime file was changed by this task.

Verified after the candidate run:

- `python3 tools/verify_bird_models.py`
- `python3 tools/validate_asset_sources.py`

Both pass against the unchanged production catalog and provenance manifest.
