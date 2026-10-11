// R-1535: sRGB hint for the city's albedo plates, per renderer.
// GL Compatibility (Godot 4.7, macOS) samples `source_color` textures without
// the sRGB decode (measured: earth plate red 0.476 on GL vs 0.178 = decoded
// 0.476 on Metal), and every procedural tone in the city shaders (fieldstone
// paving, moss, soil, lichen) was tuned against those raw plate values. The
// RenderingDevice renderers (Mobile, Forward+) do decode, so the plates went
// ~2.5x darker beside unchanged constants: pale paving, camouflage roof moss.
// Until the art is retuned for decoded plates (ADR 0043), the RD renderers read
// the plates raw too. Usage: `uniform sampler2D x : CITY_PLATE filter_..., ...;`
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define CITY_PLATE source_color,
#else
#define CITY_PLATE
#endif

// The same tuning, on the output side: the city's procedural tones are sRGB-space
// numbers on GL Compatibility. CITY_ALBEDO(c) decodes the finished albedo on the
// RD renderers so paving, moss and soil keep the GL tone; GL returns it as is.
vec3 city_albedo(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	vec3 x = max(c, vec3(0.0));
	return mix(x / 12.92, pow((x + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), x));
#endif
}
