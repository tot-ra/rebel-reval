extends RefCounted

## Species leaf atlas for falling leaves and forest-floor litter:
## assets/vegetation/leaves/leaf_species_atlas.png, built by
## tools/assets/build_leaf_species_atlas.py from one Leonardo photo per species.
## A 4x4 grid; CELLS order matches the tool. Cells hold neutral grey detail and
## an alpha cut-out, so the tint (VegetationPhenology palettes) carries the
## season: green in summer, yellow birch, red maple and rowan, brown oak.

const ATLAS := preload("res://assets/vegetation/leaves/leaf_species_atlas.png")
const PARTICLE_SHADER := preload("res://scripts/map/view3d/leaf_particle.gdshader")
const GRID := 4
const CELLS: Array[StringName] = [
	&"birch", &"oak", &"maple", &"linden",
	&"aspen", &"alder", &"ash", &"elm",
	&"willow", &"rowan", &"cherry", &"apple",
	&"hazel", &"hawthorn", &"blackthorn", &"pine_needles",
]
## Species without their own photo borrow the closest leaf.
const BORROWED := {
	&"plum": &"apple",
	&"pear": &"apple",
	&"spruce": &"pine_needles",
	&"pine": &"pine_needles",
	&"juniper": &"pine_needles",
}
const FALLBACK := &"linden"
## Real leaf length in metres (rowan: the whole compound leaf; needles: a
## cluster). The leaf fills FILL of its square cell, see the atlas tool.
const LEAF_LENGTH_M := {
	&"birch": 0.06, &"oak": 0.11, &"maple": 0.14, &"linden": 0.07,
	&"aspen": 0.06, &"alder": 0.08, &"ash": 0.08, &"elm": 0.12,
	&"willow": 0.10, &"rowan": 0.18, &"cherry": 0.10, &"apple": 0.08,
	&"hazel": 0.10, &"hawthorn": 0.05, &"blackthorn": 0.04, &"pine_needles": 0.15,
}
const FILL := 0.88

static var _particle_materials: Dictionary = {}


static func cell_name(species: StringName) -> StringName:
	if species in CELLS:
		return species
	return BORROWED.get(species, FALLBACK)


static func cell_for(species: StringName) -> int:
	return CELLS.find(cell_name(species))


## Atlas UV rectangle of a cell (position, size).
static func uv_rect(cell: int) -> Rect2:
	var size := 1.0 / float(GRID)
	return Rect2(Vector2(float(cell % GRID), float(cell / GRID)) * size, Vector2(size, size))


## Side of the square quad that shows this species' leaf at real size.
static func quad_side_m(species: StringName) -> float:
	return float(LEAF_LENGTH_M.get(cell_name(species), 0.08)) / FILL


## Falling-leaf material. `cell` -1 reads the cell from the particle colour
## alpha (CityLeafFall packs (cell + 0.5) / 16 there); otherwise every leaf
## drawn with it shows that cell (district bursts, one species per emitter).
static func particle_material(cell: int = -1) -> ShaderMaterial:
	if not _particle_materials.has(cell):
		var material := ShaderMaterial.new()
		material.shader = PARTICLE_SHADER
		material.set_shader_parameter("leaf_atlas", ATLAS)
		material.set_shader_parameter("fixed_cell", cell)
		_particle_materials[cell] = material
	return _particle_materials[cell]


## Particle colour alpha that selects `cell` in particle_material(-1).
static func cell_code(cell: int) -> float:
	return (float(cell) + 0.5) / float(GRID * GRID)


## A leaf for particles: a unit square folded a little along its midrib so it
## keeps some body edge-on. Long axis is z, petiole at +z (atlas v = 1).
static func folded_leaf_mesh(size: Vector2 = Vector2.ONE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lift := 0.12 * size.x
	var half := size * 0.5
	var rib_a := Vector3(0.0, 0.0, -half.y)
	var rib_b := Vector3(0.0, 0.0, half.y)
	var corners := {
		"la": Vector3(-half.x, lift, -half.y), "lb": Vector3(-half.x, lift, half.y),
		"ra": Vector3(half.x, lift, -half.y), "rb": Vector3(half.x, lift, half.y),
	}
	var quads := [
		[corners["la"], rib_a, rib_b, corners["lb"]],
		[rib_a, corners["ra"], corners["rb"], rib_b],
	]
	for quad: Array in quads:
		for i: int in [0, 1, 2, 0, 2, 3]:
			var v: Vector3 = quad[i]
			st.set_color(Color.WHITE)
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x / size.x + 0.5, v.z / size.y + 0.5))
			st.add_vertex(v)
	return st.commit()
