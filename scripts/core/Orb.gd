class_name Orb
extends RigidBody2D

signal escape_guard_triggered(axis: String, depth: float)
signal wall_recovery_triggered(
	level: int,
	axis: String,
	depth: float,
	ghost: bool,
	age_frames: int,
	since_last_spawn_frames: int,
	physics_frame: int
)

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: OrbVisual = $Visual

var color: int
var level: int
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
var diagnostic_warnings_enabled: bool = true
var _radius: float = 0.0
var _current_radius: float = 0.0
var _growth_start_radius: float = 0.0
var _growth_duration: float = 0.0
var _growth_elapsed: float = 0.0
var _spawn_physics_frame: int = 0
var _last_board_spawn_physics_frame: int = 0
var _last_escape_guard_physics_frame: int = -1
var _gravity_direction: Vector2 = Vector2.DOWN
var _rest_braking_active: bool = false
var _last_rolling_resistance_force: Vector2 = Vector2.ZERO
var _timeout_correction_pending: bool = false
var _timeout_corrected_position: Vector2 = Vector2.ZERO
var _timeout_corrected_velocity: Vector2 = Vector2.ZERO


func setup(p_color: int, p_level: int, cfg: GameConfig) -> void:
	color = p_color
	level = p_level
	_radius = cfg.radius_for_level(level)
	_growth_duration = maxf(cfg.grow_duration, 0.0)
	_growth_start_radius = _radius * clampf(cfg.grow_start_ratio, 0.0, 1.0)
	_current_radius = (
		_radius if _growth_duration <= 0.0 else _growth_start_radius
	)
	_growth_elapsed = 0.0
	_spawn_physics_frame = Engine.get_physics_frames()
	_last_board_spawn_physics_frame = _spawn_physics_frame
	diagnostic_last_event = "spawn"
	diagnostic_last_event_physics_frame = _spawn_physics_frame

	gravity_scale = 0.0
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = cfg.contact_max_reported
	mass = cfg.mass_for_level(level)
	linear_damp = cfg.orb_linear_damp
	angular_damp = cfg.orb_angular_damp
	collision_layer = 2
	collision_mask = 3

	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = cfg.orb_friction
	material.bounce = cfg.orb_bounce
	physics_material_override = material

	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = _current_radius
	_collision_shape.shape = circle
	_visual.setup(cfg.color_display[color], _current_radius)


func get_radius() -> float:
	return _radius


func get_current_radius() -> float:
	return _current_radius


func get_colliding_orbs() -> Array:
	var result: Array = []
	for body: Node2D in get_colliding_bodies():
		var candidate: Orb = body as Orb
		if candidate != null:
			result.append(candidate)
	return result


func enter_ghost_state(alpha: float) -> void:
	is_ghost = true
	ghost_elapsed = 0.0
	collision_layer = 4
	collision_mask = 1
	_visual.set_alpha(alpha)


func exit_ghost_state() -> void:
	is_ghost = false
	is_waiting_at_entrance = false
	collision_layer = 2
	collision_mask = 3
	_visual.set_alpha(1.0)
	_visual.set_waiting_at_entrance(false)


func advance_ghost(delta: float) -> void:
	if is_ghost:
		ghost_elapsed += delta


func enter_entrance_wait(preferred_position: Vector2, gravity: Vector2i) -> void:
	is_waiting_at_entrance = true
	entrance_preferred_position = preferred_position
	entrance_gravity = gravity
	constant_force = Vector2.ZERO
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_visual.set_waiting_at_entrance(true)


func release_entrance_wait(
	spawn_position: Vector2,
	gravity: Vector2i,
	gravity_strength: float
) -> void:
	is_waiting_at_entrance = false
	_visual.set_waiting_at_entrance(false)
	queue_timeout_correction(spawn_position, Vector2.ZERO)
	angular_velocity = 0.0
	set_gravity(gravity, gravity_strength)
	note_diagnostic_event("entrance_release")


func queue_timeout_correction(
	corrected_position: Vector2,
	corrected_velocity: Vector2
) -> void:
	_timeout_correction_pending = true
	_timeout_corrected_position = corrected_position
	_timeout_corrected_velocity = corrected_velocity
	position = corrected_position
	linear_velocity = corrected_velocity


func note_board_spawn(physics_frame: int) -> void:
	_last_board_spawn_physics_frame = physics_frame


func note_diagnostic_event(event_name: String, physics_frame: int = -1) -> void:
	diagnostic_last_event = event_name
	diagnostic_last_event_physics_frame = (
		Engine.get_physics_frames() if physics_frame < 0 else physics_frame
	)


func set_gravity(direction: Vector2i, strength: float) -> void:
	_gravity_direction = Vector2(direction)
	constant_force = (
		Vector2.ZERO
		if is_waiting_at_entrance
		else _gravity_direction * strength * mass
	)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if is_waiting_at_entrance:
		var waiting_transform: Transform2D = state.transform
		var waiting_parent: Node2D = get_parent() as Node2D
		waiting_transform.origin = (
			entrance_preferred_position
			if waiting_parent == null
			else waiting_parent.to_global(entrance_preferred_position)
		)
		state.transform = waiting_transform
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		return
	if _timeout_correction_pending:
		_timeout_correction_pending = false
		var timeout_transform: Transform2D = state.transform
		var timeout_parent: Node2D = get_parent() as Node2D
		timeout_transform.origin = (
			_timeout_corrected_position
			if timeout_parent == null
			else timeout_parent.to_global(_timeout_corrected_position)
		)
		state.transform = timeout_transform
		state.linear_velocity = _timeout_corrected_velocity
	_apply_proactive_wall_recovery(state)


func _apply_proactive_wall_recovery(state: PhysicsDirectBodyState2D) -> void:
	var parent_2d: Node2D = get_parent() as Node2D
	var local_position: Vector2 = (
		state.transform.origin
		if parent_2d == null
		else parent_2d.to_local(state.transform.origin)
	)
	var corrected_position: Vector2 = local_position
	var corrected_velocity: Vector2 = state.linear_velocity
	var half: float = Config.data.board_size * 0.5
	var center_limit: float = maxf(half - _current_radius, 0.0)
	var corrected: bool = false
	for axis_index: int in range(2):
		var coordinate: float = local_position[axis_index]
		var penetration: float = absf(coordinate) - center_limit
		if penetration <= Config.data.wall_penetration_limit:
			continue
		var wall_sign: float = signf(coordinate)
		corrected_position[axis_index] = wall_sign * center_limit
		if corrected_velocity[axis_index] * wall_sign > 0.0:
			corrected_velocity[axis_index] = 0.0
		var axis_name: String = "x" if axis_index == 0 else "y"
		var physics_frame: int = Engine.get_physics_frames()
		var age_frames: int = maxi(physics_frame - _spawn_physics_frame, 0)
		var since_last_spawn_frames: int = maxi(
			physics_frame - _last_board_spawn_physics_frame,
			0
		)
		wall_recovery_triggered.emit(
			level,
			axis_name,
			penetration,
			is_ghost,
			age_frames,
			since_last_spawn_frames,
			physics_frame
		)
		corrected = true
	if not corrected:
		return
	var corrected_transform: Transform2D = state.transform
	corrected_transform.origin = (
		corrected_position
		if parent_2d == null
		else parent_2d.to_global(corrected_position)
	)
	state.transform = corrected_transform
	state.linear_velocity = corrected_velocity


func _physics_process(delta: float) -> void:
	_advance_growth(delta)
	_last_rolling_resistance_force = Vector2.ZERO
	if _apply_escape_guard():
		return

	if _rest_braking_active:
		linear_damp = Config.data.orb_linear_damp
		angular_damp = Config.data.orb_angular_damp
		_rest_braking_active = false

	var resistance: float = Config.data.rolling_resistance * Config.data.gravity_strength
	if resistance <= 0.0 and Config.data.rest_speed <= 0.0:
		return

	var gravity_axis: Vector2 = _gravity_direction.normalized()
	var floor_limit: float = (
		Config.data.board_size * 0.5
		- _current_radius
		- Config.data.floor_contact_tolerance
	)
	if position.dot(gravity_axis) < floor_limit:
		return

	if (
		Config.data.rest_speed > 0.0
		and linear_velocity.length() < Config.data.rest_speed
	):
		linear_damp = Config.data.rest_damp
		angular_damp = Config.data.rest_damp
		_rest_braking_active = true

	if resistance <= 0.0:
		return

	var gravity_velocity: Vector2 = gravity_axis * linear_velocity.dot(gravity_axis)
	var rolling_velocity: Vector2 = linear_velocity - gravity_velocity
	var rolling_speed: float = rolling_velocity.length()
	if delta <= 0.0:
		return

	var remaining_ratio: float = 0.0
	if not is_zero_approx(rolling_speed):
		var deceleration: float = minf(resistance, rolling_speed / delta)
		var resistance_force: Vector2 = -rolling_velocity.normalized() * deceleration * mass
		_last_rolling_resistance_force = resistance_force
		apply_central_force(resistance_force)
		remaining_ratio = maxf(1.0 - deceleration * delta / rolling_speed, 0.0)

	if is_zero_approx(angular_velocity):
		return
	var circle_inertia: float = 0.5 * mass * _current_radius * _current_radius
	var angular_acceleration: float = -angular_velocity * (1.0 - remaining_ratio) / delta
	apply_torque(angular_acceleration * circle_inertia)


func _apply_escape_guard() -> bool:
	var half: float = Config.data.board_size * 0.5
	var corrected_position: Vector2 = position
	var corrected_velocity: Vector2 = linear_velocity
	var triggered: bool = false
	for axis_index: int in range(2):
		var coordinate: float = position[axis_index]
		var depth: float = absf(coordinate) + _current_radius - half
		if depth <= Config.data.escape_guard_depth:
			continue
		var wall_sign: float = signf(coordinate)
		corrected_position[axis_index] = wall_sign * (half - _current_radius)
		if corrected_velocity[axis_index] * wall_sign > 0.0:
			corrected_velocity[axis_index] = 0.0
		var axis_name: String = "x" if axis_index == 0 else "y"
		escape_guard_triggered.emit(axis_name, depth)
		var physics_frame: int = Engine.get_physics_frames()
		_last_escape_guard_physics_frame = physics_frame
		var age_frames: int = maxi(physics_frame - _spawn_physics_frame, 0)
		var since_last_spawn_frames: int = maxi(
			physics_frame - _last_board_spawn_physics_frame,
			0
		)
		if diagnostic_warnings_enabled:
			push_warning(
				"[ESCAPE_GUARD] level=%d axis=%s depth=%.3f age_frames=%d since_last_spawn_frames=%d" % [
					level,
					axis_name,
					depth,
					age_frames,
					since_last_spawn_frames,
				]
			)
		triggered = true
	if not triggered:
		return false

	var corrected_transform: Transform2D = global_transform
	var parent_2d: Node2D = get_parent() as Node2D
	corrected_transform.origin = (
		corrected_position
		if parent_2d == null
		else parent_2d.to_global(corrected_position)
	)
	PhysicsServer2D.body_set_state(
		get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		corrected_transform
	)
	PhysicsServer2D.body_set_state(
		get_rid(),
		PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,
		corrected_velocity
	)
	return true


func _advance_growth(delta: float) -> void:
	if _current_radius >= _radius or _growth_duration <= 0.0:
		return
	_growth_elapsed = minf(_growth_elapsed + delta, _growth_duration)
	var progress: float = _growth_elapsed / _growth_duration
	_set_current_radius(lerpf(_growth_start_radius, _radius, progress))


func _set_current_radius(radius: float) -> void:
	_current_radius = minf(radius, _radius)
	var circle: CircleShape2D = _collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = _current_radius
	_visual.set_radius(_current_radius)
