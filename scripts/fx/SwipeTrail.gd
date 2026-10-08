class_name SwipeTrail
extends Node3D

const DURATION: float = 0.2
const TRAIL_COLOR: Color = Color(0.72, 0.90, 1.0, 0.58)
const HALF_LENGTH_FACTOR: float = 0.38
const SHAFT_HALF_WIDTH_M: float = 0.045
const HEAD_LENGTH_M: float = 0.22
const HEAD_HALF_WIDTH_M: float = 0.13

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _elapsed: float = 0.0
var _direction: Vector2i = Vector2i.ZERO
var _active: bool = false


func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Arrow"
	add_child(_mesh_instance)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = TRAIL_COLOR
	_material.no_depth_test = true
	_mesh_instance.material_override = _material
	visible = false


func play(direction: Vector2i, board_size_px: float) -> void:
	_direction = direction
	_elapsed = 0.0
	_active = true
	_mesh_instance.mesh = _build_arrow_mesh(direction, board_size_px)
	_material.albedo_color = TRAIL_COLOR
	visible = true


func advance(delta: float) -> bool:
	if not _active:
		return false
	_elapsed = minf(_elapsed + delta, DURATION)
	var progress: float = _elapsed / DURATION
	var color_value: Color = TRAIL_COLOR
	color_value.a *= 1.0 - progress
	_material.albedo_color = color_value
	if _elapsed < DURATION:
		return false
	deactivate()
	return true


func deactivate() -> void:
	_active = false
	_elapsed = 0.0
	visible = false


func swipe_direction() -> Vector2i:
	return _direction


func elapsed() -> float:
	return _elapsed


func _build_arrow_mesh(direction: Vector2i, board_size_px: float) -> ImmediateMesh:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	var forward: Vector3 = Orb3D.plane_direction_to_world(direction).normalized()
	var side: Vector3 = Vector3(-forward.y, forward.x, 0.0)
	var half_length_m: float = board_size_px / Orb3D.PIXELS_PER_METER * HALF_LENGTH_FACTOR
	var tail: Vector3 = -forward * half_length_m
	var head_tip: Vector3 = forward * half_length_m
	var head_base: Vector3 = head_tip - forward * HEAD_LENGTH_M
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_triangle(
		mesh,
		tail - side * SHAFT_HALF_WIDTH_M,
		head_base - side * SHAFT_HALF_WIDTH_M,
		head_base + side * SHAFT_HALF_WIDTH_M
	)
	_add_triangle(
		mesh,
		tail - side * SHAFT_HALF_WIDTH_M,
		head_base + side * SHAFT_HALF_WIDTH_M,
		tail + side * SHAFT_HALF_WIDTH_M
	)
	_add_triangle(
		mesh,
		head_base - side * HEAD_HALF_WIDTH_M,
		head_tip,
		head_base + side * HEAD_HALF_WIDTH_M
	)
	mesh.surface_end()
	return mesh


func _add_triangle(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	const Z_OFFSET: float = 0.14
	mesh.surface_add_vertex(a + Vector3(0.0, 0.0, Z_OFFSET))
	mesh.surface_add_vertex(b + Vector3(0.0, 0.0, Z_OFFSET))
	mesh.surface_add_vertex(c + Vector3(0.0, 0.0, Z_OFFSET))
