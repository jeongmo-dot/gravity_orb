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

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x),
		f.y
	);
}

float circle_mask(vec2 p, vec2 center, float radius, float softness) {
	return 1.0 - smoothstep(radius - softness, radius + softness, length(p - center));
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
		float n1 = value_noise(art_uv * 8.0 + float(level_id) * 3.17);
		float n2 = value_noise(art_uv * 21.0 + float(level_id) * 7.31);
		vec3 surface = base;
		float emission_energy = 0.01;
		float roughness_value = 0.58;
		float metallic_value = 0.04;
		if (level_id == 1) {
			float vein = 1.0 - smoothstep(0.025, 0.085, abs(sin(art_uv.x * 31.0 + art_uv.y * 19.0 + n1 * 5.0)));
			surface = mix(base * (0.65 + n1 * 0.15), base, vein * 0.90);
			emission_energy = 0.01 + vein * 0.03;
			roughness_value = 0.88;
		} else if (level_id == 2) {
			float crater = max(
				circle_mask(art_uv, vec2(0.31, 0.35), 0.105, 0.018),
				max(circle_mask(art_uv, vec2(0.66, 0.58), 0.075, 0.015), circle_mask(art_uv, vec2(0.48, 0.74), 0.055, 0.012))
			);
			surface = mix(base * (0.72 + n1 * 0.18), base * 0.38, crater * 0.75);
			emission_energy = 0.02;
			roughness_value = 0.74;
		} else if (level_id == 3) {
			float land = smoothstep(0.43, 0.61, n1 + 0.18 * sin(art_uv.y * 15.0));
			surface = mix(base * 0.42, base * 0.94, land);
			emission_energy = 0.02;
			roughness_value = 0.48;
		} else if (level_id == 4) {
			float bands = 0.5 + 0.5 * sin(art_uv.y * 43.0 + n1 * 2.2);
			surface = mix(base * 0.54, base * 0.95, smoothstep(0.25, 0.82, bands));
			emission_energy = 0.02;
			roughness_value = 0.38;
			metallic_value = 0.10;
		} else if (level_id == 5) {
			float bands = 0.5 + 0.5 * sin(art_uv.y * 55.0 + n1 * 3.5);
			float storm = circle_mask(art_uv, vec2(0.66, 0.61), 0.105, 0.024) * (0.65 + 0.35 * n2);
			surface = mix(base * 0.48, base * 0.98, smoothstep(0.18, 0.86, bands));
			surface = mix(surface, base, storm);
			emission_energy = 0.02;
			roughness_value = 0.30;
		} else if (level_id == 6) {
			float cells = smoothstep(0.42, 0.82, n2);
			surface = mix(base * 0.74, base * 0.98, cells);
			emission_energy = 0.08 + cells * 0.02;
			roughness_value = 0.20;
		} else {
			float molten = smoothstep(0.37, 0.72, n1 + 0.20 * sin(art_uv.y * 34.0 + n2 * 5.0));
			surface = mix(base * 0.68, base * 0.98, molten);
			emission_energy = 0.10 + molten * 0.03;
			roughness_value = 0.18;
		}
		float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
		surface = mix(surface, base, fresnel * 0.45);
		ALBEDO = surface;
		METALLIC = metallic_value;
		ROUGHNESS = roughness_value;
		EMISSION = base * emission_energy;
		ALPHA = 1.0;
	} else if (art_layer < 1.5) {
		float alpha = 0.0;
		float energy = 0.0;
		if (level_id == 4) {
			float ellipse = length(vec2(p.x, p.y / 0.31)) * 2.0;
			alpha = smoothstep(0.72, 0.79, ellipse) * (1.0 - smoothstep(0.93, 1.0, ellipse));
			alpha *= 0.62 + 0.38 * smoothstep(-0.10, 0.22, p.y);
			energy = 1.10;
		} else if (level_id == 6 || level_id == 7) {
			float inner = body_ratio * (level_id == 6 ? 0.74 : 0.80);
			float halo = smoothstep(inner, body_ratio, radial) * (1.0 - smoothstep(body_ratio, 1.0, radial));
			float rays = 0.72 + 0.28 * sin(atan(p.y, p.x) * (level_id == 6 ? 12.0 : 16.0));
			alpha = halo * rays * (level_id == 6 ? 0.72 : 0.90);
			energy = level_id == 6 ? 1.55 : 1.95;
		}
		ALBEDO = base;
		EMISSION = base * min(energy * 0.08, 0.16);
		ROUGHNESS = 0.2;
		ALPHA = alpha;
	} else {
		float outline = smoothstep(0.82, 0.89, radial) * (1.0 - smoothstep(0.94, 0.995, radial));
		ALBEDO = base;
		EMISSION = base * 0.15;
		ROUGHNESS = 0.1;
		ALPHA = outline;
	}
}
"""
	return _shader
