class_name Hud
extends Control

const MAX_PREVIEW_COUNT: int = 3
const PREVIEW_REGION_SIZE: Vector2 = Vector2(280.0, 150.0)
const PREVIEW_GAP: float = 16.0

@onready var _next_preview: Node2D = %NextPreview
@onready var _score_label: Label = %ScoreLabel
@onready var _best_label: Label = %BestLabel
@onready var _max_combo_label: Label = %MaxComboLabel
@onready var _combo_label: Label = %ComboLabel
@onready var _danger_label: Label = %DangerLabel
@onready var _blocked_label: Label = %BlockedLabel
@onready var _game_over_panel: GameOverPanel = %GameOverPanel

var _spawner: Spawner
var _score_manager: ScoreManager


func bind_spawner(spawner: Spawner) -> void:
	_spawner = spawner
	_spawner.next_batch_changed.connect(_on_next_batch_changed)
	_on_next_batch_changed(_spawner.peek_next())


func bind_score_manager(score_manager: ScoreManager) -> void:
	_score_manager = score_manager
	_score_manager.score_changed.connect(_on_score_changed)
	_score_manager.reaction_scored.connect(_on_reaction_scored)
	_on_score_changed(_score_manager.score, _score_manager.best_score)


func bind_game_state(
	turn_manager: TurnManager,
	board: Variant,
	score_manager: ScoreManager
) -> void:
	turn_manager.warning_changed.connect(_on_warning_changed)
	turn_manager.combo_changed.connect(_on_combo_changed)
	_game_over_panel.bind(turn_manager, score_manager)
	_on_warning_changed(turn_manager.blocked_directions)
	_on_combo_changed(
		turn_manager.turn_combo,
		turn_manager.current_combo_multiplier(),
		turn_manager.max_combo
	)
	board.set_warning_directions(turn_manager.blocked_directions)


func _on_next_batch_changed(batch: Array[Dictionary]) -> void:
	for child: Node in _next_preview.get_children():
		_next_preview.remove_child(child)
		child.queue_free()

	var preview_count: int = mini(batch.size(), MAX_PREVIEW_COUNT)
	if preview_count == 0:
		return

	var radii: Array[float] = []
	var natural_width: float = 0.0
	var natural_height: float = 0.0
	for index: int in range(preview_count):
		var level: int = int(batch[index]["level"])
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
		var candidate: Dictionary = batch[index]
		var radius: float = radii[index]
		var visual: OrbVisual = OrbVisual.new()
		_next_preview.add_child(visual)
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
