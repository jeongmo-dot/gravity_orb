class_name Board3D
extends Node3D

signal orb_contact(a: Orb3D, b: Orb3D)

const ORB_SCENE: PackedScene = preload("res://scenes/Orb3D.tscn")
const PIXELS_PER_METER: float = 100.0
const VISUAL_WALL_WIDTH_M: float = 0.12
const VISUAL_TILT_DEGREES: float = 4.0
const VISUAL_TILT_DURATION: float = 0.25

@onready var _orbs_node: Node3D = %Orbs
@onready var _physics_geometry: Node3D = %PhysicsGeometry
@onready var _visual_tilt: Node3D = %VisualTilt

var _orbs: Array[Orb3D] = []
var _gravity_direction: Vector2i = Vector2i.DOWN
var _warning_directions: Array[Vector2i] = []
var _tilt_tween: Tween


func _ready() -> void:
	_configure_walls()
	_configure_visuals()


func _physics_process(_delta: float) -> void:
	_update_entrance_waiters()


func half_size() -> float:
	return Config.data.board_size * 0.5


func set_gravity(direction: Vector2i) -> void:
	_gravity_direction = direction
	for orb: Orb3D in _orbs:
		orb.set_gravity(direction, Config.data.gravity_strength)


func play_visual_tilt(direction: Vector2i) -> void:
	if _tilt_tween != null and _tilt_tween.is_valid():
		_tilt_tween.kill()
	var target: Vector3 = Vector3(
		-float(direction.y) * VISUAL_TILT_DEGREES,
		float(direction.x) * VISUAL_TILT_DEGREES,
		0.0
	)
	_tilt_tween = create_tween()
	_tilt_tween.set_trans(Tween.TRANS_QUAD)
	_tilt_tween.set_ease(Tween.EASE_OUT)
	_tilt_tween.tween_property(
		_visual_tilt,
		"rotation_degrees",
		target,
		VISUAL_TILT_DURATION * 0.45
	)
	_tilt_tween.set_ease(Tween.EASE_IN_OUT)
	_tilt_tween.tween_property(
		_visual_tilt,
		"rotation_degrees",
		Vector3.ZERO,
		VISUAL_TILT_DURATION * 0.55
	)


func spawn_orb(
	p_color: int,
	p_level: int,
	p_position: Vector2,
	p_velocity: Vector2 = Vector2.ZERO,
	p_generation: int = 0
) -> Orb3D:
	var orb: Orb3D = ORB_SCENE.instantiate() as Orb3D
	_orbs_node.add_child(orb)
	orb.setup(p_color, p_level, Config.data)
	orb.position = p_position
	orb.linear_velocity = p_velocity
	orb.generation = p_generation
	orb.set_gravity(_gravity_direction, Config.data.gravity_strength)
	orb.get_physics_body().body_entered.connect(_on_orb_body_entered.bind(orb))
	_orbs.append(orb)
	return orb


func remove_orb(orb: Orb3D) -> void:
	if not is_instance_valid(orb) or orb.consumed:
		return
	orb.consumed = true
	_orbs.erase(orb)
	orb.disable_physics()
	orb.queue_free()


func get_orbs() -> Array[Orb3D]:
	var active: Array[Orb3D] = []
	for orb: Orb3D in _orbs:
		if is_instance_valid(orb) and not orb.consumed:
			active.append(orb)
	return active


func clear() -> void:
	var to_remove: Array[Orb3D] = _orbs.duplicate()
	for orb: Orb3D in to_remove:
		remove_orb(orb)


func spawn_line(gravity: Vector2i, radius: float) -> Dictionary:
	var half: float = half_size()
	return {
		"origin": -Vector2(gravity) * (half - radius - Config.data.spawn_margin),
		"axis": Vector2(OrbTypes.perpendicular(gravity)),
		"extent": half - radius,
	}


func find_free_spawn_slot(
	gravity: Vector2i,
	radius: float,
	placed: Array[Dictionary],
	preferred_position: Vector2 = Vector2.ZERO
) -> Dictionary:
	var line: Dictionary = spawn_line(gravity, radius)
	var origin: Vector2 = line["origin"] as Vector2
	var axis: Vector2 = line["axis"] as Vector2
	var extent: float = float(line["extent"])
	var preferred_offset: float = clampf(
		(preferred_position - origin).dot(axis),
		-extent,
		extent
	)
	var offsets: Array[float] = [preferred_offset]
	var step: float = maxf(Config.data.spawn_probe_step, 0.001)
	var sample_count: int = ceili(extent * 2.0 / step)
	for sample_index: int in range(sample_count + 1):
		var offset: float = minf(-extent + float(sample_index) * step, extent)
		if not _contains_approx(offsets, offset):
			offsets.append(offset)

	var found: bool = false
	var best_position: Vector2 = preferred_position
	var best_distance: float = INF
	var best_offset: float = INF
	for offset: float in offsets:
		var candidate_position: Vector2 = origin + axis * offset
		if not _spawn_probe_is_clear(candidate_position, radius, placed):
			continue
		var distance: float = absf(offset - preferred_offset)
		if (
			not found
			or distance < best_distance
			or (is_equal_approx(distance, best_distance) and offset < best_offset)
		):
			found = true
			best_position = candidate_position
			best_distance = distance
			best_offset = offset
	return {"found": found, "position": best_position}


func entrance_waiting_orbs() -> Array[Orb3D]:
	var waiting: Array[Orb3D] = []
	for orb: Orb3D in get_orbs():
		if orb.is_waiting_at_entrance:
			waiting.append(orb)
	return waiting


func normal_overlap_count(target: Orb3D) -> int:
	var count: int = 0
	for other: Orb3D in get_orbs():
		if other == target or other.is_waiting_at_entrance:
			continue
		var overlap: float = (
			target.get_radius()
			+ other.get_radius()
			- target.position.distance_to(other.position)
		)
		if overlap > Config.data.ghost_exit_overlap:
			count += 1
	return count


func blocked_spawn_directions(batch: Array[Dictionary]) -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	for direction: Vector2i in OrbTypes.DIRECTIONS:
		if not _batch_fits_spawn_line(direction, batch):
			blocked.append(direction)
	return blocked


func set_warning_directions(directions: Array[Vector2i]) -> void:
	_warning_directions.clear()
	_warning_directions.append_array(directions)


func _batch_fits_spawn_line(gravity: Vector2i, batch: Array[Dictionary]) -> bool:
	var radii: Array[float] = []
	for candidate: Dictionary in batch:
		radii.append(Config.data.radius_for_level(int(candidate["level"])))
	radii.sort()
	radii.reverse()
	var placed: Array[Dictionary] = []
	for radius: float in radii:
		var slot: Dictionary = find_free_spawn_slot(gravity, radius, placed)
		if not bool(slot["found"]):
			return false
		placed.append({"position": slot["position"], "radius": radius})
	return true


func _spawn_probe_is_clear(
	candidate_position: Vector2,
	radius: float,
	placed: Array[Dictionary]
) -> bool:
	for orb: Orb3D in get_orbs():
		if orb.is_waiting_at_entrance:
			continue
		var overlap: float = (
			radius
			+ orb.get_radius()
			- candidate_position.distance_to(orb.position)
		)
		if overlap > Config.data.ghost_exit_overlap:
			return false
	for item: Dictionary in placed:
		var overlap: float = (
			radius
			+ float(item["radius"])
			- candidate_position.distance_to(item["position"] as Vector2)
		)
		if overlap > Config.data.ghost_exit_overlap:
			return false
	return true


func _contains_approx(values: Array[float], target: float) -> bool:
	for value: float in values:
		if is_equal_approx(value, target):
			return true
	return false


func _update_entrance_waiters() -> void:
	var placed: Array[Dictionary] = []
	for orb: Orb3D in get_orbs():
		if not orb.is_waiting_at_entrance:
			placed.append({"position": orb.position, "radius": orb.get_radius()})
	for orb: Orb3D in entrance_waiting_orbs():
		var slot: Dictionary = find_free_spawn_slot(
			orb.entrance_gravity,
			orb.get_radius(),
			placed,
			orb.entrance_preferred_position
		)
		if not bool(slot["found"]):
			continue
		var spawn_position: Vector2 = slot["position"] as Vector2
		orb.release_entrance_wait(
			spawn_position,
			orb.entrance_gravity,
			Config.data.gravity_strength
		)
		placed.append({"position": spawn_position, "radius": orb.get_radius()})


func _on_orb_body_entered(other_body: Node, orb: Orb3D) -> void:
	var other: Orb3D = other_body.get_parent() as Orb3D
	if other == null or orb.consumed or other.consumed:
		return
	if orb.get_instance_id() < other.get_instance_id():
		orb_contact.emit(orb, other)


func _configure_walls() -> void:
	var half_m: float = half_size() / PIXELS_PER_METER
	var thickness_m: float = Config.data.wall_thickness / PIXELS_PER_METER
	var depth_m: float = 0.8
	var span_m: float = half_m * 2.0 + thickness_m * 2.0
	var wall_material: PhysicsMaterial = PhysicsMaterial.new()
	wall_material.friction = Config.data.wall_friction
	wall_material.bounce = Config.data.wall_bounce
	_configure_wall(
		"WallTop",
		Vector3(0.0, -half_m - thickness_m * 0.5, 0.0),
		Vector3(span_m, thickness_m, depth_m),
		wall_material
	)
	_configure_wall(
		"WallBottom",
		Vector3(0.0, half_m + thickness_m * 0.5, 0.0),
		Vector3(span_m, thickness_m, depth_m),
		wall_material
	)
	_configure_wall(
		"WallLeft",
		Vector3(-half_m - thickness_m * 0.5, 0.0, 0.0),
		Vector3(thickness_m, span_m, depth_m),
		wall_material
	)
	_configure_wall(
		"WallRight",
		Vector3(half_m + thickness_m * 0.5, 0.0, 0.0),
		Vector3(thickness_m, span_m, depth_m),
		wall_material
	)


func _configure_wall(
	wall_name: String,
	wall_position: Vector3,
	wall_size: Vector3,
	material: PhysicsMaterial
) -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.name = wall_name
	wall.position = wall_position
	wall.collision_layer = 1
	wall.collision_mask = 2
	wall.physics_material_override = material
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = wall_size
	collision_shape.shape = box
	wall.add_child(collision_shape)
	_physics_geometry.add_child(wall)


func _configure_visuals() -> void:
	var board_size_m: float = Config.data.board_size / PIXELS_PER_METER
	var half_m: float = board_size_m * 0.5
	var backing: MeshInstance3D = MeshInstance3D.new()
	backing.name = "Backing"
	backing.position = Vector3(0.0, 0.0, -0.34)
	var backing_mesh: BoxMesh = BoxMesh.new()
	backing_mesh.size = Vector3(board_size_m, board_size_m, 0.18)
	backing.mesh = backing_mesh
	backing.material_override = _visual_material(Color("#10192e"), 0.74, 0.0)
	_visual_tilt.add_child(backing)
	_add_visual_wall("VisualTop", Vector3(0.0, -half_m, 0.0), Vector3(board_size_m, VISUAL_WALL_WIDTH_M, 0.28))
	_add_visual_wall("VisualBottom", Vector3(0.0, half_m, 0.0), Vector3(board_size_m, VISUAL_WALL_WIDTH_M, 0.28))
	_add_visual_wall("VisualLeft", Vector3(-half_m, 0.0, 0.0), Vector3(VISUAL_WALL_WIDTH_M, board_size_m, 0.28))
	_add_visual_wall("VisualRight", Vector3(half_m, 0.0, 0.0), Vector3(VISUAL_WALL_WIDTH_M, board_size_m, 0.28))


func _add_visual_wall(wall_name: String, wall_position: Vector3, size: Vector3) -> void:
	var wall_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	wall_mesh_instance.name = wall_name
	wall_mesh_instance.position = wall_position
	var wall_mesh: BoxMesh = BoxMesh.new()
	wall_mesh.size = size
	wall_mesh_instance.mesh = wall_mesh
	wall_mesh_instance.material_override = _visual_material(Color("#8ec5ff"), 0.22, 0.18)
	_visual_tilt.add_child(wall_mesh_instance)


func _visual_material(color_value: Color, roughness: float, emission_energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color_value
	material.roughness = roughness
	material.metallic = 0.25
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color_value * emission_energy
	return material
