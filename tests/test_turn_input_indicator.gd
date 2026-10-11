extends TestCase

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const WAIT_TIMEOUT_SECONDS: float = 5.0

var _turn_ready_sound_count: int = 0


func test_turn_input_cues_rejection_release_policy_and_ready_tick() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_sfx_enabled: bool = Config.data.sfx_enabled
	var original_haptics_enabled: bool = Config.data.haptics_enabled
	Config.data.sfx_enabled = true
	Config.data.haptics_enabled = true
	_turn_ready_sound_count = 0

	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.TURN)
	tree.root.add_child(main)
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var indicator: TurnInputIndicator = main.get_node(
		"UI/Hud/TurnInputIndicator"
	) as TurnInputIndicator
	var feedback: FeedbackDirector = main.get_node("FeedbackDirector") as FeedbackDirector
	feedback.sfx_bank().play_called.connect(_on_sfx_play_called)

	assert_true(await _wait_for_turn_input(manager), "initial settle reaches input")
	await tree.create_timer(TurnInputIndicator.READY_FADE_DURATION + 0.02).timeout
	assert_true(indicator.is_ready_cue(), "WAITING_INPUT shows ready cue")
	assert_near(indicator.arrow_alpha(), 1.0, 0.01, "ready arrows finish 0.2s fade")
	assert_true(not indicator.orbit_visible(), "ready cue hides orbiting light")
	assert_near(indicator.border_alpha(), 1.0, 0.001, "ready border is bright")
	assert_eq(_turn_ready_sound_count, 1, "initial unlock plays one ready tick")
	assert_eq(feedback.haptics().request_count(), 1, "initial unlock requests one haptic")
	assert_eq(
		feedback.haptics().last_duration_ms(),
		Haptics.TURN_READY_DURATION_MS,
		"ready haptic is the short variant"
	)

	var blocked: Array[Vector2i] = [Vector2i.LEFT]
	manager.blocked_directions = blocked.duplicate()
	manager.warning_changed.emit(blocked)
	assert_eq(
		indicator.arrow_color(Vector2i.LEFT),
		TurnInputIndicator.BLOCKED_COLOR,
		"blocked direction arrow is red"
	)
	assert_eq(
		indicator.arrow_color(Vector2i.RIGHT),
		TurnInputIndicator.READY_COLOR,
		"available direction arrow stays sky blue"
	)

	manager.on_swipe(Vector2i.RIGHT)
	await tree.process_frame
	assert_eq(manager.turn_index, 1, "accepted swipe starts exactly one turn")
	assert_true(indicator.is_busy_cue(), "SPAWNING shows busy cue")
	assert_true(indicator.orbit_visible(), "busy cue shows orbiting light")
	assert_near(
		indicator.border_alpha(),
		TurnInputIndicator.BUSY_BORDER_ALPHA,
		0.001,
		"busy border is dimmed to 40 percent"
	)
	await tree.create_timer(TurnInputIndicator.BUSY_FADE_DURATION + 0.02).timeout
	assert_near(indicator.arrow_alpha(), 0.0, 0.01, "busy arrows disappear in 0.1s")
	var orbit_before: float = indicator.orbit_progress()

	InputRouter._handle_event(_mouse_button(Vector2(300.0, 200.0), true))
	InputRouter._handle_event(_mouse_button(Vector2(100.0, 200.0), false))
	assert_eq(manager.turn_index, 1, "locked swipe does not start a turn")
	assert_eq(indicator.rejection_flash_count(), 1, "locked swipe flashes once")
	assert_eq(
		indicator.rejected_direction(),
		Vector2i.LEFT,
		"rejected direction chooses matching arrow"
	)
	await tree.create_timer(0.12).timeout
	assert_true(
		indicator.orbit_progress() > orbit_before,
		"busy light advances along the border"
	)

	InputRouter._handle_event(_mouse_button(Vector2(100.0, 300.0), true))
	assert_true(await _wait_for_turn_input(manager), "first turn settles")
	assert_eq(_turn_ready_sound_count, 2, "first turn unlock adds one ready tick")
	InputRouter._handle_event(_mouse_button(Vector2(300.0, 300.0), false))
	assert_eq(
		manager.turn_index,
		2,
		"gesture begun while locked is accepted once when released unlocked"
	)
	assert_true(await _wait_for_turn_input(manager), "release-accepted turn settles")
	assert_eq(_turn_ready_sound_count, 3, "second turn unlock adds one ready tick")

	(main.get_node("UI") as DebugHud).show_ranking(GameConfig.GameMode.TURN)
	await tree.process_frame
	assert_true(not indicator.is_visible_in_tree(), "ranking hides all turn input cues")
	indicator._on_state_changed(int(TurnManager.State.GAME_OVER))
	assert_true(not indicator.is_ready_cue(), "game over hides ready arrows")
	assert_true(not indicator.orbit_visible(), "game over hides orbiting light")

	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	InputRouter.set_accept_release_after_unlock(false)
	Config.data.game_mode = original_mode
	Config.data.sfx_enabled = original_sfx_enabled
	Config.data.haptics_enabled = original_haptics_enabled


func _on_sfx_play_called(
	kind: String,
	_reaction_usec: int,
	_play_usec: int,
	_reaction_physics_frame: int,
	_play_physics_frame: int,
	_reaction_process_frame: int,
	_play_process_frame: int
) -> void:
	if kind == "turn_ready":
		_turn_ready_sound_count += 1


func _wait_for_turn_input(manager: TurnManager) -> bool:
	var max_frames: int = ceili(WAIT_TIMEOUT_SECONDS * float(Engine.physics_ticks_per_second))
	for _frame_index: int in range(max_frames):
		if manager.state == TurnManager.State.WAITING_INPUT and not InputRouter.is_locked():
			return true
		if manager.state == TurnManager.State.GAME_OVER:
			return false
		await tree.physics_frame
	return false


func _mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event
