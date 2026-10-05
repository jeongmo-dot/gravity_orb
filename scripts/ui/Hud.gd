class_name Hud
extends Control

const MAX_PREVIEW_COUNT: int = 3
const PREVIEW_REGION_SIZE: Vector2 = Vector2(280.0, 150.0)
const PREVIEW_GAP: float = 16.0

@onready var _next_preview: Node2D = %NextPreview
@onready var _then_preview: Node2D = %ThenPreview
@onready var _then_label: Label = %ThenLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _best_label: Label = %BestLabel
@onready var _max_combo_label: Label = %MaxComboLabel
@onready var _combo_label: Label = %ComboLabel
@onready var _danger_label: Label = %DangerLabel
@onready var _blocked_label: Label = %BlockedLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _fever_label: Label = %FeverLabel
@onready var _bonus_label: Label = %BonusLabel
@onready var _game_over_panel: GameOverPanel = %GameOverPanel

var _spawner: Spawner
var _score_manager: ScoreManager
var _bonus_tween: Tween


func bind_spawner(spawner: Spawner) -> void:
	_spawner = spawner
	_spawner.preview_changed.connect(_on_preview_changed)
	_on_preview_changed(_spawner.peek_preview())


func bind_score_manager(score_manager: ScoreManager) -> void:
	_score_manager = score_manager
	_score_manager.score_changed.connect(_on_score_changed)
	_score_manager.reaction_scored.connect(_on_reaction_scored)
	_on_score_changed(_score_manager.score, _score_manager.best_score)


func bind_game_state(
	game_manager: Variant,
	board: Variant,
	score_manager: ScoreManager
) -> void:
	game_manager.warning_changed.connect(_on_warning_changed)
	game_manager.combo_changed.connect(_on_combo_changed)
	_game_over_panel.bind(game_manager, score_manager)
	_on_warning_changed(game_manager.blocked_directions)
	_on_combo_changed(
		game_manager.turn_combo,
		game_manager.current_combo_multiplier(),
		game_manager.max_combo
	)
	board.set_warning_directions(game_manager.blocked_directions)
	var blitz_mode: bool = game_manager is BlitzManager
	_timer_label.visible = blitz_mode
	_fever_label.visible = false
	_bonus_label.visible = false
	_blocked_label.visible = not blitz_mode
	if blitz_mode:
		game_manager.time_changed.connect(_on_time_changed)
		game_manager.fever_changed.connect(_on_fever_changed)
		game_manager.time_bonus_awarded.connect(_on_time_bonus_awarded)
		_on_time_changed(game_manager.remaining_time)


func _on_preview_changed(batches: Array) -> void:
	var next_batch: Array = batches[0] if not batches.is_empty() else []
	_render_preview(_next_preview, next_batch)
	var has_then: bool = batches.size() > 1
	_then_label.visible = has_then
	_then_preview.visible = has_then
	var then_batch: Array = batches[1] if has_then else []
	_render_preview(_then_preview, then_batch)


func _render_preview(preview_root: Node2D, batch: Array) -> void:
	for child: Node in preview_root.get_children():
		preview_root.remove_child(child)
		child.queue_free()

	var preview_count: int = mini(batch.size(), MAX_PREVIEW_COUNT)
	if preview_count == 0:
		return

	var radii: Array[float] = []
	var natural_width: float = 0.0
	var natural_height: float = 0.0
	for index: int in range(preview_count):
		var candidate: Dictionary = batch[index] as Dictionary
		var level: int = int(candidate["level"])
		var radius: float = Config.data.radius_for_level(level)
		radii.append(radius)
		natural_width += radius * 2.0
		natural_height = maxf(natural_height, radius * 2.0)
	if preview_count > 1:
		natural_width += PREVIEW_GAP * float(preview_count - 1)

	var preview_scale: float = minf(
		1.0,
		minf(
			PREVIEW_REGION_SIZE.x / natural_width,
			PREVIEW_REGION_SIZE.y / natural_height
		)
	)
	var cursor_x: float = -natural_width * preview_scale * 0.5
	for index: int in range(preview_count):
		var candidate: Dictionary = batch[index] as Dictionary
		var radius: float = radii[index]
		var visual: OrbVisual = OrbVisual.new()
		preview_root.add_child(visual)
		visual.setup(
			Config.data.color_display[int(candidate["color"])],
			radius
		)
		visual.scale = Vector2.ONE * preview_scale
		visual.position = Vector2(
			cursor_x + radius * preview_scale,
			0.0
		)
		cursor_x += (radius * 2.0 + PREVIEW_GAP) * preview_scale


func _on_score_changed(score: int, best: int) -> void:
	_score_label.text = "SCORE\n%d" % score
	_best_label.text = "BEST\n%d" % best


func _on_combo_changed(combo: int, multiplier: float, max_combo: int) -> void:
	_max_combo_label.text = "MAX COMBO %d" % max_combo
	_combo_label.visible = combo > 0
	if combo <= 0:
		_danger_label.visible = false
		return
	_combo_label.text = "COMBO %d (x%s)" % [combo, _format_multiplier(multiplier)]


func _on_reaction_scored(reaction: Dictionary) -> void:
	var occupancy: float = float(reaction.get("occupancy", 0.0))
	_danger_label.visible = occupancy >= Config.data.danger_start
	if not _danger_label.visible:
		return
	_danger_label.text = "DANGER x%.1f" % float(reaction["danger_multiplier"])


func _format_multiplier(multiplier: float) -> String:
	if is_equal_approx(multiplier, float(roundi(multiplier))):
		return str(roundi(multiplier))
	return "%.2f" % multiplier


func _on_warning_changed(directions: Array[Vector2i]) -> void:
	var names: Array[String] = []
	for direction: Vector2i in directions:
		names.append(OrbTypes.dir_name(direction))
	_blocked_label.text = (
		"BLOCKED: NONE"
		if names.is_empty()
		else "BLOCKED: %s" % ", ".join(names)
	)


func _on_time_changed(remaining: float) -> void:
	_timer_label.text = "%.1f" % maxf(remaining, 0.0)
	_timer_label.modulate = Color("#FF3B30") if remaining <= 10.0 else Color.WHITE


func _on_fever_changed(active: bool, remaining: float) -> void:
	_fever_label.visible = active
	_fever_label.text = "FEVER x%.0f  %.1fs" % [
		Config.data.blitz_fever_multiplier,
		remaining,
	]


func _on_time_bonus_awarded(seconds: float, source: String) -> void:
	if _bonus_tween != null and _bonus_tween.is_valid():
		_bonus_tween.kill()
	_bonus_label.visible = true
	_bonus_label.modulate = Color.WHITE
	_bonus_label.text = "+%gs  %s" % [seconds, source]
	_bonus_tween = create_tween()
	_bonus_tween.tween_interval(0.7)
	_bonus_tween.tween_property(_bonus_label, "modulate:a", 0.0, 0.3)
	_bonus_tween.tween_callback(func() -> void: _bonus_label.visible = false)
