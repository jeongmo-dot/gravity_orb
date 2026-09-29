class_name Hud
extends Control

@onready var _next_preview: OrbVisual = %NextPreview
@onready var _score_label: Label = %ScoreLabel
@onready var _best_label: Label = %BestLabel
@onready var _max_chain_label: Label = %MaxChainLabel

var _spawner: Spawner
var _score_manager: ScoreManager


func bind_spawner(spawner: Spawner) -> void:
	_spawner = spawner
	_spawner.next_changed.connect(_on_next_changed)
	var next_orb: Dictionary = _spawner.peek_next()
	if not next_orb.is_empty():
		_on_next_changed(int(next_orb["color"]), int(next_orb["level"]))


func bind_score_manager(score_manager: ScoreManager) -> void:
	_score_manager = score_manager
	_score_manager.score_changed.connect(_on_score_changed)
	_score_manager.max_chain_changed.connect(_on_max_chain_changed)
	_on_score_changed(_score_manager.score, _score_manager.best_score)
	_on_max_chain_changed(_score_manager.max_chain)


func _on_next_changed(color: int, level: int) -> void:
	_next_preview.setup(
		Config.data.color_display[color],
		Config.data.radius_for_level(level)
	)


func _on_score_changed(score: int, best: int) -> void:
	_score_label.text = "SCORE\n%d" % score
	_best_label.text = "BEST\n%d" % best


func _on_max_chain_changed(max_chain: int) -> void:
	_max_chain_label.text = "MAX CHAIN  %d" % max_chain
