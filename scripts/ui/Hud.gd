class_name Hud
extends Control

const MAX_PREVIEW_COUNT: int = 3
const PREVIEW_REGION_SIZE: Vector2 = Vector2(280.0, 150.0)
const PREVIEW_GAP: float = 16.0

@onready var _next_preview: Node2D = %NextPreview
@onready var _score_label: Label = %ScoreLabel
@onready var _best_label: Label = %BestLabel
@onready var _max_chain_label: Label = %MaxChainLabel

var _spawner: Spawner
var _score_manager: ScoreManager


func bind_spawner(spawner: Spawner) -> void:
	_spawner = spawner
	_spawner.next_batch_changed.connect(_on_next_batch_changed)
	_on_next_batch_changed(_spawner.peek_next())


func bind_score_manager(score_manager: ScoreManager) -> void:
	_score_manager = score_manager
	_score_manager.score_changed.connect(_on_score_changed)
	_score_manager.max_chain_changed.connect(_on_max_chain_changed)
	_on_score_changed(_score_manager.score, _score_manager.best_score)
	_on_max_chain_changed(_score_manager.max_chain)


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


func _on_max_chain_changed(max_chain: int) -> void:
	_max_chain_label.text = "MAX CHAIN  %d" % max_chain
