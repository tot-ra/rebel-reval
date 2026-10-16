shader_type spatial;
// Warm light leaking out of a lived-in house at night (docs/SYSTEMS/NIGHT_LIGHTING.md).
// One additive card sits inside each window opening, behind the glazing. All
// houses of a city chunk share one mesh, so the per-house inputs ride in the
// vertex colour and the clock in a global; no OmniLight is spent per window.
//   COLOR.r  HouseholdDay.house_shift remapped 0..1 (-0.3..+0.3 h)
//   COLOR.g  census wealth tier / 2 (poor 0, middling 0.5, rich 1)
//   COLOR.b  per-window random 0..1 (which rooms face the street)
//   COLOR.a  1 when a census household lives here, else 0 (card stays dark)
// The schedule mirrors HouseholdDay: the hearth burns 05:24-08:36 and 16:36-21:24
// (shifted per house), the table light on dark mornings and evenings while people
// are up (04:54-21:30). After that the house is dark: fire banked under ash and
// shutters closed, as the night bell demanded, except a rare sickbed or birth vigil.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// x hour 0..24, y darkness 0..1 (0 by day), z seconds for flicker.
global uniform vec4 city_night_clock;

uniform vec3 hearth_color : source_color = vec3(1.0, 0.36, 0.09);
uniform vec3 candle_color : source_color = vec3(1.0, 0.58, 0.24);
uniform float glow_energy = 2.4;

varying vec4 house;

void vertex() {
	house = COLOR;
}

float lit_between(float h, float a, float b) {
	return smoothstep(a - 0.05, a + 0.05, h) * (1.0 - smoothstep(b - 0.05, b + 0.05, h));
}

void fragment() {
	float dark = city_night_clock.y;
	if (house.a < 0.5 || dark <= 0.001) {
		discard;
	}
	float hour = city_night_clock.x;
	float t = city_night_clock.z;
	float shift = house.r * 0.6 - 0.3;
	float tier = house.g;
	float pick = house.b;
	float h = hour - shift;
	float hearth = max(lit_between(h, 5.4, 8.6), lit_between(h, 16.6, 21.4));
	float table = lit_between(hour, 4.9, 21.5);
	// The hearth room faces the street in about half the poor houses and most rich
	// ones; a rich house also lights a second room. A poor house has no table light
	// worth the name: tallow cost money, so the hearth or a pine splint does.
	float hearth_room = step(pick, 0.45 + 0.25 * tier);
	float side_room = step(pick, 0.15 + 0.35 * tier) * (1.0 - hearth_room);
	float candle_strength = mix(0.25, 0.75, tier);
	// A sickbed, a birth or a wake keeps one light burning through the night.
	float vigil = step(fract(pick * 37.13 + house.r * 11.7), 0.03)
		* (1.0 - table) * step(0.5, dark);
	// Fire flickers fast and deep; a candle only trembles.
	float phase = pick * 40.0 + house.r * 17.0;
	float flick = 0.72 + 0.16 * sin(t * 7.3 + phase) + 0.12 * sin(t * 13.1 + phase * 1.7);
	float tremble = 0.92 + 0.08 * sin(t * 5.1 + phase);
	// The fire is low in the room: the bottom of the pane is brighter.
	float low = mix(1.0, 0.45, UV.y);
	float edge = smoothstep(0.0, 0.22, UV.x) * smoothstep(1.0, 0.78, UV.x)
		* smoothstep(0.0, 0.15, UV.y) * smoothstep(1.0, 0.85, UV.y);
	vec3 light = hearth_color * hearth * hearth_room * flick * low
		+ candle_color * table * candle_strength * (hearth_room + side_room) * tremble
		+ candle_color * vigil * 0.35 * tremble;
	ALBEDO = light * edge * dark * glow_energy;
}
