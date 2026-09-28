class_name Orb
extends RigidBody2D

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: OrbVisual = $Visual

var color: int
var level: int
var generation: int = 0
var consumed: bool = false
var _radius: float = 0.0
var _gravity_direction: Vector2 = Vector2.DOWN
var _rest_braking_active: bool = false


func setup(p_color: int, p_level: int, cfg: GameConfig) -> void:
	color = p_color
	level = p_level
	_radius = cfg.radius_for_level(level)

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
	circle.radius = _radius
	_collision_shape.shape = circle
	_visual.setup(cfg.color_display[color], _radius)


func get_radius() -> float:
	return _radius


func set_gravity(direction: Vector2i, strength: float) -> void:
	_gravity_direction = Vector2(direction)
	constant_force = _gravity_direction * strength * mass


func _physics_process(delta: float) -> void:
	if _rest_braking_active:
		linear_damp = Config.data.orb_linear_damp
		angular_damp = Config.data.orb_angular_damp
		_rest_braking_active = false

	var resistance: float = Config.data.rolling_resistance * Config.data.gravity_strength
	if resistance <= 0.0 and Config.data.rest_speed <= 0.0:
		return

	if get_contact_count() <= 0:
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

	var gravity_axis: Vector2 = _gravity_direction.normalized()
	var gravity_velocity: Vector2 = gravity_axis * linear_velocity.dot(gravity_axis)
	var rolling_velocity: Vector2 = linear_velocity - gravity_velocity
	var rolling_speed: float = rolling_velocity.length()
	if delta <= 0.0:
		return

	var remaining_ratio: float = 0.0
	if not is_zero_approx(rolling_speed):
		var deceleration: float = minf(resistance, rolling_speed / delta)
		var resistance_force: Vector2 = -rolling_velocity.normalized() * deceleration * mass
		apply_central_force(resistance_force)
		remaining_ratio = maxf(1.0 - deceleration * delta / rolling_speed, 0.0)

	if is_zero_approx(angular_velocity):
		return
	var circle_inertia: float = 0.5 * mass * _radius * _radius
	var angular_acceleration: float = -angular_velocity * (1.0 - remaining_ratio) / delta
	apply_torque(angular_acceleration * circle_inertia)
