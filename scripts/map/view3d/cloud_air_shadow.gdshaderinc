// Cloud shade of the air, shared by the god-ray pass and the cloud shade map
// (cloud_shadow_map.gdshader). The includer declares `light_dir`, the global cloud
// uniforms, `cloud_cells`, and includes sky_clouds / cloud_cells first.
// Must match cloud_shadow_pass.gdshader CLOUD_LAYER_H (art-scaled deck height).
const float DECK_H = 400.0;
const float DECK_MIP = 1.5;
// Single-layer deck density where the air starts to be shaded and where it is fully
// shaded (the dome draws the same density as an opaque cloud).
const float DECK_OPEN = 0.2;
const float DECK_SOLID = 0.55;

// Share of the light the clouds stop above air point `p` (1 = full shadow): the deck
// projected along the light onto its plane, times the discrete cells. A real (not
// clamped) light slope is used so dawn shafts lie as flat as the sun; only a floor
// keeps the projection finite at the horizon.
float cloud_shadow(vec3 p, float cell_lod) {
	float light_y = max(light_dir.y, 0.03);
	float deck = 0.0;
	if (p.y < DECK_H) {
		vec2 q = p.xz + light_dir.xz / light_y * (DECK_H - p.y);
		vec2 uv = (q / DECK_H) * 0.12 - cloud_offset_g;
		float body = sky_cloud_shadow_soft(
			uv, clamp(cloud_coverage_g, 0.0, 1.0), cloud_shape_tex, cloud_noise_tex,
			cloud_detail_offset_g, cloud_chaos_g, DECK_MIP
		);
		// Threshold like the dome's thick slab: a cloud the player sees as opaque must
		// shade its column, and the thin fringe between heaps must stay open.
		deck = smoothstep(DECK_OPEN, DECK_SOLID, body);
	}
	float cells = cells_ground_shadow(p, light_dir, cloud_noise_tex, cell_lod);
	return 1.0 - (1.0 - deck) * (1.0 - cells);
}

