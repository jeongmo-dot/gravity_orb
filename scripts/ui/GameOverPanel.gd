class_name GameOverPanel
extends PanelContainer

@onready var _score_label: Label = %GameOverScore
@onready var _best_label: Label = %GameOverBest
@onready var _max_combo_label: Label = %GameOverMaxCombo
@onready var _blocked_label: Label = %GameOverBlocked
@onready var _restart_button: Button = %RestartButton

var _turn_manager: TurnManager
var _score_manager: ScoreManager


func bind(turn_manager: TurnManager, score_manager: ScoreManager) -> void:
	_turn_manager = turn_manager
	_score_manager = score_manager
	_turn_manager.game_over.connect(_on_game_over)
	_restart_button.pressed.connect(_on_restart_pressed)
	visible = false


func _on_game_over() -> void:
	_score_label.text = "SCORE  %d" % _score_manager.score
	_best_label.text = "BEST  %d" % _score_manager.best_score
	_max_combo_label.text = "MAX COMBO  %d" % _score_manager.max_combo
	_blocked_label.text = "BLOCKED: %s" % OrbTypes.dir_name(_turn_manager.gravity)
	visible = true


func _on_restart_pressed() -> void:
	InputRouter.restart_requested.emit()
