class_name ColorEffectVisual
extends Node3D

const PUSH_PULL_DURATION: float = 0.3
const SHAKE_WAVE_DURATION: float = 0.4
const LIFT_DURATION: float = 0.35
const PULL_POINT_COUNT: int = 12
const LIFT_POINTS_PER_TARGET: int = 3
const PUSH_RAY_COUNT: int = 6

var active: bool = false
var mode: GameConfig.ShockMode = GameConfig.ShockMode.PUSH
var elapsed: float = 0.0
var duration: float = PUSH_PULL_DURATION
var start_radius_px: float = 0.0
var end_radius_px: float = 0.0
var current_radius_px: float = 0.0
var lift_direction: Vector2 = Vector2.ZERO
var intensity: float = 1.0

var _ring: MeshInstance3D
var _ring_mesh: TorusMesh
var _ring_material: StandardMaterial3D
var _lines: MeshInstance3D
var _line_mesh: ImmediateMesh
var _line_material: StandardMaterial3D
var _points: MultiMeshInstance3D
var _point_multimesh: MultiMesh
var _point_material: StandardMaterial3D
var _color: Color = Color.WHITE
var _result_radius_px: float = 0.0
var _target_positions: Array[Vector2] = []


func _ready() -> void:
	add_to_group(&"color_effect_visual")
	_ring = MeshInstance3D.new()
	_ring.name = "ModeRing"
	_ring_mesh = TorusMesh.new()
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.inner_radius = 0.86
	_ring_mesh.rings = 48
	_ring_mesh.ring_segments = 8
	_ring.mesh = _ring_mesh
	_ring.rotation_degrees.x = 90.0
	_ring_material = _visual_material()
	_ring.material_override = _ring_material
	add_child(_ring)

	_lines = MeshInstance3D.new()
	_lines.name = "ModeLines"
	_line_mesh = ImmediateMesh.new()
	_lines.mesh = _line_mesh
	_line_material = _visual_material()
	add_child(_lines)

	_points = MultiMeshInstance3D.new()
	_points.name = "ModePoints"
	_point_multimesh = MultiMesh.new()
	_point_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var point_mesh: BoxMesh = BoxMesh.new()
	point_mesh.size = Vector3(0.09, 0.09, 0.09)
	_point_material = _visual_material()
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
	_color = color_value
	_result_radius_px = result_radius_px
	intensity = p_intensity
	lift_direction = p_lift_direction.normalized()
	_target_positions.clear()
	for target_value: Variant in targets:
		var target: Dictionary = target_value as Dictionary
		_target_positions.append(
			(target.get("position", origin) as Vector2) - origin
		)
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
	_ring_mesh.inner_radius = 0.72 if color_value.is_equal_approx(
		Config.data.color_display[OrbTypes.OrbColor.RED]
	) else 0.86
	_set_material(_ring_material, color_value, intensity)
	_set_material(_line_material, color_value, intensity)
	_set_material(_point_material, color_value, intensity)
	active = true
	visible = true
	_ring.visible = mode != GameConfig.ShockMode.LIFT
	_lines.visible = mode in [GameConfig.ShockMode.PUSH, GameConfig.ShockMode.LIFT]
	_points.visible = mode in [GameConfig.ShockMode.PULL, GameConfig.ShockMode.LIFT]
	_configure_point_count()
	advance(0.0)


func advance(delta: float) -> bool:
	if not active:
		return true
	elapsed = minf(elapsed + delta, duration)
	var progress: float = clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	current_radius_px = lerpf(start_radius_px, end_radius_px, progress)
	var radius_m: float = current_radius_px / Orb3D.PIXELS_PER_METER
	_ring.scale = Vector3(radius_m, radius_m, radius_m)
	match mode:
		GameConfig.ShockMode.PUSH:
			_update_push_lines(progress)
		GameConfig.ShockMode.PULL:
			_update_pull_points(progress)
		GameConfig.ShockMode.SHAKE:
			pass
		GameConfig.ShockMode.LIFT:
			_update_lift_visuals(progress)
	var alpha: float = 1.0 - progress
	_set_material_alpha(_ring_material, alpha)
	_set_material_alpha(_line_material, alpha)
	_set_material_alpha(_point_material, alpha)
	if progress < 1.0:
		return false
	deactivate()
	return true


func deactivate() -> void:
	active = false
	visible = false
	if _ring != null:
		_ring.visible = false
	if _lines != null:
		_lines.visible = false
	if _points != null:
		_points.visible = false


func push_ray_count() -> int:
	return PUSH_RAY_COUNT if mode == GameConfig.ShockMode.PUSH else 0


func lift_target_count() -> int:
	return _target_positions.size() if mode == GameConfig.ShockMode.LIFT else 0


func _configure_point_count() -> void:
	if mode == GameConfig.ShockMode.PULL:
		_point_multimesh.instance_count = PULL_POINT_COUNT
	elif mode == GameConfig.ShockMode.LIFT:
		_point_multimesh.instance_count = _target_positions.size() * LIFT_POINTS_PER_TARGET
	else:
		_point_multimesh.instance_count = 0


func _update_push_lines(progress: float) -> void:
	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_material)
	var ray_length_px: float = maxf(_result_radius_px, 1.0) * 0.5 * intensity
	for index: int in range(PUSH_RAY_COUNT):
		var direction: Vector2 = Vector2.RIGHT.rotated(
			TAU * float(index) / float(PUSH_RAY_COUNT)
		)
		var tip_radius_px: float = current_radius_px
		var tail_radius_px: float = maxf(tip_radius_px - ray_length_px, _result_radius_px)
		_line_mesh.surface_add_vertex(_plane_vertex(direction * tail_radius_px))
		_line_mesh.surface_add_vertex(_plane_vertex(direction * tip_radius_px))
	_line_mesh.surface_end()


func _update_pull_points(_progress: float) -> void:
	for index: int in range(PULL_POINT_COUNT):
		var direction: Vector2 = Vector2.RIGHT.rotated(
			TAU * float(index) / float(PULL_POINT_COUNT)
		)
		_point_multimesh.set_instance_transform(
			index,
			Transform3D(Basis.IDENTITY, _plane_vertex(direction * current_radius_px))
		)


func _update_lift_visuals(progress: float) -> void:
	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_material)
	var travel_px: float = end_radius_px * progress
	for target_position: Vector2 in _target_positions:
		var line_end: Vector2 = target_position + lift_direction * travel_px
		_line_mesh.surface_add_vertex(_plane_vertex(target_position))
		_line_mesh.surface_add_vertex(_plane_vertex(line_end))
	_line_mesh.surface_end()
	var point_index: int = 0
	for target_position: Vector2 in _target_positions:
		for step: int in range(LIFT_POINTS_PER_TARGET):
			var step_ratio: float = float(step + 1) / float(LIFT_POINTS_PER_TARGET)
			var point_position: Vector2 = (
				target_position + lift_direction * travel_px * step_ratio
			)
			_point_multimesh.set_instance_transform(
				point_index,
				Transform3D(Basis.IDENTITY, _plane_vertex(point_position))
			)
			point_index += 1


func _plane_vertex(value: Vector2) -> Vector3:
	return Orb3D.plane_vector_to_world(value) + Vector3(0.0, 0.0, 0.02)


func _visual_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.no_depth_test = true
	return material


func _set_material(
	material: StandardMaterial3D,
	color_value: Color,
	brightness: float
) -> void:
	material.albedo_color = color_value
	material.emission_enabled = true
	material.emission = Color(color_value.r, color_value.g, color_value.b) * brightness


func _set_material_alpha(material: StandardMaterial3D, alpha: float) -> void:
	var color_value: Color = _color
	color_value.a = alpha
	material.albedo_color = color_value
	material.emission = Color(_color.r, _color.g, _color.b) * intensity * alpha
