class_name SpaceBackdrop
extends MeshInstance3D

const PARALLAX_DURATION: float = 0.30
const FAR_PARALLAX_PIXELS: float = 2.0
const NEAR_PARALLAX_PIXELS: float = 8.0
const REFERENCE_VIEWPORT_SIZE: Vector2 = Vector2(1080.0, 1920.0)

var _material: ShaderMaterial
var _gravity_direction: Vector2i = Vector2i.DOWN
var _parallax_elapsed: float = PARALLAX_DURATION
var _danger_intensity: float = 0.0
var _danger_pulsing: bool = false
var _danger_pulse_elapsed: float = 0.0


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
	_material.set_shader_parameter("parallax_pixels", Vector2.ZERO)
	_material.set_shader_parameter(
		"far_parallax_ratio",
		FAR_PARALLAX_PIXELS / NEAR_PARALLAX_PIXELS
	)
	_material.set_shader_parameter("danger_tint", 0.0)
	_update_viewport_size()
	get_viewport().size_changed.connect(_update_viewport_size)
	material_override = _material
	set_process(true)


func _process(delta: float) -> void:
	_parallax_elapsed = minf(_parallax_elapsed + delta, PARALLAX_DURATION)
	var transition: float = _parallax_elapsed / PARALLAX_DURATION
	var return_arc: float = sin(transition * PI)
	var pixel_offset: Vector2 = Vector2(_gravity_direction) * NEAR_PARALLAX_PIXELS * return_arc
	var parallax_uv: Vector2 = Vector2(
		pixel_offset.x / REFERENCE_VIEWPORT_SIZE.x,
		pixel_offset.y / REFERENCE_VIEWPORT_SIZE.y
	)
	_material.set_shader_parameter("parallax_uv", parallax_uv)
	_material.set_shader_parameter("parallax_pixels", pixel_offset)
	var pulse: float = 1.0
	if _danger_pulsing:
		_danger_pulse_elapsed += delta
		pulse = 0.85 + 0.15 * cos(_danger_pulse_elapsed * TAU * 0.8)
	_material.set_shader_parameter("danger_tint", _danger_intensity * pulse)


func set_gravity_direction(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	_gravity_direction = direction
	_parallax_elapsed = 0.0


func set_danger_state(intensity: float, pulsing: bool) -> void:
	if pulsing and not _danger_pulsing:
		_danger_pulse_elapsed = 0.0
	_danger_intensity = clampf(intensity, 0.0, 1.0)
	_danger_pulsing = pulsing


func shader_material() -> ShaderMaterial:
	return _material


func current_parallax_uv() -> Vector2:
	return _material.get_shader_parameter("parallax_uv") as Vector2


func _update_viewport_size() -> void:
	if _material == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_material.set_shader_parameter("viewport_size", viewport_size.max(Vector2.ONE))


func _shader_code() -> String:
	return """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec2 parallax_uv = vec2(0.0);
uniform vec2 parallax_pixels = vec2(0.0);
uniform vec2 viewport_size = vec2(1080.0, 1920.0);
uniform float far_parallax_ratio = 0.25;
uniform float danger_tint : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 shifted_pixels = SCREEN_UV * viewport_size + parallax_pixels;
	vec2 dot_grid = shifted_pixels / 68.0;
	vec2 dot_local = (fract(dot_grid) - vec2(0.5)) * 68.0;
	float dot_mask = 1.0 - smoothstep(5.0, 6.0, length(dot_local));
	vec3 background_color = vec3(1.0, 0.941176, 0.890196);
	vec3 dot_color = vec3(1.0, 0.850980, 0.768627);
	vec3 danger_color = vec3(1.0, 0.352941, 0.431373);
	vec3 color = mix(background_color, dot_color, dot_mask);
	color = mix(color, danger_color, danger_tint * 0.34);
	ALBEDO = color;
	ROUGHNESS = 1.0;
}
"""
