class_name CelestialOrbArt
extends RefCounted

const LEVEL_NAMES: Array[String] = [
	"",
	"planet_l1",
	"planet_l2",
	"planet_l3",
	"planet_l4",
	"planet_l5",
	"planet_l6",
	"planet_l7",
]
const BODY_RADIUS_RATIOS: Array[float] = [
	0.0,
	0.94,
	0.94,
	0.94,
	0.94,
	0.94,
	0.86,
	0.82,
]
const RING_TILT_RADIANS: float = deg_to_rad(20.0)
const CAPTURE_ANIMATION_TIME: float = 4.25

static var _shader: Shader
static var _materials: Dictionary = {}
static var _billboard_meshes: Dictionary = {}
static var _animation_time: float = 0.0
static var _animation_frozen: bool = false
static var _last_animation_frame: int = -1


static func prewarm(cfg: GameConfig) -> void:
	_billboard(1)
	_billboard(2)
	for color_index: int in range(cfg.color_display.size()):
		for level_index: int in range(1, cfg.orb_max_level + 1):
			material_for(cfg, color_index, level_index)


static func clear_cache() -> void:
	_materials.clear()
	_shader = null
	_billboard_meshes.clear()
	_last_animation_frame = -1
	if not _animation_frozen:
		_animation_time = 0.0


static func shared_material_count() -> int:
	return _materials.size()


static func shared_mesh_count() -> int:
	return _billboard_meshes.size()


static func level_name(level: int) -> String:
	if level < 1 or level >= LEVEL_NAMES.size():
		return ""
	return LEVEL_NAMES[level]


static func body_radius_ratio(level: int) -> float:
	if level < 1 or level >= BODY_RADIUS_RATIOS.size():
		return 1.0
	return BODY_RADIUS_RATIOS[level]


static func has_adornment(level: int) -> bool:
	return level >= 6


static func blast_pulse_style(level: int) -> String:
	if level == 4 or level == 5:
		return "rim"
	if level >= 6:
		return "glow"
	return ""


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


static func is_animation_frozen() -> bool:
	return _animation_frozen


static func billboard_mesh(layer: int) -> ArrayMesh:
	return _billboard(layer)


static func material_for(
	cfg: GameConfig,
	color_index: int,
	level: int
) -> ShaderMaterial:
	var display_color: Color = cfg.color_display[color_index]
	var key: String = "%s:%d" % [display_color.to_html(true), level]
	if not _materials.has(key):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.resource_name = "planet_%s_l%d" % [display_color.to_html(false), level]
		material.shader = _celestial_shader()
		material.set_shader_parameter("base_color", display_color)
		material.set_shader_parameter("color_id", color_index)
		material.set_shader_parameter("level_id", level)
		material.set_shader_parameter("body_ratio", body_radius_ratio(level))
		material.set_shader_parameter("animation_time", _animation_time)
		_materials[key] = material
	return _materials[key] as ShaderMaterial


static func _apply_animation_time() -> void:
	for material_value: Variant in _materials.values():
		var material: ShaderMaterial = material_value as ShaderMaterial
		material.set_shader_parameter("animation_time", _animation_time)


static func _billboard(layer: int) -> ArrayMesh:
	if not _billboard_meshes.has(layer):
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.resource_name = "planet_camera_fixed_layer_%d" % layer
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
			Vector3(-1.0, 1.0, 0.0),
			Vector3(1.0, 1.0, 0.0),
			Vector3(1.0, -1.0, 0.0),
			Vector3(-1.0, -1.0, 0.0),
		])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
			Vector3.FORWARD,
			Vector3.FORWARD,
			Vector3.FORWARD,
			Vector3.FORWARD,
		])
		var uv_offset: float = float(layer) * 2.0
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
			Vector2(uv_offset, 0.0),
			Vector2(uv_offset + 1.0, 0.0),
			Vector2(uv_offset + 1.0, 1.0),
			Vector2(uv_offset, 1.0),
		])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_billboard_meshes[layer] = mesh
	return _billboard_meshes[layer] as ArrayMesh


static func _celestial_shader() -> Shader:
	if _shader != null:
		return _shader
	_shader = Shader.new()
	_shader.resource_name = "celestial_orb_shader"
	_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform vec4 base_color : source_color = vec4(1.0);
uniform int color_id = 0;
uniform int level_id = 1;
uniform float body_ratio = 0.94;
uniform float animation_time = 0.0;

varying vec3 local_surface_position;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

float sphere_spot(vec3 position, vec3 direction, float inner, float outer) {
	return 1.0 - smoothstep(inner, outer, length(position - normalize(direction)));
}

float sphere_ellipse_spot(vec3 position, vec3 direction, float radius_x, float radius_y) {
	vec3 center = normalize(direction);
	vec3 tangent_x = normalize(cross(vec3(0.0, 1.0, 0.0), center));
	vec3 tangent_y = normalize(cross(center, tangent_x));
	vec3 delta = position - center;
	float ellipse_distance = length(vec2(
		dot(delta, tangent_x) / radius_x,
		dot(delta, tangent_y) / radius_y
	));
	return 1.0 - smoothstep(0.78, 1.08, ellipse_distance);
}

void vertex() {
	local_surface_position = normalize(VERTEX);
}

void fragment() {
	float art_layer = 0.0;
	vec2 art_uv = UV;
	if (UV.x >= 3.5) {
		art_layer = 2.0;
		art_uv.x -= 4.0;
	} else if (UV.x >= 1.5) {
		art_layer = 1.0;
		art_uv.x -= 2.0;
	}
	vec2 p = art_uv - vec2(0.5);
	float radial = length(p) * 2.0;
	vec3 base = base_color.rgb;

	if (art_layer < 0.5) {
		vec3 body_position = normalize(local_surface_position);
		float detail = step(2.5, float(level_id));
		float animated = step(5.5, float(level_id));
		float legendary = step(6.5, float(level_id));
		float drift = animation_time * animated;
		float n1 = value_noise3(body_position * 4.9 + vec3(float(color_id) * 2.17));
		float n2 = value_noise3(body_position * 12.7 + vec3(7.2, 3.1, float(color_id) * 1.73));
		vec3 moving_position = body_position + vec3(drift * 0.028, -drift * 0.018, drift * 0.011);
		float moving_noise = value_noise3(moving_position * 9.7 + vec3(float(color_id) * 3.11));
		vec3 view_normal = normalize(NORMAL);
		vec3 view_direction = normalize(VIEW);
		float facing = clamp(dot(view_normal, view_direction), 0.0, 1.0);
		vec3 light_direction = normalize(vec3(-0.52, 0.60, 0.68));
		float light_amount = smoothstep(-0.28, 0.92, dot(view_normal, light_direction));
		float sphere_shade = (0.62 + 0.38 * light_amount) * (0.72 + 0.28 * smoothstep(0.02, 0.78, facing));
		float highlight = pow(max(dot(view_normal, light_direction), 0.0), 30.0);
		float atmosphere = pow(1.0 - facing, 2.4);
		vec3 surface = base * (0.90 + n1 * 0.16);

		if (color_id == 0) {
			float polar_cap = smoothstep(0.67, 0.84, body_position.y);
			float canyon = (1.0 - smoothstep(0.030, 0.105, abs(n2 - 0.52))) * detail;
			float dust = smoothstep(0.48, 0.72, moving_noise) * animated;
			surface = mix(surface, vec3(0.96, 0.93, 0.88), polar_cap * 0.82);
			surface = mix(surface, base * 0.35, canyon * 0.72);
			surface = mix(surface, base * 1.24, dust * 0.20);
		} else if (color_id == 1) {
			float continent = smoothstep(0.49, 0.65, n1 + body_position.y * 0.035);
			float cloud = smoothstep(0.62, 0.77, moving_noise + sin(body_position.y * 18.0) * 0.055);
			vec3 land_color = mix(base * 0.48, vec3(0.16, 0.52, 0.30), 0.62);
			surface = mix(base * (0.80 + n2 * 0.20), land_color, continent * 0.88);
			surface = mix(surface, vec3(0.94, 0.98, 1.0), cloud * (0.34 + detail * 0.16));
		} else if (color_id == 2) {
			float vertical_bands = 0.5 + 0.5 * sin((body_position.x + n1 * 0.045) * 24.0 + drift * 0.26);
			float ring_line = (1.0 - smoothstep(0.018, 0.052, abs(body_position.x * 0.18 + body_position.y))) * detail;
			surface = mix(base * 0.72, base * 1.18, smoothstep(0.18, 0.84, vertical_bands));
			surface = mix(surface, vec3(0.90, 1.0, 0.96), ring_line * 0.66);
		} else if (color_id == 3) {
			float cloud_a = 0.5 + 0.5 * sin(body_position.y * 16.0 + n1 * 2.4 + drift * 0.32);
			float cloud_b = 0.5 + 0.5 * sin(body_position.y * 31.0 - n2 * 3.1 - drift * 0.20);
			float swirls = mix(cloud_a, cloud_a * 0.68 + cloud_b * 0.32, detail);
			surface = mix(base * 0.69, mix(base * 1.18, vec3(1.0), 0.18), smoothstep(0.20, 0.82, swirls));
		} else if (color_id == 4) {
			float wind = 0.5 + 0.5 * sin(body_position.y * 24.0 + n1 * 2.2 + drift * 0.25);
			float storm = sphere_ellipse_spot(body_position, vec3(0.42, -0.17, 0.89), 0.28, 0.13) * detail;
			surface = mix(base * 0.58, base * 1.22, smoothstep(0.20, 0.84, wind));
			surface = mix(surface, base * 0.28, storm * (0.76 + animated * 0.12));
		} else {
			float crater_a = sphere_spot(body_position, vec3(-0.34, 0.28, 0.90), 0.10, 0.25);
			float crater_b = sphere_spot(body_position, vec3(0.38, -0.14, 0.91), 0.08, 0.19);
			float crater_c = sphere_spot(body_position, vec3(-0.05, -0.52, 0.85), 0.06, 0.15);
			float crater_d = sphere_spot(body_position, vec3(0.19, 0.56, 0.81), 0.045, 0.115) * detail;
			float crater = max(max(crater_a, crater_b), max(crater_c, crater_d));
			float reflection = pow(max(dot(view_normal, light_direction), 0.0), 8.0) * animated;
			surface = base * (0.83 + n1 * 0.20);
			surface = mix(surface, base * 0.42, crater * 0.72);
			surface = mix(surface, vec3(1.0), reflection * 0.28);
		}

		float fine_detail = (n2 - 0.5) * 0.10 * detail;
		surface *= 1.0 + fine_detail;
		surface *= sphere_shade;
		surface += vec3(1.0) * highlight * 0.13;
		surface += base * atmosphere * 0.31;
		surface = mix(surface, surface * 1.10, legendary);
		ALBEDO = surface;
		METALLIC = color_id == 5 ? 0.10 : 0.02;
		ROUGHNESS = color_id == 5 ? 0.72 : 0.48;
		EMISSION = surface * (0.012 + animated * 0.075 + legendary * 0.055);
		ALPHA = 1.0;
	} else if (art_layer < 1.5) {
		float alpha = 0.0;
		float energy = 0.0;
		if (level_id == 6 || level_id == 7) {
			float halo = smoothstep(body_ratio * 0.96, body_ratio + 0.025, radial)
				* (1.0 - smoothstep(body_ratio + 0.025, 0.985, radial));
			float twinkle = 0.88 + 0.12 * sin(animation_time * (level_id == 7 ? 1.24 : 0.62));
			float rays = 0.0;
			if (level_id == 7) {
				float horizontal_ray = exp(-abs(p.y) * 76.0) * (1.0 - smoothstep(0.15, 0.49, abs(p.x)));
				float vertical_ray = exp(-abs(p.x) * 76.0) * (1.0 - smoothstep(0.15, 0.49, abs(p.y)));
				rays = max(horizontal_ray, vertical_ray) * smoothstep(body_ratio * 0.74, body_ratio + 0.12, radial);
				alpha = max(halo * 0.94, rays * 0.58) * twinkle;
				energy = 1.04;
			} else {
				alpha = halo * 0.52 * twinkle;
				energy = 0.50;
			}
		}
		vec3 glow_color = mix(base, vec3(1.0), level_id == 7 ? 0.24 : 0.10);
		ALBEDO = glow_color;
		EMISSION = glow_color * energy;
		ROUGHNESS = 0.16;
		ALPHA = alpha;
	} else {
		float alpha = 0.0;
		float energy = 0.0;
		if (level_id == 4 || level_id == 5) {
			float distance_to_edge = abs(radial - body_ratio);
			alpha = (1.0 - smoothstep(0.018, 0.090, distance_to_edge)) * 0.72;
			energy = 0.46;
		} else if (level_id == 6 || level_id == 7) {
			float pulse_halo = smoothstep(body_ratio * 0.94, body_ratio + 0.02, radial)
				* (1.0 - smoothstep(body_ratio + 0.02, 0.995, radial));
			alpha = pulse_halo * (level_id == 7 ? 0.96 : 0.78);
			energy = level_id == 7 ? 0.86 : 0.66;
		}
		ALBEDO = base;
		EMISSION = base * energy;
		ROUGHNESS = 0.12;
		ALPHA = alpha;
	}
}
"""
	return _shader
