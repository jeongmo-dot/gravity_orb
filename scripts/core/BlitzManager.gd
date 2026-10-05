class_name BlitzManager
extends Node

enum State { IDLE, READY, RUNNING, FINALE, FINISHED }

signal state_changed(state: State)
signal gravity_changed(dir: Vector2i)
signal turn_started(turn_index: int, dir: Vector2i)
signal turn_finished(turn_index: int, combo: int)
signal combo_changed(combo: int, multiplier: float, max_combo: int)
signal reaction_ready(reaction: Dictionary)
signal warning_changed(walls: Array[Vector2i])
signal game_over
signal time_changed(remaining: float)
signal ready_changed(active: bool, remaining: float)
signal fever_changed(active: bool, remaining: float)
signal time_bonus_awarded(seconds: float, source: String)
signal finale_started
signal finale_blast(level: int)

const FINALE_REACTION_IDLE_TIME: float = 1.5
const FINALE_SETTLE_LIMIT: float = 5.0

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
var ready_remaining: float = 0.0
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
var productive_swipes: int = 0
var chain_histogram: Dictionary = {}
var first_reaction_time: float = -1.0
var finale_score_start: int = 0

var chain: int:
	get:
		return turn_combo

var max_chain: int:
	get:
		return max_combo

var _active: bool = false
var _swipe_cooldown_remaining: float = 0.0
var _spawn_elapsed: float = 0.0
var _chain_idle_elapsed: float = 0.0
var _has_accepted_swipe: bool = false
var _pending_swipe_windows: Array[Dictionary] = []
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
	ready_remaining = maxf(Config.data.blitz_ready_time, 0.0)
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
	productive_swipes = 0
	chain_histogram.clear()
	first_reaction_time = -1.0
	finale_score_start = 0
	_swipe_cooldown_remaining = 0.0
	_spawn_elapsed = 0.0
	_chain_idle_elapsed = 0.0
	_has_accepted_swipe = false
	_pending_swipe_windows.clear()
	_finale_interval_remaining = 0.0
	_finale_idle_elapsed = 0.0
	_finale_settle_elapsed = 0.0
	if not _collision_resolver.reaction_applied.is_connected(on_reaction):
		_collision_resolver.reaction_applied.connect(on_reaction)
	_spawner.set_blitz_mode(true)
	_spawner.sync_next_batch_size(1)
	_board.set_gravity(gravity)
	_board.set_warning_directions(blocked_directions)
	_set_fever_visual(false)
	gravity_changed.emit(gravity)
	warning_changed.emit(blocked_directions)
	_emit_combo_changed()
	time_changed.emit(remaining_time)
	fever_changed.emit(false, 0.0)
	if ready_remaining > 0.0:
		InputRouter.set_locked(true)
		_set_state(State.READY)
		ready_changed.emit(true, ready_remaining)
	else:
		_start_running()


func on_swipe(dir: Vector2i) -> void:
	if state != State.RUNNING:
		return
	if dir == gravity or _swipe_cooldown_remaining > 0.0:
		return
	gravity = dir
	turn_index += 1
	accepted_swipes += 1
	_swipe_cooldown_remaining = maxf(Config.data.blitz_swipe_cooldown, 0.0)
	_chain_idle_elapsed = 0.0
	_has_accepted_swipe = true
	_pending_swipe_windows.append({
		"remaining": maxf(Config.data.blitz_chain_window, 0.0),
	})
	_board.set_gravity(gravity)
	if _board.has_method("play_visual_tilt"):
		_board.play_visual_tilt(gravity)
	gravity_changed.emit(gravity)
	turn_started.emit(turn_index, gravity)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_collision_resolver.flush(delta)
	if state == State.READY:
		_advance_ready(delta)
	elif state == State.RUNNING:
		_advance_running(delta)
	elif state == State.FINALE:
		_advance_chain(delta)
		_advance_fever(delta)
		_advance_finale(delta)


func on_reaction(reaction: Dictionary) -> void:
	if state != State.RUNNING and state != State.FINALE:
		return
	if first_reaction_time < 0.0:
		first_reaction_time = play_time_elapsed
	_mark_latest_productive_swipe()
	reaction["chain"] = turn_combo
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
	_finale_idle_elapsed = 0.0
	reaction_ready.emit(reaction)


func current_combo_multiplier() -> float:
	return minf(
		1.0 + Config.data.blitz_chain_step * float(turn_combo),
		Config.data.blitz_chain_max_multiplier
	)


func _advance_ready(delta: float) -> void:
	ready_remaining = maxf(ready_remaining - maxf(delta, 0.0), 0.0)
	ready_changed.emit(true, ready_remaining)
	if ready_remaining <= 0.0:
		_start_running()


func _start_running() -> void:
	InputRouter.set_locked(false)
	ready_changed.emit(false, 0.0)
	_set_state(State.RUNNING)


func _advance_running(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	settle_elapsed += step
	play_time_elapsed += step
	_swipe_cooldown_remaining = maxf(_swipe_cooldown_remaining - step, 0.0)
	_advance_chain(step)
	_advance_fever(step)
	_spawn_elapsed += step
	while state == State.RUNNING:
		var spawn_interval: float = _current_spawn_interval()
		if _spawn_elapsed < spawn_interval:
			break
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


func _current_spawn_interval() -> float:
	var interval: float = Config.data.blitz_spawn_interval
	if _board_occupancy() < Config.data.blitz_target_occupancy:
		interval = Config.data.blitz_refill_interval
	return maxf(interval, 0.001)


func _advance_chain(delta: float) -> void:
	var missed_swipe: bool = false
	for index: int in range(_pending_swipe_windows.size() - 1, -1, -1):
		var window: Dictionary = _pending_swipe_windows[index]
		window["remaining"] = float(window["remaining"]) - delta
		if float(window["remaining"]) <= 0.0:
			_pending_swipe_windows.remove_at(index)
			missed_swipe = true
	if missed_swipe:
		_reset_chain()
	if not _has_accepted_swipe:
		return
	_chain_idle_elapsed += delta
	if _chain_idle_elapsed >= Config.data.blitz_chain_idle:
		_reset_chain()


func _mark_latest_productive_swipe() -> void:
	if _pending_swipe_windows.is_empty():
		return
	_pending_swipe_windows.pop_back()
	turn_combo += 1
	max_combo = maxi(max_combo, turn_combo)
	productive_swipes += 1
	chain_histogram[turn_combo] = int(chain_histogram.get(turn_combo, 0)) + 1
	if (
		Config.data.blitz_fever_chain > 0
		and turn_combo % Config.data.blitz_fever_chain == 0
	):
		fever_remaining = maxf(Config.data.blitz_fever_duration, 0.0)
		fever_count += 1
		_set_fever_visual(fever_remaining > 0.0)
		fever_changed.emit(fever_remaining > 0.0, fever_remaining)
	_emit_combo_changed()


func _reset_chain() -> void:
	if turn_combo == 0:
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
	var available: float = maxf(
		Config.data.blitz_time_bonus_cap - time_bonus_total,
		0.0
	)
	var bonus: float = minf(maxf(seconds, 0.0), available)
	if bonus <= 0.0:
		return
	remaining_time += bonus
	time_bonus_total += bonus
	time_changed.emit(remaining_time)
	time_bonus_awarded.emit(bonus, source)


func _begin_finale() -> void:
	InputRouter.set_locked(true)
	_pending_swipe_windows.clear()
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
		_finale_idle_elapsed >= FINALE_REACTION_IDLE_TIME
		or _finale_settle_elapsed >= FINALE_SETTLE_LIMIT
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
		"chain": turn_combo,
		"combo": turn_combo,
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
		"max_chain": max_combo,
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
