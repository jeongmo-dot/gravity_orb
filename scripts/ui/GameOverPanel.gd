class_name GameOverPanel
extends PanelContainer

@onready var _title_label: Label = %ResultTitle
@onready var _score_label: Label = %GameOverScore
@onready var _best_label: Label = %GameOverBest
@onready var _max_combo_label: Label = %GameOverMaxCombo
@onready var _blocked_label: Label = %GameOverBlocked
@onready var _restart_button: Button = %RestartButton

var _game_manager: Variant
var _score_manager: ScoreManager


func bind(game_manager: Variant, score_manager: ScoreManager) -> void:
	_game_manager = game_manager
	_score_manager = score_manager
	_game_manager.game_over.connect(_on_game_over)
	_restart_button.pressed.connect(_on_restart_pressed)
	visible = false


func _on_game_over() -> void:
	var blitz_mode: bool = _game_manager is BlitzManager
	_title_label.text = "TIME UP" if blitz_mode else "GAME OVER"
	_score_label.text = "SCORE  %d" % _score_manager.score
	_best_label.text = "BEST  %d" % _score_manager.best_score
	_max_combo_label.text = "%s %d" % [
		"MAX CHAIN" if blitz_mode else "MAX COMBO",
		_game_manager.max_combo,
	]
	if blitz_mode:
		_blocked_label.text = "BLAST %d   FEVER %d" % [
			_game_manager.blast_count,
			_game_manager.fever_count,
		]
	else:
		_blocked_label.text = "BLOCKED: %s" % OrbTypes.dir_name(_game_manager.gravity)
	visible = true


func _on_restart_pressed() -> void:
	InputRouter.restart_requested.emit()
