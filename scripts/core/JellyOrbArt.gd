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
const PREVIEW_TEXTURE_SIZE: int = 384
const PREVIEW_MAX_TEXTURE_SIZE: int = 512

static var _body_shader: Shader
static var _face_shader: Shader
static var _outline_shader: Shader
static var _body_materials: Dictionary = {}
static var _face_materials: Dictionary = {}
static var _outline_materials: Dictionary = {}
static var _preview_textures: Dictionary = {}
static var _face_mesh: ArrayMesh
static var _animation_time: float = 0.0
static var _animation_frozen: bool = false
static var _last_animation_frame: int = -1


static func color_for(color_index: int, level: int = 1) -> Color:
	var safe_color: int = clampi(color_index, 0, PALETTE.size() - 1)
	var safe_level: int = maxi(level, 1)
	return PALETTE[safe_color].lightened(float(safe_level) * LEVEL_LIGHTEN_AMOUNT)


static func prewarm(cfg: GameConfig) -> void:
	face_mesh()
	for color_index: int in range(PALETTE.size()):
		for level_index: int in range(1, cfg.orb_max_level + 1):
			body_material_for(color_index, level_index)
			face_material_for(color_index, level_index)
			outline_material_for(color_index, level_index)


static func clear_cache() -> void:
	_body_materials.clear()
	_face_materials.clear()
	_outline_materials.clear()
	_preview_textures.clear()
	_body_shader = null
	_face_shader = null
	_outline_shader = null
	_face_mesh = null
	_last_animation_frame = -1
	if not _animation_frozen:
		_animation_time = 0.0


static func shared_material_count() -> int:
	return _body_materials.size() + _face_materials.size() + _outline_materials.size()


static func advance_animation(delta: float) -> void:
	if _animation_frozen:
		return
	var process_frame: int = Engine.get_process_frames()
	if process_frame == _last_animation_frame:
		return
	_last_animation_frame = process_frame
	_animation_time += maxf(delta, 0.0)
	_apply_animation_time()


static func freeze_animation_for_capture() -> void:
	_animation_frozen = true
	_animation_time = CAPTURE_ANIMATION_TIME
	_apply_animation_time()


static func unfreeze_animation() -> void:
	_animation_frozen = false
	_last_animation_frame = -1


static func animation_time() -> float:
	return _animation_time


static func preview_texture_for(color_index: int, level: int) -> Texture2D:
	var safe_color: int = clampi(color_index, 0, PALETTE.size() - 1)
	var safe_level: int = clampi(level, 1, 7)
	var key: String = "%d:%d" % [safe_color, safe_level]
	if _preview_textures.has(key):
		return _preview_textures[key] as Texture2D
	var texture_size: int = PREVIEW_MAX_TEXTURE_SIZE if safe_level == 7 else PREVIEW_TEXTURE_SIZE
	var base_color: Color = color_for(safe_color, safe_level)
	var image: Image = Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	var light: Vector3 = Vector3(-0.20, -0.86, 0.48).normalized()
	var half_vector: Vector3 = (light + Vector3(0.0, 0.0, 1.0)).normalized()
	for y: int in range(texture_size):
		var unit_y: float = (float(y) + 0.5) / float(texture_size) * 2.0 - 1.0
		for x: int in range(texture_size):
			var unit_x: float = (float(x) + 0.5) / float(texture_size) * 2.0 - 1.0
			var radial_squared: float = unit_x * unit_x + unit_y * unit_y
			if radial_squared >= 1.0:
				image.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var z: float = sqrt(1.0 - radial_squared)
			var normal: Vector3 = Vector3(unit_x, unit_y, z)
			var diffuse: float = maxf(0.0, normal.dot(light))
			var half_dot: float = maxf(0.0, normal.dot(half_vector))
			var specular: float = pow(half_dot, 72.0)
			var broad: float = pow(half_dot, 11.0)
			var rim: float = pow(1.0 - z, 2.2)
			var scatter: float = maxf(0.0, unit_y) * (1.0 - z) * 0.15
			var illumination: float = 0.60 + diffuse * 0.34 + broad * 0.055
			image.set_pixel(x, y, Color(
				clampf(base_color.r * illumination + specular * 0.62 + rim * base_color.r * 0.10 + scatter * base_color.r, 0.0, 1.0),
				clampf(base_color.g * illumination + specular * 0.66 + rim * base_color.g * 0.11 + scatter * base_color.g, 0.0, 1.0),
				clampf(base_color.b * illumination + specular * 0.72 + rim * base_color.b * 0.13 + scatter * base_color.b, 0.0, 1.0),
				clampf((1.0 - sqrt(radial_squared)) * float(texture_size) * 0.52, 0.0, 1.0)
			))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_preview_textures[key] = texture
	return texture


static func body_material_for(color_index: int, level: int) -> ShaderMaterial:
	var key: String = "%d:%d" % [color_index, level]
	if not _body_materials.has(key):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.resource_name = "jelly_body_c%d_l%d" % [color_index, level]
		material.shader = _get_body_shader()
		material.set_shader_parameter("base_color", color_for(color_index, level))
		material.set_shader_parameter("level_id", level)
		material.set_shader_parameter("animation_time", _animation_time)
		_body_materials[key] = material
	return _body_materials[key] as ShaderMaterial


static func face_material_for(color_index: int, level: int) -> ShaderMaterial:
	var key: String = "%d:%d" % [color_index, level]
	if not _face_materials.has(key):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.resource_name = "jelly_face_c%d_l%d" % [color_index, level]
		material.shader = _get_face_shader()
		material.set_shader_parameter("jelly_color", color_for(color_index, level))
		material.set_shader_parameter("color_id", color_index)
		material.set_shader_parameter("is_max", level >= 7)
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
		material.set_shader_parameter("highlight_y", NORMAL_HIGHLIGHT_Y)
		material.set_shader_parameter("animation_time", _animation_time)
		_face_materials[key] = material
	return _face_materials[key] as ShaderMaterial


static func outline_material_for(color_index: int, level: int) -> ShaderMaterial:
	var key: String = "%d:%d" % [color_index, level]
	if not _outline_materials.has(key):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.resource_name = "jelly_outline_c%d_l%d" % [color_index, level]
		material.shader = _get_outline_shader()
		material.set_shader_parameter("rim_color", color_for(color_index, level))
		_outline_materials[key] = material
	return _outline_materials[key] as ShaderMaterial


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
	for value: Variant in _face_materials.values():
		(value as ShaderMaterial).set_shader_parameter("animation_time", _animation_time)


static func _get_body_shader() -> Shader:
	if _body_shader != null:
		return _body_shader
	_body_shader = Shader.new()
	_body_shader.resource_name = "jelly_body_shader"
	_body_shader.code = """
shader_type spatial;
render_mode unshaded, depth_prepass_alpha, cull_back;

uniform vec4 base_color : source_color = vec4(1.0);
uniform int level_id = 1;
uniform float animation_time = 0.0;

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 light_dir = normalize(vec3(-0.24, 0.66, 0.71));
	vec3 view_dir = vec3(0.0, 0.0, 1.0);
	vec3 half_dir = normalize(light_dir + view_dir);
	float diffuse = max(dot(n, light_dir), 0.0);
	float broad = pow(max(dot(n, half_dir), 0.0), 11.0) * 0.055;
	float sharp = pow(max(dot(n, half_dir), 0.0), 72.0);
	float facing = clamp(dot(n, view_dir), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.2);
	float lower_scatter = smoothstep(0.58, -0.78, n.y) * 0.12;
	vec3 base = base_color.rgb;
	vec3 interior = base * (0.72 + diffuse * 0.34 + lower_scatter);
	interior += mix(base, vec3(1.0), 0.72) * broad;
	interior += vec3(1.0) * sharp * 0.48;
	interior += mix(base, vec3(1.0), 0.44) * rim * 0.23;
	float max_pulse = level_id >= 7 ? (0.5 + 0.5 * sin(animation_time * 2.15)) : 0.0;
	interior += vec3(1.0) * rim * max_pulse * 0.30;
	ALBEDO = interior;
	EMISSION = interior * (0.08 + rim * (0.08 + max_pulse * 0.32));
	ROUGHNESS = 0.20;
	ALPHA = mix(0.90, 1.0, smoothstep(0.0, 0.72, facing));
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
uniform bool is_max = false;
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
	float blush = 0.0;
	float max_highlight = 0.0;
	if (is_max) {
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
	} else {
		left_eye = 1.0 - smoothstep(-0.015, 0.015,
			capsule(p, vec2(-0.25, -eye_height), vec2(-0.25, eye_height), 0.105));
		right_eye = 1.0 - smoothstep(-0.015, 0.015,
			capsule(p, vec2(0.25, -eye_height), vec2(0.25, eye_height), 0.105));
	}
	float eyes = clamp(left_eye + right_eye, 0.0, 1.0);
	float highlight = 0.0;
	if (!is_max && blink < 0.72) {
		highlight = circle_mask(p, vec2(-0.285, highlight_y), 0.034, 0.012)
			+ circle_mask(p, vec2(0.215, highlight_y), 0.034, 0.012);
	}
	float alpha = clamp(eyes + smile + blush * max_blush_alpha + highlight + max_highlight, 0.0, 1.0);
	vec3 dark = mix(vec3(0.055, 0.065, 0.11), jelly_color.rgb * 0.20, 0.22);
	if (is_max) {
		dark = max_face_color.rgb;
	}
	vec3 face_color = mix(dark, vec3(1.0), clamp(highlight, 0.0, 1.0));
	face_color = mix(face_color, max_blush_color.rgb, clamp(blush, 0.0, 1.0) * max_blush_alpha);
	face_color = mix(face_color, vec3(1.0), clamp(max_highlight, 0.0, 1.0));
	ALBEDO = face_color;
	EMISSION = face_color * 0.08;
	ALPHA = alpha;
}
"""
	return _face_shader


static func _get_outline_shader() -> Shader:
	if _outline_shader != null:
		return _outline_shader
	_outline_shader = Shader.new()
	_outline_shader.resource_name = "jelly_outline_shader"
	_outline_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform vec4 rim_color : source_color = vec4(1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radial = length(p);
	float ring = smoothstep(0.78, 0.90, radial) * (1.0 - smoothstep(0.94, 1.0, radial));
	ALBEDO = mix(rim_color.rgb, vec3(1.0), 0.35);
	EMISSION = ALBEDO * 0.70;
	ALPHA = ring * 0.92;
}
"""
	return _outline_shader
