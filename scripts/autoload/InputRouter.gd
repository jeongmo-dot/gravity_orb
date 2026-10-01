extends Node

signal swipe(direction: Vector2i)
signal restart_requested
signal debug_cycle_annihilation_rule
signal debug_cycle_spawn_count

enum PointerSource { NONE, MOUSE, TOUCH }

var _locked: bool = false
var _active_source: PointerSource = PointerSource.NONE
var _start_position: Vector2 = Vector2.ZERO
var _started_locked: bool = false


func set_locked(locked: bool) -> void:
	_locked = locked


func is_locked() -> bool:
	return _locked


func _unhandled_input(event: InputEvent) -> void:
	_handle_event(event)


func _handle_event(event: InputEvent) -> void:
	if _handle_keyboard(event):
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)


func _handle_keyboard(event: InputEvent) -> bool:
	if event.is_action_pressed(&"restart", false):
		restart_requested.emit()
		return true
	# TEMP(M6): M9 디버그 패널이 규칙 선택을 대체할 때 제거한다.
	if (
		OS.is_debug_build()
		and event.is_action_pressed(&"debug_cycle_annihilation_rule", false)
	):
		debug_cycle_annihilation_rule.emit()
		return true
	# TEMP(M7): M9 디버그 패널이 생성 수 선택을 대체할 때 제거한다.
	if OS.is_debug_build() and event.is_action_pressed(&"debug_cycle_spawn_count", false):
		debug_cycle_spawn_count.emit()
		return true
	if _locked:
		return false
	if event.is_action_pressed(&"gravity_up", false):
		swipe.emit(Vector2i.UP)
		return true
	if event.is_action_pressed(&"gravity_down", false):
		swipe.emit(Vector2i.DOWN)
		return true
	if event.is_action_pressed(&"gravity_left", false):
		swipe.emit(Vector2i.LEFT)
		return true
	if event.is_action_pressed(&"gravity_right", false):
		swipe.emit(Vector2i.RIGHT)
		return true
	return false


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_begin_pointer_gesture(PointerSource.MOUSE, event.position)
	else:
		_end_pointer_gesture(PointerSource.MOUSE, event.position)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.index != 0:
		return
	if event.pressed:
		_begin_pointer_gesture(PointerSource.TOUCH, event.position)
	else:
		_end_pointer_gesture(PointerSource.TOUCH, event.position)


func _begin_pointer_gesture(source: PointerSource, position: Vector2) -> void:
	if _active_source != PointerSource.NONE:
		return
	_active_source = source
	_start_position = position
	_started_locked = _locked


func _end_pointer_gesture(source: PointerSource, position: Vector2) -> void:
	if _active_source != source:
		return

	var delta: Vector2 = position - _start_position
	var should_ignore: bool = _started_locked or _locked
	_active_source = PointerSource.NONE
	_start_position = Vector2.ZERO
	_started_locked = false
	if should_ignore:
		return

	var direction: Vector2i = SwipeDetector.classify(
		delta,
		Config.data.swipe_min_distance,
		Config.data.swipe_dominance_ratio
	)
	if direction != Vector2i.ZERO:
		swipe.emit(direction)
