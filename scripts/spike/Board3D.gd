class_name Board3D
extends Node3D

signal orb_contact(a: Orb3D, b: Orb3D)
signal visual_gravity_changed(direction: Vector2i)
signal danger_visual_changed(intensity: float, pulsing: bool)

const ORB_SCENE: PackedScene = preload("res://scenes/Orb3D.tscn")
const PIXELS_PER_METER: float = 100.0
const VISUAL_WALL_WIDTH_M: float = 0.12
const VISUAL_TILT_DEGREES: float = 6.0
const VISUAL_TILT_DURATION: float = 0.3
const WARNING_FRAME_COLOR: Color = Color("#FF3B30")
const NORMAL_FRAME_COLOR: Color = Color("#8ec5ff")
const FEVER_FRAME_COLOR: Color = Color("#FF9F0A")
const METAL_FRAME_COLOR: Color = Color("#26384E")
const GRAVITY_GLOW_COLOR: Color = Color("#D7EEFF")
const DANGER_AMBER_COLOR: Color = Color("#FFB020")
const GRAVITY_LIGHT_DURATION: float = 0.25
const GRAVITY_FIELD_DURATION: float = 0.30
const GRAVITY_FIELD_MAX_ALPHA: float = 0.10

static var _active_board_count: int = 0

@onready var _orbs_node: Node3D = %Orbs
@onready var _physics_geometry: Node3D = %PhysicsGeometry
@onready var _visual_tilt: Node3D = %VisualTilt

var _orbs: Array[Orb3D] = []
var _next_orb_spawn_id: int = 1
var _gravity_direction: Vector2i = Vector2i.DOWN
var _warning_directions: Array[Vector2i] = []
var _visual_walls: Dictionary = {}
var _wall_materials: Dictionary = {}
var _wall_inner_glows: Dictionary = {}
var _wall_outer_glows: Dictionary = {}
var _tilt_tween: Tween
var _fever_active: bool = false
var _gravity_field_material: ShaderMaterial
var _gravity_visual_from: Vector2i = Vector2i.DOWN
var _gravity_visual_to: Vector2i = Vector2i.DOWN
var _gravity_visual_elapsed: float = GRAVITY_FIELD_DURATION
var _visual_elapsed: float = 0.0
var _danger_active: bool = false
var _danger_intensity: float = 0.0
var _danger_pulsing: bool = false
var orb_contact_reporting_enabled: bool = true
var orb_continuous_cd_enabled: bool = true
var orb_allow_sleep: bool = false
var orb_progressive_growth_enabled: bool = false
var reaction_ghost_enabled: bool = false
var ghost_timeout_count: int = 0
var ghost_completed_count: int = 0
var ghost_total_duration: float = 0.0


func _ready() -> void:
	_active_board_count += 1
	Orb3D.prewarm_shared_resources(Config.data)
	_configure_walls()
	_configure_visuals()
	set_process(true)
	_update_warning_visuals()


func _exit_tree() -> void:
	_active_board_count = maxi(_active_board_count - 1, 0)
	if _active_board_count == 0:
		Orb3D.clear_shared_resource_cache()


func _physics_process(delta: float) -> void:
	_update_entrance_waiters()
	_update_ghost_orbs(delta)


func _process(delta: float) -> void:
	_visual_elapsed += delta
	_gravity_visual_elapsed = minf(
		_gravity_visual_elapsed + delta,
		GRAVITY_FIELD_DURATION
	)
	_update_gravity_field_transition()
	_update_warning_visuals()


func half_size() -> float:
	return Config.data.board_size * 0.5


func set_gravity(direction: Vector2i) -> void:
	var previous_direction: Vector2i = _gravity_direction
	_gravity_direction = direction
	if previous_direction != direction:
		_gravity_visual_from = previous_direction
		_gravity_visual_to = direction
		_gravity_visual_elapsed = 0.0
	for orb: Orb3D in _orbs:
		orb.set_gravity(direction, Config.data.gravity_strength)
	if previous_direction != direction:
		visual_gravity_changed.emit(direction)
	_update_gravity_field_transition()
	_update_warning_visuals()


func play_visual_tilt(direction: Vector2i) -> void:
	if _tilt_tween != null and _tilt_tween.is_valid():
		_tilt_tween.kill()
	var tilt_degrees: float = maxf(Config.data.fx_tilt_degrees, 0.0)
	var tilt_duration: float = maxf(Config.data.fx_tilt_duration, 0.0)
	if not Config.data.fx_enabled or tilt_degrees <= 0.0 or tilt_duration <= 0.0:
		_visual_tilt.rotation_degrees = Vector3.ZERO
		return
	var world_direction: Vector3 = Orb3D.plane_direction_to_world(direction)
	var target: Vector3 = Vector3(
		world_direction.y * tilt_degrees,
		world_direction.x * tilt_degrees,
		0.0
	)
	_tilt_tween = create_tween()
	_tilt_tween.set_trans(Tween.TRANS_QUAD)
	_tilt_tween.set_ease(Tween.EASE_OUT)
	_tilt_tween.tween_property(
		_visual_tilt,
		"rotation_degrees",
		target,
		tilt_duration * 0.45
	)
	_tilt_tween.set_trans(Tween.TRANS_BACK)
	_tilt_tween.set_ease(Tween.EASE_OUT)
	_tilt_tween.tween_property(
		_visual_tilt,
		"rotation_degrees",
		Vector3.ZERO,
		tilt_duration * 0.55
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


func apply_blast(origin: Vector2, blast_level: int) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	var radius_factor: float = Config.data.blast_push_radius_factor_for_level(blast_level)
	var limited_radius: float = radius_factor * Config.data.board_size
	for orb: Orb3D in get_orbs():
		if orb.is_ghost or orb.is_waiting_at_entrance:
			continue
		var offset: Vector2 = orb.position - origin
		var distance: float = offset.length()
		var direction: Vector2 = (
			Vector2.RIGHT if is_zero_approx(distance) else offset / distance
		)
		var full_board: bool = radius_factor >= 1.0
		var in_range: bool = full_board or distance <= limited_radius
		var falloff_radius: float = Config.data.board_size if full_board else limited_radius
		var distance_ratio: float = (
			clampf(distance / falloff_radius, 0.0, 1.0)
			if falloff_radius > 0.0
			else 1.0
		)
		var speed: float = Config.data.blast_speed * lerpf(
			1.0,
			Config.data.blast_far_factor,
			distance_ratio
		)
		var velocity_change: Vector2 = direction * speed if in_range else Vector2.ZERO
		if not velocity_change.is_zero_approx():
			orb.apply_plane_velocity_change(velocity_change)
		targets.append({
			"orb": orb,
			"stable_spawn_id": orb.stable_spawn_id,
			"level": orb.level,
			"position": orb.position,
			"velocity_change": velocity_change,
		})
	return targets


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
	var occupied_positions: PackedVector2Array = PackedVector2Array()
	var occupied_radii: PackedFloat32Array = PackedFloat32Array()
	for orb: Orb3D in _orbs:
		if (
			not is_instance_valid(orb)
			or orb.consumed
			or orb.is_waiting_at_entrance
			or orb.is_ghost
		):
			continue
		occupied_positions.append(orb.position)
		occupied_radii.append(orb.get_radius())
	for item: Dictionary in placed:
		occupied_positions.append(item["position"] as Vector2)
		occupied_radii.append(float(item["radius"]))

	var preferred_candidate: Vector2 = origin + axis * preferred_offset
	if _spawn_probe_is_clear(
		preferred_candidate,
		radius,
		occupied_positions,
		occupied_radii
	):
		return {"found": true, "position": preferred_candidate}

	var step: float = maxf(Config.data.spawn_probe_step, 0.001)
	var sample_count: int = ceili(extent * 2.0 / step)
	var normalized_index: float = (preferred_offset + extent) / step
	var left_index: int = clampi(floori(normalized_index), 0, sample_count)
	var right_index: int = left_index + 1
	while left_index >= 0 or right_index <= sample_count:
		var choose_left: bool = right_index > sample_count
		var left_offset: float = INF
		var right_offset: float = INF
		if left_index >= 0:
			left_offset = minf(-extent + float(left_index) * step, extent)
		if right_index <= sample_count:
			right_offset = minf(-extent + float(right_index) * step, extent)
		if left_index >= 0 and right_index <= sample_count:
			var left_distance: float = absf(left_offset - preferred_offset)
			var right_distance: float = absf(right_offset - preferred_offset)
			choose_left = (
				left_distance < right_distance
				or (
					is_equal_approx(left_distance, right_distance)
					and left_offset < right_offset
				)
			)
		var offset: float = left_offset if choose_left else right_offset
		if choose_left:
			left_index -= 1
		else:
			right_index += 1
		if is_equal_approx(offset, preferred_offset):
			continue
		var candidate_position: Vector2 = origin + axis * offset
		if _spawn_probe_is_clear(
			candidate_position,
			radius,
			occupied_positions,
			occupied_radii
		):
			return {"found": true, "position": candidate_position}
	return {"found": false, "position": preferred_position}


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


func set_danger_state(occupancy: float, multiplier: float) -> void:
	var active: bool = occupancy >= Config.data.danger_start
	_danger_active = active
	_danger_intensity = (
		clampf(inverse_lerp(1.0, 4.0, maxf(multiplier, 1.0)), 0.0, 1.0)
		if active
		else 0.0
	)
	_danger_pulsing = active and multiplier >= 4.0
	danger_visual_changed.emit(_danger_intensity, _danger_pulsing)
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
	occupied_positions: PackedVector2Array,
	occupied_radii: PackedFloat32Array
) -> bool:
	for index: int in range(occupied_positions.size()):
		var minimum_distance: float = (
			radius
			+ occupied_radii[index]
			- Config.data.ghost_exit_overlap
		)
		if (
			minimum_distance > 0.0
			and candidate_position.distance_squared_to(occupied_positions[index])
			< minimum_distance * minimum_distance
		):
			return false
	return true


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
	var backing_mesh: QuadMesh = QuadMesh.new()
	backing_mesh.size = Vector2(board_size_m, board_size_m)
	backing.mesh = backing_mesh
	backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backing.material_override = _glass_backing_material()
	_visual_tilt.add_child(backing)
	var gravity_field: MeshInstance3D = MeshInstance3D.new()
	gravity_field.name = "GravityField"
	gravity_field.position = Vector3(0.0, 0.0, -0.31)
	var field_mesh: QuadMesh = QuadMesh.new()
	field_mesh.size = Vector2(board_size_m, board_size_m)
	gravity_field.mesh = field_mesh
	gravity_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gravity_field_material = _gravity_field_shader_material()
	gravity_field.material_override = _gravity_field_material
	_visual_tilt.add_child(gravity_field)
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
	_add_beveled_corners(board_size_m * 0.5)


func _add_visual_wall(wall_name: String, wall_position: Vector3, size: Vector3) -> void:
	var wall_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	wall_mesh_instance.name = wall_name
	wall_mesh_instance.position = wall_position
	var wall_mesh: BoxMesh = BoxMesh.new()
	wall_mesh.size = size
	wall_mesh_instance.mesh = wall_mesh
	var wall_material: StandardMaterial3D = _visual_material(METAL_FRAME_COLOR, 0.22, 0.08)
	wall_material.metallic = 0.78
	wall_mesh_instance.material_override = wall_material
	_visual_tilt.add_child(wall_mesh_instance)
	_visual_walls[wall_name] = wall_mesh_instance
	_wall_materials[wall_name] = wall_material

	var outer_glow: MeshInstance3D = MeshInstance3D.new()
	outer_glow.name = "OuterGlow"
	outer_glow.position.z = -0.08
	var outer_mesh: BoxMesh = BoxMesh.new()
	outer_mesh.size = Vector3(
		size.x + (0.16 if size.x > size.y else 0.10),
		size.y + (0.16 if size.y > size.x else 0.10),
		0.08
	)
	outer_glow.mesh = outer_mesh
	outer_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outer_glow.material_override = _transparent_glow_material(Color(0.0, 0.0, 0.0, 0.16))
	wall_mesh_instance.add_child(outer_glow)
	_wall_outer_glows[wall_name] = outer_glow

	var inner_glow: MeshInstance3D = MeshInstance3D.new()
	inner_glow.name = "InnerGlow"
	inner_glow.position.z = 0.17
	var inner_mesh: BoxMesh = BoxMesh.new()
	inner_mesh.size = Vector3(
		size.x if size.x > size.y else 0.035,
		0.035 if size.x > size.y else size.y,
		0.025
	)
	inner_glow.mesh = inner_mesh
	inner_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inner_glow.material_override = _transparent_glow_material(Color(0.0, 0.0, 0.0, 0.0))
	wall_mesh_instance.add_child(inner_glow)
	_wall_inner_glows[wall_name] = inner_glow


func _update_warning_visuals() -> void:
	var spawn_direction_by_name: Dictionary = {
		"VisualTop": Vector2i.DOWN,
		"VisualBottom": Vector2i.UP,
		"VisualLeft": Vector2i.RIGHT,
		"VisualRight": Vector2i.LEFT,
	}
	var gravity_direction_by_name: Dictionary = {
		"VisualTop": Vector2i.UP,
		"VisualBottom": Vector2i.DOWN,
		"VisualLeft": Vector2i.LEFT,
		"VisualRight": Vector2i.RIGHT,
	}
	var light_mix: float = _gravity_light_mix()
	var warning_pulse: float = 0.72 + 0.28 * (0.5 + 0.5 * sin(_visual_elapsed * TAU * 1.4))
	var danger_pulse: float = 1.0
	if _danger_pulsing:
		danger_pulse = 0.68 + 0.32 * (0.5 + 0.5 * sin(_visual_elapsed * TAU * 0.8))
	var danger_color: Color = _danger_color(_danger_intensity)
	for wall_name: String in spawn_direction_by_name:
		var wall: MeshInstance3D = _visual_walls.get(wall_name) as MeshInstance3D
		if wall == null:
			continue
		var spawn_direction: Vector2i = Vector2i(spawn_direction_by_name[wall_name])
		var wall_gravity_direction: Vector2i = Vector2i(gravity_direction_by_name[wall_name])
		var warning: bool = _warning_directions.has(spawn_direction)
		var frame_color: Color = METAL_FRAME_COLOR
		var emission: float = 0.08
		if warning:
			frame_color = WARNING_FRAME_COLOR.lerp(Color.WHITE, 0.08 * warning_pulse)
			emission = 0.32 + 0.30 * warning_pulse
		elif _fever_active:
			frame_color = METAL_FRAME_COLOR.lerp(FEVER_FRAME_COLOR, 0.70)
			emission = 0.48
		var wall_material: StandardMaterial3D = _wall_materials.get(wall_name) as StandardMaterial3D
		_set_standard_material_color(wall_material, frame_color, emission)

		var gravity_weight: float = 0.0
		if wall_gravity_direction == _gravity_visual_from:
			gravity_weight += 1.0 - light_mix
		if wall_gravity_direction == _gravity_visual_to:
			gravity_weight += light_mix
		var inner_color: Color = GRAVITY_GLOW_COLOR
		var inner_strength: float = gravity_weight
		if warning:
			inner_color = WARNING_FRAME_COLOR
			inner_strength = 0.52 + 0.48 * warning_pulse
		elif _fever_active:
			inner_color = FEVER_FRAME_COLOR
			inner_strength = maxf(inner_strength, 0.72)
		var inner_glow: MeshInstance3D = _wall_inner_glows.get(wall_name) as MeshInstance3D
		_set_glow_material(inner_glow, inner_color, inner_strength * 0.82)

		var outer_glow: MeshInstance3D = _wall_outer_glows.get(wall_name) as MeshInstance3D
		var outer_strength: float = (
			(0.26 + 0.74 * _danger_intensity) * danger_pulse
			if _danger_active
			else 0.0
		)
		if _fever_active:
			danger_color = FEVER_FRAME_COLOR
			outer_strength = maxf(outer_strength, 0.58)
		_set_glow_material(outer_glow, danger_color, outer_strength * 0.52)


func _visual_material(color_value: Color, roughness: float, emission_energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color_value
	material.roughness = roughness
	material.metallic = 0.25
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color_value * emission_energy
	return material


func _add_beveled_corners(half_size_m: float) -> void:
	var corners: Node3D = Node3D.new()
	corners.name = "BeveledCorners"
	_visual_tilt.add_child(corners)
	for corner_index: int in range(4):
		var x_sign: float = -1.0 if corner_index % 2 == 0 else 1.0
		var y_sign: float = -1.0 if corner_index < 2 else 1.0
		var corner: MeshInstance3D = MeshInstance3D.new()
		corner.name = "Corner%d" % corner_index
		corner.position = Vector3(x_sign * half_size_m, y_sign * half_size_m, 0.03)
		corner.rotation.z = deg_to_rad(45.0 * x_sign * y_sign)
		var corner_mesh: BoxMesh = BoxMesh.new()
		corner_mesh.size = Vector3(0.22, 0.10, 0.31)
		corner.mesh = corner_mesh
		var corner_material: StandardMaterial3D = _visual_material(
			METAL_FRAME_COLOR.lerp(NORMAL_FRAME_COLOR, 0.16),
			0.20,
			0.10
		)
		corner_material.metallic = 0.84
		corner.material_override = corner_material
		corners.add_child(corner)


func _update_gravity_field_transition() -> void:
	if _gravity_field_material == null:
		return
	_gravity_field_material.set_shader_parameter(
		"gravity_from",
		Vector2(_gravity_visual_from)
	)
	_gravity_field_material.set_shader_parameter(
		"gravity_to",
		Vector2(_gravity_visual_to)
	)
	_gravity_field_material.set_shader_parameter("gravity_mix", _gravity_field_mix())


func _gravity_field_mix() -> float:
	return clampf(
		_gravity_visual_elapsed / GRAVITY_FIELD_DURATION,
		0.0,
		1.0
	)


func _gravity_light_mix() -> float:
	return clampf(
		_gravity_visual_elapsed / GRAVITY_LIGHT_DURATION,
		0.0,
		1.0
	)


func _danger_color(intensity: float) -> Color:
	var amount: float = clampf(intensity, 0.0, 1.0)
	if amount <= 0.5:
		return NORMAL_FRAME_COLOR.lerp(DANGER_AMBER_COLOR, amount * 2.0)
	return DANGER_AMBER_COLOR.lerp(WARNING_FRAME_COLOR, (amount - 0.5) * 2.0)


func _set_standard_material_color(
	material: StandardMaterial3D,
	color_value: Color,
	emission_energy: float
) -> void:
	if material == null:
		return
	material.albedo_color = color_value
	material.emission_enabled = true
	material.emission = color_value * emission_energy


func _transparent_glow_material(color_value: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color_value
	material.emission_enabled = true
	material.emission = Color(color_value.r, color_value.g, color_value.b, 1.0)
	material.emission_energy_multiplier = 0.0
	return material


func _set_glow_material(node: MeshInstance3D, color_value: Color, strength: float) -> void:
	if node == null:
		return
	var material: StandardMaterial3D = node.material_override as StandardMaterial3D
	if material == null:
		return
	var safe_strength: float = clampf(strength, 0.0, 1.0)
	material.albedo_color = Color(color_value.r, color_value.g, color_value.b, safe_strength * 0.34)
	material.emission = color_value
	material.emission_energy_multiplier = safe_strength * 1.35


func _glass_backing_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	var glass_shader: Shader = Shader.new()
	glass_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque;

void fragment() {
	vec2 centered = abs(UV * 2.0 - 1.0);
	float edge = smoothstep(0.58, 1.0, max(centered.x, centered.y));
	float center_glow = 1.0 - smoothstep(0.0, 0.92, length((UV - vec2(0.5)) * vec2(0.88, 1.0)));
	vec3 glass = mix(vec3(0.012, 0.021, 0.046), vec3(0.025, 0.045, 0.082), center_glow * 0.55);
	glass *= 1.0 - edge * 0.30;
	ALBEDO = glass;
	ALPHA = mix(0.65, 0.78, edge);
	ROUGHNESS = 0.34;
}
"""
	material.shader = glass_shader
	return material


func _gravity_field_shader_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	var field_shader: Shader = Shader.new()
	field_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec2 gravity_from = vec2(0.0, 1.0);
uniform vec2 gravity_to = vec2(0.0, 1.0);
uniform float gravity_mix : hint_range(0.0, 1.0) = 1.0;
uniform float maximum_alpha : hint_range(0.0, 0.12) = 0.10;

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float from_angle = atan(gravity_from.y, gravity_from.x);
	float to_angle = atan(gravity_to.y, gravity_to.x);
	float angle_delta = mod(to_angle - from_angle + 3.14159265, 6.28318531) - 3.14159265;
	float gravity_angle = from_angle + angle_delta * gravity_mix;
	vec2 gravity = vec2(cos(gravity_angle), sin(gravity_angle));
	vec2 tangent = vec2(-gravity.y, gravity.x);
	float along = dot(point, gravity);
	float across = dot(point, tangent);
	float well = (along + 1.0) * 0.5;
	vec2 warped = point - gravity * across * across * (0.15 + 0.18 * well);
	float line_x = 1.0 - smoothstep(0.025, 0.070, abs(fract(warped.x * 5.0 + 0.5) - 0.5));
	float line_y = 1.0 - smoothstep(0.025, 0.070, abs(fract(warped.y * 5.0 + 0.5) - 0.5));
	float edge_fade = smoothstep(1.0, 0.80, max(abs(point.x), abs(point.y)));
	float alpha = max(line_x, line_y) * edge_fade * maximum_alpha;
	ALBEDO = vec3(0.48, 0.70, 0.88);
	ALPHA = min(alpha, 0.12);
}
"""
	material.shader = field_shader
	material.set_shader_parameter("maximum_alpha", GRAVITY_FIELD_MAX_ALPHA)
	return material
