class_name Board3D
extends Node3D

signal orb_contact(a: Orb3D, b: Orb3D)

const ORB_SCENE: PackedScene = preload("res://scenes/Orb3D.tscn")
const PIXELS_PER_METER: float = 100.0
const VISUAL_WALL_WIDTH_M: float = 0.12
const VISUAL_TILT_DEGREES: float = 4.0
const VISUAL_TILT_DURATION: float = 0.25
const WARNING_FRAME_COLOR: Color = Color("#FF3B30")
const NORMAL_FRAME_COLOR: Color = Color("#8ec5ff")
const FEVER_FRAME_COLOR: Color = Color("#FF9F0A")
const BLAST_FLASH_DURATION: float = 0.18
const BLAST_FLASH_RADIUS_M: float = 1.5
const BLAST_SHAKE_DISTANCE_M: float = 0.06

@onready var _orbs_node: Node3D = %Orbs
@onready var _physics_geometry: Node3D = %PhysicsGeometry
@onready var _visual_tilt: Node3D = %VisualTilt

var _orbs: Array[Orb3D] = []
var _next_orb_spawn_id: int = 1
var _gravity_direction: Vector2i = Vector2i.DOWN
var _warning_directions: Array[Vector2i] = []
var _visual_walls: Dictionary = {}
var _tilt_tween: Tween
var _blast_flash: MeshInstance3D
var _blast_flash_material: StandardMaterial3D
var _blast_flash_remaining: float = 0.0
var _fever_active: bool = false
var orb_contact_reporting_enabled: bool = true
var orb_continuous_cd_enabled: bool = true
var orb_allow_sleep: bool = false
var orb_progressive_growth_enabled: bool = false
var reaction_ghost_enabled: bool = false
var ghost_timeout_count: int = 0
var ghost_completed_count: int = 0
var ghost_total_duration: float = 0.0


func _ready() -> void:
	_configure_walls()
	_configure_visuals()


func _physics_process(delta: float) -> void:
	_update_entrance_waiters()
	_update_ghost_orbs(delta)
	_update_blast_effect(delta)


func half_size() -> float:
	return Config.data.board_size * 0.5


func set_gravity(direction: Vector2i) -> void:
	_gravity_direction = direction
	for orb: Orb3D in _orbs:
		orb.set_gravity(direction, Config.data.gravity_strength)


func play_visual_tilt(direction: Vector2i) -> void:
	if _tilt_tween != null and _tilt_tween.is_valid():
		_tilt_tween.kill()
	var world_direction: Vector3 = Orb3D.plane_direction_to_world(direction)
	var target: Vector3 = Vector3(
		world_direction.y * VISUAL_TILT_DEGREES,
		world_direction.x * VISUAL_TILT_DEGREES,
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
	orb.configure_physics_profile(
		orb_contact_reporting_enabled,
		orb_continuous_cd_enabled,
		orb_allow_sleep,
		orb_progressive_growth_enabled
	)
	orb.setup(p_color, p_level, Config.data)
	orb.stable_spawn_id = _next_orb_spawn_id
	_next_orb_spawn_id += 1
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


func apply_shockwave(
	origin: Vector2,
	result_level: int,
	excluded_orb: Variant,
	is_jackpot: bool,
	result_color: int = OrbTypes.OrbColor.RED,
	shake_direction_provider: Callable = Callable()
) -> Array[Dictionary]:
	var result_radius: float = Config.data.radius_for_level(result_level)
	var level_multiplier: float = (
		1.0 + Config.data.shock_level_scale * float(result_level - 1)
	)
	var jackpot_multiplier: float = Config.data.shock_jackpot_scale if is_jackpot else 1.0
	var effect_mode: GameConfig.ShockMode = GameConfig.ShockMode.PUSH
	var impulse_scale: float = 1.0
	var radius_factor: float = Config.data.shock_radius_factor
	if Config.data.color_effects_enabled:
		effect_mode = _shock_mode_for_color(result_color)
		impulse_scale = _shock_color_value(
			Config.data.shock_color_impulse_scale,
			result_color,
			1.0
		)
		radius_factor = _shock_color_value(
			Config.data.shock_color_radius_factor,
			result_color,
			Config.data.shock_radius_factor
		)
	var shock_radius: float = radius_factor * result_radius
	var targets: Array[Dictionary] = []
	for orb: Orb3D in get_orbs():
		if orb == excluded_orb or orb.is_ghost or orb.is_waiting_at_entrance:
			continue
		var offset: Vector2 = orb.position - origin
		var distance: float = offset.length()
		var impulse: Vector2 = Vector2.ZERO
		var velocity_change: Vector2 = Vector2.ZERO
		if effect_mode == GameConfig.ShockMode.SHAKE:
			var shake_speed: float = minf(
				Config.data.green_shake_speed * level_multiplier * jackpot_multiplier,
				Config.data.green_shake_max_speed * jackpot_multiplier
			)
			var shake_direction: Vector2 = _next_shake_direction(shake_direction_provider)
			velocity_change = shake_direction * shake_speed
			impulse = velocity_change * orb.get_physics_body().mass
			orb.apply_plane_velocity_change(velocity_change)
		else:
			if is_zero_approx(distance) or shock_radius <= 0.0 or distance >= shock_radius:
				continue
			var impulse_strength: float = (
				Config.data.shock_impulse
				* impulse_scale
				* level_multiplier
				* (1.0 - distance / shock_radius)
				* jackpot_multiplier
			)
			var direction: Vector2 = offset / distance
			if effect_mode == GameConfig.ShockMode.PULL:
				direction = -direction
			elif effect_mode == GameConfig.ShockMode.LIFT:
				direction = -Vector2(_gravity_direction).normalized()
			impulse = direction * impulse_strength
			if not impulse.is_zero_approx():
				orb.apply_plane_impulse(impulse)
		targets.append({
			"orb": orb,
			"stable_spawn_id": orb.stable_spawn_id,
			"level": orb.level,
			"position": orb.position,
			"mode": effect_mode,
			"impulse": impulse,
			"velocity_change": velocity_change,
		})
	return targets


func apply_blast(origin: Vector2) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for orb: Orb3D in get_orbs():
		if orb.is_ghost or orb.is_waiting_at_entrance:
			continue
		var offset: Vector2 = orb.position - origin
		var distance: float = offset.length()
		var direction: Vector2 = (
			Vector2.RIGHT if is_zero_approx(distance) else offset / distance
		)
		var distance_ratio: float = clampf(distance / Config.data.board_size, 0.0, 1.0)
		var speed: float = Config.data.blast_speed * lerpf(
			1.0,
			Config.data.blast_far_factor,
			distance_ratio
		)
		var velocity_change: Vector2 = direction * speed
		orb.apply_plane_velocity_change(velocity_change)
		targets.append({
			"orb": orb,
			"stable_spawn_id": orb.stable_spawn_id,
			"level": orb.level,
			"position": orb.position,
			"velocity_change": velocity_change,
		})
	_play_blast_effect(origin)
	return targets


func _play_blast_effect(origin: Vector2) -> void:
	if is_instance_valid(_blast_flash):
		_blast_flash.queue_free()
	_blast_flash = MeshInstance3D.new()
	_blast_flash.name = "BlastFlash"
	var ring_mesh: ImmediateMesh = ImmediateMesh.new()
	_blast_flash_material = StandardMaterial3D.new()
	_blast_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blast_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blast_flash_material.albedo_color = Color.WHITE
	_blast_flash_material.emission_enabled = true
	_blast_flash_material.emission = Color.WHITE
	_blast_flash_material.vertex_color_use_as_albedo = true
	ring_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _blast_flash_material)
	for point_index: int in range(65):
		var angle: float = TAU * float(point_index) / 64.0
		ring_mesh.surface_set_color(Color.WHITE)
		ring_mesh.surface_add_vertex(Vector3(cos(angle), sin(angle), 0.0))
	ring_mesh.surface_end()
	_blast_flash.mesh = ring_mesh
	_blast_flash.position = Orb3D.plane_position_to_world(origin, 0.35)
	_visual_tilt.add_child(_blast_flash)
	_blast_flash_remaining = BLAST_FLASH_DURATION


func _update_blast_effect(delta: float) -> void:
	if _blast_flash_remaining <= 0.0:
		return
	_blast_flash_remaining = maxf(_blast_flash_remaining - delta, 0.0)
	var progress: float = 1.0 - _blast_flash_remaining / BLAST_FLASH_DURATION
	if is_instance_valid(_blast_flash):
		var radius: float = lerpf(0.12, BLAST_FLASH_RADIUS_M, progress)
		_blast_flash.scale = Vector3(radius, radius, radius)
	if _blast_flash_material != null:
		var flash_color: Color = Color(1.0, 1.0, 1.0, 1.0 - progress)
		_blast_flash_material.albedo_color = flash_color
		_blast_flash_material.emission = Color.WHITE * (1.0 - progress)
	if _blast_flash_remaining <= 0.0:
		_visual_tilt.position = Vector3.ZERO
		if is_instance_valid(_blast_flash):
			_blast_flash.queue_free()
		_blast_flash = null
		_blast_flash_material = null
	else:
		var strength: float = (1.0 - progress) * BLAST_SHAKE_DISTANCE_M
		_visual_tilt.position = Vector3(
			sin(progress * TAU * 3.0),
			cos(progress * TAU * 4.0),
			0.0
		) * strength


func _shock_mode_for_color(color: int) -> GameConfig.ShockMode:
	if color < 0 or color >= Config.data.shock_color_modes.size():
		return GameConfig.ShockMode.PUSH
	return int(Config.data.shock_color_modes[color]) as GameConfig.ShockMode


func _shock_color_value(values: PackedFloat32Array, color: int, fallback: float) -> float:
	if color < 0 or color >= values.size():
		return fallback
	return values[color]


func _next_shake_direction(provider: Callable) -> Vector2:
	if not provider.is_valid():
		return Vector2.RIGHT
	var direction: Vector2 = provider.call() as Vector2
	return Vector2.RIGHT if direction.is_zero_approx() else direction.normalized()


func clear() -> void:
	var to_remove: Array[Orb3D] = _orbs.duplicate()
	for orb: Orb3D in to_remove:
		remove_orb(orb)


func should_ghost_reaction_results() -> bool:
	return reaction_ghost_enabled


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
		if other == target or other.is_waiting_at_entrance or other.is_ghost:
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
	_update_warning_visuals()


func set_fever_active(active: bool) -> void:
	_fever_active = active
	_update_warning_visuals()


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
		if orb.is_waiting_at_entrance or orb.is_ghost:
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
		if not orb.is_waiting_at_entrance and not orb.is_ghost:
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


func maximum_normal_overlap(ghost: Orb3D) -> float:
	var maximum_overlap: float = 0.0
	for other: Orb3D in get_orbs():
		if other == ghost or other.is_ghost:
			continue
		var overlap: float = (
			ghost.get_current_radius()
			+ other.get_current_radius()
			- ghost.position.distance_to(other.position)
		)
		maximum_overlap = maxf(maximum_overlap, overlap)
	return maximum_overlap


func average_ghost_duration() -> float:
	if ghost_completed_count == 0:
		return 0.0
	return ghost_total_duration / float(ghost_completed_count)


func _update_ghost_orbs(delta: float) -> void:
	for orb: Orb3D in get_orbs():
		if not orb.is_ghost or orb.is_waiting_at_entrance:
			continue
		orb.advance_ghost(delta)
		var maximum_overlap: float = maximum_normal_overlap(orb)
		if maximum_overlap <= Config.data.ghost_exit_overlap:
			_complete_ghost(orb, false)
		elif orb.ghost_elapsed >= Config.data.ghost_max_time:
			_complete_ghost(orb, true)


func _complete_ghost(orb: Orb3D, timed_out: bool) -> void:
	var duration: float = orb.ghost_elapsed
	orb.exit_ghost_state()
	orb.note_diagnostic_event("ghost_timeout" if timed_out else "ghost_release")
	ghost_completed_count += 1
	ghost_total_duration += duration
	if timed_out:
		ghost_timeout_count += 1


func _on_orb_body_entered(other_body: Node, orb: Orb3D) -> void:
	var other: Orb3D = other_body.get_parent() as Orb3D
	if other == null or orb.consumed or other.consumed:
		return
	if orb.stable_spawn_id < other.stable_spawn_id:
		orb_contact.emit(orb, other)


func _configure_walls() -> void:
	var half: float = half_size()
	var thickness: float = Config.data.wall_thickness
	var half_m: float = half / PIXELS_PER_METER
	var thickness_m: float = thickness / PIXELS_PER_METER
	var depth_m: float = 0.8
	var span_m: float = half_m * 2.0 + thickness_m * 2.0
	var wall_material: PhysicsMaterial = PhysicsMaterial.new()
	wall_material.friction = Config.data.wall_friction
	wall_material.bounce = Config.data.wall_bounce
	_configure_wall(
		"WallTop",
		Orb3D.plane_position_to_world(Vector2(0.0, -half - thickness * 0.5)),
		Vector3(span_m, thickness_m, depth_m),
		wall_material
	)
	_configure_wall(
		"WallBottom",
		Orb3D.plane_position_to_world(Vector2(0.0, half + thickness * 0.5)),
		Vector3(span_m, thickness_m, depth_m),
		wall_material
	)
	_configure_wall(
		"WallLeft",
		Orb3D.plane_position_to_world(Vector2(-half - thickness * 0.5, 0.0)),
		Vector3(thickness_m, span_m, depth_m),
		wall_material
	)
	_configure_wall(
		"WallRight",
		Orb3D.plane_position_to_world(Vector2(half + thickness * 0.5, 0.0)),
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
	var half: float = half_size()
	var backing: MeshInstance3D = MeshInstance3D.new()
	backing.name = "Backing"
	backing.position = Vector3(0.0, 0.0, -0.34)
	var backing_mesh: BoxMesh = BoxMesh.new()
	backing_mesh.size = Vector3(board_size_m, board_size_m, 0.18)
	backing.mesh = backing_mesh
	backing.material_override = _visual_material(Color("#10192e"), 0.74, 0.0)
	_visual_tilt.add_child(backing)
	_add_visual_wall(
		"VisualTop",
		Orb3D.plane_position_to_world(Vector2(0.0, -half)),
		Vector3(board_size_m, VISUAL_WALL_WIDTH_M, 0.28)
	)
	_add_visual_wall(
		"VisualBottom",
		Orb3D.plane_position_to_world(Vector2(0.0, half)),
		Vector3(board_size_m, VISUAL_WALL_WIDTH_M, 0.28)
	)
	_add_visual_wall(
		"VisualLeft",
		Orb3D.plane_position_to_world(Vector2(-half, 0.0)),
		Vector3(VISUAL_WALL_WIDTH_M, board_size_m, 0.28)
	)
	_add_visual_wall(
		"VisualRight",
		Orb3D.plane_position_to_world(Vector2(half, 0.0)),
		Vector3(VISUAL_WALL_WIDTH_M, board_size_m, 0.28)
	)


func _add_visual_wall(wall_name: String, wall_position: Vector3, size: Vector3) -> void:
	var wall_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	wall_mesh_instance.name = wall_name
	wall_mesh_instance.position = wall_position
	var wall_mesh: BoxMesh = BoxMesh.new()
	wall_mesh.size = size
	wall_mesh_instance.mesh = wall_mesh
	wall_mesh_instance.material_override = _visual_material(NORMAL_FRAME_COLOR, 0.22, 0.18)
	_visual_tilt.add_child(wall_mesh_instance)
	_visual_walls[wall_name] = wall_mesh_instance


func _update_warning_visuals() -> void:
	var direction_by_name: Dictionary = {
		"VisualTop": Vector2i.DOWN,
		"VisualBottom": Vector2i.UP,
		"VisualLeft": Vector2i.RIGHT,
		"VisualRight": Vector2i.LEFT,
	}
	for wall_name: String in direction_by_name:
		var wall: MeshInstance3D = _visual_walls.get(wall_name) as MeshInstance3D
		if wall == null:
			continue
		var direction: Vector2i = Vector2i(direction_by_name[wall_name])
		var warning: bool = _warning_directions.has(direction)
		var frame_color: Color = NORMAL_FRAME_COLOR
		var emission: float = 0.18
		if warning:
			frame_color = WARNING_FRAME_COLOR
			emission = 0.35
		elif _fever_active:
			frame_color = FEVER_FRAME_COLOR
			emission = 0.55
		wall.material_override = _visual_material(frame_color, 0.22, emission)


func _visual_material(color_value: Color, roughness: float, emission_energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color_value
	material.roughness = roughness
	material.metallic = 0.25
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color_value * emission_energy
	return material
