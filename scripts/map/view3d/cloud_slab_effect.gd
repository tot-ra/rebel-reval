extends CompositorEffect

## R-1873 high sky tier: renders the ray-marched cumulus slab (cloud_slab.glsl) at a
## quarter of the screen pixels with temporal reprojection, before the opaque pass, into
## `output` (a Texture2DRD the sky shader samples as `cloud_slab_tex`).
##
## WHY a compositor pass: Godot sky shaders have no history buffer, and the slab at full
## resolution cost ~8.6 ms (R-1768 spike). A compute pass can keep last frame's result,
## march one jittered ray per 2x2 pixels and let the history average the jitter out.
##
## Texels are indexed by world direction through the camera basis and tangents pushed by
## SkyWeather3D.update_cloud_slab() (on the render thread, in order with the material
## uniforms that carry the same matrices), so dome and slab can never disagree on where
## a cloud sits, whatever the framebuffer orientation.

const SHADER_FILE := preload("res://scripts/map/view3d/cloud_slab.glsl")
const GROUP := 8
## Weight of this frame's sample in the history blend (~10 frames of accumulation).
const HISTORY_BLEND := 0.1
## Extra field of view around the screen, so a lookup one frame stale still lands inside.
const MARGIN := 1.08
## Two mat4 and seven vec4 rows of the std140 Params block in cloud_slab.glsl.
const PARAMS_BYTES := 64 * 2 + 16 * 7

## Sampled by the sky shader. Its RD texture is replaced when the viewport size changes.
var output := Texture2DRD.new()

var _rd: RenderingDevice
var _march_shader := RID()
var _resolve_shader := RID()
var _march_pipeline := RID()
var _resolve_pipeline := RID()
var _params_buffer := RID()
var _linear_sampler := RID()
## Trilinear, wrapping: the cloud noise textures tile like in the sky shader.
var _repeat_sampler := RID()
var _cur := RID()
var _hist := RID()
var _out := RID()
var _size := Vector2i.ZERO
var _history_valid := false
var _frame := 0
var _prev_basis := Basis.IDENTITY
var _prev_tan := Vector2.ONE
## Render-thread copy of the latest SkyWeather3D parameters (set_params).
var _params: Dictionary = {}
## RIDs replaced on resize, freed once the sky material has moved to the new texture.
var _retired: Array[RID] = []
var _retire_countdown := 0


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_PRE_OPAQUE
	_rd = RenderingServer.get_rendering_device()
	if _rd != null:
		RenderingServer.call_on_render_thread(_create_pipelines)


## False on renderers without a RenderingDevice (Compatibility, headless dummy) or when
## the shader failed to compile; the sky then keeps the lit 2.5D deck.
func is_supported() -> bool:
	return _rd != null and _march_pipeline.is_valid() and _resolve_pipeline.is_valid()


static func renderer_supported() -> bool:
	return RenderingServer.get_rendering_device() != null


## Called on the render thread (RenderingServer.call_on_render_thread) every frame.
func set_params(params: Dictionary) -> void:
	_params = params


## Drops the history, e.g. after the effect was off or the camera cut.
func reset_history() -> void:
	_history_valid = false


func _create_pipelines() -> void:
	var march_spirv: RDShaderSPIRV = SHADER_FILE.get_spirv(&"march")
	var resolve_spirv: RDShaderSPIRV = SHADER_FILE.get_spirv(&"resolve")
	if march_spirv == null or resolve_spirv == null:
		push_error("CloudSlabEffect: cloud_slab.glsl has no march/resolve versions")
		return
	if not (march_spirv.compile_error_compute.is_empty()
			and resolve_spirv.compile_error_compute.is_empty()):
		push_error("CloudSlabEffect: %s %s" % [
			march_spirv.compile_error_compute, resolve_spirv.compile_error_compute])
		return
	_march_shader = _rd.shader_create_from_spirv(march_spirv)
	_resolve_shader = _rd.shader_create_from_spirv(resolve_spirv)
	_march_pipeline = _rd.compute_pipeline_create(_march_shader)
	_resolve_pipeline = _rd.compute_pipeline_create(_resolve_shader)
	_params_buffer = _rd.uniform_buffer_create(PARAMS_BYTES)
	var sampler := RDSamplerState.new()
	sampler.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_linear_sampler = _rd.sampler_create(sampler)
	var repeat := RDSamplerState.new()
	repeat.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	repeat.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	repeat.mip_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	repeat.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	repeat.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	repeat.repeat_w = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	_repeat_sampler = _rd.sampler_create(repeat)


func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if callback_type != EFFECT_CALLBACK_TYPE_PRE_OPAQUE or not is_supported() or _params.is_empty():
		return
	var buffers := render_data.get_render_scene_buffers()
	if buffers == null:
		return
	var full: Vector2i = buffers.get_internal_size()
	if full.x <= 0 or full.y <= 0:
		return
	var size := Vector2i((full.x + 1) / 2, (full.y + 1) / 2)
	# A target freed under us (renderer teardown) is rebuilt instead of bound invalid.
	if size != _size or not _rd.texture_is_valid(_cur):
		_resize(size)
	var shape: Texture2D = _params.get("shape")
	var noise: Texture2D = _params.get("noise")
	var cells: Texture3D = _params.get("cell_noise")
	if shape == null or noise == null or cells == null:
		return
	var shape_rd := RenderingServer.texture_get_rd_texture(shape.get_rid())
	var noise_rd := RenderingServer.texture_get_rd_texture(noise.get_rid())
	var cells_rd := RenderingServer.texture_get_rd_texture(cells.get_rid())
	if not (shape_rd.is_valid() and noise_rd.is_valid() and cells_rd.is_valid()):
		return
	_free_retired()
	var basis: Basis = _params["basis"]
	var tan_half: Vector2 = _params["tan"]
	_rd.buffer_update(_params_buffer, 0, PARAMS_BYTES, _pack_params(basis, tan_half, size, full))

	var groups := Vector3i((size.x + GROUP - 1) / GROUP, (size.y + GROUP - 1) / GROUP, 1)
	var march_set := UniformSetCacheRD.get_cache(_march_shader, 0, [
		_ubo(0, _params_buffer),
		_texture(1, shape_rd, _repeat_sampler),
		_texture(2, noise_rd, _repeat_sampler),
		_texture(3, cells_rd, _repeat_sampler),
		_image(4, _cur),
	])
	var resolve_set := UniformSetCacheRD.get_cache(_resolve_shader, 0, [
		_ubo(0, _params_buffer),
		_texture(1, _cur, _linear_sampler),
		_texture(2, _hist, _linear_sampler),
		_image(3, _out),
	])
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list, _march_pipeline)
	_rd.compute_list_bind_uniform_set(list, march_set, 0)
	_rd.compute_list_dispatch(list, groups.x, groups.y, 1)
	_rd.compute_list_add_barrier(list)
	_rd.compute_list_bind_compute_pipeline(list, _resolve_pipeline)
	_rd.compute_list_bind_uniform_set(list, resolve_set, 0)
	_rd.compute_list_dispatch(list, groups.x, groups.y, 1)
	_rd.compute_list_end()
	# The resolved frame becomes next frame's history.
	_rd.texture_copy(_out, _hist, Vector3.ZERO, Vector3.ZERO,
		Vector3(size.x, size.y, 1), 0, 0, 0, 0)
	_history_valid = true
	_prev_basis = basis
	_prev_tan = tan_half
	_frame += 1


func _pack_params(
	basis: Basis, tan_half: Vector2, size: Vector2i, full: Vector2i
) -> PackedByteArray:
	var f := PackedFloat32Array()
	# mat4 view_to_world: columns are the camera's x, y, z axes.
	for axis in [basis.x, basis.y, basis.z]:
		f.append_array([axis.x, axis.y, axis.z, 0.0])
	f.append_array([0.0, 0.0, 0.0, 1.0])
	# mat4 prev_world_to_view = transpose(prev basis): column k holds row k of the basis.
	var prev_t := _prev_basis.transposed()
	for axis in [prev_t.x, prev_t.y, prev_t.z]:
		f.append_array([axis.x, axis.y, axis.z, 0.0])
	f.append_array([0.0, 0.0, 0.0, 1.0])
	f.append_array([tan_half.x, tan_half.y, float(size.x), float(size.y)])
	f.append_array([_prev_tan.x, _prev_tan.y, 1.0 if _history_valid else 0.0, float(_frame % 1024)])
	f.append_array(_params["cloud"] as PackedFloat32Array)
	f.append_array(_params["offsets"] as PackedFloat32Array)
	var sun: Vector3 = _params["sun"]
	f.append_array([sun.x, sun.y, sun.z, float(_params["steps"])])
	var wind: Vector2 = _params["wind"]
	# Angle of one full-res pixel, for the texture LOD and fine-octave fade.
	var pixel_angle := 2.0 * tan_half.y / MARGIN / float(full.y)
	f.append_array([wind.x, wind.y, pixel_angle, HISTORY_BLEND])
	f.append_array(_params["tex_sizes"] as PackedFloat32Array)
	return f.to_byte_array()


func _resize(size: Vector2i) -> void:
	for rid in [_cur, _hist, _out]:
		if rid.is_valid():
			_retired.append(rid)
	var format := RDTextureFormat.new()
	format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format.width = size.x
	format.height = size.y
	format.usage_bits = (RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT)
	_cur = _rd.texture_create(format, RDTextureView.new())
	_hist = _rd.texture_create(format, RDTextureView.new())
	_out = _rd.texture_create(format, RDTextureView.new())
	for rid in [_cur, _hist, _out]:
		_rd.texture_clear(rid, Color(0, 0, 0, 0), 0, 1, 0, 1)
	_size = size
	_history_valid = false
	# Texture2DRD is a main-thread resource; swap it there. The old textures stay alive
	# a few frames (see _free_retired) until no frame in flight samples them.
	output.set_deferred(&"texture_rd_rid", _out)
	_retire_countdown = 4


func _free_retired() -> void:
	if _retired.is_empty():
		return
	_retire_countdown -= 1
	if _retire_countdown > 0:
		return
	for rid in _retired:
		if rid.is_valid():
			_rd.free_rid(rid)
	_retired.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd != null:
		var rids: Array[RID] = [_cur, _hist, _out, _params_buffer, _linear_sampler, _repeat_sampler,
			_march_pipeline, _resolve_pipeline, _march_shader, _resolve_shader]
		rids.append_array(_retired)
		var rd := _rd
		RenderingServer.call_on_render_thread(func() -> void:
			for rid in rids:
				if rid.is_valid():
					rd.free_rid(rid)
		)


## Bench only (capture_sky_reference.gd --slab-cost): runs march + resolve `iterations`
## times on a local RenderingDevice with the live parameters, each submitted and synced on
## its own, and returns the fastest pass in ms. Metal exposes no GPU timestamps, and in a
## running frame the pass overlaps other work, so this isolates its GPU cost.
func measure_local_gpu(size: Vector2i, iterations: int) -> float:
	if _params.is_empty():
		return -1.0
	var rd := RenderingServer.create_local_rendering_device()
	if rd == null:
		return -1.0
	var march := rd.shader_create_from_spirv(SHADER_FILE.get_spirv(&"march"))
	var resolve := rd.shader_create_from_spirv(SHADER_FILE.get_spirv(&"resolve"))
	var march_pipe := rd.compute_pipeline_create(march)
	var resolve_pipe := rd.compute_pipeline_create(resolve)
	var ubo := rd.uniform_buffer_create(PARAMS_BYTES)
	var full := size * 2
	_prev_basis = _params["basis"]
	_prev_tan = _params["tan"]
	_history_valid = true
	rd.buffer_update(ubo, 0, PARAMS_BYTES, _pack_params(_params["basis"], _params["tan"], size, full))
	var repeat_state := RDSamplerState.new()
	repeat_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	repeat_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	repeat_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	repeat_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	repeat_state.repeat_w = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	var repeat_sampler := rd.sampler_create(repeat_state)
	var clamp_sampler := rd.sampler_create(RDSamplerState.new())
	var shape := _local_texture_2d(rd, (_params["shape"] as Texture2D).get_image())
	var noise := _local_texture_2d(rd, (_params["noise"] as Texture2D).get_image())
	var cells := _local_texture_3d(rd, (_params["cell_noise"] as Texture3D).get_data())
	var format := RDTextureFormat.new()
	format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format.width = size.x
	format.height = size.y
	format.usage_bits = (RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT)
	var cur := rd.texture_create(format, RDTextureView.new())
	var hist := rd.texture_create(format, RDTextureView.new())
	var out := rd.texture_create(format, RDTextureView.new())
	var march_set := rd.uniform_set_create([_ubo(0, ubo), _texture(1, shape, repeat_sampler),
		_texture(2, noise, repeat_sampler), _texture(3, cells, repeat_sampler), _image(4, cur)], march, 0)
	var resolve_set := rd.uniform_set_create([_ubo(0, ubo), _texture(1, cur, clamp_sampler),
		_texture(2, hist, clamp_sampler), _image(3, out)], resolve, 0)
	var groups := Vector2i((size.x + GROUP - 1) / GROUP, (size.y + GROUP - 1) / GROUP)
	var best := INF
	for i in iterations + 3:
		var start := Time.get_ticks_usec()
		var list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(list, march_pipe)
		rd.compute_list_bind_uniform_set(list, march_set, 0)
		rd.compute_list_dispatch(list, groups.x, groups.y, 1)
		rd.compute_list_add_barrier(list)
		rd.compute_list_bind_compute_pipeline(list, resolve_pipe)
		rd.compute_list_bind_uniform_set(list, resolve_set, 0)
		rd.compute_list_dispatch(list, groups.x, groups.y, 1)
		rd.compute_list_end()
		rd.submit()
		rd.sync()
		# The first runs warm caches and pipelines up.
		if i >= 3:
			best = minf(best, float(Time.get_ticks_usec() - start) / 1000.0)
	rd.free()
	return best


static func _local_texture_2d(rd: RenderingDevice, image: Image) -> RID:
	var img := image.duplicate() as Image
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	var format := RDTextureFormat.new()
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	format.width = img.get_width()
	format.height = img.get_height()
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	return rd.texture_create(format, RDTextureView.new(), [img.get_data()])


static func _local_texture_3d(rd: RenderingDevice, slices: Array[Image]) -> RID:
	var data := PackedByteArray()
	for slice in slices:
		var img := slice.duplicate() as Image
		img.convert(Image.FORMAT_L8)
		data.append_array(img.get_data())
	var format := RDTextureFormat.new()
	format.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	format.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	format.width = slices[0].get_width()
	format.height = slices[0].get_height()
	format.depth = slices.size()
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	return rd.texture_create(format, RDTextureView.new(), [data])


static func _ubo(binding: int, buffer: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	u.binding = binding
	u.add_id(buffer)
	return u


static func _texture(binding: int, texture: RID, sampler: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(sampler)
	u.add_id(texture)
	return u


static func _image(binding: int, texture: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(texture)
	return u
