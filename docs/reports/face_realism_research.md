# Face realism research - AAA practice and the procedural translation

Date: 2026-08-07. Trigger: maintainer report that generated character faces read as
unrealistic and simplistic (reference: Witcher 3 and other modern blockbusters).

## What AAA faces actually consist of

Distilled from public material on the Witcher 3 / CDPR-style pipeline, Blur Studio's
FACS workflow ([Gnomon: facial blendshapes from photogrammetry](https://www.thegnomonworkshop.com/tutorials/creating-facial-blendshapes-using-photogrammetry)),
Unity HDRP's eye documentation ([Eye Shader](https://docs.unity3d.com/Packages/com.unity.render-pipelines.high-definition@10.5/manual/eye-shader.html)),
and the classic anatomical eye-rendering literature ([Francois et al., anatomically accurate eye rendering](https://inria.hal.science/inria-00166304v1/file/RReye2.pdf)).

1. **Sculpted craniofacial form, not primitives.** Faces start from 3D scans or
   ZBrush sculpts and are retopologized with edge loops that follow anatomy:
   brow ridge, recessed eye sockets (orbit), nasal bone and alae (nostril wings),
   zygomatic cheekbones, nasolabial mounds, philtrum, vermillion lip border,
   mental crease and chin boss, jaw angle, structured ear (helix/lobe). No
   sphere is ever "glued on" - every feature emerges from the skin surface.
2. **Textures carry the realism.** 2K-4K albedo maps hold soft color zoning
   (red nose/cheeks/ears, cooler darker eye sockets, lip tint, beard stubble,
   freckles/moles) and tiled pore/wrinkle detail normals are layered over the
   baked sculpt normal. Roughness varies (oilier T-zone). Flat single-color
   skin is the first tell of a game asset.
3. **Skin shading**: subsurface scattering / wrap diffuse. Our renderer is GL
   Compatibility, where Godot does not support SSS - so the warm wrap response
   has to be suggested through the albedo zoning instead.
4. **Eyes are a layered construction**, never a textured ball: sclera sphere,
   iris with a dark **limbal ring** at its edge, pupil, a transparent bulging
   **cornea** that supplies the specular highlight, upper and lower lid shells
   that overlap the eyeball, a tearline/caruncle at the inner corner. The
   limbal ring and the corneal highlight are the two highest-value cues.
5. **Hair** is strand/card based (Witcher 3 used NVIDIA HairWorks,
   [GDC Vault](https://gdcvault.com/play/1020664/The-Witcher-3-Enabling-Next));
   out of scope here, but brows as tapered tubes instead of boxes move in that
   direction.
6. **Animation** uses FACS blendshapes. Our shared-rig contract (one head bone,
   retargeted clips) forbids facial blendshapes; realism must therefore come
   from rest-pose form, materials, and texture - items 1-4.

## Translation into the deterministic generator

Constraints: `tools/hero_body_head_builder.py` output must keep the head bone,
weights (`{"head": 1.0}`), stable mesh names, per-spec `face` knobs, Tier-0/1
triangle caps (60k/56k total per body, hero baseline 51,312 with head 23,776),
and GL Compatibility materials.

- **Parametric sculpt pass**: landmark displacement fields (Gaussian sockets,
  brow ridge, cheekbones, chin boss, mental crease, temples) applied to the
  head-tube vertices in head-local space before build. Zero extra triangles,
  keeps the ring-profile contract and the `face` spec knobs.
- **Anatomical eye assembly**: smaller spherical eyeball seated in the new
  socket recess, geometry iris + pupil + limbal ring, transparent cornea shell
  (glTF alpha blend), re-seated lid shells, caruncle bead.
- **Sculpted mouth**: lips as tubes following the mouth arc (cupid's bow upper
  lip, fuller lower lip), dark seam at the vermillion border, commissures -
  replacing the two squashed spheres.
- **Structured ear**: helix rim arc + lobe around the existing ear mass.
- **Vertex-color complexion map** (COLOR_0): deterministic per-vertex tint
  fields - periorbital darkening, nose/cheek warmth, stubble mask, neck shade,
  subtle noise - multiplied into the skin albedo by Godot's importer
  (`vertex_color_use_as_albedo`). This replaces the absent SSS/texture zoning
  with zero texture memory and keeps spec palettes working (tints multiply the
  palette color). New spec knob `face.stubble` controls beard-shadow strength.
- **Brow tubes**: tapered tube arcs following the brow ridge replace the
  floating boxes.

Explicit non-goals (renderer/contract blocked): runtime SSS, parallax/refraction
eye shader, hair cards, facial blendshapes, per-character sculpted normal maps.

## What the first pass got wrong, and what fixed it

The parametric sculpt, layered eye and lip work above was written, but not
rendered, before review. Rebuilding it and capturing head close-ups exposed
four failures worth recording, because each is a trap that any future
primitive-based facial work will fall into again.

1. **New materials silently fell back to a garment tone.** `cornea`, `pupil` and
   `lip_seam` were used by the builder but never added to the palette in
   `tools/generate_hero_body.py`, whose lookup falls back to `outerwear`. The
   "transparent" cornea shipped as an opaque dark-brown ball over the iris.
   Fixed by adding the three entries, their roughness/specular response, and a
   `TRANSPARENT_ALPHA` table that drives glTF alpha blending for the cornea.
2. **An eyeball sphere with lid spheres above and below cannot read as an eye.**
   Whatever the radii, a lid ellipsoid seated beside the ball passes *behind*
   the ball at the lid line, so it never occludes the sclera; it just shows its
   own round silhouette against the cheek. Making the lids larger spheres offset
   along the eye axis (so they lie strictly outside the ball where they overlap)
   fixed the occlusion but left two flesh domes. The construction that works is
   a **lens, not a ball**: a flattened sclera ellipsoid sunk into the socket,
   with the aperture bounded by two tapered lid tubes riding its rim plus a dark
   lash-line thread. Almond opening, canthal tilt, no stray silhouettes.
3. **Nose protrusion, not nose shape, is what reads as a wedge.** The first nose
   stood out about a quarter of the head's depth; life is nearer an eighth.
   Halving the forward radii mattered more than any amount of wing and columella
   detail.
4. **The vertex-colour complexion never rendered.** Three separate exporter
   traps, all silent: Blender's glTF exporter writes a flat white COLOR_0 for
   materials with no Color Attribute node and demotes the real data to COLOR_1;
   selecting a single set instead (`ACTIVE`/`NAME`/`MATERIAL` with
   `export_all_vertex_colors=False`) carries the attribute into only the *first*
   primitive of a multi-material mesh; and Godot reads COLOR_0 and nothing else.
   Fixed by exporting all sets and promoting the real one into COLOR_0 in
   `_promote_vertex_colors`, a post-export GLB index rewrite. Verify with
   `MeshInstance3D.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]` in Godot, not
   with the Blender-side attribute, which was correct all along.

Hair and beard now also carry a fibre tint (azimuth-quantised, so strands run
down the skull; quantising world axes instead produced horizontal terracing).

Remaining known gaps, in the order they cost the most: the beard is still a
smooth shell with a hard crossing edge along the cheek, the hair shell shows
ring terracing and UV-island blocks from the procedural hair texture, and
Godot's importer leaves `vertex_color_use_as_albedo` off for the head's first
surface (`hero_beard`), so the beard tint is exported but unused.
