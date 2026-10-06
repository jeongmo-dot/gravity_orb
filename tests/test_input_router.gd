extends TestCase

const INPUT_ROUTER_SCRIPT: Script = preload("res://scripts/autoload/InputRouter.gd")

var _received: Array[Vector2i] = []
var _debug_cycles: int = 0
var _spawn_count_cycles: int = 0
var _mode_toggles: int = 0
var _restart_requests: int = 0
var _sfx_mute_toggles: int = 0


func test_mouse_left_drag_emits_once() -> void:
	var router: Variant = _new_router()
	router._handle_event(_mouse_button(Vector2(100.0, 100.0), MOUSE_BUTTON_LEFT, true))
	router._handle_event(_mouse_button(Vector2(300.0, 110.0), MOUSE_BUTTON_LEFT, false))
	_assert_swipes([Vector2i.RIGHT])
	router.free()


func test_touch_zero_drag_emits_once() -> void:
	var router: Variant = _new_router()
	router._handle_event(_touch(Vector2(200.0, 300.0), 0, true))
	router._handle_event(_touch(Vector2(200.0, 100.0), 0, false))
	_assert_swipes([Vector2i.UP])
	router.free()


func test_emulated_touch_duplicate_emits_once() -> void:
	var router: Variant = _new_router()
	var start: Vector2 = Vector2(300.0, 200.0)
	var finish: Vector2 = Vector2(300.0, 400.0)
	router._handle_event(_mouse_button(start, MOUSE_BUTTON_LEFT, true))
	router._handle_event(_touch(start, 0, true))
	router._handle_event(_mouse_button(finish, MOUSE_BUTTON_LEFT, false))
	router._handle_event(_touch(finish, 0, false))
	_assert_swipes([Vector2i.DOWN])
	router.free()


func test_touch_nonzero_index_is_ignored() -> void:
	var router: Variant = _new_router()
	router._handle_event(_touch(Vector2(100.0, 100.0), 1, true))
	router._handle_event(_touch(Vector2(300.0, 100.0), 1, false))
	_assert_swipes([])
	router.free()


func test_right_mouse_button_is_ignored() -> void:
	var router: Variant = _new_router()
	router._handle_event(_mouse_button(Vector2(100.0, 100.0), MOUSE_BUTTON_RIGHT, true))
	router._handle_event(_mouse_button(Vector2(300.0, 100.0), MOUSE_BUTTON_RIGHT, false))
	_assert_swipes([])
	router.free()


func test_short_drag_is_ignored() -> void:
	var router: Variant = _new_router()
	router._handle_event(_mouse_button(Vector2(100.0, 100.0), MOUSE_BUTTON_LEFT, true))
	router._handle_event(_mouse_button(Vector2(130.0, 100.0), MOUSE_BUTTON_LEFT, false))
	_assert_swipes([])
	router.free()


func test_locked_drag_is_ignored() -> void:
	var router: Variant = _new_router()
	router.set_locked(true)
	router._handle_event(_mouse_button(Vector2(100.0, 100.0), MOUSE_BUTTON_LEFT, true))
	router._handle_event(_mouse_button(Vector2(300.0, 100.0), MOUSE_BUTTON_LEFT, false))
	_assert_swipes([])
	router.free()


func test_drag_started_locked_stays_ignored_after_unlock() -> void:
	var router: Variant = _new_router()
	router.set_locked(true)
	router._handle_event(_mouse_button(Vector2(100.0, 100.0), MOUSE_BUTTON_LEFT, true))
	router.set_locked(false)
	router._handle_event(_mouse_button(Vector2(300.0, 100.0), MOUSE_BUTTON_LEFT, false))
	_assert_swipes([])
	router.free()


func test_keyboard_action_emits_once_and_echo_is_ignored() -> void:
	var router: Variant = _new_router()
	router._handle_event(_key(KEY_A, true, false))
	_assert_swipes([Vector2i.LEFT])

	_received.clear()
	router._handle_event(_key(KEY_A, true, true))
	_assert_swipes([])
	router.free()


func test_arrow_and_wasd_bindings_map_to_four_directions() -> void:
	var router: Variant = _new_router()
	router._handle_event(_logical_key(KEY_UP))
	router._handle_event(_key(KEY_W, true, false))
	router._handle_event(_logical_key(KEY_DOWN))
	router._handle_event(_key(KEY_S, true, false))
	router._handle_event(_logical_key(KEY_LEFT))
	router._handle_event(_key(KEY_A, true, false))
	router._handle_event(_logical_key(KEY_RIGHT))
	router._handle_event(_key(KEY_D, true, false))
	_assert_swipes(
		[
			Vector2i.UP,
			Vector2i.UP,
			Vector2i.DOWN,
			Vector2i.DOWN,
			Vector2i.LEFT,
			Vector2i.LEFT,
			Vector2i.RIGHT,
			Vector2i.RIGHT,
		]
	)
	router.free()


func test_locked_keyboard_action_is_ignored() -> void:
	var router: Variant = _new_router()
	router.set_locked(true)
	assert_true(router.is_locked(), "router reports locked state")
	router._handle_event(_key(KEY_A, true, false))
	_assert_swipes([])
	router.free()


func test_f2_debug_action_emits_even_while_locked() -> void:
	var router: Variant = _new_router()
	router.set_locked(true)
	router._handle_event(_logical_key(KEY_F2))
	assert_eq(_debug_cycles, 1, "debug cycle signal count")
	router.free()


func test_f3_spawn_count_action_emits_even_while_locked() -> void:
	var router: Variant = _new_router()
	router.set_locked(true)
	router._handle_event(_logical_key(KEY_F3))
	assert_eq(_spawn_count_cycles, 1, "spawn count cycle signal count")
	router.free()


func test_f4_game_mode_action_emits_even_while_locked() -> void:
	var router: Variant = _new_router()
	router.set_locked(true)
	router._handle_event(_logical_key(KEY_F4))
	assert_eq(_mode_toggles, 1, "game mode toggle signal count")
	router.free()


func test_restart_action_emits_even_while_locked() -> void:
	var router: Variant = _new_router()
	router.set_locked(true)
	router._handle_event(_key(KEY_R, true, false))
	assert_eq(_restart_requests, 1, "restart request signal count")
	router.free()


func test_m_sfx_mute_action_emits_even_while_locked() -> void:
	var router: Variant = _new_router()
	router.set_locked(true)
	router._handle_event(_key(KEY_M, true, false))
	assert_eq(_sfx_mute_toggles, 1, "SFX mute toggle signal count")
	router.free()


func _new_router() -> Variant:
	_received.clear()
	_debug_cycles = 0
	_spawn_count_cycles = 0
	_mode_toggles = 0
	_restart_requests = 0
	_sfx_mute_toggles = 0
	var router: Variant = INPUT_ROUTER_SCRIPT.new()
	router.swipe.connect(_record_swipe)
	router.restart_requested.connect(_record_restart_request)
	router.debug_cycle_annihilation_rule.connect(_record_debug_cycle)
	router.debug_cycle_spawn_count.connect(_record_spawn_count_cycle)
	router.debug_toggle_game_mode.connect(_record_mode_toggle)
	router.debug_toggle_sfx_mute.connect(_record_sfx_mute_toggle)
	return router


func _record_swipe(direction: Vector2i) -> void:
	_received.append(direction)


func _record_debug_cycle() -> void:
	_debug_cycles += 1


func _record_spawn_count_cycle() -> void:
	_spawn_count_cycles += 1


func _record_mode_toggle() -> void:
	_mode_toggles += 1


func _record_restart_request() -> void:
	_restart_requests += 1


func _record_sfx_mute_toggle() -> void:
	_sfx_mute_toggles += 1


func _assert_swipes(expected: Array[Vector2i]) -> void:
	assert_eq(_received.size(), expected.size(), "signal count")
	if _received.size() == expected.size():
		for index: int in range(expected.size()):
			assert_eq(_received[index], expected[index], "signal direction %d" % index)


func _mouse_button(
	position: Vector2,
	button_index: MouseButton,
	pressed: bool
) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = position
	event.button_index = button_index
	event.pressed = pressed
	return event


func _touch(position: Vector2, index: int, pressed: bool) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.position = position
	event.index = index
	event.pressed = pressed
	return event


func _key(physical_keycode: Key, pressed: bool, echo: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical_keycode
	event.pressed = pressed
	event.echo = echo
	return event


func _logical_key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event
