shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

// District and Metal water read the bank/bed for screen-space transmission.
// City GL uses alpha transmission over real geometry and baked bathymetry,
// avoiding depth/screen sampler aliasing on the Compatibility driver.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 shallow_color : source_color = vec3(0.45, 0.62, 0.75);
uniform vec3 deep_color : source_color = vec3(0.16, 0.30, 0.44);
// The rendered terrain remains the physical bed. These tints layer sediment,
// stones and vegetation over it in stable world space instead of requiring a
// second authored mesh for every underwater material transition.
uniform vec3 sand_bed_color : source_color = vec3(0.62, 0.51, 0.30);
uniform vec3 stone_bed_color : source_color = vec3(0.32, 0.36, 0.35);
uniform vec3 algae_bed_color : source_color = vec3(0.14, 0.28, 0.20);
uniform float bed_vegetation = 1.0;
uniform vec3 deep_bed_color : source_color = vec3(0.035, 0.08, 0.11);
uniform float optical_depth = 0.075;
// WS-07 bed caustics: photon-splat tiles from `bake_ocean_fft.py caustics` (light gain
// v/4 in R, mean 1). Unset tiles read white and caustic_min_pair_mean defaults to 1,
// which is no caustics. Tidewater's CausticsParams.strength is 0.75
// (notice.code.tidewater), but here ALBEDO still mixes in the art-weighted sky
// reflection (>= 0.34 + Fresnel, vs ~0.02-0.05 physically at the gameplay camera), so
// the bed carries a small share of the pixel and 0.75 left a +-4/255 net on the
// clear-noon plate. The clear preset's direct-sun gate is 0.70, so 2.8 is ~2.0
// effective, which reads as a net; revisit when WS-11 moves the reflection out.
uniform float caustic_strength = 2.8;
// WS-07 caustic tiles packed by WS-11: R = fine, G = broad (see caustics_common.gdshaderinc).
uniform sampler2D caustics_tiles : hint_default_white, filter_linear_mipmap, repeat_enable;
// Mean of min(layer A, layer B) per tile (caustics_profile.json min_pair_mean).
uniform vec2 caustic_min_pair_mean = vec2(1.0, 1.0);
// false on the `minimum` tier: dominant tile only, two layers, no dispersion (2 samples).
uniform bool caustic_full_quality = true;
// Art knob (ADR 0018): the physical net cell is 0.1-0.3 m, 4-5 px at the gameplay camera,
// where the depth mip blur averages it away. The tiles are magnified horizontally by this
// factor so the net reads; motion and depth focus stay physical.
uniform float caustic_pattern_scale = 3.0;
uniform vec3 highlight_color : source_color = vec3(0.396, 0.694, 0.769);
uniform vec3 foam_color : source_color = vec3(0.72, 0.80, 0.78);
uniform float wave_height = 0.032;
uniform float wave_chaos = 1.0;
uniform float wave_speed = 1.0;
// Horizontal Gerstner sharpening. 0 is a sine sheet; ~1 peaks crests the way
// an FFT ocean's choppiness does, without a compute FFT on GL Compatibility.
uniform float choppiness = 0.85;
// 0 travels with the wind; ~0.4 bobs in place for sheltered harbors.
uniform float standing_wave_ratio = 0.12;
uniform float depth_absorption = 7.0;
uniform float foam_intensity = 0.22;
uniform float breaker_intensity = 0.35;
// Water2-style dual normal detail without texture memory: two independent
// procedural layers are phase-blended and advected by the optional river flow.
uniform float detail_normal_strength = 0.30;
uniform float detail_normal_scale = 1.0;
// River current: world-XZ flow direction and strength. Zero for still water, so
// sea and pond surfaces are unaffected. Non-zero advects the wave field
// downstream and spawns drifting foam ribbons so a river reads as moving water.
uniform vec2 flow_direction = vec2(0.0, 0.0);
uniform float flow_strength = 0.0;
// Channel centreline of the current map's river, downstream-ordered, from
// MapViewRiverFlow: xy = world XZ, z = half width there, w unused. With fewer
// than two points the river falls back to the single flow_direction heading.
const int RIVER_PATH_MAX = 24;
uniform vec4 river_path[RIVER_PATH_MAX];
uniform int river_path_count = 0;
// World units per second per unit of flow_strength: mesh advection of the wave field,
// and the slide speed of the river's surface ripples. ~1 m/s at the Pirita's 0.6.
const float RIVER_ADVECT_SPEED = 1.4;
const float RIVER_SURFACE_SPEED = 1.8;
const float RIVER_DISPLACEMENT_SCALE = 0.0;
// Open-channel velocity profile: the bank drags the water, the fastest thread
// runs mid-channel. Share of mid-channel speed left at the bank.
const float RIVER_BANK_DRAG = 0.35;
// World units the ripple pattern travels per flow-map cycle. Because the speed
// varies across the channel, a single sliding offset would shear the pattern
// without bound; two half-cycle phases crossfade instead, so the stretch resets.
const float RIVER_FLOW_CYCLE = 6.0;
// Matches sky sun-disk fade / MapView3D day_blend. Defaults keep daytime look
// until apply_water_lighting() pushes the live cycle values.
uniform float sun_visibility = 1.0;
uniform float sun_reflection_visibility = 1.0;
uniform float day_blend = 1.0;
// The water samples the same catalog texture and celestial directions as the
// sky dome. This is cheaper than a planar reflection and stays deterministic.
uniform sampler2D star_map : filter_nearest, repeat_enable;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_reflection_color : source_color = vec3(1.0, 0.92, 0.74);
uniform float moon_visibility = 0.0;
uniform float star_visibility = 0.0;
uniform float observer_latitude = 1.0371;
uniform float sidereal_angle = 3.8101;
// Sky-dome gradient uniforms mirror sky_weather_3d defaults so reflected water
// matches the visible dome without a planar reflection pass.
uniform vec3 day_top_color : source_color = vec3(0.18, 0.38, 0.65);
uniform vec3 day_horizon_color : source_color = vec3(0.67, 0.75, 0.81);
uniform vec3 night_top_color : source_color = vec3(0.020, 0.045, 0.130);
uniform vec3 night_horizon_color : source_color = vec3(0.050, 0.100, 0.220);
uniform vec3 sunset_color : source_color = vec3(1.0, 0.25, 0.09);
uniform float sunset_factor = 0.0;
uniform float cloud_darken = 0.0;
// WS-11: reflections sample the dome's own WS-10 sky-view LUT (HDR, no RGBM decode) with the
// dome's art exposure/tint, so the sea mirrors the physical sky: the warm sun-side horizon
// and the Earth-shadow band opposite it. The gradient uniforms above are the fallback when
// the LUT is missing. Adaptation and sunset boost defaults equal sky_weather_3d.gdshader's.
uniform bool sky_lut_available = false;
uniform sampler2D sky_view_lut : filter_linear, repeat_disable;
uniform vec2 sky_lut_size = vec2(192.0, 108.0);
uniform float sky_exposure = 0.7;
uniform vec3 sky_tint : source_color = vec3(1.0);
uniform float sky_adaptation = 0.6;
uniform float sky_adaptation_max_gain = 4.0;
uniform float sky_adaptation_reference = 0.155;
uniform float sunset_boost = 0.55;
// Coastal terrain receives the live equilibrium tide. River water keeps zero
// response, while shallow/deep sea tune shoreline retreat and optical depth.
uniform float tide_level = 0.0;
uniform float tide_height = 0.0;
uniform float tide_shore_retreat = 0.0;
uniform float tide_optical_depth = 0.0;
// Stagnant moat/pond look (TERRAIN_WATER only; 0 leaves sea and river untouched).
// A town moat is a murky olive-brown ditch, not clear sea: the column darkens toward
// the middle (reads as deep), a silty shelf rims the bank, and duckweed, algae mats
// and leaf litter float on the surface. pond_murk scales the tint, pond_scum the cover.
uniform float pond_murk = 0.0;
uniform float pond_scum = 0.0;
uniform vec3 pond_deep_color : source_color = vec3(0.035, 0.06, 0.04);
uniform vec3 pond_shelf_color : source_color = vec3(0.17, 0.17, 0.09);
uniform vec3 pond_duckweed_color : source_color = vec3(0.13, 0.20, 0.05);
// Shared SkyWeather heading. Default matches the authored primary swell axis so
// calm seas keep the pre-P0-226 look until apply_sea_weather() pushes live wind.
uniform vec2 wind_direction = vec2(0.9578, 0.2873);

// WS-04 baked FFT ocean (tools/bake_ocean_fft.py, WS-03). One clock drives the
// sea on GPU and CPU: MapViewRuntimeEnvironment accumulates the scaled world
// delta into ocean_time, so time controls pause waves and boats read the same t.
global uniform float ocean_time;
// WS-08 shore swash (wave sets, breaking bore, run-up sheet, wall slosh).
#include "res://scripts/map/view3d/shore_swash.gdshaderinc"
// True only on the generated beach film (ShoreSwashSheet). It shares every
// other uniform with its source water family through MapViewMaterials.
uniform bool swash_sheet = false;
// Shore wave geometry budget, like fft_geometry_scale: the water column above
// the recessed bed is only a few hundredths of a unit, so crests are compressed
// while foam, turbidity and run-up keep the physical wave.
uniform float shore_geometry_scale = 0.12;
// WS-04 FFT uniforms and sampling live in the shared include (WS-13).
#include "res://scripts/map/view3d/ocean_fft_common.gdshaderinc"
// WS-07 tile helpers shared with UnderwaterPass so the net matches from above and below.
#include "res://scripts/map/view3d/caustics_common.gdshaderinc"
#include "res://scripts/map/view3d/atmosphere_common.gdshaderinc"
// R-1400 / R-1436: the cloud deck and discrete cells (`cloud_cells`, pushed each frame by
// MapViewMaterials.apply_cloud_cells) shade the water's own direct sun. The
// CloudShadowPass draws before transparents, so it darkens the bed seen through
// the water but not this surface or its glints.
// R-1437: keep this sampler in the vertex stage. The extra global deck
// sampler in water_cloud_shadow silently hides this surface on macOS GL.
// The city lightweight water path can still use the full deck/cell helper.
#include "res://scripts/map/view3d/cloud_cells.gdshaderinc"
// R-1518: the reflected sky carries the dome's post-rain bow (same uniforms as the dome,
// pushed by MapViewWaterMaterials.apply_water_rainbow).
uniform float rainbow_strength = 0.0;
uniform float rainbow_droplet = 0.85;
uniform vec3 rainbow_curtain = vec3(0.0);
uniform float rainbow_secondary = 1.0;
// Lower than the dome's 0.55: the reflected sky is darker than the dome, so the same
// additive bow (and its bright interior) read as a white blot on the water.
uniform float rainbow_gain = 0.32;
#include "res://scripts/map/view3d/sky_rainbow.gdshaderinc"
global uniform sampler2D cloud_noise_tex : filter_linear_mipmap, repeat_enable;
global uniform vec3 cloud_sun_dir;

// WS-15 interactive ripples (WaterRippleSim): R = height, G = previous height, B = aeration,
// on a camera-following window. ripple_window = (origin x, origin z, size, valid); valid 0
// (indoors, minimum tier, no sim) turns the whole path off.
uniform sampler2D ripple_state : filter_linear, repeat_disable;
uniform vec4 ripple_window = vec4(0.0, 0.0, 64.0, 0.0);
uniform float ripple_texel_count = 256.0;
// Shading slope per unit of height difference between neighbouring texels.
uniform float ripple_normal_strength = 25.0;
// Geometric lift per unit height. Kept tiny and crest-only: the FFT trough floor leaves just
// 0.0015 units above the recessed bed, and any ripple dip below it z-fights the bed on Metal
// (dark dashed rows in the wake). The normal carries the visible ring and its troughs.
uniform float ripple_vertex_amplitude = 0.004;
uniform float ripple_foam_strength = 0.85;
// WR-5 waves around rocks (WaterRippleSim obstacle mode, city sea only): R = scattered
// height in world units (reflection, diffraction, shadow added to the incident swell),
// G = its vertical velocity, B = impact foam. obstacle_window = (origin x, origin z,
// size, valid); valid 0 leaves the sea exactly as without the sim.
uniform sampler2D obstacle_state : filter_linear, repeat_disable;
uniform vec4 obstacle_window = vec4(0.0, 0.0, 64.0, 0.0);
uniform float obstacle_texel_count = 128.0;
uniform float obstacle_foam_strength = 1.0;
// Art-direction lever: under flat overcast light a bent normal alone barely changes the
// reflected sky, so ring flanks also catch a little highlight colour (rain reads on water).
uniform float ripple_sheen = 2.0;
// Rain rings: 0 dry .. 1 full rain (apply_sea_weather). Real rings span a few centimetres
// and live well under a second, far below the 25 cm ripple-sim texel, so they are drawn
// here procedurally on every water surface instead of being injected into the sim (which
// grew them into metre-wide rings inside a 64-unit window and none outside it).
uniform float rain_ring_intensity = 0.0;
// Sea depth blend: shallow_water and deep_water are separate meshes and materials, so
// their colour and absorption used to change along a hard cell line. Inside the active
// map both sea materials instead blend one look by the rendered WS-13b basin depth
// (R of sea_depth_map, world units, one texel per cell). sea_depth_rect is the map's
// world-XZ origin and size; outside it (neighbour previews) each family keeps its own look.
uniform sampler2D sea_depth_map : hint_default_black, filter_linear, repeat_disable;
uniform vec4 sea_depth_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float sea_depth_blend = 0.0;
// The metre-scale city uses real bathymetry, not the district optical bed floor.
// Screen depth can be invalid in Compatibility after transparent screen passes.
instance uniform bool sea_physical_depth = false;
// WR-3 city sea LOD (CitySeaLod, docs/SYSTEMS/CITY_SEA.md). sea_lod marks the
// camera-centred ring instances; the city then rebinds sea_depth_map as one RGBA
// texel per 4 m lattice vertex: R depth, G signed bed height, B shore floor weight,
// A = 1000 x (cell drawn by the rings) + extra ring levels allowed at that vertex.
instance uniform bool sea_lod = false;
// (origin x, origin z, cell size, 1 = LOD active) and (base spacing, ring-0 range,
// shore level, last level); levels count doublings of the base spacing.
uniform vec4 sea_lod_lattice = vec4(0.0, 0.0, 4.0, 0.0);
uniform vec4 sea_lod_rings = vec4(1.0, 64.0, 2.0, 6.0);
// Selection camera of the current frame (not CAMERA_POSITION_WORLD), so the CPU
// node choice and the vertex morph always agree.
uniform vec3 sea_lod_eye = vec3(0.0);
// 0 on tiers without C1 displacement (graphics-tier preset).
uniform float sea_lod_c1 = 1.0;
// Graphics tier: _city_foam_cells layers (2 = patches + lacework, 3 = + bubble
// cells, 4 = + grain).
uniform int city_foam_layers = 4;
// Metric city water: extinction per metre, independent of the legacy thin-film
// district palette. No extra sampler or pass; Beer-Lambert carries bed visibility.
uniform vec3 physical_extinction = vec3(0.40, 0.24, 0.30);
uniform float water_turbidity = 1.0;
// Basin depths where the look is fully shallow (x) and fully deep (y).
uniform vec2 sea_depth_range = vec2(1.0, 3.6);
// Per family: (choppiness, fft_geometry_scale, standing_wave_ratio, wave_height), kept in
// step with the live uniforms by MapViewWaterMaterials. The two sea meshes share their
// border vertices; displacing them with different parameters opened a crack along the
// authored shallow/deep line and moved the two sheets at visibly different amplitudes.
uniform vec4 sea_wave_shallow = vec4(0.85, 1.0, 0.18, 0.07);
uniform vec4 sea_wave_deep = vec4(1.05, 1.0, 0.08, 0.12);
// Per family: (optical_depth, depth_absorption, tide_optical_depth, unused).
uniform vec4 sea_look_shallow = vec4(0.075, 5.0, 0.055, 0.0);
uniform vec4 sea_look_deep = vec4(0.38, 9.0, 0.025, 0.0);
uniform vec3 sea_shallow_color_shallow : source_color = vec3(0.45, 0.62, 0.75);
uniform vec3 sea_shallow_color_deep : source_color = vec3(0.45, 0.62, 0.75);
uniform vec3 sea_deep_color_shallow : source_color = vec3(0.16, 0.30, 0.44);
uniform vec3 sea_deep_color_deep : source_color = vec3(0.16, 0.30, 0.44);
uniform vec3 sea_highlight_color_shallow : source_color = vec3(0.396, 0.694, 0.769);
uniform vec3 sea_highlight_color_deep : source_color = vec3(0.396, 0.694, 0.769);
uniform vec3 sea_foam_color_shallow : source_color = vec3(0.72, 0.80, 0.78);
uniform vec3 sea_foam_color_deep : source_color = vec3(0.72, 0.80, 0.78);
// WS-06 whitecaps from the baked foam channel (FFT path only; the Gerstner fallback
// keeps the P0-223 Jacobian foam). foam_tile is the seamless bubble/speckle/streak
// detail from `bake_ocean_fft.py foam-tile`; unset it reads black, so no whitecaps.
uniform sampler2D foam_tile : hint_default_black, filter_linear_mipmap, repeat_enable;
// Tiles per world unit: Tidewater foamScale 0.09 per metre x 0.87 m per unit
// (one tile spans ~11 m). The second layer is 2.3x finer.
uniform float foam_tile_scale = 0.0783;
// Tidewater foamCoverage. The two cascade channels both carry full-sea whitecap
// statistics (WS-03 amendment 2), so the contract started at 0.5; with the capped
// mask the overcast/day plate needed the full 1.0 for scattered whitecaps.
uniform float foam_coverage = 1.0;
uniform float foam_sharpness = 2.2;
// Weather scale of the baked mask (apply_sea_weather: calm 0.2 .. storm 1.8).
uniform float storm_foam_coverage = 0.8;
// R-955: 0 below Beaufort 4, 1 at/above. Gates baked whitecaps without retuning
// the WS-06 foam_coverage art lever on storms.
uniform float whitecap_onset = 1.0;
// WS-06b debug: 1 writes the baked foam mask (fft_foam.x) to ALBEDO/EMISSION so
// Metal vs Compatibility coverage can be compared without lighting or the tile.
uniform float debug_foam_mask = 0.0;
// Capture-only GPU regression: magenta marks non-finite surface math, green valid.
uniform bool debug_surface_validity = false;
// Wind streaks: storm share (0 calm .. 1 storm) times streak_amount. Tidewater's
// 0.3 vanished under the storm sky reflection on the gameplay camera.
uniform float storm_streaks = 0.0;
uniform float streak_amount = 0.6;
// Catspaws (gust) and glassy slicks: a slow, wind-borne field that scales the
// ripple cascade and the detail normal on every sea state.
uniform float gust_amount = 1.0;
uniform float slick_amount = 1.0;
// One gust lattice cell per ~60 world units.
uniform float gust_scale = 0.0167;
// MapViewRuntimeEnvironment.OCEAN_TIME_WRAP_SECONDS. Every drift below moves a whole
// number of tiles or lattice periods per wrap, so the ocean clock wrap never pops.
const float OCEAN_TIME_WRAP_SECONDS = 1638.4;
// WS-01: 1 world unit = 1 map cell = 0.87 m (MapViewBuildingMaterials.METERS_PER_WORLD_UNIT).
const float WATER_METERS_PER_UNIT = 0.87;
// Foam tile drift downwind: ~0.27 m/s and ~0.29 m/s, slow against the wave phase
// speed, so a foam patch still rides its crest.
const float FOAM_DRIFT_A_TILES_PER_WRAP = 40.0;
const float FOAM_DRIFT_B_TILES_PER_WRAP = 100.0;
// The gameplay water column is centimetres (a flat bed a few hundredths of a unit
// down), and sigma_t is already art-scaled ~15x to make it read as Baltic metres.
// The caustic focus uses the same apparent depth: terrain optical floors of
// 0.075 .. 0.38 units become ~1 .. 5 m, spanning the fine (1.2 m) and broad (4 m) bakes.
const float CAUSTIC_APPARENT_SCALE = 15.0;
// Floor of the bed light gain: the skylight share a caustic shadow cell still receives.
const float CAUSTIC_MIN_GAIN = 0.35;
// Gust field period along the wind (lattice cells) and its drift (~2.3 units/s).
const float GUST_PERIOD_CELLS = 16.0;
const float GUST_DRIFT_CELLS_PER_WRAP = 64.0;
// Highest effective whitecap mask. At 1.0 the darker half of the tile stays open, so the
// freshest foam still reads as clustered bubbles.
const float FOAM_MASK_CAP = 1.0;
// WR-1 city sea (sea_physical_depth): C1 share of vertex displacement on the
// 4 m grid, and the water kept above the bed at the bottom of a trough.
const float CITY_C1_GEOMETRY = 0.0;
const float CITY_TROUGH_CLEARANCE = 0.05;
// Bed depth (m) below the still-water line the backwash rundown may uncover.
const float CITY_RUNDOWN_BED = 0.3;
// WR-3 LOD, mirrored by CitySeaLod. Grid quads per ring node side; share of each
// ring over which it morphs into the next; morph values above SNAP count as done,
// so float noise never leaves a micro T-junction; mesh spacing (m) where C1 is
// fully carried / gone and C0 fully carried / gone (Nyquist of 4 m and 16 m waves).
const float SEA_LOD_NODE_QUADS = 16.0;
const float SEA_LOD_MORPH = 0.4;
const float SEA_LOD_SNAP = 0.9995;
const vec4 SEA_LOD_WEIGHT_SPACING = vec4(1.0, 2.0, 4.0, 8.0);
const float SEA_LOD_DRAWN = 1000.0;
// CityWorld3D.SEA_SHORE_DEPTH: depth where the shore factor reaches open water.
const float CITY_SHORE_DEPTH = 2.5;
// WR-2 city foam. Surf foam dissolves over this many seconds after the bore;
// SCUM is the patchy residual coverage left over the surf zone between sets.
const float CITY_SURF_FOAM_LIFE = 4.0;
const float CITY_SURF_SCUM = 0.12;
// Whitecaps: share of the baked foam mask that counts as breaking, its coverage
// gain, and how much of the tile's streak channel survives as wind streaks.
const float CITY_WHITECAP_THRESHOLD = 0.5;
const float CITY_WHITECAP_GAIN = 0.6;
const float CITY_STREAK_SHARE = 0.35;
// World-unit baseline of the bore/crest slope difference (fragment, city sea).
// Long enough to average the shore field's filtering steps, short against the
// 1.4-2.4 unit crest width; the 0.12 unit front meniscus is shaded a touch softer.
const float CITY_RUNUP_SLOPE_STEP = 0.08;
// Fraction of the window over which ripples fade out, so the window edge never shows a seam.
const float RIPPLE_EDGE_FADE = 0.1;
// Steepest ripple facet the shading normal may take (about 31 degrees).
const float RIPPLE_MAX_SLOPE = 0.6;
// WR-5: steepest facet the obstacle field may add to the shading normal (~50 degrees).
const float OBSTACLE_MAX_SLOPE = 1.2;
// Rain rings, world units (0.87 m): one candidate drop per 0.3-unit cell and layer, a ring
// growing to ~7 cm in 0.6 s. Two offset layers break up the lattice.
const float RAIN_RING_CELL = 0.3;
const float RAIN_RING_MAX_RADIUS = 0.3;
const float RAIN_RING_WIDTH = 0.06;
const float RAIN_RING_PERIOD = 1.1;
const float RAIN_RING_LIFE = 0.55;
const float RAIN_RING_SLOPE = 0.45;
// Cells narrower than this many pixels alias into moire; the rings fade out by then.
const float RAIN_RING_MIN_CELL_PX = 6.0;
const float RAIN_RING_FULL_CELL_PX = 14.0;

varying vec3 water_world_position;
// Shallow (0) .. deep (1) share of the sea look from sea_depth_map, or -1 for the per-family
// look. Sampled per vertex on purpose: the fragment stage already uses all 16 sampler units
// GL Compatibility allows (Godot adds shadow, radiance and light samplers), and the basin
// depth is one texel per cell, so vertex interpolation loses nothing.
varying float sea_depth_t;
// Signed, triangle-matched terrain height, supplied by every city sea vertex.
varying float sea_ground_y;
// WR-3: ownership of the (up to four) 4 m cells around a ring vertex, indexed by
// cell parity. Every triangle near land lies inside one cell, and its three
// vertices store that cell under the same parity, so the value is exact per pixel.
varying vec4 sea_lod_cells;
varying vec2 sea_bed_slope;
varying float invalid_surface_vertex;
varying vec2 wave_sample_xz;
varying float shore_factor;
// WS-13b: 1 on in-map water whose rendered sea bed may lie below the flat gameplay
// bed; flat_bed_world_y is that bed plane in world space (from UV2).
varying float flat_bed_flag;
varying float flat_bed_world_y;
// WS-02 inputs for light(), written by fragment(). glint_alpha is the GGX alpha
// (roughness squared) after slope-variance widening. The directional gate covers
// the one DirectionalLight3D, which is the sun by day and the moon by night
// (MapViewLighting slerps it between them). Local lights (torches, forge spill)
// only lose the glint under foam. diffuse_share scales Lambert on ALBEDO.
varying float glint_alpha;
varying float directional_glint_gate;
varying float local_glint_gate;
varying float diffuse_share;
// Combined deck + cell direct-sun occlusion (0 lit .. 1 full shadow).
// WHY per vertex: the fragment stage already uses all 16 GL Compatibility sampler
// units (see sea_depth_t), and the billowed cell edge is ~60 m wide, far coarser
// than any water grid. Both cloud_shape_tex and cloud_noise_tex stay in the
// vertex stage; light() applies the interpolated factor to the directional light only.
varying float cloud_cell_shadow;

// Tidewater: glints are clamped to 400x so they stay inside fp16 range.
const float GLINT_CLAMP = 400.0;
// sin(-6 deg): MapViewLighting finishes handing the light from moon to sun here.
const float SUN_LIGHT_HANDOFF_Y = -0.1045;

float _hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Value noise that repeats every `period` lattice cells along x, so a drift of a
// whole number of periods is invisible (WS-06 gust field and the ocean clock wrap).
float _noise_periodic_x(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, period);
	float x1 = mod(i.x + 1.0, period);
	return mix(
		mix(_hash(vec2(x0, i.y)), _hash(vec2(x1, i.y)), u.x),
		mix(_hash(vec2(x0, i.y + 1.0)), _hash(vec2(x1, i.y + 1.0)), u.x),
		u.y
	);
}

float _noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(_hash(i), _hash(i + vec2(1.0, 0.0)), u.x),
		mix(_hash(i + vec2(0.0, 1.0)), _hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

// Gerstner train. displacement is (dx, height, dz) before wave_height.
// normal_terms is (dh/dx, crest fold, dh/dz), also before wave_height.
// Keep the wavelengths and phases locked with BoatFloat3D.sample_wave.
void _accumulate_wave(
	vec2 position,
	vec2 direction,
	float frequency,
	float speed,
	float amplitude,
	float time,
	vec2 warp,
	float phase_offset,
	inout vec3 displacement,
	inout vec3 normal_terms
) {
	vec2 heading = normalize(direction);
	float spatial = dot(position + warp, heading) * frequency + phase_offset;
	float travel_s = sin(spatial - time * speed);
	float travel_c = cos(spatial - time * speed);
	float standing_s = sin(spatial) * sin(time * speed);
	float standing_c = cos(spatial) * sin(time * speed);
	float standing = clamp(standing_wave_ratio, 0.0, 1.0);
	float wave_s = mix(travel_s, standing_s, standing);
	float wave_c = mix(travel_c, standing_c, standing);
	// Sheltered water bobs more than it shears, so chop falls as standing rises.
	float chop = max(choppiness, 0.0) * (1.0 - standing * 0.65);
	displacement.x += chop * amplitude * heading.x * wave_c;
	displacement.y += amplitude * wave_s;
	displacement.z += chop * amplitude * heading.y * wave_c;
	float slope = frequency * amplitude * wave_c;
	normal_terms.x += heading.x * slope;
	normal_terms.y += chop * frequency * amplitude * wave_s;
	normal_terms.z += heading.y * slope;
}

// Local current of a meandering channel: xy = unit downstream heading of the
// nearest reach, z = share of mid-channel speed at this distance from the
// centreline. Without an authored centreline (sea, ponds, a river whose channel
// could not be reduced to a reach) it returns the single authored heading at
// full speed, which is the pre-R-1160-follow-up behaviour.
vec3 _river_current(vec2 world_xz) {
	vec2 base = normalize(flow_direction + vec2(0.0001, 0.0));
	if (river_path_count < 2) {
		return vec3(base, 1.0);
	}
	float best = 1.0e9;
	vec2 heading = base;
	float lateral = 0.0;
	float half_width = 1.0;
	for (int index = 0; index + 1 < RIVER_PATH_MAX; index++) {
		if (index + 1 >= river_path_count) {
			break;
		}
		vec2 a = river_path[index].xy;
		vec2 b = river_path[index + 1].xy;
		vec2 reach = b - a;
		float length_squared = dot(reach, reach);
		// A zero-length reach has no heading, so it must never win the search:
		// it would stall the ripples wherever it happened to be nearest.
		if (length_squared < 0.000001) {
			continue;
		}
		float t = clamp(dot(world_xz - a, reach) / length_squared, 0.0, 1.0);
		vec2 offset = world_xz - (a + reach * t);
		float distance_squared = dot(offset, offset);
		if (distance_squared < best) {
			best = distance_squared;
			heading = reach * inversesqrt(length_squared);
			lateral = sqrt(distance_squared);
			half_width = max(mix(river_path[index].z, river_path[index + 1].z, t), 0.5);
		}
	}
	float across = clamp(lateral / half_width, 0.0, 1.0);
	return vec3(heading, mix(1.0, RIVER_BANK_DRAG, across * across));
}

vec2 _wave_heading(vec2 base_direction, vec2 current) {
	vec2 ref = normalize(vec2(1.0, 0.28));
	// River: wave trains travel downstream. The sea headings only set a small
	// spread around the current (a quarter of their angle from the reference), so
	// crests stay crossing the channel instead of sliding sideways like open sea.
	if (flow_strength > 0.001) {
		float spread = (atan(base_direction.y, base_direction.x) - atan(ref.y, ref.x)) * 0.25;
		float cs = cos(spread);
		float sn = sin(spread);
		return vec2(current.x * cs - current.y * sn, current.x * sn + current.y * cs);
	}
	vec2 wind = wind_direction / max(length(wind_direction), 0.001);
	float angle = atan(wind.y, wind.x) - atan(ref.y, ref.x);
	float c = cos(angle);
	float s = sin(angle);
	vec2 dir = normalize(base_direction);
	return vec2(dir.x * c - dir.y * s, dir.x * s + dir.y * c);
}

// Three bands stand in for a JONSWAP FFT on GL Compatibility: swell and wind
// waves displace the mesh, ripples stay in the detail normal. Wavelengths stay
// longer than the 1/3-cell water grid so crests are geometric, not aliased.
void _water_field(vec2 position, float time, out vec3 displacement, out vec3 normal_terms) {
	vec2 drift = vec2(time * 0.035, -time * 0.021);
	vec2 warp_position = position * 0.115 + drift;
	vec2 warp = vec2(
		_noise(warp_position + vec2(17.2, -8.4)),
		_noise(warp_position * 0.83 + vec2(-11.7, 23.9))
	) - vec2(0.5);
	vec2 fine_warp = vec2(
		_noise(position * 0.31 + vec2(-time * 0.052, time * 0.018) + vec2(43.1, 7.6)),
		_noise(position * 0.27 + vec2(time * 0.024, time * 0.047) + vec2(-19.4, 31.8))
	) - vec2(0.5);
	warp = (warp * 2.8 + fine_warp * 0.65) * wave_chaos;

	float amplitude_noise = _noise(position * 0.16 + drift * 1.7 + vec2(5.3, 41.2));
	float amplitude_variation = mix(0.72, 1.22, amplitude_noise);
	displacement = vec3(0.0);
	normal_terms = vec3(0.0);
	// One centreline lookup per sample; the wave trains all share this reach.
	vec2 current = _river_current(position).xy;
	// Swell: ~9 m and ~6 m, the scale a harbor camera can actually read.
	_accumulate_wave(position, _wave_heading(vec2(1.0, 0.28), current), 0.62, 0.48, 0.62, time, warp, 0.3, displacement, normal_terms);
	_accumulate_wave(position, _wave_heading(vec2(0.82, 0.55), current), 0.91, 0.61, 0.28, time, warp * 0.8, 1.7, displacement, normal_terms);
	// Wind waves: a few meters, still sampled by the subdivided water grid.
	_accumulate_wave(position, _wave_heading(vec2(0.36, 1.0), current), 1.85, 1.05, 0.16, time, warp * 0.72, 2.1, displacement, normal_terms);
	_accumulate_wave(position, _wave_heading(vec2(-0.55, 0.84), current), 2.70, 1.40, 0.08, time, fine_warp * wave_chaos, 4.2, displacement, normal_terms);
	displacement *= amplitude_variation;
	normal_terms *= amplitude_variation;
}

// Horizontal displacement Jacobian for crest whitecaps. Mirrors _water_field warp
// and wave trains; warp derivatives are omitted like common FFT-ocean stand-ins.
void _accumulate_wave_jacobian(
	vec2 position,
	vec2 direction,
	float frequency,
	float speed,
	float amplitude,
	float time,
	vec2 warp,
	float phase_offset,
	inout vec4 jacobian_terms
) {
	vec2 heading = normalize(direction);
	float spatial = dot(position + warp, heading) * frequency + phase_offset;
	float phase_travel = spatial - time * speed;
	float standing = clamp(standing_wave_ratio, 0.0, 1.0);
	float d_spatial_dx = heading.x * frequency;
	float d_spatial_dz = heading.y * frequency;
	float travel_ds_dx = cos(phase_travel) * d_spatial_dx;
	float travel_ds_dz = cos(phase_travel) * d_spatial_dz;
	float travel_dc_dx = -sin(phase_travel) * d_spatial_dx;
	float travel_dc_dz = -sin(phase_travel) * d_spatial_dz;
	float stand_ds_dx = cos(spatial) * sin(time * speed) * d_spatial_dx;
	float stand_ds_dz = cos(spatial) * sin(time * speed) * d_spatial_dz;
	float stand_dc_dx = -sin(spatial) * sin(time * speed) * d_spatial_dx;
	float stand_dc_dz = -sin(spatial) * sin(time * speed) * d_spatial_dz;
	float ds_dx = mix(travel_ds_dx, stand_ds_dx, standing);
	float ds_dz = mix(travel_ds_dz, stand_ds_dz, standing);
	float dc_dx = mix(travel_dc_dx, stand_dc_dx, standing);
	float dc_dz = mix(travel_dc_dz, stand_dc_dz, standing);
	float chop = max(choppiness, 0.0) * (1.0 - standing * 0.65);
	float ax = chop * amplitude * heading.x;
	float az = chop * amplitude * heading.y;
	jacobian_terms.x += ax * dc_dx;
	jacobian_terms.y += ax * dc_dz;
	jacobian_terms.z += az * dc_dx;
	jacobian_terms.w += az * dc_dz;
}

float _water_jacobian(vec2 position, float time) {
	vec2 drift = vec2(time * 0.035, -time * 0.021);
	vec2 warp_position = position * 0.115 + drift;
	vec2 warp = vec2(
		_noise(warp_position + vec2(17.2, -8.4)),
		_noise(warp_position * 0.83 + vec2(-11.7, 23.9))
	) - vec2(0.5);
	vec2 fine_warp = vec2(
		_noise(position * 0.31 + vec2(-time * 0.052, time * 0.018) + vec2(43.1, 7.6)),
		_noise(position * 0.27 + vec2(time * 0.024, time * 0.047) + vec2(-19.4, 31.8))
	) - vec2(0.5);
	warp = (warp * 2.8 + fine_warp * 0.65) * wave_chaos;
	float amplitude_noise = _noise(position * 0.16 + drift * 1.7 + vec2(5.3, 41.2));
	float amplitude_variation = mix(0.72, 1.22, amplitude_noise);
	vec4 jacobian_terms = vec4(0.0);
	// Crest whitecaps are a still-water path (the caller gates on flow_strength),
	// so the headings never take the river branch and need no centreline lookup.
	vec2 current = normalize(flow_direction + vec2(0.0001, 0.0));
	_accumulate_wave_jacobian(position, _wave_heading(vec2(1.0, 0.28), current), 0.62, 0.48, 0.62, time, warp, 0.3, jacobian_terms);
	_accumulate_wave_jacobian(position, _wave_heading(vec2(0.82, 0.55), current), 0.91, 0.61, 0.28, time, warp * 0.8, 1.7, jacobian_terms);
	_accumulate_wave_jacobian(position, _wave_heading(vec2(0.36, 1.0), current), 1.85, 1.05, 0.16, time, warp * 0.72, 2.1, jacobian_terms);
	_accumulate_wave_jacobian(position, _wave_heading(vec2(-0.55, 0.84), current), 2.70, 1.40, 0.08, time, fine_warp * wave_chaos, 4.2, jacobian_terms);
	jacobian_terms *= amplitude_variation;
	return (1.0 + jacobian_terms.x) * (1.0 + jacobian_terms.w)
		- jacobian_terms.y * jacobian_terms.z;
}

// A finite-difference slope is a small procedural stand-in for a sampled normal
// map. Keeping the samples in world space makes detail continuous across the
// separate water meshes generated for each terrain cell.
vec2 _detail_gradient(vec2 position) {
	float sample_step = 0.07;
	return vec2(
		_noise(position + vec2(sample_step, 0.0)) - _noise(position - vec2(sample_step, 0.0)),
		_noise(position + vec2(0.0, sample_step)) - _noise(position - vec2(0.0, sample_step))
	) / (sample_step * 2.0);
}

// Water2-style dual scrolling detail: each layer has its own frequency, phase
// and scroll vector, while river current advects both layers downstream. This
// affects shading only; the physical displacement remains _water_shape() so
// boats and visuals continue to share the existing wave field.
// One phase of the river ripple pattern: a coarse and a fine layer sampled in the
// (across, along) frame of the local current and rotated back to world XZ, so
// ripples stay stretched along the channel wherever it bends. `seed` separates
// the two crossfaded phases, so the fade reads as changing water, not a dissolve.
// Surface threads of a river: foam ribbons and sky sheen. One warped _noise call
// shows its own axis-aligned lattice as rectangular patches, because a river has
// no wave displacement to break the lattice up the way the sea does. A second
// octave on a lattice rotated 37 degrees and scaled by an irrational-ish factor
// only realigns every few channel widths, so no grid survives.
float _river_threads(vec2 uv, vec2 seed) {
	float coarse = _noise(uv + _noise(uv * 0.6 + seed) * 1.4);
	vec2 rotated = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80)) * uv * 2.17;
	float fine = _noise(rotated + _noise(rotated * 0.7 + seed.yx) * 1.1);
	return coarse * 0.62 + fine * 0.38;
}

vec2 _river_detail_slope(vec2 p, vec2 across_axis, vec2 along_axis, float scale, float seed) {
	vec2 uv_a = vec2(dot(p, across_axis) * 1.9, dot(p, along_axis) * 0.62) * scale
		+ vec2(12.4 + seed * 37.1, -4.7 - seed * 18.3);
	vec2 uv_b = vec2(dot(p, across_axis) * 4.3, dot(p, along_axis) * 1.35) * scale
		+ vec2(-21.8 - seed * 11.9, 16.1 + seed * 25.4);
	vec2 grad_a = _detail_gradient(uv_a);
	vec2 grad_b = _detail_gradient(uv_b);
	vec2 slope_a = across_axis * grad_a.x * 1.9 + along_axis * grad_a.y * 0.62;
	vec2 slope_b = across_axis * grad_b.x * 4.3 + along_axis * grad_b.y * 1.35;
	return (slope_a * 0.55 + slope_b * 0.45) * scale;
}

vec3 _water_detail_normal(vec2 position, float time) {
	float scale = max(detail_normal_scale, 0.1);
	vec2 current_offset = flow_direction * (flow_strength * time * 0.42);
	if (flow_strength > 0.001) {
		// River: ripples slide downstream at a speed the eye can follow, along the
		// local reach rather than one global heading, and slower where the bank
		// drags them. The sea's fixed wind drift is dropped so nothing scrolls
		// against the flow. Two half-cycle phases crossfade (see RIVER_FLOW_CYCLE).
		vec3 current = _river_current(position);
		vec2 across_axis = vec2(-current.y, current.x);
		float travelled = flow_strength * current.z * RIVER_SURFACE_SPEED * time;
		float phase = fract(travelled / RIVER_FLOW_CYCLE);
		vec2 slope_now = _river_detail_slope(
			position - current.xy * (phase * RIVER_FLOW_CYCLE), across_axis, current.xy, scale, 0.0
		);
		vec2 slope_next = _river_detail_slope(
			position - current.xy * (fract(phase + 0.5) * RIVER_FLOW_CYCLE),
			across_axis, current.xy, scale, 1.0
		);
		// Each phase weighs most at its own mid-cycle, where it is least stretched.
		vec2 river_slope = mix(slope_now, slope_next, abs(1.0 - 2.0 * phase));
		return normalize(vec3(-river_slope.x * 0.16, 1.0, -river_slope.y * 0.16));
	}
	vec2 layer_a = position * scale * 1.7 - current_offset;
	layer_a += vec2(-time * 0.19, time * 0.13) + vec2(12.4, -4.7);
	vec2 layer_b = position * scale * 3.9 - current_offset * 1.65;
	layer_b += vec2(time * 0.27, -time * 0.23) + vec2(-21.8, 16.1);
	vec2 slope = _detail_gradient(layer_a) * 0.58 + _detail_gradient(layer_b) * 0.42;
	return normalize(vec3(-slope.x * 0.18, 1.0, -slope.y * 0.18));
}

// Deterministic world-space masks keep the bed continuous across authored water
// terrain borders. The weights always sum to one, so depth changes material
// dominance instead of stacking four opaque color filters.
vec4 _seabed_layers(vec2 position, float water_depth) {
	float broad = _noise(position * 0.12 + vec2(31.7, -14.2));
	float broken = _noise(position * 0.46 + vec2(-9.3, 27.1));
	float detail = _noise(position * 1.85 + vec2(4.6, 18.8));
	float deep_weight = smoothstep(0.20, 0.34, water_depth);
	float shallow_weight = 1.0 - deep_weight;
	float stone_weight = smoothstep(0.56, 0.78, broken * 0.72 + detail * 0.28) * shallow_weight;
	float algae_depth = smoothstep(0.06, 0.16, water_depth) * (1.0 - smoothstep(0.30, 0.46, water_depth));
	// Sparse algae can tint an authentic shallow bed, but it must never read as
	// the terrestrial grass layer continuing below a pond or harbour surface.
	float algae_weight = smoothstep(0.48, 0.72, broad * 0.68 + broken * 0.32) * algae_depth * bed_vegetation * 0.22;
	float sand_weight = max(shallow_weight - stone_weight - algae_weight, 0.08 * shallow_weight);
	float shallow_total = max(sand_weight + stone_weight + algae_weight, 0.0001);
	vec3 shallow_layers = vec3(sand_weight, stone_weight, algae_weight) / shallow_total;
	return vec4(shallow_layers * shallow_weight, deep_weight);
}

// WS-07: light gain on the bed (1 = none) from the baked caustic tiles, projected onto
// the bed along the refracted sun ray. bed_xz is where the refracted view ray meets the
// bed, h_m the apparent bed depth in metres, fft_slope the surface slope (zero off FFT).
// Tile UV / stretch / scroll live in caustics_common.gdshaderinc (byte-identical helpers).
vec3 _bed_caustic_gain(vec2 bed_xz, float h_m, vec3 sun_dir, vec2 fft_slope, vec3 sigma_t, float sun_gate) {
	vec3 sun = normalize(sun_dir);
	vec3 ts = refract(-sun, vec3(0.0, 1.0, 0.0), 1.0 / WATER_IOR);
	float ts_down = max(-ts.y, 0.2);
	vec3 c = _caustic_tiles_at(bed_xz, h_m, sun_dir, fft_slope, caustic_full_quality, true);
	// The light's own path down the column, art-scaled sigma_t per real metre like the
	// view path (h_m is apparent depth; the real column is h_m / CAUSTIC_APPARENT_SCALE).
	vec3 light_down = exp(-sigma_t * (h_m / CAUSTIC_APPARENT_SCALE) / ts_down);
	// With strength above 1 the dark cells between lines would extrapolate below zero;
	// real caustic cells keep some diffuse sky light, so floor the gain.
	return max(vec3(1.0) + (c - vec3(1.0)) * caustic_strength * light_down * sun_gate, vec3(CAUSTIC_MIN_GAIN));
}

// WS-01: view-space position of a depth-buffer sample. GL Compatibility uses
// OpenGL NDC (Z in -1..1); Mobile/Forward+ (the Metal capture path) store NDC Z
// directly (0..1, reversed). One helper keeps both conventions in one place.
vec3 _view_position(vec2 screen_uv, float raw_depth, mat4 inverse_projection) {
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(screen_uv, raw_depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth);
	#endif
	vec4 view_position = inverse_projection * vec4(ndc, 1.0);
	return view_position.xyz / view_position.w;
}

float _view_depth(vec2 screen_uv, float raw_depth, mat4 inverse_projection) {
	return -_view_position(screen_uv, raw_depth, inverse_projection).z;
}

vec2 _world_to_screen_uv(vec3 world_position, mat4 projection, mat4 view) {
	vec4 clip = projection * (view * vec4(world_position, 1.0));
	return clip.xy / clip.w * 0.5 + 0.5;
}

// WS-13b: view depth where this pixel's eye ray meets the flat gameplay bed plane,
// decoded through the same raw-depth round trip as a depth-buffer sample so the
// result matches what the old flat bed wrote (on either renderer). Rays that do
// not descend (camera under the surface looking up) return a far value.
float _flat_bed_view_depth(
	vec3 view_vertex, float bed_world_y, vec2 screen_uv, mat4 projection,
	mat4 inverse_projection, mat4 inverse_view
) {
	bool orthographic = abs(projection[2][3]) < 0.5;
	vec3 ray = orthographic ? vec3(0.0, 0.0, -1.0) : normalize(view_vertex);
	float ray_world_y = (inverse_view * vec4(ray, 0.0)).y;
	float drop = (inverse_view * vec4(view_vertex, 1.0)).y - bed_world_y;
	if (ray_world_y > -0.0001 || drop <= 0.0) {
		return 1.0e9;
	}
	vec4 clip = projection * vec4(view_vertex + ray * (drop / -ray_world_y), 1.0);
	float ndc_z = clip.z / clip.w;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	float raw_depth = ndc_z * 0.5 + 0.5;
	#else
	float raw_depth = ndc_z;
	#endif
	return _view_depth(screen_uv, raw_depth, inverse_projection);
}

// Kept identical to the sky shader projection so constellations reflected in
// the water occupy the same astronomical positions as the visible sky dome.
vec2 _equatorial_uv(vec3 direction) {
	float north = -direction.z;
	float east = direction.x;
	float up = direction.y;
	float sin_lat = sin(observer_latitude);
	float cos_lat = cos(observer_latitude);
	float sin_dec = clamp(up * sin_lat + north * cos_lat, -1.0, 1.0);
	float declination = asin(sin_dec);
	float hour_angle = atan(-east, up * cos_lat - north * sin_lat);
	float right_ascension = sidereal_angle - hour_angle;
	return vec2(fract(right_ascension / TAU), 0.5 - declination / PI);
}

// Bounded analytic sky-dome color for reflected rays. Matches the sky shader's
// gradient path (without marching clouds) so fresnel reflections track the dome.
float reflected_night_readability() {
	// Keep in sync with night_floor_readability() in sky_weather_3d.gdshader.
	float twilight = pow(smoothstep(-0.309017, 0.0, sun_direction.y), 0.7);
	return mix(0.16 + moon_visibility * 0.15, 1.0, twilight);
}

vec3 _sky_dome_gradient(vec3 dir) {
	float height = dir.y;
	float night_fill = reflected_night_readability();
	vec3 top = mix(mix(vec3(0.0015, 0.0020, 0.0030), night_top_color, night_fill), day_top_color, day_blend);
	vec3 horizon = mix(mix(vec3(0.0030, 0.0040, 0.0060), night_horizon_color, night_fill), day_horizon_color, day_blend);
	float sun_amount = max(dot(dir, normalize(sun_direction)), 0.0);
	horizon = mix(horizon, sunset_color, sunset_factor * pow(sun_amount, 2.0) * 0.8);
	float air_mass = 1.0 / max(height + 0.12, 0.12);
	float haze = 1.0 - exp(-air_mass * (0.10 + cloud_darken * 0.12));
	vec3 color = mix(top, horizon, haze);
	float forward_scatter = pow(sun_amount, 12.0) * (0.06 + haze * 0.20);
	color += mix(sun_reflection_color, sunset_color, sunset_factor)
		* forward_scatter * day_blend * (1.0 - cloud_darken * 0.8);
	color = mix(color, horizon * vec3(0.83, 0.87, 0.93), cloud_darken * 0.38);
	color = mix(color, horizon * 0.55, clamp(-height * 3.0, 0.0, 1.0));
	return color;
}

vec3 _sky_lut_radiance(vec3 dir) {
	return texture(sky_view_lut, atmosphere_sky_view_uv(dir, sun_direction, sky_lut_size)).rgb;
}

// WS-11 reflected sky. Same composition as sky_weather_3d.gdshader's LUT branch: exposure,
// tint and zenith-driven adaptation, the night gradient added by (1 - day_blend) so moonlit
// reflections survive after dark, and the small art sunset boost. Clouds are not in the LUT;
// the existing cloud_darken veil and the below-horizon darkening stay from the gradient path.
// Ported from Tidewater (MIT), see notice.code.tidewater (frame.horizonColor / sky sampling).
// R-1518: distant drops act as if at infinity, so the reflected bow is the sky bow
// mirrored about the horizon. Lit by the same sun hue as the dome's bow.
vec3 _with_reflected_rainbow(vec3 color, vec3 dir) {
	vec3 light = sun_reflection_color
		/ max(max(sun_reflection_color.r, max(sun_reflection_color.g, sun_reflection_color.b)), 1e-4);
	// rainbow_secondary is pushed but not passed: the committed sky_rainbow.gdshaderinc
	// has no secondary-bow argument yet (R-1547), and the sky dome calls it the same way.
	return rainbow_apply(color, dir, sun_direction, rainbow_strength * (1.0 - cloud_darken),
		rainbow_droplet, rainbow_curtain, light * rainbow_gain);
}

vec3 _sky_dome_reflection(vec3 dir) {
	if (!sky_lut_available) {
		return _with_reflected_rainbow(_sky_dome_gradient(dir), dir);
	}
	float height = dir.y;
	float sun_amount = max(dot(dir, normalize(sun_direction)), 0.0);
	float air_mass = 1.0 / max(height + 0.12, 0.12);
	float haze = 1.0 - exp(-air_mass * (0.10 + cloud_darken * 0.12));
	vec3 lut_zenith = _sky_lut_radiance(vec3(0.0, 1.0, 0.0));
	float zenith_luminance = dot(lut_zenith, vec3(0.2126, 0.7152, 0.0722));
	float adaptation = clamp(
		pow(sky_adaptation_reference / max(zenith_luminance, 1e-6), sky_adaptation),
		1.0, sky_adaptation_max_gain);
	vec3 art = sky_exposure * sky_tint * adaptation;
	// Same highlight shoulder as the dome, so the water does not mirror a brighter horizon.
	vec3 lut_horizon = sky_highlight_shoulder(
		_sky_lut_radiance(normalize(vec3(dir.x, 0.0, dir.z) + vec3(0.0, 0.0, 1e-5))) * art);
	float night = 1.0 - day_blend;
	float night_fill = reflected_night_readability();
	vec3 night_top = mix(vec3(0.0015, 0.0020, 0.0030), night_top_color, night_fill);
	vec3 night_horizon = mix(vec3(0.0030, 0.0040, 0.0060), night_horizon_color, night_fill);
	vec3 horizon = lut_horizon + night_horizon * night;
	vec3 color = sky_highlight_shoulder(_sky_lut_radiance(dir) * art)
		+ mix(night_top, night_horizon, haze) * night;
	color += sunset_color * sunset_factor * pow(sun_amount, 2.0) * haze * sunset_boost;
	color = mix(color, horizon * vec3(0.83, 0.87, 0.93), cloud_darken * 0.38);
	color = mix(color, horizon * 0.55, clamp(-height * 3.0, 0.0, 1.0));
	return _with_reflected_rainbow(color, dir);
}

// WS-06 catspaws and slicks: gain for the ripple cascade and the detail normal.
// Above 1 a gust roughens the water into a dark patch; below 1 a slick flattens it
// into a glassy streak that mirrors the sky. Lives in the wind frame and drifts
// downwind, so the patches cross the water with the wind.
float _sea_gust(vec2 world_xz) {
	vec2 p = _fft_to_wind(world_xz, _fft_wind_axis()) * gust_scale;
	float drift = ocean_time * GUST_DRIFT_CELLS_PER_WRAP / OCEAN_TIME_WRAP_SECONDS;
	float n = _noise_periodic_x(p - vec2(drift, 0.0), GUST_PERIOD_CELLS) * 0.7
		+ _noise_periodic_x(p * 3.0 - vec2(drift * 3.0, 0.0) + vec2(0.0, 7.3), GUST_PERIOD_CELLS * 3.0) * 0.3;
	float gust = smoothstep(0.52, 0.72, n);
	float slick = 1.0 - smoothstep(0.30, 0.46, n);
	return 1.0 + gust_amount * 0.4 * gust - slick_amount * 0.6 * slick;
}

// R-955 fetch/shelter from the WS-08 signed shore field (positive = water).
// Short upwind fetch or a tight basin cuts FFT amplitude and foam together.
float _fetch_shelter(vec2 world_xz) {
	if (shore_field_valid < 0.5) {
		return 1.0;
	}
	vec2 wind = wind_direction / max(length(wind_direction), 0.001);
	vec2 extent = max(shore_field_size, vec2(0.001));
	vec2 uv = (world_xz - shore_field_origin) / extent;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 1.0;
	}
	float local_dist = textureLod(shore_field, shore_atlas_uv(uv, 0.0), 0.0).r;
	vec2 uv_up = (world_xz - wind * 8.0 - shore_field_origin) / extent;
	float upwind_dist = 12.0;
	if (uv_up.x >= 0.0 && uv_up.y >= 0.0 && uv_up.x <= 1.0 && uv_up.y <= 1.0) {
		upwind_dist = textureLod(shore_field, shore_atlas_uv(uv_up, 0.0), 0.0).r;
	}
	float fetch = smoothstep(0.0, 12.0, upwind_dist);
	float basin = smoothstep(1.5, 12.0, local_dist);
	return mix(0.38, 1.0, min(fetch, basin));
}

vec2 _ripple_uv(vec2 world_xz) {
	return (world_xz - ripple_window.xy) / max(ripple_window.z, 0.001);
}

// 0 outside the window or with the sim off, 1 inside, fading near the window edge.
// WR-5 obstacle window lookup: same layout and edge fade as the ripple window.
vec2 _obstacle_uv(vec2 world_xz) {
	return (world_xz - obstacle_window.xy) / max(obstacle_window.z, 0.001);
}

float _obstacle_weight(vec2 uv) {
	vec2 edge = min(uv, vec2(1.0) - uv);
	return obstacle_window.w * smoothstep(0.0, RIPPLE_EDGE_FADE, min(edge.x, edge.y));
}

float _ripple_weight(vec2 uv) {
	vec2 edge = min(uv, vec2(1.0) - uv);
	return ripple_window.w * smoothstep(0.0, RIPPLE_EDGE_FADE, min(edge.x, edge.y));
}

// Rain rings: surface slope (d height / dx, dz) of expanding, fading drop rings. Each cell of
// each layer holds at most one drop per period, centred so its ring never leaves the cell;
// rain_ring_intensity sets the share of cells that fire.
vec2 _rain_ring_slope(vec2 world_xz, float time) {
	vec2 slope = vec2(0.0);
	for (int layer = 0; layer < 2; layer++) {
		float layer_f = float(layer);
		vec2 q = world_xz / RAIN_RING_CELL + vec2(0.5, 0.37) * layer_f;
		vec2 cell = floor(q);
		vec2 seed = cell + vec2(17.3, -41.9) * layer_f;
		float cycle = time / RAIN_RING_PERIOD + _hash(seed + vec2(-3.7, 2.9));
		// A fresh coin per cycle so a cell does not ring at the same spot every period.
		float cycle_index = floor(cycle);
		if (_hash(seed + vec2(cycle_index * 0.137, 8.1)) > rain_ring_intensity * 0.85) {
			continue;
		}
		float age = fract(cycle) * RAIN_RING_PERIOD / RAIN_RING_LIFE;
		if (age >= 1.0) {
			continue;
		}
		vec2 center = cell + 0.3 + 0.4 * vec2(
			_hash(seed + vec2(cycle_index, 1.3)), _hash(seed + vec2(5.3, cycle_index))
		);
		vec2 d = q - center;
		float r = length(d);
		float x = (r - age * RAIN_RING_MAX_RADIUS) / RAIN_RING_WIDTH;
		float fade = (1.0 - age) * (1.0 - age);
		// Derivative of a Gaussian ring profile along the radius.
		float dh = -2.0 * x * exp(-x * x) * fade;
		slope += dh * d / max(r, 0.0001);
	}
	return slope * RAIN_RING_SLOPE;
}

// WS-02 specular terms (Tidewater water material). a2 is GGX alpha squared.
float _d_ggx(float n_dot_h, float a2) {
	float d = n_dot_h * n_dot_h * (a2 - 1.0) + 1.0;
	return a2 / (PI * d * d);
}

// Height-correlated Smith visibility; already divided by 4 NdL NdV.
float _v_smith_ggx_correlated(float n_dot_l, float n_dot_v, float a2) {
	float ggx_v = n_dot_l * sqrt(n_dot_v * n_dot_v * (1.0 - a2) + a2);
	float ggx_l = n_dot_v * sqrt(n_dot_l * n_dot_l * (1.0 - a2) + a2);
	return 0.5 / max(ggx_v + ggx_l, 1e-5);
}

// Exact unpolarised dielectric Fresnel. WHY not Schlick: Schlick overshoots at
// the grazing angles the gameplay camera sees most of the sea from.
float _fresnel_dielectric(float cos_theta, float ior) {
	float c = clamp(cos_theta, 0.0, 1.0);
	float g = sqrt(ior * ior - 1.0 + c * c);
	float a = (g - c) / (g + c);
	float b = (c * (g + c) - 1.0) / (c * (g - c) + 1.0);
	return 0.5 * a * a * (1.0 + b * b);
}

// One continuous city surface: offshore waves rise into a finite-depth bore
// over the sand. Coverage is resolved in fragment from this same shore phase.
// Returns height and its partial derivative with respect to bed height.
vec2 _city_runup_profile(ShoreState shore, float bed_y, float ocean_y) {
	float front = shore.front_distance - shore.distance;
	float active = smoothstep(0.001, 0.04, front);
	float edge = smoothstep(0.0, 0.12, shore.front_distance);
	float roller_coordinate = (shore.front_distance - 0.28) / 0.32;
	// The raised roller belongs to the uprush bore. On the backwash the front is a
	// feather-thin retreating film; keeping the roller there stood a glassy wall
	// of water along the whole beach.
	float roller = exp(-roller_coordinate * roller_coordinate)
		* mix(1.0, 0.15, smoothstep(0.0, 0.25, shore.backwash));
	float thickness = (shore.sheet_thickness * 3.0
		+ roller * mix(0.10, 0.42, shore_sea_state)) * active * edge;
	float u = clamp((bed_y + 0.45) / 0.57, 0.0, 1.0);
	float shore_blend = u * u * (3.0 - 2.0 * u) * shore.beach * shore.valid;
	float bed_surface = bed_y + 0.018 + thickness;
	// Smooth maximum keeps the terrain floor while removing the reflection hinge.
	float merge = max(0.12 - abs(ocean_y - bed_surface), 0.0) / 0.12;
	float joined = max(ocean_y, bed_surface) + merge * merge * 0.03;
	float height = mix(ocean_y, joined, shore_blend);
	// All inland vertices need the floor, including ones beyond the current
	// front: otherwise a straddling triangle pulls its wet portion under sand.
	if (height < bed_y + 0.018) {
		return vec2(bed_y + 0.018, 1.0);
	}
	// Chain rule allows replacing only the terrain's flat triangle gradient
	// with its interpolated smooth normal. Wave/front slopes remain analytic.
	float dw = 6.0 * u * (1.0 - u) / 0.57 * shore.beach * shore.valid;
	float bed_weight = shore_blend * clamp(0.5 + (bed_surface - ocean_y) / 0.24, 0.0, 1.0)
		+ dw * (joined - ocean_y);
	return vec2(height, bed_weight);
}

float _city_runup_height(ShoreState shore, float bed_y, float ocean_y) {
	return _city_runup_profile(shore, bed_y, ocean_y).x;
}

// WR-2: city foam structure, attached to the water. The input is a Lagrangian
// (rest) coordinate: the FFT vertex displacement already carries it with the
// surface, and the surf passes it pre-shifted by the swash excursion, so foam
// rides crests and surges in and out with each breaker. No time term here: the
// old version scrolled every layer downwind at a fixed speed, which read as a
// global foam sheet sliding over the sea. x = bubble-cell structure (0..1,
// clusters -> cells -> grain) for _foam_dissolve, y = wind-aligned streak.
vec2 _city_foam_cells(vec2 xz) {
	vec2 p = _fft_to_wind(xz, _fft_wind_axis());
	vec2 rotated = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p;
	// Domain warp from the smooth speckle channel at two scales: lace edges tear
	// irregularly instead of following the tile's round Worley bubble rims.
	vec2 warp = vec2(
		texture(foam_tile, p * 0.0041 + vec2(0.41, 0.09)).g,
		texture(foam_tile, rotated * 0.0047 + vec2(0.83, 0.27)).g
	) - 0.5;
	// Value-noise patches (metres, then decimetres) carry the shape; the bubble
	// cells only add detail, so rims never dominate as rings.
	float patches = texture(foam_tile, p * 0.0043 + warp * 0.035).g;
	float lacework = texture(foam_tile, rotated * 0.011 + vec2(0.23, 0.61) + warp * 0.06).g;
	// WR-3 tier: lower tiers skip the finest layers (one fetch each) and
	// renormalise the weights, so the structure keeps its spread and still
	// dissolves into lace (a constant stand-in flattened it into white blobs).
	float structure = patches * 0.36 + lacework * 0.26;
	float weight = 0.62;
	if (city_foam_layers > 2) {
		structure += texture(foam_tile, rotated * 0.12 + vec2(0.31, 0.73) + warp * 0.55).r * 0.24;
		weight += 0.24;
	}
	if (city_foam_layers > 3) {
		structure += texture(foam_tile, p * 0.52 + vec2(0.67, 0.19) + warp * 1.2).r * 0.14;
		weight += 0.14;
	}
	structure /= weight;
	// Streaks meander with the same warp instead of running as straight rays.
	float streak = texture(foam_tile, p * foam_tile_scale + vec2(0.0, warp.x * 0.12)).b;
	return vec2(clamp((structure - 0.2) * 1.75, 0.0, 1.0), streak);
}

// WR-2: foam that ages breaks into lace instead of fading as a sheet. Coverage c
// (0..1) keeps only the brightest part of the structure, so dying foam shrinks
// to bubble rims and holes open in it (the industry "foam dissolve" threshold).
// The edge widens with the pixel footprint of the structure (fwidth), so distant
// or grazing foam averages to grey coverage instead of moire rims.
float _foam_dissolve(float structure, float c) {
	float k = clamp(c, 0.0, 1.0);
	float soft = 0.12 + min(fwidth(structure) * 1.5, 0.5);
	return smoothstep(1.0 - k - soft * 0.5, 1.0 - k + soft * 0.5, structure) * step(0.001, k);
}

// WR-3 LOD field texel at lattice vertex i; outside the map: no water, full floor.
vec4 _sea_lod_texel(ivec2 i) {
	ivec2 size = textureSize(sea_depth_map, 0);
	if (i.x < 0 || i.y < 0 || i.x >= size.x || i.y >= size.y) {
		return vec4(0.0, 0.0, 1.0, 0.0);
	}
	return texelFetch(sea_depth_map, i, 0);
}

// Manual bilinear of the lattice field. Exact (no filtering hardware) so a lattice
// vertex reads its texel bit for bit, like the static meshes' own attributes.
vec4 _sea_lod_field(vec2 xz) {
	vec2 u = (xz - sea_lod_lattice.xy) / sea_lod_lattice.z;
	vec2 i0 = floor(u);
	vec2 f = u - i0;
	ivec2 b = ivec2(i0);
	vec4 row0 = mix(_sea_lod_texel(b), _sea_lod_texel(b + ivec2(1, 0)), f.x);
	vec4 row1 = mix(_sea_lod_texel(b + ivec2(0, 1)), _sea_lod_texel(b + ivec2(1, 1)), f.x);
	return mix(row0, row1, f.y);
}

// Continuous ring level at distance d: ring L ends at range * 2^L and morphs into
// ring L+1 over its outer SEA_LOD_MORPH share (CDLOD morph band).
float _sea_lod_ring(float d) {
	float range = sea_lod_rings.y;
	float t = d / range;
	float level = t < 1.0 ? 0.0 : floor(log2(t)) + 1.0;
	float outer = range * exp2(level);
	float inner = level < 0.5 ? 0.0 : outer * 0.5;
	float w = SEA_LOD_MORPH * (outer - inner);
	return min(level + clamp((d - outer + w) / w, 0.0, 1.0), sea_lod_rings.w);
}

float _sea_lod_distance_level(vec2 xz) {
	return _sea_lod_ring(length(vec3(xz.x, 0.0, xz.y) - sea_lod_eye));
}

// 4 m lattice cell size in base-spacing units (a power of two).
float _sea_lod_cell_span() {
	return sea_lod_lattice.z / sea_lod_rings.x;
}

// Mesh level wanted at lattice point q (base-spacing units): the distance level,
// raised to the 4 m shore level next to the static surf skirt (shared edges) and
// capped near unowned cells so no coarse triangle spans one (A channel).
float _sea_lod_level_at(vec2 q, bool on_cells) {
	vec2 xz = sea_lod_lattice.xy + q * sea_lod_rings.x;
	float shore = sea_lod_rings.z;
	float level = max(_sea_lod_distance_level(xz), shore * _sea_lod_field(xz).b);
	float cap = shore;
	if (on_cells) {
		// q is an exact lattice vertex here; index it from q, not from world xz,
		// so float rounding never reads the neighbouring texel.
		float a = _sea_lod_texel(ivec2(round(q / _sea_lod_cell_span()))).a;
		cap = shore + a - SEA_LOD_DRAWN * step(SEA_LOD_DRAWN - 0.5, a);
	}
	return min(level, min(cap, sea_lod_rings.w));
}

// Ring node vertex. INSTANCE_CUSTOM = (node x, node z in node sizes, level, 2^level),
// VERTEX.xz = grid index. Everything runs on exact integer lattice coordinates, and
// step k reads its level at the vertex snapped to step k's own lattice: a fine
// vertex on a coarse neighbour's edge then repeats the neighbour's arithmetic bit
// for bit, so rings meet without cracks. Floor snapping keeps the static grid's
// diagonal, so a fully morphed quad equals the coarse quad.
vec3 _sea_lod_vertex(vec3 local, vec4 node, out float mesh_level, out vec2 lattice_g) {
	float span = node.w;
	vec2 g0 = (node.xy * SEA_LOD_NODE_QUADS + local.xz) * span;
	vec2 g = g0;
	float level = node.z;
	float cell_span = _sea_lod_cell_span();
	float previous = 1.0;
	mesh_level = level;
	for (int k = 0; k < 16; k++) {
		if (level + float(k) >= sea_lod_rings.w) {
			break;
		}
		vec2 q = g0 - mod(g0, span);
		float m = clamp(_sea_lod_level_at(q, span >= cell_span) - (level + float(k)), 0.0, 1.0);
		m = min(m >= SEA_LOD_SNAP ? 1.0 : m, previous);
		if (m <= 0.0) {
			break;
		}
		g = mix(g, g0 - mod(g0, span * 2.0), m);
		mesh_level += m;
		previous = m;
		span *= 2.0;
	}
	lattice_g = g;
	vec2 xz = sea_lod_lattice.xy + g * sea_lod_rings.x;
	return vec3(xz.x, 0.0, xz.y);
}

// Displacement weights (C0, C1) from the coarser of the mesh spacing and the
// distance spacing. Band and skirt pass one 4 m cell: no C1, C0 by distance only.
vec2 _sea_lod_weights(vec2 xz, float mesh_spacing) {
	float e = max(mesh_spacing, sea_lod_rings.x * exp2(_sea_lod_distance_level(xz)));
	vec4 s = SEA_LOD_WEIGHT_SPACING;
	return vec2(1.0 - smoothstep(s.z, s.w, e), sea_lod_c1 * (1.0 - smoothstep(s.x, s.y, e)));
}

// Drawn flags of the cells whose closure holds lattice point g (base units),
// stored by cell parity.
vec4 _sea_lod_cells(vec2 g) {
	vec2 u = g / _sea_lod_cell_span();
	vec2 lo = ceil(u) - 1.0;
	vec2 hi = floor(u);
	vec4 cells = vec4(1.0);
	for (int n = 0; n < 4; n++) {
		ivec2 c = ivec2(int((n & 1) == 0 ? lo.x : hi.x), int(n < 2 ? lo.y : hi.y));
		float drawn = step(SEA_LOD_DRAWN - 0.5, _sea_lod_texel(c).a);
		int parity = (c.x & 1) + 2 * (c.y & 1);
		if (parity == 0) {
			cells.x = drawn;
		} else if (parity == 1) {
			cells.y = drawn;
		} else if (parity == 2) {
			cells.z = drawn;
		} else {
			cells.w = drawn;
		}
	}
	return cells;
}

// Whether a ring pixel at undisplaced xz belongs to a ring-drawn cell. The pixel's
// own cell is exact (all three vertices of a ring triangle store it under its
// parity); within SEA_LOD_EDGE of a cell edge the neighbour's parity counts too,
// so an edge pixel is never dropped by rounding next to a drawn neighbour. A
// sliver drawn over an undrawn neighbour lies on the shared edge, where both
// surfaces have the same vertices.
const float SEA_LOD_EDGE = 0.004;
bool _sea_lod_pixel_drawn(vec2 xz, vec4 cells) {
	vec2 u = (xz - sea_lod_lattice.xy) / sea_lod_lattice.z;
	vec2 lo = floor(u - SEA_LOD_EDGE);
	vec2 hi = floor(u + SEA_LOD_EDGE);
	float drawn = 0.0;
	for (int n = 0; n < 4; n++) {
		ivec2 c = ivec2(int((n & 1) == 0 ? lo.x : hi.x), int(n < 2 ? lo.y : hi.y));
		int parity = (c.x & 1) + 2 * (c.y & 1);
		drawn = max(drawn, parity == 0 ? cells.x : (parity == 1 ? cells.y : (parity == 2 ? cells.z : cells.w)));
	}
	return drawn > 0.5;
}

void vertex() {
	vec3 undisplaced_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	sea_ground_y = (MODEL_MATRIX * vec4(VERTEX.x, UV2.y, VERTEX.z, 1.0)).y;
	// WR-3: band and skirt count as one 4 m cell (no C1); rings use their morph.
	float lod_mesh_spacing = sea_lod_lattice.z;
	sea_lod_cells = vec4(1.0);
	if (sea_lod) {
		float mesh_level;
		vec2 lattice_g;
		VERTEX = _sea_lod_vertex(VERTEX, INSTANCE_CUSTOM, mesh_level, lattice_g);
		// Ring instances carry identity transforms, so VERTEX is already world space.
		undisplaced_world = VERTEX;
		sea_ground_y = _sea_lod_field(VERTEX.xz).g;
		lod_mesh_spacing = sea_lod_rings.x * exp2(mesh_level);
		sea_lod_cells = _sea_lod_cells(lattice_g);
	}
	bool lod_active = sea_physical_depth && sea_lod_lattice.w > 0.5;
	wave_sample_xz = undisplaced_world.xz;
	sea_bed_slope = -NORMAL.xz / max(NORMAL.y, 0.001);
	// Cells project along the sun only; once the directional light has handed
	// over to the moon the gate is 0 and nothing shades the moon path.
	cloud_cell_shadow = cells_ground_shadow(undisplaced_world, cloud_sun_dir, cloud_noise_tex, 1.0)
		* 0.85 * smoothstep(SUN_LIGHT_HANDOFF_Y, 0.0, cloud_sun_dir.y);
	sea_depth_t = -1.0;
	if (sea_depth_blend > 0.5) {
		vec2 sea_uv = (undisplaced_world.xz - sea_depth_rect.xy) / max(sea_depth_rect.zw, vec2(0.001));
		if (all(greaterThanEqual(sea_uv, vec2(0.0))) && all(lessThanEqual(sea_uv, vec2(1.0)))) {
			float basin = textureLod(sea_depth_map, sea_uv, 0.0).r;
			if (lod_active) {
				// WR-3: the LOD field holds depth per lattice vertex; read it exactly
				// so rings, skirt and band pick the same wave parameters.
				basin = _sea_lod_field(undisplaced_world.xz).r;
			}
			sea_depth_t = smoothstep(sea_depth_range.x, sea_depth_range.y, basin);
		}
	}
	// Wave parameters: the depth blend inside the map, this family's own uniforms outside.
	vec4 wave_params = vec4(choppiness, fft_geometry_scale, standing_wave_ratio, wave_height);
	if (sea_depth_t >= 0.0) {
		wave_params = mix(sea_wave_shallow, sea_wave_deep, sea_depth_t);
	}
	shore_factor = clamp(COLOR.r, 0.0, 1.0);
	if (lod_active) {
		// WR-3: the same depth hint as COLOR.r, from the float bed every city sea
		// mesh shares, so rings, skirt and band stay bit-identical on shared vertices.
		shore_factor = clamp(-sea_ground_y / CITY_SHORE_DEPTH, 0.0, 1.0);
	}
	flat_bed_flag = step(0.5, UV2.x);
	flat_bed_world_y = (MODEL_MATRIX * vec4(VERTEX.x, UV2.y, VERTEX.z, 1.0)).y;
	// Processor functions cannot return early; the sheet restores this at the end.
	vec3 rest_vertex = VERTEX;
	// Advect the wave field downstream so ripples travel along the current.
	vec2 flow_advection = flow_direction * (flow_strength * TIME * wave_speed * RIVER_ADVECT_SPEED);
	vec3 displacement = vec3(0.0);
	vec3 normal_terms = vec3(0.0);
	if (use_fft) {
		// FFT replaces wave_height; wave_height stays the Gerstner amplitude only.
		// Foam is resampled in fragment(): GL vertex atlas alpha is not trusted.
		vec3 unused_foam;
		// WR-1: the city's 4 m open-sea grid cannot carry C1 (4-16 m waves); it
		// stays in the per-pixel normal. District grids keep their displacement.
		// WR-3: with the LOD, C1 returns where a ring is fine enough and far rings
		// fall back to normal-only (_sea_lod_weights).
		vec2 lod_weights = vec2(1.0, sea_physical_depth ? CITY_C1_GEOMETRY : 1.0);
		if (lod_active) {
			lod_weights = _sea_lod_weights(undisplaced_world.xz, lod_mesh_spacing);
		}
		displacement = _fft_displacement_foam_with_c1(
			wave_sample_xz, unused_foam, wave_params.x, wave_params.z, wave_params.y,
			lod_weights.y
		) * lod_weights.x;
		// Lee of a quay or headland: reuse the WS-08 signed shore field as fetch.
		displacement *= _fetch_shelter(wave_sample_xz);
	} else {
		_water_field(wave_sample_xz - flow_advection, TIME * wave_speed, displacement, normal_terms);
		displacement *= wave_params.w;
		// River bed sits only WATER_RECESS below the surface: full sea-style troughs
		// would cut the water into bands and expose the bed. The ripple read comes
		// from the shading normal, so the mesh itself only needs to ripple gently.
		if (flow_strength > 0.001) {
			displacement *= RIVER_DISPLACEMENT_SCALE;
		}
	}
	// Low tide withdraws the clipped coastal edge instead of requiring a second
	// authored shoreline mesh. High tide reaches the original maximum contour.
	// The fragment stage clips the retreat band. Vertices rise and also shift
	// horizontally so crests peak instead of staying a displaced sine sheet.
	// Keep clipped patch seams pinned, but let the crest rise almost all the way
	// into the shallows. The old broad fade erased waves before they reached land.
	float displacement_fade = smoothstep(0.0, 0.16, shore_factor);
	float shoaling = mix(1.32, 1.0, smoothstep(0.0, 0.65, shore_factor));
	displacement *= displacement_fade * shoaling;
	if (use_fft) {
		// WHY: the recessed bed sits only WATER_SURFACE_LIFT (0.006 units) below
		// the rest surface, so any trough exposes it. Troughs ease into a floor
		// just above the bed while crests keep their full height: broad troughs,
		// sharp crests. The shading normal still carries the full trough slope.
		// WS-05 hull sampling must apply the same floor to stay seated.
		if (sea_physical_depth) {
			// WR-1: the city bed lies metres below; troughs keep their depth.
			float room = undisplaced_world.y + tide_height * tide_level
				- (sea_ground_y + CITY_TROUGH_CLEARANCE);
			// WR-5: reflected and diffracted waves from rocks and walls ride on the
			// swell before the bed floor, so a trough beside a boulder still stops
			// above the bed (and below the rock top, which then pokes through).
			if (obstacle_window.w > 0.5) {
				vec2 obstacle_uv = _obstacle_uv(wave_sample_xz);
				displacement.y += textureLod(obstacle_state, obstacle_uv, 0.0).r
					* _obstacle_weight(obstacle_uv);
			}
			displacement.y = _fft_bed_trough(displacement.y, room);
		} else if (displacement.y < 0.0) {
			displacement.y = -FFT_TROUGH_FLOOR * (1.0 - exp(displacement.y / FFT_TROUGH_FLOOR));
		}
	}
	if (ripple_window.w > 0.5) {
		vec2 ripple_uv = _ripple_uv(wave_sample_xz);
		float ripple_h = textureLod(ripple_state, ripple_uv, 0.0).r * ripple_vertex_amplitude;
		displacement.y += max(ripple_h * _ripple_weight(ripple_uv), 0.0);
	}
	if (shore_field_valid > 0.5 && shore_strength > 0.0) {
		ShoreState shore = shore_state(undisplaced_world.xz, ocean_time, shore_sea());
		// Crests and the wall slosh only rise: a trough would expose the recessed
		// bed, so the slosh reads as water climbing the wall and falling back to
		// rest. The crest top curls towards land.
		float shore_lift = (shore.height + max(shore.slosh, 0.0)) * shore_geometry_scale;
		displacement.y += shore_lift * shore.valid;
		displacement.xz += shore.to_land * shore.curl * shore_geometry_scale * shore.valid;
		if (sea_physical_depth) {
			// Pin horizontal motion before it reaches the bank, not at a mesh seam.
			displacement.xz *= 1.0 - smoothstep(-1.0, -0.12, sea_ground_y);
			float ocean_y = undisplaced_world.y + tide_height * tide_level + displacement.y;
			displacement.y = _city_runup_height(shore, sea_ground_y, ocean_y)
				- undisplaced_world.y - tide_height * tide_level;
		}
	}
	invalid_surface_vertex = 0.0;
	if (debug_surface_validity && (any(isnan(displacement)) || any(isinf(displacement)))) {
		// A NaN vertex can disappear before fragment diagnostics see it.
		// Only in the capture diagnostic, restore it and flag the triangle.
		invalid_surface_vertex = 1.0;
		displacement = vec3(0.0);
	}
	VERTEX.x += displacement.x;
	VERTEX.y += tide_height * tide_level + displacement.y;
	VERTEX.z += displacement.z;
	water_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (swash_sheet) {
		// The film lies on the sand; the ocean displacement must not lift it.
		VERTEX = rest_vertex;
		water_world_position = undisplaced_world;
	}
}

void fragment() {
	// Sea depth blend (see sea_depth_map): shallow and deep sea share one look that follows
	// the rendered basin depth, so the drop-off reads as a gradient, not a cell line.
	float w_optical_depth = optical_depth;
	float w_depth_absorption = depth_absorption;
	float w_tide_optical_depth = tide_optical_depth;
	vec3 w_shallow_color = shallow_color;
	vec3 w_deep_color = deep_color;
	vec3 w_highlight_color = highlight_color;
	vec3 w_foam_color = foam_color;
	// A vertex outside the map rect drags the interpolated value below zero near the edge;
	// treat any negative as "off" so neighbour previews keep their per-family look.
	if (sea_depth_t >= 0.0) {
		{
			float sea_t = clamp(sea_depth_t, 0.0, 1.0);
			vec4 look = mix(sea_look_shallow, sea_look_deep, sea_t);
			w_optical_depth = look.x;
			w_depth_absorption = look.y;
			w_tide_optical_depth = look.z;
			w_shallow_color = mix(sea_shallow_color_shallow, sea_shallow_color_deep, sea_t);
			w_deep_color = mix(sea_deep_color_shallow, sea_deep_color_deep, sea_t);
			w_highlight_color = mix(sea_highlight_color_shallow, sea_highlight_color_deep, sea_t);
			w_foam_color = mix(sea_foam_color_shallow, sea_foam_color_deep, sea_t);
		}
	}
	// Screen size of one rain-ring cell; derivatives stay in uniform control flow here.
	float rain_cell_px = RAIN_RING_CELL / max(length(fwidth(water_world_position.xz)), 0.00001);
	// WR-3: ring nodes cover whole 4 m cells; cells owned by the static skirt and
	// surf band, or by land, are cut per pixel (after the derivative above).
	if (sea_lod && !_sea_lod_pixel_drawn(wave_sample_xz, sea_lod_cells)) {
		discard;
	}
	// WS-06b: per-pixel baked foam. Do not read a vertex varying; GL Compatibility
	// vertex fetches from the compressed disp arrays often drop the alpha.
	vec3 fft_foam = vec3(0.0);
	// WS-08 beach film. Processor functions cannot return early, so the film is
	// shaded into locals here and replaces the ocean outputs at the end.
	ShoreState sheet;
	vec3 sheet_normal = vec3(0.0, 0.0, 1.0);
	vec3 sheet_albedo = vec3(0.0);
	float sheet_alpha = 0.0;
	// WS-02: 0.22 is GGX alpha ~0.05, a wet film just rougher than calm sea.
	float sheet_roughness = 0.22;
	float sheet_foam = 0.0;
	if (swash_sheet) {
		// WS-08 beach film: exists only where the analytic swash currently covers
		// the sand. It is a thin, mostly transparent layer: the wet sand below is
		// already darkened by the terrain pass, so the film adds the extinction
		// tint, a strong Fresnel sky reflection, the sun glint and the front foam.
		sheet = shore_state(water_world_position.xz, ocean_time, shore_sea());
		if (sheet.valid * sheet.beach < 0.01 || sheet.wet < 0.5) {
			discard;
		}
		vec3 film_normal = normalize(mix(
			vec3(0.0, 1.0, 0.0), _water_detail_normal(water_world_position.xz, TIME * wave_speed), 0.35
		));
		vec3 film_view_normal = normalize((VIEW_MATRIX * vec4(film_normal, 0.0)).xyz);
		sheet_normal = film_view_normal;
		float film_facing = clamp(dot(film_view_normal, normalize(VIEW)), 0.0, 1.0);
		float film_fresnel = 0.02 + 0.98 * pow(1.0 - film_facing, 5.0);
		vec3 film_world_view = normalize((INV_VIEW_MATRIX * vec4(normalize(VIEW), 0.0)).xyz);
		vec3 film_sky_ray = normalize(reflect(-film_world_view, film_normal));
		vec3 film_sky = _sky_dome_reflection(film_sky_ray) * smoothstep(-0.01, 0.06, film_sky_ray.y);
		// Spectral extinction over the sheet thickness (metres -> world units).
		vec3 film_transmission = exp(
			-(sheet.sheet_thickness / SHORE_METERS_PER_UNIT) * w_depth_absorption * vec3(1.28, 0.72, 0.40) * 6.0
		);
		vec3 film_color = mix(w_shallow_color * 0.55, sand_bed_color * 0.7, film_transmission);
		film_color = mix(film_color, film_sky, clamp(0.30 + film_fresnel * 0.9, 0.0, 0.9));
		// WS-02: the film's sun glint comes from light() like the sea's.
		// Meniscus: the last SHORE_MENISCUS units bend down to the sand, so the edge
		// fades and darkens instead of ending on a cut polygon line.
		float meniscus = smoothstep(0.0, SHORE_MENISCUS, sheet.front_distance);
		film_color *= mix(0.78, 1.0, meniscus);
		float film_alpha = clamp(0.28 + sheet.sheet_thickness * 9.0 + film_fresnel * 0.45, 0.0, 0.8);
		film_alpha *= meniscus;
		float film_foam = clamp(sheet.front_foam * 1.2, 0.0, 1.0);
		film_foam *= smoothstep(0.0, 0.03, sheet.front_distance);
		sheet_albedo = mix(film_color, mix(w_foam_color, vec3(0.93, 0.95, 0.94), 0.6), film_foam);
		sheet_alpha = max(film_alpha, film_foam * 0.92);
		sheet_roughness = mix(0.22, 0.6, film_foam);
		sheet_foam = film_foam;
	}
	float tide_coverage = tide_shore_retreat * max(-tide_level, 0.0);
	if (!sea_physical_depth && shore_factor < tide_coverage) {
		discard;
	}
	// WS-08: one shore evaluation per fragment feeds the surf turbidity and the
	// bore / wall foam below. Rivers (shore_strength 0) and maps without a sea
	// shoreline keep the previous breaker bands.
	bool shore_live = shore_field_valid > 0.5 && shore_strength > 0.0;
	float swash_bore = 0.0;
	ShoreState shore_now;
	float city_coverage = 1.0;
	// WR-9: share of the run-up film left over shingle (drained, pebbles poking through).
	float runup_drain = 1.0;
	if (shore_live) {
		shore_now = shore_state(wave_sample_xz, ocean_time, shore_sea());
		float still_water = tide_height * tide_level;
		if (sea_physical_depth && sea_ground_y > still_water - CITY_RUNDOWN_BED) {
			// Above the still-water line the bed height owns coverage; a filtered
			// distance-field zero must never cut a dry crack through it. Just
			// below it, where waves reach, the backwash rundown may uncover the
			// bed (shore_state front_distance < 0) until the next bore.
			// Below it, only while the rundown is active: otherwise the bed stays
			// covered, so the filtered field zero cannot open a standing crack.
			bool above_still = sea_ground_y > still_water + 0.002;
			float front = shore_now.front_distance - shore_now.distance;
			bool runs_up = shore_now.valid * shore_now.beach >= 0.01;
			// Ragged, per-wave tip width: the film thins out over 0.12..0.67 m
			// instead of ending in one crisp line along the beach.
			float tip = runs_up
				? smoothstep(0.0, shore_now.edge_feather, shore_now.front_distance) : 0.0;
			if (above_still) {
				if (!runs_up || front < 0.001 || shore_now.front_distance <= 0.0) {
					discard;
				}
				city_coverage = tip;
			} else if (runs_up) {
				city_coverage = mix(1.0, tip, smoothstep(0.0, 0.05, shore_now.rundown));
				if (city_coverage < 0.001) {
					discard;
				}
			}
		}
	}
	// Sample the undisplaced XZ. Evaluating Gerstner at the chopped position
	// feeds the displacement back into itself and swims the normal off the crest.
	vec2 flow_advection = flow_direction * (flow_strength * TIME * wave_speed * RIVER_ADVECT_SPEED);
	vec3 displacement = vec3(0.0);
	vec3 normal_terms = vec3(0.0);
	vec3 world_normal = vec3(0.0, 1.0, 0.0);
	// Crest fold feeding the crest SSS glow: Gerstner normal_terms.y on the
	// fallback path, the FFT Jacobian 1 - (1 + Jx)(1 + Jz) on the FFT path.
	float crest_term = 0.0;
	// Pixel footprint in world units, taken in uniform control flow so the FFT
	// LOD and cascade fade stay valid inside the branch below.
	vec2 pixel_footprint = fwidth(wave_sample_xz);
	// WS-06 gust/slick gain; 1 on the Gerstner fallback (rivers, ponds).
	float sea_gust = 1.0;
	if (use_fft) {
		sea_gust = _sea_gust(wave_sample_xz);
		world_normal = _fft_normal_gust(
			wave_sample_xz, max(pixel_footprint.x, pixel_footprint.y), sea_gust, crest_term
		);
	} else {
		_water_field(wave_sample_xz - flow_advection, TIME * wave_speed, displacement, normal_terms);
		float crest_lift = max(1.0 - normal_terms.y * wave_height, 0.15);
		world_normal = normalize(vec3(
			-normal_terms.x * wave_height,
			crest_lift,
			-normal_terms.z * wave_height
		));
		crest_term = normal_terms.y;
	}
	// Layer two independently scrolling detail normals over the broad wave normal.
	// The low-sun relief clamp still applies below, preventing sharp glint bands at
	// sunrise while preserving the small-scale broken reflection at daytime angles.
	vec3 detail_normal = _water_detail_normal(water_world_position.xz, TIME * wave_speed);
	world_normal = normalize(mix(world_normal, detail_normal, clamp(detail_normal_strength * sea_gust, 0.0, 1.0)));
	// WS-15: ripple slopes from central differences, added on top of the FFT and detail
	// normals so rings bend reflections and glints. Aeration feeds the foam mask below.
	float ripple_aeration = 0.0;
	float ripple_slope_length = 0.0;
	if (ripple_window.w > 0.5) {
		vec2 ripple_uv = _ripple_uv(wave_sample_xz);
		float ripple_weight = _ripple_weight(ripple_uv);
		vec2 ripple_du = vec2(1.0 / max(ripple_texel_count, 1.0), 0.0);
		float ripple_hx = textureLod(ripple_state, ripple_uv + ripple_du.xy, 0.0).r
			- textureLod(ripple_state, ripple_uv - ripple_du.xy, 0.0).r;
		float ripple_hz = textureLod(ripple_state, ripple_uv + ripple_du.yx, 0.0).r
			- textureLod(ripple_state, ripple_uv - ripple_du.yx, 0.0).r;
		vec2 ripple_slope = vec2(ripple_hx, ripple_hz) * (0.5 * ripple_normal_strength * ripple_weight);
		// A hull crest can be several times a raindrop ring; unbounded slopes lay the normal
		// flat and mirror the dark lower hemisphere as black streaks.
		ripple_slope /= max(1.0, length(ripple_slope) / RIPPLE_MAX_SLOPE);
		world_normal = normalize(world_normal + vec3(-ripple_slope.x, 0.0, -ripple_slope.y));
		ripple_slope_length = length(ripple_slope);
		ripple_aeration = textureLod(ripple_state, ripple_uv, 0.0).b * ripple_weight;
	}
	// WR-5: the obstacle field's slopes bend the normal like the ripples; its impact foam
	// joins the surf foam below.
	float obstacle_foam = 0.0;
	if (sea_physical_depth && obstacle_window.w > 0.5) {
		vec2 obstacle_uv = _obstacle_uv(wave_sample_xz);
		float obstacle_weight = _obstacle_weight(obstacle_uv);
		float obstacle_du = 1.0 / max(obstacle_texel_count, 1.0);
		float texel_world = obstacle_window.z * obstacle_du;
		vec2 obstacle_slope = vec2(
			textureLod(obstacle_state, obstacle_uv + vec2(obstacle_du, 0.0), 0.0).r
				- textureLod(obstacle_state, obstacle_uv - vec2(obstacle_du, 0.0), 0.0).r,
			textureLod(obstacle_state, obstacle_uv + vec2(0.0, obstacle_du), 0.0).r
				- textureLod(obstacle_state, obstacle_uv - vec2(0.0, obstacle_du), 0.0).r
		) * (0.5 / max(texel_world, 0.001) * obstacle_weight);
		obstacle_slope /= max(1.0, length(obstacle_slope) / OBSTACLE_MAX_SLOPE);
		world_normal = normalize(world_normal + vec3(-obstacle_slope.x, 0.0, -obstacle_slope.y));
		obstacle_foam = textureLod(obstacle_state, obstacle_uv, 0.0).b * obstacle_weight
			* obstacle_foam_strength;
	}
	// Rain rings fade out before their cells shrink to a few pixels (distance, top-down
	// zoom), where the lattice would otherwise alias into a moire overlay.
	float rain_ring_fade = rain_ring_intensity > 0.001
		? smoothstep(RAIN_RING_MIN_CELL_PX, RAIN_RING_FULL_CELL_PX, rain_cell_px)
		: 0.0;
	if (rain_ring_fade > 0.001) {
		vec2 rain_slope = _rain_ring_slope(water_world_position.xz, TIME) * rain_ring_fade;
		world_normal = normalize(world_normal + vec3(-rain_slope.x, 0.0, -rain_slope.y));
		ripple_slope_length = max(ripple_slope_length, length(rain_slope));
	}
	if (sea_physical_depth && shore_live) {
		float ocean_crest = tide_height * tide_level
			+ (shore_now.height + max(shore_now.slosh, 0.0)) * shore_geometry_scale * shore_now.valid;
		vec2 runup = _city_runup_profile(shore_now, sea_ground_y, ocean_crest);
		// WHY not dFdx/dFdy of runup.x: the height comes from the filtered shore
		// field, which steps slightly between pixels when a texel is magnified over
		// many of them. Screen derivatives turn those steps into slope spikes, and
		// up close (Retina, low camera) the bore face and incoming crests showed a
		// moire of dashes and zebra stripes. A world-space difference over a
		// fixed baseline averages the steps out. The wave profile varies along
		// to_land, so one extra sample there carries the face; alongshore only the
		// smooth interpolated bed slope (sea_bed_slope) contributes.
		vec2 slope = sea_bed_slope * runup.y;
		if (dot(shore_now.to_land, shore_now.to_land) > 0.25) {
			vec2 step_xz = shore_now.to_land * CITY_RUNUP_SLOPE_STEP;
			ShoreState shore_ahead = shore_state(wave_sample_xz + step_xz, ocean_time, shore_sea());
			float crest_ahead = tide_height * tide_level
				+ (shore_ahead.height + max(shore_ahead.slosh, 0.0)) * shore_geometry_scale * shore_ahead.valid;
			float bed_ahead = sea_ground_y + dot(sea_bed_slope, step_xz);
			float rise = _city_runup_height(shore_ahead, bed_ahead, crest_ahead) - runup.x;
			vec2 along = vec2(-shore_now.to_land.y, shore_now.to_land.x);
			slope = shore_now.to_land * (rise / CITY_RUNUP_SLOPE_STEP) + along * dot(slope, along);
		}
		// Include the rising bore face in the shading normal, not only FFT ripples.
		float inland = smoothstep(-0.45, 0.12, sea_ground_y) * shore_now.beach * shore_now.valid;
		vec2 ocean_slope = world_normal.xz / max(world_normal.y, 0.2) * (1.0 - inland);
		world_normal = normalize(vec3(ocean_slope.x - slope.x, 1.0, ocean_slope.y - slope.y));
	}
	// Low-angle sunlight turns tiny animated normal changes into long, fast
	// specular bands. Keep the physical wave displacement, but reduce only the
	// shading normal relief near the horizon; the blend widens the sunrise and
	// sunset transition instead of switching the highlight on frame-to-frame.
	float sun_height_stability = smoothstep(0.03, 0.28, abs(sun_direction.y));
	float direct_normal_relief = mix(0.24, 0.80, sun_height_stability);
	vec3 calm_normal = normalize(mix(vec3(0.0, 1.0, 0.0), world_normal, direct_normal_relief));
	vec3 view_normal = normalize((VIEW_MATRIX * vec4(calm_normal, 0.0)).xyz);
	NORMAL = view_normal;

	// City GL uses alpha transmission. Its depth/screen samplers can alias on
	// this large material, so neither optical depth nor refraction may read them.
	bool physical_alpha = false;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	physical_alpha = sea_physical_depth;
#endif
	float surface_depth = max(-VERTEX.z, 0.0001);
	float raw_scene_depth = 0.0;
	float scene_depth = surface_depth;
	if (!physical_alpha) {
		raw_scene_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
		scene_depth = _view_depth(SCREEN_UV, raw_scene_depth, INV_PROJECTION_MATRIX);
	}
	if (!physical_alpha && flat_bed_flag > 0.5) {
		// WS-13b: the rendered sea bed lies metres below the flat gameplay bed.
		// Every optical term below was tuned against that flat bed, so the column
		// is measured to it: identical top-down water, real depth for cameras
		// under the surface (UnderwaterPass reads the raw depth buffer).
		scene_depth = min(scene_depth, _flat_bed_view_depth(
			VERTEX, flat_bed_world_y, SCREEN_UV, PROJECTION_MATRIX, INV_PROJECTION_MATRIX,
			INV_VIEW_MATRIX
		));
	}
	// WS-01: vertical water column under this pixel, the physical depth. Unlike the
	// distance along the view ray it does not grow when the camera drops or orbits.
	vec3 surface_world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float water_column = 0.0;
	if (scene_depth > surface_depth) {
		vec3 bed_world = (INV_VIEW_MATRIX * vec4(
			_view_position(SCREEN_UV, raw_scene_depth, INV_PROJECTION_MATRIX), 1.0
		)).xyz;
		// WS-13b: optics stay measured to the flat gameplay bed, not the rendered basin.
		float bed_y = flat_bed_flag > 0.5 ? max(bed_world.y, flat_bed_world_y) : bed_world.y;
		water_column = max(surface_world.y - bed_y, 0.0);
	}
	// R-1437: preserve the physical city column even if screen depth resolves to
	// the surface/another transparent pass. The existing vertex-only depth fetch
	// avoids exceeding Compatibility's fragment sampler budget. Districts opt out.
	float basin_column = sea_physical_depth ? max(surface_world.y - sea_ground_y, 0.0) : 0.0;
	water_column = max(water_column, basin_column);
	// Authored water cells share a flat gameplay bed a few centimetres down, so the
	// per-terrain absorption profile also selects a minimum optical path. This floor,
	// not the thin real column, is what keeps shallow/river/deep water distinct.
	float terrain_optical_depth = w_optical_depth + max(w_depth_absorption - 5.0, 0.0) * 0.055;
	// Rising coastal water hides more of the layered bed; ebbing water exposes it.
	// Rivers use a zero w_tide_optical_depth profile and remain unchanged.
	terrain_optical_depth = max(terrain_optical_depth + tide_level * w_tide_optical_depth, 0.018);
	if (sea_physical_depth) {
		terrain_optical_depth = 0.0;
	}

	// Ported from Tidewater (MIT), see notice.code.tidewater: follow the Snell-refracted
	// view ray to the bed instead of the straight screen ray, which overestimates the
	// water path 1.5-2x at the gameplay camera angle and ~10x at grazing angles.
	// VIEW points at the eye in view space for perspective and orthographic cameras.
	vec3 eye_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	// calm_normal, not the detail normal: the path length must not shimmer.
	vec3 transmitted_ray = refract(-eye_world, calm_normal, 1.0 / WATER_IOR);
	// Wave facets on the coarse mesh (or total internal reflection from below, which
	// returns a zero vector) can send the ray upward; keep it heading for the bed.
	transmitted_ray = normalize(vec3(transmitted_ray.x, min(transmitted_ray.y, -0.08), transmitted_ray.z));
	// Refracted cosine against the vertical; the floor bounds the path at the horizon.
	float transmitted_down = max(-transmitted_ray.y, 0.04);
	float path_len = water_column / transmitted_down;
	// One refinement against the depth buffer (Tidewater refines twice against a
	// height function): project the refracted bed hit, re-measure the column there,
	// and project again. Never accept a sample whose depth is in front of the surface;
	// that is the refraction halo that pulls dry bank pixels into the water.
	vec2 refracted_uv = SCREEN_UV;
	if (!physical_alpha && water_column > 0.0) {
		vec2 first_uv = _world_to_screen_uv(surface_world + transmitted_ray * path_len, PROJECTION_MATRIX, VIEW_MATRIX);
		float first_raw = textureLod(depth_texture, clamp(first_uv, vec2(0.0), vec2(1.0)), 0.0).r;
		vec3 first_bed = _view_position(first_uv, first_raw, INV_PROJECTION_MATRIX);
		bool first_valid = all(greaterThanEqual(first_uv, vec2(0.0))) && all(lessThanEqual(first_uv, vec2(1.0)))
			&& -first_bed.z > surface_depth + 0.002;
		if (first_valid) {
			float first_bed_y = (INV_VIEW_MATRIX * vec4(first_bed, 1.0)).y;
			first_bed_y = flat_bed_flag > 0.5 ? max(first_bed_y, flat_bed_world_y) : first_bed_y;
			float refined_column = max(surface_world.y - first_bed_y, 0.0);
			float refined_path = refined_column / transmitted_down;
			vec2 refined_uv = _world_to_screen_uv(surface_world + transmitted_ray * refined_path, PROJECTION_MATRIX, VIEW_MATRIX);
			float refined_depth = _view_depth(
				clamp(refined_uv, vec2(0.0), vec2(1.0)),
				textureLod(depth_texture, clamp(refined_uv, vec2(0.0), vec2(1.0)), 0.0).r,
				INV_PROJECTION_MATRIX
			);
			bool refined_valid = all(greaterThanEqual(refined_uv, vec2(0.0))) && all(lessThanEqual(refined_uv, vec2(1.0)))
				&& refined_depth > surface_depth + 0.002;
			if (refined_valid) {
				refracted_uv = refined_uv;
				water_column = refined_column;
				path_len = refined_path;
			}
		}
	}
	// A rejected refinement keeps the straight sample and the column measured there.
	refracted_uv = clamp(refracted_uv, vec2(0.001), vec2(0.999));
	vec3 floor_color = vec3(0.0);
	if (!physical_alpha) {
		floor_color = textureLod(screen_texture, refracted_uv, 0.0).rgb;
	}
	// Optical path in world units: the refracted path, floored by the terrain profile.
	float water_depth = max(max(path_len, basin_column / transmitted_down), terrain_optical_depth);
	// The layered bed and its caustics are classified by vertical depth (same floor),
	// so an orbiting camera cannot turn sand into deep-water bed.
	float bed_column = max(water_column, terrain_optical_depth);

	// Beer-Lambert along the refracted path. Wavelength-dependent extinction removes
	// red first and blue last, so depth shifts hue instead of uniformly darkening RGB.
	// sigma_t is art-scaled: the gameplay column is centimetres, not Baltic metres.
	vec3 sigma_t = w_depth_absorption * vec3(1.28, 0.72, 0.40) / WATER_METERS_PER_UNIT;
	float metres_per_unit = WATER_METERS_PER_UNIT;
	if (sea_physical_depth) {
		metres_per_unit = 1.0;
		sigma_t = physical_extinction * water_turbidity;
	}

	float twilight_water_light = smoothstep(-0.25, 0.25, sun_direction.y);
	vec3 seabed = vec3(0.0);
	// GL city transmission comes from fixed-function blending. Its synthetic
	// bed and caustic samples are discarded, so skip that work explicitly.
	if (!physical_alpha) {
		// Sand dominates illuminated shallows, stones break it into cool patches,
		// algae occupies sheltered mid-depth water, and the final layer suppresses
		// all bed detail once little daylight reaches the floor. The actual rendered
		// floor remains visible below the tint, preserving quays, props and authored
		// bank materials seen through the surface.
		vec4 bed_layers = _seabed_layers(water_world_position.xz, bed_column);
		vec3 shallow_bed = (
			sand_bed_color * bed_layers.x
			+ stone_bed_color * bed_layers.y
			+ algae_bed_color * bed_layers.z
		);
		vec3 layered_bed = mix(shallow_bed, deep_bed_color, bed_layers.w);
		// The rendered terrain is physical geometry, but its grass texture should only
		// survive as a restrained hint right at a clear, shallow edge. Otherwise the
		// map's flat recessed bed makes it look like a meadow continues under water.
		float bed_detail_visibility = exp(-water_depth * 9.5) * 0.18;
		seabed = mix(layered_bed, floor_color * layered_bed * 1.18, bed_detail_visibility);
		if (sea_physical_depth) {
			// Preserve actual rocks, fish and foundations. Do not attenuate their
			// contrast a second time with the old synthetic centimetre-deep bed.
			seabed = floor_color;
		}

		// WS-07: caustics are light on the bed, applied before extinction, so the view path
		// dims them again on the way up. They fade with depth (light_down), at night and
		// under cloud. The sun-disk visibility ramp is intentionally not the gate: it spans
		// only a few degrees and makes animated nets switch on as a band at sunrise; the
		// wider solar envelope keeps the transition continuous.
		// A caustic net only modulates the direct-sun share of the bed light; the skylight
		// share is uniform. That share falls with sun height, squared because skylight takes
		// over the bed at dusk (0.05 at a 13-degree sunset sun, none once the sun is down).
		float caustic_direct_share = smoothstep(0.0, 0.7, sun_direction.y);
		caustic_direct_share *= caustic_direct_share;
		// Cloud: the contract's (1 - cloud_darken * 0.85) never acts, because MapViewLighting
		// does not push cloud_darken to water (it stays 0; WS-11 owns that chain).
		// sun_reflection_visibility is the direct-sun factor the glint already uses: sun disk
		// x (1 - cloud coverage), 0.70 clear, 0.34 cloudy, 0.02 overcast. Its narrow horizon
		// ramp sits where caustic_direct_share is already ~0, so it cannot band at sunrise.
		float caustic_sun_gate = twilight_water_light * caustic_direct_share * (1.0 - bed_layers.w)
			* sun_reflection_visibility;
		// Where the refracted view ray meets the bed (WS-01 path), not the surface point.
		vec2 caustic_bed_xz = surface_world.xz + transmitted_ray.xz * path_len;
		vec2 caustic_slope = use_fft ? -world_normal.xz / max(world_normal.y, 0.2) : vec2(0.0);
		seabed *= _bed_caustic_gain(
			caustic_bed_xz, bed_column * WATER_METERS_PER_UNIT * CAUSTIC_APPARENT_SCALE, sun_direction,
			caustic_slope, sigma_t, caustic_sun_gate
		);
	}

	float path_m = water_depth * metres_per_unit;
	vec3 spectral_transmission = exp(-sigma_t * path_m);
	float absorption = 1.0 - dot(spectral_transmission, vec3(0.333333));
	vec3 transmitted = seabed * spectral_transmission;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	if (sea_physical_depth) {
		// GLES screen copies alias atlas samplers on this large material (the
		// underwater pass has the same driver constraint). Let fixed-function
		// blending transmit the actual opaque bed/fish; shade only the water.
		transmitted = vec3(0.0);
	}
	#endif
	vec3 water_color = transmitted + w_deep_color * (vec3(1.0) - spectral_transmission) * 0.82;
	water_color = mix(water_color, w_shallow_color, (1.0 - absorption) * 0.12);
	if (shore_live) {
		// The stirred sediment continues into the run-up. The legacy surf-zone
		// mask steps at distance zero: using it as a city tint drew a ruler-sharp
		// sea/shore colour boundary even though geometry and normals were joined.
		float stirred = shore_now.surf_zone;
		float sediment = SHORE_TURBIDITY * shore_now.valid;
		if (sea_physical_depth) {
			stirred = max(stirred,
				(1.0 - smoothstep(0.0, 0.5, shore_now.distance)) * shore_now.beach);
			// A centimetre-thin sheet cannot scatter like a metre-deep bore.
			sediment *= absorption;
		}
		water_color = mix(water_color, sand_bed_color * 0.9, sediment * stirred);
	}

	vec2 city_foam = vec2(0.0);
	if (sea_physical_depth) {
		vec2 advected = wave_sample_xz;
		if (shore_live) {
			// Water side: the bore's landward lunge and slow return (surge). Sheet
			// side: the run-up front carries its water up the sand and back.
			float front = shore_now.front_distance - shore_now.distance;
			float on_sheet = 1.0 - smoothstep(-0.4, 0.4, shore_now.distance);
			float shift = mix(shore_now.surge, front * shore_depth_scale * shore_now.beach, on_sheet);
			advected -= shore_now.to_land * shift * shore_now.valid;
		}
		city_foam = _city_foam_cells(advected);
	}
	// COLOR.r is baked from the same smooth contour that clips the mesh. A pair
	// of advancing breaker bands now travels into that contour, crests, and fades
	// at the bank. This reads as surf arriving at shore rather than static edge foam.
	float shore = 1.0 - smoothstep(0.0, 0.88, shore_factor);
	float breaker_phase = shore_factor * 18.0 + TIME * (1.45 * wave_speed);
	float breaker_warp = (_noise(water_world_position.xz * 0.42 + vec2(TIME * 0.08, -TIME * 0.04)) - 0.5) * 3.4;
	float breaker_a = pow(max(sin(breaker_phase + breaker_warp), 0.0), 5.0);
	float breaker_b = pow(max(sin(breaker_phase * 0.62 + breaker_warp * 0.7 + 2.4), 0.0), 7.0);
	float breaker_band = (breaker_a + breaker_b * 0.55) * smoothstep(0.04, 0.92, shore);
	if (shore_live) {
		// The analytic bore replaces the travelling sin() bands; hard edges throw
		// foam at the foot of the wall instead of running up.
		float swash_foam = shore_now.bore_foam * mix(0.45, 1.0, _swash_patch(water_world_position.xz, TIME));
		swash_foam += shore_now.wall_foam * mix(0.35, 1.0, _swash_patch(water_world_position.xz * 1.3, TIME));
		breaker_band = mix(breaker_band, 0.0, shore_now.valid);
		// Broken water is aerated white, unlike the tinted edge foam: add it after the
		// breaker scale so the bore reads from the gameplay camera.
		if (sea_physical_depth) {
			float front = shore_now.front_distance - shore_now.distance;
			float front_coordinate = (shore_now.front_distance - 0.28) / 0.4;
			float rolling_front = exp(-front_coordinate * front_coordinate);
			float trailing_foam = exp(-max(shore_now.front_distance, 0.0) / 1.4) * 0.45;
			float runup_foam = (rolling_front * 1.4 + trailing_foam)
				* smoothstep(0.001, 0.04, front) * smoothstep(0.0, 0.1, shore_now.front_distance)
				* shore_now.beach * shore_now.valid;
			swash_foam = mix(swash_foam, max(swash_foam, runup_foam),
				smoothstep(-0.45, 0.12, sea_ground_y));
		}
		swash_bore = clamp(swash_foam * shore_now.valid, 0.0, 1.0);
		if (sea_physical_depth) {
			// WR-2: coverage follows the bore's age, not a saturated gain. The
			// fresh roller just behind the front is a dense white band; behind it
			// foam dissolves into lace over CITY_SURF_FOAM_LIFE seconds; between
			// sets only a thin, patchy scum remains. foam_gain scales coverage.
			float age = shore_now.foam_age;
			float energy = mix(0.55, 1.0, clamp(shore_sea_state, 0.0, 1.0));
			// Squares by multiplication: GLSL pow() is undefined for a negative base
			// (the NaN class behind the earlier dark shore bands).
			// WR-4 breaker type: a plunging jet bursts a wider, denser roller; a
			// surging wave slides up and back with little white water.
			float roller_x = (age - 0.35) / mix(0.5, 0.8, shore_now.plunge);
			float roller = exp(-roller_x * roller_x);
			float trail = exp(-age / CITY_SURF_FOAM_LIFE);
			float zone = clamp(shore_now.bore_foam / max(shore_foam_gain, 0.001), 0.0, 1.0);
			float coverage = max(roller * 0.95, trail * mix(0.6, 0.72, shore_now.plunge))
				* step(0.0, shore_now.distance) * smoothstep(0.0, 0.25, zone) * energy
				* (1.0 - 0.7 * shore_now.surging);
			// Hard edges (quays, rocks) keep their slosh foam band.
			coverage = max(coverage, clamp(shore_now.wall_foam, 0.0, 1.0) * 0.8);
			coverage = max(coverage, CITY_SURF_SCUM * shore_now.surf_zone * energy);
			// The run-up film is a thin, see-through sheet: a narrow foam bead at
			// its leading edge and sparse lace behind it, not a white blanket.
			float behind_front = shore_now.front_distance * shore_depth_scale;
			float wet_sheet = step(shore_now.distance, 0.0) * step(0.0, behind_front)
				* shore_now.beach * step(0.02, shore_now.front_distance - shore_now.distance);
			float bead_x = (behind_front - 0.35) / 0.4;
			float bead = exp(-bead_x * bead_x);
			float lace = exp(-behind_front / 2.5) * 0.35;
			// WR-9: over shingle (steep bed) the backwash sinks into the gaps: the
			// film thins far faster than its front retreats, its bubbles pop, and
			// pebble crowns break through once it is thinner than they are tall.
			float porous = shore_porosity(length(sea_bed_slope)) * shore_now.beach;
			ShoreBeach drain = shore_beach(shore_now, porous);
			float film_metres = shore_now.sheet_thickness * drain.film_keep;
			runup_drain = mix(1.0, drain.film_keep
				* shore_pebble_cover(film_metres, porous), wet_sheet);
			coverage = max(coverage, max(bead * 0.9, lace) * wet_sheet * energy * drain.foam_keep);
			swash_bore = _foam_dissolve(city_foam.x, coverage * shore_now.valid)
				* mix(0.7, 1.0, roller);
		}
	}
	if (obstacle_foam > 0.001) {
		// WR-5 impact foam: dense where a crest just hit the rock, lace as it wraps
		// around and dissolves (same attached cells as the surf foam).
		swash_bore = max(swash_bore, _foam_dissolve(city_foam.x, clamp(obstacle_foam, 0.0, 1.0)));
	}
	vec2 foam_uv = water_world_position.xz * 3.4 + vec2(-TIME * 0.22, TIME * 0.09) * wave_speed;
	float foam_noise = _noise(foam_uv + _noise(foam_uv * 0.47) * 2.2);
	float foam_ribbon = 0.5 + 0.5 * sin(
		dot(water_world_position.xz, vec2(5.4, 3.8)) - TIME * 0.85 * wave_speed + foam_noise * 3.0
	);
	float edge_foam = shore * smoothstep(0.52, 0.88, foam_noise * 0.70 + foam_ribbon * 0.30);
	float foam = edge_foam * foam_intensity + breaker_band * breaker_intensity;
	foam *= smoothstep(0.012, 0.08, water_column);
	if (sea_physical_depth) {
		// WR-2: the edge ribbons scroll with TIME regardless of the water; the
		// city's surf, whitecaps and wakes carry all of its foam.
		foam = 0.0;
	}


	// WS-06 whitecaps. The baked mask decides where foam is; the foam tile, sampled at
	// the undisplaced wave_sample_xz (in the wind frame) so it rides the surface,
	// decides what it looks like: bubble clusters appear first where the tile is
	// bright, and the patch thins back into them as the baked foam decays.
	float whitecap = 0.0;
	float whitecap_fresh = 0.0;
	float wind_streak = 0.0;
	if (use_fft && !swash_sheet) {
		fft_foam = _fft_foam_terms(wave_sample_xz);
		vec2 whitecap_uv = _fft_to_wind(wave_sample_xz, _fft_wind_axis()) * foam_tile_scale;
		vec2 foam_drift_a = vec2(ocean_time * FOAM_DRIFT_A_TILES_PER_WRAP / OCEAN_TIME_WRAP_SECONDS, 0.0);
		vec2 foam_drift_b = vec2(ocean_time * FOAM_DRIFT_B_TILES_PER_WRAP / OCEAN_TIME_WRAP_SECONDS, 0.0);
		vec4 tile_a = vec4(0.0);
		float foam_texture;
		if (sea_physical_depth) {
			foam_texture = city_foam.x;
			tile_a.b = city_foam.y * CITY_STREAK_SHARE;
		} else {
			tile_a = texture(foam_tile, whitecap_uv - foam_drift_a);
			vec4 tile_b = texture(foam_tile, whitecap_uv * 2.3 + vec2(0.37, 0.61) - foam_drift_b);
			foam_texture = mix(tile_a.r, tile_b.r, 0.5) * mix(0.7, 1.0, tile_a.g);
		}
		// Capped so even a storm crest keeps bubble holes instead of a flat white sheet.
		float foam_mask = min(fft_foam.x * storm_foam_coverage * foam_coverage, FOAM_MASK_CAP);
		whitecap = clamp((foam_mask - (1.0 - foam_texture)) * foam_sharpness, 0.0, 1.0);
		if (sea_physical_depth) {
			// WR-2: the baked mask is broad (it carries every decaying patch), so the
			// old threshold whitened most of the city sea. Only the upper part of the
			// mask breaks: open-sea cover then grows from a few % in a fresh breeze
			// towards a fifth of the sea in a gale (Monahan-like), as lace.
			float breaking = clamp((foam_mask - CITY_WHITECAP_THRESHOLD)
				/ (1.0 - CITY_WHITECAP_THRESHOLD), 0.0, 1.0);
			whitecap = _foam_dissolve(foam_texture, breaking * CITY_WHITECAP_GAIN);
		}
		// Storm streaks: the tile's B channel is stretched 6:1 along +X, which is
		// downwind in the wind frame. The coarse C0 mask links them to whitecaps.
		float streak_link = smoothstep(0.02, 0.3, fft_foam.z * storm_foam_coverage);
		float open_water = smoothstep(0.14, 0.48, shore_factor) * smoothstep(0.03, 0.10, water_column);
		// WHY: calm shallows stay clear, but a storm sea breaks hardest where it
		// shoals, so the surf zone must foam instead of reading like a calm lagoon.
		// storm_streaks is the same 0 (sea 0.5) .. 1 (storm) share the streaks use.
		open_water = mix(open_water, smoothstep(0.03, 0.10, water_column), storm_streaks * 0.85);
		// Streak foam floats on the surface, so it is laid on as white foam below
		// instead of the sunk tint of old whitecap foam.
		wind_streak = clamp(tile_a.b * streak_amount * storm_streaks * streak_link, 0.0, 1.0) * open_water;
		whitecap *= open_water * whitecap_onset * _fetch_shelter(wave_sample_xz);
		// The bake decays foam over time: a high raw value just broke (bright,
		// opaque), a low one is old foam, thin and sunk under the surface.
		// A rougher sea breaks more often than the reference bake, so the weather scale
		// also lowers the bar for foam to count as freshly broken.
		whitecap_fresh = whitecap * smoothstep(0.35, 0.8, fft_foam.y * storm_foam_coverage);
		// The decayed tail of the baked foam falls below the whitecap threshold within
		// about a second; this thin lace over the brightest bubble rims keeps it
		// visible for the few seconds the bake still carries it.
		float foam_trail = smoothstep(0.06, 0.3, foam_mask) * smoothstep(0.35, 0.75, foam_texture) * open_water;
		if (sea_physical_depth) {
			// Old whitecap foam: sparse lace that thins as the mask decays.
			foam_trail = _foam_dissolve(foam_texture, smoothstep(0.2, 0.9, foam_mask) * 0.35) * open_water;
		}
		float whitecap_old = max(whitecap - whitecap_fresh, foam_trail * 0.9);
		water_color = mix(water_color, mix(w_shallow_color, w_foam_color, 0.4), whitecap_old * 0.6);
		water_color = mix(water_color, mix(w_foam_color, vec3(0.93, 0.95, 0.94), 0.6), whitecap_fresh);
		water_color = mix(water_color, w_foam_color, wind_streak);
		whitecap_fresh = max(whitecap_fresh, wind_streak);
	}

	float surface_foam = sea_physical_depth
		? clamp(max(whitecap_fresh, max(swash_bore, foam)), 0.0, 1.0) : whitecap_fresh;

	// Thin crests transmit more Baltic teal than troughs; fades with the same solar
	// envelope as floor caustics so night water stays dark without a bloom pass.
	float crest_subsurface = smoothstep(0.0, 0.30, max(crest_term, 0.0));
	crest_subsurface *= choppiness * smoothstep(0.14, 0.48, shore_factor);
	// Fresh foam is opaque: no light comes through the crest under it.
	crest_subsurface *= 1.0 - surface_foam;
	float crest_sss_visibility = twilight_water_light * day_blend;
	vec3 crest_transmit_tint = mix(w_shallow_color, w_highlight_color, 0.58);
	water_color += crest_transmit_tint
		* crest_subsurface
		* crest_sss_visibility
		* (0.18 + (1.0 - absorption) * 0.22);

	// Schlick Fresnel plus the PBR specular lobe produces stable sky reflection
	// and narrow sun glints at the shallow isometric viewing angle.
	float facing = clamp(dot(view_normal, normalize(VIEW)), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
	vec3 world_view = normalize((INV_VIEW_MATRIX * vec4(normalize(VIEW), 0.0)).xyz);
	// WHY: from the steep gameplay camera a uniform sky hides slopes, so the 0.38
	// relief made a storm sea read as flat as a calm one. Rougher seas let more of
	// the FFT slope into the reflected ray: crest trains and their wavelength show.
	// ocean_amplitude runs 0.5 (calm) .. 1.6 (storm) on the FFT path only.
	float sea_relief = use_fft ? smoothstep(0.5, 1.6, ocean_amplitude) : 0.0;
	vec3 reflection_normal = normalize(mix(vec3(0.0, 1.0, 0.0), world_normal, mix(0.38, 0.62, sea_relief)));
	vec3 reflected_sky_ray = normalize(reflect(-world_view, reflection_normal));
	// A steep storm facet can tip the ray below the horizon, where the dome reads
	// black and paints ink blots on the sea. The far face of the next crest is what
	// it would see, which is close to the horizon colour, so hold the ray there.
	if (sea_relief > 0.0) {
		reflected_sky_ray = normalize(vec3(reflected_sky_ray.x, max(reflected_sky_ray.y, 0.07), reflected_sky_ray.z));
	}
	float reflected_above_horizon = smoothstep(-0.01, 0.06, reflected_sky_ray.y);
	vec3 sky_reflection = _sky_dome_reflection(reflected_sky_ray) * reflected_above_horizon;
	// Keep the reflection legible from the gameplay camera. Fresnel still makes
	// grazing angles brightest, while this base share stops the shallow bed from
	// overpowering sky and sun reflections on broad, calm water.
	float sky_reflection_weight = clamp(
		0.34 + fresnel * mix(0.44, 0.62, day_blend),
		0.0,
		0.88
	);
	if (sea_physical_depth) {
		// A fixed 34% reflection bleaches the bed even when looking straight
		// down. Fresnel gives clear shallows and a reflective grazing horizon.
		sky_reflection_weight = clamp(fresnel, 0.02, 0.92);
	}
	// Fresh foam is rough and diffuse, so it does not mirror the sky. Old foam lies
	// under the surface and keeps the reflection on top of it.
	sky_reflection_weight *= 1.0 - surface_foam;
	// Stagnant water: darken and tint the column, then lay a floating film over it.
	// shore_factor is 0 at the bank and grows toward open water, so it doubles as a
	// depth cue: silty shelf at the edge, near-black olive in the middle.
	float scum_cover = 0.0;
	vec3 scum_color = pond_duckweed_color;
	if (pond_murk > 0.001 && !swash_sheet) {
		vec2 pp = water_world_position.xz;
		float centre = smoothstep(0.10, 0.85, shore_factor);
		float bank = 1.0 - smoothstep(0.0, 0.45, shore_factor);
		vec3 murk = mix(pond_shelf_color, pond_deep_color, centre);
		water_color = mix(water_color, murk, pond_murk * mix(0.80, 0.95, centre));
		// Sky mirrored in a silty, algae-rich column is greenish and dull, not blue.
		sky_reflection *= vec3(0.46, 0.62, 0.40);
		// Wet mud shelf: a ragged, opaque-looking band along the waterline gives the
		// edge a sloped bank instead of a ruler-straight cut into clear water.
		float mud_edge = 0.50 + 0.20 * _noise(pp * 1.7 + vec2(4.2, -9.1))
			+ 0.10 * _noise(pp * 6.3 + vec2(-2.7, 13.4));
		float mud_band = 1.0 - smoothstep(0.04, mud_edge, shore_factor);
		vec3 mud_color = mix(vec3(0.34, 0.26, 0.15), vec3(0.22, 0.22, 0.10),
			_noise(pp * 3.1 + vec2(8.8, 1.4)));
		water_color = mix(water_color, mud_color * mix(0.6, 1.0, day_blend), mud_band * mud_band * 0.95 * pond_murk);
		// Shadowed, darker band right beyond the mud: reads as the bank dropping away.
		water_color *= 1.0 - bank * bank * 0.45 * pond_murk;
		// Floating film: slow drifting patches that gather at the banks, broken into
		// lemna-sized speckles, plus occasional brown leaf litter and algae stains.
		vec2 drift = vec2(TIME * 0.012, -TIME * 0.007);
		float patches = _noise(pp * 0.33 + drift + vec2(7.1, 2.3)) * 0.6
			+ _noise(pp * 0.9 - drift * 1.6 + vec2(-3.4, 11.8)) * 0.4;
		float mat_mask = smoothstep(0.50 - bank * 0.18, 0.68 - bank * 0.12, patches);
		float speckle = smoothstep(0.30, 0.62, _noise(pp * 7.5 + vec2(19.2, -5.6)) * 0.65
			+ _noise(pp * 17.0 + vec2(-8.3, 3.9)) * 0.35);
		// Thin lemna film everywhere (never fully clear), thickest in the bank band.
		float film = smoothstep(0.50, 0.75, _noise(pp * 11.0 + vec2(2.3, 6.7))) * 0.35;
		scum_cover = max(mat_mask * mix(0.55, 1.0, speckle), film + bank * 0.25) * pond_scum;
		float stain = smoothstep(0.58, 0.8, _noise(pp * 0.21 + vec2(-14.7, 5.5)));
		water_color = mix(water_color, pond_shelf_color * 1.15, stain * 0.35 * pond_murk);
		float leaves = smoothstep(0.80, 0.92, _noise(pp * 5.2 + vec2(31.0, 9.7))) * (0.4 + bank);
		scum_color = mix(pond_duckweed_color * mix(0.7, 1.25, speckle), vec3(0.20, 0.14, 0.07), clamp(leaves, 0.0, 1.0));
		scum_cover = clamp(max(scum_cover, leaves * 0.55 * pond_scum), 0.0, 0.92);
		sky_reflection_weight *= mix(1.0, 0.8, pond_murk) * (1.0 - scum_cover * 0.85);
	}
	// WS-06 art-direction lever, like ripple_sheen: seen from the steep gameplay camera
	// a flatter or rougher normal barely changes a uniform sky, so a glassy slick also
	// mirrors a little more of it and a catspaw a little less, then reads darker.
	float gust_tone = sea_gust - 1.0;
	sky_reflection_weight = clamp(sky_reflection_weight * (1.0 - gust_tone * 0.5), 0.0, 0.92);
	water_color = mix(water_color, sky_reflection, sky_reflection_weight);
	water_color *= 1.0 - max(gust_tone, 0.0) * 0.3;
	// The film sits on top of the mirror, lit like a diffuse leaf surface.
	water_color = mix(water_color, scum_color * mix(0.55, 1.0, day_blend), scum_cover);

	// WHY: DayNightCycle packs a solar day into 60s. Reflecting the catalog and
	// sun/moon through fully animated wave normals turns that race into frantic
	// pre-dawn sparkles on open sea. Celestial samples use a calmer normal so
	// waves still displace while glints stay readable instead of strobing.
	vec3 reflected_stars = texture(star_map, _equatorial_uv(reflected_sky_ray)).rgb;
	// Drop star glitter as soon as the sun disk begins to rise so dawn does not
	// stack racing constellations on top of the emerging sun path.
	float night_sparkle = star_visibility * (1.0 - sun_reflection_visibility);
	water_color += reflected_stars * night_sparkle * reflected_above_horizon * fresnel * 0.16;

	// WS-02: sun and moon glints come from light() (GGX x Smith x exact Fresnel),
	// so the light's shadow removes them behind quays and hulls. These gates keep
	// the old twilight rules. Low sun elongates the glitter path; keep a warm dawn
	// cue without a racing sparkle highway while the disk skims the horizon on a
	// compressed day cycle.
	float low_sun_glitter = smoothstep(-0.02, 0.22, sun_direction.y);
	float sun_glint_gate = sun_reflection_visibility * smoothstep(0.0, 0.05, sun_direction.y)
		* mix(0.2, 1.0, low_sun_glitter);
	// MapViewLighting uses the actual sun or moon bearing, never an interpolated one.
	float sun_light_share = step(0.0, sun_direction.y);
	float moon_glint_gate = moon_visibility * (1.0 - sun_light_share);
	directional_glint_gate = (moon_glint_gate + sun_glint_gate * sun_light_share) * (1.0 - surface_foam);
	local_glint_gate = 1.0 - surface_foam;


	// Jacobian whitecaps on the Gerstner fallback: folding crests, not shoreline bands.
	// A short time lag leaves foam behind the advancing crest without a foam buffer.
	// The FFT path styles its baked, lingering foam above (WS-06 whitecap).
	if (!use_fft && flow_strength <= 0.001) {
		float jacobian_now = _water_jacobian(wave_sample_xz - flow_advection, TIME * wave_speed);
		float jacobian_trail = _water_jacobian(
			wave_sample_xz - flow_advection,
			TIME * wave_speed - 0.42
		);
		float crest_fold = max(
			smoothstep(0.92, 0.55, jacobian_now),
			smoothstep(0.92, 0.55, jacobian_trail) * 0.68
		);
		crest_fold *= choppiness * foam_intensity * 1.35;
		crest_fold *= smoothstep(0.14, 0.48, shore_factor);
		crest_fold *= smoothstep(0.03, 0.10, water_column);
		foam += crest_fold;
	}

	// Downstream foam streaks for flowing rivers. The along-current coordinate
	// scrolls with time so the ribbons travel toward the far bank, while the
	// cross-current axis stays tight so the foam elongates into streaks rather
	// than round blobs. flow_strength == 0 leaves still water untouched.
	if (flow_strength > 0.0) {
		vec3 current = _river_current(water_world_position.xz);
		vec2 flow_dir = current.xy;
		vec2 flow_cross = vec2(-flow_dir.y, flow_dir.x);
		// The time rate stays uniform across the channel: a position-dependent
		// scroll speed would shear these patterns without bound. The bank drag
		// shows in the ripple travel (detail normal) and in the sheen strength.
		float along = dot(water_world_position.xz, flow_dir) - TIME * wave_speed * flow_strength * 1.6;
		float across = dot(water_world_position.xz, flow_cross);
		vec2 streak_uv = vec2(across * 2.1, along * 0.55);
		float streak = _river_threads(streak_uv, vec2(9.1, 2.3));
		float current_foam = smoothstep(0.48, 0.74, streak) * flow_strength;
		current_foam *= smoothstep(0.012, 0.08, water_column);
		foam += current_foam * 0.55;
		// Long bright filaments of sky sheen sliding downstream at a different speed
		// from the foam, so a still frame already shows which way the water runs and
		// the two layers shear against each other in motion. Slack water by the bank
		// is glassier, so the filaments fade out as the current drops.
		float along_sheen = dot(water_world_position.xz, flow_dir) - TIME * wave_speed * flow_strength * RIVER_SURFACE_SPEED;
		vec2 sheen_uv = vec2(across * 1.35, along_sheen * 0.22);
		float sheen = smoothstep(0.46, 0.72, _river_threads(sheen_uv, vec2(3.7, 8.2)));
		water_color = mix(water_color, w_highlight_color, sheen * 0.30 * current.z);
		// Banks drag the current: foam threads gather along the shore.
		foam += shore * current_foam * 0.6;
	}
	// WS-15 churned water behind hulls: broken into bubbly clumps rather than a flat sheet.
	if (ripple_aeration > 0.001) {
		float bubbles = _noise(water_world_position.xz * 7.5 + vec2(TIME * 0.3, -TIME * 0.2));
		bubbles = smoothstep(0.25, 0.75, bubbles * 0.6 + ripple_aeration * 0.6);
		foam += ripple_aeration * ripple_foam_strength * bubbles
			* smoothstep(0.012, 0.08, water_column);
	}
	water_color = mix(water_color, w_highlight_color, clamp(ripple_slope_length * ripple_sheen, 0.0, 0.25));
	water_color = mix(water_color, w_foam_color, clamp(foam, 0.0, 0.72));
	// WS-08 surf bore on top of the tinted foam: brighter and whiter than edge foam.
	water_color = mix(water_color, mix(w_foam_color, vec3(0.93, 0.95, 0.94), 0.6), swash_bore * 0.85);

	ALBEDO = water_color;
	ALPHA = 1.0;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	if (sea_physical_depth) {
		float foam_cover = clamp(max(foam, max(whitecap_fresh, swash_bore)), 0.0, 1.0);
		float through = dot(spectral_transmission, vec3(0.2126, 0.7152, 0.0722))
			* (1.0 - sky_reflection_weight) * (1.0 - foam_cover);
		ALPHA = clamp(1.0 - through, 0.025, 1.0);
		ALBEDO = water_color / ALPHA;
	}
	#endif
	// WS-02 roughness from wave slope variance (Toksvig-style). Calm water is a
	// near mirror; rivers and foam are rougher. A rougher sea widens the glitter
	// path, and slope the pixel cannot resolve (distant waves, the detail normal
	// that calm_normal flattens at low sun) becomes roughness instead of a
	// single-pixel sparkle.
	vec3 normal_dx = dFdx(world_normal);
	vec3 normal_dy = dFdy(world_normal);
	float unresolved_slope = clamp(dot(normal_dx, normal_dx) + dot(normal_dy, normal_dy), 0.0, 0.25);
	float rough_water = max(step(0.001, flow_strength), clamp(foam, 0.0, 1.0));
	float base_alpha = mix(0.03, 0.08, rough_water);
	// choppiness x wave_chaos spans ~0.5 (calm) to ~1.9 (storm) under apply_sea_weather.
	float sea_variance = mix(0.0015, 0.02, smoothstep(0.45, 1.8, choppiness * wave_chaos));
	ROUGHNESS = sqrt(sqrt(base_alpha * base_alpha + sea_variance + unresolved_slope));
	// Godot maps SPECULAR to dielectric F0; 0.25 is approximately water's 0.02.
	// With the custom light() it only scales ambient and reflection-probe specular.
	SPECULAR = mix(0.05, 0.25, sun_visibility);
	// WS-06: fresh foam is a rough diffuse scatterer. It takes its brightness from
	// the lights through ALBEDO, so it dims with the night instead of glowing.
	ROUGHNESS = mix(ROUGHNESS, sea_physical_depth ? 0.72 : 0.6, surface_foam);
	// Duckweed and leaf litter scatter light diffusely, unlike open water.
	ROUGHNESS = mix(ROUGHNESS, 0.75, scum_cover);
	SPECULAR = mix(SPECULAR, sea_physical_depth ? 0.05 : 0.1, surface_foam);
	glint_alpha = ROUGHNESS * ROUGHNESS;
	// WHY full Lambert rather than the ~0.02 of physical water: ALBEDO here is the
	// already composited transmitted bed plus sky reflection, tuned under the old
	// built-in diffuse. Dropping it to 0.02 would leave the sea lit by ambient
	// only. Moving the sky reflection out of ALBEDO belongs to WS-11.
	diffuse_share = 1.0;
	// WS-13: the surface seen from below. The old P0-227 fog tint is gone; the
	// UnderwaterPass fogs everything between the lens and this surface, so the
	// branch only resolves what the surface itself shows: Snell's window inside
	// the critical angle, total internal reflection (a silver-green mirror of the
	// lit water) outside it. Unshaded via EMISSION so the sun cannot light the
	// underside a second time.
	// City sea triangles have consistent winding. A tall approaching crest can be
	// above the eye while its FRONT is visible: comparing heights paints a false
	// underwater band across that crest. Legacy district edge strips have mixed
	// winding and retain their rest-height convention.
	vec3 camera_world = INV_VIEW_MATRIX[3].xyz;
	bool seen_from_below = sea_physical_depth ? !FRONT_FACING
		: camera_world.y < water_world_position.y;
	if (seen_from_below && !swash_sheet) {
		ALPHA = 1.0;
		vec3 uw_ambient;
		vec3 uw_sun;
		_uw_lighting(
			mix(w_shallow_color, w_deep_color, 0.35), sun_reflection_color, sun_direction,
			day_blend, cloud_darken, uw_ambient, uw_sun
		);
		NORMAL = -NORMAL;
		ALBEDO = vec3(0.0);
		UwWindow uw = _uw_window(
			SCREEN_UV, VIEW_MATRIX, -world_view, normalize(mix(vec3(0.0, 1.0, 0.0), world_normal, 0.6))
		);
		vec3 uw_air = vec3(
			textureLod(screen_texture, clamp(uw.uv + uw.fringe, vec2(0.001), vec2(0.999)), 0.0).r,
			textureLod(screen_texture, uw.uv, 0.0).g,
			textureLod(screen_texture, clamp(uw.uv - uw.fringe, vec2(0.001), vec2(0.999)), 0.0).b
		);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		if (sea_physical_depth) {
			vec3 exit_ray = refract(-world_view, -normalize(mix(vec3(0.0, 1.0, 0.0), world_normal, 0.6)), WATER_IOR);
			uw_air = _sky_dome_reflection(normalize(exit_ray + vec3(0.0, 0.0001, 0.0)));
		}
#endif
		EMISSION = _uw_below_color(
			uw, uw_air, -world_view, uw_ambient, uw_sun, sun_direction, _uw_sigma_t(cloud_darken),
			deep_bed_color
		);
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		// light() ignores SPECULAR; the underside is EMISSION only.
		directional_glint_gate = 0.0;
		local_glint_gate = 0.0;
		diffuse_share = 0.0;
	}
	if (swash_sheet) {
		NORMAL = sheet_normal;
		ALBEDO = sheet_albedo;
		ALPHA = sheet_alpha;
		ROUGHNESS = sheet_roughness;
		SPECULAR = mix(0.05, 0.5, sun_visibility);
		glint_alpha = sheet_roughness * sheet_roughness;
		directional_glint_gate = sun_glint_gate * sun_light_share * (1.0 - sheet_foam);
		local_glint_gate = 1.0 - sheet_foam;
	}
	// Foam lace at the tip stays opaque where the thinning film has faded out, so
	// the edge reads as a broken foam line rather than a clean cut.
	float tip_foam = shore_live ? swash_bore * smoothstep(0.0, 0.04, shore_now.front_distance) : 0.0;
	ALPHA *= max(city_coverage, tip_foam) * runup_drain;
	if (debug_foam_mask > 0.5) {
		// Unlit mask: lighting and the foam tile must not hide renderer coverage.
		vec3 mask = vec3(fft_foam.x);
		ALBEDO = mask;
		EMISSION = mask;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		ALPHA = 1.0;
		directional_glint_gate = 0.0;
		local_glint_gate = 0.0;
		diffuse_share = 0.0;
	}
	if (debug_surface_validity) {
		bool invalid = any(isnan(world_normal)) || any(isinf(world_normal))
			|| any(isnan(water_color)) || any(isinf(water_color))
			|| isnan(swash_bore) || isnan(ALPHA) || invalid_surface_vertex > 0.001;
		ALBEDO = vec3(0.0);
		EMISSION = invalid ? vec3(1.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
		NORMAL = vec3(0.0, 0.0, 1.0);
		glint_alpha = 1.0;
		ALPHA = 1.0;
		SPECULAR = 0.0;
		directional_glint_gate = 0.0;
		local_glint_gate = 0.0;
		diffuse_share = 0.0;
	}
}

// WS-02: GGX x height-correlated Smith x exact dielectric Fresnel for every
// light. NORMAL is the calm normal from fragment(), so the compressed day cycle
// does not turn wave detail into racing specular bands. ATTENUATION carries the
// shadow, so quays and hulls cut the glitter path.
void light() {
	vec3 half_vector = normalize(VIEW + LIGHT);
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	float n_dot_v = max(dot(NORMAL, VIEW), 1e-4);
	float n_dot_h = max(dot(NORMAL, half_vector), 0.0);
	float v_dot_h = max(dot(VIEW, half_vector), 0.0);
	float a2 = max(glint_alpha * glint_alpha, 1e-6);
	float glint = _d_ggx(n_dot_h, a2) * _v_smith_ggx_correlated(n_dot_l, n_dot_v, a2)
		* _fresnel_dielectric(v_dot_h, WATER_IOR) * n_dot_l;
	float gate = LIGHT_IS_DIRECTIONAL ? directional_glint_gate : local_glint_gate;
	// Deck and cells dim direct diffuse and glints together, without shading ambient.
	float cloud_lit = LIGHT_IS_DIRECTIONAL ? 1.0 - cloud_cell_shadow : 1.0;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * min(glint, GLINT_CLAMP) * gate * cloud_lit;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * n_dot_l * diffuse_share * cloud_lit / PI;
}
