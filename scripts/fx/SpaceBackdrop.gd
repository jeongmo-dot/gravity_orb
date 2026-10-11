class_name SpaceBackdrop
extends MeshInstance3D

const PARALLAX_DURATION: float = 0.30
const FAR_PARALLAX_PIXELS: float = 2.0
const NEAR_PARALLAX_PIXELS: float = 8.0
const REFERENCE_VIEWPORT_SIZE: Vector2 = Vector2(1080.0, 1920.0)
const METEOR_INTERVAL_SECONDS: float = 30.0
const METEOR_DURATION_SECONDS: float = 0.6

var _material: ShaderMaterial
var _gravity_direction: Vector2i = Vector2i.DOWN
var _parallax_elapsed: float = PARALLAX_DURATION
var _danger_intensity: float = 0.0
var _danger_pulsing: bool = false
var _elapsed: float = 0.0


func _ready() -> void:
	var backdrop_mesh: QuadMesh = QuadMesh.new()
	backdrop_mesh.size = Vector2(24.0, 44.0)
	mesh = backdrop_mesh
	position = Vector3(0.0, 0.0, -1.4)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 64.0
	_material = ShaderMaterial.new()
	var backdrop_shader: Shader = Shader.new()
	backdrop_shader.code = _shader_code()
	_material.shader = backdrop_shader
	_material.set_shader_parameter("parallax_uv", Vector2.ZERO)
	_material.set_shader_parameter(
		"far_parallax_ratio",
		FAR_PARALLAX_PIXELS / NEAR_PARALLAX_PIXELS
	)
	_material.set_shader_parameter("danger_tint", 0.0)
	_material.set_shader_parameter("meteor_cycle_seconds", METEOR_INTERVAL_SECONDS)
	_material.set_shader_parameter("meteor_duration_seconds", METEOR_DURATION_SECONDS)
	material_override = _material
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	_parallax_elapsed = minf(_parallax_elapsed + delta, PARALLAX_DURATION)
	var transition: float = _parallax_elapsed / PARALLAX_DURATION
	var return_arc: float = sin(transition * PI)
	var pixel_offset: Vector2 = Vector2(_gravity_direction) * NEAR_PARALLAX_PIXELS * return_arc
	var parallax_uv: Vector2 = Vector2(
		pixel_offset.x / REFERENCE_VIEWPORT_SIZE.x,
		pixel_offset.y / REFERENCE_VIEWPORT_SIZE.y
	)
	_material.set_shader_parameter("parallax_uv", parallax_uv)
	var pulse: float = 1.0
	if _danger_pulsing:
		pulse = 0.76 + 0.24 * (0.5 + 0.5 * sin(_elapsed * TAU * 0.8))
	_material.set_shader_parameter("danger_tint", _danger_intensity * pulse)


func set_gravity_direction(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	_gravity_direction = direction
	_parallax_elapsed = 0.0


func set_danger_state(intensity: float, pulsing: bool) -> void:
	_danger_intensity = clampf(intensity, 0.0, 1.0)
	_danger_pulsing = pulsing


func shader_material() -> ShaderMaterial:
	return _material


func current_parallax_uv() -> Vector2:
	return _material.get_shader_parameter("parallax_uv") as Vector2


func _shader_code() -> String:
	return """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec2 parallax_uv = vec2(0.0);
uniform float far_parallax_ratio = 0.25;
uniform float danger_tint : hint_range(0.0, 1.0) = 0.0;
uniform float meteor_cycle_seconds = 30.0;
uniform float meteor_duration_seconds = 0.6;

float hash21(vec2 value) {
	value = fract(value * vec2(123.34, 456.21));
	value += dot(value, value + 45.32);
	return fract(value.x * value.y);
}

vec2 hash22(vec2 value) {
	float first = hash21(value);
	return vec2(first, hash21(value + first + 19.19));
}

float value_noise(vec2 value) {
	vec2 cell = floor(value);
	vec2 local = fract(value);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}

float cloud_noise(vec2 value) {
	return value_noise(value) * 0.64 + value_noise(value * 2.03 + 7.1) * 0.36;
}

float star_layer(vec2 uv, float scale, float threshold, float radius, float phase) {
	vec2 cell = floor(uv * scale);
	vec2 local = fract(uv * scale);
	float identity = hash21(cell + phase);
	vec2 point = 0.16 + hash22(cell + phase + 3.7) * 0.68;
	float distance_to_star = length(local - point);
	float star = smoothstep(radius, 0.0, distance_to_star) * step(threshold, identity);
	float twinkle = 0.68 + 0.32 * sin(TIME * (0.55 + identity * 0.65) + identity * 31.0);
	return star * twinkle;
}

float segment_distance(vec2 point, vec2 start, vec2 end) {
	vec2 segment = end - start;
	float amount = clamp(dot(point - start, segment) / dot(segment, segment), 0.0, 1.0);
	return length(point - (start + segment * amount));
}

void fragment() {
	vec2 uv = UV;
	float vignette = 1.0 - smoothstep(0.18, 0.78, length((uv - vec2(0.5)) * vec2(0.75, 1.0)));
	vec3 color = mix(vec3(0.006, 0.011, 0.034), vec3(0.030, 0.012, 0.060), uv.y);
	color += vec3(0.018, 0.022, 0.050) * vignette;

	float slow_time = TIME / 96.0;
	float violet = smoothstep(0.50, 0.84, cloud_noise(uv * vec2(2.2, 3.1) + vec2(slow_time, -slow_time * 0.35)));
	float teal = smoothstep(0.54, 0.86, cloud_noise(uv * vec2(3.1, 2.4) + vec2(-slow_time * 0.42, slow_time * 0.26) + 13.0));
	float magenta = smoothstep(0.58, 0.88, cloud_noise(uv * vec2(1.7, 3.6) + vec2(slow_time * 0.18, slow_time * 0.51) + 31.0));
	color += vec3(0.075, 0.025, 0.105) * violet;
	color += vec3(0.018, 0.074, 0.080) * teal;
	color += vec3(0.080, 0.018, 0.058) * magenta;

	float far_stars = star_layer(uv + parallax_uv * far_parallax_ratio, 86.0, 0.963, 0.105, 1.0);
	float middle_stars = star_layer(uv + parallax_uv * 0.58, 47.0, 0.982, 0.090, 8.0);
	float near_stars = star_layer(uv + parallax_uv, 25.0, 0.991, 0.075, 17.0);
	color += vec3(0.34, 0.40, 0.54) * far_stars;
	color += vec3(0.43, 0.50, 0.60) * middle_stars;
	color += vec3(0.54, 0.56, 0.58) * near_stars;

	float cycle = max(meteor_cycle_seconds, 20.0);
	float meteor_phase = fract(TIME / cycle);
	float active_span = max(meteor_duration_seconds / cycle, 0.001);
	float meteor_progress = clamp(meteor_phase / active_span, 0.0, 1.0);
	float cycle_index = floor(TIME / cycle);
	float meteor_y = 0.12 + hash21(vec2(cycle_index, 27.0)) * 0.26;
	vec2 meteor_direction = normalize(vec2(1.0, 0.28));
	vec2 meteor_head = vec2(-0.12, meteor_y) + meteor_direction * meteor_progress * 1.45;
	vec2 meteor_tail = meteor_head - meteor_direction * 0.18;
	float meteor = smoothstep(0.010, 0.0, segment_distance(uv, meteor_tail, meteor_head));
	meteor *= 1.0 - smoothstep(active_span * 0.80, active_span, meteor_phase);
	color += vec3(0.48, 0.55, 0.58) * meteor;

	color = mix(color, color + vec3(0.075, 0.004, 0.006), danger_tint * 0.55);
	ALBEDO = clamp(color, vec3(0.0), vec3(0.58));
	ROUGHNESS = 1.0;
}
"""
