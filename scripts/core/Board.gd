class_name Board
extends Node2D

signal orb_contact(a: Orb, b: Orb)

const ORB_SCENE: PackedScene = preload("res://scenes/Orb.tscn")
const FRAME_WIDTH: float = 4.0
const WARNING_FRAME_WIDTH: float = 12.0
const WARNING_FRAME_COLOR: Color = Color("#FF3B30")
const FEVER_FRAME_COLOR: Color = Color("#FF9F0A")
const BLAST_FLASH_DURATION: float = 0.18
const BLAST_SHAKE_DISTANCE: float = 6.0

@onready var _wall_top: StaticBody2D = %WallTop
@onready var _wall_bottom: StaticBody2D = %WallBottom
@onready var _wall_left: StaticBody2D = %WallLeft
@onready var _wall_right: StaticBody2D = %WallRight
@onready var _frame_border: Line2D = %Border
@onready var _frame: Node2D = _frame_border.get_parent() as Node2D
@onready var _orbs_node: Node2D = %Orbs

var _orbs: Array[Orb] = []
var _next_orb_spawn_id: int = 1
var _gravity_direction: Vector2i = Vector2i.DOWN
var _last_ghost_timeout_physics_frame: int = -1
var _pending_wall_recovery_warnings: Array[Dictionary] = []
var _wall_recovery_warning_flush_scheduled: bool = false
var escape_guard_count: int = 0
var wall_recovery_count: int = 0
var wall_recovery_since_last_ghost_timeout_frames: Array[int] = []
var wall_recovery_events: Array[Dictionary] = []
var timeout_correction_count: int = 0
var ghost_timeout_count: int = 0
var ghost_completed_count: int = 0
var ghost_total_duration: float = 0.0
var diagnostic_warnings_enabled: bool = true
var _warning_directions: Array[Vector2i] = []
var _blast_flash_position: Vector2 = Vector2.ZERO
var _blast_flash_remaining: float = 0.0
var _blast_flash_radius: float = 0.0
var _fever_active: bool = false


func _ready() -> void:
	_configure_walls()
	_configure_frame()


func _physics_process(delta: float) -> void:
	_update_entrance_waiters()
	_update_ghost_orbs(delta)
	_update_blast_effect(delta)


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
	orb.stable_spawn_id = _next_orb_spawn_id
	_next_orb_spawn_id += 1
	orb.diagnostic_warnings_enabled = diagnostic_warnings_enabled
	orb.note_board_spawn(spawn_physics_frame)
	orb.position = p_position
	orb.linear_velocity = p_velocity
	orb.generation = p_generation
	orb.set_gravity(_gravity_direction, Config.data.gravity_strength)
	orb.enter_ghost_state(Config.data.ghost_alpha)
	orb.body_entered.connect(_on_orb_body_entered.bind(orb))
	orb.escape_guard_triggered.connect(_on_orb_escape_guard_triggered)
	orb.wall_recovery_triggered.connect(_on_orb_wall_recovery_triggered.bind(orb))
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
	for orb: Orb in get_orbs():
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
			impulse = velocity_change * orb.mass
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
	for orb: Orb in get_orbs():
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
	_play_blast_effect(origin, blast_level)
	return targets


func _play_blast_effect(origin: Vector2, blast_level: int) -> void:
	_blast_flash_position = origin
	_blast_flash_radius = (
		Config.data.board_size
		* Config.data.blast_push_radius_factor_for_level(blast_level)
	)
	_blast_flash_remaining = BLAST_FLASH_DURATION
	queue_redraw()


func _update_blast_effect(delta: float) -> void:
	if _blast_flash_remaining <= 0.0:
		return
	_blast_flash_remaining = maxf(_blast_flash_remaining - delta, 0.0)
	if _blast_flash_remaining <= 0.0:
		_frame.position = Vector2.ZERO
	else:
		var progress: float = 1.0 - _blast_flash_remaining / BLAST_FLASH_DURATION
		var strength: float = (1.0 - progress) * BLAST_SHAKE_DISTANCE
		_frame.position = Vector2(
			sin(progress * TAU * 3.0),
			cos(progress * TAU * 4.0)
		) * strength
	queue_redraw()


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
	var orbs_to_remove: Array[Orb] = _orbs.duplicate()
	for orb: Orb in orbs_to_remove:
		remove_orb(orb)


func should_ghost_reaction_results() -> bool:
	return true


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
		var position: Vector2 = origin + axis * offset
		if not _spawn_probe_is_clear(position, radius, placed):
			continue
		var distance: float = absf(offset - preferred_offset)
		if (
			not found
			or distance < best_distance
			or (is_equal_approx(distance, best_distance) and offset < best_offset)
		):
			found = true
			best_position = position
			best_distance = distance
			best_offset = offset
	return {"found": found, "position": best_position}


func entrance_waiting_orbs() -> Array[Orb]:
	var waiting: Array[Orb] = []
	for orb: Orb in get_orbs():
		if orb.is_waiting_at_entrance:
			waiting.append(orb)
	return waiting


func maximum_normal_overlap(ghost: Orb) -> float:
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


func normal_overlap_count(ghost: Orb) -> int:
	var count: int = 0
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
	queue_redraw()


func set_fever_active(active: bool) -> void:
	_fever_active = active
	_frame_border.default_color = FEVER_FRAME_COLOR if active else Color.WHITE


func _batch_fits_spawn_line(
	gravity: Vector2i,
	batch: Array[Dictionary]
) -> bool:
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
	position: Vector2,
	radius: float,
	placed: Array[Dictionary]
) -> bool:
	for orb: Orb in _orbs:
		if not is_instance_valid(orb) or orb.consumed or orb.is_ghost:
			continue
		var overlap: float = (
			radius
			+ orb.get_current_radius()
			- position.distance_to(orb.position)
		)
		if overlap > Config.data.ghost_exit_overlap:
			return false
	for item: Dictionary in placed:
		var overlap: float = (
			radius
			+ float(item["radius"])
			- position.distance_to(item["position"] as Vector2)
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
	for orb: Orb in get_orbs():
		if orb.is_ghost and not orb.is_waiting_at_entrance:
			placed.append(
				{"position": orb.position, "radius": orb.get_radius()}
			)
	for orb: Orb in entrance_waiting_orbs():
		var slot: Dictionary = find_free_spawn_slot(
			orb.entrance_gravity,
			orb.get_radius(),
			placed,
			orb.entrance_preferred_position
		)
		if not bool(slot["found"]):
			continue
		var position: Vector2 = slot["position"] as Vector2
		orb.release_entrance_wait(
			position,
			orb.entrance_gravity,
			Config.data.gravity_strength
		)
		placed.append({"position": position, "radius": orb.get_radius()})


func average_ghost_duration() -> float:
	if ghost_completed_count == 0:
		return 0.0
	return ghost_total_duration / float(ghost_completed_count)


func _update_ghost_orbs(delta: float) -> void:
	for orb: Orb in get_orbs():
		if not orb.is_ghost or orb.is_waiting_at_entrance:
			continue
		orb.advance_ghost(delta)
		var maximum_overlap: float = maximum_normal_overlap(orb)
		if maximum_overlap <= Config.data.ghost_exit_overlap:
			_complete_ghost(orb, false, maximum_overlap)
		elif (
			orb.ghost_elapsed >= Config.data.ghost_max_time
			or is_equal_approx(orb.ghost_elapsed, Config.data.ghost_max_time)
		):
			_complete_ghost(orb, true, maximum_overlap)


func _complete_ghost(orb: Orb, timed_out: bool, maximum_overlap: float) -> void:
	var duration: float = orb.ghost_elapsed
	if timed_out:
		_last_ghost_timeout_physics_frame = Engine.get_physics_frames()
		_restore_existing_orbs_inside_board(orb)
		_relieve_timeout_overlap(orb)
	orb.exit_ghost_state()
	orb.note_diagnostic_event("timeout_correction" if timed_out else "ghost_release")
	ghost_completed_count += 1
	ghost_total_duration += duration
	if not timed_out:
		return
	ghost_timeout_count += 1
	if diagnostic_warnings_enabled:
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
		orb.note_diagnostic_event("timeout_correction")
		timeout_correction_count += 1


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
		timeout_correction_count += 1


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
	if orb.stable_spawn_id < other.stable_spawn_id:
		orb_contact.emit(orb, other)


func _on_orb_escape_guard_triggered(_axis: String, _depth: float) -> void:
	escape_guard_count += 1


func _on_orb_wall_recovery_triggered(
	level: int,
	axis: String,
	depth: float,
	ghost: bool,
	age_frames: int,
	since_last_spawn_frames: int,
	physics_frame: int,
	orb: Orb
) -> void:
	wall_recovery_count += 1
	var since_last_ghost_timeout_frames: int = -1
	if _last_ghost_timeout_physics_frame >= 0:
		since_last_ghost_timeout_frames = physics_frame - _last_ghost_timeout_physics_frame
	wall_recovery_since_last_ghost_timeout_frames.append(since_last_ghost_timeout_frames)
	wall_recovery_events.append(
		{
			"orb_id": orb.get_instance_id(),
			"level": level,
			"axis": axis,
			"depth": depth,
			"ghost": ghost,
			"age_frames": age_frames,
			"since_last_spawn_frames": since_last_spawn_frames,
			"since_last_ghost_timeout_frames": since_last_ghost_timeout_frames,
			"physics_frame": physics_frame,
			"position": orb.position,
			"radius": orb.get_current_radius(),
			"pile_depth": _diagnostic_pile_depth(orb),
			"neighbor_levels": _diagnostic_neighbor_levels(orb),
			"wall_contact": _diagnostic_wall_contact(orb),
			"last_event": orb.diagnostic_last_event,
			"frames_since_last_event": maxi(
				physics_frame - orb.diagnostic_last_event_physics_frame,
				0
			),
		}
	)
	if not diagnostic_warnings_enabled:
		return
	_pending_wall_recovery_warnings.append(
		{
			"level": level,
			"axis": axis,
			"depth": depth,
			"ghost": ghost,
			"age_frames": age_frames,
			"since_last_spawn_frames": since_last_spawn_frames,
			"since_last_ghost_timeout_frames": since_last_ghost_timeout_frames,
			"physics_frame": physics_frame,
		}
	)
	if not _wall_recovery_warning_flush_scheduled:
		_wall_recovery_warning_flush_scheduled = true
		call_deferred("_flush_wall_recovery_warnings")


func _diagnostic_pile_depth(target: Orb) -> int:
	if not target.position.is_finite():
		return 0
	var perpendicular: Vector2 = Vector2(OrbTypes.perpendicular(_gravity_direction))
	var count: int = 0
	for other: Orb in get_orbs():
		if not other.position.is_finite():
			continue
		var cross_distance: float = absf((other.position - target.position).dot(perpendicular))
		if cross_distance <= target.get_current_radius() + other.get_current_radius():
			count += 1
	return count


func _diagnostic_neighbor_levels(target: Orb) -> Array[int]:
	var levels: Array[int] = []
	if not target.position.is_finite():
		return levels
	for other: Orb in get_orbs():
		if other == target:
			continue
		if not other.position.is_finite():
			continue
		var contact_distance: float = (
			target.get_current_radius()
			+ other.get_current_radius()
			+ Config.data.ghost_exit_overlap
		)
		if target.position.distance_squared_to(other.position) <= contact_distance * contact_distance:
			levels.append(other.level)
	return levels


func _diagnostic_wall_contact(target: Orb) -> bool:
	if not target.position.is_finite():
		return false
	var wall_gap: float = minf(
		half_size() - absf(target.position.x) - target.get_current_radius(),
		half_size() - absf(target.position.y) - target.get_current_radius()
	)
	return wall_gap <= Config.data.floor_contact_tolerance


func _flush_wall_recovery_warnings() -> void:
	_wall_recovery_warning_flush_scheduled = false
	for event: Dictionary in _pending_wall_recovery_warnings:
		var recovery_frame: int = int(event["physics_frame"])
		push_warning(
			"[WALL_RECOVERY] level=%d axis=%s depth=%.3f ghost=%s age_frames=%d since_last_spawn_frames=%d since_last_ghost_timeout_frames=%d on_ghost_timeout_frame=%s" % [
				int(event["level"]),
				str(event["axis"]),
				float(event["depth"]),
				str(bool(event["ghost"])),
				int(event["age_frames"]),
				int(event["since_last_spawn_frames"]),
				int(event["since_last_ghost_timeout_frames"]),
				str(recovery_frame == _last_ghost_timeout_physics_frame),
			]
		)
	_pending_wall_recovery_warnings.clear()


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


func _draw() -> void:
	if _blast_flash_remaining > 0.0:
		var progress: float = 1.0 - _blast_flash_remaining / BLAST_FLASH_DURATION
		draw_arc(
			_blast_flash_position,
			lerpf(12.0, _blast_flash_radius, progress),
			0.0,
			TAU,
			64,
			Color(1.0, 1.0, 1.0, 1.0 - progress),
			8.0,
			true
		)
	var half: float = half_size()
	for direction: Vector2i in _warning_directions:
		var wall_center: Vector2 = -Vector2(direction) * half
		var wall_axis: Vector2 = Vector2(OrbTypes.perpendicular(direction))
		draw_line(
			wall_center - wall_axis * half,
			wall_center + wall_axis * half,
			WARNING_FRAME_COLOR,
			WARNING_FRAME_WIDTH
		)
