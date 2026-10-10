extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const OUTPUT_DIRECTORY: String = "res://artifacts/screens"
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
	Config.data.spawn_count_ramp_turns = 100
	Config.data.spawn_count_max = 3
	manager.turn_index = 100
	spawner.sync_next_batch_size(101)
	await get_tree().process_frame
	_validate_turn_ramp_preview_scene(main, 2, "turn_ramp_next")
	await _capture("12_turn_ramp_next.png")
	Config.data.spawn_count_ramp_turns = 50
	Config.data.spawn_count_max = 0
	manager.turn_index = 250
	spawner.sync_next_batch_size(251)
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
	var board: Variant = main.get_node("Board")
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
	_validate_blitz_survival_hud_scene(main)
	await _capture("06_blitz_fever_chain.png")

	hud._hide_bonus_label()
	for popup: ScorePopup in hud.active_score_popups():
		popup.deactivate()
	hud._on_fever_changed(false, 0.0)
	hud._hide_fever_visuals()
	hud._on_combo_changed(3, 1.3, 8)
	spawner.sync_blitz_next_batch_size(8)
	hud._set_danger_badge(0.70, 4.0)
	hud.set_process(false)
	await _capture("07_blitz_danger.png")

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
