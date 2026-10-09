shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// Dusty shafts of sunlight from a church's stained-glass windows (R-1451).
// Each window is a prism of side quads: the window-end vertices (UV.x = 0)
// sit on the glass plane, the far ones (UV.x = 1) are pushed along the light
// until they reach the floor (UV2.x, site-local) or the opposite wall (UV.y,
// the inward depth of the room). The shaft carries the window's mean panel
// colour (COLOR.rgb), fades with throw and towards its silhouette, and dims
// as the wall's thickness (UV2.y) closes the opening (width COLOR.a * 4) to a
// slanting sun. It follows the sun every frame without rebuilding the mesh.

// xyz direction towards the light, w the direct light strength 0..1.
global uniform vec4 window_sun;
uniform float intensity = 0.22;

varying float along;
varying float aperture;

void vertex() {
	// Mesh space is site-local (the shaft mesh sits at the site root).
	vec3 l = normalize(transpose(mat3(MODEL_MATRIX)) * window_sun.xyz);
	vec3 n = normalize(NORMAL);
	float facing = dot(l, n);
	float t = 0.0;
	if (UV.x > 0.5 && l.y > 0.02 && facing > 0.02 && window_sun.w > 0.01) {
		t = min((VERTEX.y - UV2.x) / l.y, UV.y / facing);
		t = max(t, 0.0);
	}
	VERTEX -= l * t;
	along = UV.x;
	// Sideways drift of the light across the wall thickness against the
	// opening's width: a grazing sun gets only a sliver through the reveal.
	vec3 d = normalize(cross(vec3(0.0, 1.0, 0.0), n));
	float drift = UV2.y * abs(dot(l, d)) / max(facing, 0.02);
	aperture = clamp(1.0 - drift / max(COLOR.a * 4.0, 0.1), 0.0, 1.0);
}

void fragment() {
	// Soft silhouette: a side seen edge-on adds little, so the shaft has no
	// hard outline; brightest near the window, thinning towards the floor.
	vec3 nrm = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	float face = smoothstep(0.0, 0.6, abs(dot(nrm, VIEW)));
	float fade = (1.0 - along * 0.75) * smoothstep(0.0, 0.08, along);
	ALBEDO = COLOR.rgb * intensity * window_sun.w * face * fade * aperture;
}
