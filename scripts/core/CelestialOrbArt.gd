class_name CelestialOrbArt
extends RefCounted

const LEVEL_NAMES: Array[String] = [
	"",
	"meteor",
	"moon",
	"rocky_planet",
	"ringed_planet",
	"gas_giant",
	"star",
	"sun",
]
const BODY_RADIUS_RATIOS: Array[float] = [
	0.0,
	0.94,
	0.94,
	0.94,
	0.68,
	0.94,
	0.82,
	0.84,
]
const RING_TILT_RADIANS: float = deg_to_rad(20.0)
const METEOR_VERTEX_MIN_SCALE: float = 0.905
const METEOR_VERTEX_MAX_SCALE: float = 1.055

static var _shader: Shader
static var _materials: Dictionary = {}
static var _billboard_meshes: Dictionary = {}


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
	return level == 4 or level >= 6


static func blast_pulse_style(level: int) -> String:
	if level == 4 or level == 5:
		return "rim"
	if level >= 6:
		return "glow"
	return ""


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
		material.resource_name = "celestial_%s_l%d" % [display_color.to_html(false), level]
		material.shader = _celestial_shader()
		material.set_shader_parameter("base_color", display_color)
		material.set_shader_parameter("level_id", level)
		material.set_shader_parameter("body_ratio", body_radius_ratio(level))
		_materials[key] = material
	return _materials[key] as ShaderMaterial


static func _billboard(layer: int) -> ArrayMesh:
	if not _billboard_meshes.has(layer):
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.resource_name = "celestial_camera_fixed_layer_%d" % layer
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
uniform int level_id = 1;
uniform float body_ratio = 0.94;

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

float ellipse_mask(vec2 p, vec2 center, vec2 radii, float softness) {
	float distance_value = length((p - center) / radii);
	return 1.0 - smoothstep(1.0 - softness, 1.0 + softness, distance_value);
}

float ellipse_ring(vec2 p, vec2 center, vec2 radii, float thickness) {
	float normalized_distance = length((p - center) / radii);
	return 1.0 - smoothstep(thickness, thickness * 1.8, abs(normalized_distance - 1.0));
}

void vertex() {
	local_surface_position = normalize(VERTEX);
	if (UV.x < 1.5 && level_id == 1) {
		vec3 direction = normalize(VERTEX);
		float rough_shape = value_noise3(direction * 3.7 + vec3(4.1, 7.3, 2.2));
		float large_lobes = 0.5 + 0.5 * sin(direction.x * 5.0 + direction.y * 3.0 - direction.z * 4.0);
		float displacement = mix(0.905, 1.055, rough_shape * 0.72 + large_lobes * 0.28);
		VERTEX *= displacement;
	}
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
		float n1 = value_noise3(body_position * 5.3 + vec3(float(level_id) * 1.71));
		float n2 = value_noise3(body_position * 13.7 + vec3(7.2, 3.1, float(level_id) * 2.13));
		vec3 view_normal = normalize(NORMAL);
		vec3 view_direction = normalize(VIEW);
		float facing = clamp(dot(view_normal, view_direction), 0.0, 1.0);
		vec3 light_direction = normalize(vec3(-0.52, 0.60, 0.68));
		float light_amount = smoothstep(-0.28, 0.92, dot(view_normal, light_direction));
		float sphere_shade = (0.60 + 0.40 * light_amount) * (0.70 + 0.30 * smoothstep(0.02, 0.78, facing));
		float highlight = pow(max(dot(view_normal, light_direction), 0.0), 30.0);
		float atmosphere = pow(1.0 - facing, 2.4);
		vec3 surface = base;
		float emission_energy = 0.012;
		float roughness_value = 0.62;
		float metallic_value = 0.02;
		if (level_id == 1) {
			float vein_a = 1.0 - smoothstep(0.055, 0.145, abs(n1 - 0.50));
			float vein_b = 1.0 - smoothstep(0.045, 0.115, abs(n2 - 0.57));
			float vein = max(vein_a * 0.85, vein_b * 0.65);
			float grey = dot(base, vec3(0.299, 0.587, 0.114));
			vec3 rock = mix(vec3(grey) * 0.34, base * 0.42, 0.32) * (0.76 + n1 * 0.25);
			surface = mix(rock, base * 1.34, vein);
			emission_energy = 0.01 + vein * 0.22;
			roughness_value = 0.92;
		} else if (level_id == 2) {
			float crater_a = sphere_spot(body_position, vec3(-0.34, 0.28, 0.90), 0.10, 0.25);
			float crater_b = sphere_spot(body_position, vec3(0.38, -0.14, 0.91), 0.08, 0.19);
			float crater_c = sphere_spot(body_position, vec3(-0.05, -0.52, 0.85), 0.06, 0.15);
			float crater_d = sphere_spot(body_position, vec3(0.19, 0.56, 0.81), 0.045, 0.115);
			float crater = max(max(crater_a, crater_b), max(crater_c, crater_d));
			float crater_rim = max(
				sphere_spot(body_position, vec3(-0.34, 0.28, 0.90), 0.21, 0.29) - crater_a,
				sphere_spot(body_position, vec3(0.38, -0.14, 0.91), 0.16, 0.23) - crater_b
			);
			surface = base * (0.91 + n1 * 0.18);
			surface = mix(surface, base * 0.38, crater * 0.82);
			surface += base * crater_rim * 0.42;
			roughness_value = 0.78;
		} else if (level_id == 3) {
			float continent_field = n1 * 0.72 + n2 * 0.28 + body_position.y * 0.06;
			float land = smoothstep(0.42, 0.64, continent_field);
			float grey = dot(base, vec3(0.299, 0.587, 0.114));
			vec3 ocean = base * (0.92 + n2 * 0.18);
			vec3 continent = mix(vec3(grey) * 0.34, base * 0.38, 0.30) * (0.76 + n1 * 0.18);
			surface = mix(ocean, continent, land);
			roughness_value = mix(0.34, 0.70, land);
		} else if (level_id == 4) {
			float latitude = body_position.y + (n1 - 0.5) * 0.028;
			float bands = 0.5 + 0.5 * sin(latitude * 30.0 + n2 * 1.1);
			surface = mix(base * 0.52, base * 1.05, smoothstep(0.18, 0.83, bands));
			roughness_value = 0.40;
			metallic_value = 0.08;
		} else if (level_id == 5) {
			float latitude = body_position.y + (n1 - 0.5) * 0.075;
			float broad_bands = 0.5 + 0.5 * sin(latitude * 25.0 + n2 * 3.5);
			float fine_bands = 0.5 + 0.5 * sin(latitude * 58.0 - n1 * 4.0);
			float band_mix = broad_bands * 0.72 + fine_bands * 0.28;
			float storm = sphere_ellipse_spot(body_position, vec3(0.43, -0.18, 0.89), 0.30, 0.13);
			float storm_eye = sphere_ellipse_spot(body_position, vec3(0.43, -0.18, 0.89), 0.075, 0.048);
			surface = mix(base * 0.46, base * 1.08, smoothstep(0.18, 0.84, band_mix));
			surface = mix(surface, mix(base * 1.25, vec3(1.0), 0.18), storm * (0.76 + n2 * 0.18));
			surface = mix(surface, base * 0.34, storm_eye * 0.92);
			roughness_value = 0.30;
		} else if (level_id == 6) {
			float cells = smoothstep(0.34, 0.78, n1 * 0.58 + n2 * 0.42);
			float white_core = pow(facing, 4.8) * 0.70;
			surface = mix(base * (0.91 + cells * 0.14), vec3(1.0), white_core);
			surface *= 0.96 + 0.04 * sin(TIME * 1.15 + n2 * 6.2831);
			emission_energy = 0.22 + white_core * 0.10;
			roughness_value = 0.16;
		} else {
			float boiling_a = value_noise3(body_position * 11.0 + vec3(TIME * 0.09, -TIME * 0.07, TIME * 0.04));
			float boiling_b = value_noise3(body_position * 23.0 + vec3(-TIME * 0.05, TIME * 0.08, 4.7));
			float granules = smoothstep(0.38, 0.72, boiling_a * 0.65 + boiling_b * 0.35);
			float rice_cells = smoothstep(0.56, 0.70, boiling_b) * (1.0 - smoothstep(0.76, 0.88, boiling_b));
			float edge_darkening = 0.70 + 0.30 * smoothstep(0.02, 0.88, facing);
			surface = mix(base * 0.88, mix(base * 1.36, vec3(1.0), 0.38), granules) * edge_darkening;
			surface = mix(surface, vec3(1.0), rice_cells * 0.44);
			emission_energy = 0.50 + granules * 0.16 + rice_cells * 0.12;
			roughness_value = 0.18;
		}
		if (level_id <= 5) {
			surface *= sphere_shade;
			if (level_id >= 2) {
				surface += vec3(1.0) * highlight * 0.16;
			}
			surface += base * atmosphere * (level_id == 1 ? 0.20 : 0.34);
		} else {
			surface = mix(surface, base * 1.12, atmosphere * 0.28);
		}
		ALBEDO = surface;
		METALLIC = metallic_value;
		ROUGHNESS = roughness_value;
		EMISSION = surface * emission_energy;
		ALPHA = 1.0;
	} else if (art_layer < 1.5) {
		float alpha = 0.0;
		float energy = 0.0;
		if (level_id == 4) {
			float ellipse = length(vec2(p.x / 0.49, p.y / 0.135));
			float ring = smoothstep(0.78, 0.84, ellipse) * (1.0 - smoothstep(0.94, 1.0, ellipse));
			float front_weight = mix(0.42, 1.0, smoothstep(-0.08, 0.18, p.y));
			alpha = ring * front_weight * 0.95;
			energy = 0.30;
		} else if (level_id == 6 || level_id == 7) {
			float halo = smoothstep(body_ratio * 0.74, body_ratio, radial) * (1.0 - smoothstep(body_ratio, 1.0, radial));
			float twinkle = 0.88 + 0.12 * sin(TIME * (level_id == 6 ? 1.15 : 0.62));
			float rays = 0.0;
			if (level_id == 6) {
				float horizontal_ray = exp(-abs(p.y) * 72.0) * (1.0 - smoothstep(0.12, 0.49, abs(p.x)));
				float vertical_ray = exp(-abs(p.x) * 72.0) * (1.0 - smoothstep(0.12, 0.49, abs(p.y)));
				rays = max(horizontal_ray, vertical_ray) * smoothstep(body_ratio * 0.62, body_ratio * 0.88, radial);
				alpha = max(halo * 0.66, rays * 0.74) * twinkle;
				energy = 0.58;
			} else {
				float prominence_a = ellipse_ring(p, vec2(-0.38, -0.25), vec2(0.13, 0.085), 0.14);
				float prominence_b = ellipse_ring(p, vec2(0.39, -0.14), vec2(0.10, 0.15), 0.14);
				float prominence_c = ellipse_ring(p, vec2(0.08, 0.42), vec2(0.15, 0.095), 0.14);
				float prominences = max(prominence_a, max(prominence_b, prominence_c));
				alpha = max(halo * 0.82, prominences * 0.84) * twinkle;
				energy = 0.72;
			}
		}
		ALBEDO = base;
		EMISSION = base * energy;
		ROUGHNESS = 0.18;
		ALPHA = alpha;
	} else {
		float alpha = 0.0;
		float energy = 0.0;
		if (level_id == 4 || level_id == 5) {
			float rim_center = body_ratio - (level_id == 5 ? 0.025 : 0.0);
			float distance_to_edge = abs(radial - rim_center);
			alpha = (1.0 - smoothstep(0.018, 0.090, distance_to_edge)) * 0.72;
			energy = 0.46;
		} else if (level_id == 6 || level_id == 7) {
			float pulse_halo = smoothstep(body_ratio * 0.78, body_ratio, radial) * (1.0 - smoothstep(body_ratio, 1.0, radial));
			float pulse_rays = 0.0;
			if (level_id == 6) {
				pulse_rays = max(exp(-abs(p.x) * 62.0), exp(-abs(p.y) * 62.0));
				pulse_rays *= smoothstep(body_ratio * 0.68, body_ratio * 0.92, radial) * (1.0 - smoothstep(0.90, 1.0, radial));
			}
			alpha = max(pulse_halo * 0.88, pulse_rays * 0.58);
			energy = level_id == 6 ? 0.62 : 0.78;
		}
		ALBEDO = base;
		EMISSION = base * energy;
		ROUGHNESS = 0.12;
		ALPHA = alpha;
	}
}
"""
	return _shader
