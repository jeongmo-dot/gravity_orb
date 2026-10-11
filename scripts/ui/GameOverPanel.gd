class_name GameOverPanel
extends PanelContainer

signal mode_select_requested
signal ranking_requested(mode: GameConfig.GameMode, highlight_rank: int)

const SCORE_ANIMATION_SECONDS: float = 0.6
const PANEL_ANIMATION_SECONDS: float = 0.25
const DIM_ANIMATION_SECONDS: float = 0.2
const LEVEL_NAMES_KO: Array[String] = [
	"", "운석", "달", "바위 행성", "고리 행성", "가스 거인", "별", "태양"
]

@onready var _title_label: Label = %ResultTitle
@onready var _score_label: Label = %GameOverScore
@onready var _best_label: Label = %GameOverBest
@onready var _survived_time_label: Label = %SurvivedTimeLabel
@onready var _max_combo_label: Label = %GameOverMaxCombo
@onready var _blocked_label: Label = %GameOverBlocked
@onready var _extra_label: Label = %ResultExtraLabel
@onready var _ranking_result_label: Label = %RankingResultLabel
@onready var _restart_button: Button = %RestartButton
@onready var _ranking_button: Button = %ResultRankingButton
@onready var _mode_select_button: Button = %ModeSelectButton
@onready var _dimmer: ColorRect = %ResultDimmer

var _game_manager: Variant
var _score_manager: ScoreManager
var _action_taken: bool = false


func bind(game_manager: Variant, score_manager: ScoreManager) -> void:
	_game_manager = game_manager
	_score_manager = score_manager
	_game_manager.game_over.connect(_on_game_over)
	_restart_button.pressed.connect(_on_restart_pressed)
	_ranking_button.pressed.connect(_on_ranking_pressed)
	_mode_select_button.pressed.connect(_on_mode_select_pressed)
	for button: Button in [_restart_button, _ranking_button, _mode_select_button]:
		ButtonMotion.bind(button)
	_dimmer.visible = false
	visible = false


func _on_game_over() -> void:
	_action_taken = false
	_set_actions_enabled(false)
	var blitz_mode: bool = _game_manager is BlitzManager
	_title_label.text = "TIME UP" if blitz_mode else "GAME OVER"
	_score_label.text = "0"
	_set_stat_text(blitz_mode)
	var ranking: Dictionary = _game_manager.game_over_details.get("ranking", {}) as Dictionary
	var rank: int = int(ranking.get("rank", 0))
	_ranking_result_label.visible = rank > 0
	_ranking_result_label.text = "최고 기록!" if rank == 1 else "새 기록 · %d위" % rank
	_best_label.visible = rank <= 0
	_best_label.text = "BEST %s" % _format_score(_score_manager.best_score)
	_dimmer.visible = true
	_dimmer.modulate.a = 0.0
	visible = true
	pivot_offset = size * 0.5
	scale = Vector2(0.92, 0.92)
	modulate.a = 0.0
	var dim_tween: Tween = _dimmer.create_tween()
	dim_tween.tween_property(_dimmer, "modulate:a", 1.0, DIM_ANIMATION_SECONDS)
	var panel_tween: Tween = create_tween().set_parallel(true)
	panel_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(self, "scale", Vector2.ONE, PANEL_ANIMATION_SECONDS)
	panel_tween.tween_property(self, "modulate:a", 1.0, PANEL_ANIMATION_SECONDS)
	var score_tween: Tween = create_tween()
	score_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	score_tween.tween_method(_set_animated_score, 0, _score_manager.score, SCORE_ANIMATION_SECONDS)
	if rank > 0:
		_ranking_result_label.scale = Vector2(0.72, 0.72)
		_ranking_result_label.pivot_offset = _ranking_result_label.size * 0.5
		var badge_tween: Tween = _ranking_result_label.create_tween()
		badge_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		badge_tween.tween_interval(SCORE_ANIMATION_SECONDS)
		badge_tween.tween_property(
			_ranking_result_label,
			"scale",
			Vector2.ONE,
			PANEL_ANIMATION_SECONDS
		)
	await panel_tween.finished
	_set_actions_enabled(true)


func _set_stat_text(blitz_mode: bool) -> void:
	if blitz_mode:
		_survived_time_label.text = "버틴 시간\n%s" % _format_survived_time(
			float(_game_manager.game_over_details.get(
				"survived_time", _game_manager.play_time_elapsed
			))
		)
		_max_combo_label.text = "최대 체인\n%d" % _game_manager.max_combo
		_blocked_label.text = "블라스트\n%d" % _game_manager.blast_count
		_extra_label.text = "피버\n%d" % _game_manager.fever_count
	else:
		var level: int = clampi(_score_manager.max_level_reached, 0, LEVEL_NAMES_KO.size() - 1)
		_survived_time_label.text = "턴 수\n%d" % _game_manager.turn_index
		_max_combo_label.text = "최대 콤보\n%d" % _game_manager.max_combo
		_blocked_label.text = "최고 천체\nL%d %s" % [level, LEVEL_NAMES_KO[level]]
		var blocked_direction: Vector2i = _game_manager.game_over_details.get(
			"direction", _game_manager.gravity
		) as Vector2i
		_extra_label.text = "막힌 방향\n%s" % OrbTypes.dir_name(blocked_direction)
	for label: Label in [
		_survived_time_label, _max_combo_label, _blocked_label, _extra_label
	]:
		label.visible = true


func _set_animated_score(value: int) -> void:
	_score_label.text = _format_score(value)


func _format_survived_time(seconds: float) -> String:
	var total_seconds: int = maxi(floori(maxf(seconds, 0.0)), 0)
	return "%d:%02d" % [total_seconds / 60, total_seconds % 60]


func _format_score(score: int) -> String:
	var digits: String = str(maxi(score, 0))
	var formatted: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits[index]
	return formatted


func _set_actions_enabled(enabled: bool) -> void:
	_restart_button.disabled = not enabled
	_ranking_button.disabled = not enabled
	_mode_select_button.disabled = not enabled


func _take_action() -> bool:
	if _action_taken or _restart_button.disabled:
		return false
	_action_taken = true
	_set_actions_enabled(false)
	return true


func _on_restart_pressed() -> void:
	if _take_action():
		InputRouter.restart_requested.emit()


func _on_mode_select_pressed() -> void:
	if _take_action():
		mode_select_requested.emit()


func _on_ranking_pressed() -> void:
	if not _take_action():
		return
	var mode: GameConfig.GameMode = (
		GameConfig.GameMode.BLITZ if _game_manager is BlitzManager else GameConfig.GameMode.TURN
	)
	var ranking: Dictionary = _game_manager.game_over_details.get("ranking", {}) as Dictionary
	ranking_requested.emit(mode, int(ranking.get("rank", 0)))
