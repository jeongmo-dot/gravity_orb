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
var ghost_timeout_count: int = 0
var ghost_completed_count: int = 0
var ghost_total_duration: float = 0.0


func _ready() -> void:
	_configure_walls()
	_configure_frame()


func _physics_process(delta: float) -> void:
	_update_ghost_orbs(delta)


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
	orb.enter_ghost_state(Config.data.ghost_alpha)
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


func average_ghost_duration() -> float:
	if ghost_completed_count == 0:
		return 0.0
	return ghost_total_duration / float(ghost_completed_count)


func _update_ghost_orbs(delta: float) -> void:
	for orb: Orb in get_orbs():
		if not orb.is_ghost:
			continue
		orb.advance_ghost(delta)
		var maximum_overlap: float = _maximum_normal_overlap(orb)
		if maximum_overlap <= Config.data.ghost_exit_overlap:
			_complete_ghost(orb, false, maximum_overlap)
		elif (
			orb.ghost_elapsed >= Config.data.ghost_max_time
			or is_equal_approx(
				orb.ghost_elapsed,
				Config.data.ghost_max_time
			)
		):
			_complete_ghost(orb, true, maximum_overlap)


func _maximum_normal_overlap(ghost: Orb) -> float:
	var maximum_overlap: float = 0.0
	for other: Orb in _orbs:
		if (
			other == ghost
			or not is_instance_valid(other)
			or other.consumed
			or other.is_ghost
		):
			continue
		var overlap: float = (
			ghost.get_current_radius()
			+ other.get_current_radius()
			- ghost.position.distance_to(other.position)
		)
		maximum_overlap = maxf(maximum_overlap, overlap)
	return maximum_overlap


func _complete_ghost(orb: Orb, timed_out: bool, maximum_overlap: float) -> void:
	var duration: float = orb.ghost_elapsed
	if timed_out:
		_restore_existing_orbs_inside_board(orb)
		_relieve_timeout_overlap(orb)
	orb.exit_ghost_state()
	ghost_completed_count += 1
	ghost_total_duration += duration
	if not timed_out:
		return
	ghost_timeout_count += 1
	push_warning(
		"[GHOST_TIMEOUT] id=%d level=%d elapsed=%.3f max_overlap=%.3f" % [
			orb.get_instance_id(),
			orb.level,
			duration,
			maximum_overlap,
		]
	)


func _restore_existing_orbs_inside_board(excluded_orb: Orb) -> void:
	for orb: Orb in _orbs:
		if (
			orb == excluded_orb
			or not is_instance_valid(orb)
			or orb.consumed
		):
			continue
		var center_limit: float = maxf(
			half_size()
			- orb.get_current_radius()
			- Config.data.ghost_exit_overlap,
			0.0
		)
		var corrected_position: Vector2 = Vector2(
			clampf(orb.position.x, -center_limit, center_limit),
			clampf(orb.position.y, -center_limit, center_limit)
		)
		if corrected_position.is_equal_approx(orb.position):
			continue
		var corrected_velocity: Vector2 = orb.linear_velocity
		for axis_index: int in range(2):
			var original_coordinate: float = orb.position[axis_index]
			var velocity_component: float = corrected_velocity[axis_index]
			if (
				original_coordinate > center_limit
				and velocity_component > 0.0
			) or (
				original_coordinate < -center_limit
				and velocity_component < 0.0
			):
				corrected_velocity[axis_index] = 0.0
		orb.queue_timeout_correction(corrected_position, corrected_velocity)


func _relieve_timeout_overlap(orb: Orb) -> void:
	var normal_orbs: Array[Orb] = []
	for other: Orb in _orbs:
		if (
			other != orb
			and is_instance_valid(other)
			and not other.consumed
			and not other.is_ghost
		):
			normal_orbs.append(other)
	if normal_orbs.is_empty():
		return

	var original_position: Vector2 = orb.position
	var corrected_position: Vector2 = original_position
	var maximum_passes: int = normal_orbs.size() * normal_orbs.size()
	for _pass: int in range(maximum_passes):
		var changed: bool = false
		for other: Orb in normal_orbs:
			var other_position: Vector2 = _clamp_orb_center(
				other.position,
				other.get_current_radius()
			)
			var target_distance: float = (
				orb.get_current_radius()
				+ other.get_current_radius()
				+ Config.data.ghost_exit_overlap
			)
			var offset: Vector2 = corrected_position - other_position
			if offset.length_squared() >= target_distance * target_distance:
				continue
			var best_position: Vector2 = corrected_position
			var best_overlap: float = _maximum_overlap_at(
				orb,
				corrected_position,
				normal_orbs
			)
			var best_distance_squared: float = INF
			for direction: Vector2 in _timeout_relief_directions(offset):
				var candidate: Vector2 = _clamp_orb_center(
					other_position + direction * target_distance,
					orb.get_current_radius()
				)
				var candidate_overlap: float = _maximum_overlap_at(
					orb,
					candidate,
					normal_orbs
				)
				var candidate_distance_squared: float = (
					candidate.distance_squared_to(corrected_position)
				)
				if (
					candidate_overlap < best_overlap
					or (
						is_equal_approx(candidate_overlap, best_overlap)
						and candidate_distance_squared < best_distance_squared
					)
				):
					best_position = candidate
					best_overlap = candidate_overlap
					best_distance_squared = candidate_distance_squared
			if not best_position.is_equal_approx(corrected_position):
				corrected_position = best_position
				changed = true
		if (
			not changed
			or is_zero_approx(
				_maximum_overlap_at(orb, corrected_position, normal_orbs)
			)
		):
			break

	if not corrected_position.is_equal_approx(orb.position):
		orb.queue_timeout_correction(corrected_position, orb.linear_velocity)


func _timeout_relief_directions(offset: Vector2) -> Array[Vector2]:
	var directions: Array[Vector2] = []
	if not offset.is_zero_approx():
		directions.append(offset.normalized())
	var gravity_axis: Vector2 = Vector2(_gravity_direction).normalized()
	if gravity_axis.is_zero_approx():
		gravity_axis = Vector2.DOWN
	var perpendicular: Vector2 = Vector2(-gravity_axis.y, gravity_axis.x)
	for direction: Vector2 in [
		-gravity_axis,
		perpendicular,
		-perpendicular,
		gravity_axis,
	]:
		if not directions.has(direction):
			directions.append(direction)
	return directions


func _maximum_overlap_at(
	orb: Orb,
	position: Vector2,
	normal_orbs: Array[Orb]
) -> float:
	var maximum_overlap: float = 0.0
	for other: Orb in normal_orbs:
		var other_position: Vector2 = _clamp_orb_center(
			other.position,
			other.get_current_radius()
		)
		var overlap: float = (
			orb.get_current_radius()
			+ other.get_current_radius()
			- position.distance_to(other_position)
		)
		maximum_overlap = maxf(maximum_overlap, overlap)
	return maximum_overlap


func _clamp_orb_center(position: Vector2, radius: float) -> Vector2:
	var center_limit: float = maxf(half_size() - radius, 0.0)
	return Vector2(
		clampf(position.x, -center_limit, center_limit),
		clampf(position.y, -center_limit, center_limit)
	)


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
