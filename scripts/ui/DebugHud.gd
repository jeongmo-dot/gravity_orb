class_name DebugHud
extends CanvasLayer

const STATE_NAMES: Array[String] = [
	"WAITING_INPUT",
	"SIMULATING",
	"SPAWNING",
	"CHECK_GAMEOVER",
	"GAME_OVER",
]
const ANNIHILATION_RULE_NAMES: Array[String] = ["A", "B", "C"]

@onready var _turn_manager: TurnManager = %TurnManager
@onready var _spawner: Spawner = %Spawner
@onready var _score_manager: ScoreManager = %ScoreManager
@onready var _board: Board = %Board
@onready var _label: Label = %DebugLabel
@onready var _hud: Hud = %Hud

var _state: TurnManager.State = TurnManager.State.WAITING_INPUT
var _gravity: Vector2i = Vector2i.DOWN
var _turn_index: int = 0
var _turn_max_chain: int = 0


func _ready() -> void:
	_hud.bind_spawner(_spawner)
	_hud.bind_score_manager(_score_manager)
	_hud.bind_game_state(_turn_manager, _board, _score_manager)
	_state = _turn_manager.state
	_gravity = _turn_manager.gravity
	_turn_index = _turn_manager.turn_index
	_turn_max_chain = _turn_manager.turn_max_chain
	_turn_manager.state_changed.connect(_on_state_changed)
	_turn_manager.gravity_changed.connect(_on_gravity_changed)
	_turn_manager.turn_started.connect(_on_turn_started)
	_turn_manager.turn_finished.connect(_on_turn_finished)
	_turn_manager.chain_changed.connect(_on_chain_changed)
	_update_label()


func _process(_delta: float) -> void:
	_update_label()


func _on_state_changed(next_state: TurnManager.State) -> void:
	_state = next_state


func _on_gravity_changed(direction: Vector2i) -> void:
	_gravity = direction


func _on_turn_started(next_turn_index: int, _direction: Vector2i) -> void:
	_turn_index = next_turn_index
	_turn_max_chain = 0


func _on_turn_finished(finished_turn_index: int, _max_chain: int) -> void:
	_turn_index = finished_turn_index
	_turn_max_chain = _max_chain


func _on_chain_changed(chain: int) -> void:
	_turn_max_chain = chain


func _update_label() -> void:
	_label.text = "State: %s\nGravity: %s\nTurn: %d\nChain: %d\nRule: %s\nSpawn: %d\nSettle: %.2f s\nSeed: %d" % [
		STATE_NAMES[_state],
		OrbTypes.dir_name(_gravity),
		_turn_index,
		_turn_max_chain,
		ANNIHILATION_RULE_NAMES[Config.data.annihilation_rule],
		Config.data.spawn_count_for_turn(_turn_manager.turn_index + 1),
		_turn_manager._settle_elapsed,
		_spawner.seed_used,
	]
