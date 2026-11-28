class_name JellyOrbArt
extends RefCounted

const PALETTE: Array[Color] = [
	Color("ff7595"),
	Color("72a7ff"),
	Color("59e2ab"),
	Color("ffe77a"),
	Color("bc86ff"),
	Color("ffad63"),
]
const LEVEL_LIGHTEN_AMOUNT: float = 0.018
const CAPTURE_ANIMATION_TIME: float = 4.25
const MAX_FACE_COLOR: Color = Color("1b1630")
const MAX_BLUSH_COLOR: Color = Color("ff4f7f")
const STONE_BODY_COLOR: Color = Color(0.55, 0.57, 0.60)
const MAX_EYE_CENTER_X: float = 0.26
const MAX_EYE_CENTER_Y: float = -0.08
const MAX_EYE_RADIUS_X: float = 0.09
const MAX_EYE_RADIUS_Y: float = 0.13
const MAX_HIGHLIGHT_LARGE_OFFSET: Vector2 = Vector2(-0.03, -0.06)
const MAX_HIGHLIGHT_LARGE_RADIUS: float = 0.04
const MAX_HIGHLIGHT_SMALL_OFFSET: Vector2 = Vector2(0.04, 0.06)
const MAX_HIGHLIGHT_SMALL_RADIUS: float = 0.02
const MAX_MOUTH_CENTER_Y: float = 0.14
const MAX_MOUTH_ARC_RADIUS: float = 0.06
const MAX_MOUTH_STROKE_WIDTH: float = 0.04
const MAX_BLUSH_CENTER_X: float = 0.46
const MAX_BLUSH_CENTER_Y: float = 0.16
const MAX_BLUSH_RADIUS_X: float = 0.12
const MAX_BLUSH_RADIUS_Y: float = 0.07
const MAX_BLUSH_ALPHA: float = 0.45
const NORMAL_HIGHLIGHT_Y: float = -0.075
const BLAST_EYE_OUTER_TOP: Vector2 = Vector2(0.32, -0.16)
const BLAST_EYE_INNER: Vector2 = Vector2(0.16, -0.04)
const BLAST_EYE_OUTER_BOTTOM: Vector2 = Vector2(0.32, 0.08)
const BLAST_EYE_STROKE_WIDTH: float = 0.064
const BLAST_MOUTH_CENTER: Vector2 = Vector2(0.0, 0.22)
const BLAST_MOUTH_RADII: Vector2 = Vector2(0.064, 0.076)
const BLAST_MOUTH_COLOR: Color = Color("3a1530")
const BLAST_BLUSH_CENTER: Vector2 = Vector2(0.48, 0.18)
const BLAST_BLUSH_RADII: Vector2 = Vector2(0.16, 0.10)
const BLAST_BLUSH_ALPHA: float = 0.60
const BELLY_CENTER: Vector2 = Vector2(0.12, 0.44)
const BELLY_RADIUS_SCALE: float = 0.54
const BELLY_LIGHTEN_AMOUNT: float = 0.35
const BELLY_ALPHA: float = 0.85
const BELLY_HIGHLIGHT_ALPHA: float = 0.70
const JELLY_BODY_LIGHT_MIX: float = 0.66
const JELLY_BODY_DEEP_SV: Vector2 = Vector2(1.20, 0.88)
const JELLY_BODY_EDGE_SV: Vector2 = Vector2(1.36, 0.79)
const JELLY_BODY_GRADIENT: Vector4 = Vector4(0.12, 0.28, 1.36, 0.50)
const JELLY_BODY_DEEP_STOP: float = 0.86
const JELLY_BODY_ALPHA: Vector4 = Vector4(0.95, 0.90, 0.93, 0.97)
# Ellipses store center and radii. Styles store angle, falloff bounds and opacity.
const JELLY_BODY_ELLIPSES: Array[Vector4] = [
	Vector4(0.12, 0.42, 0.60, 0.40),
	Vector4(0.50, 0.52, 0.16, 0.06),
	Vector4(-0.36, -0.50, 0.38, 0.20),
	Vector4(-0.50, -0.38, 0.10, 0.065),
	Vector4(-0.27, -0.66, 0.035, 0.035),
]
const JELLY_BODY_ELLIPSE_STYLES: Array[Vector4] = [
	Vector4(0.0, 0.55, 1.45, 0.55),
	Vector4(-45.0, 0.40, 1.60, 0.40),
	Vector4(-32.0, 0.80, 1.20, 0.50),
	Vector4(-32.0, 1.0, 1.0, 0.95),
	Vector4(0.0, 1.0, 1.0, 0.90),
]
const JELLY_BODY_SHADOW_OFFSET: float = 1.06
const JELLY_BODY_SHADOW_RADII: Vector2 = Vector2(0.78, 0.11)
const JELLY_BODY_SHADOW_FALLOFF: Vector2 = Vector2(0.64, 1.36)
const JELLY_BODY_SHADOW_ALPHA: float = 0.25
const TAP_SHEEN_ANGLE_DEGREES: float = 25.0
const TAP_SHEEN_PERIOD: float = 2.8
const TAP_SHEEN_SWEEP_FRACTION: float = 0.55
const TAP_SHEEN_TRAVEL: float = 2.0
const TAP_SHEEN_HALF_WIDTH: float = 0.60
const TAP_SHEEN_BRIGHTNESS: float = 0.50
const TAP_SHEEN_STREAK_OFFSET: float = 0.30
const TAP_SHEEN_STREAK_HALF_WIDTH: float = 0.025
const TAP_SHEEN_STREAK_BRIGHTNESS: float = 0.65
const TAP_SHEEN_PHASE_STEP: float = 0.7
const TAP_SHEEN_FADE_SECONDS: float = 0.15
const PREVIEW_TEXTURE_SIZE: int = 384
const PREVIEW_MAX_TEXTURE_SIZE: int = 512

static var _body_shader: Shader
static var _face_shader: Shader
static var _belly_shader: Shader
static var _shadow_material: ShaderMaterial
static var _body_materials: Dictionary = {}
static var _stone_body_materials: Dictionary = {}
static var _face_materials: Dictionary = {}
static var _belly_materials: Dictionary = {}
static var _preview_textures: Dictionary = {}
static var _face_mesh: ArrayMesh
static var _animation_time: float = 0.0
static var _animation_frozen: bool = false
static var _last_animation_frame: int = -1


static func color_for(color_index: int, level: int = 1) -> Color:
	var safe_color: int = clampi(color_index, 0, PALETTE.size() - 1)
	var safe_level: int = clampi(level, 1, Config.data.orb_max_level)
	var visual_level: float = 1.0
	if Config.data.orb_max_level > 1:
		visual_level += (
			float(safe_level - 1) * 6.0 / float(Config.data.orb_max_level - 1)
		)
	return PALETTE[safe_color].lightened(visual_level * LEVEL_LIGHTEN_AMOUNT)


static func prewarm(cfg: GameConfig) -> void:
	face_mesh()
	shadow_material()
	for color_index: int in range(PALETTE.size()):
		for level_index: int in range(1, cfg.orb_max_level + 1):
			body_material_for(color_index, level_index)
			face_material_for(color_index, level_index)
			belly_material_for(color_index, level_index)


static func clear_cache() -> void:
	_body_materials.clear()
	_stone_body_materials.clear()
	_face_materials.clear()
	_belly_materials.clear()
	_preview_textures.clear()
	_body_shader = null
	_face_shader = null
	_belly_shader = null
	_shadow_material = null
	_face_mesh = null
	_last_animation_frame = -1
	if not _animation_frozen:
		_animation_time = 0.0


static func shared_material_count() -> int:
	return (
		_body_materials.size()
		+ _stone_body_materials.size()
		+ _face_materials.size()
		+ _belly_materials.size()
		+ (1 if _shadow_material != null else 0)
	)


static func advance_animation(delta: float) -> void:
	if _animation_frozen:
		return
	var process_frame: int = Engine.get_process_frames()
	if process_frame == _last_animation_frame:
		return
	_last_animation_frame = process_frame
	_animation_time += maxf(delta, 0.0)
	_apply_animation_time()


static func freeze_animation_for_capture(time: float = CAPTURE_ANIMATION_TIME) -> void:
	_animation_frozen = true
	_animation_time = time
	_apply_animation_time()


static func unfreeze_animation() -> void:
	_animation_frozen = false
	_last_animation_frame = -1


static func animation_time() -> float:
	return _animation_time


static func preview_texture_for(color_index: int, level: int) -> Texture2D:
	var safe_color: int = clampi(color_index, 0, PALETTE.size() - 1)
	var safe_level: int = clampi(level, 1, Config.data.orb_max_level)
	var key: String = "%d:%d" % [safe_color, safe_level]
	return _preview_texture_for_base(key, safe_level, color_for(safe_color, safe_level))


static func stone_preview_texture_for(level: int) -> Texture2D:
	var safe_level: int = clampi(level, 1, Config.data.orb_max_level)
	return _preview_texture_for_base(
		"stone:%d" % safe_level,
		safe_level,
		STONE_BODY_COLOR
	)


static func _preview_texture_for_base(
	key: String,
	safe_level: int,
	base_color: Color
) -> Texture2D:
	if _preview_textures.has(key):
		return _preview_textures[key] as Texture2D
	var texture_size: int = (
		PREVIEW_MAX_TEXTURE_SIZE
		if safe_level == Config.data.orb_max_level
		else PREVIEW_TEXTURE_SIZE
	)
	var image: Image = Image.create(texture_size, texture_size, false, Image.FORMAT_RGBAF)
	image.fill(Color.TRANSPARENT)
	var pixel_step: float = 2.0 / float(texture_size)
	var light: Color = base_color.lerp(Color.WHITE, JELLY_BODY_LIGHT_MIX)
	var deep: Color = _body_hsv_color(base_color, JELLY_BODY_DEEP_SV)
	var edge: Color = _body_hsv_color(base_color, JELLY_BODY_EDGE_SV)
	var gradient_center: Vector2 = Vector2(JELLY_BODY_GRADIENT.x, JELLY_BODY_GRADIENT.y)
	for y: int in range(1, texture_size - 1):
		var unit_y: float = (float(y) + 0.5) * pixel_step - 1.0
		for x: int in range(1, texture_size - 1):
			var point: Vector2 = Vector2((float(x) + 0.5) * pixel_step - 1.0, unit_y)
			if point.length_squared() >= 1.0:
				continue
			var t: float = minf(point.distance_to(gradient_center) / JELLY_BODY_GRADIENT.z, 1.0)
			var color: Color
			if t < JELLY_BODY_GRADIENT.w:
				color = light.lerp(base_color, t / JELLY_BODY_GRADIENT.w)
			elif t < JELLY_BODY_DEEP_STOP:
				color = base_color.lerp(deep, inverse_lerp(JELLY_BODY_GRADIENT.w, JELLY_BODY_DEEP_STOP, t))
			else:
				color = deep.lerp(edge, inverse_lerp(JELLY_BODY_DEEP_STOP, 1.0, t))
			color.a = clampf((1.0 - point.length()) * float(texture_size) * 0.52, 0.0, 1.0)
			image.set_pixel(x, y, color)
	for index: int in range(JELLY_BODY_ELLIPSES.size()):
		_draw_preview_reflection(image, pixel_step, index, light if index == 0 else Color.WHITE)
	image.convert(Image.FORMAT_RGBA8)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_preview_textures[key] = texture
	return texture


static func _draw_preview_reflection(image: Image, pixel_step: float, index: int, tint: Color) -> void:
	var ellipse: Vector4 = JELLY_BODY_ELLIPSES[index]
	var style: Vector4 = JELLY_BODY_ELLIPSE_STYLES[index]
	var center: Vector2 = Vector2(ellipse.x, ellipse.y)
	var radii: Vector2 = Vector2(ellipse.z, ellipse.w)
	var axis: Vector2 = Vector2.from_angle(deg_to_rad(style.x))
	var hard_edge: bool = style.y == style.z
	var bound: float = maxf(radii.x, radii.y) * style.z + 2.0 * pixel_step
	var size: int = image.get_width()
	var first: Vector2i = Vector2i(((center + Vector2.ONE * (1.0 - bound)) / pixel_step).floor())
	var limit: Vector2i = Vector2i(((center + Vector2.ONE * (1.0 + bound)) / pixel_step).ceil())
	for y: int in range(maxi(0, first.y), mini(size, limit.y)):
		for x: int in range(maxi(0, first.x), mini(size, limit.x)):
			var offset: Vector2 = (Vector2(x, y) + Vector2.ONE * 0.5) * pixel_step - Vector2.ONE - center
			var q: Vector2 = Vector2(offset.dot(axis), offset.dot(axis.orthogonal())) / radii
			var distance: float = q.length()
			var lower: float = style.y
			var upper: float = style.z
			if hard_edge:
				var gradient: Vector2 = (q / radii).rotated(deg_to_rad(style.x)) / maxf(distance, 0.000001)
				var width: float = maxf((absf(gradient.x) + absf(gradient.y)) * pixel_step, 0.000001)
				lower -= width
				upper += width
			if distance >= upper:
				continue
			var color: Color = image.get_pixel(x, y)
			if color.a == 0.0:
				continue
			var result: Color = color.lerp(tint, style.w * (1.0 - smoothstep(lower, upper, distance)))
			result.a = color.a
			image.set_pixel(x, y, result)


static func _body_hsv_color(base: Color, sv: Vector2) -> Color:
	return Color.from_hsv(base.h, minf(1.0, base.s * sv.x), base.v * sv.y)


static func _new_body_material(name: String, base: Color, level: int) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.resource_name = name
	material.render_priority = 10
	material.shader = _get_body_shader()
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("light_color", base.lerp(Color.WHITE, JELLY_BODY_LIGHT_MIX))
	material.set_shader_parameter("deep_color", _body_hsv_color(base, JELLY_BODY_DEEP_SV))
	material.set_shader_parameter("edge_color", _body_hsv_color(base, JELLY_BODY_EDGE_SV))
	material.set_shader_parameter("body_gradient", JELLY_BODY_GRADIENT)
	material.set_shader_parameter("body_deep_stop", JELLY_BODY_DEEP_STOP)
	material.set_shader_parameter("body_alpha", JELLY_BODY_ALPHA)
	material.set_shader_parameter("body_ellipses", PackedVector4Array(JELLY_BODY_ELLIPSES))
	var styles: PackedVector4Array = PackedVector4Array()
	for style: Vector4 in JELLY_BODY_ELLIPSE_STYLES:
		styles.append(Vector4(deg_to_rad(style.x), style.y, style.z, style.w))
	material.set_shader_parameter("body_ellipse_styles", styles)
	material.set_shader_parameter("level_id", level)
	material.set_shader_parameter("max_level_id", Config.data.orb_max_level)
	material.set_shader_parameter("animation_time", _animation_time)
	return material


static func body_material_for(color_index: int, level: int) -> ShaderMaterial:
	var key: String = "%d:%d" % [color_index, level]
	if not _body_materials.has(key):
		var material: ShaderMaterial = _new_body_material(
			"jelly_body_c%d_l%d" % [color_index, level], color_for(color_index, level), level
		)
		material.set_shader_parameter(
			"tap_sheen_axis", Vector2.from_angle(deg_to_rad(TAP_SHEEN_ANGLE_DEGREES))
		)
		material.set_shader_parameter("tap_sheen_period", TAP_SHEEN_PERIOD)
		material.set_shader_parameter("tap_sheen_sweep_fraction", TAP_SHEEN_SWEEP_FRACTION)
		material.set_shader_parameter("tap_sheen_travel", TAP_SHEEN_TRAVEL)
		material.set_shader_parameter("tap_sheen_half_width", TAP_SHEEN_HALF_WIDTH)
		material.set_shader_parameter("tap_sheen_brightness", TAP_SHEEN_BRIGHTNESS)
		material.set_shader_parameter("tap_sheen_streak_offset", TAP_SHEEN_STREAK_OFFSET)
		material.set_shader_parameter("tap_sheen_streak_half_width", TAP_SHEEN_STREAK_HALF_WIDTH)
		material.set_shader_parameter("tap_sheen_streak_brightness", TAP_SHEEN_STREAK_BRIGHTNESS)
		material.set_shader_parameter("tap_sheen_phase", float(color_index) * TAP_SHEEN_PHASE_STEP)
		material.set_shader_parameter("tap_sheen_enabled", true)
		_body_materials[key] = material
	return _body_materials[key] as ShaderMaterial


static func stone_body_material(level: int) -> ShaderMaterial:
	var safe_level: int = clampi(level, 1, Config.data.orb_max_level)
	if not _stone_body_materials.has(safe_level):
		var material: ShaderMaterial = _new_body_material(
			"jelly_stone_body_l%d" % safe_level, STONE_BODY_COLOR, safe_level
		)
		material.set_shader_parameter("tap_sheen_phase", 0.0)
		material.set_shader_parameter("tap_sheen_enabled", false)
		_stone_body_materials[safe_level] = material
	return _stone_body_materials[safe_level] as ShaderMaterial


static func face_material_for(
	color_index: int,
	level: int,
	blast_ready: bool = false
) -> ShaderMaterial:
	var uses_sparkle_face: bool = blast_ready and level < Config.data.orb_max_level
	var uses_squeezed_face: bool = level >= Config.data.orb_max_level
	var key: String = "%d:%d:%s:%s" % [
		color_index,
		level,
		uses_sparkle_face,
		uses_squeezed_face,
	]
	if not _face_materials.has(key):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.resource_name = "jelly_face_c%d_l%d_sp%s_sq%s" % [
			color_index,
			level,
			uses_sparkle_face,
			uses_squeezed_face,
		]
		material.render_priority = 12
		material.shader = _get_face_shader()
		material.set_shader_parameter("jelly_color", color_for(color_index, level))
		material.set_shader_parameter("color_id", color_index)
		material.set_shader_parameter("is_sparkle_face", uses_sparkle_face)
		material.set_shader_parameter("is_squeezed_face", uses_squeezed_face)
		material.set_shader_parameter("max_face_color", MAX_FACE_COLOR)
		material.set_shader_parameter("max_blush_color", MAX_BLUSH_COLOR)
		material.set_shader_parameter("max_eye_x", MAX_EYE_CENTER_X)
		material.set_shader_parameter("max_eye_y", MAX_EYE_CENTER_Y)
		material.set_shader_parameter("max_eye_radii", Vector2(
			MAX_EYE_RADIUS_X,
			MAX_EYE_RADIUS_Y
		))
		material.set_shader_parameter("max_highlight_large_offset", MAX_HIGHLIGHT_LARGE_OFFSET)
		material.set_shader_parameter("max_highlight_large_radius", MAX_HIGHLIGHT_LARGE_RADIUS)
		material.set_shader_parameter("max_highlight_small_offset", MAX_HIGHLIGHT_SMALL_OFFSET)
		material.set_shader_parameter("max_highlight_small_radius", MAX_HIGHLIGHT_SMALL_RADIUS)
		material.set_shader_parameter("max_mouth_y", MAX_MOUTH_CENTER_Y)
		material.set_shader_parameter("max_mouth_radius", MAX_MOUTH_ARC_RADIUS)
		material.set_shader_parameter("max_mouth_width", MAX_MOUTH_STROKE_WIDTH)
		material.set_shader_parameter("max_blush_x", MAX_BLUSH_CENTER_X)
		material.set_shader_parameter("max_blush_y", MAX_BLUSH_CENTER_Y)
		material.set_shader_parameter("max_blush_radii", Vector2(
			MAX_BLUSH_RADIUS_X,
			MAX_BLUSH_RADIUS_Y
		))
		material.set_shader_parameter("max_blush_alpha", MAX_BLUSH_ALPHA)
		material.set_shader_parameter("blast_eye_outer_top", BLAST_EYE_OUTER_TOP)
		material.set_shader_parameter("blast_eye_inner", BLAST_EYE_INNER)
		material.set_shader_parameter("blast_eye_outer_bottom", BLAST_EYE_OUTER_BOTTOM)
		material.set_shader_parameter("blast_eye_stroke_width", BLAST_EYE_STROKE_WIDTH)
		material.set_shader_parameter("blast_mouth_center", BLAST_MOUTH_CENTER)
		material.set_shader_parameter("blast_mouth_radii", BLAST_MOUTH_RADII)
		material.set_shader_parameter("blast_mouth_color", BLAST_MOUTH_COLOR)
		material.set_shader_parameter("blast_blush_center", BLAST_BLUSH_CENTER)
		material.set_shader_parameter("blast_blush_radii", BLAST_BLUSH_RADII)
		material.set_shader_parameter("blast_blush_alpha", BLAST_BLUSH_ALPHA)
		material.set_shader_parameter("highlight_y", NORMAL_HIGHLIGHT_Y)
		material.set_shader_parameter("animation_time", _animation_time)
		_face_materials[key] = material
	return _face_materials[key] as ShaderMaterial


static func belly_material_for(color_index: int, level: int) -> ShaderMaterial:
	var key: String = "%d:%d" % [color_index, level]
	if not _belly_materials.has(key):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.resource_name = "jelly_belly_c%d_l%d" % [color_index, level]
		material.render_priority = 11
		material.shader = _get_belly_shader()
		material.set_shader_parameter(
			"belly_color",
			color_for(color_index, level).lightened(BELLY_LIGHTEN_AMOUNT)
		)
		material.set_shader_parameter("belly_center", BELLY_CENTER)
		material.set_shader_parameter("belly_radius_scale", BELLY_RADIUS_SCALE)
		material.set_shader_parameter("belly_alpha", BELLY_ALPHA)
		material.set_shader_parameter("highlight_alpha", BELLY_HIGHLIGHT_ALPHA)
		_belly_materials[key] = material
	return _belly_materials[key] as ShaderMaterial


static func face_mesh() -> ArrayMesh:
	if _face_mesh == null:
		_face_mesh = ArrayMesh.new()
		_face_mesh.resource_name = "jelly_face_billboard"
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
			Vector3(-1.0, 1.0, 0.0),
			Vector3(1.0, 1.0, 0.0),
			Vector3(1.0, -1.0, 0.0),
			Vector3(-1.0, -1.0, 0.0),
		])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
			Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD,
		])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(1.0, 0.0),
			Vector2(1.0, 1.0), Vector2(0.0, 1.0),
		])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		_face_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _face_mesh


static func _apply_animation_time() -> void:
	for value: Variant in _body_materials.values():
		(value as ShaderMaterial).set_shader_parameter("animation_time", _animation_time)
	for value: Variant in _stone_body_materials.values():
		(value as ShaderMaterial).set_shader_parameter("animation_time", _animation_time)
	for value: Variant in _face_materials.values():
		(value as ShaderMaterial).set_shader_parameter("animation_time", _animation_time)


static func shadow_material() -> ShaderMaterial:
	if _shadow_material != null:
		return _shadow_material
	var shader: Shader = Shader.new()
	shader.resource_name = "jelly_shadow_shader"
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec2 shadow_falloff;
uniform float shadow_alpha;
instance uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
instance uniform float shadow_visual_alpha = 1.0;

void fragment() {
	float distance = length(UV * 2.0 - 1.0) * shadow_falloff.y;
	ALBEDO = shadow_color.rgb;
	ALPHA = shadow_alpha * (1.0 - smoothstep(shadow_falloff.x, shadow_falloff.y, distance))
		* shadow_visual_alpha;
}
"""
	_shadow_material = ShaderMaterial.new()
	_shadow_material.resource_name = "jelly_shadow_material"
	_shadow_material.render_priority = 9
	_shadow_material.shader = shader
	_shadow_material.set_shader_parameter("shadow_falloff", JELLY_BODY_SHADOW_FALLOFF)
	_shadow_material.set_shader_parameter("shadow_alpha", JELLY_BODY_SHADOW_ALPHA)
	return _shadow_material


static func _get_body_shader() -> Shader:
	if _body_shader != null:
		return _body_shader
	_body_shader = Shader.new()
	_body_shader.resource_name = "jelly_body_shader"
	_body_shader.code = """
shader_type spatial;
render_mode unshaded, depth_prepass_alpha, cull_back;

uniform vec4 base_color : source_color;
uniform vec4 light_color : source_color;
uniform vec4 deep_color : source_color;
uniform vec4 edge_color : source_color;
uniform vec4 body_gradient;
uniform float body_deep_stop;
uniform vec4 body_alpha;
uniform vec4 body_ellipses[5];
uniform vec4 body_ellipse_styles[5];
uniform int level_id = 1;
uniform int max_level_id = 10;
uniform float animation_time = 0.0;
uniform bool tap_sheen_enabled = false;
uniform vec2 tap_sheen_axis;
uniform float tap_sheen_period;
uniform float tap_sheen_sweep_fraction;
uniform float tap_sheen_travel;
uniform float tap_sheen_half_width;
uniform float tap_sheen_brightness;
uniform float tap_sheen_streak_offset;
uniform float tap_sheen_streak_half_width;
uniform float tap_sheen_streak_brightness;
uniform float tap_sheen_phase = 0.0;
instance uniform float tap_sheen_strength = 0.0;
varying float sphere_radius;
varying vec3 sphere_center_view;

void vertex() {
	sphere_radius = length(VERTEX);
	sphere_center_view = MODELVIEW_MATRIX[3].xyz;
}

float ellipse_distance(vec2 p, vec4 ellipse, float angle) {
	vec2 offset = p - ellipse.xy;
	float cosine = cos(angle);
	float sine = sin(angle);
	vec2 rotated = vec2(dot(offset, vec2(cosine, sine)), dot(offset, vec2(-sine, cosine)));
	return length(rotated / ellipse.zw);
}

float soft_reflection(vec2 p, int index) {
	vec4 style = body_ellipse_styles[index];
	float distance = ellipse_distance(p, body_ellipses[index], style.x);
	return style.w * (1.0 - smoothstep(style.y, style.z, distance));
}

float sharp_reflection(vec2 p, int index) {
	vec4 style = body_ellipse_styles[index];
	float distance = ellipse_distance(p, body_ellipses[index], style.x);
	float width = max(fwidth(distance), 0.000001);
	return style.w * (1.0 - smoothstep(style.y - width, style.z + width, distance));
}

void fragment() {
	// Project the surface and center on the screen axes in radii at the center depth.
	vec2 offset = VERTEX.xy - sphere_center_view.xy;
	if (PROJECTION_MATRIX[3][3] == 0.0) {
		offset = VERTEX.xy * (sphere_center_view.z / VERTEX.z) - sphere_center_view.xy;
	}
	vec2 p = offset * vec2(1.0, -1.0) / sphere_radius;
	float t = min(1.0, length(p - body_gradient.xy) / body_gradient.z);
	vec4 body;
	if (t < body_gradient.w) {
		body = mix(vec4(light_color.rgb, body_alpha.x), vec4(base_color.rgb, body_alpha.y),
			t / body_gradient.w);
	} else if (t < body_deep_stop) {
		body = mix(vec4(base_color.rgb, body_alpha.y), vec4(deep_color.rgb, body_alpha.z),
			(t - body_gradient.w) / (body_deep_stop - body_gradient.w));
	} else {
		body = mix(vec4(deep_color.rgb, body_alpha.z), vec4(edge_color.rgb, body_alpha.w),
			(t - body_deep_stop) / (1.0 - body_deep_stop));
	}
	vec3 color = mix(body.rgb, light_color.rgb, soft_reflection(p, 0));
	color = mix(color, vec3(1.0), soft_reflection(p, 1));
	color = mix(color, vec3(1.0), soft_reflection(p, 2));
	if (tap_sheen_enabled && tap_sheen_strength > 0.0) {
		float cycle = fract((animation_time + tap_sheen_phase) / tap_sheen_period);
		float progress = min(1.0, cycle / tap_sheen_sweep_fraction);
		float center = mix(-tap_sheen_travel, tap_sheen_travel, smoothstep(0.0, 1.0, progress));
		float d = dot(p, tap_sheen_axis) - center;
		float broad = tap_sheen_brightness * max(0.0, 1.0 - abs(d) / tap_sheen_half_width);
		float streak = tap_sheen_streak_brightness
			* max(0.0, 1.0 - abs(d - tap_sheen_streak_offset) / tap_sheen_streak_half_width);
		color = mix(color, vec3(1.0), broad * tap_sheen_strength);
		color = mix(color, vec3(1.0), streak * tap_sheen_strength);
	}
	color = mix(color, vec3(1.0), sharp_reflection(p, 3));
	color = mix(color, vec3(1.0), sharp_reflection(p, 4));
	if (level_id >= max_level_id) {
		float rim = pow(1.0 - clamp(normalize(NORMAL).z, 0.0, 1.0), 2.2);
		float max_pulse = 0.5 + 0.5 * sin(animation_time * 2.15);
		color += vec3(1.0) * rim * max_pulse * 0.30;
	}
	ALBEDO = color;
	ALPHA = body.a;
}
"""
	return _body_shader


static func _get_face_shader() -> Shader:
	if _face_shader != null:
		return _face_shader
	_face_shader = Shader.new()
	_face_shader.resource_name = "jelly_face_shader"
	_face_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform vec4 jelly_color : source_color = vec4(1.0);
uniform int color_id = 0;
uniform bool is_sparkle_face = false;
uniform bool is_squeezed_face = false;
uniform float animation_time = 0.0;
uniform vec4 max_face_color : source_color = vec4(0.106, 0.086, 0.188, 1.0);
uniform vec4 max_blush_color : source_color = vec4(1.0, 0.31, 0.50, 1.0);
uniform float max_eye_x = 0.26;
uniform float max_eye_y = -0.08;
uniform vec2 max_eye_radii = vec2(0.09, 0.13);
uniform vec2 max_highlight_large_offset = vec2(-0.03, -0.06);
uniform float max_highlight_large_radius = 0.04;
uniform vec2 max_highlight_small_offset = vec2(0.04, 0.06);
uniform float max_highlight_small_radius = 0.02;
uniform float max_mouth_y = 0.14;
uniform float max_mouth_radius = 0.06;
uniform float max_mouth_width = 0.04;
uniform float max_blush_x = 0.46;
uniform float max_blush_y = 0.16;
uniform vec2 max_blush_radii = vec2(0.12, 0.07);
uniform float max_blush_alpha = 0.45;
uniform vec2 blast_eye_outer_top = vec2(0.32, -0.16);
uniform vec2 blast_eye_inner = vec2(0.16, -0.04);
uniform vec2 blast_eye_outer_bottom = vec2(0.32, 0.08);
uniform float blast_eye_stroke_width = 0.064;
uniform vec2 blast_mouth_center = vec2(0.0, 0.22);
uniform vec2 blast_mouth_radii = vec2(0.064, 0.076);
uniform vec4 blast_mouth_color : source_color = vec4(0.227, 0.082, 0.188, 1.0);
uniform vec2 blast_blush_center = vec2(0.48, 0.18);
uniform vec2 blast_blush_radii = vec2(0.16, 0.10);
uniform float blast_blush_alpha = 0.60;
uniform float highlight_y = -0.075;

float capsule(vec2 p, vec2 a, vec2 b, float radius) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - radius;
}

float circle_mask(vec2 p, vec2 center, float radius, float feather) {
	return 1.0 - smoothstep(radius - feather, radius + feather, length(p - center));
}

float ellipse_mask(vec2 p, vec2 center, vec2 radii, float feather) {
	float radial = length((p - center) / radii);
	return 1.0 - smoothstep(1.0 - feather, 1.0 + feather, radial);
}

float lower_arc_mask(vec2 p, vec2 center, float radius, float width) {
	float ring_distance = abs(length(p - center) - radius);
	float ring = 1.0 - smoothstep(width * 0.5 - 0.008, width * 0.5 + 0.008, ring_distance);
	float lower_half = smoothstep(center.y - 0.008, center.y + 0.008, p.y);
	return ring * lower_half;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float blink_wave = sin(animation_time * 2.35 + float(color_id) * 0.91);
	float blink = smoothstep(0.965, 0.997, blink_wave);
	float eye_height = mix(0.22, 0.018, blink);
	float left_eye = 0.0;
	float right_eye = 0.0;
	float smile = 0.0;
	float blast_mouth = 0.0;
	float blush = 0.0;
	float max_highlight = 0.0;
	if (is_sparkle_face) {
		vec2 left_center = vec2(-max_eye_x, max_eye_y);
		vec2 right_center = vec2(max_eye_x, max_eye_y);
		float left_open = ellipse_mask(p, left_center, max_eye_radii, 0.08);
		float right_open = ellipse_mask(p, right_center, max_eye_radii, 0.08);
		float left_closed = 1.0 - smoothstep(-0.008, 0.008,
			capsule(p, left_center - vec2(max_eye_radii.x, 0.0), left_center + vec2(max_eye_radii.x, 0.0), max_mouth_width * 0.5));
		float right_closed = 1.0 - smoothstep(-0.008, 0.008,
			capsule(p, right_center - vec2(max_eye_radii.x, 0.0), right_center + vec2(max_eye_radii.x, 0.0), max_mouth_width * 0.5));
		left_eye = mix(left_open, left_closed, blink);
		right_eye = mix(right_open, right_closed, blink);
		float eye_open = 1.0 - blink;
		max_highlight = (
			circle_mask(p, left_center + max_highlight_large_offset, max_highlight_large_radius, 0.008)
			+ circle_mask(p, left_center + max_highlight_small_offset, max_highlight_small_radius, 0.006)
			+ circle_mask(p, right_center + max_highlight_large_offset, max_highlight_large_radius, 0.008)
			+ circle_mask(p, right_center + max_highlight_small_offset, max_highlight_small_radius, 0.006)
		) * eye_open;
		vec2 left_mouth_center = vec2(-max_mouth_radius, max_mouth_y);
		vec2 right_mouth_center = vec2(max_mouth_radius, max_mouth_y);
		smile = max(
			lower_arc_mask(p, left_mouth_center, max_mouth_radius, max_mouth_width),
			lower_arc_mask(p, right_mouth_center, max_mouth_radius, max_mouth_width)
		);
		smile = max(smile, circle_mask(p, vec2(-max_mouth_radius * 2.0, max_mouth_y), max_mouth_width * 0.5, 0.008));
		smile = max(smile, circle_mask(p, vec2(0.0, max_mouth_y), max_mouth_width * 0.5, 0.008));
		smile = max(smile, circle_mask(p, vec2(max_mouth_radius * 2.0, max_mouth_y), max_mouth_width * 0.5, 0.008));
		blush = ellipse_mask(p, vec2(-max_blush_x, max_blush_y), max_blush_radii, 0.12)
			+ ellipse_mask(p, vec2(max_blush_x, max_blush_y), max_blush_radii, 0.12);
	} else if (is_squeezed_face) {
		float stroke_radius = blast_eye_stroke_width * 0.5;
		vec2 left_outer_top = vec2(-blast_eye_outer_top.x, blast_eye_outer_top.y);
		vec2 left_inner = vec2(-blast_eye_inner.x, blast_eye_inner.y);
		vec2 left_outer_bottom = vec2(-blast_eye_outer_bottom.x, blast_eye_outer_bottom.y);
		left_eye = max(
			1.0 - smoothstep(-0.008, 0.008, capsule(p, left_outer_top, left_inner, stroke_radius)),
			1.0 - smoothstep(-0.008, 0.008, capsule(p, left_inner, left_outer_bottom, stroke_radius))
		);
		right_eye = max(
			1.0 - smoothstep(-0.008, 0.008, capsule(p, blast_eye_outer_top, blast_eye_inner, stroke_radius)),
			1.0 - smoothstep(-0.008, 0.008, capsule(p, blast_eye_inner, blast_eye_outer_bottom, stroke_radius))
		);
		blast_mouth = ellipse_mask(p, blast_mouth_center, blast_mouth_radii, 0.12);
		blush = ellipse_mask(
			p,
			vec2(-blast_blush_center.x, blast_blush_center.y),
			blast_blush_radii,
			0.12
		) + ellipse_mask(p, blast_blush_center, blast_blush_radii, 0.12);
	} else {
		left_eye = 1.0 - smoothstep(-0.015, 0.015,
			capsule(p, vec2(-0.25, -eye_height), vec2(-0.25, eye_height), 0.105));
		right_eye = 1.0 - smoothstep(-0.015, 0.015,
			capsule(p, vec2(0.25, -eye_height), vec2(0.25, eye_height), 0.105));
	}
	float eyes = clamp(left_eye + right_eye, 0.0, 1.0);
	float highlight = 0.0;
	if (!is_sparkle_face && !is_squeezed_face && blink < 0.72) {
		highlight = circle_mask(p, vec2(-0.285, highlight_y), 0.034, 0.012)
			+ circle_mask(p, vec2(0.215, highlight_y), 0.034, 0.012);
	}
	float blush_alpha = is_squeezed_face ? blast_blush_alpha : max_blush_alpha;
	float alpha = clamp(
		eyes + smile + blast_mouth + blush * blush_alpha + highlight + max_highlight,
		0.0,
		1.0
	);
	vec3 dark = mix(vec3(0.055, 0.065, 0.11), jelly_color.rgb * 0.20, 0.22);
	if (is_sparkle_face || is_squeezed_face) {
		dark = max_face_color.rgb;
	}
	vec3 face_color = mix(dark, vec3(1.0), clamp(highlight, 0.0, 1.0));
	face_color = mix(face_color, blast_mouth_color.rgb, clamp(blast_mouth, 0.0, 1.0));
	float other_feature = clamp(eyes + smile + blast_mouth + highlight + max_highlight, 0.0, 1.0);
	float blush_color_mask = clamp(blush, 0.0, 1.0) * (1.0 - other_feature);
	face_color = mix(face_color, max_blush_color.rgb, blush_color_mask);
	face_color = mix(face_color, vec3(1.0), clamp(max_highlight, 0.0, 1.0));
	ALBEDO = face_color;
	EMISSION = face_color * 0.08;
	ALPHA = alpha;
}
"""
	return _face_shader


static func _get_belly_shader() -> Shader:
	if _belly_shader != null:
		return _belly_shader
	_belly_shader = Shader.new()
	_belly_shader.resource_name = "jelly_belly_shader"
	_belly_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform vec4 belly_color : source_color = vec4(1.0);
uniform vec2 belly_center = vec2(0.12, 0.44);
uniform float belly_radius_scale = 0.54;
uniform float belly_alpha = 0.85;
uniform float highlight_alpha = 0.70;
instance uniform float fill_fraction = 0.0;
instance uniform float visual_alpha = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float fraction = clamp(fill_fraction, 0.0, 0.999999);
	float radius = belly_radius_scale * sqrt(fraction);
	vec2 local = (p - belly_center) / max(radius, 0.000001);
	float belly_distance = length(local);
	float body_distance = length(p);
	float belly_width = max(fwidth(belly_distance), 0.000001);
	float body_width = max(fwidth(body_distance), 0.000001);
	float belly_mask = 1.0 - smoothstep(1.0 - belly_width, 1.0 + belly_width, belly_distance);
	float body_mask = 1.0 - smoothstep(1.0 - body_width, 1.0 + body_width, body_distance);
	float z = sqrt(max(1.0 - dot(local, local), 0.0));
	vec3 normal = normalize(vec3(local.x, -local.y, z));
	vec3 light_dir = normalize(vec3(-0.24, 0.66, 0.71));
	vec3 half_dir = normalize(light_dir + vec3(0.0, 0.0, 1.0));
	float reflection = pow(max(dot(normal, half_dir), 0.0), 72.0);
	vec3 color = mix(belly_color.rgb, vec3(1.0), reflection * highlight_alpha);
	ALBEDO = color;
	EMISSION = color * 0.08;
	ALPHA = belly_mask * body_mask * belly_alpha * visual_alpha;
}
"""
	return _belly_shader
