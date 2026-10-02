class_name Orb3D
extends Node

const PIXELS_PER_METER: float = 100.0

@onready var _body: RigidBody3D = %Body
@onready var _collision_shape: CollisionShape3D = %CollisionShape3D
@onready var _mesh: MeshInstance3D = %Mesh

var color: int = 0
var level: int = 1
var generation: int = 0
var consumed: bool = false
var is_ghost: bool = false
var is_waiting_at_entrance: bool = false
var entrance_preferred_position: Vector2 = Vector2.ZERO
var entrance_gravity: Vector2i = Vector2i.DOWN
var _radius: float = 0.0

var position: Vector2:
	get:
		return Vector2(_body.position.x, _body.position.y) * PIXELS_PER_METER
	set(value):
		_body.position = Vector3(
			value.x / PIXELS_PER_METER,
			value.y / PIXELS_PER_METER,
			0.0
		)

var linear_velocity: Vector2:
	get:
		return Vector2(_body.linear_velocity.x, _body.linear_velocity.y) * PIXELS_PER_METER
	set(value):
		_body.linear_velocity = Vector3(
			value.x / PIXELS_PER_METER,
			value.y / PIXELS_PER_METER,
			0.0
		)

var angular_velocity: float:
	get:
		return _body.angular_velocity.z
	set(value):
		_body.angular_velocity = Vector3(0.0, 0.0, value)


func setup(p_color: int, p_level: int, cfg: GameConfig) -> void:
	color = p_color
	level = p_level
	_radius = cfg.radius_for_level(level)
	var radius_m: float = _radius / PIXELS_PER_METER

	_body.gravity_scale = 0.0
	_body.can_sleep = false
	_body.continuous_cd = true
	_body.contact_monitor = true
	_body.max_contacts_reported = cfg.contact_max_reported
	_body.mass = cfg.mass_for_level(level)
	_body.linear_damp = cfg.orb_linear_damp
	_body.angular_damp = cfg.orb_angular_damp
	_body.axis_lock_linear_z = true
	_body.axis_lock_angular_x = true
	_body.axis_lock_angular_y = true
	_body.collision_layer = 2
	_body.collision_mask = 3

	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = cfg.orb_friction
	material.bounce = cfg.orb_bounce
	_body.physics_material_override = material

	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = radius_m
	_collision_shape.shape = sphere_shape

	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = radius_m
	sphere_mesh.height = radius_m * 2.0
	sphere_mesh.radial_segments = 32
	sphere_mesh.rings = 16
	_mesh.mesh = sphere_mesh
	var visual_material: StandardMaterial3D = StandardMaterial3D.new()
	visual_material.albedo_color = cfg.color_display[color]
	visual_material.metallic = 0.18
	visual_material.roughness = 0.24
	visual_material.emission_enabled = true
	visual_material.emission = cfg.color_display[color] * 0.08
	_mesh.material_override = visual_material


func get_radius() -> float:
	return _radius


func get_current_radius() -> float:
	return _radius


func set_gravity(direction: Vector2i, strength: float) -> void:
	if is_waiting_at_entrance:
		_body.constant_force = Vector3.ZERO
		return
	var acceleration_m: Vector2 = Vector2(direction) * strength / PIXELS_PER_METER
	_body.constant_force = Vector3(
		acceleration_m.x,
		acceleration_m.y,
		0.0
	) * _body.mass
	_body.sleeping = false


func enter_entrance_wait(preferred_position: Vector2, gravity: Vector2i) -> void:
	is_waiting_at_entrance = true
	entrance_preferred_position = preferred_position
	entrance_gravity = gravity
	position = preferred_position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_body.constant_force = Vector3.ZERO
	_body.collision_layer = 0
	_body.collision_mask = 0
	_body.freeze = true
	_set_waiting_visual(true)


func release_entrance_wait(
	spawn_position: Vector2,
	gravity: Vector2i,
	gravity_strength: float
) -> void:
	position = spawn_position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	is_waiting_at_entrance = false
	_body.collision_layer = 2
	_body.collision_mask = 3
	_body.freeze = false
	_set_waiting_visual(false)
	set_gravity(gravity, gravity_strength)


func disable_physics() -> void:
	_body.collision_layer = 0
	_body.collision_mask = 0
	_body.constant_force = Vector3.ZERO
	_body.freeze = true


func get_physics_body() -> RigidBody3D:
	return _body


func get_colliding_orbs() -> Array[Orb3D]:
	var result: Array[Orb3D] = []
	for body: Node3D in _body.get_colliding_bodies():
		var candidate: Orb3D = body.get_parent() as Orb3D
		if candidate != null:
			result.append(candidate)
	return result


func _set_waiting_visual(waiting: bool) -> void:
	var material: StandardMaterial3D = _mesh.material_override as StandardMaterial3D
	if material == null:
		return
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if waiting else BaseMaterial3D.TRANSPARENCY_DISABLED
	var display_color: Color = Config.data.color_display[color]
	display_color.a = 0.45 if waiting else 1.0
	material.albedo_color = display_color
