class_name TurnManager
extends Node

enum State { WAITING_INPUT, SIMULATING, SPAWNING, CHECK_GAMEOVER, GAME_OVER }

signal state_changed(state: State)
signal gravity_changed(dir: Vector2i)
signal turn_started(turn_index: int, dir: Vector2i)
signal turn_finished(turn_index: int, combo: int)
signal planet_unlocked(color_index: int)
signal jelly_tap_effect_unlocked(color_index: int)
signal timed_jelly_placed(turns: int, bonus_levels: int)
signal timed_stone_created(turns: int)
signal timed_stone_hardened
signal combo_changed(combo: int, multiplier: float, max_combo: int)
signal reaction_ready(reaction: Dictionary)
signal warning_changed(walls: Array[Vector2i])
signal final_move_changed(visible: bool, message: String)
signal game_started
signal game_over

const FINAL_MOVE_MESSAGE: String = "막혔어요 · 한 번의 이동으로 입구를 비우세요"

@onready var _board: Variant = %Board
@onready var _spawner: Spawner = %Spawner
@onready var _collision_resolver: CollisionResolver = %CollisionResolver

var _score_manager: ScoreManager

var state: State = State.WAITING_INPUT
var gravity: Vector2i = Vector2i.DOWN
var turn_index: int = 0
var turn_combo: int = 0
var max_combo: int = 0
var capped_turn_count: int = 0
var merge_delayed_turn_count: int = 0
var merge_delay_seconds_sum: float = 0.0
var merge_delay_seconds_max: float = 0.0
var merge_extension_turn_count: int = 0
var merge_extension_seconds_sum: float = 0.0
var merge_extension_seconds_max: float = 0.0
var merge_extension_capped_turn_count: int = 0
var blocked_directions: Array[Vector2i] = []
var game_over_details: Dictionary = {}
var final_move_pending: bool = false
var final_move_active: bool = false
var final_move_count: int = 0
var final_move_success_count: int = 0
var settle_elapsed: float = 0.0
var timed_jelly_placed_count: int = 0
var timed_jelly_success_count: int = 0
var timed_jelly_failure_count: int = 0
var timed_jelly_success_turns_sum: int = 0
var timed_jelly_success_result_levels: Dictionary = {}
var timed_stone_created_count: int = 0
var timed_stone_max_concurrent: int = 0
var _settle_elapsed: float:
	get:
		return settle_elapsed
	set(value):
		settle_elapsed = value

var _stable_time: float = 0.0
var _is_initial_settle: bool = false
var _is_tap_blast_settle: bool = false
var _is_timed_burst_settle: bool = false
var _timed_jelly_callout_seen: bool = false
var _timed_stone_callout_seen: bool = false
var _current_merge_delay_seconds: float = 0.0
var _merge_extension_used: bool = false
var _merge_extension_cap_reached: bool = false
var _jelly_tap_effect_callout_seen: Dictionary = {}


func _ready() -> void:
	_score_manager = get_node_or_null("%ScoreManager") as ScoreManager
	_collision_resolver.reaction_applied.connect(on_reaction)


func start_game() -> void:
	_collision_resolver.cancel_active_jelly_merges()
	turn_index = 0
	turn_combo = 0
	max_combo = 0
	capped_turn_count = 0
	merge_delayed_turn_count = 0
	merge_delay_seconds_sum = 0.0
	merge_delay_seconds_max = 0.0
	merge_extension_turn_count = 0
	merge_extension_seconds_sum = 0.0
	merge_extension_seconds_max = 0.0
	merge_extension_capped_turn_count = 0
	blocked_directions.clear()
	game_over_details.clear()
	final_move_pending = false
	final_move_active = false
	final_move_count = 0
	final_move_success_count = 0
	_jelly_tap_effect_callout_seen.clear()
	_is_timed_burst_settle = false
	_timed_jelly_callout_seen = false
	_timed_stone_callout_seen = false
	timed_jelly_placed_count = 0
	timed_jelly_success_count = 0
	timed_jelly_failure_count = 0
	timed_jelly_success_turns_sum = 0
	timed_jelly_success_result_levels.clear()
	timed_stone_created_count = 0
	timed_stone_max_concurrent = 0
	final_move_changed.emit(false, "")
	gravity = Vector2i.DOWN
	_is_initial_settle = true
	_is_tap_blast_settle = false
	InputRouter.set_locked(true)
	_board.set_gravity(gravity)
	_board.set_warning_directions(blocked_directions)
	gravity_changed.emit(gravity)
	_emit_combo_changed()
	_begin_settle()
	_set_state(State.SIMULATING)
	game_started.emit()


func on_swipe(dir: Vector2i) -> void:
	if state != State.WAITING_INPUT:
		return
	if dir == gravity and not Config.data.allow_same_direction_swipe:
		return
	_start_turn(dir, true)


func _start_turn(
	dir: Vector2i,
	change_gravity: bool,
	spawn_next: bool = true
) -> void:
	turn_index += 1
	turn_combo = 0
	_emit_combo_changed()
	for orb: Variant in _board.get_orbs():
		orb.generation = 0
	InputRouter.set_locked(true)
	if change_gravity:
		gravity = dir
		_board.set_gravity(gravity)
		if _board.has_method("play_visual_tilt"):
			_board.play_visual_tilt(gravity)
		gravity_changed.emit(gravity)
	turn_started.emit(turn_index, gravity)
	var spending_final_move: bool = final_move_pending
	if spending_final_move or not spawn_next:
		final_move_pending = false
		if spending_final_move:
			final_move_active = true
		_begin_settle()
		_set_state(State.SIMULATING)
	else:
		_set_state(State.SPAWNING)


func on_tap(screen_position: Vector2) -> void:
	if state != State.WAITING_INPUT or Config.data.game_mode != GameConfig.GameMode.JELLY:
		return
	if not _board.has_method("screen_position_to_plane"):
		return
	var plane_position: Vector2 = _board.screen_position_to_plane(screen_position)
	if not is_finite(plane_position.x) or not is_finite(plane_position.y):
		return
	var selected_orb: Variant = null
	var selected_distance: float = INF
	for orb: Variant in _board.get_orbs():
		if not _collision_resolver.is_jelly_tap_blast_candidate(orb):
			continue
		var distance: float = orb.position.distance_to(plane_position)
		var touch_radius: float = (
			orb.get_current_radius() + Config.data.jelly_tap_blast_touch_margin
		)
		if distance <= touch_radius and distance < selected_distance:
			selected_orb = orb
			selected_distance = distance
	if selected_orb == null:
		return
	try_tap_blast_orb(selected_orb)


func try_tap_blast_orb(orb: Variant) -> bool:
	if state != State.WAITING_INPUT or Config.data.game_mode != GameConfig.GameMode.JELLY:
		return false
	if not _collision_resolver.is_jelly_tap_blast_candidate(orb):
		return false
	var uses_turn: bool = Config.data.jelly_tap_blast_uses_turn
	if uses_turn:
		var tap_effect: GameConfig.JellyTapEffect = Config.data.jelly_tap_effect_for_color(
			int(orb.color)
		)
		_start_turn(
			gravity,
			false,
			tap_effect != GameConfig.JellyTapEffect.REST
		)
	else:
		turn_combo = 0
		_emit_combo_changed()
		InputRouter.set_locked(true)
		_is_tap_blast_settle = true
		_begin_settle()
		_set_state(State.SIMULATING)
	if not _collision_resolver.apply_jelly_tap_blast(orb):
		if not uses_turn:
			_is_tap_blast_settle = false
			InputRouter.set_locked(false)
			_set_state(State.WAITING_INPUT)
		return false
	return true


func _physics_process(delta: float) -> void:
	var applied_reactions: int = _collision_resolver.flush(delta)

	if state == State.SPAWNING:
		var spawned: Array = _spawner.try_spawn(_board, gravity, turn_index)
		for orb: Variant in spawned:
			if not bool(orb.get("is_timed")):
				continue
			timed_jelly_placed_count += 1
			if not _timed_jelly_callout_seen:
				_timed_jelly_callout_seen = true
				timed_jelly_placed.emit(
					int(orb.get("timed_turns_remaining")),
					Config.data.jelly_timed_bonus_levels
				)
		var unlocked_color: int = Config.data.newly_unlocked_color_for_turn(turn_index)
		if unlocked_color >= 0:
			for orb: Variant in spawned:
				if int(orb.color) == unlocked_color:
					planet_unlocked.emit(unlocked_color)
					break
		_begin_settle()
		_set_state(State.SIMULATING)
		return

	if state != State.SIMULATING:
		return

	if applied_reactions > 0:
		_stable_time = 0.0

	settle_elapsed += delta
	if (
		_board.has_method("is_gravity_transition_active")
		and bool(_board.is_gravity_transition_active())
	):
		_stable_time = 0.0
	elif _all_below_threshold():
		_stable_time += delta
	else:
		_stable_time = 0.0

	if settle_elapsed >= Config.data.max_settle_time:
		if _should_extend_jelly_merges():
			var extension_limit: float = (
				Config.data.max_settle_time
				+ maxf(Config.data.jelly_merge_extension_max, 0.0)
			)
			if settle_elapsed < extension_limit:
				_collision_resolver.sweep_resting_contacts()
				var active_merges: int = _collision_resolver.active_jelly_merge_count()
				var touching_pairs: int = (
					_collision_resolver.touching_jelly_merge_pair_count()
				)
				if active_merges > 0 or touching_pairs > 0:
					_merge_extension_used = true
					_track_active_merge_delay(delta)
					return
				_finish_capped_settle()
				return
			_merge_extension_cap_reached = true
		_collision_resolver.set_accepting_new_jelly_merges(false)
		if _collision_resolver.active_jelly_merge_count() > 0:
			_track_active_merge_delay(delta)
			return
		_collision_resolver.sweep_resting_contacts()
		_finish_capped_settle()
	elif _stable_time >= Config.data.stable_duration:
		var swept_reactions: int = _collision_resolver.sweep_resting_contacts()
		if (
			swept_reactions > 0
			or _collision_resolver.active_jelly_merge_count() > 0
		):
			_stable_time = 0.0
			return
		_on_settled()


func _should_extend_jelly_merges() -> bool:
	return (
		Config.data.game_mode == GameConfig.GameMode.JELLY
		and Config.data.jelly_merge_extension_max > 0.0
	)


func _track_active_merge_delay(delta: float) -> void:
	if _is_initial_settle or _is_tap_blast_settle:
		return
	if _current_merge_delay_seconds <= 0.0:
		merge_delayed_turn_count += 1
	_current_merge_delay_seconds += delta


func _finish_capped_settle() -> void:
	if not _is_initial_settle and not _is_tap_blast_settle:
		capped_turn_count += 1
	_on_settled()


func _all_below_threshold() -> bool:
	if _collision_resolver.has_pending_reactions():
		return false
	for orb: Variant in _board.get_orbs():
		if orb.is_waiting_at_entrance:
			continue
		if orb.linear_velocity.length() > Config.data.stable_linear_speed:
			return false
		if absf(orb.angular_velocity) > Config.data.stable_angular_speed:
			return false
	return true


func on_reaction(reaction: Dictionary) -> void:
	_stable_time = 0.0
	turn_combo += 1
	max_combo = maxi(max_combo, turn_combo)
	reaction["combo"] = turn_combo
	_emit_combo_changed()
	_track_jelly_tap_effect_callout(reaction)
	_track_timed_jelly_success(reaction)
	reaction_ready.emit(reaction)


func _track_timed_jelly_success(reaction: Dictionary) -> void:
	if not bool(reaction.get("timed_success", false)):
		return
	timed_jelly_success_count += 1
	var placed_turn: int = int(reaction.get("timed_source_placed_turn", 0))
	if placed_turn > 0:
		timed_jelly_success_turns_sum += maxi(turn_index - placed_turn, 0)
	var result_level: int = int(reaction.get("result_level", 0))
	timed_jelly_success_result_levels[result_level] = int(
		timed_jelly_success_result_levels.get(result_level, 0)
	) + 1


func _track_jelly_tap_effect_callout(reaction: Dictionary) -> void:
	if Config.data.game_mode != GameConfig.GameMode.JELLY:
		return
	var reaction_type: ReactionRules.Type = reaction.get(
		"type", ReactionRules.Type.NONE
	) as ReactionRules.Type
	var qualifies: bool = reaction_type == ReactionRules.Type.MERGE
	if reaction_type == ReactionRules.Type.TAP_BLAST:
		qualifies = int(reaction.get("tap_effect", -1)) == GameConfig.JellyTapEffect.GROW
	if (
		not qualifies
		or int(reaction.get("result_level", 0)) < Config.data.jelly_tap_blast_min_level
	):
		return
	var color_index: int = int(reaction.get("result_color", -1))
	if color_index < 0 or _jelly_tap_effect_callout_seen.has(color_index):
		return
	_jelly_tap_effect_callout_seen[color_index] = true
	jelly_tap_effect_unlocked.emit(color_index)


func current_combo_multiplier() -> float:
	return ScoreManager.combo_multiplier_for(turn_combo, Config.data)


func _emit_combo_changed() -> void:
	combo_changed.emit(turn_combo, current_combo_multiplier(), max_combo)


func _begin_settle() -> void:
	_collision_resolver.set_accepting_new_jelly_merges(true)
	_current_merge_delay_seconds = 0.0
	_merge_extension_used = false
	_merge_extension_cap_reached = false
	_stable_time = 0.0
	settle_elapsed = 0.0


func _on_settled() -> void:
	_record_merge_extension_metrics()
	merge_delay_seconds_sum += _current_merge_delay_seconds
	merge_delay_seconds_max = maxf(
		merge_delay_seconds_max,
		_current_merge_delay_seconds
	)
	if _is_initial_settle:
		_is_initial_settle = false
		_update_warnings()
		InputRouter.set_locked(false)
		_set_state(State.WAITING_INPUT)
		return
	if _is_tap_blast_settle:
		_is_tap_blast_settle = false
		_update_warnings()
		InputRouter.set_locked(false)
		_set_state(State.WAITING_INPUT)
		return
	if _is_timed_burst_settle:
		_is_timed_burst_settle = false
	elif _advance_timed_jellies():
		_is_timed_burst_settle = true
		_begin_settle()
		_set_state(State.SIMULATING)
		return

	_set_state(State.CHECK_GAMEOVER)
	turn_finished.emit(turn_index, turn_combo)
	var blocked_spawns: Array = _board.entrance_waiting_orbs()
	if not blocked_spawns.is_empty():
		if Config.data.game_mode == GameConfig.GameMode.JELLY and not final_move_active:
			final_move_pending = true
			final_move_count += 1
			final_move_changed.emit(true, FINAL_MOVE_MESSAGE)
			_update_warnings()
			InputRouter.set_locked(false)
			_set_state(State.WAITING_INPUT)
			return
		game_over_details = _build_game_over_details(blocked_spawns)
		game_over_details["final_moves"] = final_move_count
		game_over_details["final_move_successes"] = final_move_success_count
		game_over_details["ranking"] = _commit_completed_ranking()
		final_move_active = false
		final_move_changed.emit(false, "")
		_set_state(State.GAME_OVER)
		game_over.emit()
		return
	if final_move_active:
		final_move_active = false
		final_move_success_count += 1
		final_move_changed.emit(false, "")
	_update_warnings()
	InputRouter.set_locked(false)
	_set_state(State.WAITING_INPUT)


func _record_merge_extension_metrics() -> void:
	if not _merge_extension_used or _is_initial_settle or _is_tap_blast_settle:
		return
	var extension_seconds: float = clampf(
		settle_elapsed - Config.data.max_settle_time,
		0.0,
		maxf(Config.data.jelly_merge_extension_max, 0.0)
	)
	merge_extension_turn_count += 1
	merge_extension_seconds_sum += extension_seconds
	merge_extension_seconds_max = maxf(
		merge_extension_seconds_max,
		extension_seconds
	)
	if _merge_extension_cap_reached:
		merge_extension_capped_turn_count += 1


func _advance_timed_jellies() -> bool:
	if not Config.data.jelly_timed_enabled:
		return false
	var transition_started: bool = false
	var expired_stones: Array = []
	for orb: Variant in _board.get_orbs():
		if not bool(orb.get("is_timed_stone")):
			continue
		if bool(orb.get("timed_stone_permanent")):
			continue
		if int(orb.decrement_timed_stone_turn()) <= 0:
			expired_stones.append(orb)
	for orb: Variant in expired_stones:
		_remove_timed_stone(orb)
		transition_started = true
	var expired: Array = []
	for orb: Variant in _board.get_orbs():
		if not bool(orb.get("is_timed")) or bool(orb.get("is_waiting_at_entrance")):
			continue
		if int(orb.decrement_timed_turn()) <= 0:
			expired.append(orb)
	var stone_hardened: bool = false
	for orb: Variant in expired:
		match Config.data.jelly_timed_fail_mode:
			1:
				stone_hardened = _spawn_timed_scatter(orb) or stone_hardened
			2:
				stone_hardened = _harden_timed_jelly(orb, true) or stone_hardened
			_:
				if Config.data.jelly_timed_stone_enabled:
					stone_hardened = _harden_timed_jelly(orb) or stone_hardened
				else:
					_spawn_timed_burst(orb)
		transition_started = true
	if stone_hardened:
		timed_stone_hardened.emit()
	_update_timed_stone_maximum()
	return transition_started


func _harden_timed_jelly(source: Variant, permanent: bool = false) -> bool:
	if not is_instance_valid(source) or bool(source.get("consumed")):
		return false
	var stone_turns: int = 0 if permanent else maxi(Config.data.jelly_timed_stone_turns, 0)
	source.set_timed_stone(stone_turns, permanent)
	source.note_diagnostic_event("timed_stone")
	timed_jelly_failure_count += 1
	timed_stone_created_count += 1
	if not _timed_stone_callout_seen:
		_timed_stone_callout_seen = true
		timed_stone_created.emit(stone_turns)
	return true


func _spawn_timed_scatter(source: Variant) -> bool:
	if not is_instance_valid(source) or bool(source.get("consumed")):
		return false
	var color_index: int = int(source.color)
	_collision_resolver.remove_jelly_with_clean_visual(source)
	var count: int = maxi(Config.data.jelly_timed_scatter_count, 0)
	var positions: Array[Vector2] = _timed_scatter_positions(count)
	for position: Vector2 in positions:
		var stone: Variant = _board.spawn_orb(
			color_index,
			1,
			position,
			Vector2.ZERO,
			0
		)
		stone.set_timed_stone(0, true)
		stone.enter_ghost_state(Config.data.ghost_alpha)
		stone.note_diagnostic_event("timed_stone_scatter")
	timed_jelly_failure_count += 1
	timed_stone_created_count += positions.size()
	if not _timed_stone_callout_seen:
		_timed_stone_callout_seen = true
		timed_stone_created.emit(0)
	return true


func _timed_scatter_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var safe_count: int = mini(maxi(count, 0), 25)
	if safe_count <= 0:
		return positions
	var radius: float = Config.data.radius_for_level(1)
	var center_limit: float = maxf(
		Config.data.board_size * 0.5 - radius - Config.data.spawn_margin,
		0.0
	)
	var candidates: Array[Vector2] = []
	for row: int in range(5):
		for column: int in range(5):
			candidates.append(Vector2(
				lerpf(-center_limit, center_limit, float(column) / 4.0),
				lerpf(-center_limit, center_limit, float(row) / 4.0)
			))
	var existing: Array = _board.get_orbs()
	while positions.size() < safe_count and not candidates.is_empty():
		var best_index: int = 0
		var best_score: float = -INF
		for index: int in range(candidates.size()):
			var score: float = _timed_scatter_clearance(
				candidates[index],
				radius,
				existing,
				positions
			)
			if score > best_score:
				best_score = score
				best_index = index
		positions.append(candidates[best_index])
		candidates.remove_at(best_index)
	return positions


func _timed_scatter_clearance(
	candidate: Vector2,
	radius: float,
	existing: Array,
	selected: Array[Vector2]
) -> float:
	var clearance: float = INF
	for orb: Variant in existing:
		if not is_instance_valid(orb) or bool(orb.get("consumed")):
			continue
		clearance = minf(
			clearance,
			candidate.distance_to(orb.position) - radius - float(orb.get_current_radius())
		)
	for position: Vector2 in selected:
		clearance = minf(clearance, candidate.distance_to(position) - radius * 2.0)
	return clearance


func _remove_timed_stone(source: Variant) -> void:
	if not is_instance_valid(source) or bool(source.get("consumed")):
		return
	source.note_diagnostic_event("timed_stone_expired")
	_collision_resolver.remove_jelly_with_clean_visual(source)


func _update_timed_stone_maximum() -> void:
	var active_count: int = 0
	for orb: Variant in _board.get_orbs():
		if bool(orb.get("is_timed_stone")):
			active_count += 1
	timed_stone_max_concurrent = maxi(timed_stone_max_concurrent, active_count)


func _spawn_timed_burst(source: Variant) -> void:
	if not is_instance_valid(source) or bool(source.get("consumed")):
		return
	var color_index: int = int(source.color)
	var center: Vector2 = source.position
	var source_radius: float = float(source.get_current_radius())
	var level_one_radius: float = Config.data.radius_for_level(1)
	var count: int = maxi(Config.data.jelly_timed_burst_count, 0)
	var offsets: Array[Vector2] = _timed_burst_offsets(
		count,
		source_radius,
		level_one_radius
	)
	_board.remove_orb(source)
	for index: int in range(count):
		var position: Vector2 = center + offsets[index]
		var center_limit: float = maxf(
			Config.data.board_size * 0.5 - level_one_radius,
			0.0
		)
		position = Vector2(
			clampf(position.x, -center_limit, center_limit),
			clampf(position.y, -center_limit, center_limit)
		)
		var burst_orb: Variant = _board.spawn_orb(
			color_index,
			1,
			position,
			Vector2.ZERO,
			0
		)
		burst_orb.enter_ghost_state(Config.data.ghost_alpha)
		burst_orb.note_diagnostic_event("timed_burst")
	timed_jelly_failure_count += 1


func _timed_burst_offsets(
	count: int,
	source_radius: float,
	level_one_radius: float
) -> Array[Vector2]:
	var safe_count: int = maxi(count, 0)
	var unit_offsets: Array[Vector2] = []
	if safe_count <= 0:
		return unit_offsets
	unit_offsets.append(Vector2.ZERO)
	var ring_index: int = 1
	while unit_offsets.size() < safe_count:
		var ring: Array[Vector2] = _hex_ring_offsets(ring_index)
		var remaining: int = safe_count - unit_offsets.size()
		var take_count: int = mini(remaining, ring.size())
		if take_count == ring.size():
			unit_offsets.append_array(ring)
		else:
			for selection_index: int in range(take_count):
				var ring_offset_index: int = floori(
					float(selection_index) * float(ring.size()) / float(take_count)
				)
				unit_offsets.append(ring[ring_offset_index])
		ring_index += 1
	var maximum_unit_distance: float = 0.0
	for offset: Vector2 in unit_offsets:
		maximum_unit_distance = maxf(maximum_unit_distance, offset.length())
	var natural_spacing: float = level_one_radius * 2.0 + Config.data.spawn_margin
	var fit_spacing: float = natural_spacing
	if maximum_unit_distance > 0.0:
		fit_spacing = minf(
			natural_spacing,
			(maxf(source_radius, 0.0) + maxf(level_one_radius, 0.0))
			/ maximum_unit_distance
		)
	var result: Array[Vector2] = []
	for offset: Vector2 in unit_offsets:
		result.append(offset * fit_spacing)
	return result


func _hex_ring_offsets(ring_index: int) -> Array[Vector2]:
	var safe_ring: int = maxi(ring_index, 1)
	var axial_directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(-1, 1),
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(1, -1),
	]
	var axial: Vector2i = axial_directions[4] * safe_ring
	var result: Array[Vector2] = []
	for side_index: int in range(axial_directions.size()):
		for _step_index: int in range(safe_ring):
			result.append(Vector2(
				float(axial.x) + float(axial.y) * 0.5,
				float(axial.y) * sqrt(3.0) * 0.5
			))
			axial += axial_directions[side_index]
	return result


func _commit_completed_ranking() -> Dictionary:
	if _score_manager == null:
		return {"rank": 0, "record": {}}
	var mode: GameConfig.GameMode = Config.data.game_mode
	return _score_manager.commit_ranking(
		mode,
		{
			"max_combo": max_combo,
			"turns": turn_index,
			"max_level": _score_manager.max_level_reached,
			"final_moves": final_move_success_count,
		}
	)


func _build_game_over_details(blocked_spawns: Array) -> Dictionary:
	var levels: Array[int] = []
	var overlap_counts: Array[int] = []
	for orb: Variant in blocked_spawns:
		levels.append(orb.level)
		overlap_counts.append(_board.normal_overlap_count(orb))
	return {
		"direction": gravity,
		"spawned_levels": levels,
		"overlap_counts": overlap_counts,
	}


func _update_warnings() -> void:
	var next_blocked: Array[Vector2i] = _board.blocked_spawn_directions(
		_spawner.peek_next()
	)
	_board.set_warning_directions(next_blocked)
	if next_blocked == blocked_directions:
		return
	blocked_directions = next_blocked
	var published: Array[Vector2i] = []
	published.append_array(blocked_directions)
	warning_changed.emit(published)


func _set_state(next_state: State) -> void:
	if _board.has_method("set_turn_resting"):
		_board.set_turn_resting(next_state == State.WAITING_INPUT)
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)
