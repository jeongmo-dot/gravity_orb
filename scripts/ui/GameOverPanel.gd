class_name GameOverPanel
extends PanelContainer

signal mode_select_requested
signal ranking_requested(mode: GameConfig.GameMode, highlight_rank: int)

@onready var _title_label: Label = %ResultTitle
@onready var _score_label: Label = %GameOverScore
@onready var _best_label: Label = %GameOverBest
@onready var _max_combo_label: Label = %GameOverMaxCombo
@onready var _blocked_label: Label = %GameOverBlocked
@onready var _ranking_result_label: Label = %RankingResultLabel
@onready var _restart_button: Button = %RestartButton
@onready var _ranking_button: Button = %ResultRankingButton
@onready var _mode_select_button: Button = %ModeSelectButton
@onready var _dimmer: ColorRect = %ResultDimmer

var _game_manager: Variant
var _score_manager: ScoreManager


func bind(game_manager: Variant, score_manager: ScoreManager) -> void:
	_game_manager = game_manager
	_score_manager = score_manager
	_game_manager.game_over.connect(_on_game_over)
	_restart_button.pressed.connect(_on_restart_pressed)
	_ranking_button.pressed.connect(_on_ranking_pressed)
	_mode_select_button.pressed.connect(_on_mode_select_pressed)
	_dimmer.visible = false
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
	var ranking: Dictionary = _game_manager.game_over_details.get("ranking", {}) as Dictionary
	var rank: int = int(ranking.get("rank", 0))
	_ranking_result_label.visible = rank > 0
	_ranking_result_label.text = "최고 기록!" if rank == 1 else "새 기록! %d위" % rank
	_dimmer.visible = true
	visible = true


func _on_restart_pressed() -> void:
	InputRouter.restart_requested.emit()


func _on_mode_select_pressed() -> void:
	mode_select_requested.emit()


func _on_ranking_pressed() -> void:
	var mode: GameConfig.GameMode = (
		GameConfig.GameMode.BLITZ if _game_manager is BlitzManager else GameConfig.GameMode.TURN
	)
	var ranking: Dictionary = _game_manager.game_over_details.get("ranking", {}) as Dictionary
	ranking_requested.emit(mode, int(ranking.get("rank", 0)))
