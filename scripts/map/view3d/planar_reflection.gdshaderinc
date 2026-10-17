// R-1861 planar reflection (PlanarReflection3D, planar_reflection_3d.gd): the scene
// mirrored about a horizontal plane near the view, rendered at reduced size. Pools and
// calm water add it as emission (Mobile has no SSR, so the built-in specular sees only
// the sky radiance). The texture is display-referred (tonemapped, sRGB); it is
// linearised and divided by the main exposure so the main view's tonemap does not lift
// it a second time.
global uniform sampler2D planar_reflection_tex;
// x = plane height (world y), y = strength (0 = off), z = 1 / main exposure, w = height fade (m).
global uniform vec4 planar_reflection_plane;

// Weight of the reflection for a surface at `surface_y`: full on the plane, none
// `planar_reflection_plane.w` metres off it (the mirror is only right on its plane).
float planar_reflection_weight(float surface_y) {
	float fade = planar_reflection_plane.w;
	float off = abs(surface_y - planar_reflection_plane.x);
	return planar_reflection_plane.y * (1.0 - smoothstep(fade * 0.3, fade, off));
}

// Linear radiance of the mirrored scene seen at this pixel. `offset` shifts the lookup
// (ripples, rain rings) in reflection UV; `blur` > 0 spreads four taps that far for a
// film or a rougher surface (the viewport texture has no mipmaps).
vec3 planar_reflection_color(vec2 screen_uv, vec2 offset, float blur) {
	vec2 uv = clamp(vec2(screen_uv.x, 1.0 - screen_uv.y) + offset, vec2(0.002), vec2(0.998));
	vec3 c;
	if (blur > 0.0005) {
		c = textureLod(planar_reflection_tex, clamp(uv + vec2(blur, blur * 0.4), 0.002, 0.998), 0.0).rgb;
		c += textureLod(planar_reflection_tex, clamp(uv + vec2(-blur * 0.4, blur), 0.002, 0.998), 0.0).rgb;
		c += textureLod(planar_reflection_tex, clamp(uv + vec2(-blur, -blur * 0.4), 0.002, 0.998), 0.0).rgb;
		c += textureLod(planar_reflection_tex, clamp(uv + vec2(blur * 0.4, -blur), 0.002, 0.998), 0.0).rgb;
		c *= 0.25;
	} else {
		c = textureLod(planar_reflection_tex, uv, 0.0).rgb;
	}
	vec3 lin = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
	return lin * planar_reflection_plane.z;
}

// Schlick Fresnel of still water (F0 ~0.02) against the geometric up normal; `f0`
// lets a shader match the F0 its SPECULAR implies.
float planar_reflection_fresnel(vec3 up_view, vec3 view_dir, float f0) {
	float c = clamp(dot(up_view, view_dir), 0.0, 1.0);
	return f0 + (1.0 - f0) * pow(1.0 - c, 5.0);
}
