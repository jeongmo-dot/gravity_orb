class_name ColorEffectVisual
extends Node3D

const PUSH_PULL_DURATION: float = 0.3
const SHAKE_WAVE_DURATION: float = 0.4
const LIFT_DURATION: float = 0.35
const PUSH_STARDUST_COUNT: int = 12
const PULL_STARDUST_COUNT: int = 12
const LIFT_POINTS_PER_TARGET: int = 3

var active: bool = false
var mode: GameConfig.ShockMode = GameConfig.ShockMode.PUSH
var elapsed: float = 0.0
var duration: float = PUSH_PULL_DURATION
var start_radius_px: float = 0.0
var end_radius_px: float = 0.0
var current_radius_px: float = 0.0
var lift_direction: Vector2 = Vector2.ZERO
var intensity: float = 1.0

var _points: MultiMeshInstance3D
var _point_multimesh: MultiMesh
var _point_material: ShaderMaterial
var _result_radius_px: float = 0.0
var _target_positions: Array[Vector2] = []


func _ready() -> void:
	add_to_group(&"color_effect_visual")
	_points = MultiMeshInstance3D.new()
	_points.name = "ModeStardust"
	_point_multimesh = MultiMesh.new()
	_point_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var point_mesh: QuadMesh = QuadMesh.new()
	point_mesh.size = Vector2(0.18, 0.18)
	_point_material = _star_material()
	point_mesh.material = _point_material
	_point_multimesh.mesh = point_mesh
	_points.multimesh = _point_multimesh
	add_child(_points)
	deactivate()


func play(
	p_mode: GameConfig.ShockMode,
	origin: Vector2,
	color_value: Color,
	result_radius_px: float,
	effect_radius_px: float,
	p_intensity: float,
	p_lift_direction: Vector2,
	targets: Array
) -> void:
	mode = p_mode
	_result_radius_px = result_radius_px
	intensity = p_intensity
	lift_direction = p_lift_direction.normalized()
	_target_positions.clear()
	for target_value: Variant in targets:
		var target: Dictionary = target_value as Dictionary
		_target_positions.append((target.get("position", origin) as Vector2) - origin)
	match mode:
		GameConfig.ShockMode.PUSH:
			duration = PUSH_PULL_DURATION
			start_radius_px = result_radius_px
			end_radius_px = effect_radius_px
		GameConfig.ShockMode.PULL:
			duration = PUSH_PULL_DURATION
			start_radius_px = effect_radius_px
			end_radius_px = result_radius_px
		GameConfig.ShockMode.SHAKE:
			duration = SHAKE_WAVE_DURATION
			start_radius_px = result_radius_px
			end_radius_px = effect_radius_px
		GameConfig.ShockMode.LIFT:
			duration = LIFT_DURATION
			start_radius_px = result_radius_px
			end_radius_px = effect_radius_px
	current_radius_px = start_radius_px
	elapsed = 0.0
	position = Orb3D.plane_position_to_world(origin, 0.62)
	_point_material.set_shader_parameter("tint", color_value)
	_point_material.set_shader_parameter("brightness", intensity)
	_point_material.set_shader_parameter("alpha_multiplier", 1.0)
	active = true
	visible = true
	_points.visible = mode in [GameConfig.ShockMode.PUSH, GameConfig.ShockMode.PULL, GameConfig.ShockMode.LIFT]
	_configure_point_count()
	advance(0.0)


func advance(delta: float) -> bool:
	if not active:
		return true
	elapsed = minf(elapsed + delta, duration)
	var progress: float = clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	current_radius_px = lerpf(start_radius_px, end_radius_px, progress)
	match mode:
		GameConfig.ShockMode.PUSH:
			_update_push_stardust(progress)
		GameConfig.ShockMode.PULL:
			_update_pull_stardust(progress)
		GameConfig.ShockMode.SHAKE:
			pass
		GameConfig.ShockMode.LIFT:
			_update_lift_stardust(progress)
	var alpha: float = 1.0 - progress
	_point_material.set_shader_parameter("alpha_multiplier", alpha)
	if progress < 1.0:
		return false
	deactivate()
	return true


func deactivate() -> void:
	active = false
	visible = false
	if _points != null:
		_points.visible = false


func push_ray_count() -> int:
	return 0


func stardust_count() -> int:
	return _point_multimesh.instance_count if _points.visible else 0


func uses_light_beam() -> bool:
	return false


func lift_target_count() -> int:
	return _target_positions.size() if mode == GameConfig.ShockMode.LIFT else 0


func _configure_point_count() -> void:
	if mode == GameConfig.ShockMode.PUSH:
		_point_multimesh.instance_count = PUSH_STARDUST_COUNT
	elif mode == GameConfig.ShockMode.PULL:
		_point_multimesh.instance_count = PULL_STARDUST_COUNT
	elif mode == GameConfig.ShockMode.LIFT:
		_point_multimesh.instance_count = _target_positions.size() * LIFT_POINTS_PER_TARGET
	else:
		_point_multimesh.instance_count = 0


func _update_push_stardust(progress: float) -> void:
	for index: int in range(PUSH_STARDUST_COUNT):
		var phase: float = float(index) / float(PUSH_STARDUST_COUNT)
		var direction: Vector2 = Vector2.RIGHT.rotated(TAU * phase)
		var stagger: float = fmod(progress + phase * 0.22, 1.0)
		var radius_px: float = lerpf(_result_radius_px, current_radius_px, stagger)
		_set_point_transform(index, direction * radius_px, 0.65 + 0.35 * (1.0 - stagger))


func _update_pull_stardust(progress: float) -> void:
	for index: int in range(PULL_STARDUST_COUNT):
		var phase: float = float(index) / float(PULL_STARDUST_COUNT)
		var angle: float = TAU * phase + progress * TAU * 0.85
		var stagger: float = fmod(progress + phase * 0.18, 1.0)
		var radius_px: float = lerpf(start_radius_px, _result_radius_px, stagger)
		_set_point_transform(
			index,
			Vector2.RIGHT.rotated(angle) * radius_px,
			0.55 + 0.45 * (1.0 - stagger)
		)


func _update_lift_stardust(progress: float) -> void:
	var point_index: int = 0
	for target_position: Vector2 in _target_positions:
		for step: int in range(LIFT_POINTS_PER_TARGET):
			var phase: float = float(step) / float(LIFT_POINTS_PER_TARGET)
			var travel_ratio: float = clampf(progress - phase * 0.18, 0.0, 1.0)
			var travel_px: float = end_radius_px * travel_ratio
			var sideways: Vector2 = lift_direction.rotated(PI * 0.5) * sin(
				(progress + phase) * TAU
			) * 5.0
			_set_point_transform(
				point_index,
				target_position + lift_direction * travel_px + sideways,
				0.70 + 0.30 * (1.0 - travel_ratio)
			)
			point_index += 1


func _set_point_transform(index: int, position_px: Vector2, scale_value: float) -> void:
	var basis: Basis = Basis.IDENTITY.scaled(Vector3.ONE * scale_value)
	_point_multimesh.set_instance_transform(
		index,
		Transform3D(basis, _plane_vertex(position_px))
	)


func _plane_vertex(value: Vector2) -> Vector3:
	return Orb3D.plane_vector_to_world(value) + Vector3(0.0, 0.0, 0.02)


func _star_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = "\n".join([
		"shader_type spatial;",
		"render_mode unshaded, cull_disabled, blend_add, depth_draw_never;",
		"uniform vec4 tint : source_color = vec4(1.0);",
		"uniform float brightness = 1.0;",
		"uniform float alpha_multiplier = 1.0;",
		"void fragment() {",
		"  vec2 p = abs(UV * 2.0 - 1.0);",
		"  float vertical = (1.0 - smoothstep(0.03, 0.18, p.x)) * (1.0 - smoothstep(0.15, 1.0, p.y));",
		"  float horizontal = (1.0 - smoothstep(0.03, 0.18, p.y)) * (1.0 - smoothstep(0.15, 1.0, p.x));",
		"  float star = max(vertical, horizontal);",
		"  ALBEDO = tint.rgb * brightness;",
		"  EMISSION = tint.rgb * brightness;",
		"  ALPHA = star * tint.a * alpha_multiplier;",
		"}",
	])
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material
