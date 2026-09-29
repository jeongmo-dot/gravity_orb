class_name Board
extends Node2D

signal orb_contact(a: Orb, b: Orb)

const ORB_SCENE: PackedScene = preload("res://scenes/Orb.tscn")
const FRAME_WIDTH: float = 4.0

@onready var _wall_top: StaticBody2D = %WallTop
@onready var _wall_bottom: StaticBody2D = %WallBottom
@onready var _wall_left: StaticBody2D = %WallLeft
@onready var _wall_right: StaticBody2D = %WallRight
@onready var _frame_border: Line2D = %Border
@onready var _orbs_node: Node2D = %Orbs

var _orbs: Array[Orb] = []
var _gravity_direction: Vector2i = Vector2i.DOWN
var escape_guard_count: int = 0


func _ready() -> void:
	_configure_walls()
	_configure_frame()


func half_size() -> float:
	return Config.data.board_size * 0.5


func set_gravity(direction: Vector2i) -> void:
	_gravity_direction = direction
	for orb: Orb in _orbs:
		orb.set_gravity(_gravity_direction, Config.data.gravity_strength)


func spawn_orb(
	p_color: int,
	p_level: int,
	p_position: Vector2,
	p_velocity: Vector2 = Vector2.ZERO,
	p_generation: int = 0
) -> Orb:
	var spawn_physics_frame: int = Engine.get_physics_frames()
	for existing_orb: Orb in _orbs:
		if is_instance_valid(existing_orb) and not existing_orb.consumed:
			existing_orb.note_board_spawn(spawn_physics_frame)
	var orb: Orb = ORB_SCENE.instantiate() as Orb
	_orbs_node.add_child(orb)
	orb.setup(p_color, p_level, Config.data)
	orb.note_board_spawn(spawn_physics_frame)
	orb.position = p_position
	orb.linear_velocity = p_velocity
	orb.generation = p_generation
	orb.set_gravity(_gravity_direction, Config.data.gravity_strength)
	orb.body_entered.connect(_on_orb_body_entered.bind(orb))
	orb.escape_guard_triggered.connect(_on_orb_escape_guard_triggered)
	_orbs.append(orb)
	_print_growth_spawn_diagnostic(orb, spawn_physics_frame)
	return orb


func remove_orb(orb: Orb) -> void:
	if not is_instance_valid(orb) or orb.consumed:
		return
	orb.consumed = true
	_orbs.erase(orb)
	orb.collision_layer = 0
	orb.collision_mask = 0
	orb.freeze = true
	orb.queue_free()


func get_orbs() -> Array[Orb]:
	var active_orbs: Array[Orb] = []
	for orb: Orb in _orbs:
		if is_instance_valid(orb) and not orb.consumed:
			active_orbs.append(orb)
	return active_orbs


func clear() -> void:
	var orbs_to_remove: Array[Orb] = _orbs.duplicate()
	for orb: Orb in orbs_to_remove:
		remove_orb(orb)


func spawn_line(gravity: Vector2i, radius: float) -> Dictionary:
	var half: float = half_size()
	return {
		"origin": -Vector2(gravity) * (half - radius - Config.data.spawn_margin),
		"axis": Vector2(OrbTypes.perpendicular(gravity)),
		"extent": half - radius,
	}


func _on_orb_body_entered(other_body: Node, orb: Orb) -> void:
	var other: Orb = other_body as Orb
	if other == null or orb.consumed or other.consumed:
		return
	if orb.get_instance_id() < other.get_instance_id():
		orb_contact.emit(orb, other)


func _on_orb_escape_guard_triggered(_axis: String, _depth: float) -> void:
	escape_guard_count += 1


func _print_growth_spawn_diagnostic(orb: Orb, physics_frame: int) -> void:
	if not OS.get_cmdline_user_args().has("--growth-diagnose"):
		return
	var overlaps: Array[String] = []
	for other: Orb in _orbs:
		if other == orb or other.consumed:
			continue
		var distance: float = orb.position.distance_to(other.position)
		var penetration: float = (
			orb.get_current_radius() + other.get_current_radius() - distance
		)
		if penetration <= 0.0:
			continue
		overlaps.append(
			"id=%d level=%d distance=%.3f penetration=%.3f current_radius=%.3f velocity=%s" % [
				other.get_instance_id(),
				other.level,
				distance,
				penetration,
				other.get_current_radius(),
				str(other.linear_velocity),
			]
		)
	print(
		"GROWTH_SPAWN frame=%d id=%d level=%d current_radius=%.3f final_radius=%.3f position=%s velocity=%s overlaps=%s" % [
			physics_frame,
			orb.get_instance_id(),
			orb.level,
			orb.get_current_radius(),
			orb.get_radius(),
			str(orb.position),
			str(orb.linear_velocity),
			str(overlaps),
		]
	)


func _configure_walls() -> void:
	var half: float = half_size()
	var thickness: float = Config.data.wall_thickness
	var wall_material: PhysicsMaterial = PhysicsMaterial.new()
	wall_material.friction = Config.data.wall_friction
	wall_material.bounce = Config.data.wall_bounce

	_configure_wall(
		_wall_top,
		Vector2(0.0, -half - thickness * 0.5),
		Vector2(Config.data.board_size + thickness * 2.0, thickness),
		wall_material
	)
	_configure_wall(
		_wall_bottom,
		Vector2(0.0, half + thickness * 0.5),
		Vector2(Config.data.board_size + thickness * 2.0, thickness),
		wall_material
	)
	_configure_wall(
		_wall_left,
		Vector2(-half - thickness * 0.5, 0.0),
		Vector2(thickness, Config.data.board_size + thickness * 2.0),
		wall_material
	)
	_configure_wall(
		_wall_right,
		Vector2(half + thickness * 0.5, 0.0),
		Vector2(thickness, Config.data.board_size + thickness * 2.0),
		wall_material
	)


func _configure_wall(
	wall: StaticBody2D,
	wall_position: Vector2,
	wall_size: Vector2,
	material: PhysicsMaterial
) -> void:
	wall.position = wall_position
	wall.collision_layer = 1
	wall.collision_mask = 2
	wall.physics_material_override = material
	var collision_shape: CollisionShape2D = wall.get_node("CollisionShape2D") as CollisionShape2D
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = wall_size
	collision_shape.shape = rectangle


func _configure_frame() -> void:
	var half: float = half_size()
	_frame_border.points = PackedVector2Array(
		[
			Vector2(-half, -half),
			Vector2(half, -half),
			Vector2(half, half),
			Vector2(-half, half),
		]
	)
	_frame_border.width = FRAME_WIDTH
	_frame_border.default_color = Color.WHITE
	_frame_border.closed = true
