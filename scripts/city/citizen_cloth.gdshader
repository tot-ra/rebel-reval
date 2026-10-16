// Census resident cloth (docs/SYSTEMS/CITIZEN_WARDROBE.md, task R-1667).
// One material per (garment material, cloth grade), shared by every resident who
// wears it. What differs per resident lives in instance uniforms: the dyes and
// the wear (mud, soot, flour, stains, patches, fading), so no resident owns a
// material or a texture. CitizenWardrobe swaps `cull_back` for `cull_disabled`
// for double-sided garments.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// RGBA: R mud spatter, G soot smudge, B flour dust, A stain blotches (textiles.wear_mask).
uniform sampler2D wear_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
// Linear colour of the undyed garment (the glTF base colour factor).
uniform vec3 base_color = vec3(1.0);
// Garment UVs count tiles of the baked family; uv_scale maps them onto the grade tile.
uniform float uv_scale = 1.0;
uniform float tile_metres = 0.09;
uniform float wear_tile_metres = 0.6;
uniform float normal_depth = 1.0;
// Rim sheen of a wool nap or fur; 0 for linen and leather.
uniform float fuzz = 0.0;
// Which instance dye replaces base_color: 0 none, 1 dye_outer, 2 dye_under.
uniform int dye_slot = 0;

// Linear rgb; a = 1 when the resident has a dye for this slot.
instance uniform vec4 dye_outer = vec4(1.0, 1.0, 1.0, 0.0);
instance uniform vec4 dye_under = vec4(1.0, 1.0, 1.0, 0.0);
// mud, soot, flour, stain amounts (0..1).
instance uniform vec4 wear_soil = vec4(0.0);
// patches, fade, seed (0..1), unused.
instance uniform vec4 wear_age = vec4(0.0);

// Model-space height and front of the skinned body (metres; feet at 0, face +Z).
varying vec3 body_pos;

// Dried street mud and ash read lighter than dark wool, as on worn clothes in KCD2.
const vec3 MUD = vec3(0.16, 0.125, 0.085);
const vec3 SOOT = vec3(0.035, 0.033, 0.031);
const vec3 ASH = vec3(0.11, 0.105, 0.1);
const vec3 FLOUR = vec3(0.78, 0.76, 0.70);
const vec3 STAIN = vec3(0.13, 0.025, 0.018);

float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float band(float h, float lo, float hi, float soft) {
	return smoothstep(lo - soft, lo, h) * (1.0 - smoothstep(hi, hi + soft, h));
}

void vertex() {
	body_pos = VERTEX;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 tint = base_color;
	if (dye_slot == 1 && dye_outer.a > 0.5) {
		tint = dye_outer.rgb;
	} else if (dye_slot == 2 && dye_under.a > 0.5) {
		tint = dye_under.rgb;
	}
	vec3 albedo = texture(albedo_tex, uv).rgb * tint;
	vec3 orm = texture(orm_tex, uv).rgb;
	float rough = orm.g;
	float seed = wear_age.z;
	vec2 metres = UV * tile_metres;

	// Patches: some 16 cm cells of a poor garment are pieces of other cloth,
	// sewn on with a darker seam. Hashed per resident (seed), stable per garment.
	vec2 cell_uv = metres / 0.16 + seed * 17.0;
	vec2 cell = floor(cell_uv);
	vec2 f = fract(cell_uv);
	float edge = min(min(f.x, f.y), min(1.0 - f.x, 1.0 - f.y));
	float pick = hash12(cell);
	float patch_piece = step(pick, wear_age.x * 0.22) * step(0.12, edge);
	float seam = patch_piece * (1.0 - smoothstep(0.12, 0.16, edge));
	vec3 other = albedo * (0.72 + 0.5 * hash12(cell + 3.7)) * vec3(1.0, 0.96 + 0.08 * hash12(cell + 9.1), 0.92);
	albedo = mix(albedo, other, patch_piece);
	albedo *= 1.0 - 0.45 * seam;

	// Fading: sun and lye pale and grey the dye of everyday clothes.
	float grey = dot(albedo, vec3(0.3, 0.59, 0.11));
	albedo = mix(albedo, vec3(grey) * 1.1 + 0.025, wear_age.y * 0.5);

	vec4 mask = texture(wear_tex, metres / wear_tile_metres + seed * vec2(0.37, 0.61));
	float h = body_pos.y;
	float front = smoothstep(-0.02, 0.1, body_pos.z);
	// Mud: splashed hems, thickest at the ground.
	float mud = wear_soil.x * (1.0 - smoothstep(0.1, 0.7, h));
	mud = clamp(mud * (mask.r * 2.4 + 0.7 * (1.0 - smoothstep(0.05, 0.35, h))), 0.0, 1.0);
	// Soot: the forge greys the whole upper body, blackest in front.
	float soot = wear_soil.y * mix(0.45, 1.0, front) * smoothstep(0.45, 0.85, h);
	soot = clamp(soot * (0.25 + 1.3 * mask.g), 0.0, 1.0);
	// Flour, lime and stone dust: front of the body and the sleeves.
	float flour = wear_soil.z * mix(0.35, 1.0, front) * band(h, 0.6, 1.5, 0.15);
	flour = clamp(flour * (0.2 + mask.b * 1.8), 0.0, 1.0) * 0.85;
	// Blood and gut stains: front of the belly, where the work is held.
	float stain = wear_soil.w * front * band(h, 0.75, 1.3, 0.12);
	stain = clamp(stain * mask.a * 1.4, 0.0, 1.0);

	albedo = mix(albedo, MUD, mud);
	// Soot greys the cloth first (ash) and blackens where it is thickest.
	albedo = mix(albedo, ASH, soot * 0.7);
	albedo = mix(albedo, SOOT, smoothstep(0.5, 1.0, soot) * 0.8);
	albedo = mix(albedo, FLOUR, flour);
	albedo = mix(albedo, STAIN, stain * 0.85);
	rough = mix(rough, 0.97, max(mud, flour));
	rough = mix(rough, 0.6, stain * 0.5);

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	AO = orm.r;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	RIM = fuzz * (1.0 - max(mud, soot));
	RIM_TINT = 0.6;
}
