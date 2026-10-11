// Panel layout of a church window (CI-01, R-1393), shared by the glass itself
// (city_stained_glass.gdshader) and the sunlight it throws into the church
// (city_window_sunlight.gdshader, R-1451), so the coloured patch on the floor
// shows exactly the panels of the window it came through.

// Plate width / height (512 x 768).
const float PLATE_ASPECT = 0.6667;
// Glazing programme per church, six panels each, cycled across the window
// (index from SiteKit.GLAZING): the patron and Marian panels first, grisaille
// between them as in parish glazing of the period.
const int PROGRAMMES[24] = {
	0, 2, 7, 1, 6, 7, // 0 Holy Spirit (hospital church: Passion and Marian cycle)
	3, 1, 7, 0, 2, 7, // 1 St Olaf
	4, 1, 7, 0, 6, 7, // 2 St Nicholas (and its St Barbara chapel)
	5, 1, 7, 2, 0, 7 // 3 St Mary
};

// Plate lookup for a point `uv` (metres across the window from its left edge,
// up from the sill) of a window `total_width` wide with `lights` lights,
// `height` tall, glazing `code` = programme * 16 + seed. Returns the plate uv
// (xy), the plate layer (z) and the saddle-bar factor (w, 0 on the iron bar).
vec4 glass_panel(vec2 uv, float total_width, float lights, float height, int code) {
	float width = total_width / lights;
	int programme = clamp(code / 16, 0, 3);
	int seed = code % 16;
	int light = int(floor(uv.x / width));
	vec2 lu = vec2(mod(uv.x, width), uv.y);
	// A tall narrow light gets a column of panels instead of one plate
	// squeezed into a strip: each panel stays within ~1.3x of the plate's
	// own proportions. The pointed head simply clips the top panel.
	float panels = max(1.0, floor(height * PLATE_ASPECT / width / 1.3 + 0.5));
	float panel_h = height / panels;
	float row = min(floor(lu.y / panel_h), panels - 1.0);
	float pv = lu.y - row * panel_h;
	// Neighbouring lights and stacked panels walk the programme, so no two
	// adjacent figure panels repeat.
	int slot = (seed + light + int(row) * int(lights)) % 6;
	float layer = float(PROGRAMMES[programme * 6 + slot]);
	vec2 pu = vec2(clamp(lu.x / width, 0.0, 1.0), 1.0 - clamp(pv / panel_h, 0.0, 1.0));
	// Iron saddle bar between stacked panels.
	float bar = 1.0;
	if (panels > 1.0) {
		float joint = clamp(floor(lu.y / panel_h + 0.5), 1.0, max(panels - 1.0, 1.0));
		bar = smoothstep(0.012, 0.025, abs(lu.y - joint * panel_h));
	}
	return vec4(pu, layer, bar);
}
