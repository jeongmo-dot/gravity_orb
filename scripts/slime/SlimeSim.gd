class_name SlimeSim
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT]

class SlimeBody extends RefCounted:
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var mass: int = 1
	var level: int = 0
	var color_index: int = 0
	var radius: float = 31.5
	var impact: float = 0.0
	var idle_phase: float = 0.0
	var idle_speed: float = 1.0
	var visual_scale: float = 1.0
	var merge_glow: float = 0.0
	var rotation: float = 0.0
	var roll: float = 0.0
	var deform: Vector2 = Vector2.ONE

	func copy() -> SlimeBody:
		var result := SlimeBody.new()
		result.position = position
		result.velocity = velocity
		result.mass = mass
		result.level = level
		result.color_index = color_index
		result.radius = radius
		result.impact = impact
		result.idle_phase = idle_phase
		result.idle_speed = idle_speed
		result.visual_scale = visual_scale
		result.merge_glow = merge_glow
		result.rotation = rotation
		result.roll = roll
		result.deform = deform
		return result

	func physics_array() -> Array[Variant]:
		return [position.x, position.y, velocity.x, velocity.y, mass, level, color_index, radius]


var config: SlimeConfig
var slimes: Array[SlimeBody] = []
var gravity_direction: Vector2i = Vector2i.DOWN
var next_slimes: Array[Dictionary] = []
var intro_queue: Array[Dictionary] = []
var color_bag: Array[int] = []
var completed_colors: Dictionary = {}

var turn: int = 0
var score: int = 0
var chain: int = 0
var run_best_chain: int = 0
var active_color_count: int = 3
var pending_new_color: int = -1
var unlock_grace_waves_left: int = 0
var moving: bool = false
var game_over: bool = false
var final_move_pending: bool = false
var final_move_active: bool = false
var settle_elapsed: float = 0.0
var simulation_elapsed: float = 0.0
var intro_elapsed: float = 0.0
var collision_cooldown_left: float = 0.0
var gravity_flash_left: float = 0.0
var message: String = ""
var tick_count: int = 0
var turn_start_tick: int = 0
var turn_end_tick: int = 0

var max_completions: int = 0
var max_clears: int = 0
var final_move_count: int = 0
var final_move_success_count: int = 0
var intro_cancel_count: int = 0
var maximum_slime_count: int = 0
var maximum_slime_radius: float = 0.0
var completed_turn_durations: Array[float] = []

var _game_rng := RandomNumberGenerator.new()
var _visual_rng := RandomNumberGenerator.new()
var _events: Array[Dictionary] = []
var _visuals_enabled: bool = true
var _seed_used: int = 1


func _init(
	p_config: SlimeConfig,
	p_seed: int = 1,
	p_visuals_enabled: bool = true,
	p_start_initial_admission: bool = true
) -> void:
	config = p_config
	_visuals_enabled = p_visuals_enabled
	reset(p_seed, p_start_initial_admission)


func reset(seed_value: int = 1, start_initial_admission: bool = true) -> void:
	slimes.clear()
	next_slimes.clear()
	intro_queue.clear()
	color_bag.clear()
	completed_colors.clear()
	_events.clear()
	gravity_direction = Vector2i.DOWN
	turn = 0
	score = 0
	chain = 0
	run_best_chain = 0
	active_color_count = config.start_colors
	pending_new_color = -1
	unlock_grace_waves_left = 0
	moving = false
	game_over = false
	final_move_pending = false
	final_move_active = false
	settle_elapsed = 0.0
	simulation_elapsed = 0.0
	intro_elapsed = 0.0
	collision_cooldown_left = 0.0
	gravity_flash_left = 0.0
	message = ""
	tick_count = 0
	turn_start_tick = 0
	turn_end_tick = 0
	max_completions = 0
	max_clears = 0
	final_move_count = 0
	final_move_success_count = 0
	intro_cancel_count = 0
	maximum_slime_count = 0
	maximum_slime_radius = 0.0
	completed_turn_durations.clear()
	if seed_value > 0:
		_game_rng.seed = seed_value
		_seed_used = seed_value
	else:
		_game_rng.randomize()
		_seed_used = _game_rng.seed
	_visual_rng.seed = _seed_used ^ 0x5EED5EED
	if start_initial_admission:
		_start_initial_admission()


func get_seed_used() -> int:
	return _seed_used


func set_visuals_enabled(enabled: bool) -> void:
	_visuals_enabled = enabled


func add_slime(
	position_value: Vector2,
	level_value: int,
	color_value: int,
	velocity_value: Vector2 = Vector2.ZERO,
	mass_value: int = -1
) -> SlimeBody:
	var slime := SlimeBody.new()
	var computed_mass: int = 1 << clampi(level_value, 0, config.radii.size() - 1)
	slime.position = position_value
	slime.velocity = velocity_value
	var requested_mass: int = mass_value if mass_value > 0 else computed_mass
	slime.mass = requested_mass if config.max_growth_enabled else mini(requested_mass, config.max_mass)
	slime.level = level_for_mass(slime.mass)
	slime.color_index = color_value
	slime.radius = radius_for_mass(slime.mass)
	if _visuals_enabled:
		slime.idle_phase = _visual_rng.randf_range(0.0, TAU)
		slime.idle_speed = _visual_rng.randf_range(1.5, 2.1)
		slime.rotation = Vector2(gravity_direction).angle() - PI * 0.5
	slimes.append(slime)
	maximum_slime_count = maxi(maximum_slime_count, slimes.size())
	maximum_slime_radius = maxf(maximum_slime_radius, slime.radius)
	return slime


func clear_slimes() -> void:
	slimes.clear()
	maximum_slime_count = 0
	maximum_slime_radius = 0.0


func start_turn(direction: Vector2i) -> bool:
	if moving or game_over or not DIRECTIONS.has(direction):
		return false
	gravity_direction = direction
	turn += 1
	chain = 0
	gravity_flash_left = config.gravity_flash_duration
	turn_start_tick = tick_count
	_emit_event("turn_started", {"turn": turn, "direction": direction})
	if final_move_pending:
		final_move_pending = false
		final_move_active = true
		final_move_count += 1
		_set_message("FINAL MOVE · 공간을 다시 여세요")
	else:
		_schedule_next_batch(direction)
		if intro_queue.is_empty():
			_set_message("중력 이동 중...")
		else:
			_set_message("중력 전환 · 슬라임 %d마리 등장" % intro_queue.size())
	moving = true
	settle_elapsed = 0.0
	simulation_elapsed = 0.0
	intro_elapsed = 0.0
	var kick: Vector2 = Vector2(direction) * config.turn_kick_speed
	for slime: SlimeBody in slimes:
		slime.velocity += kick
	return true


func step(delta: float) -> void:
	if delta <= 0.0:
		return
	tick_count += 1
	collision_cooldown_left = maxf(0.0, collision_cooldown_left - delta)
	gravity_flash_left = maxf(0.0, gravity_flash_left - delta)
	_update_visual_state(delta)
	_update_intro(delta)
	if not moving:
		return
	if intro_queue.is_empty():
		simulation_elapsed += delta
	var gravity: Vector2 = Vector2(gravity_direction)
	var lateral: Vector2 = Vector2(-gravity.y, gravity.x)
	var damping_factor: float = pow(config.damping, delta * 60.0)
	var lateral_factor: float = pow(config.lateral_damping, delta * 60.0)
	var soft_factor: float = pow(config.soft_stop_factor, delta * 60.0)
	for slime: SlimeBody in slimes:
		slime.velocity += gravity * config.gravity_acceleration * delta
		slime.velocity *= damping_factor
		var gravity_velocity: Vector2 = gravity * slime.velocity.dot(gravity)
		var lateral_velocity: Vector2 = lateral * slime.velocity.dot(lateral) * lateral_factor
		slime.velocity = gravity_velocity + lateral_velocity
		if intro_queue.is_empty() and simulation_elapsed > config.soft_stop_start:
			slime.velocity *= soft_factor
		slime.position += slime.velocity * delta
		_update_motion_visual(slime, delta, gravity, lateral)
		_resolve_wall(slime)
	for iteration: int in range(config.solver_iterations):
		resolve_pairs()
	for slime: SlimeBody in slimes:
		_resolve_wall(slime)
	var all_resting: bool = true
	for slime: SlimeBody in slimes:
		if slime.velocity.length() > config.rest_speed:
			all_resting = false
			break
	if all_resting:
		settle_elapsed += delta
	else:
		settle_elapsed = 0.0
	if intro_queue.is_empty() and (
		settle_elapsed > config.settle_hold
		or simulation_elapsed >= config.max_simulation_time
	):
		finish_turn()


func finish_turn() -> void:
	if not moving:
		return
	moving = false
	intro_queue.clear()
	settle_elapsed = 0.0
	simulation_elapsed = 0.0
	for slime: SlimeBody in slimes:
		slime.velocity = Vector2.ZERO
	turn_end_tick = tick_count
	if turn > 0:
		completed_turn_durations.append(float(turn_end_tick - turn_start_tick) / 60.0)
	_emit_event("turn_finished", {"turn": turn, "tick": turn_end_tick})
	if final_move_active:
		final_move_active = false
		if all_entries_blocked():
			game_over = true
			next_slimes.clear()
			_set_message("보드가 가득 찼습니다")
			_emit_event("game_over", {"score": score, "turn": turn})
		else:
			final_move_success_count += 1
			_set_message("공간 확보 성공 · 다음 중력을 선택하세요")
			if next_slimes.is_empty():
				roll_next_batch()
		return
	if all_entries_blocked():
		final_move_pending = true
		_set_message("FINAL MOVE · 한 번의 중력 이동으로 공간을 만드세요")
		_emit_event("final_move", {"turn": turn})
	else:
		_set_message("다음 중력을 선택하세요")
	if next_slimes.is_empty():
		roll_next_batch()


func resolve_pairs() -> void:
	var i: int = 0
	while i < slimes.size():
		var j: int = i + 1
		while j < slimes.size():
			var a: SlimeBody = slimes[i]
			var b: SlimeBody = slimes[j]
			var delta_position: Vector2 = b.position - a.position
			var distance: float = delta_position.length()
			var target_distance: float = a.radius + b.radius
			if distance <= target_distance + config.touch_margin:
				var same_color: bool = a.color_index == b.color_index
				var can_absorb: bool = config.max_growth_enabled or (
					a.mass < config.max_mass and b.mass < config.max_mass
				)
				if same_color and can_absorb:
					_merge_pair(i, j, a, b)
					j = i + 1
					continue
				if a.mass >= config.max_mass and b.mass >= config.max_mass:
					_clear_max_pair(i, j, a, b)
					j = i + 1
					continue
			if distance < target_distance:
				var normal: Vector2 = Vector2.RIGHT if distance <= 0.01 else delta_position / distance
				var penetration: float = target_distance - maxf(distance, 0.01)
				a.position -= normal * penetration * 0.5
				b.position += normal * penetration * 0.5
				_apply_stack_slip(a, b, delta_position, target_distance, i, j)
				var relative_speed: float = (b.velocity - a.velocity).dot(normal)
				if relative_speed < 0.0:
					var impulse: Vector2 = normal * relative_speed * config.pair_impulse_factor
					a.velocity += impulse
					b.velocity -= impulse
					var impact: float = clampf(-relative_speed / config.pair_impact_divisor, 0.0, 1.0)
					a.impact = maxf(a.impact, impact)
					b.impact = maxf(b.impact, impact)
					_emit_collision_event(impact, (a.position + b.position) * 0.5)
			j += 1
		i += 1


func radius_for_level(level_value: int) -> float:
	return config.radii[clampi(level_value, 0, config.radii.size() - 1)]


func level_for_mass(mass_value: int) -> int:
	var safe_mass: int = clampi(mass_value, 1, config.max_mass)
	var result: int = 0
	while result + 1 < config.radii.size() and (1 << (result + 1)) <= safe_mass:
		result += 1
	return result


func radius_for_mass(mass_value: int) -> float:
	var safe_mass: int = maxi(mass_value, 1)
	if config.max_growth_enabled and safe_mass > config.max_mass:
		var max_radius: float = radius_for_level(config.radii.size() - 1)
		var growth_ratio: float = float(safe_mass) / float(config.max_mass)
		return minf(
			max_radius * pow(growth_ratio, config.max_growth_exponent),
			config.max_growth_radius_cap
		)
	safe_mass = mini(safe_mass, config.max_mass)
	if safe_mass >= config.max_mass:
		return radius_for_level(config.radii.size() - 1)
	var lower_level: int = level_for_mass(safe_mass)
	var lower_mass: int = 1 << lower_level
	var upper_mass: int = mini(lower_mass * 2, config.max_mass)
	var lower_radius: float = radius_for_level(lower_level)
	var upper_radius: float = (
		config.pre_max_radius
		if upper_mass >= config.max_mass
		else radius_for_level(lower_level + 1)
	)
	if upper_mass == lower_mass:
		return lower_radius
	var weight: float = float(safe_mass - lower_mass) / float(upper_mass - lower_mass)
	return lerpf(lower_radius, upper_radius, weight)


func roll_next_batch() -> void:
	_check_color_unlocks()
	var free_slots: int = maxi(0, config.max_slimes - slimes.size())
	if free_slots <= 0:
		next_slimes.clear()
		return
	var count: int = _roll_batch_count()
	if unlock_grace_waves_left > 0:
		count = mini(count, config.unlock_grace_max_count)
		unlock_grace_waves_left -= 1
	count = mini(count, free_slots)
	var rolled: Array[Dictionary] = []
	for index: int in range(count):
		rolled.append({"color": roll_color(), "level": roll_level()})
	if pending_new_color >= 0:
		var forced_count: int = mini(config.forced_new_color_slots, count)
		for index: int in range(forced_count):
			rolled[index]["color"] = pending_new_color
		pending_new_color = -1
	next_slimes = rolled


func roll_level() -> int:
	var roll: float = _game_rng.randf()
	if roll < config.spawn_level_weights[0]:
		return 0
	if roll < config.spawn_level_weights[0] + config.spawn_level_weights[1]:
		return 1
	return 2


func roll_color() -> int:
	if color_bag.is_empty():
		for color_index: int in range(active_color_count):
			for copy_index: int in range(config.color_bag_copies):
				color_bag.append(color_index)
		_shuffle_int_array(color_bag)
	return color_bag.pop_back()


func entry_position_for(direction: Vector2i, radius: float, lane: float = 0.5) -> Vector2:
	var board: Rect2 = config.board_rect
	var clamped_lane: float = clampf(lane, 0.0, 1.0)
	if direction == Vector2i.DOWN:
		return Vector2(lerpf(board.position.x + radius, board.end.x - radius, clamped_lane), board.position.y + radius)
	if direction == Vector2i.UP:
		return Vector2(lerpf(board.position.x + radius, board.end.x - radius, clamped_lane), board.end.y - radius)
	if direction == Vector2i.RIGHT:
		return Vector2(board.position.x + radius, lerpf(board.position.y + radius, board.end.y - radius, clamped_lane))
	return Vector2(board.end.x - radius, lerpf(board.position.y + radius, board.end.y - radius, clamped_lane))


func entry_clearance_for(direction: Vector2i, level_value: int = 0, lane: float = 0.5) -> float:
	var radius: float = radius_for_level(level_value)
	var entry_position: Vector2 = entry_position_for(direction, radius, lane)
	var clearance: float = 999.0
	for slime: SlimeBody in slimes:
		clearance = minf(clearance, entry_position.distance_to(slime.position) - radius - slime.radius - config.entry_margin)
	return clearance


func entry_stage_for(direction: Vector2i) -> int:
	var clearance: float = entry_clearance_for(direction)
	if clearance < config.entry_danger_clearance:
		return 2
	if clearance < config.entry_caution_clearance:
		return 1
	return 0


func all_entries_blocked() -> bool:
	for direction: Vector2i in DIRECTIONS:
		if entry_clearance_for(direction) >= 0.0:
			return false
	return true


func set_next_slimes(entries: Array[Dictionary]) -> void:
	next_slimes.clear()
	for entry: Dictionary in entries:
		next_slimes.append(entry.duplicate(true))


func drain_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = _events.duplicate(true)
	_events.clear()
	return result


func state_hash() -> String:
	var bodies: Array[Variant] = []
	for slime: SlimeBody in slimes:
		bodies.append(slime.physics_array())
	var next_data: Array[Variant] = []
	for entry: Dictionary in next_slimes:
		next_data.append([int(entry.get("color", 0)), int(entry.get("level", 0))])
	var intro_data: Array[Variant] = []
	for entry: Dictionary in intro_queue:
		intro_data.append([
			float(entry.get("delay", 0.0)),
			float(entry.get("lane", 0.5)),
			int(entry.get("color", 0)),
			int(entry.get("level", 0)),
		])
	var data: Array[Variant] = [
		bodies,
		next_data,
		intro_data,
		gravity_direction.x,
		gravity_direction.y,
		turn,
		score,
		chain,
		run_best_chain,
		active_color_count,
		pending_new_color,
		unlock_grace_waves_left,
		moving,
		game_over,
		final_move_pending,
		final_move_active,
		settle_elapsed,
		simulation_elapsed,
		intro_elapsed,
		tick_count,
		_game_rng.state,
	]
	return JSON.stringify(data).sha256_text()


func duplicate_sim() -> SlimeSim:
	var result := SlimeSim.new(config, _seed_used, _visuals_enabled, false)
	result.slimes.clear()
	for slime: SlimeBody in slimes:
		result.slimes.append(slime.copy())
	result.gravity_direction = gravity_direction
	result.next_slimes.assign(next_slimes.duplicate(true))
	result.intro_queue.assign(intro_queue.duplicate(true))
	result.color_bag.assign(color_bag.duplicate())
	result.completed_colors = completed_colors.duplicate(true)
	result.turn = turn
	result.score = score
	result.chain = chain
	result.run_best_chain = run_best_chain
	result.active_color_count = active_color_count
	result.pending_new_color = pending_new_color
	result.unlock_grace_waves_left = unlock_grace_waves_left
	result.moving = moving
	result.game_over = game_over
	result.final_move_pending = final_move_pending
	result.final_move_active = final_move_active
	result.settle_elapsed = settle_elapsed
	result.simulation_elapsed = simulation_elapsed
	result.intro_elapsed = intro_elapsed
	result.collision_cooldown_left = collision_cooldown_left
	result.gravity_flash_left = gravity_flash_left
	result.message = message
	result.tick_count = tick_count
	result.turn_start_tick = turn_start_tick
	result.turn_end_tick = turn_end_tick
	result.max_completions = max_completions
	result.max_clears = max_clears
	result.final_move_count = final_move_count
	result.final_move_success_count = final_move_success_count
	result.intro_cancel_count = intro_cancel_count
	result.maximum_slime_count = maximum_slime_count
	result.maximum_slime_radius = maximum_slime_radius
	result.completed_turn_durations.assign(completed_turn_durations.duplicate())
	result._game_rng.state = _game_rng.state
	result._visual_rng.state = _visual_rng.state
	result._events.clear()
	return result


func _start_initial_admission() -> void:
	var lanes: Array[float] = []
	for lane: float in config.initial_lanes:
		lanes.append(lane)
	_shuffle_float_array(lanes)
	for index: int in range(config.initial_count):
		var lane: float = clampf(
			lanes[index] + _game_rng.randf_range(-config.initial_lane_jitter, config.initial_lane_jitter),
			config.initial_lane_min,
			config.initial_lane_max
		)
		intro_queue.append({
			"delay": config.initial_delay + float(index) * config.initial_delay_step + _game_rng.randf_range(0.0, config.initial_delay_jitter),
			"lane": lane,
			"color": index % config.start_colors,
			"level": int(config.initial_levels[index]),
		})
	roll_next_batch()
	moving = true
	settle_elapsed = 0.0
	simulation_elapsed = 0.0
	intro_elapsed = 0.0
	_set_message("슬라임들이 입장합니다...")


func _update_visual_state(delta: float) -> void:
	if not _visuals_enabled:
		return
	for slime: SlimeBody in slimes:
		slime.impact = maxf(0.0, slime.impact - delta * 4.8)
		slime.visual_scale = lerpf(slime.visual_scale, 1.0, minf(delta * 13.0, 1.0))
		slime.merge_glow = maxf(0.0, slime.merge_glow - delta * 3.2)
		slime.idle_phase = fmod(slime.idle_phase + delta * slime.idle_speed, TAU)
		var gravity_angle: float = Vector2(gravity_direction).angle() - PI * 0.5
		slime.rotation = lerp_angle(slime.rotation, gravity_angle, minf(delta * 8.0, 1.0))
		if not moving:
			slime.deform = slime.deform.lerp(Vector2.ONE, minf(delta * 11.0, 1.0))
			slime.roll = lerp_angle(slime.roll, 0.0, minf(delta * 4.5, 1.0))


func _update_motion_visual(
	slime: SlimeBody,
	delta: float,
	gravity: Vector2,
	lateral: Vector2
) -> void:
	if not _visuals_enabled:
		return
	slime.roll += slime.velocity.dot(lateral) / maxf(slime.radius, 1.0) * delta * 0.86
	var fall_speed: float = maxf(0.0, slime.velocity.dot(gravity))
	var stretch: float = clampf(fall_speed / 5100.0, 0.0, 0.19)
	var target := Vector2(1.0 - 0.55 * stretch, 1.0 + stretch)
	if slime.impact > 0.0:
		target = Vector2(1.0 + 0.18 * slime.impact, 1.0 - 0.20 * slime.impact)
	slime.deform = slime.deform.lerp(target, minf(delta * 11.0, 1.0))


func _update_intro(delta: float) -> void:
	if intro_queue.is_empty():
		return
	intro_elapsed += delta
	while not intro_queue.is_empty():
		var entry: Dictionary = intro_queue.front()
		var delay: float = float(entry.get("delay", 0.0))
		if intro_elapsed < delay:
			return
		var level_value: int = int(entry.get("level", 0))
		var lane: float = float(entry.get("lane", 0.5))
		if entry_clearance_for(gravity_direction, level_value, lane) >= 0.0:
			var radius: float = radius_for_level(level_value)
			var spawned: SlimeBody = add_slime(
				entry_position_for(gravity_direction, radius, lane),
				level_value,
				int(entry.get("color", 0)),
				Vector2(gravity_direction) * config.spawn_speed
			)
			if _visuals_enabled:
				spawned.visual_scale = 0.35
			intro_queue.pop_front()
			_emit_event("spawned", {"level": level_value, "lane": lane})
			continue
		if intro_elapsed > delay + config.intro_abandon_time:
			intro_queue.clear()
			intro_cancel_count += 1
			_set_message("투입 중단 · 현재 슬라임 이동 후 공간을 확인합니다")
			_emit_event("intro_cancelled", {"turn": turn})
		return


func _resolve_wall(slime: SlimeBody) -> void:
	var board: Rect2 = config.board_rect
	var left: float = board.position.x + slime.radius
	var right: float = board.end.x - slime.radius
	var top: float = board.position.y + slime.radius
	var bottom: float = board.end.y - slime.radius
	var impact: float = 0.0
	if slime.position.x < left:
		impact = maxf(impact, clampf(absf(slime.velocity.x) / config.wall_impact_divisor, 0.0, 1.0))
		slime.position.x = left
		slime.velocity.x = absf(slime.velocity.x) * config.wall_restitution
	elif slime.position.x > right:
		impact = maxf(impact, clampf(absf(slime.velocity.x) / config.wall_impact_divisor, 0.0, 1.0))
		slime.position.x = right
		slime.velocity.x = -absf(slime.velocity.x) * config.wall_restitution
	if slime.position.y < top:
		impact = maxf(impact, clampf(absf(slime.velocity.y) / config.wall_impact_divisor, 0.0, 1.0))
		slime.position.y = top
		slime.velocity.y = absf(slime.velocity.y) * config.wall_restitution
	elif slime.position.y > bottom:
		impact = maxf(impact, clampf(absf(slime.velocity.y) / config.wall_impact_divisor, 0.0, 1.0))
		slime.position.y = bottom
		slime.velocity.y = -absf(slime.velocity.y) * config.wall_restitution
	if impact > 0.0:
		slime.impact = maxf(slime.impact, impact)


func _apply_stack_slip(
	a: SlimeBody,
	b: SlimeBody,
	delta_position: Vector2,
	target_distance: float,
	a_index: int,
	b_index: int
) -> void:
	var gravity: Vector2 = Vector2(gravity_direction)
	var tangent: Vector2 = Vector2(-gravity.y, gravity.x)
	var lateral_distance: float = delta_position.dot(tangent)
	var gravity_distance: float = absf(delta_position.dot(gravity))
	if (
		absf(lateral_distance) > target_distance * config.stack_slip_alignment
		or gravity_distance < target_distance * config.stack_slip_min_axis
	):
		return
	var a_is_upper: bool = a.position.dot(gravity) < b.position.dot(gravity)
	var upper: SlimeBody = a if a_is_upper else b
	var lower: SlimeBody = b if a_is_upper else a
	var upper_offset: float = (upper.position - lower.position).dot(tangent)
	var slip_sign: float = signf(upper_offset)
	if absf(upper_offset) < 0.5:
		slip_sign = -1.0 if (a_index + b_index + upper.color_index + upper.mass) % 2 == 0 else 1.0
	var current_slip: float = upper.velocity.dot(tangent) * slip_sign
	if current_slip < config.stack_slip_speed:
		var impulse_amount: float = minf(config.stack_slip_max_impulse, config.stack_slip_speed - current_slip)
		upper.velocity += tangent * slip_sign * impulse_amount
		lower.velocity -= tangent * slip_sign * impulse_amount * config.stack_slip_lower_share
	upper.position += tangent * slip_sign * config.stack_slip_nudge


func _merge_pair(i: int, j: int, a: SlimeBody, b: SlimeBody) -> void:
	var source_a_position: Vector2 = a.position
	var source_b_position: Vector2 = b.position
	var source_a_radius: float = a.radius
	var source_b_radius: float = b.radius
	var raw_mass: int = a.mass + b.mass
	var merged_mass: int = raw_mass if config.max_growth_enabled else mini(raw_mass, config.max_mass)
	var merged_position: Vector2 = (a.position + b.position) * 0.5
	var merged_velocity: Vector2 = (a.velocity + b.velocity) * config.merge_velocity_keep
	var color_index: int = a.color_index
	var reached_max: bool = (
		merged_mass >= config.max_mass
		and a.mass < config.max_mass
		and b.mass < config.max_mass
	)
	var newly_completed_color: bool = reached_max and not completed_colors.has(color_index)
	var base_score: int = raw_mass * config.score_per_mass
	if reached_max:
		base_score += config.max_completion_bonus
		max_completions += 1
	if newly_completed_color:
		completed_colors[color_index] = true
	var colors_before: int = active_color_count
	var gained_score: int = _add_chain_score(base_score)
	slimes.remove_at(j)
	slimes.remove_at(i)
	var merged: SlimeBody = add_slime(merged_position, level_for_mass(merged_mass), color_index, merged_velocity, merged_mass)
	merged.visual_scale = clampf(
		maxf(source_a_radius, source_b_radius) / merged.radius * 0.88,
		0.68,
		0.88
	)
	merged.merge_glow = 1.0
	if active_color_count == colors_before:
		if chain >= 2:
			_set_message("%d CHAIN!  +%d" % [chain, gained_score])
		elif reached_max:
			_set_message("MAX 슬라임 완성!  +%d" % gained_score)
		else:
			_set_message("흡수!  +%d" % gained_score)
	_emit_event("absorbed", {
		"mass": merged_mass,
		"raw_mass": raw_mass,
		"position": merged_position,
		"source_a_position": source_a_position,
		"source_b_position": source_b_position,
		"source_a_radius": source_a_radius,
		"source_b_radius": source_b_radius,
		"result_radius": merged.radius,
		"color": color_index,
		"level": merged.level,
		"gained_score": gained_score,
		"chain": chain,
		"reached_max": reached_max,
		"newly_completed_color": newly_completed_color,
	})
	if reached_max:
		_emit_event("max_completed", {
			"color": color_index,
			"position": merged_position,
			"newly_completed_color": newly_completed_color,
		})


func _clear_max_pair(i: int, j: int, a: SlimeBody, b: SlimeBody) -> void:
	var center: Vector2 = (a.position + b.position) * 0.5
	var source_a_position: Vector2 = a.position
	var source_b_position: Vector2 = b.position
	var source_a_radius: float = a.radius
	var source_b_radius: float = b.radius
	var color_a: int = a.color_index
	var color_b: int = b.color_index
	slimes.remove_at(j)
	slimes.remove_at(i)
	var colors_before: int = active_color_count
	var gained_score: int = _add_chain_score(config.max_clear_score)
	max_clears += 1
	for slime: SlimeBody in slimes:
		var delta_position: Vector2 = slime.position - center
		var distance: float = delta_position.length()
		if distance >= config.max_clear_push_radius:
			continue
		var direction: Vector2
		if distance <= 0.01:
			var angle: float = _game_rng.randf_range(0.0, TAU)
			direction = Vector2.from_angle(angle)
		else:
			direction = delta_position / distance
		var strength: float = 1.0 - distance / config.max_clear_push_radius
		slime.velocity += direction * config.max_clear_push_speed * strength
		slime.impact = maxf(slime.impact, 0.28)
	if active_color_count == colors_before:
		if chain >= 2:
			_set_message("MAX CLEAR · %d CHAIN!  +%d" % [chain, gained_score])
		else:
			_set_message("MAX CLEAR!  +%d" % gained_score)
	_emit_event("max_clear", {
		"position": center,
		"source_a_position": source_a_position,
		"source_b_position": source_b_position,
		"source_a_radius": source_a_radius,
		"source_b_radius": source_b_radius,
		"color_a": color_a,
		"color_b": color_b,
		"gained_score": gained_score,
		"chain": chain,
	})


func _add_chain_score(base_score: int) -> int:
	if turn <= 0:
		score += base_score
		return base_score
	chain += 1
	run_best_chain = maxi(run_best_chain, chain)
	var multiplier_steps: int = mini(chain - 1, config.chain_multiplier_max_steps)
	var multiplier: float = 1.0 + float(multiplier_steps) * config.chain_multiplier_step
	var gained: int = int(round(float(base_score) * multiplier))
	score += gained
	_check_color_unlocks()
	return gained


func _check_color_unlocks() -> void:
	while active_color_count < config.slime_colors.size():
		var threshold_index: int = active_color_count - config.start_colors
		if threshold_index < 0 or threshold_index >= config.unlock_scores.size():
			return
		if score < config.unlock_scores[threshold_index]:
			return
		pending_new_color = active_color_count
		active_color_count += 1
		unlock_grace_waves_left = config.unlock_grace_waves
		color_bag.clear()
		_set_message("새로운 색상 해금!  %d / 7" % active_color_count)
		_emit_event("unlock", {"color": pending_new_color, "count": active_color_count})


func _schedule_next_batch(direction: Vector2i) -> void:
	intro_queue.clear()
	var count: int = mini(next_slimes.size(), maxi(0, config.max_slimes - slimes.size()))
	for index: int in range(count):
		var entry: Dictionary = next_slimes[index]
		intro_queue.append({
			"delay": config.intro_initial_delay + float(index) * config.intro_delay_step,
			"lane": 0.5,
			"color": int(entry.get("color", 0)),
			"level": int(entry.get("level", 0)),
		})
	next_slimes.clear()
	gravity_direction = direction


func _roll_batch_count() -> int:
	var slime_count: int = slimes.size()
	var count: int
	if slime_count < config.crowd_thresholds[0]:
		count = config.low_crowd_bonus_count if _game_rng.randf() < config.low_crowd_bonus_chance else config.low_crowd_spawn_count
	elif slime_count < config.crowd_thresholds[1]:
		count = config.medium_crowd_spawn_count
	else:
		count = config.high_crowd_spawn_count
	if turn >= config.turn_level_three_floor:
		count = maxi(count, 3)
	elif turn >= config.turn_level_two_floor:
		count = maxi(count, 2)
	return count


func _emit_collision_event(impact: float, position_value: Vector2) -> void:
	if impact <= config.sound_impact_threshold or collision_cooldown_left > 0.0:
		return
	collision_cooldown_left = config.collision_sound_cooldown
	_emit_event("collision", {"impact": impact, "position": position_value})


func _emit_event(event_type: String, payload: Dictionary = {}) -> void:
	var event: Dictionary = payload.duplicate(true)
	event["type"] = event_type
	event["tick"] = tick_count
	_events.append(event)


func _set_message(value: String) -> void:
	message = value
	_emit_event("message", {"text": value})


func _shuffle_float_array(values: Array[float]) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var other: int = _game_rng.randi_range(0, index)
		var temporary: float = values[index]
		values[index] = values[other]
		values[other] = temporary


func _shuffle_int_array(values: Array[int]) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var other: int = _game_rng.randi_range(0, index)
		var temporary: int = values[index]
		values[index] = values[other]
		values[other] = temporary
