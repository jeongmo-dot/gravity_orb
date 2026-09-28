class_name Hud
extends Control

@onready var _next_preview: OrbVisual = %NextPreview

var _spawner: Spawner


func bind_spawner(spawner: Spawner) -> void:
	_spawner = spawner
	_spawner.next_changed.connect(_on_next_changed)
	var next_orb: Dictionary = _spawner.peek_next()
	if not next_orb.is_empty():
		_on_next_changed(int(next_orb["color"]), int(next_orb["level"]))


func _on_next_changed(color: int, level: int) -> void:
	_next_preview.setup(
		Config.data.color_display[color],
		Config.data.radius_for_level(level)
	)
