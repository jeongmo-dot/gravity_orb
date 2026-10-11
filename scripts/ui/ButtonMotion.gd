class_name ButtonMotion
extends RefCounted

const PRESS_SCALE: Vector2 = Vector2(0.96, 0.96)
const TRANSITION_SECONDS: float = 0.08


static func bind(button: Button) -> void:
	_apply_focus_and_hover_styles(button)
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	button.pivot_offset = button.size * 0.5
	button.button_down.connect(func() -> void: _animate(button, PRESS_SCALE, 1.08))
	button.button_up.connect(func() -> void: _animate(button, Vector2.ONE, 1.0))
	button.mouse_exited.connect(func() -> void: _animate(button, Vector2.ONE, 1.0))


static func _animate(button: Button, target_scale: Vector2, brightness: float) -> void:
	if not is_instance_valid(button):
		return
	var tween: Tween = button.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, TRANSITION_SECONDS)
	tween.tween_property(
		button,
		"self_modulate",
		Color(brightness, brightness, brightness, 1.0),
		TRANSITION_SECONDS
	)


static func _apply_focus_and_hover_styles(button: Button) -> void:
	var normal: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
	if normal == null:
		return
	var highlighted: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	highlighted.border_color = normal.border_color.lightened(0.22)
	highlighted.bg_color = normal.bg_color.lightened(0.05)
	button.add_theme_stylebox_override("hover", highlighted)
	button.add_theme_stylebox_override("focus", highlighted)
