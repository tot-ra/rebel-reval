shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform vec4 outline_color : source_color = vec4(1.0, 0.85, 0.15, 1.0);
uniform float grow_amount = 0.007;
// WHY: inverted-hull back faces on the far side of a body/skirt are what draw
// "inner contours". A true silhouette back face has a normal near-perpendicular to
// the view ray, so fragments whose normal points away from the camera are dropped.
uniform float silhouette_limit = 0.28;

varying float v_facing;

void vertex() {
	VERTEX += NORMAL * grow_amount;
	vec3 view_normal = normalize((MODELVIEW_NORMAL_MATRIX * NORMAL));
	// Ortho and perspective alike: view-space z of the normal vs the camera axis.
	v_facing = view_normal.z;
}

void fragment() {
	// Back faces have view-space normal z < 0 (pointing away); at the silhouette it is ~0.
	if (v_facing < -silhouette_limit) {
		discard;
	}
	ALBEDO = outline_color.rgb;
}
