class_name TurnManager
extends Node

enum State { WAITING_INPUT, SIMULATING, SPAWNING, CHECK_GAMEOVER, GAME_OVER }

signal state_changed(state: State)
signal gravity_changed(dir: Vector2i)
signal turn_started(turn_index: int, dir: Vector2i)
signal turn_finished(turn_index: int, max_chain: int)

@onready var _board: Board = %Board
@onready var _spawner: Spawner = %Spawner

var state: State = State.WAITING_INPUT
var gravity: Vector2i = Vector2i.DOWN
var turn_index: int = 0

var _stable_time: float = 0.0
var _settle_elapsed: float = 0.0
var _is_initial_settle: bool = false


func start_game() -> void:
	turn_index = 0
	gravity = Vector2i.DOWN
	_is_initial_settle = true
	InputRouter.set_locked(true)
	_board.set_gravity(gravity)
	gravity_changed.emit(gravity)
	_begin_settle()
	_set_state(State.SIMULATING)


func on_swipe(dir: Vector2i) -> void:
	if state != State.WAITING_INPUT:
		return
	if dir == gravity and not Config.data.allow_same_direction_swipe:
		return

	turn_index += 1
	InputRouter.set_locked(true)
	gravity = dir
	_board.set_gravity(gravity)
	gravity_changed.emit(gravity)
	turn_started.emit(turn_index, gravity)
	_set_state(State.SPAWNING)


func _physics_process(delta: float) -> void:
	if state == State.SPAWNING:
		_spawner.try_spawn(_board, gravity)
		_begin_settle()
		_set_state(State.SIMULATING)
		return

	if state != State.SIMULATING:
		return

	_settle_elapsed += delta
	if _all_below_threshold():
		_stable_time += delta
	else:
		_stable_time = 0.0

	if _stable_time >= Config.data.stable_duration:
		_on_settled()
	elif _settle_elapsed >= Config.data.max_settle_time:
		push_warning(
			"forced settle turn=%d elapsed=%.3f" % [turn_index, _settle_elapsed]
		)
		_on_settled()


func _all_below_threshold() -> bool:
	for orb: Orb in _board.get_orbs():
		if orb.linear_velocity.length() > Config.data.stable_linear_speed:
			return false
		if absf(orb.angular_velocity) > Config.data.stable_angular_speed:
			return false
	return true


func _begin_settle() -> void:
	_stable_time = 0.0
	_settle_elapsed = 0.0


func _on_settled() -> void:
	if _is_initial_settle:
		_is_initial_settle = false
		InputRouter.set_locked(false)
		_set_state(State.WAITING_INPUT)
		return

	_set_state(State.CHECK_GAMEOVER)
	turn_finished.emit(turn_index, 0)
	InputRouter.set_locked(false)
	_set_state(State.WAITING_INPUT)


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)
