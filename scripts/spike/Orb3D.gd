class_name Orb3D
extends Node

const PIXELS_PER_METER: float = 100.0

@onready var _body: RigidBody3D = %Body
@onready var _collision_shape: CollisionShape3D = %CollisionShape3D
@onready var _mesh: MeshInstance3D = %Mesh

var color: int = 0
var level: int = 1
var generation: int = 0
var stable_spawn_id: int = 0
var consumed: bool = false
var is_ghost: bool = false
var is_waiting_at_entrance: bool = false
var entrance_preferred_position: Vector2 = Vector2.ZERO
var entrance_gravity: Vector2i = Vector2i.DOWN
var diagnostic_last_event: String = "spawn"
var diagnostic_last_event_physics_frame: int = 0
var _radius: float = 0.0
var _current_radius: float = 0.0
var _growth_start_radius: float = 0.0
var _growth_duration: float = 0.0
var _growth_elapsed: float = 0.0
var _contact_reporting_enabled: bool = true
var _continuous_cd_enabled: bool = true
var _allow_sleep: bool = false
var _progressive_growth_enabled: bool = false

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
	_growth_duration = maxf(cfg.grow_duration, 0.0) if _progressive_growth_enabled else 0.0
	_growth_start_radius = _radius * clampf(cfg.grow_start_ratio, 0.0, 1.0)
	_current_radius = _radius if _growth_duration <= 0.0 else _growth_start_radius
	_growth_elapsed = 0.0
	diagnostic_last_event = "spawn"
	diagnostic_last_event_physics_frame = Engine.get_physics_frames()
	var radius_m: float = _current_radius / PIXELS_PER_METER

	_body.gravity_scale = 0.0
	_body.can_sleep = _allow_sleep
	_body.continuous_cd = _continuous_cd_enabled
	_body.contact_monitor = _contact_reporting_enabled
	_body.max_contacts_reported = cfg.contact_max_reported if _contact_reporting_enabled else 0
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


func _physics_process(delta: float) -> void:
	_advance_growth(delta)


func configure_physics_profile(
	contact_reporting_enabled: bool,
	continuous_cd_enabled: bool,
	allow_sleep: bool,
	progressive_growth_enabled: bool = false
) -> void:
	_contact_reporting_enabled = contact_reporting_enabled
	_continuous_cd_enabled = continuous_cd_enabled
	_allow_sleep = allow_sleep
	_progressive_growth_enabled = progressive_growth_enabled


func get_radius() -> float:
	return _radius


func get_current_radius() -> float:
	return _current_radius


func note_diagnostic_event(event_name: String, physics_frame: int = -1) -> void:
	diagnostic_last_event = event_name
	diagnostic_last_event_physics_frame = (
		Engine.get_physics_frames() if physics_frame < 0 else physics_frame
	)


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
	note_diagnostic_event("entrance_release")


func disable_physics() -> void:
	_body.collision_layer = 0
	_body.collision_mask = 0
	_body.constant_force = Vector3.ZERO
	_body.freeze = true


func get_physics_body() -> RigidBody3D:
	return _body


func get_colliding_orbs() -> Array[Orb3D]:
	var result: Array[Orb3D] = []
	if not _body.contact_monitor:
		return result
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


func _advance_growth(delta: float) -> void:
	if _current_radius >= _radius or _growth_duration <= 0.0:
		return
	_growth_elapsed = minf(_growth_elapsed + delta, _growth_duration)
	var progress: float = _growth_elapsed / _growth_duration
	_set_current_radius(lerpf(_growth_start_radius, _radius, progress))


func _set_current_radius(radius_px: float) -> void:
	_current_radius = minf(radius_px, _radius)
	var radius_m: float = _current_radius / PIXELS_PER_METER
	var sphere_shape: SphereShape3D = _collision_shape.shape as SphereShape3D
	if sphere_shape != null:
		sphere_shape.radius = radius_m
	var sphere_mesh: SphereMesh = _mesh.mesh as SphereMesh
	if sphere_mesh != null:
		sphere_mesh.radius = radius_m
		sphere_mesh.height = radius_m * 2.0
