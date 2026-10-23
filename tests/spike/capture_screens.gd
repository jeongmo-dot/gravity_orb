extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const SLIME_MAIN_SCENE: PackedScene = preload("res://scenes/SlimeMain.tscn")
const ORB_3D_SCENE: PackedScene = preload("res://scenes/Orb3D.tscn")
const DEFAULT_OUTPUT_DIRECTORY: String = "res://artifacts/screens"
const MEASUREMENT_DIRECTORY: String = "res://artifacts/measurements"
const DEFAULT_USER_SAVE: String = "user://save.cfg"
const TEMP_SAVE_PREFIX: String = "--capture-save-path="
const OUTPUT_DIRECTORY_PREFIX: String = "--capture-output-directory="
const HUD_SCENES_ONLY_ARGUMENT: String = "--capture-hud-scenes-only"
const CAPTURE_SEED: int = 5050
const TURN_CAPTURE_SCORE: int = 9_999_999
const TURN_CAPTURE_BEST: int = 9_999_999
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
	"15_orb_closeup.png",
	"16_gravity_switch.png",
	"17_board_danger.png",
	"18_board_blocked.png",
	"19_settings.png",
	"20_start_no_record.png",
	"21_start_screen_t2_5.png",
	"22_start_screen_t5_0.png",
	"23_merge_stardust_a.png",
	"23_merge_stardust_b.png",
	"24_birth_l6_a.png",
	"24_birth_l6_b.png",
	"25_birth_l7_a.png",
	"25_birth_l7_b.png",
	"26_blast_l4_a.png",
	"26_blast_l4_b.png",
	"27_blast_l6_a.png",
	"27_blast_l6_b.png",
	"28_blast_l5_crowded_a.png",
	"28_blast_l5_crowded_b.png",
	"29_blast_l6_crowded_a.png",
	"29_blast_l6_crowded_b.png",
	"30_callout_great_a.png",
	"30_callout_great_b.png",
	"31_callout_unstoppable_a.png",
	"31_callout_unstoppable_b.png",
	"32_popup_merge.png",
	"33_popup_blast_big.png",
	"34_color_push_a.png",
	"34_color_push_b.png",
	"35_color_pull_a.png",
	"35_color_pull_b.png",
	"36_color_shake_a.png",
	"36_color_shake_b.png",
	"37_color_lift_a.png",
	"37_color_lift_b.png",
	"38_fever_start_a.png",
	"38_fever_start_b.png",
	"39_fever_running.png",
	"40_blitz_timer_long.png",
	"41_blitz_bonus_gauge_a.png",
	"41_blitz_bonus_gauge_b.png",
	"42_blitz_bonus_layer_cross.png",
	"43_blitz_bonus_fever.png",
	"44_turn_ready.png",
	"45_turn_busy_a.png",
	"45_turn_busy_b.png",
	"46_turn_rejected.png",
	"47_mars_rotations.png",
	"48_slime_core.png",
	"49_slime_states.png",
	"50_slime_shell_start.png",
	"50_slime_shell_ranking.png",
	"50_slime_shell_result.png",
	"50_slime_shell_play_ready.png",
	"50_slime_shell_play_final_move.png",
	"50_slime_shell_play_busy.png",
	"50_slime_shell_play_rejected.png",
	"51_slime_max_growth.png",
	"52_new_planet_callout.png",
	"52_jelly_final_move.png",
	"53_jelly_blast_j5.png",
	"53_jelly_look_levels.png",
	"53_jelly_look_crowded.png",
	"53_jelly_look_absorption.png",
	"53_jelly_look_max.png",
	"53_jelly_look_stretch.png",
	"53_jelly_look_unlock.png",
	"54_jelly_shell_start.png",
	"54_jelly_shell_ranking.png",
	"54_jelly_shell_result.png",
]
const HUD_CAPTURE_FILES: Array[String] = [
	"02_turn_early.png",
	"03_turn_combo.png",
	"06_blitz_fever_chain.png",
	"07_blitz_danger.png",
	"12_turn_ramp_next.png",
	"13_turn_ramp_uncapped_next.png",
	"17_board_danger.png",
	"18_board_blocked.png",
	"40_blitz_timer_long.png",
	"41_blitz_bonus_gauge_a.png",
	"41_blitz_bonus_gauge_b.png",
	"42_blitz_bonus_layer_cross.png",
	"43_blitz_bonus_fever.png",
	"44_turn_ready.png",
	"45_turn_busy_a.png",
	"45_turn_busy_b.png",
	"46_turn_rejected.png",
	"52_new_planet_callout.png",
	"52_jelly_final_move.png",
	"53_jelly_blast_j5.png",
	"53_jelly_look_levels.png",
	"53_jelly_look_crowded.png",
	"53_jelly_look_absorption.png",
	"53_jelly_look_max.png",
	"53_jelly_look_stretch.png",
	"53_jelly_look_unlock.png",
]

var _failed: bool = false
var _output_directory: String = DEFAULT_OUTPUT_DIRECTORY
var _temp_save_path: String = "res://artifacts/screens/capture_save.tmp.cfg"
var _hud_scenes_only: bool = false
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
	CelestialOrbArt.freeze_animation_for_capture()
	JellyOrbArt.freeze_animation_for_capture()

	if not _hud_scenes_only:
		await _capture_start_screen()
	if not _failed:
		await _capture_turn_scenes()
	if not _failed:
		await _capture_blitz_scenes()
	if not _failed and not _hud_scenes_only:
		await _capture_orb_codex()
	if not _failed and not _hud_scenes_only:
		await _capture_orb_closeup()
	if not _failed and not _hud_scenes_only:
		await _capture_mars_rotations()
	if not _failed and not _hud_scenes_only:
		await _capture_slime_core()
	if not _failed and not _hud_scenes_only:
		await _capture_slime_states()
	if not _failed and not _hud_scenes_only:
		await _capture_slime_shell()
	if not _failed and not _hud_scenes_only:
		await _capture_jelly_shell()
	if not _failed and not _hud_scenes_only:
		await _capture_slime_shell_play()
	if not _failed and not _hud_scenes_only:
		await _capture_slime_max_growth()
	if not _failed and not _hud_scenes_only:
		await _capture_reaction_effect_scenes()
	if not _failed and not _hud_scenes_only:
		await _capture_v4_2_scenes()
	if not _failed and not _hud_scenes_only:
		await _measure_v2_contrast()
	if not _failed and not _hud_scenes_only:
		await _measure_gravity_wall_lights()

	_verify_capture_files()
	_verify_user_save_unchanged()
	_remove_file(_temp_save_path)
	CelestialOrbArt.unfreeze_animation()
	JellyOrbArt.unfreeze_animation()
	get_tree().quit(1 if _failed else 0)


func _capture_start_screen() -> void:
	var main: Main = await _create_main(Main.NO_MODE)
	var blitz_name: Label = main.get_node("UI/StartScreen/Content/BlitzNameLabel") as Label
	var blitz_description: Label = main.get_node(
		"UI/StartScreen/Content/BlitzDescriptionLabel"
	) as Label
	if blitz_name.text != "BLITZ" or blitz_description.text != "시간 버티기":
		_fail("BLITZ start subtitle mismatch")
	var no_record_label: Label = main.get_node(
		"UI/StartScreen/Content/BlitzBestLabel"
	) as Label
	_expect_label_text(no_record_label, "BEST —", "BLITZ no-record start label")
	await _capture("20_start_no_record.png")
	(main.get_node("UI") as DebugHud).show_settings()
	await get_tree().create_timer(0.30).timeout
	await _capture("19_settings.png")
	(main.get_node("UI/SettingsPanel/SettingsPanelBody/Margin/Content/SettingsCloseButton") as Button).pressed.emit()
	await get_tree().create_timer(0.30).timeout
	await _destroy_main(main)
	SaveStore.save_best_score(_temp_save_path, GameConfig.GameMode.TURN, 1234)
	SaveStore.save_best_score(_temp_save_path, GameConfig.GameMode.BLITZ, 6789)
	SaveStore.save_last_mode(_temp_save_path, GameConfig.GameMode.BLITZ)
	main = await _create_main(Main.NO_MODE)
	await _capture("01_start_screen.png")
	await get_tree().create_timer(2.5).timeout
	await _capture("21_start_screen_t2_5.png")
	await get_tree().create_timer(2.5).timeout
	await _capture("22_start_screen_t5_0.png")
	await _destroy_main(main)
	_remove_file(_temp_save_path)


func _capture_turn_scenes() -> void:
	var main: Main = await _create_main(int(GameConfig.GameMode.TURN))
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var spawner: Spawner = main.get_node("Spawner") as Spawner
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	var board: Board3D = main.get_node("Board") as Board3D
	if not await _wait_for_turn_input(manager):
		_fail("TURN did not reach initial input state")
		await _destroy_main(main)
		return
	await _write_board_projection_report(main, board)
	await _write_turn_input_cue_report(main)
	var ready_blocked: Array[Vector2i] = [Vector2i.LEFT]
	manager.blocked_directions = ready_blocked.duplicate()
	manager.warning_changed.emit(ready_blocked)
	board.set_warning_directions(ready_blocked)
	await get_tree().create_timer(TurnInputIndicator.READY_FADE_DURATION + 0.02).timeout
	await _capture("44_turn_ready.png")
	manager.on_swipe(Vector2i.RIGHT)
	manager.set_physics_process(false)
	manager._set_state(TurnManager.State.SIMULATING)
	manager.settle_elapsed = 0.5
	await get_tree().create_timer(TurnInputIndicator.BUSY_FADE_DURATION + 0.02).timeout
	await _capture("45_turn_busy_a.png")
	manager.settle_elapsed = 1.0
	await get_tree().process_frame
	await _capture("45_turn_busy_b.png")
	InputRouter.swipe_rejected.emit(Vector2i.LEFT)
	await get_tree().create_timer(0.04).timeout
	await _capture("46_turn_rejected.png")
	manager._set_state(TurnManager.State.SPAWNING)
	manager.settle_elapsed = 0.0
	manager.set_physics_process(true)
	if not await _wait_for_turn_input(manager):
		_fail("TURN cue capture did not settle")
		await _destroy_main(main)
		return
	var no_blocked: Array[Vector2i] = []
	manager.blocked_directions.clear()
	manager.warning_changed.emit(no_blocked)
	board.set_warning_directions(no_blocked)
	for turn_index: int in range(4):
		manager.on_swipe(DIRECTION_PATTERN[turn_index])
		if not await _wait_for_turn_input(manager):
			_fail("TURN early scene did not settle after swipe %d" % (turn_index + 1))
			await _destroy_main(main)
			return
	await _capture("02_turn_early.png")
	var capture_turn_index: int = manager.turn_index
	var capture_gravity: Vector2i = manager.gravity
	var capture_orbs_before: Array = board.get_orbs()
	manager.turn_index = 29
	spawner.sync_next_batch_size(30)
	var capture_batch: Array = spawner._preview_batches[0]
	var capture_candidate: Dictionary = capture_batch[0] as Dictionary
	capture_candidate["color"] = OrbTypes.OrbColor.PURPLE
	hud._on_preview_changed([
		[{"color": OrbTypes.OrbColor.PURPLE, "level": 1}],
		[{"color": OrbTypes.OrbColor.BLUE, "level": 1}],
	])
	manager.set_physics_process(false)
	manager.on_swipe(Vector2i.RIGHT)
	manager._physics_process(0.0)
	await get_tree().create_timer(0.08).timeout
	await _capture("52_new_planet_callout.png")
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._hide_callout_label()
	for orb: Variant in board.get_orbs():
		if not capture_orbs_before.has(orb):
			board.remove_orb(orb as Orb3D)
	await get_tree().process_frame
	manager.turn_index = capture_turn_index
	manager.gravity = capture_gravity
	board.set_gravity(capture_gravity)
	manager._set_state(TurnManager.State.WAITING_INPUT)
	InputRouter.set_locked(false)
	manager.set_physics_process(true)
	manager.on_swipe(Vector2i.RIGHT)
	await get_tree().create_timer(0.12).timeout
	if not _hud_scenes_only:
		await _capture("16_gravity_switch.png")
	if not await _wait_for_turn_input(manager):
		_fail("TURN gravity-switch scene did not settle")
		await _destroy_main(main)
		return

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
	hud.set_process(false)
	hud._set_danger_badge(0.70, 4.0)
	await get_tree().create_timer(0.625).timeout
	await _capture("17_board_danger.png")
	hud._set_danger_badge(0.0, 1.0)
	manager.blocked_directions.clear()
	manager.blocked_directions.append(Vector2i.DOWN)
	manager.warning_changed.emit(manager.blocked_directions)
	board.set_warning_directions(manager.blocked_directions)
	await get_tree().create_timer(0.20).timeout
	_validate_turn_blocked_scene(main)
	await _capture("18_board_blocked.png")
	_validate_turn_blocked_pixels(main)
	Config.data.game_mode = GameConfig.GameMode.JELLY
	manager.final_move_pending = true
	manager.final_move_changed.emit(true, TurnManager.FINAL_MOVE_MESSAGE)
	await get_tree().create_timer(0.20).timeout
	if not hud._jelly_final_move_banner.visible:
		_fail("JELLY FINAL MOVE banner must be visible")
	if hud._jelly_final_move_banner.message != TurnManager.FINAL_MOVE_MESSAGE:
		_fail("JELLY FINAL MOVE message mismatch")
	await _capture("52_jelly_final_move.png")
	print("SCREEN_CAPTURE_CHECK scene=jelly_final_move band=visible message=exact")
	manager.final_move_pending = false
	manager.final_move_changed.emit(false, "")
	Config.data.jelly_blast_min_level = 5
	var jelly_level_four: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		4,
		Vector2(-150.0, -250.0)
	)
	var jelly_level_five: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		5,
		Vector2(150.0, -250.0)
	)
	jelly_level_four.disable_physics()
	jelly_level_five.disable_physics()
	if jelly_level_four.is_blast_armed():
		_fail("J5 capture L4 must not show BLAST pulse")
	if not jelly_level_five.is_blast_armed():
		_fail("J5 capture L5 must show BLAST pulse")
	await get_tree().create_timer(0.10).timeout
	await _capture("53_jelly_blast_j5.png")
	print("SCREEN_CAPTURE_CHECK scene=jelly_blast_j5 l4=unarmed l5=armed")
	board.remove_orb(jelly_level_four)
	board.remove_orb(jelly_level_five)
	await _capture_jelly_look(main, board)
	Config.data.jelly_blast_min_level = 5
	Config.data.game_mode = GameConfig.GameMode.TURN
	manager.blocked_directions.clear()
	hud._on_warning_changed(manager.blocked_directions)
	board.set_warning_directions(manager.blocked_directions)
	Config.data.spawn_count_ramp_turns = 20
	Config.data.spawn_count_max = 0
	manager.turn_index = 20
	spawner.sync_next_batch_size(21)
	_force_l1_preview(spawner)
	await get_tree().process_frame
	_validate_turn_ramp_preview_scene(main, 2, "turn_ramp_next")
	await _capture("12_turn_ramp_next.png")
	manager.turn_index = 100
	spawner.sync_next_batch_size(101)
	_force_l1_preview(spawner)
	await get_tree().process_frame
	_validate_turn_ramp_preview_scene(main, 6, "turn_ramp_uncapped_next")
	await _capture("13_turn_ramp_uncapped_next.png")
	if _hud_scenes_only:
		await _destroy_main(main)
		return

	score.score = TURN_CAPTURE_SCORE
	score.best_score = TURN_CAPTURE_BEST
	manager.max_combo = 4
	manager.gravity = TURN_GAME_OVER_DIRECTION
	manager.blocked_directions.clear()
	manager.blocked_directions.append(TURN_GAME_OVER_DIRECTION)
	hud._on_warning_changed(manager.blocked_directions)
	manager.game_over.emit()
	await get_tree().create_timer(0.65).timeout
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
	if not _hud_scenes_only:
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
	manager.remaining_time = Config.data.blitz_time_bar_reference
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
	var fever_band: ColorRect = main.get_node("UI/Hud/FeverBand") as ColorRect
	print(
		"SCREEN_CAPTURE_CHECK scene=blitz_fever_band position=(%.1f,%.1f) size=(%.1f,%.1f)" % [
			fever_band.position.x,
			fever_band.position.y,
			fever_band.size.x,
			fever_band.size.y,
		]
	)
	if absf(fever_band.position.x) > 0.5:
		_fail("BLITZ FEVER band must span the viewport without horizontal clipping")
	print("SCREEN_CAPTURE_CHECK scene=blitz_l4_blast radius_factor=0.3")
	await _capture("06_blitz_fever_chain.png")
	await get_tree().create_timer(0.40).timeout

	hud._hide_bonus_label()
	hud._on_fever_changed(false, 0.0)
	hud._hide_fever_visuals()
	board.set_fever_active(false)
	var time_bar: BlitzTimeBar = main.get_node("UI/Hud/TimeBarFill") as BlitzTimeBar
	time_bar.clear_bonus()
	manager.remaining_time = 128.4
	hud._on_time_changed(manager.remaining_time)
	_validate_blitz_long_timer_scene(main, 3, 38.4 / 45.0)
	await _capture("40_blitz_timer_long.png")

	manager.remaining_time = 20.0
	hud._on_time_changed(manager.remaining_time)
	manager.remaining_time = 21.6
	hud._on_time_changed(manager.remaining_time)
	hud._on_time_bonus_awarded(1.6, "MERGE_L7")
	_validate_blitz_bonus_segment_scene(main, 1, false)
	var bonus_label: Label = main.get_node("UI/Hud/BonusLabel") as Label
	if not bonus_label.visible or bonus_label.text != "+1.6s":
		_fail("BLITZ bonus text must appear with the first bright frame")
	await _capture("41_blitz_bonus_gauge_a.png")
	await get_tree().create_timer(0.98).timeout
	if not time_bar.bonus_is_fading() or not bonus_label.visible:
		_fail("BLITZ bonus gauge mixing must start with the label fade")
	await _capture("41_blitz_bonus_gauge_b.png")

	hud._reset_callout_tracking()
	time_bar.clear_bonus()
	manager.remaining_time = 44.0
	hud._on_time_changed(manager.remaining_time)
	manager.remaining_time = 46.0
	hud._on_time_changed(manager.remaining_time)
	hud._on_time_bonus_awarded(2.0, "BLAST_L6")
	_validate_blitz_bonus_segment_scene(main, 2, false)
	await _capture("42_blitz_bonus_layer_cross.png")

	hud._reset_callout_tracking()
	time_bar.clear_bonus()
	hud._on_fever_changed(true, 3.0)
	board.set_fever_active(true)
	manager.remaining_time = 20.0
	hud._on_time_changed(manager.remaining_time)
	manager.remaining_time = 23.2
	hud._on_time_changed(manager.remaining_time)
	hud._on_time_bonus_awarded(3.2, "MERGE_L7")
	_validate_blitz_bonus_segment_scene(main, 1, true)
	if not bonus_label.visible or bonus_label.text != "+3.2s":
		_fail("BLITZ fever bonus text must appear with its bright piece")
	await _capture("43_blitz_bonus_fever.png")

	hud._hide_bonus_label()
	for popup: ScorePopup in hud.active_score_popups():
		popup.deactivate()
	hud._on_fever_changed(false, 0.0)
	hud._hide_fever_visuals()
	board.set_fever_active(false)
	hud._on_combo_changed(3, 1.3, 8)
	spawner.sync_blitz_next_batch_size(8)
	hud._set_danger_badge(0.70, 4.0)
	hud.set_process(false)
	for color: int in range(Config.data.color_display.size()):
		var small_planet: Orb3D = board.spawn_orb(
			color,
			1,
			Vector2(-300.0 + float(color) * 120.0, 250.0)
		)
		small_planet.disable_physics()
	feedback.play_reaction_visuals({
		"type": ReactionRules.Type.BLAST,
		"position": Vector2(0.0, -140.0),
		"levels": [6, 6],
		"colors": [OrbTypes.OrbColor.YELLOW, OrbTypes.OrbColor.CYAN],
		"shock_level": 6,
	})
	await get_tree().create_timer(0.24).timeout
	print("SCREEN_CAPTURE_CHECK scene=blitz_l6_blast radius_factor=1.0")
	print("SCREEN_CAPTURE_CHECK scene=blitz_danger small_planets=6 level=1")
	await _capture("07_blitz_danger.png")
	if _hud_scenes_only:
		await _destroy_main(main)
		return
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
	await get_tree().create_timer(0.65).timeout
	_validate_blitz_result_scene(main)
	await _capture("09_blitz_result.png")

	var ranking_result: Dictionary = _prepare_blitz_ranking_capture()
	score.best_score = SaveStore.load_best_score(_temp_save_path, GameConfig.GameMode.BLITZ)
	hud._on_score_changed(score.score, score.best_score)
	manager.game_over_details["ranking"] = ranking_result
	manager.game_over.emit()
	var ui: DebugHud = main.get_node("UI") as DebugHud
	ui.show_ranking(GameConfig.GameMode.BLITZ, int(ranking_result["rank"]))
	await get_tree().create_timer(0.30).timeout
	_validate_blitz_ranking_scene(main)
	await _capture("10_ranking_blitz.png")
	(main.get_node("UI/RankingPanel/Panel/Content/RankingCloseButton") as Button).pressed.emit()
	await get_tree().create_timer(0.60).timeout
	_validate_new_record_result_scene(main)
	await _capture("11_result_new_record.png")
	await _destroy_main(main)


func _capture_orb_codex() -> void:
	var main: Main = await _create_main(Main.NO_MODE)
	(main.get_node("UI") as CanvasLayer).visible = false
	(main.get_node("Board") as Board3D).visible = false
	(main.get_node("SpaceBackdrop") as SpaceBackdrop).visible = false
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
			orb.set_physics_process(false)
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
	await _capture("14_orb_codex_repeat.png")
	_verify_deterministic_orb_capture()
	_analyze_orb_codex(camera, descriptors)
	print("SCREEN_CAPTURE_CHECK scene=orb_codex colors=6 levels=7 symbols=off")
	await _destroy_main(main)


func _capture_orb_closeup() -> void:
	var main: Main = await _create_main(Main.NO_MODE)
	(main.get_node("UI") as CanvasLayer).visible = false
	(main.get_node("Board") as Board3D).visible = false
	(main.get_node("SpaceBackdrop") as SpaceBackdrop).visible = false
	var camera: Camera3D = main.get_node("Camera3D") as Camera3D
	camera.position.z = 55.0 / 2.2
	var positions: Array[Vector2] = []
	for color: int in range(Config.data.color_display.size()):
		var column: int = color % 3
		var row: int = color / 3
		positions.append(Vector2(-205.0 + float(column) * 205.0, -190.0 + float(row) * 205.0))
		var orb: Orb3D = ORB_3D_SCENE.instantiate() as Orb3D
		main.add_child(orb)
		orb.setup(color, 5, Config.data)
		orb.disable_physics()
		orb.set_physics_process(false)
		orb.set_render_clamp_enabled(false)
		orb.position = positions[color]
	var comparison_levels: Array[int] = [1, 7]
	for index: int in range(comparison_levels.size()):
		var comparison: Orb3D = ORB_3D_SCENE.instantiate() as Orb3D
		main.add_child(comparison)
		comparison.setup(OrbTypes.OrbColor.BLUE, comparison_levels[index], Config.data)
		comparison.disable_physics()
		comparison.set_physics_process(false)
		comparison.set_render_clamp_enabled(false)
		comparison.position = Vector2(-115.0 + float(index) * 210.0, 245.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("15_orb_closeup.png")
	print("SCREEN_CAPTURE_CHECK scene=orb_closeup planets=6 level=5 earth_compare=L1,L7 scale=2.2x")
	await _destroy_main(main)


func _capture_mars_rotations() -> void:
	var main: Main = await _create_main(Main.NO_MODE)
	(main.get_node("UI") as CanvasLayer).visible = false
	(main.get_node("Board") as Board3D).visible = false
	(main.get_node("SpaceBackdrop") as SpaceBackdrop).visible = false
	var camera: Camera3D = main.get_node("Camera3D") as Camera3D
	camera.position.z = 55.0 / 2.2
	var positions: Array[Vector2] = [
		Vector2(-115.0, -120.0),
		Vector2(115.0, -120.0),
		Vector2(-115.0, 120.0),
		Vector2(115.0, 120.0),
	]
	var angles_degrees: Array[float] = [0.0, 90.0, 180.0, 270.0]
	for index: int in range(angles_degrees.size()):
		var orb: Orb3D = ORB_3D_SCENE.instantiate() as Orb3D
		main.add_child(orb)
		orb.setup(OrbTypes.OrbColor.RED, 5, Config.data)
		orb.disable_physics()
		orb.set_physics_process(false)
		orb.set_render_clamp_enabled(false)
		orb.position = positions[index]
		orb.get_physics_body().rotation = Vector3(
			0.0,
			0.0,
			deg_to_rad(angles_degrees[index])
		)
		orb._process(0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("47_mars_rotations.png")
	print("SCREEN_CAPTURE_CHECK scene=mars_rotations planet=mars level=5 angles=0,90,180,270 scale=2.2x")
	await _destroy_main(main)


func _capture_slime_core() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var games: Array[Variant] = []
	var positions: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(viewport_size.x * 0.5, 0.0),
		Vector2(0.0, viewport_size.y * 0.5),
		viewport_size * 0.5,
	]
	for index: int in range(4):
		var game: Variant = SLIME_MAIN_SCENE.instantiate()
		game.shell_enabled = false
		game.save_path = _temp_save_path
		add_child(game)
		await get_tree().process_frame
		game.process_mode = Node.PROCESS_MODE_DISABLED
		game.scale = Vector2.ONE * 0.5
		game.position = positions[index]
		games.append(game)

	var admission: SlimeSim = games[0].get_sim()
	for tick: int in range(13):
		admission.step(1.0 / 60.0)
	games[0].refresh_presentation()

	var ready: SlimeSim = games[1].get_sim()
	ready.clear_slimes()
	ready.intro_queue.clear()
	ready.moving = false
	var radius: float = ready.radius_for_level(0)
	var down_entry: Vector2 = ready.entry_position_for(Vector2i.DOWN, radius)
	ready.add_slime(
		down_entry + Vector2(0.0, radius * 2.0 + ready.config.entry_margin + 14.9),
		0,
		0
	)
	var left_entry: Vector2 = ready.entry_position_for(Vector2i.LEFT, radius)
	ready.add_slime(
		left_entry + Vector2(-radius * 2.0 - ready.config.entry_margin - 50.0, 0.0),
		0,
		1
	)
	ready.set_next_slimes([{"level": 0, "color": 2}, {"level": 1, "color": 0}])
	ready.moving = true
	ready.finish_turn()
	games[1].refresh_presentation()

	var final_move: SlimeSim = games[2].get_sim()
	final_move.clear_slimes()
	final_move.intro_queue.clear()
	_add_slime_entry_blockers(final_move)
	final_move.turn = 18
	final_move.score = 54250
	final_move.moving = true
	final_move.finish_turn()
	games[2].refresh_presentation()

	var result: SlimeSim = games[3].get_sim()
	result.clear_slimes()
	result.intro_queue.clear()
	_add_slime_entry_blockers(result)
	result.turn = 27
	result.score = 128750
	result.run_best_chain = 6
	result.final_move_active = true
	result.moving = true
	result.finish_turn()
	games[3].refresh_presentation()

	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("48_slime_core.png")
	print("SCREEN_CAPTURE_CHECK scene=slime_core panels=admission,entry-bars,final-move,result")
	for game: Variant in games:
		game.queue_free()
	await get_tree().process_frame


func _capture_slime_states() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var games: Array[Variant] = []
	var positions: Array[Vector2] = [Vector2.ZERO, Vector2(viewport_size.x * 0.5, 0.0), Vector2(0.0, viewport_size.y * 0.5), viewport_size * 0.5]
	for index: int in range(4):
		var game: Variant = SLIME_MAIN_SCENE.instantiate()
		game.shell_enabled = false
		game.save_path = _temp_save_path
		add_child(game)
		await get_tree().process_frame
		game.process_mode = Node.PROCESS_MODE_DISABLED
		game.scale = Vector2.ONE * 0.5
		game.position = positions[index]
		games.append(game)

	var moving: SlimeSim = games[0].get_sim()
	for tick: int in range(34):
		moving.step(1.0 / 60.0)
	for index: int in range(moving.slimes.size()):
		moving.slimes[index].velocity = Vector2(520.0 + float(index) * 80.0, 90.0 - float(index) * 30.0)
	for tick: int in range(4):
		moving.step(1.0 / 60.0)
	games[0].refresh_presentation()

	var waiting: SlimeSim = games[1].get_sim()
	waiting.clear_slimes()
	waiting.intro_queue.clear()
	waiting.moving = false
	var radius: float = waiting.radius_for_level(0)
	var down_entry: Vector2 = waiting.entry_position_for(Vector2i.DOWN, radius)
	waiting.add_slime(down_entry + Vector2(0.0, radius * 2.0 + waiting.config.entry_margin + 14.9), 0, 0).visual_scale = 1.0
	var left_entry: Vector2 = waiting.entry_position_for(Vector2i.LEFT, radius)
	waiting.add_slime(left_entry + Vector2(-radius * 2.0 - waiting.config.entry_margin - 50.0, 0.0), 0, 1).visual_scale = 1.0
	var blinking: SlimeSim.SlimeBody = waiting.add_slime(Vector2(250.0, 500.0), 2, 0)
	blinking.visual_scale = 1.0
	blinking.idle_phase = PI * 0.5 / 0.73
	var max_face: SlimeSim.SlimeBody = waiting.add_slime(Vector2(380.0, 680.0), 6, 2, Vector2.ZERO, 64)
	max_face.visual_scale = 1.0
	waiting.set_next_slimes([{"level": 0, "color": 2}, {"level": 1, "color": 0}])
	waiting.moving = true
	waiting.finish_turn()
	games[1].refresh_presentation()

	var merging: SlimeSim = games[2].get_sim()
	merging.clear_slimes()
	merging.intro_queue.clear()
	merging.moving = false
	merging.turn = 7
	var merge_radius: float = merging.radius_for_mass(4)
	merging.add_slime(Vector2(280.0 - merge_radius, 520.0), 2, 1, Vector2.ZERO, 4).visual_scale = 1.0
	merging.add_slime(Vector2(280.0 + merge_radius, 520.0), 2, 1, Vector2.ZERO, 4).visual_scale = 1.0
	merging.resolve_pairs()
	games[2].refresh_presentation()
	(games[2].get_node("Content/SlimeView") as SlimeView).advance_visuals(0.18)
	games[2].refresh_presentation()

	var clearing: SlimeSim = games[3].get_sim()
	clearing.clear_slimes()
	clearing.intro_queue.clear()
	_add_slime_entry_blockers(clearing)
	clearing.turn = 18
	clearing.score = 54250
	var max_radius: float = clearing.radius_for_mass(64)
	clearing.add_slime(Vector2(320.0 - max_radius, 560.0), 6, 0, Vector2.ZERO, 64).visual_scale = 1.0
	clearing.add_slime(Vector2(320.0 + max_radius, 560.0), 6, 1, Vector2.ZERO, 64).visual_scale = 1.0
	clearing.resolve_pairs()
	clearing.moving = true
	clearing.finish_turn()
	games[3].refresh_presentation()
	(games[3].get_node("Content/SlimeView") as SlimeView).advance_visuals(0.22)
	games[3].refresh_presentation()

	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("49_slime_states.png")
	print(
		"SCREEN_CAPTURE_CHECK scene=slime_states panels=initial-moving-trails,waiting-bars-faces,absorb,max-clear-final stages=%d,%d,%d,%d"
		% [
			waiting.entry_stage_for(Vector2i.DOWN),
			waiting.entry_stage_for(Vector2i.LEFT),
			waiting.entry_stage_for(Vector2i.UP),
			waiting.entry_stage_for(Vector2i.RIGHT),
		]
	)
	for game: Variant in games:
		game.queue_free()
	await get_tree().process_frame


func _capture_slime_shell() -> void:
	SaveStore.add_ranking(
		_temp_save_path,
		GameConfig.GameMode.SLIME,
		148500,
		{"turns": 62, "max_chain": 9, "max_colors": 5},
		"2026-10-16 21:10"
	)
	SaveStore.add_ranking(
		_temp_save_path,
		GameConfig.GameMode.SLIME,
		96250,
		{"turns": 47, "max_chain": 6, "max_colors": 4},
		"2026-10-17 09:25"
	)
	SaveStore.save_last_mode(_temp_save_path, GameConfig.GameMode.SLIME)
	var main: Main = await _create_main(Main.NO_MODE)
	await _capture("50_slime_shell_start.png")
	var ui: DebugHud = main.get_node("UI") as DebugHud
	ui.show_ranking(GameConfig.GameMode.SLIME, 1)
	await get_tree().create_timer(0.30).timeout
	await _capture("50_slime_shell_ranking.png")
	await _destroy_main(main)

	var game: SlimeGame = SLIME_MAIN_SCENE.instantiate() as SlimeGame
	game.save_path = _temp_save_path
	add_child(game)
	await get_tree().process_frame
	game.set_physics_process(false)
	var sim: SlimeSim = game.get_sim()
	sim.score = 187750
	sim.turn = 73
	sim.run_best_chain = 11
	sim.completed_colors = {0: true, 1: true, 2: true, 3: true, 4: true, 5: true}
	sim.game_over = true
	game.refresh_presentation()
	game._sync_input_lock()
	game._commit_game_over_once()
	await get_tree().create_timer(1.25).timeout
	await _capture("50_slime_shell_result.png")
	print("SCREEN_CAPTURE_CHECK scene=slime_shell cards=3 ranking=slime result=shared")
	game.queue_free()
	await get_tree().process_frame


func _capture_jelly_shell() -> void:
	SaveStore.add_ranking(
		_temp_save_path,
		GameConfig.GameMode.JELLY,
		176400,
		{"max_combo": 12, "turns": 84, "max_level": 7, "final_moves": 3},
		"2026-10-23 20:15"
	)
	SaveStore.add_ranking(
		_temp_save_path,
		GameConfig.GameMode.JELLY,
		112750,
		{"max_combo": 8, "turns": 61, "max_level": 6, "final_moves": 1},
		"2026-10-23 18:40"
	)
	SaveStore.save_last_mode(_temp_save_path, GameConfig.GameMode.JELLY)
	var main: Main = await _create_main(Main.NO_MODE)
	var start: StartScreen = main.get_node("UI/StartScreen") as StartScreen
	if not (start.get_node("Content/JellyButton") as Button).button_pressed:
		_fail("JELLY start card must reflect the saved last mode")
	await _capture("54_jelly_shell_start.png")
	var ui: DebugHud = main.get_node("UI") as DebugHud
	ui.show_ranking(GameConfig.GameMode.JELLY, 1)
	await get_tree().create_timer(0.30).timeout
	await _capture("54_jelly_shell_ranking.png")
	await _destroy_main(main)

	main = await _create_main(int(GameConfig.GameMode.JELLY))
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	manager.set_physics_process(false)
	manager.turn_index = 73
	manager.max_combo = 11
	manager.final_move_count = 5
	manager.final_move_success_count = 4
	score.score = 187750
	score.best_score = 187750
	score.max_level_reached = 7
	manager.game_over_details = {
		"direction": Vector2i.RIGHT,
		"final_moves": 5,
		"final_move_successes": 4,
	}
	manager.game_over_details["ranking"] = manager._commit_completed_ranking()
	manager.game_over.emit()
	await get_tree().create_timer(0.85).timeout
	await _capture("54_jelly_shell_result.png")
	print("SCREEN_CAPTURE_CHECK scene=jelly_shell cards=4 ranking=jelly result=final-move")
	await _destroy_main(main)


func _capture_slime_shell_play() -> void:
	var game: SlimeGame = SLIME_MAIN_SCENE.instantiate() as SlimeGame
	game.save_path = _temp_save_path
	add_child(game)
	await get_tree().process_frame
	game.set_physics_process(false)
	var sim: SlimeSim = game.get_sim()
	var radius: float = sim.radius_for_level(0)

	sim.clear_slimes()
	sim.intro_queue.clear()
	sim.game_over = false
	sim.final_move_pending = false
	sim.add_slime(
		sim.entry_position_for(Vector2i.DOWN, radius)
			+ Vector2(0.0, radius * 2.0 + sim.config.entry_margin + 14.9),
		0,
		0
	).visual_scale = 1.0
	sim.add_slime(
		sim.entry_position_for(Vector2i.LEFT, radius)
			+ Vector2(-radius * 2.0 - sim.config.entry_margin - 50.0, 0.0),
		0,
		1
	).visual_scale = 1.0
	sim.set_next_slimes([{"level": 0, "color": 2}, {"level": 1, "color": 0}])
	sim.moving = true
	sim.finish_turn()
	game.refresh_presentation()
	game._sync_input_lock()
	await get_tree().process_frame
	await _capture("50_slime_shell_play_ready.png")

	sim.clear_slimes()
	_add_slime_entry_blockers(sim)
	sim.turn = 18
	sim.moving = true
	sim.finish_turn()
	game.refresh_presentation()
	game._sync_input_lock()
	await get_tree().process_frame
	await _capture("50_slime_shell_play_final_move.png")

	sim.clear_slimes()
	sim.intro_queue.clear()
	sim.game_over = false
	sim.final_move_pending = false
	sim.final_move_active = false
	sim.add_slime(Vector2(320.0, 720.0), 2, 0).visual_scale = 1.0
	sim.set_next_slimes([{"level": 0, "color": 1}, {"level": 1, "color": 2}])
	sim.moving = false
	sim.start_turn(Vector2i.LEFT)
	game._begin_lock_orbit_clock()
	var orbit_duration: float = (
		float(game.get("_lock_intro_last_scheduled"))
		+ sim.config.max_simulation_time
	)
	sim.intro_elapsed = orbit_duration * 0.10
	game.refresh_presentation()
	game._sync_input_lock()
	await get_tree().process_frame
	await _capture("50_slime_shell_play_busy.png")

	InputRouter.swipe_rejected.emit(Vector2i.UP)
	await get_tree().process_frame
	await _capture("50_slime_shell_play_rejected.png")
	print(
		"SCREEN_CAPTURE_CHECK scene=slime_shell_play states=ready,final-move,busy@0.1,rejected arrows=none shell=enabled"
	)
	game.queue_free()
	await get_tree().process_frame


func _capture_slime_max_growth() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var games: Array[SlimeGame] = []
	var labels: Array[Label] = []
	var positions: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(viewport_size.x * 0.5, 0.0),
		Vector2(0.0, viewport_size.y * 0.5),
		viewport_size * 0.5,
	]
	var masses: Array[int] = [64, 128, 256]
	for index: int in range(4):
		var game: SlimeGame = SLIME_MAIN_SCENE.instantiate() as SlimeGame
		game.shell_enabled = false
		game.save_path = _temp_save_path
		add_child(game)
		await get_tree().process_frame
		game.process_mode = Node.PROCESS_MODE_DISABLED
		game.scale = Vector2.ONE * 0.5
		game.position = positions[index]
		var sim: SlimeSim = game.get_sim()
		sim.clear_slimes()
		sim.intro_queue.clear()
		sim.moving = false
		sim.turn = 1
		if index < masses.size():
			var mass_value: int = masses[index]
			var slime: SlimeSim.SlimeBody = sim.add_slime(
				sim.config.board_rect.get_center(),
				6,
				index,
				Vector2.ZERO,
				mass_value
			)
			slime.visual_scale = 1.0
		else:
			var large_radius: float = sim.radius_for_mass(450)
			var small_radius: float = sim.radius_for_mass(1)
			sim.add_slime(Vector2(270.0, 540.0), 6, 3, Vector2.ZERO, 450).visual_scale = 1.0
			sim.add_slime(
				Vector2(270.0 + large_radius + small_radius, 540.0),
				0,
				3,
				Vector2.ZERO,
				1
			).visual_scale = 1.0
			sim.resolve_pairs()
			var events: Array[Dictionary] = sim.drain_events()
			(game.get_node("Content/SlimeView") as SlimeView).handle_events(events)
			(game.get_node("Content/SlimeView") as SlimeView).advance_visuals(0.14)
		game.refresh_presentation()
		games.append(game)

		var label := Label.new()
		label.text = "MASS %d · MAX" % (masses[index] if index < masses.size() else 451)
		if index == 3:
			label.text += " · 450 + 1 흡수"
		label.position = positions[index] + Vector2(9.0, 8.0)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color("fff4b5"))
		label.add_theme_color_override("font_outline_color", Color("10162f"))
		label.add_theme_constant_override("outline_size", 4)
		add_child(label)
		labels.append(label)

	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("51_slime_max_growth.png")
	print("SCREEN_CAPTURE_CHECK scene=slime_max_growth panels=mass64,128,256,451 absorption=450+1 radius_cap=165")
	for label: Label in labels:
		label.queue_free()
	for game: SlimeGame in games:
		game.queue_free()
	await get_tree().process_frame


func _add_slime_entry_blockers(sim: SlimeSim) -> void:
	var radius: float = sim.radius_for_level(0)
	for direction: Vector2i in SlimeSim.DIRECTIONS:
		var blocker: SlimeSim.SlimeBody = sim.add_slime(sim.entry_position_for(direction, radius), 0, direction.x + direction.y + 2)
		blocker.visual_scale = 1.0


func _verify_deterministic_orb_capture() -> void:
	var first_path: String = _output_directory.path_join("14_orb_codex.png")
	var repeat_path: String = _output_directory.path_join("14_orb_codex_repeat.png")
	var first: Image = Image.load_from_file(ProjectSettings.globalize_path(first_path))
	var repeat: Image = Image.load_from_file(ProjectSettings.globalize_path(repeat_path))
	if first == null or first.is_empty() or repeat == null or repeat.is_empty():
		_fail("Could not load repeated orb codex captures")
	elif first.get_data() != repeat.get_data():
		var changed_pixels: int = 0
		var maximum_difference: float = 0.0
		for y: int in range(first.get_height()):
			for x: int in range(first.get_width()):
				var difference: float = _rgb_distance(first.get_pixel(x, y), repeat.get_pixel(x, y))
				if difference > 0.0:
					changed_pixels += 1
					maximum_difference = maxf(maximum_difference, difference)
		_fail(
			"Orb codex repeated capture pixels differ at fixed animation time: pixels=%d max=%.6f" % [
				changed_pixels,
				maximum_difference,
			]
		)
	else:
		print(
			"ORB_CODEX_DETERMINISM fixed_time=%.2f bytes=%d equal=true" % [
				CelestialOrbArt.animation_time(),
				first.get_data().size(),
			]
		)
		_remove_file(repeat_path)


func _capture_reaction_effect_scenes() -> void:
	await _capture_reaction_pair("23_merge_stardust", ReactionRules.Type.MERGE, 3, 0.18, 0.42)
	if _failed:
		return
	await _capture_reaction_pair("24_birth_l6", ReactionRules.Type.MERGE, 6, 0.13, 0.52)
	if _failed:
		return
	await _capture_reaction_pair("25_birth_l7", ReactionRules.Type.MERGE, 7, 0.13, 0.58)
	if _failed:
		return
	await _capture_reaction_pair("26_blast_l4", ReactionRules.Type.BLAST, 4, 0.18, 0.42)
	if _failed:
		return
	await _capture_reaction_pair("27_blast_l6", ReactionRules.Type.BLAST, 6, 0.18, 0.60)
	if _failed:
		return
	await _capture_crowded_blast_pair("28_blast_l5_crowded", 5, 0.22, 0.58)
	if _failed:
		return
	await _capture_crowded_blast_pair("29_blast_l6_crowded", 6, 0.22, 0.58)
	if _failed:
		return
	await _measure_same_size_planet_glow()


func _capture_v4_2_scenes() -> void:
	var main: Main = await _create_main(int(GameConfig.GameMode.BLITZ))
	var manager: BlitzManager = main.get_node("BlitzManager") as BlitzManager
	var board: Board3D = main.get_node("Board") as Board3D
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var feedback: FeedbackDirector = main.get_node("FeedbackDirector") as FeedbackDirector
	manager.set_physics_process(false)
	board.set_physics_process(false)
	for orb: Orb3D in board.get_orbs():
		orb.disable_physics()

	hud._show_callout("GREAT!", 1)
	await get_tree().create_timer(0.08).timeout
	await _capture("30_callout_great_a.png")
	await get_tree().create_timer(0.36).timeout
	await _capture("30_callout_great_b.png")
	hud._show_callout("UNSTOPPABLE!", 4)
	await get_tree().create_timer(0.08).timeout
	await _capture("31_callout_unstoppable_a.png")
	await get_tree().create_timer(0.42).timeout
	await _capture("31_callout_unstoppable_b.png")

	hud._hide_callout_label()
	hud._on_reaction_scored({
		"type": ReactionRules.Type.MERGE,
		"result_color": OrbTypes.OrbColor.CYAN,
		"position": Vector2(-80.0, -40.0),
		"points": 1280,
		"base_points": 1280,
		"combo_multiplier": 1.0,
	})
	await get_tree().create_timer(0.10).timeout
	await _capture("32_popup_merge.png")
	for popup: ScorePopup in hud.active_score_popups():
		popup.deactivate()
	hud._on_reaction_scored({
		"type": ReactionRules.Type.BLAST,
		"position": Vector2(80.0, -40.0),
		"points": 48600,
		"base_points": 6075,
		"combo_multiplier": 8.0,
	})
	await get_tree().create_timer(0.10).timeout
	var big_popup: ScorePopup = hud.active_score_popups()[0]
	if big_popup.score_text() != "+48,600" or big_popup.formula_text() != "6,075 ×8":
		_fail("V4-2 big popup comma/formula mismatch")
	await _capture("33_popup_blast_big.png")
	for popup: ScorePopup in hud.active_score_popups():
		popup.deactivate()

	await _capture_color_effect_pair(
		feedback, "34_color_push", OrbTypes.OrbColor.RED, Vector2(-80.0, -30.0)
	)
	await _capture_color_effect_pair(
		feedback, "35_color_pull", OrbTypes.OrbColor.PURPLE, Vector2(80.0, -30.0)
	)
	await _capture_color_effect_pair(
		feedback, "36_color_shake", OrbTypes.OrbColor.BLUE, Vector2.ZERO
	)
	await _capture_color_effect_pair(
		feedback, "37_color_lift", OrbTypes.OrbColor.YELLOW, Vector2.ZERO
	)

	hud._on_fever_changed(true, 5.0)
	board.set_fever_active(true)
	await get_tree().create_timer(0.08).timeout
	await _capture("38_fever_start_a.png")
	await get_tree().create_timer(0.22).timeout
	await _capture("38_fever_start_b.png")
	await get_tree().create_timer(0.90).timeout
	if hud.active_ui_sparkle_count() > 20:
		_fail("V4-2 visible UI sparkle count exceeds twenty")
	await _capture("39_fever_running.png")
	hud._on_fever_changed(false, 0.0)
	board.set_fever_active(false)
	print("SCREEN_CAPTURE_CHECK scene=v4_2 callouts=4 popups=2 color_pairs=4 fever=3")
	await _destroy_main(main)


func _capture_color_effect_pair(
	feedback: FeedbackDirector,
	base_name: String,
	color_index: int,
	origin: Vector2
) -> void:
	feedback.clear_effects()
	feedback.play_reaction_visuals({
		"type": ReactionRules.Type.MERGE,
		"result_level": 3,
		"result_color": color_index,
		"position": origin,
		"shock_targets": [
			{"position": origin + Vector2(-150.0, 80.0)},
			{"position": origin + Vector2(120.0, 110.0)},
		],
	})
	if feedback.active_color_effect_count() != 1:
		_fail("%s must create exactly one color visual" % base_name)
		return
	var effect: ColorEffectVisual = feedback.active_color_effects()[0]
	var expected_rings: int = 0 if color_index == OrbTypes.OrbColor.YELLOW else 1
	if effect.ring_layer_count() != expected_rings:
		_fail("%s ring layer mismatch" % base_name)
		return
	await get_tree().create_timer(0.08).timeout
	await _capture("%s_a.png" % base_name)
	await get_tree().create_timer(0.14).timeout
	await _capture("%s_b.png" % base_name)


func _capture_reaction_pair(
	base_name: String,
	reaction_type: ReactionRules.Type,
	level: int,
	first_time: float,
	second_time: float
) -> void:
	var main: Main = await _create_main(Main.NO_MODE)
	(main.get_node("UI") as CanvasLayer).visible = false
	var board: Board3D = main.get_node("Board") as Board3D
	board.set_process(false)
	var feedback: FeedbackDirector = main.get_node("FeedbackDirector") as FeedbackDirector
	feedback.clear_effects()
	var origin: Vector2 = Vector2.ZERO
	var reaction: Dictionary = {
		"type": reaction_type,
		"position": origin,
	}
	if reaction_type == ReactionRules.Type.MERGE:
		var result_orb: Orb3D = board.spawn_orb(
			OrbTypes.OrbColor.YELLOW,
			level,
			origin
		)
		result_orb.disable_physics()
		reaction["result_orb"] = result_orb
		reaction["result_level"] = level
		reaction["result_color"] = OrbTypes.OrbColor.YELLOW
		reaction["chain"] = 1
	else:
		reaction["levels"] = [level, level]
		reaction["colors"] = [OrbTypes.OrbColor.PURPLE, OrbTypes.OrbColor.CYAN]
		reaction["shock_level"] = level
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var baseline: Image = get_viewport().get_texture().get_image()
	feedback.play_reaction_visuals(reaction)
	await get_tree().create_timer(first_time).timeout
	await _capture("%s_a.png" % base_name)
	if reaction_type == ReactionRules.Type.BLAST and level == 4:
		_validate_l4_local_brightness(main, baseline)
	await get_tree().create_timer(maxf(second_time - first_time, 0.01)).timeout
	await _capture("%s_b.png" % base_name)
	print(
		"REACTION_CAPTURE scene=%s level=%d time_a=%.2f time_b=%.2f" % [
			base_name,
			level,
			first_time,
			second_time,
		]
	)
	await _destroy_main(main)


func _validate_l4_local_brightness(main: Main, baseline: Image) -> void:
	await RenderingServer.frame_post_draw
	var effect_image: Image = get_viewport().get_texture().get_image()
	var camera: Camera3D = main.get_node("Camera3D") as Camera3D
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var image_scale: Vector2 = Vector2(effect_image.get_size()) / viewport_size
	var center: Vector2 = camera.unproject_position(
		Orb3D.plane_position_to_world(Vector2.ZERO)
	) * image_scale
	var push_radius_px: float = (
		Config.data.board_size * Config.data.blast_push_radius_factor_for_level(4)
	)
	var edge: Vector2 = camera.unproject_position(
		Orb3D.plane_position_to_world(Vector2(push_radius_px, 0.0))
	) * image_scale
	var radius: float = center.distance_to(edge) + 4.0
	var baseline_outside: float = _average_luminance_outside_circle(
		baseline,
		center,
		radius
	)
	var effect_outside: float = _average_luminance_outside_circle(
		effect_image,
		center,
		radius
	)
	var gain: float = effect_outside - baseline_outside
	print(
		"REACTION_PIXEL_CHECK scene=blast_l4 outside_gain=%.5f maximum=0.03000" % gain
	)
	if gain > 0.03:
		_fail("L4 blast outside-radius brightness gain %.5f exceeds 0.03" % gain)


func _capture_crowded_blast_pair(
	base_name: String,
	level: int,
	first_time: float,
	second_time: float
) -> void:
	var main: Main = await _create_main(Main.NO_MODE)
	(main.get_node("UI") as CanvasLayer).visible = false
	var board: Board3D = main.get_node("Board") as Board3D
	board.set_process(false)
	var orb_descriptors: Array[Dictionary] = _populate_crowded_board(board)
	var feedback: FeedbackDirector = main.get_node("FeedbackDirector") as FeedbackDirector
	feedback.clear_effects()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	feedback.play_reaction_visuals({
		"type": ReactionRules.Type.BLAST,
		"position": Vector2.ZERO,
		"levels": [level, level],
		"colors": [OrbTypes.OrbColor.PURPLE, OrbTypes.OrbColor.CYAN],
		"shock_level": level,
	})
	await get_tree().create_timer(first_time).timeout
	await _capture("%s_a.png" % base_name)
	await get_tree().create_timer(maxf(second_time - first_time, 0.01)).timeout
	await _capture("%s_b.png" % base_name)
	# Measure after the wave rings have expanded beyond the inner board sample,
	# so this is specifically orb-versus-nebula contrast rather than ring contrast.
	await _validate_crowded_nebula_contrast(main, level, orb_descriptors, base_name)
	print(
		"REACTION_CAPTURE scene=%s level=%d crowded_orbs=%d time_a=%.2f time_b=%.2f" % [
			base_name,
			level,
			orb_descriptors.size(),
			first_time,
			second_time,
		]
	)
	await _destroy_main(main)


func _capture_jelly_look(main: Main, board: Board3D) -> void:
	var feedback: FeedbackDirector = main.get_node("FeedbackDirector") as FeedbackDirector
	var hud: Hud = main.get_node("UI/Hud") as Hud
	feedback.clear_effects()
	_clear_capture_board(board)
	var level_positions: Array[Vector2] = [
		Vector2(-330.0, -230.0), Vector2(-225.0, -230.0),
		Vector2(-100.0, -225.0), Vector2(45.0, -215.0),
		Vector2(220.0, -195.0), Vector2(-155.0, 105.0),
		Vector2(135.0, 120.0),
	]
	for index: int in range(level_positions.size()):
		var orb: Orb3D = board.spawn_orb(index % JellyOrbArt.PALETTE.size(), index + 1, level_positions[index])
		orb.disable_physics()
	await _capture("53_jelly_look_levels.png")

	_clear_capture_board(board)
	var crowded_coordinates: Array[float] = [-320.0, -160.0, 0.0, 160.0, 320.0]
	var orb_index: int = 0
	for y: float in crowded_coordinates:
		for x: float in crowded_coordinates:
			var crowded_orb: Orb3D = board.spawn_orb(
				orb_index % JellyOrbArt.PALETTE.size(),
				1 + orb_index % 3,
				Vector2(x, y)
			)
			crowded_orb.disable_physics()
			orb_index += 1
	await _capture("53_jelly_look_crowded.png")

	_clear_capture_board(board)
	var absorber: Orb3D = board.spawn_orb(2, 4, Vector2(115.0, 0.0))
	absorber.disable_physics()
	feedback.play_reaction_visuals({
		"type": ReactionRules.Type.MERGE,
		"position": Vector2(115.0, 0.0),
		"result_level": 4,
		"result_color": 2,
		"result_orb": absorber,
		"jelly_absorption": true,
		"source_positions": [Vector2(-180.0, 0.0), Vector2(115.0, 0.0)],
		"source_radii": [Config.data.radius_for_level(3), Config.data.radius_for_level(4)],
		"levels": [3, 4],
		"colors": [2, 2],
	})
	await get_tree().create_timer(0.035).timeout
	await _capture("53_jelly_look_absorption.png")

	feedback.clear_effects()
	_clear_capture_board(board)
	var max_orb: Orb3D = board.spawn_orb(4, 7, Vector2.ZERO)
	max_orb.disable_physics()
	feedback.play_reaction_visuals({
		"type": ReactionRules.Type.MERGE,
		"position": Vector2.ZERO,
		"result_level": 7,
		"result_color": 4,
		"result_orb": max_orb,
		"levels": [6, 6],
		"colors": [4, 4],
	})
	hud._on_preview_changed([
		[{"color": OrbTypes.OrbColor.PURPLE, "level": 7}],
		[{"color": OrbTypes.OrbColor.RED, "level": 7}],
	])
	await get_tree().create_timer(0.16).timeout
	var max_preview: OrbVisual = hud._next_preview.get_child(0) as OrbVisual
	if max_preview.jelly_level() != 7 or max_preview.celestial_level() != 0:
		_fail("JELLY MAX capture NEXT must use the 2D MAX jelly face")
	await _capture("53_jelly_look_max.png")

	feedback.clear_effects()
	_clear_capture_board(board)
	var stretch_directions: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN, Vector2(-1.0, -0.55).normalized()]
	var stretch_positions: Array[Vector2] = [Vector2(-240.0, 0.0), Vector2.ZERO, Vector2(240.0, 0.0)]
	for index: int in range(stretch_positions.size()):
		var stretch_orb: Orb3D = board.spawn_orb(index, 3 + index, stretch_positions[index])
		stretch_orb.disable_physics()
		stretch_orb.linear_velocity = stretch_directions[index] * 1100.0
		stretch_orb._process(0.0)
	await _capture("53_jelly_look_stretch.png")
	_clear_capture_board(board)
	feedback.clear_effects()

	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._hide_callout_label()
	hud._planet_unlock_seen.erase(OrbTypes.OrbColor.PURPLE)
	hud._preview_unlock_seen.erase(OrbTypes.OrbColor.PURPLE)
	hud._on_preview_changed([
		[{"color": OrbTypes.OrbColor.PURPLE, "level": 2}],
		[{"color": OrbTypes.OrbColor.BLUE, "level": 1}],
	])
	hud._on_planet_unlocked(OrbTypes.OrbColor.PURPLE)
	await get_tree().create_timer(0.08).timeout
	var next_jelly: OrbVisual = hud._next_preview.get_child(0) as OrbVisual
	if hud._callout_label.text != "새 젤리 — 보라":
		_fail("JELLY unlock capture must use the new jelly wording")
	if hud._planet_callout_visual.jelly_level() != Hud.PLANET_UNLOCK_ORB_LEVEL:
		_fail("JELLY unlock capture must use jelly callout art")
	if next_jelly.jelly_level() != 2 or next_jelly.celestial_level() != 0:
		_fail("JELLY unlock capture NEXT must use jelly preview art")
	await _capture("53_jelly_look_unlock.png")
	print("SCREEN_CAPTURE_CHECK scene=jelly_look levels=7 crowded=25 absorption=true max=true stretch=true unlock=jelly")
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._hide_callout_label()


func _clear_capture_board(board: Board3D) -> void:
	for orb: Orb3D in board.get_orbs().duplicate():
		board.remove_orb(orb)


func _populate_crowded_board(board: Board3D) -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []
	var coordinates: Array[float] = [-320.0, -160.0, 0.0, 160.0, 320.0]
	var orb_index: int = 0
	for y: float in coordinates:
		for x: float in coordinates:
			var row_index: int = floori(float(orb_index) / float(coordinates.size()))
			var level: int = 1 + (orb_index * 5 + row_index) % 3
			var color: int = (orb_index * 7 + level) % Config.data.color_display.size()
			var position_value: Vector2 = Vector2(x, y)
			var orb: Orb3D = board.spawn_orb(color, level, position_value)
			orb.disable_physics()
			descriptors.append({
				"position": position_value,
				"body_radius": (
					Config.data.radius_for_level(level)
					* CelestialOrbArt.body_radius_ratio(level)
				),
			})
			orb_index += 1
	return descriptors


func _validate_crowded_nebula_contrast(
	main: Main,
	level: int,
	orb_descriptors: Array[Dictionary],
	scene_name: String
) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var camera: Camera3D = main.get_node("Camera3D") as Camera3D
	var image_scale: Vector2 = Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var effect_center: Vector2 = camera.unproject_position(
		Orb3D.plane_position_to_world(Vector2.ZERO)
	) * image_scale
	var sample_radius_px: float = minf(
		Config.data.board_size * Config.data.blast_push_radius_factor_for_level(level),
		Config.data.board_size * 0.43
	)
	var effect_edge: Vector2 = camera.unproject_position(
		Orb3D.plane_position_to_world(Vector2(sample_radius_px, 0.0))
	) * image_scale
	var effect_radius: float = effect_center.distance_to(effect_edge)
	var projected_orbs: Array[Dictionary] = []
	var orb_total: float = 0.0
	var orb_samples: int = 0
	for descriptor: Dictionary in orb_descriptors:
		var position_value: Vector2 = descriptor["position"] as Vector2
		var body_radius_px: float = float(descriptor["body_radius"])
		var center: Vector2 = camera.unproject_position(
			Orb3D.plane_position_to_world(position_value)
		) * image_scale
		var edge: Vector2 = camera.unproject_position(
			Orb3D.plane_position_to_world(position_value + Vector2(body_radius_px, 0.0))
		) * image_scale
		var radius: float = center.distance_to(edge)
		projected_orbs.append({"center": center, "radius": radius})
		if center.distance_to(effect_center) > effect_radius:
			continue
		var core_metrics: Dictionary = _circle_luminance(image, center, radius * 0.52)
		orb_total += float(core_metrics["total"])
		orb_samples += int(core_metrics["count"])
	var background_total: float = 0.0
	var background_samples: int = 0
	var min_x: int = maxi(0, floori(effect_center.x - effect_radius))
	var max_x: int = mini(image.get_width() - 1, ceili(effect_center.x + effect_radius))
	var min_y: int = maxi(0, floori(effect_center.y - effect_radius))
	var max_y: int = mini(image.get_height() - 1, ceili(effect_center.y + effect_radius))
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var point: Vector2 = Vector2(float(x), float(y))
			if point.distance_to(effect_center) > effect_radius:
				continue
			var covered_by_orb: bool = false
			for projected: Dictionary in projected_orbs:
				if point.distance_to(projected["center"] as Vector2) <= float(projected["radius"]) * 1.10:
					covered_by_orb = true
					break
			if covered_by_orb:
				continue
			background_total += image.get_pixel(x, y).get_luminance()
			background_samples += 1
	var orb_average: float = orb_total / float(maxi(orb_samples, 1))
	var background_average: float = background_total / float(maxi(background_samples, 1))
	var ratio: float = orb_average / maxf(background_average, 0.001)
	print(
		"REACTION_PIXEL_CHECK scene=%s orb=%.5f nebula_background=%.5f ratio=%.2f minimum=4.00 orb_samples=%d background_samples=%d" % [
			scene_name,
			orb_average,
			background_average,
			ratio,
			orb_samples,
			background_samples,
		]
	)
	if orb_samples <= 0 or background_samples <= 0:
		_fail("%s crowded nebula contrast has no samples" % scene_name)
	elif ratio < 4.0:
		_fail("%s orb/background luminance ratio %.2f is below 4.0" % [scene_name, ratio])


func _circle_luminance(image: Image, center: Vector2, radius: float) -> Dictionary:
	var min_x: int = maxi(0, floori(center.x - radius))
	var max_x: int = mini(image.get_width() - 1, ceili(center.x + radius))
	var min_y: int = maxi(0, floori(center.y - radius))
	var max_y: int = mini(image.get_height() - 1, ceili(center.y + radius))
	var radius_squared: float = radius * radius
	var total: float = 0.0
	var count: int = 0
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			if Vector2(float(x), float(y)).distance_squared_to(center) > radius_squared:
				continue
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return {"total": total, "count": count}


func _measure_same_size_planet_glow() -> void:
	var main: Main = await _create_main(Main.NO_MODE)
	(main.get_node("UI") as CanvasLayer).visible = false
	(main.get_node("Board") as Board3D).visible = false
	(main.get_node("SpaceBackdrop") as SpaceBackdrop).visible = false
	var target_outer_radius_px: float = 120.0
	var centers: Array[Vector2] = [Vector2(-130.0, 0.0), Vector2(130.0, 0.0)]
	var levels: Array[int] = [6, 7]
	for index: int in range(levels.size()):
		var level: int = levels[index]
		var orb: Orb3D = ORB_3D_SCENE.instantiate() as Orb3D
		main.add_child(orb)
		orb.setup(OrbTypes.OrbColor.BLUE, level, Config.data)
		orb.disable_physics()
		orb.set_process(false)
		orb.set_physics_process(false)
		orb.set_render_clamp_enabled(false)
		orb.position = centers[index]
		var outer_scale: float = target_outer_radius_px / Config.data.radius_for_level(level)
		orb._mesh.scale = Vector3.ONE * outer_scale
		orb._adornment.scale = Vector3.ONE * (target_outer_radius_px / Orb3D.PIXELS_PER_METER)
		orb._blast_outline.visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var camera: Camera3D = main.get_node("Camera3D") as Camera3D
	var image_scale: Vector2 = Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var projected_outer_radius: float = absf(
		(camera.unproject_position(Orb3D.plane_position_to_world(Vector2(target_outer_radius_px, 0.0))) * image_scale).x
		- (camera.unproject_position(Orb3D.plane_position_to_world(Vector2.ZERO)) * image_scale).x
	)
	var luminance: Array[float] = []
	for index: int in range(centers.size()):
		var center_position: Vector2 = centers[index]
		var center: Vector2 = camera.unproject_position(
			Orb3D.plane_position_to_world(center_position)
		) * image_scale
		var body_ratio: float = CelestialOrbArt.body_radius_ratio(levels[index])
		luminance.append(
			_annulus_average_luminance(
				image,
				center,
				projected_outer_radius * (body_ratio + 0.015),
				projected_outer_radius * 0.975
			)
		)
	print(
		"REACTION_PIXEL_CHECK scene=same_size_planet_glow l6=%.5f l7=%.5f" % [
			luminance[0],
			luminance[1],
		]
	)
	if luminance[1] <= luminance[0]:
		_fail(
			"Same-size L7 outline luminance %.5f must exceed L6 %.5f" % [
				luminance[1],
				luminance[0],
			]
		)
	await _destroy_main(main)


func _annulus_average_luminance(
	image: Image,
	center: Vector2,
	inner_radius: float,
	outer_radius: float
) -> float:
	var min_x: int = maxi(0, floori(center.x - outer_radius))
	var max_x: int = mini(image.get_width() - 1, ceili(center.x + outer_radius))
	var min_y: int = maxi(0, floori(center.y - outer_radius))
	var max_y: int = mini(image.get_height() - 1, ceili(center.y + outer_radius))
	var inner_squared: float = inner_radius * inner_radius
	var outer_squared: float = outer_radius * outer_radius
	var total: float = 0.0
	var count: int = 0
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var distance_squared: float = Vector2(float(x), float(y)).distance_squared_to(center)
			if distance_squared < inner_squared or distance_squared > outer_squared:
				continue
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return total / float(maxi(count, 1))


func _average_luminance_outside_circle(
	image: Image,
	center: Vector2,
	radius: float
) -> float:
	var total: float = 0.0
	var count: int = 0
	var radius_squared: float = radius * radius
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if Vector2(float(x), float(y)).distance_squared_to(center) <= radius_squared:
				continue
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return total / float(maxi(count, 1))


func _disk_average_luminance(image: Image, center: Vector2, radius: float) -> float:
	var min_x: int = maxi(0, floori(center.x - radius))
	var max_x: int = mini(image.get_width() - 1, ceili(center.x + radius))
	var min_y: int = maxi(0, floori(center.y - radius))
	var max_y: int = mini(image.get_height() - 1, ceili(center.y + radius))
	var radius_squared: float = radius * radius
	var total: float = 0.0
	var count: int = 0
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			if Vector2(float(x), float(y)).distance_squared_to(center) > radius_squared:
				continue
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return total / float(maxi(count, 1))


func _measure_v2_contrast() -> void:
	var main: Main = await _create_main(Main.NO_MODE)
	(main.get_node("UI") as CanvasLayer).visible = false
	var board: Board3D = main.get_node("Board") as Board3D
	board.visible = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var empty_image: Image = get_viewport().get_texture().get_image()
	var camera: Camera3D = main.get_node("Camera3D") as Camera3D
	var backdrop: SpaceBackdrop = main.get_node("SpaceBackdrop") as SpaceBackdrop
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var image_scale: Vector2 = Vector2(
		float(empty_image.get_width()) / viewport_size.x,
		float(empty_image.get_height()) / viewport_size.y
	)
	var board_half: float = board.half_size()
	var board_top_left: Vector2 = camera.unproject_position(
		Orb3D.plane_position_to_world(Vector2(-board_half, -board_half))
	) * image_scale
	var board_bottom_right: Vector2 = camera.unproject_position(
		Orb3D.plane_position_to_world(Vector2(board_half, board_half))
	) * image_scale
	var board_rect: Rect2 = Rect2(
		Vector2(
			minf(board_top_left.x, board_bottom_right.x),
			minf(board_top_left.y, board_bottom_right.y)
		),
		Vector2(
			absf(board_bottom_right.x - board_top_left.x),
			absf(board_bottom_right.y - board_top_left.y)
		)
	)
	var inner_rect: Rect2 = board_rect.grow(-board_rect.size.x * 0.08)
	var empty_board_average: float = _average_luminance(empty_image, inner_rect)
	var background_maximum: float = _maximum_luminance_outside(empty_image, board_rect.grow(6.0))
	board.set_danger_state(0.70, 4.0)
	board._process(0.625)
	backdrop._process(0.625)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var danger_background_image: Image = get_viewport().get_texture().get_image()
	board.set_danger_state(0.0, 1.0)
	board._process(0.0)
	backdrop._process(0.0)
	var crowded_image: Image = Image.load_from_file(
		ProjectSettings.globalize_path(_output_directory.path_join("07_blitz_danger.png"))
	)
	var danger_image: Image = Image.load_from_file(
		ProjectSettings.globalize_path(_output_directory.path_join("17_board_danger.png"))
	)
	var blocked_image: Image = Image.load_from_file(
		ProjectSettings.globalize_path(_output_directory.path_join("18_board_blocked.png"))
	)
	var crowded_metrics: Dictionary = _crowded_board_luminance(crowded_image, inner_rect)
	var orb_average: float = float(crowded_metrics["orb_average"])
	var crowded_board_average: float = float(crowded_metrics["board_average"])
	var ratio: float = orb_average / maxf(crowded_board_average, 0.001)
	var danger_band: Color = _average_frame_band_color(danger_image, board_rect, 4.0, 10.0)
	var normal_background_red: float = _background_red_average(empty_image, board_rect)
	var danger_background_red: float = _background_red_average(danger_background_image, board_rect)
	var background_red_gain: float = (danger_background_red - normal_background_red) * 255.0
	var blocked_top: Color = _average_side_band_color(
		blocked_image, board_rect, Vector2i.UP, 4.0, 10.0
	)
	print(
		"SPACE_CONTRAST empty_board_average=%.4f background_maximum=%.4f crowded_orb_average=%.4f crowded_board_average=%.4f orb_board_ratio=%.2f" % [
			empty_board_average,
			background_maximum,
			orb_average,
			crowded_board_average,
			ratio,
		]
	)
	print(
		"SPACE_DANGER_BAND r=%.1f g=%.1f b=%.1f background_red_gain=%.1f" % [
			danger_band.r * 255.0,
			danger_band.g * 255.0,
			danger_band.b * 255.0,
			background_red_gain,
		]
	)
	print(
		"SPACE_BLOCKED_BAND wall=TOP r=%.1f g=%.1f b=%.1f expected=normal" % [
			blocked_top.r * 255.0,
			blocked_top.g * 255.0,
			blocked_top.b * 255.0,
		]
	)
	if empty_board_average > 0.10:
		_fail("Empty board average luminance %.4f exceeds 0.10" % empty_board_average)
	if background_maximum > 0.60:
		_fail("Space background maximum luminance %.4f exceeds 0.60" % background_maximum)
	if danger_band.r * 255.0 < 90.0:
		_fail("Danger outer band red %.1f is below 90" % (danger_band.r * 255.0))
	if danger_band.r < danger_band.g * 2.0 or danger_band.r < danger_band.b * 2.0:
		_fail("Danger outer band is not red-dominant at the pulse minimum")
	if background_red_gain < 20.0:
		_fail("Danger nebula red gain %.1f is below 20" % background_red_gain)
	if blocked_top.r > maxf(blocked_top.g, blocked_top.b) * 1.5:
		_fail("Blocked top wall still has a red-dominant warning band")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MEASUREMENT_DIRECTORY))
	var report_path: String = MEASUREMENT_DIRECTORY.path_join("space_contrast_report.json")
	var report_file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if report_file == null:
		_fail("Could not write space contrast report")
	else:
		report_file.store_string(JSON.stringify({
			"empty_board_average_luminance": empty_board_average,
			"empty_board_maximum": 0.10,
			"background_maximum_luminance": background_maximum,
			"background_maximum": 0.60,
			"crowded_capture": "07_blitz_danger.png",
			"crowded_orb_average_luminance": orb_average,
			"crowded_board_average_luminance": crowded_board_average,
			"crowded_orb_to_board_ratio": ratio,
			"crowded_segmentation": "orb>=0.16, board<=0.10",
			"danger_outer_band_rgb_255": [
				danger_band.r * 255.0,
				danger_band.g * 255.0,
				danger_band.b * 255.0,
			],
			"danger_background_red_gain_255": background_red_gain,
			"blocked_top_normal_band_rgb_255": [
				blocked_top.r * 255.0,
				blocked_top.g * 255.0,
				blocked_top.b * 255.0,
			],
		}, "  "))
	await _destroy_main(main)


func _measure_gravity_wall_lights() -> void:
	var main: Main = await _create_main(Main.NO_MODE)
	(main.get_node("UI") as CanvasLayer).visible = false
	var board: Board3D = main.get_node("Board") as Board3D
	board.visible = true
	var camera: Camera3D = main.get_node("Camera3D") as Camera3D
	board.set_process(false)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var board_half: float = board.half_size()
	var measurements: Dictionary = {}
	for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		board.set_gravity(direction)
		board._process(Board3D.GRAVITY_FIELD_DURATION)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var image_scale: Vector2 = Vector2(
			float(image.get_width()) / viewport_size.x,
			float(image.get_height()) / viewport_size.y
		)
		var center_point: Vector2 = _wall_sample_point(direction, board_half, 0.0)
		var first_end: Vector2 = _wall_sample_point(direction, board_half, -board_half * 0.72)
		var second_end: Vector2 = _wall_sample_point(direction, board_half, board_half * 0.72)
		var center_luminance: float = _point_luminance(
			image, camera.unproject_position(Orb3D.plane_position_to_world(center_point)) * image_scale
		)
		var first_end_luminance: float = _point_luminance(
			image, camera.unproject_position(Orb3D.plane_position_to_world(first_end)) * image_scale
		)
		var second_end_luminance: float = _point_luminance(
			image, camera.unproject_position(Orb3D.plane_position_to_world(second_end)) * image_scale
		)
		var other_maximum: float = 0.0
		for other_direction: Vector2i in [
			Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT
		]:
			if other_direction == direction:
				continue
			var other_point: Vector2 = _wall_sample_point(other_direction, board_half, 0.0)
			other_maximum = maxf(
				other_maximum,
				_point_luminance(
					image,
					camera.unproject_position(Orb3D.plane_position_to_world(other_point)) * image_scale
				)
			)
		print(
			"GRAVITY_WALL_LIGHT direction=%s center=%.4f end_a=%.4f end_b=%.4f other_max=%.4f" % [
				_direction_name(direction),
				center_luminance,
				first_end_luminance,
				second_end_luminance,
				other_maximum,
			]
		)
		if center_luminance < first_end_luminance or center_luminance < second_end_luminance:
			_fail("Gravity wall center must be at least as bright as both ends")
		if center_luminance < other_maximum * 1.5:
			_fail("Gravity wall center must be 1.5x brighter than the other wall centers")
		measurements[_direction_name(direction)] = {
			"center": center_luminance,
			"end_a": first_end_luminance,
			"end_b": second_end_luminance,
			"other_maximum": other_maximum,
		}
	board.set_gravity(Vector2i.DOWN)
	board._process(Board3D.GRAVITY_LIGHT_DURATION)
	board.set_gravity(Vector2i.RIGHT)
	board._process(Board3D.GRAVITY_LIGHT_DURATION * 0.5)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var transition_image: Image = get_viewport().get_texture().get_image()
	var transition_scale: Vector2 = Vector2(
		float(transition_image.get_width()) / viewport_size.x,
		float(transition_image.get_height()) / viewport_size.y
	)
	var corner_offset: float = board_half * 0.84
	var bottom_right: float = _point_luminance(
		transition_image,
		camera.unproject_position(
			Orb3D.plane_position_to_world(Vector2(corner_offset, board_half))
		) * transition_scale
	)
	var right_bottom: float = _point_luminance(
		transition_image,
		camera.unproject_position(
			Orb3D.plane_position_to_world(Vector2(board_half, corner_offset))
		) * transition_scale
	)
	var bottom_left: float = _point_luminance(
		transition_image,
		camera.unproject_position(
			Orb3D.plane_position_to_world(Vector2(-corner_offset, board_half))
		) * transition_scale
	)
	var left_bottom: float = _point_luminance(
		transition_image,
		camera.unproject_position(
			Orb3D.plane_position_to_world(Vector2(-board_half, corner_offset))
		) * transition_scale
	)
	var target_corner: float = (bottom_right + right_bottom) * 0.5
	var opposite_corner: float = (bottom_left + left_bottom) * 0.5
	print(
		"GRAVITY_WALL_TRANSITION from=DOWN to=RIGHT target_corner=%.4f opposite_corner=%.4f" % [
			target_corner,
			opposite_corner,
		]
	)
	if target_corner <= opposite_corner:
		_fail("DOWN to RIGHT gravity light must travel through the bottom-right corner")
	measurements["DOWN_TO_RIGHT"] = {
		"target_corner": target_corner,
		"opposite_corner": opposite_corner,
	}
	var report_path: String = MEASUREMENT_DIRECTORY.path_join("gravity_wall_light_report.json")
	var report_file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if report_file == null:
		_fail("Could not write gravity wall light report")
	else:
		report_file.store_string(JSON.stringify(measurements, "  "))
	await _destroy_main(main)


func _wall_sample_point(direction: Vector2i, half_size: float, along: float) -> Vector2:
	if direction == Vector2i.UP:
		return Vector2(along, -half_size)
	if direction == Vector2i.RIGHT:
		return Vector2(half_size, along)
	if direction == Vector2i.DOWN:
		return Vector2(along, half_size)
	return Vector2(-half_size, along)


func _direction_name(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "UP"
	if direction == Vector2i.RIGHT:
		return "RIGHT"
	if direction == Vector2i.DOWN:
		return "DOWN"
	return "LEFT"


func _point_luminance(image: Image, point: Vector2) -> float:
	var center_x: int = clampi(roundi(point.x), 0, image.get_width() - 1)
	var center_y: int = clampi(roundi(point.y), 0, image.get_height() - 1)
	var total: float = 0.0
	var count: int = 0
	for y: int in range(maxi(center_y - 2, 0), mini(center_y + 2, image.get_height() - 1) + 1):
		for x: int in range(maxi(center_x - 2, 0), mini(center_x + 2, image.get_width() - 1) + 1):
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return total / float(maxi(count, 1))


func _average_frame_band_color(
	image: Image,
	board_rect: Rect2,
	inner_distance: float,
	outer_distance: float
) -> Color:
	var total: Color = Color(0.0, 0.0, 0.0, 0.0)
	for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		total += _average_side_band_color(
			image, board_rect, direction, inner_distance, outer_distance
		)
	return total / 4.0


func _average_side_band_color(
	image: Image,
	board_rect: Rect2,
	direction: Vector2i,
	inner_distance: float,
	outer_distance: float
) -> Color:
	var corner_margin: float = board_rect.size.x * 0.04
	var region: Rect2
	if direction == Vector2i.UP:
		region = Rect2(
			board_rect.position.x + corner_margin,
			board_rect.position.y - outer_distance,
			board_rect.size.x - corner_margin * 2.0,
			outer_distance - inner_distance
		)
	elif direction == Vector2i.RIGHT:
		region = Rect2(
			board_rect.end.x + inner_distance,
			board_rect.position.y + corner_margin,
			outer_distance - inner_distance,
			board_rect.size.y - corner_margin * 2.0
		)
	elif direction == Vector2i.DOWN:
		region = Rect2(
			board_rect.position.x + corner_margin,
			board_rect.end.y + inner_distance,
			board_rect.size.x - corner_margin * 2.0,
			outer_distance - inner_distance
		)
	else:
		region = Rect2(
			board_rect.position.x - outer_distance,
			board_rect.position.y + corner_margin,
			outer_distance - inner_distance,
			board_rect.size.y - corner_margin * 2.0
		)
	return _average_color(image, region)


func _average_color(image: Image, region: Rect2) -> Color:
	var min_x: int = clampi(floori(region.position.x), 0, image.get_width() - 1)
	var max_x: int = clampi(ceili(region.end.x), 0, image.get_width() - 1)
	var min_y: int = clampi(floori(region.position.y), 0, image.get_height() - 1)
	var max_y: int = clampi(ceili(region.end.y), 0, image.get_height() - 1)
	var total: Color = Color(0.0, 0.0, 0.0, 0.0)
	var count: int = 0
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			total += image.get_pixel(x, y)
			count += 1
	return total / float(maxi(count, 1))


func _background_red_average(image: Image, board_rect: Rect2) -> float:
	var top: float = board_rect.end.y + 18.0
	var bottom: float = minf(board_rect.end.y + 80.0, float(image.get_height()))
	if bottom <= top:
		return 0.0
	return _average_color(
		image,
		Rect2(0.0, top, float(image.get_width()), bottom - top)
	).r


func _average_luminance(image: Image, region: Rect2) -> float:
	var min_x: int = clampi(floori(region.position.x), 0, image.get_width() - 1)
	var max_x: int = clampi(ceili(region.end.x), 0, image.get_width() - 1)
	var min_y: int = clampi(floori(region.position.y), 0, image.get_height() - 1)
	var max_y: int = clampi(ceili(region.end.y), 0, image.get_height() - 1)
	var total: float = 0.0
	var count: int = 0
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return total / float(maxi(count, 1))


func _maximum_luminance_outside(image: Image, excluded: Rect2) -> float:
	var maximum: float = 0.0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if excluded.has_point(Vector2(float(x), float(y))):
				continue
			maximum = maxf(maximum, image.get_pixel(x, y).get_luminance())
	return maximum


func _crowded_board_luminance(image: Image, region: Rect2) -> Dictionary:
	var min_x: int = clampi(floori(region.position.x), 0, image.get_width() - 1)
	var max_x: int = clampi(ceili(region.end.x), 0, image.get_width() - 1)
	var min_y: int = clampi(floori(region.position.y), 0, image.get_height() - 1)
	var max_y: int = clampi(ceili(region.end.y), 0, image.get_height() - 1)
	var orb_total: float = 0.0
	var orb_count: int = 0
	var board_total: float = 0.0
	var board_count: int = 0
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var luminance: float = image.get_pixel(x, y).get_luminance()
			if luminance >= 0.16:
				orb_total += luminance
				orb_count += 1
			elif luminance <= 0.10:
				board_total += luminance
				board_count += 1
	return {
		"orb_average": orb_total / float(maxi(orb_count, 1)),
		"board_average": board_total / float(maxi(board_count, 1)),
		"orb_samples": orb_count,
		"board_samples": board_count,
	}


func _analyze_orb_codex(camera: Camera3D, descriptors: Array[Dictionary]) -> void:
	var image_path: String = _output_directory.path_join("14_orb_codex.png")
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(image_path))
	if image == null or image.is_empty():
		_fail("Could not load orb codex for color analysis")
		return
	var samples: Dictionary = {}
	var seam_center_sum: float = 0.0
	var seam_surrounding_sum: float = 0.0
	var seam_sample_count: int = 0
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
		var body_radius: float = (
			screen_radius * CelestialOrbArt.body_radius_ratio(int(descriptor["level"]))
		)
		var seam_metrics: Dictionary = _seam_column_metrics(image, screen_center, body_radius)
		var lab: Vector3 = _color_to_lab(average)
		var reference: Color = Config.data.color_display[int(descriptor["color"])]
		var reference_lab: Vector3 = _color_to_lab(reference)
		var hue_error: float = _hue_angle_difference(lab, reference_lab)
		var key: String = "%d:%d" % [int(descriptor["level"]), int(descriptor["color"])]
		samples[key] = {
			"rgb": [average.r, average.g, average.b],
			"luminance": average.get_luminance(),
			"lab": [lab.x, lab.y, lab.z],
			"hue_error_deg": hue_error,
			"seam_center_difference": seam_metrics["center_difference"],
			"seam_surrounding_difference": seam_metrics["surrounding_difference"],
			"seam_ratio": seam_metrics["ratio"],
		}
		seam_center_sum += float(seam_metrics["center_difference"])
		seam_surrounding_sum += float(seam_metrics["surrounding_difference"])
		seam_sample_count += 1
	var seam_center_average: float = seam_center_sum / float(seam_sample_count)
	var seam_surrounding_average: float = seam_surrounding_sum / float(seam_sample_count)
	var seam_ratio: float = seam_center_average / maxf(seam_surrounding_average, 0.002)
	print(
		"ORB_CODEX_SEAM center_average=%.5f surrounding_average=%.5f ratio=%.2f" % [
			seam_center_average,
			seam_surrounding_average,
			seam_ratio,
		]
	)
	if seam_ratio > 2.0:
		_fail("Orb codex aggregate seam ratio %.2f exceeds 2.0" % seam_ratio)
	var reference_min_delta_e: float = INF
	var reference_min_gray_difference: float = INF
	var reference_closest_gray_pair: Array[int] = [-1, -1]
	for first_color: int in range(Config.data.color_display.size()):
		for second_color: int in range(first_color + 1, Config.data.color_display.size()):
			reference_min_delta_e = minf(
				reference_min_delta_e,
				_color_to_lab(Config.data.color_display[first_color]).distance_to(
					_color_to_lab(Config.data.color_display[second_color])
				)
			)
			var gray_difference: float = absf(
				Config.data.color_display[first_color].get_luminance()
				- Config.data.color_display[second_color].get_luminance()
			)
			if gray_difference < reference_min_gray_difference:
				reference_min_gray_difference = gray_difference
				reference_closest_gray_pair = [first_color, second_color]
	var levels: Array[Dictionary] = []
	for level: int in range(1, Config.data.orb_max_level + 1):
		var minimum_delta_e: float = INF
		var maximum_hue_error: float = 0.0
		var maximum_seam_ratio: float = 0.0
		var minimum_gray_difference: float = INF
		var closest_gray_pair: Array[int] = [-1, -1]
		var color_samples: Array[Dictionary] = []
		for color: int in range(Config.data.color_display.size()):
			var sample: Dictionary = samples["%d:%d" % [level, color]] as Dictionary
			maximum_hue_error = maxf(maximum_hue_error, float(sample["hue_error_deg"]))
			maximum_seam_ratio = maxf(maximum_seam_ratio, float(sample["seam_ratio"]))
			color_samples.append({
				"color": color,
				"rgb": sample["rgb"],
				"luminance": sample["luminance"],
				"lab": sample["lab"],
				"hue_error_deg": sample["hue_error_deg"],
				"seam_center_difference": sample["seam_center_difference"],
				"seam_surrounding_difference": sample["seam_surrounding_difference"],
				"seam_ratio": sample["seam_ratio"],
			})
			var first_lab_values: Array = sample["lab"] as Array
			var first_lab: Vector3 = Vector3(
				float(first_lab_values[0]),
				float(first_lab_values[1]),
				float(first_lab_values[2])
			)
			for second_color: int in range(color + 1, Config.data.color_display.size()):
				var second_sample: Dictionary = samples["%d:%d" % [level, second_color]] as Dictionary
				var gray_difference: float = absf(
					float(sample["luminance"]) - float(second_sample["luminance"])
				)
				if gray_difference < minimum_gray_difference:
					minimum_gray_difference = gray_difference
					closest_gray_pair = [color, second_color]
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
			"maximum_seam_ratio": maximum_seam_ratio,
			"minimum_grayscale_luminance_difference": minimum_gray_difference,
			"closest_grayscale_color_pair": closest_gray_pair,
			"colors": color_samples,
		})
		print(
			"ORB_CODEX_COLOR level=%d min_delta_e=%.2f max_hue_error=%.2f max_seam_ratio=%.2f min_gray=%.5f gray_pair=%s" % [
				level,
				minimum_delta_e,
				maximum_hue_error,
				maximum_seam_ratio,
				minimum_gray_difference,
				str(closest_gray_pair),
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
		"reference_minimum_grayscale_luminance_difference": reference_min_gray_difference,
		"reference_closest_grayscale_color_pair": reference_closest_gray_pair,
		"seam_check": {
			"center_average": seam_center_average,
			"surrounding_average": seam_surrounding_average,
			"ratio": seam_ratio,
			"maximum_ratio": 2.0,
		},
		"levels": levels,
	}, "  "))
	print(
		"ORB_CODEX_REFERENCE min_delta_e=%.2f min_gray=%.5f gray_pair=%s report=%s" % [
			reference_min_delta_e,
			reference_min_gray_difference,
			str(reference_closest_gray_pair),
			report_path,
		]
	)


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


func _seam_column_metrics(image: Image, center: Vector2, radius: float) -> Dictionary:
	var left_center_x: int = floori(center.x - 0.5)
	var right_center_x: int = left_center_x + 1
	var center_difference: float = _body_column_pair_difference(
		image,
		left_center_x,
		right_center_x,
		center.y,
		radius
	)
	var surrounding_sum: float = 0.0
	var surrounding_count: int = 0
	for left_x: int in range(left_center_x - 7, right_center_x + 7):
		if left_x == left_center_x:
			continue
		surrounding_sum += _body_column_pair_difference(
			image,
			left_x,
			left_x + 1,
			center.y,
			radius
		)
		surrounding_count += 1
	var surrounding_difference: float = surrounding_sum / float(surrounding_count)
	return {
		"center_difference": center_difference,
		"surrounding_difference": surrounding_difference,
		"ratio": center_difference / maxf(surrounding_difference, 0.002),
	}


func _body_column_pair_difference(
	image: Image,
	left_x: int,
	right_x: int,
	center_y: float,
	radius: float
) -> float:
	var min_y: int = maxi(0, floori(center_y - radius * 0.72))
	var max_y: int = mini(image.get_height() - 1, ceili(center_y + radius * 0.72))
	var safe_left_x: int = clampi(left_x, 0, image.get_width() - 1)
	var safe_right_x: int = clampi(right_x, 0, image.get_width() - 1)
	var difference_sum: float = 0.0
	var sample_count: int = 0
	for y: int in range(min_y, max_y + 1):
		if absf(float(y) + 0.5 - center_y) < radius * 0.34:
			continue
		difference_sum += _rgb_distance(
			image.get_pixel(safe_left_x, y),
			image.get_pixel(safe_right_x, y)
		)
		sample_count += 1
	if sample_count <= 0:
		return 0.0
	return difference_sum / float(sample_count)


func _rgb_distance(first: Color, second: Color) -> float:
	return Vector3(first.r, first.g, first.b).distance_to(
		Vector3(second.r, second.g, second.b)
	)


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
		var game_mode: GameConfig.GameMode = GameConfig.GameMode.TURN
		if mode == int(GameConfig.GameMode.BLITZ):
			game_mode = GameConfig.GameMode.BLITZ
		elif mode == int(GameConfig.GameMode.JELLY):
			game_mode = GameConfig.GameMode.JELLY
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
	var path: String = _output_directory.path_join(file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		_fail("Could not save %s: %s" % [path, error_string(error)])
		return
	print("SCREEN_CAPTURE file=%s size=%dx%d" % [path, image.get_width(), image.get_height()])


func _write_board_projection_report(main: Main, board: Board3D) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var camera: Camera3D = main.get_node("Camera3D") as Camera3D
	var logical_size: Vector2 = get_viewport().get_visible_rect().size
	var image: Image = get_viewport().get_texture().get_image()
	var image_scale: Vector2 = Vector2(image.get_size()) / logical_size
	var outer_half_m: float = (
		board.half_size() / Board3D.PIXELS_PER_METER
		+ Board3D.OUTER_GLOW_WIDTH_M * 0.5
	)
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	var corners: Array[Vector2] = [
		Vector2(-outer_half_m, -outer_half_m),
		Vector2(outer_half_m, -outer_half_m),
		Vector2(outer_half_m, outer_half_m),
		Vector2(-outer_half_m, outer_half_m),
	]
	for corner: Vector2 in corners:
		var projected: Vector2 = camera.unproject_position(
			board.to_global(Vector3(corner.x, corner.y, 0.0))
		)
		minimum = minimum.min(projected)
		maximum = maximum.max(projected)
	var logical_rect: Rect2 = Rect2(minimum, maximum - minimum)
	var report: Dictionary = {
		"logical_size": {"x": logical_size.x, "y": logical_size.y},
		"image_size": {"x": image.get_width(), "y": image.get_height()},
		"keep_aspect": camera.keep_aspect,
		"fov_degrees": camera.fov,
		"logical": {
			"left": logical_rect.position.x,
			"right": logical_rect.end.x,
			"width": logical_rect.size.x,
		},
		"pixels": {
			"left": logical_rect.position.x * image_scale.x,
			"right": logical_rect.end.x * image_scale.x,
			"width": logical_rect.size.x * image_scale.x,
		},
	}
	var path: String = _output_directory.path_join("board_projection.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write board projection report")
		return
	file.store_string(JSON.stringify(report, "  "))
	print(
		"SCREEN_CAPTURE_BOARD ratio=%dx%d left=%.3f right=%.3f width=%.3f" % [
			image.get_width(), image.get_height(),
			float((report["pixels"] as Dictionary)["left"]),
			float((report["pixels"] as Dictionary)["right"]),
			float((report["pixels"] as Dictionary)["width"]),
		]
	)


func _write_turn_input_cue_report(main: Main) -> void:
	var indicator: TurnInputIndicator = main.get_node(
		"UI/Hud/TurnInputIndicator"
	) as TurnInputIndicator
	var board_rect: Rect2 = indicator._projected_board_rect()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var top_hud_bottom: float = 0.0
	for node_path: String in [
		"UI/Hud/ScorePanel",
		"UI/Hud/BestPanel",
		"UI/Hud/DangerPanel",
		"UI/Hud/MaxComboLabel",
		"UI/Hud/MultiplierLabel",
		"UI/Hud/ComboLabel",
	]:
		var top_control: Control = main.get_node(node_path) as Control
		top_hud_bottom = maxf(top_hud_bottom, top_control.get_global_rect().end.y)
	var shelf: Control = main.get_node("UI/Hud/PreviewShelf") as Control
	var shelf_top: float = shelf.get_global_rect().position.y
	var arrow_bounds: Dictionary = {}
	var arrows_inside_viewport: bool = true
	var arrows_outside_board: bool = true
	for direction: Vector2i in OrbTypes.DIRECTIONS:
		var bounds: Rect2 = indicator.arrow_bounds(board_rect, direction)
		var mark_bounds: Rect2 = indicator.blocked_mark_bounds(board_rect, direction)
		arrow_bounds[OrbTypes.dir_name(direction)] = {
			"left": bounds.position.x,
			"top": bounds.position.y,
			"right": bounds.end.x,
			"bottom": bounds.end.y,
		}
		arrows_inside_viewport = (
			arrows_inside_viewport
			and viewport_rect.encloses(bounds)
			and viewport_rect.encloses(mark_bounds)
		)
		arrows_outside_board = arrows_outside_board and _cue_bounds_outside_board(
			bounds, board_rect, direction
		) and _cue_bounds_outside_board(mark_bounds, board_rect, direction)
	var top_arrow: Rect2 = indicator.arrow_bounds(board_rect, Vector2i.UP)
	var bottom_arrow: Rect2 = indicator.arrow_bounds(board_rect, Vector2i.DOWN)
	var top_mark: Rect2 = indicator.blocked_mark_bounds(board_rect, Vector2i.UP)
	var bottom_mark: Rect2 = indicator.blocked_mark_bounds(board_rect, Vector2i.DOWN)
	var top_hud_clear: bool = minf(top_arrow.position.y, top_mark.position.y) >= top_hud_bottom
	var shelf_clear: bool = bottom_arrow.end.y <= shelf_top
	shelf_clear = shelf_clear and bottom_mark.end.y <= shelf_top
	if not arrows_inside_viewport:
		_fail("Turn input arrows leave the visible HUD canvas")
	if not arrows_outside_board:
		_fail("Turn input arrows enter the board interior")
	if not top_hud_clear:
		_fail("Turn input top arrow overlaps the multiplier/combo HUD")
	if not shelf_clear:
		_fail("Turn input bottom arrow overlaps the preview shelf")
	var report: Dictionary = {
		"arrow_size_logical_px": indicator.arrow_size(),
		"arrow_appear_scale": [0.8, 1.0],
		"arrow_breath_alpha": [
			TurnInputIndicator.BREATH_ALPHA_MIN,
			TurnInputIndicator.BREATH_ALPHA_MAX,
		],
		"arrow_breath_seconds": TurnInputIndicator.BREATH_DURATION,
		"orbit_light_diameter_logical_px": indicator.orbit_light_diameter(),
		"orbit_trail_logical_px": indicator.orbit_trail_length(board_rect),
		"orbit_trail_side_fraction": TurnInputIndicator.ORBIT_TRAIL_SIDE_FRACTION,
		"board": {
			"left": board_rect.position.x,
			"top": board_rect.position.y,
			"right": board_rect.end.x,
			"bottom": board_rect.end.y,
		},
		"arrow_bounds": arrow_bounds,
		"arrows_inside_viewport": arrows_inside_viewport,
		"arrows_outside_board": arrows_outside_board,
		"top_hud_bottom": top_hud_bottom,
		"preview_shelf_top": shelf_top,
		"top_hud_clear": top_hud_clear,
		"preview_shelf_clear": shelf_clear,
	}
	var path: String = _output_directory.path_join("turn_input_cue.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write turn input cue report")
		return
	file.store_string(JSON.stringify(report, "  "))
	print(
		"TURN_INPUT_CUE arrow=%.1f orbit=%.1f trail=%.1f top_clear=%s shelf_clear=%s" % [
			indicator.arrow_size(),
			indicator.orbit_light_diameter(),
			indicator.orbit_trail_length(board_rect),
			str(top_hud_clear),
			str(shelf_clear),
		]
	)


func _cue_bounds_outside_board(
	bounds: Rect2,
	board_rect: Rect2,
	direction: Vector2i
) -> bool:
	if direction == Vector2i.LEFT:
		return bounds.end.x <= board_rect.position.x + 0.001
	if direction == Vector2i.RIGHT:
		return bounds.position.x >= board_rect.end.x - 0.001
	if direction == Vector2i.UP:
		return bounds.end.y <= board_rect.position.y + 0.001
	return bounds.position.y >= board_rect.end.y - 0.001


func _prepare_output_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_directory))
	for file_name: String in CAPTURE_FILES:
		_remove_file(_output_directory.path_join(file_name))
	_remove_file(_output_directory.path_join("board_projection.json"))
	_remove_file(_output_directory.path_join("turn_input_cue.json"))
	_remove_file(_temp_save_path)


func _verify_capture_files() -> void:
	var expected_files: Array[String] = HUD_CAPTURE_FILES if _hud_scenes_only else CAPTURE_FILES
	for file_name: String in expected_files:
		var path: String = _output_directory.path_join(file_name)
		if not FileAccess.file_exists(path):
			_fail("Missing capture %s" % path)


func _validate_turn_game_over_scene(main: Main) -> void:
	var blocked: Label = main.get_node("UI/Hud/BlockedLabel") as Label
	if not blocked.visible:
		_fail("TURN game-over capture must show blocked direction")
	_expect_label_text(blocked, "← 막힘", "TURN HUD blocked direction")
	_expect_label_text(
		main.get_node("UI/Hud/ScoreLabel") as Label,
		str(TURN_CAPTURE_SCORE),
		"TURN HUD score"
	)
	_expect_label_text(
		main.get_node("UI/Hud/GameOverPanel/Margin/Content/GameOverScore") as Label,
		"9,999,999",
		"TURN result score"
	)
	_expect_label_text(
		main.get_node("UI/Hud/GameOverPanel/Margin/Content/ResultExtraValue") as Label,
		"LEFT",
		"TURN result blocked direction"
	)
	print("SCREEN_CAPTURE_CHECK scene=turn_game_over score=%d blocked=LEFT" % TURN_CAPTURE_SCORE)


func _validate_turn_blocked_scene(main: Main) -> void:
	var blocked: Label = main.get_node("UI/Hud/BlockedLabel") as Label
	var game_over_panel: Control = main.get_node("UI/Hud/GameOverPanel") as Control
	if not blocked.visible:
		_fail("TURN blocked capture must show the blocked direction")
	_expect_label_text(blocked, "↓ 막힘", "TURN blocked-only HUD direction")
	if game_over_panel.visible:
		_fail("TURN blocked capture must not show the game-over panel")
	print("SCREEN_CAPTURE_CHECK scene=board_blocked blocked=DOWN game_over=false")


func _validate_turn_blocked_pixels(main: Main) -> void:
	var image: Image = Image.load_from_file(
		ProjectSettings.globalize_path(_output_directory.path_join("18_board_blocked.png"))
	)
	if image == null or image.is_empty():
		_fail("TURN blocked capture could not be loaded for pixel validation")
		return
	var indicator: TurnInputIndicator = main.get_node(
		"UI/Hud/TurnInputIndicator"
	) as TurnInputIndicator
	var logical_board: Rect2 = indicator._projected_board_rect()
	var logical_arrow: Rect2 = indicator.arrow_bounds(logical_board, Vector2i.DOWN)
	var logical_mark: Rect2 = indicator.blocked_mark_bounds(logical_board, Vector2i.DOWN)
	var logical_size: Vector2 = get_viewport().get_visible_rect().size
	var image_scale: Vector2 = Vector2(
		float(image.get_width()) / logical_size.x,
		float(image.get_height()) / logical_size.y
	)
	var board_rect: Rect2 = Rect2(
		logical_board.position * image_scale,
		logical_board.size * image_scale
	)
	var arrow_rect: Rect2 = Rect2(
		logical_arrow.position * image_scale,
		logical_arrow.size * image_scale
	).grow(2.0)
	var mark_rect: Rect2 = Rect2(
		logical_mark.position * image_scale,
		logical_mark.size * image_scale
	).grow(1.0)
	var top_band: Color = _average_side_band_color(
		image, board_rect, Vector2i.UP, 4.0, 10.0
	)
	var red_arrow_pixels: int = _count_red_dominant_pixels(image, arrow_rect)
	var red_mark_pixels: int = _count_red_dominant_pixels(image, mark_rect)
	print(
		"TURN_BLOCKED_PIXEL_CHECK arrow_red_pixels=%d x_red_pixels=%d top_wall_rgb=%.1f,%.1f,%.1f" % [
			red_arrow_pixels,
			red_mark_pixels,
			top_band.r * 255.0,
			top_band.g * 255.0,
			top_band.b * 255.0,
		]
	)
	if red_arrow_pixels < 20:
		_fail("TURN blocked capture does not contain the red chevron")
	if red_mark_pixels < 6:
		_fail("TURN blocked capture does not contain the small red X above the chevron")
	if top_band.r > maxf(top_band.g, top_band.b) * 1.5:
		_fail("TURN blocked capture still contains a red warning wall")


func _count_red_dominant_pixels(image: Image, rect: Rect2) -> int:
	var min_x: int = maxi(0, floori(rect.position.x))
	var max_x: int = mini(image.get_width() - 1, ceili(rect.end.x))
	var min_y: int = maxi(0, floori(rect.position.y))
	var max_y: int = mini(image.get_height() - 1, ceili(rect.end.y))
	var count: int = 0
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var color: Color = image.get_pixel(x, y)
			if color.r >= 0.55 and color.r > color.g * 1.4 and color.r > color.b * 1.4:
				count += 1
	return count


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
	var next_has_l1: bool = false
	var then_has_l1: bool = false
	for child: Node in next_preview.get_children():
		if child is OrbVisual and (child as OrbVisual).celestial_level() == 1:
			next_has_l1 = true
	for child: Node in then_preview.get_children():
		if child is OrbVisual and (child as OrbVisual).celestial_level() == 1:
			then_has_l1 = true
	if not next_has_l1 or not then_has_l1:
		_fail("TURN NEXT/THEN capture must visibly include an L1 meteor")
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


func _force_l1_preview(spawner: Spawner) -> void:
	for batch: Array in spawner._preview_batches:
		if not batch.is_empty():
			var candidate: Dictionary = batch[0] as Dictionary
			candidate["level"] = 1
	spawner._publish_preview()


func _validate_blitz_time_up_scene(main: Main) -> void:
	_expect_label_text(
		main.get_node("UI/Hud/TimerLabel") as Label,
		"0.0",
		"BLITZ TIME UP timer"
	)
	_expect_label_text(
		main.get_node("UI/Hud/ScoreLabel") as Label,
		str(BLITZ_CAPTURE_SCORE),
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
		str(BLITZ_CAPTURE_SCORE),
		"BLITZ result HUD score"
	)
	_expect_label_text(
		main.get_node("UI/Hud/GameOverPanel/Margin/Content/GameOverScore") as Label,
		"18,760",
		"BLITZ result panel score"
	)
	_expect_label_text(
		main.get_node("UI/Hud/GameOverPanel/Margin/Content/GameOverBest") as Label,
		"BEST 18,760",
		"BLITZ result panel best"
	)
	_expect_label_text(
		main.get_node("UI/Hud/GameOverPanel/Margin/Content/SurvivedTimeLabel") as Label,
		"버틴 시간",
		"BLITZ survived time label"
	)
	_expect_label_text(
		main.get_node("UI/Hud/GameOverPanel/Margin/Content/SurvivedTimeValue") as Label,
		"2:05",
		"BLITZ survived time"
	)
	print("SCREEN_CAPTURE_CHECK scene=blitz_result timer=0.0 score=%d" % BLITZ_CAPTURE_SCORE)


func _validate_blitz_survival_hud_scene(main: Main) -> void:
	_expect_label_text(
		main.get_node("UI/Hud/TimerLabel") as Label,
		"45.0",
		"BLITZ maximum clock"
	)
	_expect_label_text(
		main.get_node("UI/Hud/BonusLabel") as Label,
		"+0.3s",
		"BLITZ aggregated time bonus"
	)
	var drain_rate: Label = main.get_node("UI/Hud/DrainRateLabel") as Label
	if drain_rate.visible:
		_fail("BLITZ constant-speed clock must hide the drain multiplier at one layer")
	print("SCREEN_CAPTURE_CHECK scene=blitz_survival_hud bonus=+0.3s drain=constant")


func _validate_blitz_long_timer_scene(
	main: Main,
	expected_layers: int,
	expected_fill: float
) -> void:
	_expect_label_text(
		main.get_node("UI/Hud/TimerLabel") as Label,
		"128.4",
		"BLITZ long timer"
	)
	_expect_label_text(
		main.get_node("UI/Hud/DrainRateLabel") as Label,
		"×3",
		"BLITZ layered timer count"
	)
	var time_bar: BlitzTimeBar = main.get_node("UI/Hud/TimeBarFill") as BlitzTimeBar
	if time_bar.layer_count() != expected_layers:
		_fail("BLITZ long timer layer count mismatch")
	if not is_equal_approx(time_bar.layer_fill_ratio(), expected_fill):
		_fail("BLITZ long timer layer fill mismatch")
	print("SCREEN_CAPTURE_CHECK scene=blitz_timer_long layers=3 fill=%.3f" % expected_fill)


func _validate_blitz_bonus_segment_scene(
	main: Main,
	expected_pieces: int,
	expected_fever: bool
) -> void:
	var time_bar: BlitzTimeBar = main.get_node("UI/Hud/TimeBarFill") as BlitzTimeBar
	if not time_bar.bonus_is_active():
		_fail("BLITZ bonus segment must be visible")
	if time_bar.bonus_piece_rects().size() != expected_pieces:
		_fail("BLITZ bonus segment piece count mismatch")
	if time_bar.bonus_is_fever() != expected_fever:
		_fail("BLITZ bonus segment fever tint mismatch")
	print(
		"SCREEN_CAPTURE_CHECK scene=blitz_bonus pieces=%d fever=%s" % [
			expected_pieces,
			str(expected_fever),
		]
	)


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
		main.get_node(content_path + "RankingResultBadge/RankingResultLabel") as Label,
		"새 기록 · 3위",
		"BLITZ result ranking message"
	)
	if (main.get_node(content_path + "GameOverBest") as Label).visible:
		_fail("BLITZ ranked result must hide BEST in favor of the rank badge")
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
		if argument == HUD_SCENES_ONLY_ARGUMENT:
			_hud_scenes_only = true
		elif argument.begins_with(TEMP_SAVE_PREFIX):
			_temp_save_path = argument.trim_prefix(TEMP_SAVE_PREFIX)
		elif argument.begins_with(OUTPUT_DIRECTORY_PREFIX):
			_output_directory = argument.trim_prefix(OUTPUT_DIRECTORY_PREFIX)


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
