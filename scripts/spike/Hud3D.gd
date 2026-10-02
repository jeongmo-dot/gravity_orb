class_name Hud3D
extends CanvasLayer

const STATE_NAMES: Array[String] = [
	"WAITING_INPUT",
	"SIMULATING",
	"SPAWNING",
	"CHECK_GAMEOVER",
	"GAME_OVER",
]

@onready var _manager: TurnManager3D = %TurnManager
@onready var _spawner: Spawner3D = %Spawner
@onready var _score_manager: ScoreManager = %ScoreManager
@onready var _status_label: Label = %StatusLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _next_label: Label = %NextLabel
@onready var _game_over_label: Label = %GameOverLabel


func _ready() -> void:
	_manager.state_changed.connect(_update_status.unbind(1))
	_manager.gravity_changed.connect(_update_status.unbind(1))
	_manager.turn_started.connect(_update_status.unbind(2))
	_manager.turn_finished.connect(_update_status.unbind(2))
	_manager.warning_changed.connect(_update_status.unbind(1))
	_manager.game_over.connect(_on_game_over)
	_spawner.next_batch_changed.connect(_on_next_batch_changed)
	_score_manager.score_changed.connect(_on_score_changed)
	_on_score_changed(_score_manager.score, _score_manager.best_score)
	_on_next_batch_changed(_spawner.peek_next())
	_update_status()


func _process(_delta: float) -> void:
	_update_status()


func _update_status() -> void:
	var blocked_names: Array[String] = []
	for direction: Vector2i in _manager.blocked_directions:
		blocked_names.append(OrbTypes.dir_name(direction))
	_status_label.text = "JOLT 3D SPIKE\nState: %s\nGravity: %s\nTurn: %d\nSettle: %.2f s\nBlocked: %s" % [
		STATE_NAMES[_manager.state],
		OrbTypes.dir_name(_manager.gravity),
		_manager.turn_index,
		_manager.settle_elapsed,
		"NONE" if blocked_names.is_empty() else ", ".join(blocked_names),
	]


func _on_score_changed(score: int, best: int) -> void:
	_score_label.text = "SCORE  %d\nBEST  %d" % [score, best]


func _on_next_batch_changed(batch: Array[Dictionary]) -> void:
	var descriptions: Array[String] = []
	for candidate: Dictionary in batch:
		descriptions.append("C%d L%d" % [int(candidate["color"]) + 1, int(candidate["level"])])
	_next_label.text = "NEXT\n%s" % "   ".join(descriptions)


func _on_game_over() -> void:
	_game_over_label.visible = true
	_game_over_label.text = "GAME OVER\nTURN %d\nSCORE %d\n%s" % [
		_manager.turn_index,
		_score_manager.score,
		OrbTypes.dir_name(_manager.gravity),
	]
