class_name TurnManager3D
extends Node

enum State { WAITING_INPUT, SIMULATING, SPAWNING, CHECK_GAMEOVER, GAME_OVER }

signal state_changed(state: State)
signal gravity_changed(dir: Vector2i)
signal turn_started(turn_index: int, dir: Vector2i)
signal turn_finished(turn_index: int, max_chain: int)
signal chain_changed(chain: int)
signal warning_changed(walls: Array[Vector2i])
signal game_over

@onready var _board: Board3D = %Board
@onready var _spawner: Spawner3D = %Spawner
@onready var _collision_resolver: CollisionResolver3D = %CollisionResolver

var state: State = State.WAITING_INPUT
var gravity: Vector2i = Vector2i.DOWN
var turn_index: int = 0
var turn_max_chain: int = 0
var capped_turn_count: int = 0
var blocked_directions: Array[Vector2i] = []
var game_over_details: Dictionary = {}
var settle_elapsed: float = 0.0

var _stable_time: float = 0.0
var _is_initial_settle: bool = false


func _ready() -> void:
	_collision_resolver.reaction_applied.connect(on_reaction)


func start_game() -> void:
	turn_index = 0
	turn_max_chain = 0
	capped_turn_count = 0
	blocked_directions.clear()
	game_over_details.clear()
	gravity = Vector2i.DOWN
	_is_initial_settle = true
	InputRouter.set_locked(true)
	_board.set_gravity(gravity)
	_board.set_warning_directions(blocked_directions)
	gravity_changed.emit(gravity)
	_begin_settle()
	_set_state(State.SIMULATING)


func on_swipe(direction: Vector2i) -> void:
	if state != State.WAITING_INPUT:
		return
	if direction == gravity and not Config.data.allow_same_direction_swipe:
		return

	turn_index += 1
	turn_max_chain = 0
	for orb: Orb3D in _board.get_orbs():
		orb.generation = 0
	InputRouter.set_locked(true)
	gravity = direction
	_board.set_gravity(gravity)
	_board.play_visual_tilt(gravity)
	gravity_changed.emit(gravity)
	turn_started.emit(turn_index, gravity)
	_set_state(State.SPAWNING)


func _physics_process(delta: float) -> void:
	var applied_reactions: int = _collision_resolver.flush()

	if state == State.SPAWNING:
		_spawner.try_spawn(_board, gravity, turn_index)
		_begin_settle()
		_set_state(State.SIMULATING)
		return

	if state != State.SIMULATING:
		return

	if applied_reactions > 0:
		_stable_time = 0.0

	settle_elapsed += delta
	if _all_below_threshold():
		_stable_time += delta
	else:
		_stable_time = 0.0

	if settle_elapsed >= Config.data.max_settle_time:
		_collision_resolver.sweep_resting_contacts()
		if not _is_initial_settle:
			capped_turn_count += 1
		_on_settled()
	elif _stable_time >= Config.data.stable_duration:
		if _collision_resolver.sweep_resting_contacts() > 0:
			_stable_time = 0.0
			return
		_on_settled()


func _all_below_threshold() -> bool:
	for orb: Orb3D in _board.get_orbs():
		if orb.is_waiting_at_entrance:
			continue
		if orb.linear_velocity.length() > Config.data.stable_linear_speed:
			return false
		if absf(orb.angular_velocity) > Config.data.stable_angular_speed:
			return false
	return true


func on_reaction(reaction: Dictionary) -> void:
	_stable_time = 0.0
	var chain: int = int(reaction["chain"])
	if chain <= turn_max_chain:
		return
	turn_max_chain = chain
	chain_changed.emit(turn_max_chain)


func _begin_settle() -> void:
	_stable_time = 0.0
	settle_elapsed = 0.0


func _on_settled() -> void:
	if _is_initial_settle:
		_is_initial_settle = false
		_update_warnings()
		InputRouter.set_locked(false)
		_set_state(State.WAITING_INPUT)
		return

	_set_state(State.CHECK_GAMEOVER)
	turn_finished.emit(turn_index, turn_max_chain)
	var blocked_spawns: Array[Orb3D] = _board.entrance_waiting_orbs()
	if not blocked_spawns.is_empty():
		game_over_details = _build_game_over_details(blocked_spawns)
		_set_state(State.GAME_OVER)
		game_over.emit()
		return
	_update_warnings()
	InputRouter.set_locked(false)
	_set_state(State.WAITING_INPUT)


func _build_game_over_details(blocked_spawns: Array[Orb3D]) -> Dictionary:
	var levels: Array[int] = []
	var overlap_counts: Array[int] = []
	for orb: Orb3D in blocked_spawns:
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
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)
