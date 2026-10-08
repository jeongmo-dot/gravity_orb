class_name Orb3D
extends Node

const PIXELS_PER_METER: float = 100.0
const STRETCH_SPEED_THRESHOLD: float = 900.0
const STRETCH_ALONG_SCALE: float = 1.15
const STRETCH_PERPENDICULAR_SCALE: float = 0.92

@onready var _body: RigidBody3D = %Body
@onready var _collision_shape: CollisionShape3D = %CollisionShape3D
@onready var _mesh: MeshInstance3D = %Mesh
@onready var _symbol_mesh: MeshInstance3D = %Symbol

var color: int = 0
var level: int = 1
var generation: int = 0
var stable_spawn_id: int = 0
var consumed: bool = false
var is_ghost: bool = false
var ghost_elapsed: float = 0.0
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
var _display_color: Color = Color.WHITE
var _blast_armed: bool = false
var _blast_blink_period: float = 0.8
var _blast_blink_elapsed: float = 0.0
var _visual_punch_tween: Tween
var _visual_punch_scale: Vector3 = Vector3.ONE:
	set(value):
		_visual_punch_scale = value
		_update_visual_transform()
var _render_clamp_enabled: bool = true

var position: Vector2:
	get:
		return world_position_to_plane(_body.position)
	set(value):
		_body.position = plane_position_to_world(value)
		_update_visual_transform()

var linear_velocity: Vector2:
	get:
		return world_vector_to_plane(_body.linear_velocity)
	set(value):
		_body.linear_velocity = plane_vector_to_world(value)

var angular_velocity: float:
	get:
		return world_angular_velocity_to_plane(_body.angular_velocity.z)
	set(value):
		_body.angular_velocity = Vector3(
			0.0,
			0.0,
			plane_angular_velocity_to_world(value)
		)


static func plane_position_to_world(value: Vector2, z: float = 0.0) -> Vector3:
	return Vector3(
		value.x / PIXELS_PER_METER,
		-value.y / PIXELS_PER_METER,
		z
	)


static func world_position_to_plane(value: Vector3) -> Vector2:
	return Vector2(value.x, -value.y) * PIXELS_PER_METER


static func plane_vector_to_world(value: Vector2) -> Vector3:
	return Vector3(
		value.x / PIXELS_PER_METER,
		-value.y / PIXELS_PER_METER,
		0.0
	)


static func world_vector_to_plane(value: Vector3) -> Vector2:
	return Vector2(value.x, -value.y) * PIXELS_PER_METER


static func plane_direction_to_world(value: Vector2i) -> Vector3:
	return Vector3(float(value.x), -float(value.y), 0.0)


static func plane_angular_velocity_to_world(value: float) -> float:
	return -value


static func world_angular_velocity_to_plane(value: float) -> float:
	return -value


func setup(p_color: int, p_level: int, cfg: GameConfig) -> void:
	color = p_color
	level = p_level
	_display_color = cfg.color_display[color]
	_blast_armed = cfg.blast_enabled and level >= cfg.active_blast_min_level()
	_blast_blink_period = maxf(cfg.blast_blink_period, 0.001)
	_blast_blink_elapsed = 0.0
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
	visual_material.albedo_color = _display_color
	visual_material.metallic = 0.18
	visual_material.roughness = 0.24
	visual_material.emission_enabled = true
	visual_material.emission = _display_color * blast_emission_strength()
	_mesh.material_override = visual_material
	_symbol_mesh.mesh = OrbSymbols.mesh_for_color(color)
	_symbol_mesh.visible = cfg.orb_symbols_enabled
	_symbol_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_symbol_mesh.transparency = 0.0
	_update_visual_transform()


func _physics_process(delta: float) -> void:
	_advance_growth(delta)
	_advance_blast_blink(delta)


func _process(_delta: float) -> void:
	_update_visual_transform()


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


func set_render_clamp_enabled(enabled: bool) -> void:
	_render_clamp_enabled = enabled
	_update_visual_transform()


func is_blast_armed() -> bool:
	return _blast_armed


func blast_emission_strength() -> float:
	if not _blast_armed:
		return 0.08
	return 0.20 + 0.80 * (
		0.5 + 0.5 * sin(TAU * _blast_blink_elapsed / _blast_blink_period)
	)


func play_visual_punch(scale_factor: float = 1.18, duration: float = 0.14) -> void:
	if _visual_punch_tween != null and _visual_punch_tween.is_valid():
		_visual_punch_tween.kill()
	var target_scale: Vector3 = Vector3.ONE * scale_factor
	var start_scale: Vector3 = Vector3.ONE.lerp(target_scale, 0.02)
	_visual_punch_scale = start_scale
	_visual_punch_tween = create_tween()
	_visual_punch_tween.set_trans(Tween.TRANS_BACK)
	_visual_punch_tween.set_ease(Tween.EASE_OUT)
	_visual_punch_tween.tween_method(
		_set_visual_punch_scale,
		start_scale,
		target_scale,
		duration * 0.45
	)
	_visual_punch_tween.set_trans(Tween.TRANS_QUAD)
	_visual_punch_tween.set_ease(Tween.EASE_IN_OUT)
	_visual_punch_tween.tween_method(
		_set_visual_punch_scale,
		target_scale,
		Vector3.ONE,
		duration * 0.55
	)


func play_visual_pull_punch(duration: float = 0.3) -> void:
	if _visual_punch_tween != null and _visual_punch_tween.is_valid():
		_visual_punch_tween.kill()
	var contracted_scale: Vector3 = Vector3.ONE / 1.18
	var expanded_scale: Vector3 = Vector3.ONE * 1.18
	var start_scale: Vector3 = Vector3.ONE.lerp(contracted_scale, 0.02)
	_visual_punch_scale = start_scale
	_visual_punch_tween = create_tween()
	_visual_punch_tween.set_trans(Tween.TRANS_QUAD)
	_visual_punch_tween.set_ease(Tween.EASE_OUT)
	_visual_punch_tween.tween_method(
		_set_visual_punch_scale,
		start_scale,
		contracted_scale,
		duration * 0.35
	)
	_visual_punch_tween.set_trans(Tween.TRANS_BACK)
	_visual_punch_tween.tween_method(
		_set_visual_punch_scale,
		contracted_scale,
		expanded_scale,
		duration * 0.30
	)
	_visual_punch_tween.set_trans(Tween.TRANS_QUAD)
	_visual_punch_tween.set_ease(Tween.EASE_IN_OUT)
	_visual_punch_tween.tween_method(
		_set_visual_punch_scale,
		expanded_scale,
		Vector3.ONE,
		duration * 0.35
	)


func _set_visual_punch_scale(value: Vector3) -> void:
	_visual_punch_scale = value


func enter_ghost_state(alpha: float) -> void:
	is_ghost = true
	ghost_elapsed = 0.0
	_body.collision_layer = 4
	_body.collision_mask = 1
	_set_visual_alpha(alpha)


func exit_ghost_state() -> void:
	is_ghost = false
	is_waiting_at_entrance = false
	_body.collision_layer = 2
	_body.collision_mask = 3
	_body.sleeping = false
	_set_visual_alpha(1.0)


func advance_ghost(delta: float) -> void:
	if is_ghost:
		ghost_elapsed += delta


func note_diagnostic_event(event_name: String, physics_frame: int = -1) -> void:
	diagnostic_last_event = event_name
	diagnostic_last_event_physics_frame = (
		Engine.get_physics_frames() if physics_frame < 0 else physics_frame
	)


func set_gravity(direction: Vector2i, strength: float) -> void:
	if is_waiting_at_entrance:
		_body.constant_force = Vector3.ZERO
		return
	var level_strength: float = strength * (
		1.0 + Config.data.gravity_level_scale * float(level - 1)
	)
	var acceleration_px: Vector2 = Vector2(direction) * level_strength
	_body.constant_force = plane_vector_to_world(acceleration_px) * _body.mass
	_body.sleeping = false


func apply_plane_impulse(impulse: Vector2) -> void:
	_body.apply_central_impulse(plane_vector_to_world(impulse))
	_body.sleeping = false


func apply_plane_velocity_change(velocity_change: Vector2) -> void:
	apply_plane_impulse(velocity_change * _body.mass)


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


func visual_stretch_scale() -> Vector3:
	if not Config.data.fx_enabled or not Config.data.fx_orb_stretch_enabled:
		return Vector3.ONE
	if linear_velocity.length() < STRETCH_SPEED_THRESHOLD:
		return Vector3.ONE
	return Vector3(
		STRETCH_ALONG_SCALE,
		STRETCH_PERPENDICULAR_SCALE,
		STRETCH_PERPENDICULAR_SCALE
	)


func visual_mesh_scale() -> Vector3:
	return _mesh.scale


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
	_set_visual_alpha(0.45 if waiting else 1.0)


func _set_visual_alpha(alpha: float) -> void:
	var material: StandardMaterial3D = _mesh.material_override as StandardMaterial3D
	if material == null:
		return
	material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
		if alpha < 1.0
		else BaseMaterial3D.TRANSPARENCY_DISABLED
	)
	var display_color: Color = _display_color
	display_color.a = alpha
	material.albedo_color = display_color
	material.emission = _display_color * blast_emission_strength()
	_symbol_mesh.transparency = 1.0 - clampf(alpha, 0.0, 1.0)


func _advance_blast_blink(delta: float) -> void:
	if not _blast_armed:
		return
	_blast_blink_elapsed += delta
	var material: StandardMaterial3D = _mesh.material_override as StandardMaterial3D
	if material != null:
		material.emission = _display_color * blast_emission_strength()


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
	_update_visual_transform()


func _update_visual_transform() -> void:
	if (
		not is_instance_valid(_mesh)
		or not is_instance_valid(_symbol_mesh)
		or not is_instance_valid(_body)
	):
		return
	var radius_m: float = _current_radius / PIXELS_PER_METER
	var render_plane_position: Vector2 = world_position_to_plane(_body.position)
	if _render_clamp_enabled:
		var half: float = Config.data.board_size * 0.5
		var limit: float = maxf(half - _current_radius, 0.0)
		render_plane_position = Vector2(
			clampf(render_plane_position.x, -limit, limit),
			clampf(render_plane_position.y, -limit, limit)
		)
	var render_world_position: Vector3 = plane_position_to_world(
		render_plane_position,
		_body.position.z
	)
	_mesh.position = render_world_position
	var stretch_scale: Vector3 = visual_stretch_scale()
	_mesh.scale = _visual_punch_scale * stretch_scale
	if stretch_scale.is_equal_approx(Vector3.ONE):
		_mesh.rotation = _body.rotation
	else:
		var world_velocity: Vector3 = _body.linear_velocity
		_mesh.rotation = Vector3(0.0, 0.0, atan2(world_velocity.y, world_velocity.x))
	_symbol_mesh.position = render_world_position + Vector3(0.0, 0.0, radius_m + 0.002)
	_symbol_mesh.rotation = Vector3.ZERO
	var symbol_size_m: float = radius_m * OrbSymbols.SYMBOL_SIZE_FACTOR
	_symbol_mesh.scale = Vector3(symbol_size_m, symbol_size_m, 1.0)
