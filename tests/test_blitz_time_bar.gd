extends TestCase

const TOLERANCE: float = 0.0001


func test_layer_count_fill_and_color_at_required_boundaries() -> void:
	var bar: BlitzTimeBar = BlitzTimeBar.new()
	bar.size = Vector2(450.0, 18.0)
	var cases: Array[Dictionary] = [
		{"time": 0.0, "layers": 1, "fill": 0.0},
		{"time": 44.9, "layers": 1, "fill": 44.9 / 45.0},
		{"time": 45.0, "layers": 1, "fill": 1.0},
		{"time": 45.1, "layers": 2, "fill": 0.1 / 45.0},
		{"time": 90.0, "layers": 2, "fill": 1.0},
		{"time": 128.4, "layers": 3, "fill": 38.4 / 45.0},
	]
	for test_case: Dictionary in cases:
		bar.set_time(float(test_case["time"]), 45.0)
		assert_eq(
			bar.layer_count(),
			int(test_case["layers"]),
			"layer count at %.1f seconds" % float(test_case["time"])
		)
		assert_near(
			bar.layer_fill_ratio(),
			float(test_case["fill"]),
			TOLERANCE,
			"layer fill at %.1f seconds" % float(test_case["time"])
		)
	bar.set_time(9.9, 45.0)
	assert_eq(bar.layer_color(), BlitzTimeBar.DANGER_COLOR, "last ten seconds stay red")
	bar.set_time(45.1, 45.0)
	assert_eq(bar.layer_color(), Color("#22C7D9"), "second layer is cyan")
	bar.set_time(90.1, 45.0)
	assert_eq(bar.layer_color(), Color("#A35CF0"), "third layer is purple")
	bar.queue_free()


func test_bonus_segment_position_width_aggregation_boundary_and_fever() -> void:
	var bar: BlitzTimeBar = BlitzTimeBar.new()
	bar.size = Vector2(450.0, 18.0)
	bar.set_time(21.6, 45.0)
	bar.show_bonus(20.0, 21.6, false)
	var pieces: Array[Rect2] = bar.bonus_piece_rects()
	assert_eq(pieces.size(), 1, "single-layer bonus has one piece")
	assert_near(pieces[0].position.x, 200.0, TOLERANCE, "bonus starts at old fill")
	assert_near(pieces[0].size.x, 16.0, TOLERANCE, "bonus width matches seconds")
	bar.show_bonus(20.0, 22.0, false)
	pieces = bar.bonus_piece_rects()
	assert_near(pieces[0].size.x, 20.0, TOLERANCE, "aggregated bonus grows one piece")
	bar.clear_bonus()
	bar.show_bonus(44.0, 46.0, false)
	pieces = bar.bonus_piece_rects()
	assert_eq(pieces.size(), 2, "boundary-crossing bonus splits into two pieces")
	assert_near(pieces[0].position.x, 440.0, TOLERANCE, "lower piece ends at layer edge")
	assert_near(pieces[1].position.x, 0.0, TOLERANCE, "upper piece starts at left edge")
	bar.clear_bonus()
	bar.show_bonus(20.0, 20.05, true)
	pieces = bar.bonus_piece_rects()
	assert_near(pieces[0].size.x, 6.0, TOLERANCE, "tiny bonus keeps six-pixel width")
	assert_true(bar.bonus_is_fever(), "fever segment keeps amber-glow state")
	bar.advance_bonus(0.36)
	assert_true(bar.bonus_alpha() < 1.0, "bonus fades after hold")
	bar.advance_bonus(0.30)
	assert_true(not bar.bonus_is_active(), "bonus finishes after fade")
	bar.show_bonus(21.0, 21.2, false)
	assert_true(not bar.bonus_is_fever(), "new segment clears expired fever tint")
	bar.queue_free()


func test_large_timer_text_uses_measured_width_and_layer_count_replaces_speed() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_ready: float = Config.data.blitz_ready_time
	Config.data.game_mode = GameConfig.GameMode.BLITZ
	Config.data.blitz_ready_time = 0.0
	var main: Main = preload("res://scenes/Main3D.tscn").instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.BLITZ)
	main.get_node("ScoreManager").set("save_path", "")
	tree.root.add_child(main)
	await tree.process_frame
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var timer: Label = main.get_node("UI/Hud/TimerLabel") as Label
	var layer_label: Label = main.get_node("UI/Hud/DrainRateLabel") as Label
	for remaining: float in [128.4, 999.9, 1234.5]:
		hud._on_time_changed(remaining)
		var font: Font = timer.get_theme_font("font")
		var text_width: float = font.get_string_size(
			timer.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			timer.get_theme_font_size("font_size")
		).x
		assert_true(
			timer.size.x >= text_width + 16.0,
			"%.1f timer has measured padding" % remaining
		)
	assert_true(layer_label.visible, "large time shows a layer count")
	assert_eq(layer_label.text, "×28", "layer count is unlimited")
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.game_mode = original_mode
	Config.data.blitz_ready_time = original_ready
