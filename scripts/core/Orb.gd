class_name Orb
extends RigidBody2D

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: OrbVisual = $Visual

var color: int
var level: int
var _radius: float = 0.0


func setup(p_color: int, p_level: int, cfg: GameConfig) -> void:
	color = p_color
	level = p_level
	_radius = cfg.radius_for_level(level)

	gravity_scale = 0.0
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
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
	constant_force = Vector2(direction) * strength * mass
