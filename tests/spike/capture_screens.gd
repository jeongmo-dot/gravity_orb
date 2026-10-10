extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const ORB_3D_SCENE: PackedScene = preload("res://scenes/Orb3D.tscn")
const OUTPUT_DIRECTORY: String = "res://artifacts/screens"
const MEASUREMENT_DIRECTORY: String = "res://artifacts/measurements"
const DEFAULT_USER_SAVE: String = "user://save.cfg"
const TEMP_SAVE_PREFIX: String = "--capture-save-path="
const CAPTURE_SEED: int = 5050
const TURN_CAPTURE_SCORE: int = 2048
const TURN_CAPTURE_BEST: int = 3764
const BLITZ_CAPTURE_SCORE: int = 18760
const BLITZ_CAPTURE_BEST: int = 18760
const RANKING_CAPTURE_BEST: int = 25000
const TURN_GAME_OVER_DIRECTION: Vector2i = Vector2i.LEFT
const WAIT_TIMEOUT_SECONDS: float = 5.0
const DIRECTION_PATTERN: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.LEFT,
	Vector2i.DOWN,
]
const CAPTURE_FILES: Array[String] = [
	"01_start_screen.png",
	"02_turn_early.png",
	"03_turn_combo.png",
	"04_turn_game_over.png",
	"05_blitz_ready.png",
	"06_blitz_fever_chain.png",
	"07_blitz_danger.png",
	"08_blitz_time_up.png",
	"09_blitz_result.png",
	"10_ranking_blitz.png",
	"11_result_new_record.png",
	"12_turn_ramp_next.png",
	"13_turn_ramp_uncapped_next.png",
	"14_orb_codex.png",
]

var _failed: bool = false
var _temp_save_path: String = "res://artifacts/screens/capture_save.tmp.cfg"
var _user_save_existed: bool = false
var _user_save_bytes: PackedByteArray = PackedByteArray()


func _ready() -> void:
	call_deferred("_run_capture_suite")


func _run_capture_suite() -> void:
	_parse_arguments()
	if _temp_save_path == DEFAULT_USER_SAVE:
		push_error("Capture save path must not be the user save path")
		get_tree().quit(1)
		return
	_snapshot_user_save()
	_prepare_output_directory()
	Config.data.rng_seed = CAPTURE_SEED
	Config.data.fx_hitstop_enabled = false

	await _capture_start_screen()
	if not _failed:
		await _capture_turn_scenes()
	if not _failed:
		await _capture_blitz_scenes()
	if not _failed:
		await _capture_orb_codex()

	_verify_capture_files()
	_verify_user_save_unchanged()
	_remove_file(_temp_save_path)
	get_tree().quit(1 if _failed else 0)


func _capture_start_screen() -> void:
	var main: Main = await _create_main(Main.NO_MODE)
	var blitz_button: Button = main.get_node("UI/StartScreen/Content/BlitzButton") as Button
	if blitz_button.text != "BLITZ\n버티기 타임어택":
		_fail("BLITZ start subtitle mismatch")
	await _capture("01_start_screen.png")
	await _destroy_main(main)


func _capture_turn_scenes() -> void:
	var main: Main = await _create_main(int(GameConfig.GameMode.TURN))
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var spawner: Spawner = main.get_node("Spawner") as Spawner
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	if not await _wait_for_turn_input(manager):
		_fail("TURN did not reach initial input state")
		await _destroy_main(main)
		return
	for turn_index: int in range(4):
		manager.on_swipe(DIRECTION_PATTERN[turn_index])
		if not await _wait_for_turn_input(manager):
			_fail("TURN early scene did not settle after swipe %d" % (turn_index + 1))
			await _destroy_main(main)
			return
	await _capture("02_turn_early.png")

	for turn_index: int in range(4, 12):
		manager.on_swipe(DIRECTION_PATTERN[turn_index % DIRECTION_PATTERN.size()])
		if not await _wait_for_turn_input(manager):
			_fail("TURN combo scene did not settle after swipe %d" % (turn_index + 1))
			await _destroy_main(main)
			return
	manager.set_physics_process(false)
	hud._on_score_changed(TURN_CAPTURE_SCORE, TURN_CAPTURE_BEST)
	hud._on_combo_changed(4, 8.0, 4)
	await get_tree().create_timer(0.30).timeout
	await _capture("03_turn_combo.png")
	Config.data.spawn_count_ramp_turns = 20
	Config.data.spawn_count_max = 0
	manager.turn_index = 20
	spawner.sync_next_batch_size(21)
	await get_tree().process_frame
	_validate_turn_ramp_preview_scene(main, 2, "turn_ramp_next")
	await _capture("12_turn_ramp_next.png")
	manager.turn_index = 100
	spawner.sync_next_batch_size(101)
	await get_tree().process_frame
	_validate_turn_ramp_preview_scene(main, 6, "turn_ramp_uncapped_next")
	await _capture("13_turn_ramp_uncapped_next.png")

	score.score = TURN_CAPTURE_SCORE
	score.best_score = TURN_CAPTURE_BEST
	manager.max_combo = 4
	manager.gravity = TURN_GAME_OVER_DIRECTION
	manager.blocked_directions.clear()
	manager.blocked_directions.append(TURN_GAME_OVER_DIRECTION)
	hud._on_warning_changed(manager.blocked_directions)
	manager.game_over.emit()
	_validate_turn_game_over_scene(main)
	await _capture("04_turn_game_over.png")
	await _destroy_main(main)


func _capture_blitz_scenes() -> void:
	var main: Main = await _create_main(int(GameConfig.GameMode.BLITZ))
	var manager: BlitzManager = main.get_node("BlitzManager") as BlitzManager
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var spawner: Spawner = main.get_node("Spawner") as Spawner
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	var board: Board3D = main.get_node("Board") as Board3D
	await _capture("05_blitz_ready.png")
	if not await _wait_for_blitz_running(manager):
		_fail("BLITZ did not leave READY")
		await _destroy_main(main)
		return
	for swipe_index: int in range(8):
		manager.on_swipe(DIRECTION_PATTERN[swipe_index])
		await _wait_physics_seconds(0.35)
	manager.set_physics_process(false)

	score.score = BLITZ_CAPTURE_SCORE
	score.best_score = BLITZ_CAPTURE_BEST
	hud._on_score_changed(BLITZ_CAPTURE_SCORE, BLITZ_CAPTURE_BEST)
	hud._reset_callout_tracking()
	manager.play_time_elapsed = 120.0
	manager.remaining_time = Config.data.blitz_start_time
	hud._on_time_changed(manager.remaining_time)
	hud._on_time_bonus_awarded(0.1, "MERGE_L3")
	hud._on_time_bonus_awarded(0.2, "MERGE_L4")
	hud._process(Config.data.blitz_time_bonus_display_window)
	hud._on_combo_changed(8, 2.0, 8)
	hud._on_fever_changed(true, 3.0)
	if board.has_method("set_fever_active"):
		board.call("set_fever_active", true)
	await get_tree().create_timer(0.35).timeout
	var level_three: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.PURPLE,
		3,
		Vector2(-240.0, -160.0)
	)
	var level_four: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.CYAN,
		4,
		Vector2(220.0, -140.0)
	)
	var level_six: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.YELLOW,
		6,
		Vector2(0.0, -280.0)
	)
	level_three.disable_physics()
	level_four.disable_physics()
	level_six.disable_physics()
	if level_three.is_blast_armed():
		_fail("BLITZ L3 capture orb must not blink")
	if not level_four.is_blast_armed() or not level_six.is_blast_armed():
		_fail("BLITZ L4 and L6 capture orbs must blink")
	var feedback: FeedbackDirector = main.get_node("FeedbackDirector") as FeedbackDirector
	feedback.play_reaction_visuals({
		"type": ReactionRules.Type.BLAST,
		"position": Vector2(220.0, -140.0),
		"levels": [4, 4],
		"colors": [OrbTypes.OrbColor.PURPLE, OrbTypes.OrbColor.CYAN],
		"shock_level": 4,
	})
	await get_tree().create_timer(0.24).timeout
	_validate_blitz_survival_hud_scene(main)
	print("SCREEN_CAPTURE_CHECK scene=blitz_l4_blast radius_factor=0.3")
	await _capture("06_blitz_fever_chain.png")
	await get_tree().create_timer(0.40).timeout

	hud._hide_bonus_label()
	for popup: ScorePopup in hud.active_score_popups():
		popup.deactivate()
	hud._on_fever_changed(false, 0.0)
	hud._hide_fever_visuals()
	hud._on_combo_changed(3, 1.3, 8)
	spawner.sync_blitz_next_batch_size(8)
	hud._set_danger_badge(0.70, 4.0)
	hud.set_process(false)
	feedback.play_reaction_visuals({
		"type": ReactionRules.Type.BLAST,
		"position": Vector2(0.0, -140.0),
		"levels": [6, 6],
		"colors": [OrbTypes.OrbColor.YELLOW, OrbTypes.OrbColor.CYAN],
		"shock_level": 6,
	})
	await get_tree().create_timer(0.24).timeout
	print("SCREEN_CAPTURE_CHECK scene=blitz_l6_blast radius_factor=1.0")
	await _capture("07_blitz_danger.png")
	await get_tree().create_timer(0.40).timeout

	hud._set_danger_badge(0.0, 1.0)
	hud._on_combo_changed(0, 1.0, 8)
	manager.state = BlitzManager.State.FINALE
	manager.remaining_time = 0.0
	hud._on_time_changed(manager.remaining_time)
	hud._on_finale_started()
	await get_tree().create_timer(0.15).timeout
	_validate_blitz_time_up_scene(main)
	await _capture("08_blitz_time_up.png")

	hud._hide_time_up_label()
	manager.max_combo = 8
	manager.blast_count = 3
	manager.fever_count = 2
	manager.game_over_details["survived_time"] = 125.0
	manager.game_over.emit()
	_validate_blitz_result_scene(main)
	await _capture("09_blitz_result.png")

	var ranking_result: Dictionary = _prepare_blitz_ranking_capture()
	score.best_score = SaveStore.load_best_score(_temp_save_path, GameConfig.GameMode.BLITZ)
	hud._on_score_changed(score.score, score.best_score)
	manager.game_over_details["ranking"] = ranking_result
	manager.game_over.emit()
	var ui: DebugHud = main.get_node("UI") as DebugHud
	ui.show_ranking(GameConfig.GameMode.BLITZ, int(ranking_result["rank"]))
	_validate_blitz_ranking_scene(main)
	await _capture("10_ranking_blitz.png")
	(main.get_node("UI/RankingPanel/Panel/Content/RankingCloseButton") as Button).pressed.emit()
	_validate_new_record_result_scene(main)
	await _capture("11_result_new_record.png")
	await _destroy_main(main)


func _capture_orb_codex() -> void:
	var main: Main = await _create_main(Main.NO_MODE)
	(main.get_node("UI") as CanvasLayer).visible = false
	(main.get_node("Board") as Board3D).visible = false
	var camera: Camera3D = main.get_node("Camera3D") as Camera3D
	camera.position.z = 55.0
	var level_radii: Array[float] = []
	for level: int in range(1, Config.data.orb_max_level + 1):
		level_radii.append(Config.data.radius_for_level(level))
	var total_width: float = 0.0
	for radius: float in level_radii:
		total_width += radius * 2.0
	total_width += float(level_radii.size() - 1) * 20.0
	var level_centers: Array[float] = []
	var cursor: float = -total_width * 0.5
	for radius: float in level_radii:
		level_centers.append(cursor + radius)
		cursor += radius * 2.0 + 20.0
	var descriptors: Array[Dictionary] = []
	for color: int in range(Config.data.color_display.size()):
		var row_y: float = -750.0 + float(color) * 300.0
		for level: int in range(1, Config.data.orb_max_level + 1):
			var orb: Orb3D = ORB_3D_SCENE.instantiate() as Orb3D
			main.add_child(orb)
			orb.setup(color, level, Config.data)
			orb.disable_physics()
			orb.set_render_clamp_enabled(false)
			var plane_position: Vector2 = Vector2(level_centers[level - 1], row_y)
			orb.position = plane_position
			descriptors.append({
				"color": color,
				"level": level,
				"plane_position": plane_position,
				"radius": Config.data.radius_for_level(level),
			})
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("14_orb_codex.png")
	_analyze_orb_codex(camera, descriptors)
	print("SCREEN_CAPTURE_CHECK scene=orb_codex colors=6 levels=7 symbols=on")
	await _destroy_main(main)


func _analyze_orb_codex(camera: Camera3D, descriptors: Array[Dictionary]) -> void:
	var image_path: String = OUTPUT_DIRECTORY.path_join("14_orb_codex.png")
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(image_path))
	if image == null or image.is_empty():
		_fail("Could not load orb codex for color analysis")
		return
	var samples: Dictionary = {}
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var image_scale: Vector2 = Vector2(
		float(image.get_width()) / viewport_size.x,
		float(image.get_height()) / viewport_size.y
	)
	for descriptor: Dictionary in descriptors:
		var plane_position: Vector2 = descriptor["plane_position"] as Vector2
		var radius_px: float = float(descriptor["radius"])
		var world_center: Vector3 = Orb3D.plane_position_to_world(plane_position)
		var world_edge: Vector3 = Orb3D.plane_position_to_world(
			plane_position + Vector2(radius_px, 0.0)
		)
		var screen_center: Vector2 = camera.unproject_position(world_center) * image_scale
		var screen_edge: Vector2 = camera.unproject_position(world_edge) * image_scale
		var screen_radius: float = absf(screen_edge.x - screen_center.x)
		var average: Color = _bright_average(image, screen_center, screen_radius)
		var lab: Vector3 = _color_to_lab(average)
		var reference: Color = Config.data.color_display[int(descriptor["color"])]
		var reference_lab: Vector3 = _color_to_lab(reference)
		var hue_error: float = _hue_angle_difference(lab, reference_lab)
		var key: String = "%d:%d" % [int(descriptor["level"]), int(descriptor["color"])]
		samples[key] = {
			"rgb": [average.r, average.g, average.b],
			"lab": [lab.x, lab.y, lab.z],
			"hue_error_deg": hue_error,
		}
	var reference_min_delta_e: float = INF
	for first_color: int in range(Config.data.color_display.size()):
		for second_color: int in range(first_color + 1, Config.data.color_display.size()):
			reference_min_delta_e = minf(
				reference_min_delta_e,
				_color_to_lab(Config.data.color_display[first_color]).distance_to(
					_color_to_lab(Config.data.color_display[second_color])
				)
			)
	var levels: Array[Dictionary] = []
	for level: int in range(1, Config.data.orb_max_level + 1):
		var minimum_delta_e: float = INF
		var maximum_hue_error: float = 0.0
		var color_samples: Array[Dictionary] = []
		for color: int in range(Config.data.color_display.size()):
			var sample: Dictionary = samples["%d:%d" % [level, color]] as Dictionary
			maximum_hue_error = maxf(maximum_hue_error, float(sample["hue_error_deg"]))
			color_samples.append({
				"color": color,
				"rgb": sample["rgb"],
				"lab": sample["lab"],
				"hue_error_deg": sample["hue_error_deg"],
			})
			var first_lab_values: Array = sample["lab"] as Array
			var first_lab: Vector3 = Vector3(
				float(first_lab_values[0]),
				float(first_lab_values[1]),
				float(first_lab_values[2])
			)
			for second_color: int in range(color + 1, Config.data.color_display.size()):
				var second_sample: Dictionary = samples["%d:%d" % [level, second_color]] as Dictionary
				var second_values: Array = second_sample["lab"] as Array
				var second_lab: Vector3 = Vector3(
					float(second_values[0]),
					float(second_values[1]),
					float(second_values[2])
				)
				minimum_delta_e = minf(minimum_delta_e, first_lab.distance_to(second_lab))
		levels.append({
			"level": level,
			"minimum_delta_e_76": minimum_delta_e,
			"maximum_hue_error_deg": maximum_hue_error,
			"colors": color_samples,
		})
		print(
			"ORB_CODEX_COLOR level=%d min_delta_e=%.2f max_hue_error=%.2f" % [
				level,
				minimum_delta_e,
				maximum_hue_error,
			]
		)
		if minimum_delta_e < 25.0:
			_fail("Orb codex L%d minimum Delta E %.2f is below 25" % [level, minimum_delta_e])
		if maximum_hue_error > 25.0:
			_fail("Orb codex L%d hue error %.2f exceeds 25 degrees" % [level, maximum_hue_error])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MEASUREMENT_DIRECTORY))
	var report_path: String = MEASUREMENT_DIRECTORY.path_join("orb_codex_color_report.json")
	var report_file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if report_file == null:
		_fail("Could not write orb codex color report")
		return
	report_file.store_string(JSON.stringify({
		"bright_pixel_fraction": 0.4,
		"reference_minimum_delta_e_76": reference_min_delta_e,
		"levels": levels,
	}, "  "))
	print("ORB_CODEX_REFERENCE min_delta_e=%.2f report=%s" % [reference_min_delta_e, report_path])


func _bright_average(image: Image, center: Vector2, radius: float) -> Color:
	var colors: Array[Color] = []
	var min_x: int = maxi(0, floori(center.x - radius))
	var max_x: int = mini(image.get_width() - 1, ceili(center.x + radius))
	var min_y: int = maxi(0, floori(center.y - radius))
	var max_y: int = mini(image.get_height() - 1, ceili(center.y + radius))
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			if Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center) <= radius:
				colors.append(image.get_pixel(x, y))
	colors.sort_custom(_is_color_brighter)
	var sample_count: int = maxi(1, ceili(float(colors.size()) * 0.4))
	var sum: Vector3 = Vector3.ZERO
	for index: int in range(sample_count):
		sum += Vector3(colors[index].r, colors[index].g, colors[index].b)
	var average: Vector3 = sum / float(sample_count)
	return Color(average.x, average.y, average.z, 1.0)


func _is_color_brighter(first: Color, second: Color) -> bool:
	return first.get_luminance() > second.get_luminance()


func _color_to_lab(color_value: Color) -> Vector3:
	var red: float = _srgb_to_linear(color_value.r)
	var green: float = _srgb_to_linear(color_value.g)
	var blue: float = _srgb_to_linear(color_value.b)
	var x: float = (red * 0.4124564 + green * 0.3575761 + blue * 0.1804375) / 0.95047
	var y: float = red * 0.2126729 + green * 0.7151522 + blue * 0.0721750
	var z: float = (red * 0.0193339 + green * 0.1191920 + blue * 0.9503041) / 1.08883
	var fx: float = _lab_component(x)
	var fy: float = _lab_component(y)
	var fz: float = _lab_component(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


func _srgb_to_linear(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)


func _lab_component(value: float) -> float:
	return pow(value, 1.0 / 3.0) if value > 0.008856 else 7.787 * value + 16.0 / 116.0


func _hue_angle_difference(first: Vector3, second: Vector3) -> float:
	var first_angle: float = rad_to_deg(atan2(first.z, first.y))
	var second_angle: float = rad_to_deg(atan2(second.z, second.y))
	return absf(wrapf(first_angle - second_angle + 180.0, 0.0, 360.0) - 180.0)


func _prepare_blitz_ranking_capture() -> Dictionary:
	var fixture_scores: Array[int] = [25000, 22000, 16000, 12000]
	for index: int in range(fixture_scores.size()):
		SaveStore.add_ranking(
			_temp_save_path,
			GameConfig.GameMode.BLITZ,
			fixture_scores[index],
			{"max_chain": 14 - index, "blasts": 5 - index, "fevers": 3 - index},
			"2026-10-0%d 1%d:00" % [index + 5, index + 4]
		)
	return SaveStore.add_ranking(
		_temp_save_path,
		GameConfig.GameMode.BLITZ,
		BLITZ_CAPTURE_SCORE,
		{"max_chain": 8, "blasts": 3, "fevers": 2},
		"2026-10-09 18:30"
	)


func _create_main(mode: int) -> Main:
	var main: Main = MAIN_SCENE.instantiate() as Main
	if mode != Main.NO_MODE:
		var game_mode: GameConfig.GameMode = (
			GameConfig.GameMode.BLITZ
			if mode == int(GameConfig.GameMode.BLITZ)
			else GameConfig.GameMode.TURN
		)
		main.launch_immediately(game_mode)
	(main.get_node("ScoreManager") as ScoreManager).save_path = _temp_save_path
	(main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = _temp_save_path
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	return main


func _destroy_main(main: Main) -> void:
	main.queue_free()
	await get_tree().process_frame
	InputRouter.set_locked(false)


func _wait_for_turn_input(manager: TurnManager) -> bool:
	var max_frames: int = ceili(WAIT_TIMEOUT_SECONDS * float(Engine.physics_ticks_per_second))
	for _frame_index: int in range(max_frames):
		if manager.state == TurnManager.State.WAITING_INPUT:
			return true
		if manager.state == TurnManager.State.GAME_OVER:
			return false
		await get_tree().physics_frame
	return false


func _wait_for_blitz_running(manager: BlitzManager) -> bool:
	var max_frames: int = ceili(WAIT_TIMEOUT_SECONDS * float(Engine.physics_ticks_per_second))
	for _frame_index: int in range(max_frames):
		if manager.state == BlitzManager.State.RUNNING:
			return true
		await get_tree().physics_frame
	return false


func _wait_physics_seconds(seconds: float) -> void:
	var frame_count: int = ceili(seconds * float(Engine.physics_ticks_per_second))
	for _frame_index: int in range(frame_count):
		await get_tree().physics_frame


func _capture(file_name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = OUTPUT_DIRECTORY.path_join(file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		_fail("Could not save %s: %s" % [path, error_string(error)])
		return
	print("SCREEN_CAPTURE file=%s size=%dx%d" % [path, image.get_width(), image.get_height()])


func _prepare_output_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	for file_name: String in CAPTURE_FILES:
		_remove_file(OUTPUT_DIRECTORY.path_join(file_name))
	_remove_file(_temp_save_path)


func _verify_capture_files() -> void:
	for file_name: String in CAPTURE_FILES:
		var path: String = OUTPUT_DIRECTORY.path_join(file_name)
		if not FileAccess.file_exists(path):
			_fail("Missing capture %s" % path)


func _validate_turn_game_over_scene(main: Main) -> void:
	var blocked: Label = main.get_node("UI/Hud/BlockedLabel") as Label
	if not blocked.visible:
		_fail("TURN game-over capture must show blocked direction")
	_expect_label_text(blocked, "BLOCKED: LEFT", "TURN HUD blocked direction")
	_expect_label_text(
		main.get_node("UI/Hud/ScoreLabel") as Label,
		"SCORE\n%d" % TURN_CAPTURE_SCORE,
		"TURN HUD score"
	)
	_expect_label_text(
		main.get_node("UI/Hud/GameOverPanel/Margin/Content/GameOverScore") as Label,
		"SCORE  %d" % TURN_CAPTURE_SCORE,
		"TURN result score"
	)
	_expect_label_text(
		main.get_node("UI/Hud/GameOverPanel/Margin/Content/GameOverBlocked") as Label,
		"BLOCKED: LEFT",
		"TURN result blocked direction"
	)
	print("SCREEN_CAPTURE_CHECK scene=turn_game_over score=%d blocked=LEFT" % TURN_CAPTURE_SCORE)


func _validate_turn_ramp_preview_scene(main: Main, batch_size: int, scene_name: String) -> void:
	var next_preview: Node2D = main.get_node("UI/Hud/NextPreview") as Node2D
	var then_preview: Node2D = main.get_node("UI/Hud/ThenPreview") as Node2D
	var next_count: Label = main.get_node("UI/Hud/NextCountLabel") as Label
	var then_count: Label = main.get_node("UI/Hud/ThenCountLabel") as Label
	var visible_count: int = mini(batch_size, Hud.MAX_PREVIEW_COUNT)
	if next_preview.get_child_count() != visible_count:
		_fail("TURN NEXT preview must show %d orbs" % visible_count)
	if then_preview.get_child_count() != visible_count:
		_fail("TURN THEN preview must show %d orbs" % visible_count)
	var expects_count_labels: bool = batch_size > Hud.MAX_PREVIEW_COUNT
	if next_count.visible != expects_count_labels:
		_fail("TURN NEXT count label visibility mismatch")
	if then_count.visible != expects_count_labels:
		_fail("TURN THEN count label visibility mismatch")
	if expects_count_labels:
		_expect_label_text(next_count, "×%d" % batch_size, "TURN NEXT count")
		_expect_label_text(then_count, "×%d" % batch_size, "TURN THEN count")
	print(
		"SCREEN_CAPTURE_CHECK scene=%s batch=%d visible=%d count_labels=%s" % [
			scene_name,
			batch_size,
			visible_count,
			str(expects_count_labels),
		]
	)


func _validate_blitz_time_up_scene(main: Main) -> void:
	_expect_label_text(
		main.get_node("UI/Hud/TimerLabel") as Label,
		"0.0",
		"BLITZ TIME UP timer"
	)
	_expect_label_text(
		main.get_node("UI/Hud/ScoreLabel") as Label,
		"SCORE\n%d" % BLITZ_CAPTURE_SCORE,
		"BLITZ TIME UP HUD score"
	)
	print("SCREEN_CAPTURE_CHECK scene=blitz_time_up timer=0.0 score=%d" % BLITZ_CAPTURE_SCORE)


func _validate_blitz_result_scene(main: Main) -> void:
	_expect_label_text(
		main.get_node("UI/Hud/TimerLabel") as Label,
		"0.0",
		"BLITZ result timer"
	)
	_expect_label_text(
		main.get_node("UI/Hud/ScoreLabel") as Label,
		"SCORE\n%d" % BLITZ_CAPTURE_SCORE,
		"BLITZ result HUD score"
	)
	_expect_label_text(
		main.get_node("UI/Hud/GameOverPanel/Margin/Content/GameOverScore") as Label,
		"SCORE  %d" % BLITZ_CAPTURE_SCORE,
		"BLITZ result panel score"
	)
	_expect_label_text(
		main.get_node("UI/Hud/GameOverPanel/Margin/Content/GameOverBest") as Label,
		"BEST  %d" % BLITZ_CAPTURE_BEST,
		"BLITZ result panel best"
	)
	_expect_label_text(
		main.get_node("UI/Hud/GameOverPanel/Margin/Content/SurvivedTimeLabel") as Label,
		"버틴 시간 2:05",
		"BLITZ survived time"
	)
	print("SCREEN_CAPTURE_CHECK scene=blitz_result timer=0.0 score=%d" % BLITZ_CAPTURE_SCORE)


func _validate_blitz_survival_hud_scene(main: Main) -> void:
	_expect_label_text(
		main.get_node("UI/Hud/TimerLabel") as Label,
		"30.0",
		"BLITZ survival start clock"
	)
	_expect_label_text(
		main.get_node("UI/Hud/BonusLabel") as Label,
		"+0.3s",
		"BLITZ aggregated time bonus"
	)
	_expect_label_text(
		main.get_node("UI/Hud/DrainRateLabel") as Label,
		"×1.2",
		"BLITZ drain multiplier"
	)
	print("SCREEN_CAPTURE_CHECK scene=blitz_survival_hud bonus=+0.3s drain=1.2")


func _validate_blitz_ranking_scene(main: Main) -> void:
	var ranking: RankingPanel = main.get_node("UI/RankingPanel") as RankingPanel
	if not ranking.visible:
		_fail("BLITZ ranking capture must show ranking panel")
	if ranking.current_mode() != GameConfig.GameMode.BLITZ:
		_fail("BLITZ ranking capture must open BLITZ tab")
	if ranking.highlighted_rank() != 3:
		_fail("BLITZ ranking capture must highlight rank 3")
	var first_row: Label = main.get_node(
		"UI/RankingPanel/Panel/Content/Rows/RankingRow1/Text/Columns/Score"
	) as Label
	var third_row: Label = main.get_node(
		"UI/RankingPanel/Panel/Content/Rows/RankingRow3/Text/Columns/Score"
	) as Label
	if not first_row.text.contains("25,000"):
		_fail("BLITZ ranking first row must show 25,000")
	if not third_row.text.contains("18,760"):
		_fail("BLITZ ranking highlighted row must show 18,760")
	print("SCREEN_CAPTURE_CHECK scene=ranking_blitz rank=3 score=%d" % BLITZ_CAPTURE_SCORE)


func _validate_new_record_result_scene(main: Main) -> void:
	var content_path: String = "UI/Hud/GameOverPanel/Margin/Content/"
	_expect_label_text(
		main.get_node(content_path + "RankingResultLabel") as Label,
		"새 기록! 3위",
		"BLITZ result ranking message"
	)
	_expect_label_text(
		main.get_node(content_path + "GameOverBest") as Label,
		"BEST  %d" % RANKING_CAPTURE_BEST,
		"BLITZ ranked result BEST"
	)
	for button_name: String in ["RestartButton", "ResultRankingButton", "ModeSelectButton"]:
		var button: Button = main.get_node(content_path + button_name) as Button
		if not button.visible or button.size.y < 120.0:
			_fail("BLITZ result button %s must be visible and at least 120px" % button_name)
	print("SCREEN_CAPTURE_CHECK scene=result_new_record rank=3 buttons=3")


func _expect_label_text(label: Label, expected: String, description: String) -> void:
	if label.text != expected:
		_fail("%s expected '%s', got '%s'" % [description, expected, label.text])


func _snapshot_user_save() -> void:
	_user_save_existed = FileAccess.file_exists(DEFAULT_USER_SAVE)
	if _user_save_existed:
		_user_save_bytes = FileAccess.get_file_as_bytes(DEFAULT_USER_SAVE)


func _verify_user_save_unchanged() -> void:
	var exists_after: bool = FileAccess.file_exists(DEFAULT_USER_SAVE)
	if exists_after != _user_save_existed:
		_fail("Capture tool changed user save existence")
		return
	if exists_after and FileAccess.get_file_as_bytes(DEFAULT_USER_SAVE) != _user_save_bytes:
		_fail("Capture tool changed user save contents")


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(TEMP_SAVE_PREFIX):
			_temp_save_path = argument.trim_prefix(TEMP_SAVE_PREFIX)


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
