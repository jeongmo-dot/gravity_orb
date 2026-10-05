class_name BlitzManager
extends Node

enum State { IDLE, RUNNING, FINALE, FINISHED }

signal state_changed(state: State)
signal gravity_changed(dir: Vector2i)
signal turn_started(turn_index: int, dir: Vector2i)
signal turn_finished(turn_index: int, combo: int)
signal combo_changed(combo: int, multiplier: float, max_combo: int)
signal reaction_ready(reaction: Dictionary)
signal warning_changed(walls: Array[Vector2i])
signal game_over
signal time_changed(remaining: float)
signal fever_changed(active: bool, remaining: float)
signal time_bonus_awarded(seconds: float, source: String)
signal finale_started
signal finale_blast(level: int)

@onready var _board: Variant = %Board
@onready var _spawner: Spawner = %Spawner
@onready var _collision_resolver: CollisionResolver = %CollisionResolver
@onready var _score_manager: ScoreManager = %ScoreManager

var state: State = State.IDLE
var gravity: Vector2i = Vector2i.DOWN
var turn_index: int = 0
var turn_combo: int = 0
var max_combo: int = 0
var blocked_directions: Array[Vector2i] = []
var game_over_details: Dictionary = {}
var settle_elapsed: float = 0.0
var remaining_time: float = 0.0
var play_time_elapsed: float = 0.0
var fever_remaining: float = 0.0
var fever_count: int = 0
var fever_total_time: float = 0.0
var blast_count: int = 0
var finale_blast_count: int = 0
var time_bonus_total: float = 0.0
var spawn_count: int = 0
var skipped_spawn_ticks: int = 0
var accepted_swipes: int = 0
var first_reaction_time: float = -1.0
var finale_score_start: int = 0

var _active: bool = false
var _swipe_cooldown_remaining: float = 0.0
var _spawn_elapsed: float = 0.0
var _combo_elapsed: float = 0.0
var _finale_interval_remaining: float = 0.0
var _finale_idle_elapsed: float = 0.0
var _finale_settle_elapsed: float = 0.0


func _ready() -> void:
	set_physics_process(false)


func start_game() -> void:
	Config.data.game_mode = GameConfig.GameMode.BLITZ
	_active = true
	set_physics_process(true)
	state = State.IDLE
	gravity = Vector2i.DOWN
	turn_index = 0
	turn_combo = 0
	max_combo = 0
	blocked_directions.clear()
	game_over_details.clear()
	settle_elapsed = 0.0
	remaining_time = maxf(Config.data.blitz_duration, 0.0)
	play_time_elapsed = 0.0
	fever_remaining = 0.0
	fever_count = 0
	fever_total_time = 0.0
	blast_count = 0
	finale_blast_count = 0
	time_bonus_total = 0.0
	spawn_count = 0
	skipped_spawn_ticks = 0
	accepted_swipes = 0
	first_reaction_time = -1.0
	finale_score_start = 0
	_swipe_cooldown_remaining = 0.0
	_spawn_elapsed = 0.0
	_combo_elapsed = 0.0
	_finale_interval_remaining = 0.0
	_finale_idle_elapsed = 0.0
	_finale_settle_elapsed = 0.0
	if not _collision_resolver.reaction_applied.is_connected(on_reaction):
		_collision_resolver.reaction_applied.connect(on_reaction)
	_spawner.set_blitz_mode(true)
	InputRouter.set_locked(false)
	_board.set_gravity(gravity)
	_board.set_warning_directions(blocked_directions)
	_set_fever_visual(false)
	gravity_changed.emit(gravity)
	warning_changed.emit(blocked_directions)
	_emit_combo_changed()
	time_changed.emit(remaining_time)
	fever_changed.emit(false, 0.0)
	_set_state(State.RUNNING)


func on_swipe(dir: Vector2i) -> void:
	if state != State.RUNNING:
		return
	if dir == gravity or _swipe_cooldown_remaining > 0.0:
		return
	gravity = dir
	turn_index += 1
	accepted_swipes += 1
	_swipe_cooldown_remaining = maxf(Config.data.blitz_swipe_cooldown, 0.0)
	_board.set_gravity(gravity)
	if _board.has_method("play_visual_tilt"):
		_board.play_visual_tilt(gravity)
	gravity_changed.emit(gravity)
	turn_started.emit(turn_index, gravity)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_collision_resolver.flush(delta)
	if state == State.RUNNING:
		_advance_running(delta)
	elif state == State.FINALE:
		_advance_combo(delta)
		_advance_fever(delta)
		_advance_finale(delta)


func on_reaction(reaction: Dictionary) -> void:
	if state != State.RUNNING and state != State.FINALE:
		return
	if first_reaction_time < 0.0:
		first_reaction_time = play_time_elapsed
	if turn_combo > 0 and _combo_elapsed <= Config.data.blitz_combo_window:
		turn_combo += 1
	else:
		turn_combo = 1
	_combo_elapsed = 0.0
	max_combo = maxi(max_combo, turn_combo)
	var fever_was_active: bool = fever_remaining > 0.0
	if turn_combo == Config.data.blitz_fever_combo:
		fever_remaining = maxf(Config.data.blitz_fever_duration, 0.0)
		if not fever_was_active:
			fever_count += 1
		_set_fever_visual(fever_remaining > 0.0)
		fever_changed.emit(fever_remaining > 0.0, fever_remaining)
	reaction["combo"] = turn_combo
	reaction["combo_multiplier"] = current_combo_multiplier()
	reaction["fever"] = fever_remaining > 0.0
	var reaction_type: ReactionRules.Type = reaction["type"] as ReactionRules.Type
	if reaction_type == ReactionRules.Type.BLAST:
		blast_count += 1
	if state == State.RUNNING:
		if reaction_type == ReactionRules.Type.BLAST:
			_award_time_bonus(Config.data.blitz_time_bonus_blast, "BLAST")
		elif reaction_type == ReactionRules.Type.MAX_CLEAR:
			_award_time_bonus(Config.data.blitz_time_bonus_jackpot, "MAX CLEAR")
		if turn_combo % 10 == 0:
			_award_time_bonus(Config.data.blitz_time_bonus_combo10, "COMBO %d" % turn_combo)
	_emit_combo_changed()
	_finale_idle_elapsed = 0.0
	reaction_ready.emit(reaction)


func current_combo_multiplier() -> float:
	var combo_index: int = maxi(turn_combo, 1) - 1
	return minf(
		1.0 + Config.data.blitz_combo_step * float(combo_index),
		Config.data.blitz_combo_max_multiplier
	)


func _advance_running(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	settle_elapsed += step
	play_time_elapsed += step
	_swipe_cooldown_remaining = maxf(_swipe_cooldown_remaining - step, 0.0)
	_advance_combo(step)
	_advance_fever(step)
	_spawn_elapsed += step
	var spawn_interval: float = maxf(Config.data.blitz_spawn_interval, 0.001)
	while _spawn_elapsed >= spawn_interval and state == State.RUNNING:
		_spawn_elapsed -= spawn_interval
		if not _board.entrance_waiting_orbs().is_empty():
			skipped_spawn_ticks += 1
			continue
		var spawned: Array = _spawner.try_spawn(_board, gravity, spawn_count + 1)
		spawn_count += spawned.size()
	remaining_time = maxf(remaining_time - step, 0.0)
	time_changed.emit(remaining_time)
	if remaining_time <= 0.0:
		_begin_finale()


func _advance_combo(delta: float) -> void:
	if turn_combo <= 0:
		return
	_combo_elapsed += delta
	if _combo_elapsed <= Config.data.blitz_combo_window:
		return
	turn_combo = 0
	_emit_combo_changed()


func _advance_fever(delta: float) -> void:
	if fever_remaining <= 0.0:
		return
	var active_delta: float = minf(delta, fever_remaining)
	fever_total_time += active_delta
	fever_remaining = maxf(fever_remaining - delta, 0.0)
	if fever_remaining <= 0.0:
		_set_fever_visual(false)
	fever_changed.emit(fever_remaining > 0.0, fever_remaining)


func _award_time_bonus(seconds: float, source: String) -> void:
	var bonus: float = maxf(seconds, 0.0)
	if bonus <= 0.0:
		return
	remaining_time += bonus
	time_bonus_total += bonus
	time_changed.emit(remaining_time)
	time_bonus_awarded.emit(bonus, source)


func _begin_finale() -> void:
	InputRouter.set_locked(true)
	finale_score_start = _score_manager.score
	_finale_interval_remaining = maxf(Config.data.blitz_finale_interval, 0.0)
	_finale_idle_elapsed = 0.0
	_finale_settle_elapsed = 0.0
	_set_state(State.FINALE)
	finale_started.emit()


func _advance_finale(delta: float) -> void:
	_finale_interval_remaining = maxf(_finale_interval_remaining - delta, 0.0)
	var candidate: Variant = _next_finale_orb()
	if candidate != null:
		_finale_settle_elapsed = 0.0
		if _finale_interval_remaining <= 0.0:
			_apply_finale_blast(candidate)
			_finale_interval_remaining = maxf(Config.data.blitz_finale_interval, 0.0)
		return
	_finale_idle_elapsed += delta
	_finale_settle_elapsed += delta
	if (
		_finale_idle_elapsed >= Config.data.blitz_combo_window
		or _finale_settle_elapsed >= 5.0
	):
		_finish_game()


func _next_finale_orb() -> Variant:
	var candidates: Array = []
	for orb: Variant in _board.get_orbs():
		if orb.consumed or orb.is_ghost or orb.is_waiting_at_entrance:
			continue
		if orb.level >= Config.data.blitz_blast_min_level:
			candidates.append(orb)
	candidates.sort_custom(
		func(first: Variant, second: Variant) -> bool:
			if first.level != second.level:
				return first.level > second.level
			return first.stable_spawn_id < second.stable_spawn_id
	)
	return null if candidates.is_empty() else candidates[0]


func _apply_finale_blast(orb: Variant) -> void:
	var level: int = orb.level
	var origin: Vector2 = orb.position
	var occupancy: float = _board_occupancy()
	_board.remove_orb(orb)
	var blast_targets: Array[Dictionary] = _board.apply_blast(origin)
	blast_count += 1
	finale_blast_count += 1
	var levels: Array[int] = [level]
	var reaction: Dictionary = {
		"type": ReactionRules.Type.BLAST,
		"levels": levels,
		"result_level": 0,
		"occupancy": occupancy,
		"combo": 1,
		"combo_multiplier": 1.0,
		"fever": false,
		"finale": true,
		"blast_targets": blast_targets,
	}
	reaction_ready.emit(reaction)
	finale_blast.emit(level)


func _finish_game() -> void:
	_active = false
	set_physics_process(false)
	_set_fever_visual(false)
	_score_manager.commit()
	game_over_details = {
		"reason": "TIME UP",
		"max_combo": max_combo,
		"blast_count": blast_count,
		"fever_count": fever_count,
		"finale_score": _score_manager.score - finale_score_start,
	}
	_set_state(State.FINISHED)
	game_over.emit()


func _board_occupancy() -> float:
	var occupied_area: float = 0.0
	for orb: Variant in _board.get_orbs():
		var radius: float = Config.data.radius_for_level(orb.level)
		occupied_area += PI * radius * radius
	return occupied_area / (Config.data.board_size * Config.data.board_size)


func _set_fever_visual(active: bool) -> void:
	if _board.has_method("set_fever_active"):
		_board.set_fever_active(active)


func _emit_combo_changed() -> void:
	combo_changed.emit(turn_combo, current_combo_multiplier(), max_combo)


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)
