extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const DEFAULT_OUTPUT_DIRECTORY: String = "res://artifacts/screens"
const DEFAULT_USER_SAVE: String = "user://save.cfg"
const OUTPUT_PREFIX: String = "--capture-output-directory="
const SAVE_PREFIX: String = "--capture-save-path="
const CAPTURE_FILES: Array[String] = [
	"01_jelly_start.png",
	"02_jelly_ranking.png",
	"03_jelly_result.png",
	"04_jelly_gameplay.png",
	"05_jelly_final_move.png",
	"06_jelly_blast_down.png",
	"07_jelly_blast_right.png",
	"08_jelly_full_down.png",
	"09_jelly_full_right.png",
	"10_jelly_eat_00.png",
	"11_jelly_eat_01.png",
	"12_jelly_eat_02.png",
	"13_jelly_merge_effect.png",
	"14_jelly_absorption_effect.png",
	"15_jelly_blast_effect.png",
	"16_jelly_jackpot_effect.png",
	"17_jelly_max_effect.png",
	"18_jelly_landing_strip.png",
	"19_jelly_crowded_rest.png",
	"20_jelly_yellow_cheek_zoom.png",
	"21_jelly_green_cheek_zoom.png",
	"22_jelly_blue_cheek_zoom.png",
	"23_jelly_belly_half_zoom.png",
	"24_jelly_belly_three_quarter_zoom.png",
	"25_jelly_max_effect_zoom.png",
	"26_settings.png",
	"27_start_no_record.png",
	"28_gravity_switch.png",
	"29_board_danger.png",
	"30_board_blocked.png",
	"31_turn_input_ready.png",
	"32_turn_input_busy.png",
	"33_turn_input_rejected.png",
	"34_callout_great.png",
	"35_callout_incredible.png",
	"36_popup_merge.png",
	"37_popup_blast_big.png",
	"38_jelly_look_levels.png",
	"39_jelly_look_crowded.png",
	"40_jelly_look_max.png",
	"41_jelly_look_stretch.png",
	"42_jelly_look_absorption.png",
	"43_jelly_look_unlock.png",
	"44_jelly_motion_land_01.png",
	"45_jelly_motion_land_02.png",
	"46_jelly_motion_land_03.png",
	"47_jelly_motion_land_04.png",
	"48_jelly_motion_land_05.png",
	"49_jelly_motion_land_06.png",
	"50_jelly_motion_land_07.png",
	"51_jelly_motion_land_08.png",
	"52_jelly_motion_land_09.png",
	"53_jelly_motion_land_10.png",
	"54_jelly_motion_breathe_max.png",
	"55_jelly_motion_rest.png",
	"56_jelly_motion_right.png",
]

var _output_directory: String = DEFAULT_OUTPUT_DIRECTORY
var _temp_save_path: String = "res://artifacts/screens/capture_save.tmp.cfg"
var _failed: bool = false
var _user_save_existed: bool = false
var _user_save_bytes: PackedByteArray = PackedByteArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_parse_arguments()
	if _temp_save_path == DEFAULT_USER_SAVE:
		_fail("Capture save path must not be the user save path")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_directory))
	_snapshot_user_save()
	var original_sfx_enabled: bool = Config.data.sfx_enabled
	Config.data.sfx_enabled = false
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.rng_seed = 5050
	await _capture_shell_scenes()
	await _capture_gameplay_scenes()
	Config.data.sfx_enabled = original_sfx_enabled
	_verify_user_save_unchanged()
	_remove_file(_temp_save_path)
	for file_name: String in CAPTURE_FILES:
		if not FileAccess.file_exists(_output_directory.path_join(file_name)):
			_fail("Missing capture %s" % file_name)
	print("SCREEN_CAPTURE_SUITE exit=%d files=%d" % [1 if _failed else 0, CAPTURE_FILES.size()])
	get_tree().quit(1 if _failed else 0)


func _capture_shell_scenes() -> void:
	_remove_file(_temp_save_path)
	var main: Main = await _create_main(false)
	await _capture("27_start_no_record.png")
	(main.get_node("UI") as DebugHud).show_settings()
	await get_tree().create_timer(0.30).timeout
	await _capture("26_settings.png")
	await _destroy_main(main)

	SaveStore.add_ranking(
		_temp_save_path,
		GameConfig.GameMode.JELLY,
		176400,
		{"max_combo": 12, "turns": 84, "max_level": 7, "final_moves": 3},
		"2026-10-25 20:15"
	)
	SaveStore.add_ranking(
		_temp_save_path,
		GameConfig.GameMode.JELLY,
		112750,
		{"max_combo": 8, "turns": 61, "max_level": 6, "final_moves": 1},
		"2026-10-25 18:40"
	)
	main = await _create_main(false)
	await _capture("01_jelly_start.png")
	(main.get_node("UI") as DebugHud).show_ranking(GameConfig.GameMode.JELLY, 1)
	await get_tree().create_timer(0.25).timeout
	await _capture("02_jelly_ranking.png")
	await _destroy_main(main)

	main = await _create_main(true)
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
	await _capture("03_jelly_result.png")
	await _destroy_main(main)


func _capture_gameplay_scenes() -> void:
	var main: Main = await _create_main(true)
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	manager.set_physics_process(false)
	var board: Board3D = main.get_node("Board") as Board3D
	var hud: Hud = main.get_node("UI/Hud") as Hud
	board.clear()
	board.set_gravity(Vector2i.DOWN)
	_spawn_specs(board, [
		{"color": 0, "level": 1, "mass": 1.0, "position": Vector2(-310.0, 300.0)},
		{"color": 1, "level": 2, "mass": 2.0, "position": Vector2(-185.0, 260.0)},
		{"color": 2, "level": 3, "mass": 6.0, "position": Vector2(-30.0, 210.0)},
		{"color": 3, "level": 4, "mass": 8.0, "position": Vector2(150.0, 160.0)},
		{"color": 4, "level": 5, "mass": 24.0, "position": Vector2(310.0, 70.0)},
		{"color": 5, "level": 7, "mass": 64.0, "position": Vector2(50.0, -210.0)},
	])
	hud._on_preview_changed([
		[{"color": OrbTypes.OrbColor.YELLOW, "level": 2}],
		[{"color": OrbTypes.OrbColor.PURPLE, "level": 1}],
	])
	await get_tree().create_timer(0.20).timeout
	await _capture("04_jelly_gameplay.png")
	hud._on_final_move_changed(true, TurnManager.FINAL_MOVE_MESSAGE)
	await _capture("05_jelly_final_move.png")
	hud._on_final_move_changed(false, "")
	await _capture_recovered_hud_scenes(main, manager, board, hud)

	board.clear()
	_spawn_featured(board)
	await _capture("06_jelly_blast_down.png")
	board.clear()
	board.set_gravity(Vector2i.RIGHT)
	_spawn_featured(board)
	await _capture("07_jelly_blast_right.png")

	board.clear()
	board.set_gravity(Vector2i.DOWN)
	_spawn_full(board)
	await get_tree().create_timer(Orb3D.JELLY_BELLY_TRANSITION_DURATION).timeout
	await _capture("08_jelly_full_down.png")
	board.clear()
	board.set_gravity(Vector2i.RIGHT)
	_spawn_full(board)
	await get_tree().create_timer(Orb3D.JELLY_BELLY_TRANSITION_DURATION).timeout
	await _capture("09_jelly_full_right.png")

	board.clear()
	board.set_gravity(Vector2i.DOWN)
	var eater: Orb3D = board.spawn_orb(OrbTypes.OrbColor.BLUE, 3, Vector2(-90.0, 40.0))
	var food: Orb3D = board.spawn_orb(OrbTypes.OrbColor.BLUE, 2, Vector2(90.0, 40.0))
	eater.disable_physics()
	food.disable_physics()
	await _capture("10_jelly_eat_00.png")
	board.remove_orb(food)
	await get_tree().process_frame
	eater.set_jelly_mass(6.0, Config.data)
	await get_tree().create_timer(Orb3D.JELLY_BELLY_TRANSITION_DURATION).timeout
	await _capture("11_jelly_eat_01.png")
	eater.set_jelly_mass(8.0, Config.data)
	await get_tree().create_timer(Orb3D.JELLY_BELLY_TRANSITION_DURATION).timeout
	await _capture("12_jelly_eat_02.png")
	await _capture_effect_scenes(main, board)
	await _capture_overlay_detail_scenes(main, board)
	await _capture_deform_scenes(main, board)
	await _capture_recovered_jelly_scenes(main, board, hud)
	await _destroy_main(main)


func _capture_effect_scenes(main: Main, board: Board3D) -> void:
	var director: FeedbackDirector = main.get_node("FeedbackDirector") as FeedbackDirector
	board.clear()
	director.clear_effects()
	var result: Orb3D = board.spawn_orb(OrbTypes.OrbColor.BLUE, 3, Vector2.ZERO)
	result.disable_physics()
	director.play_reaction_visuals({
		"type": ReactionRules.Type.MERGE,
		"result_orb": result,
		"result_level": 3,
		"result_color": OrbTypes.OrbColor.BLUE,
		"position": Vector2.ZERO,
		"shock_targets": [],
	})
	await get_tree().create_timer(0.06).timeout
	await _capture("13_jelly_merge_effect.png")

	board.clear()
	director.clear_effects()
	result = board.spawn_orb(OrbTypes.OrbColor.GREEN, 3, Vector2.ZERO)
	result.disable_physics()
	director.play_reaction_visuals({
		"type": ReactionRules.Type.MERGE,
		"result_orb": result,
		"result_level": 3,
		"result_color": OrbTypes.OrbColor.GREEN,
		"position": Vector2.ZERO,
		"jelly_absorption": true,
		"source_positions": [Vector2(-150.0, 0.0), Vector2(150.0, 0.0)],
		"source_radii": [60.0, 25.0],
		"colors": [OrbTypes.OrbColor.GREEN, OrbTypes.OrbColor.GREEN],
		"levels": [3, 2],
		"shock_targets": [],
	})
	await get_tree().create_timer(0.08).timeout
	await _capture("14_jelly_absorption_effect.png")

	board.clear()
	director.clear_effects()
	_spawn_specs(board, [
		{"color": OrbTypes.OrbColor.RED, "level": 6, "mass": 32.0, "position": Vector2(-85.0, 0.0)},
		{"color": OrbTypes.OrbColor.BLUE, "level": 6, "mass": 32.0, "position": Vector2(85.0, 0.0)},
	])
	director.play_reaction_visuals({
		"type": ReactionRules.Type.BLAST,
		"levels": [6, 6],
		"colors": [OrbTypes.OrbColor.RED, OrbTypes.OrbColor.BLUE],
		"position": Vector2.ZERO,
	})
	await get_tree().create_timer(0.06).timeout
	await _capture("15_jelly_blast_effect.png")

	board.clear()
	director.clear_effects()
	director.play_reaction_visuals({
		"type": ReactionRules.Type.MAX_CLEAR,
		"levels": [7, 7],
		"colors": [OrbTypes.OrbColor.PURPLE, OrbTypes.OrbColor.PURPLE],
		"result_color": OrbTypes.OrbColor.PURPLE,
		"position": Vector2.ZERO,
		"shock_targets": [],
	})
	await get_tree().create_timer(0.06).timeout
	await _capture("16_jelly_jackpot_effect.png")

	board.clear()
	director.clear_effects()
	result = board.spawn_orb(OrbTypes.OrbColor.YELLOW, 7, Vector2.ZERO)
	result.disable_physics()
	director.play_reaction_visuals({
		"type": ReactionRules.Type.MERGE,
		"result_orb": result,
		"result_level": 7,
		"result_color": OrbTypes.OrbColor.YELLOW,
		"position": Vector2.ZERO,
		"shock_targets": [],
	})
	await get_tree().create_timer(0.06).timeout
	await _capture("17_jelly_max_effect.png")


func _capture_overlay_detail_scenes(main: Main, board: Board3D) -> void:
	var director: FeedbackDirector = main.get_node("FeedbackDirector") as FeedbackDirector
	var camera: Camera3D = main.get_node("Camera3D") as Camera3D
	director.clear_effects()
	board.clear()
	board.set_gravity(Vector2i.DOWN)
	var cheek_specs: Array[Dictionary] = [
		{
			"color": OrbTypes.OrbColor.YELLOW,
			"position": Vector2(-220.0, 0.0),
			"expected": Color8(247, 133, 126),
			"file": "20_jelly_yellow_cheek_zoom.png",
		},
		{
			"color": OrbTypes.OrbColor.GREEN,
			"position": Vector2.ZERO,
			"expected": Color8(192, 131, 142),
			"file": "21_jelly_green_cheek_zoom.png",
		},
		{
			"color": OrbTypes.OrbColor.BLUE,
			"position": Vector2(220.0, 0.0),
			"expected": Color8(200, 112, 170),
			"file": "22_jelly_blue_cheek_zoom.png",
		},
	]
	var cheek_orbs: Array[Orb3D] = []
	for spec: Dictionary in cheek_specs:
		var orb: Orb3D = board.spawn_orb(
			int(spec["color"]),
			5,
			spec["position"] as Vector2
		)
		orb.disable_physics()
		cheek_orbs.append(orb)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var cheek_image: Image = get_viewport().get_texture().get_image()
	for index: int in range(cheek_orbs.size()):
		var orb: Orb3D = cheek_orbs[index]
		var spec: Dictionary = cheek_specs[index]
		var cheek_point: Vector2 = camera.unproject_position(
			orb._face.global_transform * Vector3(
				JellyOrbArt.BLAST_BLUSH_CENTER.x,
				-JellyOrbArt.BLAST_BLUSH_CENTER.y,
				0.0
			)
		)
		var actual: Color = _pixel_at(cheek_image, cheek_point)
		var expected: Color = spec["expected"] as Color
		print(
			"JELLY_OVERLAY_PIXEL kind=cheek color=%d actual=%s expected=%s tolerance=12" % [
				int(spec["color"]),
				_rgb8_text(actual),
				_rgb8_text(expected),
			]
		)
		if not _color_within_rgb8(actual, expected, 12):
			_fail("Cheek pixel outside tolerance for color %d" % int(spec["color"]))
		await _capture_zoom(
			spec["file"] as String,
			camera.unproject_position(orb._mesh.global_position),
			76
		)

	board.clear()
	var belly_half: Orb3D = board.spawn_orb(OrbTypes.OrbColor.GREEN, 3, Vector2(-100.0, 0.0))
	var belly_three_quarter: Orb3D = board.spawn_orb(OrbTypes.OrbColor.GREEN, 3, Vector2(100.0, 0.0))
	belly_half.set_jelly_mass(6.0, Config.data)
	belly_three_quarter.set_jelly_mass(7.0, Config.data)
	belly_half.disable_physics()
	belly_three_quarter.disable_physics()
	await get_tree().create_timer(Orb3D.JELLY_BELLY_TRANSITION_DURATION).timeout
	await _capture_zoom(
		"23_jelly_belly_half_zoom.png",
		camera.unproject_position(belly_half._mesh.global_position),
		76
	)
	await _capture_zoom(
		"24_jelly_belly_three_quarter_zoom.png",
		camera.unproject_position(belly_three_quarter._mesh.global_position),
		76
	)
	await _verify_belly_pixel(camera, belly_half, "0.50")
	await _verify_belly_pixel(camera, belly_three_quarter, "0.75")

	board.clear()
	director.clear_effects()
	var maximum: Orb3D = board.spawn_orb(OrbTypes.OrbColor.YELLOW, 7, Vector2.ZERO)
	maximum.disable_physics()
	director.play_reaction_visuals({
		"type": ReactionRules.Type.MERGE,
		"result_orb": maximum,
		"result_level": 7,
		"result_color": OrbTypes.OrbColor.YELLOW,
		"position": Vector2.ZERO,
		"shock_targets": [],
	})
	await get_tree().create_timer(0.14).timeout
	await _capture_zoom(
		"25_jelly_max_effect_zoom.png",
		camera.unproject_position(maximum._mesh.global_position),
		132
	)


func _capture_deform_scenes(main: Main, board: Board3D) -> void:
	(main.get_node("FeedbackDirector") as FeedbackDirector).clear_effects()
	board.clear()
	board.set_gravity(Vector2i.DOWN)
	var landing_specs: Array[Dictionary] = [
		{"position": Vector2(-220.0, 50.0), "deform": Vector2(0.84, 1.18)},
		{"position": Vector2(0.0, 50.0), "deform": Vector2.ONE},
		{"position": Vector2(220.0, 50.0), "deform": Vector2(1.18, 0.80)},
	]
	for index: int in range(landing_specs.size()):
		var spec: Dictionary = landing_specs[index]
		var orb: Orb3D = board.spawn_orb(
			index,
			3,
			spec["position"] as Vector2
		)
		orb.disable_physics()
		orb._jelly_deform = spec["deform"] as Vector2
		orb._update_visual_transform()
	await _capture("18_jelly_landing_strip.png")

	board.clear()
	var level: int = 2
	var radius_px: float = Config.data.radius_for_level(level)
	var spacing_px: float = radius_px * 2.0
	var orb_index: int = 0
	for row: int in range(4):
		for column: int in range(5):
			var resting: Orb3D = board.spawn_orb(
				(row + column) % JellyOrbArt.PALETTE.size(),
				level,
				Vector2(
					(float(column) - 2.0) * spacing_px,
					(float(row) - 1.5) * spacing_px
				)
			)
			resting.disable_physics()
			resting.set_turn_resting(true)
			resting._jelly_breath_weight = 1.0
			resting._jelly_idle_elapsed = float(orb_index) * 0.37
			resting._update_visual_transform()
			orb_index += 1
	await _capture("19_jelly_crowded_rest.png")


func _capture_recovered_hud_scenes(
	main: Main,
	manager: TurnManager,
	board: Board3D,
	hud: Hud
) -> void:
	board.clear()
	board.set_gravity(Vector2i.RIGHT)
	board.play_visual_tilt(Vector2i.RIGHT)
	_spawn_featured(board)
	await get_tree().create_timer(0.12).timeout
	await _capture("28_gravity_switch.png")

	hud._set_danger_badge(0.70, 4.0)
	board.set_danger_state(0.70, 4.0)
	await get_tree().create_timer(0.18).timeout
	await _capture("29_board_danger.png")
	hud._set_danger_badge(0.0, 1.0)
	board.set_danger_state(0.0, 1.0)

	manager.blocked_directions.assign([Vector2i.DOWN])
	manager.warning_changed.emit(manager.blocked_directions)
	board.set_warning_directions(manager.blocked_directions)
	manager._set_state(TurnManager.State.WAITING_INPUT)
	InputRouter.set_locked(false)
	await get_tree().create_timer(TurnInputIndicator.READY_FADE_DURATION + 0.02).timeout
	await _capture("30_board_blocked.png")
	await _capture("31_turn_input_ready.png")

	manager._set_state(TurnManager.State.SIMULATING)
	manager.settle_elapsed = 0.5
	await get_tree().create_timer(TurnInputIndicator.BUSY_FADE_DURATION + 0.02).timeout
	await _capture("32_turn_input_busy.png")
	InputRouter.swipe_rejected.emit(Vector2i.LEFT)
	await get_tree().create_timer(0.04).timeout
	await _capture("33_turn_input_rejected.png")
	manager.blocked_directions.clear()
	var no_blocked_directions: Array[Vector2i] = []
	manager.warning_changed.emit(no_blocked_directions)
	board.set_warning_directions(no_blocked_directions)
	manager._set_state(TurnManager.State.WAITING_INPUT)
	InputRouter.set_locked(false)

	hud._show_callout("GREAT!", 1)
	await get_tree().create_timer(0.10).timeout
	await _capture("34_callout_great.png")
	hud._show_callout("INCREDIBLE!", 3)
	await get_tree().create_timer(0.10).timeout
	await _capture("35_callout_incredible.png")
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
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
	await _capture("36_popup_merge.png")
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
		_fail("restored JELLY big popup comma/formula mismatch")
	await _capture("37_popup_blast_big.png")
	for popup: ScorePopup in hud.active_score_popups():
		popup.deactivate()
	print(
		"SCREEN_CAPTURE_CHECK scene=recovered_hud gravity=true danger=true blocked=true "
		+ "input=ready,busy,rejected callouts=great,incredible popups=merge,blast"
	)


func _capture_recovered_jelly_scenes(main: Main, board: Board3D, hud: Hud) -> void:
	var feedback: FeedbackDirector = main.get_node("FeedbackDirector") as FeedbackDirector
	board.clear()
	feedback.clear_effects()
	var level_positions: Array[Vector2] = [
		Vector2(-330.0, -230.0),
		Vector2(-225.0, -230.0),
		Vector2(-100.0, -225.0),
		Vector2(45.0, -215.0),
		Vector2(220.0, -195.0),
		Vector2(-155.0, 105.0),
		Vector2(135.0, 120.0),
	]
	for index: int in range(level_positions.size()):
		var level_orb: Orb3D = board.spawn_orb(
			index % JellyOrbArt.PALETTE.size(),
			index + 1,
			level_positions[index]
		)
		level_orb.disable_physics()
	await _capture("38_jelly_look_levels.png")

	board.clear()
	var crowded_coordinates: Array[float] = [-320.0, -160.0, 0.0, 160.0, 320.0]
	var crowded_index: int = 0
	for y: float in crowded_coordinates:
		for x: float in crowded_coordinates:
			var crowded_orb: Orb3D = board.spawn_orb(
				crowded_index % JellyOrbArt.PALETTE.size(),
				1 + crowded_index % 3,
				Vector2(x, y)
			)
			crowded_orb.disable_physics()
			crowded_index += 1
	await _capture("39_jelly_look_crowded.png")
	await _measure_hud_face_overlap(main, board, hud)

	board.clear()
	feedback.clear_effects()
	var maximum: Orb3D = board.spawn_orb(OrbTypes.OrbColor.PURPLE, 7, Vector2.ZERO)
	maximum.disable_physics()
	feedback.play_reaction_visuals({
		"type": ReactionRules.Type.MERGE,
		"position": Vector2.ZERO,
		"result_level": 7,
		"result_color": OrbTypes.OrbColor.PURPLE,
		"result_orb": maximum,
		"levels": [6, 6],
		"colors": [OrbTypes.OrbColor.PURPLE, OrbTypes.OrbColor.PURPLE],
		"shock_targets": [],
	})
	hud._on_preview_changed([
		[{"color": OrbTypes.OrbColor.PURPLE, "level": 7}],
		[{"color": OrbTypes.OrbColor.RED, "level": 7}],
	])
	await get_tree().create_timer(0.16).timeout
	await _capture("40_jelly_look_max.png")

	board.clear()
	feedback.clear_effects()
	var stretch_values: Array[Vector2] = [
		Vector2(1.18, 1.0),
		Vector2(1.0, 1.19),
		Vector2(1.14, 1.10),
	]
	for index: int in range(stretch_values.size()):
		var stretch_orb: Orb3D = board.spawn_orb(
			index,
			3 + index,
			Vector2(-240.0 + float(index) * 240.0, 0.0)
		)
		stretch_orb.disable_physics()
		stretch_orb._jelly_deform = stretch_values[index]
		stretch_orb._update_visual_transform()
	await _capture("41_jelly_look_stretch.png")

	board.clear()
	var absorber: Orb3D = board.spawn_orb(OrbTypes.OrbColor.GREEN, 4, Vector2(115.0, 0.0))
	absorber.disable_physics()
	feedback.play_reaction_visuals({
		"type": ReactionRules.Type.MERGE,
		"position": Vector2(115.0, 0.0),
		"result_level": 4,
		"result_color": OrbTypes.OrbColor.GREEN,
		"result_orb": absorber,
		"jelly_absorption": true,
		"source_positions": [Vector2(-180.0, 0.0), Vector2(115.0, 0.0)],
		"source_radii": [Config.data.radius_for_level(3), Config.data.radius_for_level(4)],
		"levels": [3, 4],
		"colors": [OrbTypes.OrbColor.GREEN, OrbTypes.OrbColor.GREEN],
		"shock_targets": [],
	})
	await get_tree().create_timer(0.05).timeout
	await _capture("42_jelly_look_absorption.png")

	board.clear()
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
	await _capture("43_jelly_look_unlock.png")
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._hide_callout_label()

	board.clear()
	board.set_turn_resting(false)
	board.set_gravity(Vector2i.DOWN)
	var landing: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 7, Vector2.ZERO)
	landing.disable_physics()
	landing.set_gravity(Vector2i.DOWN, Config.data.gravity_strength)
	for frame_index: int in range(10):
		if frame_index < 4:
			landing.linear_velocity = Vector2(0.0, 1100.0 - float(frame_index) * 120.0)
		else:
			if frame_index == 4:
				landing.linear_velocity = Vector2(0.0, 1100.0)
			landing.get_physics_body().linear_velocity = Vector3.ZERO
			landing._physics_process(0.025)
		landing._process(0.025)
		await _capture("%02d_jelly_motion_land_%02d.png" % [44 + frame_index, frame_index + 1])

	board.clear()
	var breathing: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 7, Vector2.ZERO)
	breathing.disable_physics()
	breathing.set_turn_resting(true)
	breathing._jelly_breath_weight = 1.0
	breathing._jelly_idle_elapsed = PI / (2.0 * 1.8)
	breathing._process(0.0)
	await _capture("54_jelly_motion_breathe_max.png")

	board.clear()
	var rest_radius: float = Config.data.radius_for_level(2)
	for rest_index: int in range(40):
		var column: int = rest_index % 8
		var row: int = rest_index / 8
		var resting: Orb3D = board.spawn_orb(
			rest_index % JellyOrbArt.PALETTE.size(),
			2,
			Vector2(
				(float(column) - 3.5) * rest_radius * 1.72,
				(float(row) - 2.0) * rest_radius * 1.72
			)
		)
		resting.disable_physics()
		resting.set_turn_resting(true)
	await _capture("55_jelly_motion_rest.png")
	board.set_gravity(Vector2i.RIGHT)
	for moving: Orb3D in board.get_orbs():
		moving.set_turn_resting(false)
		moving.linear_velocity = Vector2.RIGHT * 1100.0
		moving._process(0.12)
	await _capture("56_jelly_motion_right.png")
	print(
		"SCREEN_CAPTURE_CHECK scene=recovered_jelly levels=7 crowded=25 max=true "
		+ "stretch=true absorption=true unlock=true land_frames=10 breathe=true rest=40 right=true"
	)


func _measure_hud_face_overlap(main: Main, board: Board3D, hud: Hud) -> void:
	var camera: Camera3D = main.get_node("Camera3D") as Camera3D
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._show_callout("NICE!", 0)
	hud._on_reaction_scored({
		"type": ReactionRules.Type.MERGE,
		"result_color": OrbTypes.OrbColor.GREEN,
		"position": Vector2.ZERO,
		"points": 1280,
		"base_points": 1280,
		"combo_multiplier": 1.0,
	})
	var maximum_ratio: float = 0.0
	var overlap_frames: int = 0
	var sample_frames: int = 120
	for _frame_index: int in range(sample_frames):
		await get_tree().process_frame
		var hud_rects: Array[Rect2] = []
		if hud._callout_label.visible:
			hud_rects.append(hud._callout_label.get_global_rect())
		for popup: ScorePopup in hud.active_score_popups():
			hud_rects.append(popup.get_global_rect())
		var frame_overlap: bool = false
		for orb: Orb3D in board.get_orbs():
			var center: Vector2 = camera.unproject_position(orb._face.global_position)
			var edge: Vector2 = camera.unproject_position(
				orb._face.global_position + Vector3(orb.get_current_radius() * 0.0045, 0.0, 0.0)
			)
			var half_size: float = maxf(center.distance_to(edge), 1.0)
			var face_rect: Rect2 = Rect2(center - Vector2.ONE * half_size, Vector2.ONE * half_size * 2.0)
			for hud_rect: Rect2 in hud_rects:
				var overlap: Rect2 = face_rect.intersection(hud_rect)
				if overlap.has_area():
					frame_overlap = true
					maximum_ratio = maxf(
						maximum_ratio,
						overlap.get_area() / maxf(face_rect.get_area(), 1.0)
					)
		if frame_overlap:
			overlap_frames += 1
	print(
		"JELLY_HUD_FACE_OVERLAP max_ratio=%.4f overlap_seconds=%.3f sampled_seconds=1.000" % [
			maximum_ratio,
			float(overlap_frames) / 120.0,
		]
	)
	for popup: ScorePopup in hud.active_score_popups():
		popup.deactivate()
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._hide_callout_label()


func _spawn_featured(board: Board3D) -> void:
	var specs: Array[Dictionary] = [
		{"color": 3, "level": 5, "position": Vector2(-280.0, -180.0)},
		{"color": 4, "level": 5, "position": Vector2(-80.0, -180.0)},
		{"color": 2, "level": 6, "position": Vector2(150.0, -100.0)},
		{"color": 0, "level": 7, "position": Vector2(70.0, 190.0)},
	]
	for spec: Dictionary in specs:
		var orb: Orb3D = board.spawn_orb(int(spec["color"]), int(spec["level"]), spec["position"] as Vector2)
		orb.disable_physics()


func _spawn_full(board: Board3D) -> void:
	_spawn_specs(board, [
		{"color": 2, "level": 3, "mass": 4.0, "position": Vector2(-300.0, -190.0)},
		{"color": 2, "level": 3, "mass": 6.0, "position": Vector2(-100.0, -190.0)},
		{"color": 2, "level": 3, "mass": 7.0, "position": Vector2(100.0, -190.0)},
		{"color": 3, "level": 5, "mass": 24.0, "position": Vector2(270.0, 130.0)},
	])


func _spawn_specs(board: Board3D, specs: Array[Dictionary]) -> void:
	for spec: Dictionary in specs:
		var orb: Orb3D = board.spawn_orb(int(spec["color"]), int(spec["level"]), spec["position"] as Vector2)
		orb.set_jelly_mass(float(spec["mass"]), Config.data)
		orb.disable_physics()


func _create_main(play: bool) -> Main:
	var main: Main = MAIN_SCENE.instantiate() as Main
	if play:
		main.launch_immediately(GameConfig.GameMode.JELLY)
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


func _capture_zoom(file_name: String, center: Vector2, half_size: int) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	center = _image_point(image, center)
	var size: int = half_size * 2
	var x: int = clampi(roundi(center.x) - half_size, 0, image.get_width() - size)
	var y: int = clampi(roundi(center.y) - half_size, 0, image.get_height() - size)
	var zoom: Image = image.get_region(Rect2i(x, y, size, size))
	zoom.resize(480, 480, Image.INTERPOLATE_LANCZOS)
	var path: String = _output_directory.path_join(file_name)
	var error: Error = zoom.save_png(path)
	if error != OK:
		_fail("Could not save %s: %s" % [path, error_string(error)])
		return
	print("SCREEN_CAPTURE_ZOOM file=%s source=%dx%d output=480x480" % [path, size, size])


func _verify_belly_pixel(camera: Camera3D, orb: Orb3D, fraction_label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var point: Vector2 = camera.unproject_position(
		orb._belly.global_transform * Vector3(
			JellyOrbArt.BELLY_CENTER.x,
			-JellyOrbArt.BELLY_CENTER.y,
			0.0
		)
	)
	var visible_image: Image = get_viewport().get_texture().get_image()
	var visible_color: Color = _pixel_at(visible_image, point)
	orb._belly.visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var hidden_image: Image = get_viewport().get_texture().get_image()
	var hidden_color: Color = _pixel_at(hidden_image, point)
	orb._belly.visible = true
	var difference: int = maxi(
		absi(roundi((visible_color.r - hidden_color.r) * 255.0)),
		maxi(
			absi(roundi((visible_color.g - hidden_color.g) * 255.0)),
			absi(roundi((visible_color.b - hidden_color.b) * 255.0))
		)
	)
	print(
		"JELLY_OVERLAY_PIXEL kind=belly fraction=%s visible=%s hidden=%s max_delta=%d" % [
			fraction_label,
			_rgb8_text(visible_color),
			_rgb8_text(hidden_color),
			difference,
		]
	)
	if difference <= 12:
		_fail("Belly fill %s is not visibly different from the body" % fraction_label)


func _pixel_at(image: Image, point: Vector2) -> Color:
	point = _image_point(image, point)
	return image.get_pixel(
		clampi(roundi(point.x), 0, image.get_width() - 1),
		clampi(roundi(point.y), 0, image.get_height() - 1)
	)


func _image_point(image: Image, viewport_point: Vector2) -> Vector2:
	var logical_size: Vector2 = get_viewport().get_visible_rect().size
	if logical_size.x <= 0.0 or logical_size.y <= 0.0:
		return viewport_point
	return viewport_point * Vector2(
		float(image.get_width()) / logical_size.x,
		float(image.get_height()) / logical_size.y
	)


func _color_within_rgb8(actual: Color, expected: Color, tolerance: int) -> bool:
	return (
		absi(roundi((actual.r - expected.r) * 255.0)) <= tolerance
		and absi(roundi((actual.g - expected.g) * 255.0)) <= tolerance
		and absi(roundi((actual.b - expected.b) * 255.0)) <= tolerance
	)


func _rgb8_text(color_value: Color) -> String:
	return "%d,%d,%d" % [
		roundi(color_value.r * 255.0),
		roundi(color_value.g * 255.0),
		roundi(color_value.b * 255.0),
	]


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(OUTPUT_PREFIX):
			_output_directory = argument.trim_prefix(OUTPUT_PREFIX)
		elif argument.begins_with(SAVE_PREFIX):
			_temp_save_path = argument.trim_prefix(SAVE_PREFIX)


func _snapshot_user_save() -> void:
	_user_save_existed = FileAccess.file_exists(DEFAULT_USER_SAVE)
	if _user_save_existed:
		_user_save_bytes = FileAccess.get_file_as_bytes(DEFAULT_USER_SAVE)


func _verify_user_save_unchanged() -> void:
	var exists_after: bool = FileAccess.file_exists(DEFAULT_USER_SAVE)
	if exists_after != _user_save_existed:
		_fail("Capture tool changed user save existence")
	elif exists_after and FileAccess.get_file_as_bytes(DEFAULT_USER_SAVE) != _user_save_bytes:
		_fail("Capture tool changed user save contents")


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
