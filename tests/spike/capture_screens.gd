extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const DEFAULT_OUTPUT_DIRECTORY: String = "res://artifacts/screens"
const DEFAULT_USER_SAVE: String = "user://save.cfg"
const OUTPUT_PREFIX: String = "--capture-output-directory="
const SAVE_PREFIX: String = "--capture-save-path="
const PILE_JITTER_SEED: int = 11620261030
const SPAWN_RAMP_CAPTURE_SEED: int = 11920261031
const CAPTURE_FILES: Array[String] = [
	"01_jelly_start.png",
	"02_jelly_ranking.png",
	"03_jelly_result.png",
	"04_jelly_gameplay.png",
	"05_jelly_final_move.png",
	"06_jelly_l6_normal_l8_blast_face.png",
	"07_jelly_l10_blast.png",
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
	"57_callout_nice.png",
	"58_callout_amazing.png",
	"59_callout_unstoppable.png",
	"60_popup_crowded.png",
	"61_jelly_gravity_left_down_diagonal.png",
	"62_jelly_gravity_left_down_rest.png",
	"63_jelly_gravity_right_down_rest.png",
	"64_jelly_initial_four_colors.png",
	"65_jelly_preview_budget_mix.png",
	"66_jelly_preview_board_match.png",
	"67_jelly_preview_next_1.png",
	"68_jelly_preview_next_2.png",
	"69_jelly_preview_next_5.png",
	"70_jelly_preview_then_l2_5.png",
	"71_jelly_turn_hud_three_digit.png",
	"72_jelly_merge_process_equal_00.png",
	"73_jelly_merge_process_equal_25.png",
	"74_jelly_merge_process_equal_50.png",
	"75_jelly_merge_process_equal_75.png",
	"76_jelly_merge_process_equal_100.png",
	"77_jelly_merge_process_absorb_00.png",
	"78_jelly_merge_process_absorb_25.png",
	"79_jelly_merge_process_absorb_50.png",
	"80_jelly_merge_process_absorb_75.png",
	"81_jelly_merge_process_absorb_100.png",
	"82_jelly_merge_process_level_up_00.png",
	"83_jelly_merge_process_level_up_25.png",
	"84_jelly_merge_process_level_up_50.png",
	"85_jelly_merge_process_level_up_75.png",
	"86_jelly_merge_process_level_up_100.png",
	"87_jelly_l1_l10_profile_a.png",
	"88_jelly_l1_l10_profile_b.png",
	"89_jelly_tap_blast_a_00.png",
	"90_jelly_tap_blast_a_50.png",
	"91_jelly_tap_blast_a_100.png",
	"92_jelly_tap_blast_b_00.png",
	"93_jelly_tap_blast_b_50.png",
	"94_jelly_tap_blast_b_100.png",
	"95_jelly_l10_blast_a.png",
	"96_jelly_l10_blast_b.png",
	"97_jelly_l10_jackpot_a.png",
	"98_jelly_l10_jackpot_b.png",
	"99_jelly_result_l10_max.png",
	"100_jelly_default_l7_l6_00.png",
	"101_jelly_default_l7_l6_50.png",
	"102_jelly_default_l7_l6_100.png",
	"103_jelly_default_l8_blast.png",
	"104_jelly_l8_tap_turn_before.png",
	"105_jelly_l8_tap_turn_entering.png",
	"106_jelly_l8_tap_turn_settled.png",
	"107_jelly_l8_l9_blast.png",
	"108_jelly_tap_pink_before.png",
	"109_jelly_tap_pink_010.png",
	"110_jelly_tap_pink_settled.png",
	"111_jelly_tap_blue_before.png",
	"112_jelly_tap_blue_010.png",
	"113_jelly_tap_blue_settled.png",
	"114_jelly_tap_green_before.png",
	"115_jelly_tap_green_010.png",
	"116_jelly_tap_green_settled.png",
	"117_jelly_tap_yellow_before.png",
	"118_jelly_tap_yellow_010.png",
	"119_jelly_tap_yellow_settled.png",
	"120_jelly_tap_purple_before.png",
	"121_jelly_tap_purple_010.png",
	"122_jelly_tap_purple_settled.png",
	"123_jelly_tap_orange_before.png",
	"124_jelly_tap_orange_010.png",
	"125_jelly_tap_orange_settled.png",
	"126_jelly_tap_blue_callout.png",
	"127_jelly_tap_orange_callout.png",
	"128_jelly_tap_effects_full.png",
	"129_jelly_blast_push_k0_big_000.png",
	"130_jelly_blast_push_k0_big_010.png",
	"131_jelly_blast_push_k0_big_020.png",
	"132_jelly_blast_push_k0_big_040.png",
	"133_jelly_blast_push_k0_yellow_000.png",
	"134_jelly_blast_push_k0_yellow_010.png",
	"135_jelly_blast_push_k0_yellow_020.png",
	"136_jelly_blast_push_k0_yellow_040.png",
	"137_jelly_blast_push_k4_big_000.png",
	"138_jelly_blast_push_k4_big_010.png",
	"139_jelly_blast_push_k4_big_020.png",
	"140_jelly_blast_push_k4_big_040.png",
	"141_jelly_blast_push_k4_yellow_000.png",
	"142_jelly_blast_push_k4_yellow_010.png",
	"143_jelly_blast_push_k4_yellow_020.png",
	"144_jelly_blast_push_k4_yellow_040.png",
	"145_jelly_blast_push_full.png",
	"146_jelly_tap_lift_0_yellow_000.png",
	"147_jelly_tap_lift_0_yellow_010.png",
	"148_jelly_tap_lift_0_yellow_020.png",
	"149_jelly_tap_lift_0_yellow_040.png",
	"150_jelly_tap_lift_900_yellow_000.png",
	"151_jelly_tap_lift_900_yellow_010.png",
	"152_jelly_tap_lift_900_yellow_020.png",
	"153_jelly_tap_lift_900_yellow_040.png",
	"154_jelly_tap_lift_full.png",
	"180_jelly_four_green_rest_before.png",
	"181_jelly_four_green_rest_after.png",
	"182_jelly_four_yellow_magnet_000.png",
	"183_jelly_four_yellow_magnet_020.png",
	"184_jelly_four_yellow_magnet_040.png",
	"185_jelly_four_yellow_magnet_070.png",
	"186_jelly_four_pink_callout.png",
	"187_jelly_four_blue_callout.png",
	"188_jelly_four_green_callout.png",
	"189_jelly_four_yellow_callout.png",
	"190_jelly_four_effects_full.png",
	"191_jelly_clean_zone_pink_before.png",
	"192_jelly_clean_zone_pink_after.png",
	"193_jelly_clean_zone_blue_before.png",
	"194_jelly_clean_zone_blue_after.png",
	"195_jelly_clean_zone_green_before.png",
	"196_jelly_clean_zone_green_after.png",
	"197_jelly_clean_zone_yellow_before.png",
	"198_jelly_clean_zone_yellow_after.png",
	"199_jelly_timed_board_initial.png",
	"200_jelly_timed_board_1.png",
	"201_jelly_timed_preview_next.png",
	"202_jelly_timed_success_before.png",
	"203_jelly_timed_success_after_bonus.png",
	"204_jelly_timed_timeout_before.png",
	"205_jelly_timed_stone_after_harden.png",
	"206_jelly_timed_first_callout.png",
	"207_jelly_timed_stone_1.png",
	"208_jelly_timed_stone_broken_settled.png",
	"209_jelly_timed_stone_first_callout.png",
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
	var ranking: RankingPanel = main.get_node("UI/RankingPanel") as RankingPanel
	if (ranking.get_node("Panel/Content/RankingHeader/Columns/Turns") as Label).text != "턴":
		_fail("JELLY ranking capture does not show the turn header")
	if (ranking.get_node("Panel/Content/Rows/RankingRow1/Text/Columns/Turns") as Label).text != "84":
		_fail("JELLY ranking capture does not show stored turns")
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
	var resolver: CollisionResolver = main.get_node("CollisionResolver") as CollisionResolver
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
	_spawn_l6_normal_and_l8_blast_faces(board)
	await _capture("06_jelly_l6_normal_l8_blast_face.png")
	board.clear()
	var first_blast: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		Config.data.orb_max_level,
		Vector2(-120.0, 0.0)
	)
	var second_blast: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		Config.data.orb_max_level,
		Vector2(120.0, 0.0)
	)
	first_blast.disable_physics()
	second_blast.disable_physics()
	resolver.report_contact(first_blast, second_blast, "capture_l10_blast")
	if resolver.flush() != 1:
		_fail("different-color maximum-level pair did not produce one capture reaction")
	var score_manager: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	if score_manager.score != 3840:
		_fail("L10+L10 capture score expected 3840, got %d" % score_manager.score)
	await get_tree().create_timer(0.06).timeout
	await _capture("07_jelly_l10_blast.png")

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
	await _capture_recovered_jelly_scenes(main, manager, board, hud)
	await _capture_jelly_merge_process_scenes(board, resolver, manager)
	await _capture_turn_hud_scene(main, manager, hud)
	await _capture_level_ten_scenes(main, board)
	await _destroy_main(main)


func _capture_level_ten_scenes(main: Main, board: Board3D) -> void:
	var director: FeedbackDirector = main.get_node("FeedbackDirector") as FeedbackDirector
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var resolver: CollisionResolver = main.get_node("CollisionResolver") as CollisionResolver
	var hud: Hud = main.get_node("UI/Hud") as Hud
	for profile: String in ["A", "B"]:
		_set_jelly_level_profile(profile)
		board.clear()
		director.clear_effects()
		for level: int in range(1, Config.data.orb_max_level + 1):
			var orb: Orb3D = board.spawn_orb(
				OrbTypes.OrbColor.PURPLE,
				level,
				Vector2(-405.0 + float(level - 1) * 90.0, 20.0)
			)
			orb.disable_physics()
		await _capture(
			"87_jelly_l1_l10_profile_a.png"
			if profile == "A"
			else "88_jelly_l1_l10_profile_b.png"
		)
		await _capture_tap_blast_progress(board, director, profile)
		await _capture_level_ten_pair_effect(main, board, director, profile, false)
		await _capture_level_ten_pair_effect(main, board, director, profile, true)
	await _capture_default_g1_scenes(main, board, director)
	await _capture_default_d_scenes(main, board, director)
	await _capture_timed_jelly_scenes(main, manager, board, resolver, hud)

	_set_jelly_level_profile("B")
	board.clear()
	director.clear_effects()
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	manager.turn_index = 128
	manager.max_combo = 10
	score.score = 128000
	score.best_score = 128000
	score.max_level_reached = Config.data.orb_max_level
	manager.game_over_details = {
		"direction": Vector2i.DOWN,
		"final_moves": 2,
		"final_move_successes": 1,
	}
	manager.game_over_details["ranking"] = manager._commit_completed_ranking()
	manager.game_over.emit()
	await get_tree().create_timer(0.85).timeout
	await _capture("99_jelly_result_l10_max.png")


func _capture_timed_jelly_scenes(
	main: Main,
	manager: TurnManager,
	board: Board3D,
	resolver: CollisionResolver,
	hud: Hud
) -> void:
	_set_jelly_level_profile("B")
	var director: FeedbackDirector = main.get_node("FeedbackDirector") as FeedbackDirector
	resolver.set_physics_process(false)
	resolver.cancel_active_jelly_merges()
	Config.data.jelly_timed_enabled = true
	Config.data.fx_callouts_enabled = true
	director.clear_effects()
	board.clear()
	_clear_capture_hud_residue(hud)
	var timed: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.YELLOW,
		Config.data.jelly_timed_level,
		Vector2.ZERO
	)
	timed.set_timed(Config.data.jelly_timed_turns, 20)
	timed.disable_physics()
	await get_tree().process_frame
	await _capture("199_jelly_timed_board_initial.png")
	timed.set_timed(1, 20)
	await _capture("200_jelly_timed_board_1.png")

	_clear_capture_hud_residue(hud)
	hud._on_preview_changed([
		[{
			"color": OrbTypes.OrbColor.YELLOW,
			"level": Config.data.jelly_timed_level,
			"timed": true,
			"timed_turns": Config.data.jelly_timed_turns,
		}],
		[{"color": OrbTypes.OrbColor.BLUE, "level": 1}],
	])
	await _capture("201_jelly_timed_preview_next.png")

	director.clear_effects()
	board.clear()
	_clear_capture_hud_residue(hud)
	var timed_level: int = Config.data.jelly_timed_level
	var first: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		timed_level,
		Vector2(-80.0, 0.0)
	)
	var second: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		timed_level,
		Vector2(80.0, 0.0)
	)
	first.set_timed(Config.data.jelly_timed_turns, 20)
	first.disable_physics()
	second.disable_physics()
	await _capture("202_jelly_timed_success_before.png")
	var original_duration: float = Config.data.jelly_merge_duration
	Config.data.jelly_merge_duration = 0.0
	resolver.report_contact(first, second, "capture_timed_success")
	if resolver.flush() != 1:
		_fail("timed success capture did not resolve exactly once")
	Config.data.jelly_merge_duration = original_duration
	await get_tree().process_frame
	var success_orbs: Array[Orb3D] = board.get_orbs()
	var classified: Dictionary = ReactionRules.classify(
		OrbTypes.OrbColor.RED,
		timed_level,
		OrbTypes.OrbColor.RED,
		timed_level,
		Config.data,
		Config.data.jelly_mass_for_level(timed_level),
		Config.data.jelly_mass_for_level(timed_level)
	)
	var expected_result_level: int = mini(
		int(classified["result_level"]) + Config.data.jelly_timed_bonus_levels,
		Config.data.orb_max_level
	)
	if (
		success_orbs.size() != 1
		or success_orbs[0].level != expected_result_level
		or success_orbs[0].is_timed
	):
		_fail("timed success capture expected one normal bonus result")
	await _capture("203_jelly_timed_success_after_bonus.png")

	director.clear_effects()
	board.clear()
	_clear_capture_hud_residue(hud)
	var expiring: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		timed_level,
		Vector2.ZERO
	)
	expiring.set_timed(1, 32)
	expiring.disable_physics()
	await _capture("204_jelly_timed_timeout_before.png")
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	var score_before: int = score.score
	manager._timed_stone_callout_seen = true
	manager._harden_timed_jelly(expiring)
	await get_tree().process_frame
	if (
		board.get_orbs().size() != 1
		or not expiring.is_timed_stone
		or expiring.timed_stone_turns_remaining != Config.data.jelly_timed_stone_turns
		or score.score != score_before
	):
		_fail("timed timeout capture expected one scoreless stone in place")
	await _capture("205_jelly_timed_stone_after_harden.png")
	expiring.set_timed_stone(1)
	await _capture("207_jelly_timed_stone_1.png")
	manager._remove_timed_stone(expiring)
	resolver._advance_tap_clean_visuals(Config.data.jelly_tap_clean_visual_time + 0.01)
	await get_tree().process_frame
	if not board.get_orbs().is_empty() or score.score != score_before:
		_fail("timed stone break capture expected an empty scoreless settled board")
	await _capture("208_jelly_timed_stone_broken_settled.png")

	director.clear_effects()
	_clear_capture_hud_residue(hud)
	hud._pending_planet_unlocks.clear()
	hud._pending_jelly_tap_effects.clear()
	hud._timed_jelly_callout_seen = false
	hud._timed_jelly_callout_pending = false
	hud._on_timed_jelly_placed(
		Config.data.jelly_timed_turns,
		Config.data.jelly_timed_bonus_levels
	)
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	_report_callout_fit("206_jelly_timed_first_callout", hud)
	await _capture("206_jelly_timed_first_callout.png")
	hud._hide_callout_label()

	director.clear_effects()
	board.clear()
	_clear_capture_hud_residue(hud)
	var callout_stone: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		timed_level,
		Vector2.ZERO
	)
	callout_stone.set_timed_stone(Config.data.jelly_timed_stone_turns)
	callout_stone.disable_physics()
	hud._timed_stone_callout_seen = false
	hud._timed_stone_callout_pending = false
	hud._on_timed_stone_created(Config.data.jelly_timed_stone_turns)
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	_report_callout_fit("209_jelly_timed_stone_first_callout", hud)
	await _capture("209_jelly_timed_stone_first_callout.png")
	hud._hide_callout_label()


func _capture_default_g1_scenes(
	main: Main,
	board: Board3D,
	director: FeedbackDirector
) -> void:
	var resolver: CollisionResolver = main.get_node("CollisionResolver") as CollisionResolver
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var original_gap: int = Config.data.jelly_merge_level_gap
	var original_blast_level: int = Config.data.jelly_blast_min_level
	var original_duration: float = Config.data.jelly_merge_duration
	var original_scan: bool = resolver.proximity_reaction_scan_enabled
	_set_jelly_level_profile("B")
	Config.data.jelly_merge_duration = 0.3
	resolver.proximity_reaction_scan_enabled = false
	resolver.cancel_active_jelly_merges()
	board.clear()
	manager.turn_combo = 0
	manager.max_combo = 0
	manager._emit_combo_changed()
	await get_tree().process_frame
	var larger: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.PURPLE,
		7,
		Vector2.ZERO
	)
	var smaller: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.PURPLE,
		6,
		Vector2.ZERO
	)
	var touching_distance: float = larger.get_current_radius() + smaller.get_current_radius()
	larger.position = Vector2(-touching_distance * 0.5, 0.0)
	smaller.position = Vector2(touching_distance * 0.5, 0.0)
	larger.linear_velocity = Vector2.ZERO
	smaller.linear_velocity = Vector2.ZERO
	resolver.report_contact(larger, smaller, "default_g1_capture")
	resolver.flush()
	await _capture("100_jelly_default_l7_l6_00.png")
	var active_before: Array[Orb3D] = board.get_orbs()
	resolver.flush(Config.data.jelly_merge_duration * 0.5)
	for orb: Orb3D in active_before:
		if is_instance_valid(orb):
			orb._physics_process(Config.data.jelly_merge_duration * 0.5)
	await _capture("101_jelly_default_l7_l6_50.png")
	active_before = board.get_orbs()
	resolver.flush(Config.data.jelly_merge_duration * 0.5)
	for orb: Orb3D in active_before:
		if is_instance_valid(orb):
			orb._physics_process(Config.data.jelly_merge_duration * 0.5)
	await _capture("102_jelly_default_l7_l6_100.png")

	board.clear()
	director.clear_effects()
	var first: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		8,
		Vector2(-150.0, 0.0)
	)
	var second: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		8,
		Vector2(150.0, 0.0)
	)
	first.disable_physics()
	second.disable_physics()
	director.play_reaction_visuals({
		"type": ReactionRules.Type.BLAST,
		"levels": [8, 8],
		"colors": [first.color, second.color],
		"position": Vector2.ZERO,
		"shock_level": 8,
	})
	await get_tree().create_timer(0.06).timeout
	await _capture("103_jelly_default_l8_blast.png")

	resolver.cancel_active_jelly_merges()
	resolver.proximity_reaction_scan_enabled = original_scan
	Config.data.jelly_merge_duration = original_duration
	Config.data.jelly_merge_level_gap = original_gap
	Config.data.jelly_blast_min_level = original_blast_level


func _capture_default_d_scenes(
	main: Main,
	board: Board3D,
	director: FeedbackDirector
) -> void:
	_set_jelly_level_profile("B")
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var spawner: Spawner = main.get_node("Spawner") as Spawner
	var hud: Hud = main.get_node("UI/Hud") as Hud
	board.clear()
	director.clear_effects()
	board.set_gravity(Vector2i.DOWN)
	manager.gravity = Vector2i.DOWN
	manager.turn_index = 124
	manager.turn_combo = 0
	manager.max_combo = 0
	manager.final_move_pending = false
	manager.final_move_active = false
	manager._is_initial_settle = false
	manager._is_tap_blast_settle = false
	manager.state = TurnManager.State.WAITING_INPUT
	manager._emit_combo_changed()
	spawner.init_rng(130)
	spawner.sync_next_batch_size(125)
	hud._refresh_turn_number()
	InputRouter.set_locked(false)
	var source: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.YELLOW,
		8,
		Vector2.ZERO
	)
	source.disable_physics()
	var nearby_specs: Array[Dictionary] = [
		{"color": OrbTypes.OrbColor.RED, "level": 1, "position": Vector2(-175.0, -110.0)},
		{"color": OrbTypes.OrbColor.BLUE, "level": 2, "position": Vector2(185.0, -95.0)},
		{"color": OrbTypes.OrbColor.GREEN, "level": 3, "position": Vector2(-150.0, 145.0)},
		{"color": OrbTypes.OrbColor.PURPLE, "level": 2, "position": Vector2(165.0, 155.0)},
	]
	for spec: Dictionary in nearby_specs:
		var nearby: Orb3D = board.spawn_orb(
			int(spec["color"]),
			int(spec["level"]),
			spec["position"] as Vector2
		)
		nearby.disable_physics()
	await get_tree().process_frame
	var preview_before: Array = spawner.peek_preview()
	await _capture("104_jelly_l8_tap_turn_before.png")
	var original_hitstop_enabled: bool = Config.data.fx_hitstop_enabled
	Config.data.fx_hitstop_enabled = false
	manager.set_physics_process(true)
	if not manager.try_tap_blast_orb(source):
		_fail("L8 tap turn capture could not start")
	await get_tree().physics_frame
	await get_tree().process_frame
	if manager.turn_index != 125:
		_fail("L8 tap turn capture expected turn index 125")
	if spawner.peek_preview() == preview_before:
		_fail("L8 tap turn capture did not advance NEXT and THEN")
	await _capture("105_jelly_l8_tap_turn_entering.png")
	for _frame: int in range(360):
		if manager.state == TurnManager.State.WAITING_INPUT:
			break
		await get_tree().physics_frame
	if manager.state != TurnManager.State.WAITING_INPUT:
		_fail("L8 tap turn capture did not settle")
	await get_tree().process_frame
	await _capture("106_jelly_l8_tap_turn_settled.png")
	manager.set_physics_process(false)
	Config.data.fx_hitstop_enabled = original_hitstop_enabled

	board.clear()
	director.clear_effects()
	var level_eight: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		8,
		Vector2(-150.0, 0.0)
	)
	var level_nine: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		9,
		Vector2(150.0, 0.0)
	)
	level_eight.disable_physics()
	level_nine.disable_physics()
	director.play_reaction_visuals({
		"type": ReactionRules.Type.BLAST,
		"levels": [8, 9],
		"colors": [level_eight.color, level_nine.color],
		"position": Vector2.ZERO,
		"shock_level": 9,
	})
	await get_tree().create_timer(0.06).timeout
	await _capture("107_jelly_l8_l9_blast.png")
	await _capture_jelly_tap_effect_scenes(main, board, director)


func _capture_jelly_tap_effect_scenes(
	main: Main,
	board: Board3D,
	director: FeedbackDirector
) -> void:
	_set_jelly_level_profile("B")
	Config.data.jelly_tap_clean_max_level = 2
	Config.data.jelly_tap_grow_min_clean = 3
	Config.data.jelly_tap_effect_modes = PackedInt32Array([2, 3, 4, 5, 6, 7])
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var resolver: CollisionResolver = main.get_node("CollisionResolver") as CollisionResolver
	var spawner: Spawner = main.get_node("Spawner") as Spawner
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var names: Array[String] = ["pink", "blue", "green", "yellow", "purple", "orange"]
	var file_number: int = 108
	var original_hitstop_enabled: bool = Config.data.fx_hitstop_enabled
	Config.data.fx_hitstop_enabled = false
	for color_index: int in range(6):
		resolver.cancel_active_jelly_merges()
		board.clear()
		director.clear_effects()
		board.set_gravity(Vector2i.DOWN)
		manager.gravity = Vector2i.DOWN
		manager.turn_index = 200 + color_index
		manager.turn_combo = 0
		manager.final_move_pending = false
		manager.final_move_active = false
		manager._is_initial_settle = false
		manager._is_tap_blast_settle = false
		manager.state = TurnManager.State.WAITING_INPUT
		spawner.init_rng(1330 + color_index)
		spawner.sync_next_batch_size(manager.turn_index + 1)
		InputRouter.set_locked(false)
		var source: Orb3D = board.spawn_orb(color_index, 8, Vector2.ZERO)
		source.disable_physics()
		for clean_index: int in range(3):
			var clean_orb: Orb3D = board.spawn_orb(
				color_index,
				mini(clean_index + 1, 2),
				Vector2(-250.0 + float(clean_index) * 250.0, 180.0)
			)
			clean_orb.disable_physics()
		for other_index: int in range(3):
			var other: Orb3D = board.spawn_orb(
				(color_index + other_index + 1) % 6,
				other_index + 2,
				Vector2(-220.0 + float(other_index) * 220.0, -190.0)
			)
			other.disable_physics()
		await get_tree().process_frame
		if color_index == OrbTypes.OrbColor.GREEN:
			hud._show_jelly_tap_effect(OrbTypes.OrbColor.GREEN)
			if hud._callout_tween != null and hud._callout_tween.is_valid():
				hud._callout_tween.kill()
		await _capture("%03d_jelly_tap_%s_before.png" % [file_number, names[color_index]])
		manager.set_physics_process(true)
		if not manager.try_tap_blast_orb(source):
			_fail("tap effect capture could not start for color %d" % color_index)
		await get_tree().create_timer(0.10).timeout
		# Freeze the turn while the 0.10 s frame is rendered. Otherwise a physics-frame
		# state transition can replace the forced hint between _show_jelly_tap_effect()
		# and _capture(), leaving a mixed/partially redrawn label in the evidence image.
		manager.set_physics_process(false)
		if color_index == OrbTypes.OrbColor.GREEN:
			hud._show_jelly_tap_effect(OrbTypes.OrbColor.GREEN)
			if hud._callout_tween != null and hud._callout_tween.is_valid():
				hud._callout_tween.kill()
		await _capture("%03d_jelly_tap_%s_010.png" % [file_number + 1, names[color_index]])
		manager.set_physics_process(true)
		for _frame: int in range(480):
			if manager.state == TurnManager.State.WAITING_INPUT:
				break
			await get_tree().physics_frame
		if manager.state != TurnManager.State.WAITING_INPUT:
			_fail("tap effect capture did not settle for color %d" % color_index)
		if color_index == OrbTypes.OrbColor.GREEN:
			hud._show_jelly_tap_effect(OrbTypes.OrbColor.GREEN)
			if hud._callout_tween != null and hud._callout_tween.is_valid():
				hud._callout_tween.kill()
		await _capture("%03d_jelly_tap_%s_settled.png" % [file_number + 2, names[color_index]])
		manager.set_physics_process(false)
		file_number += 3

	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._hide_callout_label()
	hud._on_jelly_tap_effect_unlocked(OrbTypes.OrbColor.BLUE)
	hud._show_next_jelly_tap_effect()
	await _capture("126_jelly_tap_blue_callout.png")
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._hide_callout_label()
	hud._on_jelly_tap_effect_unlocked(OrbTypes.OrbColor.CYAN)
	hud._show_next_jelly_tap_effect()
	await _capture("127_jelly_tap_orange_callout.png")
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._hide_callout_label()

	board.clear()
	for color_index: int in range(6):
		var column: int = color_index % 3
		var row: int = color_index / 3
		var orb: Orb3D = board.spawn_orb(
			color_index,
			8,
			Vector2(-280.0 + float(column) * 280.0, -170.0 + float(row) * 340.0)
		)
		orb.disable_physics()
	await _capture("128_jelly_tap_effects_full.png")
	await _capture_four_color_effect_scenes(main, board, director, resolver, spawner, hud)
	await _capture_blast_push_evidence(main, board, resolver)
	await _capture_tap_lift_evidence(board, resolver)
	await _capture_tap_push_evidence(main, board, resolver)
	Config.data.fx_hitstop_enabled = original_hitstop_enabled


func _capture_four_color_effect_scenes(
	main: Main,
	board: Board3D,
	director: FeedbackDirector,
	resolver: CollisionResolver,
	spawner: Spawner,
	hud: Hud
) -> void:
	Config.data.turn_color_unlock_turns.clear()
	Config.data.jelly_tap_effect_modes = PackedInt32Array([2, 3, 7, 6, 1, 1])
	Config.data.jelly_tap_clean_max_level = 1
	Config.data.jelly_tap_clean_zone_rule = true
	Config.data.jelly_tap_rest_clean_count = 2
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	resolver.cancel_active_jelly_merges()
	board.clear()
	director.clear_effects()
	_clear_capture_hud_residue(hud)
	board.set_gravity(Vector2i.DOWN)
	manager.gravity = Vector2i.DOWN
	manager.turn_index = 29
	manager.turn_combo = 0
	manager.final_move_pending = false
	manager.final_move_active = false
	manager.state = TurnManager.State.WAITING_INPUT
	manager.set_physics_process(false)
	spawner.init_rng(1390)
	spawner.sync_next_batch_size(30)
	InputRouter.set_locked(false)
	hud._refresh_turn_number()
	var rest_source: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.GREEN, 8, Vector2(0.0, 120.0)
	)
	rest_source.disable_physics()
	for index: int in range(3):
		var rest_clean: Orb3D = board.spawn_orb(
			OrbTypes.OrbColor.GREEN,
			1 + index % 2,
			Vector2(-230.0 + float(index) * 230.0, -120.0)
		)
		rest_clean.disable_physics()
	await get_tree().process_frame
	await _capture("180_jelly_four_green_rest_before.png")
	if not manager.try_tap_blast_orb(rest_source):
		_fail("four-color green REST capture could not start")
	manager.set_physics_process(false)
	await get_tree().process_frame
	await _capture("181_jelly_four_green_rest_after.png")

	resolver.cancel_active_jelly_merges()
	board.clear()
	director.clear_effects()
	_clear_capture_hud_residue(hud)
	board.set_gravity(Vector2i.DOWN)
	var magnet_source: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.YELLOW, 8, Vector2.ZERO
	)
	for index: int in range(8):
		var angle: float = TAU * float(index) / 8.0
		board.spawn_orb(
			index % 4,
			4 + index % 3,
			Vector2.from_angle(angle) * (230.0 + float(index % 2) * 70.0)
		)
	await get_tree().process_frame
	await _capture("182_jelly_four_yellow_magnet_000.png")
	if not resolver.apply_jelly_tap_blast(magnet_source):
		_fail("four-color yellow MAGNET capture could not start")
	await _wait_physics_seconds(0.2)
	await _capture("183_jelly_four_yellow_magnet_020.png")
	await _wait_physics_seconds(0.2)
	await _capture("184_jelly_four_yellow_magnet_040.png")
	await _wait_physics_seconds(0.3)
	await _capture("185_jelly_four_yellow_magnet_070.png")

	resolver.cancel_active_jelly_merges()
	board.clear()
	director.clear_effects()
	_clear_capture_hud_residue(hud)
	for color_index: int in range(4):
		var column: int = color_index % 2
		var row: int = color_index / 2
		var orb: Orb3D = board.spawn_orb(
			color_index,
			8,
			Vector2(-180.0 + float(column) * 360.0, -180.0 + float(row) * 360.0)
		)
		orb.disable_physics()
	var callout_files: Array[String] = [
		"186_jelly_four_pink_callout.png",
		"187_jelly_four_blue_callout.png",
		"188_jelly_four_green_callout.png",
		"189_jelly_four_yellow_callout.png",
	]
	for color_index: int in range(4):
		_clear_capture_hud_residue(hud)
		hud._show_jelly_tap_effect(color_index)
		if hud._callout_tween != null and hud._callout_tween.is_valid():
			hud._callout_tween.kill()
		_report_callout_fit(callout_files[color_index].trim_suffix(".png"), hud)
		await _capture(callout_files[color_index])
		hud._hide_callout_label()
	await _capture("190_jelly_four_effects_full.png")
	await _capture_clean_zone_evidence(board, resolver, director, hud)


func _capture_clean_zone_evidence(
	board: Board3D,
	resolver: CollisionResolver,
	director: FeedbackDirector,
	hud: Hud
) -> void:
	var cases: Array[Dictionary] = [
		{
			"name": "pink",
			"color": OrbTypes.OrbColor.RED,
			"source": Vector2.ZERO,
			"matching": [
				{"color": OrbTypes.OrbColor.RED, "level": 1, "position": Vector2(-220.0, 0.0)},
				{"color": OrbTypes.OrbColor.BLUE, "level": 1, "position": Vector2(220.0, 0.0)},
			],
			"remaining": [
				{"color": OrbTypes.OrbColor.RED, "level": 1, "position": Vector2(340.0, 0.0)},
				{"color": OrbTypes.OrbColor.BLUE, "level": 2, "position": Vector2(0.0, -180.0)},
			],
			"base": 191,
		},
		{
			"name": "blue",
			"color": OrbTypes.OrbColor.BLUE,
			"source": Vector2.ZERO,
			"matching": [
				{"color": OrbTypes.OrbColor.BLUE, "level": 1, "position": Vector2(-300.0, 450.0)},
				{"color": OrbTypes.OrbColor.BLUE, "level": 1, "position": Vector2(300.0, 450.0)},
			],
			"remaining": [
				{"color": OrbTypes.OrbColor.BLUE, "level": 1, "position": Vector2(0.0, 380.0)},
				{"color": OrbTypes.OrbColor.RED, "level": 1, "position": Vector2(150.0, 450.0)},
				{"color": OrbTypes.OrbColor.BLUE, "level": 2, "position": Vector2(-150.0, 450.0)},
			],
			"base": 193,
		},
		{
			"name": "green",
			"color": OrbTypes.OrbColor.GREEN,
			"source": Vector2(300.0, 260.0),
			"matching": [
				{"color": OrbTypes.OrbColor.GREEN, "level": 1, "position": Vector2(-260.0, -340.0)},
				{"color": OrbTypes.OrbColor.GREEN, "level": 1, "position": Vector2(160.0, -210.0)},
			],
			"remaining": [
				{"color": OrbTypes.OrbColor.GREEN, "level": 1, "position": Vector2(-180.0, -40.0)},
				{"color": OrbTypes.OrbColor.GREEN, "level": 1, "position": Vector2(120.0, 140.0)},
				{"color": OrbTypes.OrbColor.GREEN, "level": 2, "position": Vector2(40.0, -410.0)},
				{"color": OrbTypes.OrbColor.RED, "level": 1, "position": Vector2(330.0, -430.0)},
			],
			"base": 195,
		},
		{
			"name": "yellow",
			"color": OrbTypes.OrbColor.YELLOW,
			"source": Vector2(-220.0, 0.0),
			"matching": [
				{"color": OrbTypes.OrbColor.YELLOW, "level": 1, "position": Vector2(240.0, 0.0)},
			],
			"remaining": [
				{"color": OrbTypes.OrbColor.YELLOW, "level": 1, "position": Vector2(280.0, 0.0)},
				{"color": OrbTypes.OrbColor.YELLOW, "level": 2, "position": Vector2(0.0, -180.0)},
			],
			"base": 197,
		},
	]
	for capture_case: Dictionary in cases:
		resolver.cancel_active_jelly_merges()
		board.clear()
		director.clear_effects()
		_clear_capture_hud_residue(hud)
		board.set_gravity(Vector2i.DOWN)
		var source: Orb3D = board.spawn_orb(
			int(capture_case["color"]),
			8,
			capture_case["source"] as Vector2
		)
		source.disable_physics()
		for spec_value: Variant in capture_case["matching"] as Array:
			var matching_spec: Dictionary = spec_value as Dictionary
			var matching: Orb3D = board.spawn_orb(
				int(matching_spec["color"]),
				int(matching_spec["level"]),
				matching_spec["position"] as Vector2
			)
			matching.disable_physics()
		for remaining_value: Variant in capture_case["remaining"] as Array:
			var remaining_spec: Dictionary = remaining_value as Dictionary
			var remaining: Orb3D = board.spawn_orb(
				int(remaining_spec["color"]),
				int(remaining_spec["level"]),
				remaining_spec["position"] as Vector2
			)
			remaining.disable_physics()
		await get_tree().process_frame
		var base: int = int(capture_case["base"])
		var name: String = str(capture_case["name"])
		await _capture("%03d_jelly_clean_zone_%s_before.png" % [base, name])
		if not resolver.apply_jelly_tap_blast(source):
			_fail("%s clean-zone evidence tap did not trigger" % name)
		resolver.flush(Config.data.jelly_tap_clean_visual_time + 0.05)
		await get_tree().process_frame
		_clear_capture_hud_residue(hud)
		await _capture("%03d_jelly_clean_zone_%s_after.png" % [base + 1, name])


func _clear_capture_hud_residue(hud: Hud) -> void:
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._hide_callout_label()
	hud._on_combo_changed(0, 1.0, 0)
	for popup: ScorePopup in hud.active_score_popups():
		popup.deactivate()


func _capture_blast_push_evidence(
	main: Main,
	board: Board3D,
	resolver: CollisionResolver
) -> void:
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	manager.set_physics_process(false)
	var profiles: Array[Dictionary] = [
		{"tag": "k0", "common": false, "speed": 900.0, "far": 0.4, "pause": 0.0, "lift": 0.0, "base": 129},
		{"tag": "k4", "common": true, "speed": 1350.0, "far": 0.5, "pause": 0.2, "lift": 0.0, "base": 137},
	]
	for profile: Dictionary in profiles:
		Config.data.jelly_tap_common_push = bool(profile["common"])
		Config.data.blast_speed = float(profile["speed"])
		Config.data.blast_far_factor = float(profile["far"])
		Config.data.blast_gravity_pause_time = float(profile["pause"])
		Config.data.jelly_tap_lift_speed = float(profile["lift"])
		Config.data.jelly_tap_push_radius_factor = 0.0
		Config.data.jelly_tap_push_speed = 0.0
		await _capture_blast_push_case(
			board, resolver, str(profile["tag"]), "big", int(profile["base"])
		)
		await _capture_blast_push_case(
			board, resolver, str(profile["tag"]), "yellow", int(profile["base"]) + 4
		)
	await _capture("145_jelly_blast_push_full.png")


func _capture_tap_lift_evidence(board: Board3D, resolver: CollisionResolver) -> void:
	Config.data.jelly_tap_common_push = true
	Config.data.blast_speed = 1350.0
	Config.data.blast_far_factor = 0.5
	Config.data.blast_gravity_pause_time = 0.2
	Config.data.jelly_tap_push_radius_factor = 0.0
	Config.data.jelly_tap_push_speed = 0.0
	var profiles: Array[Dictionary] = [
		{"tag": "0", "lift": 0.0, "base": 146},
		{"tag": "900", "lift": 900.0, "base": 150},
	]
	for profile: Dictionary in profiles:
		Config.data.jelly_tap_lift_speed = float(profile["lift"])
		await _capture_blast_push_case(
			board,
			resolver,
			str(profile["tag"]),
			"yellow",
			int(profile["base"]),
			"tap_lift"
		)
	Config.data.jelly_tap_lift_speed = 900.0
	await _capture("154_jelly_tap_lift_full.png")


func _capture_tap_push_evidence(
	main: Main,
	board: Board3D,
	resolver: CollisionResolver
) -> void:
	Config.data.jelly_tap_common_push = true
	Config.data.blast_speed = 1350.0
	Config.data.blast_far_factor = 0.5
	Config.data.blast_gravity_pause_time = 0.2
	var profiles: Array[Dictionary] = [
		{"tag": "l9", "lift": 900.0, "radius": 0.0, "speed": 0.0, "base": 155},
		{"tag": "t0", "lift": 0.0, "radius": 0.0, "speed": 0.0, "base": 163},
		{"tag": "t3", "lift": 0.0, "radius": 0.5, "speed": 1800.0, "base": 171},
	]
	for profile: Dictionary in profiles:
		Config.data.jelly_tap_lift_speed = float(profile["lift"])
		Config.data.jelly_tap_push_radius_factor = float(profile["radius"])
		Config.data.jelly_tap_push_speed = float(profile["speed"])
		_clear_tap_push_capture_residue(main)
		await _capture_blast_push_case(
			board,
			resolver,
			str(profile["tag"]),
			"center",
			int(profile["base"]),
			"tap_push",
			main
		)
		_clear_tap_push_capture_residue(main)
		await _capture_blast_push_case(
			board,
			resolver,
			str(profile["tag"]),
			"yellow",
			int(profile["base"]) + 4,
			"tap_push",
			main
		)
	Config.data.jelly_tap_lift_speed = 0.0
	Config.data.jelly_tap_push_radius_factor = 0.5
	Config.data.jelly_tap_push_speed = 1800.0
	_clear_tap_push_capture_residue(main)
	await _capture("179_jelly_tap_push_full.png")


func _clear_tap_push_capture_residue(main: Main) -> void:
	var director: FeedbackDirector = main.get_node("FeedbackDirector") as FeedbackDirector
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	director.clear_effects()
	for popup: ScorePopup in hud.active_score_popups():
		popup.deactivate()
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._hide_callout_label()
	manager.turn_combo = 0
	manager._emit_combo_changed()


func _capture_blast_push_case(
	board: Board3D,
	resolver: CollisionResolver,
	profile_tag: String,
	kind: String,
	first_file_number: int,
	file_prefix: String = "blast_push",
	main: Main = null
) -> void:
	resolver.cancel_active_jelly_merges()
	board.clear()
	board.set_gravity(Vector2i.DOWN)
	await get_tree().process_frame
	for row: int in range(4):
		for column: int in range(6):
			var color: int = (column + row * 2) % 5
			var position: Vector2 = Vector2(
				(float(column) - 2.5) * 110.0,
				(float(row) - 1.5) * 110.0
			)
			if kind == "yellow":
				position = Vector2(
					(float(column) - 2.5) * 110.0,
					board.half_size() - 52.0 - float(row) * 108.0
				)
			board.spawn_orb(color, 3, position)
	if kind == "big":
		var first: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 8, Vector2(-4.0, 0.0))
		var second: Orb3D = board.spawn_orb(OrbTypes.OrbColor.BLUE, 8, Vector2(4.0, 0.0))
		resolver.report_contact(first, second, "capture_blast_push_big")
		if resolver.flush() != 1:
			_fail("%s big blast evidence did not trigger" % profile_tag)
	else:
		var source_position: Vector2 = (
			Vector2.ZERO
			if kind == "center"
			else Vector2(0.0, board.half_size() - 52.0 - 4.8 * 108.0)
		)
		var source_level: int = 8 if file_prefix == "tap_push" else 10
		var source: Orb3D = board.spawn_orb(
			OrbTypes.OrbColor.YELLOW,
			source_level,
			source_position
		)
		if not resolver.apply_jelly_tap_blast(source):
			_fail("%s yellow tap evidence did not trigger" % profile_tag)
		if main != null:
			_clear_tap_push_capture_residue(main)
	var suffixes: Array[String] = ["000", "010", "020", "040"]
	var waits: Array[int] = [0, 12, 12, 24]
	for index: int in range(suffixes.size()):
		await _wait_physics_frames(waits[index])
		await _capture("%03d_jelly_%s_%s_%s_%s.png" % [
			first_file_number + index,
			file_prefix,
			profile_tag,
			kind,
			suffixes[index],
		])


func _capture_tap_blast_progress(
	board: Board3D,
	director: FeedbackDirector,
	profile: String
) -> void:
	var first_file_number: int = 89 if profile == "A" else 92
	board.clear()
	director.clear_effects()
	var source: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.YELLOW,
		Config.data.orb_max_level,
		Vector2.ZERO
	)
	source.disable_physics()
	await _capture("%02d_jelly_tap_blast_%s_00.png" % [
		first_file_number,
		profile.to_lower(),
	])
	board.clear()
	director.clear_effects()
	var original_hitstop_enabled: bool = Config.data.fx_hitstop_enabled
	Config.data.fx_hitstop_enabled = false
	director.play_reaction_visuals(_tap_blast_capture_reaction())
	await get_tree().create_timer(FeedbackDirector.SUPERNOVA_DURATION * 0.5).timeout
	await _capture("%02d_jelly_tap_blast_%s_50.png" % [
		first_file_number + 1,
		profile.to_lower(),
	])
	await get_tree().create_timer(FeedbackDirector.SUPERNOVA_DURATION * 0.5).timeout
	await _capture("%02d_jelly_tap_blast_%s_100.png" % [
		first_file_number + 2,
		profile.to_lower(),
	])
	Config.data.fx_hitstop_enabled = original_hitstop_enabled


func _tap_blast_capture_reaction(level: int = -1) -> Dictionary:
	var resolved_level: int = Config.data.orb_max_level if level < 0 else level
	return {
		"type": ReactionRules.Type.TAP_BLAST,
		"levels": [resolved_level],
		"colors": [OrbTypes.OrbColor.YELLOW],
		"position": Vector2.ZERO,
		"shock_level": resolved_level,
		"blast_radius_factor": Config.data.jelly_tap_blast_radius_factor,
	}


func _capture_level_ten_pair_effect(
	main: Main,
	board: Board3D,
	director: FeedbackDirector,
	profile: String,
	jackpot: bool
) -> void:
	board.clear()
	director.clear_effects()
	var first_color: int = OrbTypes.OrbColor.RED
	var second_color: int = first_color if jackpot else OrbTypes.OrbColor.BLUE
	_spawn_specs(board, [
		{
			"color": first_color,
			"level": Config.data.orb_max_level,
			"mass": Config.data.jelly_mass_for_level(Config.data.orb_max_level),
			"position": Vector2(-150.0, 0.0),
		},
		{
			"color": second_color,
			"level": Config.data.orb_max_level,
			"mass": Config.data.jelly_mass_for_level(Config.data.orb_max_level),
			"position": Vector2(150.0, 0.0),
		},
	])
	var reaction: Dictionary = {
		"type": ReactionRules.Type.MAX_CLEAR if jackpot else ReactionRules.Type.BLAST,
		"levels": [Config.data.orb_max_level, Config.data.orb_max_level],
		"colors": [first_color, second_color],
		"result_color": first_color,
		"position": Vector2.ZERO,
		"shock_level": Config.data.orb_max_level,
	}
	if jackpot:
		var manager: TurnManager = main.get_node("TurnManager") as TurnManager
		var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
		manager.turn_combo = 0
		manager._emit_combo_changed()
		score.reset()
		manager.on_reaction(reaction)
		var expected_points: int = int(
			float(Config.data.score_for_level(Config.data.orb_max_level))
			* Config.data.max_merge_bonus_factor
		)
		if int(reaction.get("points", 0)) != expected_points:
			_fail("jackpot capture expected %d points, got %d" % [
				expected_points,
				int(reaction.get("points", 0)),
			])
		if profile == "B" and expected_points != 5120:
			_fail("default L10 jackpot capture expected 5120 points")
	else:
		director.play_reaction_visuals(reaction)
	await get_tree().create_timer(0.06).timeout
	var file_number: int = (
		97 if jackpot and profile == "A"
		else 98 if jackpot
		else 95 if profile == "A"
		else 96
	)
	await _capture("%02d_jelly_l10_%s_%s.png" % [
		file_number,
		"jackpot" if jackpot else "blast",
		profile.to_lower(),
	])


func _set_jelly_level_profile(profile: String) -> void:
	Config.data.orb_max_level = 10
	Config.data.jelly_merge_level_gap = 1
	Config.data.jelly_blast_min_level = 8
	Config.data.jelly_blast_requires_same_level = false
	Config.data.jelly_tap_blast_min_level = 8
	Config.data.blast_score_factor = 15.0
	Config.data.jelly_tap_blast_score_factor = 0.5
	Config.data.jelly_tap_blast_uses_turn = true
	Config.data.max_merge_bonus_factor = 40.0
	Config.data.orb_friction_by_level = PackedFloat32Array([
		0.3, 0.3, 0.3, 0.4, 0.4, 0.4, 0.4, 0.5, 0.5, 0.5,
	])
	if profile == "A":
		Config.data.jelly_level_masses = PackedFloat32Array([
			1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0, 128.0, 256.0, 512.0,
		])
		Config.data.level_radii = PackedFloat32Array([
			25.0, 40.0, 47.0, 55.0, 64.0, 75.0, 88.0, 102.0, 120.0, 140.0,
		])
		Config.data.level_scores = PackedInt32Array([
			2, 4, 8, 16, 32, 64, 128, 256, 512, 1024,
		])
		return
	Config.data.jelly_level_masses = PackedFloat32Array([
		1.0, 2.0, 3.0, 5.0, 7.0, 11.0, 17.0, 27.0, 42.0, 64.0,
	])
	Config.data.level_radii = PackedFloat32Array([
		25.0, 40.0, 52.0, 68.0, 80.0, 92.0, 102.0, 115.0, 128.0, 140.0,
	])
	Config.data.level_scores = PackedInt32Array([
		2, 4, 6, 10, 14, 22, 34, 54, 84, 128,
	])


func _capture_turn_hud_scene(main: Main, manager: TurnManager, hud: Hud) -> void:
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	var spawner: Spawner = main.get_node("Spawner") as Spawner
	manager._set_state(TurnManager.State.SIMULATING)
	manager.turn_index = 124
	manager._set_state(TurnManager.State.WAITING_INPUT)
	spawner.sync_next_batch_size(125)
	score.score = 1234567
	score.best_score = 9876543
	score.score_changed.emit(score.score, score.best_score)
	await get_tree().create_timer(Hud.SCORE_ROLL_DURATION + 0.05).timeout
	if hud._turn_label.text != "125":
		_fail("three-digit TURN capture does not show 125")
	if hud._score_label.text != "1234567":
		_fail("seven-digit SCORE capture does not show 1234567")
	var expected_budget: int = Config.data.spawn_count_for_turn(125)
	for batch: Array in spawner.peek_preview():
		if _preview_batch_cost(batch) != expected_budget:
			_fail("three-digit TURN capture preview does not use turn 125 budget")
	await _capture("71_jelly_turn_hud_three_digit.png")


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
		{"color": OrbTypes.OrbColor.RED, "level": 6, "mass": 32.0, "position": Vector2(-120.0, 0.0)},
		{"color": OrbTypes.OrbColor.BLUE, "level": 6, "mass": 32.0, "position": Vector2(120.0, 0.0)},
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
	# The blast-face art is intentionally unreachable with the J7 default because
	# L7 keeps the MAX face. Preserve its isolated visual regression fixture by
	# lowering only this fixture's threshold, then restore the product default.
	var default_blast_min_level: int = Config.data.jelly_blast_min_level
	Config.data.jelly_blast_min_level = 5
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
	Config.data.jelly_blast_min_level = default_blast_min_level

	board.clear()
	var belly_half: Orb3D = board.spawn_orb(OrbTypes.OrbColor.GREEN, 3, Vector2(-100.0, 0.0))
	var belly_three_quarter: Orb3D = board.spawn_orb(OrbTypes.OrbColor.GREEN, 3, Vector2(100.0, 0.0))
	belly_half.set_jelly_mass(6.0, Config.data)
	belly_three_quarter.set_jelly_mass(6.5, Config.data)
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
	manager.gravity = Vector2i.RIGHT
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
	if hud.get_node_or_null("BlockedPanel") != null or hud.get_node_or_null("BlockedLabel") != null:
		_fail("blocked text panel still exists in the warning capture")
	await _capture("30_board_blocked.png")
	await _capture("31_turn_input_ready.png")
	var indicator: TurnInputIndicator = main.get_node(
		"UI/Hud/TurnInputIndicator"
	) as TurnInputIndicator
	if indicator.is_direction_selectable(Vector2i.RIGHT):
		_fail("current RIGHT gravity arrow is still selectable in the ready capture")
	print("SCREEN_CAPTURE_CHECK scene=input_ready current=RIGHT visible=UP,DOWN,LEFT hidden=RIGHT")

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
	_report_callout_fit("34_callout_great", hud)
	await _capture("34_callout_great.png")
	hud._show_callout("INCREDIBLE!", 3)
	await get_tree().create_timer(0.10).timeout
	_report_callout_fit("35_callout_incredible", hud)
	await _capture("35_callout_incredible.png")
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._hide_callout_label()

	hud._on_reaction_scored({
		"type": ReactionRules.Type.MERGE,
		"result_color": OrbTypes.OrbColor.CYAN,
		"result_level": 3,
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
		"levels": [5, 5],
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

	var extra_callouts: Array[Dictionary] = [
		{"text": "NICE!", "stage": 0, "file": "57_callout_nice.png"},
		{"text": "AMAZING!", "stage": 2, "file": "58_callout_amazing.png"},
		{"text": "UNSTOPPABLE!", "stage": 4, "file": "59_callout_unstoppable.png"},
	]
	for callout: Dictionary in extra_callouts:
		hud._show_callout(str(callout["text"]), int(callout["stage"]))
		await get_tree().create_timer(0.10).timeout
		_report_callout_fit(str(callout["file"]).trim_suffix(".png"), hud)
		await _capture(str(callout["file"]))
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._hide_callout_label()
	print(
		"SCREEN_CAPTURE_CHECK scene=recovered_hud gravity=true danger=true blocked=true "
		+ "input=ready,busy,rejected callouts=nice,great,amazing,incredible,unstoppable "
		+ "popups=merge,blast"
	)


func _capture_recovered_jelly_scenes(
	main: Main,
	manager: TurnManager,
	board: Board3D,
	hud: Hud
) -> void:
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
	hud._on_reaction_scored({
		"type": ReactionRules.Type.MERGE,
		"result_color": OrbTypes.OrbColor.GREEN,
		"result_level": 3,
		"position": Vector2.ZERO,
		"points": 1280,
		"base_points": 1280,
		"combo_multiplier": 1.0,
	})
	await get_tree().create_timer(0.10).timeout
	await _capture("60_popup_crowded.png")
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
	_report_callout_fit("43_jelly_look_unlock", hud)
	await _capture("43_jelly_look_unlock.png")
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._hide_callout_label()

	await _capture_recovered_jelly_motion(main, manager, board)
	await _capture_gravity_turn_scenes(main, manager, board)
	await _capture_spawn_ramp_scenes(main, board, hud)
	await _capture_preview_scale_scenes(board, hud)
	print(
		"SCREEN_CAPTURE_CHECK scene=recovered_jelly levels=7 crowded=25 max=true "
		+ "stretch=true absorption=true unlock=true land_frames=10 breathe=true "
		+ "physical_pile=true right_motion=true gravity_turn_scenes=3 spawn_ramp_scenes=2 "
		+ "preview_scale_scenes=5"
	)


func _capture_spawn_ramp_scenes(main: Main, board: Board3D, hud: Hud) -> void:
	var spawner: Spawner = main.get_node("Spawner") as Spawner
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	board.clear()
	spawner.init_rng(SPAWN_RAMP_CAPTURE_SEED)
	spawner.spawn_initial(board, Vector2i.DOWN)
	var initial_orbs: Array[Orb3D] = board.get_orbs()
	var initial_colors: Array[int] = []
	var initial_positions: Array[Vector2] = []
	var distinct_colors: Dictionary = {}
	for orb: Orb3D in initial_orbs:
		orb.disable_physics()
		initial_colors.append(orb.color)
		initial_positions.append(orb.position)
		distinct_colors[orb.color] = true
		if orb.level != 1:
			_fail("spawn ramp initial capture contains a non-L1 orb")
	if initial_orbs.size() != Config.data.color_count_for_turn(1):
		_fail("spawn ramp initial capture count mismatch")
	if distinct_colors.size() != initial_orbs.size():
		_fail("spawn ramp initial capture colors are not distinct")
	await get_tree().process_frame
	await _capture("64_jelly_initial_four_colors.png")

	var mixed_seed: int = -1
	var preview: Array = []
	for candidate_seed: int in range(1, 1001):
		spawner._preview_batches.clear()
		spawner.init_rng(candidate_seed)
		spawner.sync_next_batch_size(21)
		preview = spawner.peek_preview()
		var next_batch: Array = preview[0] as Array
		var levels: Array[int] = []
		for candidate: Dictionary in next_batch:
			levels.append(int(candidate["level"]))
		if next_batch.size() == 2 and levels.has(1) and levels.has(2):
			mixed_seed = candidate_seed
			break
	if mixed_seed < 0:
		_fail("could not find deterministic L1 + L2 budget-three preview")
		return
	manager._set_state(TurnManager.State.SIMULATING)
	manager.turn_index = 20
	manager._set_state(TurnManager.State.WAITING_INPUT)
	hud._on_preview_changed(preview)
	await get_tree().process_frame
	var next_batch: Array = preview[0] as Array
	if _preview_batch_cost(next_batch) != 3:
		_fail("mixed NEXT does not spend budget three")
	if hud._turn_label.text != "21":
		_fail("mixed NEXT capture TURN does not match preview turn 21")
	await _capture("65_jelly_preview_budget_mix.png")
	print(
		(
			"SCREEN_CAPTURE_CHECK scene=spawn_ramp seed=%d preview_turn=21 initial_colors=%s positions=%s "
			+ "next_levels=%s next_cost=%d next_count=%d"
		) % [
			mixed_seed,
			str(initial_colors),
			str(initial_positions),
			str(next_batch.map(func(candidate: Dictionary) -> int: return int(candidate["level"]))),
			_preview_batch_cost(next_batch),
			next_batch.size(),
		]
	)


func _preview_batch_cost(batch: Array) -> int:
	var total: int = 0
	for candidate: Dictionary in batch:
		total += Config.data.spawn_cost_for_level(int(candidate["level"]))
	return total


func _capture_preview_scale_scenes(board: Board3D, hud: Hud) -> void:
	board.clear()
	board.set_gravity(Vector2i.DOWN)
	var board_l1: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.YELLOW,
		1,
		Vector2(-150.0, 40.0)
	)
	var board_l2: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		2,
		Vector2(150.0, 40.0)
	)
	board_l1.disable_physics()
	board_l2.disable_physics()
	var level_pair: Array = [
		{"color": OrbTypes.OrbColor.YELLOW, "level": 1},
		{"color": OrbTypes.OrbColor.BLUE, "level": 2},
	]
	hud._on_preview_changed([level_pair, level_pair])
	await get_tree().process_frame
	await _capture("66_jelly_preview_board_match.png")
	_measure_preview_diameters(board_l1, board_l2, hud)

	var next_one: Array = [{"color": OrbTypes.OrbColor.YELLOW, "level": 1}]
	hud._on_preview_changed([next_one, level_pair])
	await get_tree().process_frame
	await _capture("67_jelly_preview_next_1.png")
	var next_two: Array = [
		{"color": OrbTypes.OrbColor.YELLOW, "level": 1},
		{"color": OrbTypes.OrbColor.BLUE, "level": 2},
	]
	hud._on_preview_changed([next_two, level_pair])
	await get_tree().process_frame
	await _capture("68_jelly_preview_next_2.png")
	var next_five: Array = []
	for index: int in range(5):
		next_five.append({"color": index % 4, "level": 1 + index % 2})
	hud._on_preview_changed([next_five, level_pair])
	await get_tree().process_frame
	await _capture("69_jelly_preview_next_5.png")

	var then_l2_five: Array = []
	for index: int in range(5):
		then_l2_five.append({"color": index % 4, "level": 2})
	hud._on_preview_changed([next_one, then_l2_five])
	await get_tree().process_frame
	await _capture("70_jelly_preview_then_l2_5.png")


func _capture_jelly_merge_process_scenes(
	board: Board3D,
	resolver: CollisionResolver,
	manager: TurnManager
) -> void:
	var original_duration: float = Config.data.jelly_merge_duration
	var original_scan: bool = resolver.proximity_reaction_scan_enabled
	Config.data.jelly_merge_duration = 0.3
	resolver.proximity_reaction_scan_enabled = false
	await _capture_jelly_merge_process_case(
		board, resolver, manager, 2, 2.0, 2, 2.0, 72
	)
	await _capture_jelly_merge_process_case(
		board, resolver, manager, 3, 4.0, 2, 2.0, 77
	)
	await _capture_jelly_merge_process_case(
		board, resolver, manager, 3, 6.0, 2, 2.0, 82
	)
	resolver.proximity_reaction_scan_enabled = original_scan
	Config.data.jelly_merge_duration = original_duration


func _capture_jelly_merge_process_case(
	board: Board3D,
	resolver: CollisionResolver,
	manager: TurnManager,
	first_level: int,
	first_mass: float,
	second_level: int,
	second_mass: float,
	file_number: int
) -> void:
	resolver.cancel_active_jelly_merges()
	board.clear()
	manager.turn_combo = 0
	manager.max_combo = 0
	manager._emit_combo_changed()
	await get_tree().process_frame
	var first: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.PURPLE,
		first_level,
		Vector2.ZERO
	)
	var second: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.PURPLE,
		second_level,
		Vector2.ZERO
	)
	first.set_jelly_mass(first_mass, Config.data)
	second.set_jelly_mass(second_mass, Config.data)
	var touching_distance: float = first.get_current_radius() + second.get_current_radius()
	first.position = Vector2(-touching_distance * 0.5, 0.0)
	second.position = Vector2(touching_distance * 0.5, 0.0)
	first.linear_velocity = Vector2.ZERO
	second.linear_velocity = Vector2.ZERO
	resolver.report_contact(first, second, "capture")
	resolver.flush()
	for stage: int in range(5):
		if stage > 0:
			var active_before: Array[Orb3D] = board.get_orbs()
			resolver.flush(Config.data.jelly_merge_duration * 0.25)
			for orb: Orb3D in active_before:
				if is_instance_valid(orb):
					orb._physics_process(Config.data.jelly_merge_duration * 0.25)
		await get_tree().process_frame
		await _capture("%02d_jelly_merge_process_%s_%02d.png" % [
			file_number + stage,
			(
				"equal" if file_number == 72
				else "absorb" if file_number == 77
				else "level_up"
			),
			stage * 25,
		])
	await get_tree().create_timer(1.0).timeout


func _measure_preview_diameters(board_l1: Orb3D, board_l2: Orb3D, hud: Hud) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		_fail("preview diameter measurement has no camera")
		return
	var board_l1_px: float = _orb_screen_diameter(camera, board_l1)
	var board_l2_px: float = _orb_screen_diameter(camera, board_l2)
	var next_l1: OrbVisual = hud._next_preview.get_child(0) as OrbVisual
	var next_l2: OrbVisual = hud._next_preview.get_child(1) as OrbVisual
	var then_l1: OrbVisual = hud._then_preview.get_child(0) as OrbVisual
	var then_l2: OrbVisual = hud._then_preview.get_child(1) as OrbVisual
	var next_l1_px: float = _preview_screen_diameter(next_l1, 1)
	var next_l2_px: float = _preview_screen_diameter(next_l2, 2)
	var then_l1_px: float = _preview_screen_diameter(then_l1, 1)
	var then_l2_px: float = _preview_screen_diameter(then_l2, 2)
	print(
		(
			"JELLY_PREVIEW_SIZE_CHECK board_l1=%.3f next_l1=%.3f then_l1=%.3f "
			+ "board_l2=%.3f next_l2=%.3f then_l2=%.3f"
		) % [
			board_l1_px,
			next_l1_px,
			then_l1_px,
			board_l2_px,
			next_l2_px,
			then_l2_px,
		]
	)
	for comparison: Vector2 in [
		Vector2(board_l1_px, next_l1_px),
		Vector2(board_l1_px, then_l1_px),
		Vector2(board_l2_px, next_l2_px),
		Vector2(board_l2_px, then_l2_px),
	]:
		var difference_ratio: float = absf(comparison.x - comparison.y) / maxf(
			comparison.x,
			0.001
		)
		if difference_ratio > 0.05:
			_fail("preview body diameter differs from board by more than five percent")


func _orb_screen_diameter(camera: Camera3D, orb: Orb3D) -> float:
	var body: RigidBody3D = orb.get_physics_body()
	var center: Vector2 = camera.unproject_position(body.global_position)
	var edge_world: Vector3 = body.global_position + (
		body.global_transform.basis.x.normalized()
		* orb.get_current_radius()
		/ Board3D.PIXELS_PER_METER
	)
	return center.distance_to(camera.unproject_position(edge_world)) * 2.0


func _preview_screen_diameter(visual: OrbVisual, level: int) -> float:
	return (
		Config.data.radius_for_level(level)
		* 2.0
		* visual.global_transform.x.length()
	)


func _capture_recovered_jelly_motion(
	main: Main,
	manager: TurnManager,
	board: Board3D
) -> void:
	var resolver: CollisionResolver = main.get_node("CollisionResolver") as CollisionResolver
	resolver.set_physics_process(false)
	resolver._pending.clear()
	board.clear()
	manager._set_state(TurnManager.State.SIMULATING)
	board.set_turn_resting(false)
	board.set_gravity(Vector2i.DOWN)
	var landing: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		7,
		Vector2(0.0, -330.0)
	)
	var landing_states: Dictionary = {}
	var landing_scales: Dictionary = {}
	await _wait_physics_seconds(0.08)
	for falling_index: int in range(4):
		await _capture_landing_frame(landing, falling_index, landing_states, landing_scales)
		if falling_index < 3:
			await _wait_physics_seconds(0.12)

	var contact_wait_frames: int = 0
	while (
		landing.get_physics_body().get_colliding_bodies().is_empty()
		and contact_wait_frames < Engine.physics_ticks_per_second
	):
		await get_tree().physics_frame
		contact_wait_frames += 1
	if landing.get_physics_body().get_colliding_bodies().is_empty():
		_fail("JELLY landing capture did not reach the physical floor")
	await _capture_landing_frame(landing, 4, landing_states, landing_scales)
	var recovery_frame_steps: Array[int] = [2, 4, 8, 14, 24]
	for recovery_index: int in range(recovery_frame_steps.size()):
		await _wait_physics_frames(recovery_frame_steps[recovery_index])
		await _capture_landing_frame(
			landing,
			5 + recovery_index,
			landing_states,
			landing_scales
		)
	if landing_states.size() != 10:
		_fail("JELLY landing captures must contain ten distinct physical states")
	if landing_scales.size() < 5:
		_fail("JELLY landing captures must show at least five distinct body scales")

	board.clear()
	board.set_gravity(Vector2i.DOWN)
	var breathing: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 7, Vector2.ZERO)
	breathing.disable_physics()
	breathing.set_turn_resting(true)
	breathing._jelly_breath_weight = 1.0
	breathing._jelly_idle_elapsed = PI / (2.0 * 1.8)
	breathing._process(0.0)
	await _capture("54_jelly_motion_breathe_max.png")

	board.clear()
	board.set_turn_resting(false)
	board.set_gravity(Vector2i.DOWN)
	var pile_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	pile_rng.seed = PILE_JITTER_SEED
	for orb_index: int in range(40):
		var column: int = orb_index % 8
		var row: int = orb_index / 8
		board.spawn_orb(
			orb_index % JellyOrbArt.PALETTE.size(),
			1,
			Vector2(
				-315.0 + float(column) * 90.0 + pile_rng.randf_range(-10.0, 10.0),
				-360.0 + float(row) * 78.0
			)
		)
	var settle_directions: Array[Vector2i] = [
		Vector2i.DOWN,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.LEFT,
		Vector2i.DOWN,
	]
	for direction: Vector2i in settle_directions:
		board.set_gravity(direction)
		await _wait_physics_seconds(1.2)
	board.set_gravity(Vector2i.DOWN)
	await _wait_physics_seconds(1.8)
	var resting_pairs: int = _count_actual_orb_contact_pairs(board)
	var boundary_contacts: Dictionary = _count_pile_boundary_contacts(board)
	var resting_height: float = _pile_height(board)
	var resting_longest_line: int = _longest_pile_support_line(board, Vector2i.DOWN)
	if resting_pairs <= 0:
		_fail("JELLY rest capture must contain actual orb contact pairs")
	if (
		int(boundary_contacts["floor"]) <= 0
		or int(boundary_contacts["walls"]) <= 0
		or int(boundary_contacts["corners"]) <= 0
	):
		_fail("JELLY rest capture must physically touch floor, walls, and corners")
	board.set_turn_resting(true)
	await get_tree().create_timer(0.25).timeout
	await _capture("55_jelly_motion_rest.png")

	board.set_turn_resting(false)
	board.set_gravity(Vector2i.RIGHT)
	await _wait_physics_seconds(0.22)
	var moving_count: int = 0
	var maximum_speed: float = 0.0
	for moving: Orb3D in board.get_orbs():
		var speed: float = moving.linear_velocity.length()
		maximum_speed = maxf(maximum_speed, speed)
		if speed > Config.data.stable_linear_speed:
			moving_count += 1
	var moving_pairs: int = _count_actual_orb_contact_pairs(board)
	if moving_count <= 0:
		_fail("JELLY right-gravity capture must contain moving physical orbs")
	if moving_pairs <= 0:
		_fail("JELLY right-gravity capture must retain actual pile contacts")
	await _capture("56_jelly_motion_right.png")
	print(
		(
			"JELLY_MOTION_PILE orbs=%d rest_pairs=%d floor=%d walls=%d corners=%d "
			+ "rest_height=%.3f longest_line=%d right_moving=%d right_pairs=%d "
			+ "right_max_speed=%.3f jitter_seed=%d"
		) % [
			board.get_orbs().size(),
			resting_pairs,
			int(boundary_contacts["floor"]),
			int(boundary_contacts["walls"]),
			int(boundary_contacts["corners"]),
			resting_height,
			resting_longest_line,
			moving_count,
			moving_pairs,
			maximum_speed,
			PILE_JITTER_SEED,
		]
	)
	resolver._pending.clear()
	manager._set_state(TurnManager.State.WAITING_INPUT)
	InputRouter.set_locked(false)


func _capture_gravity_turn_scenes(
	main: Main,
	manager: TurnManager,
	board: Board3D
) -> void:
	var resolver: CollisionResolver = main.get_node("CollisionResolver") as CollisionResolver
	resolver.set_physics_process(false)
	resolver._pending.clear()
	manager._set_state(TurnManager.State.SIMULATING)
	board.set_turn_resting(false)
	board.clear()
	var configured_time: float = Config.data.gravity_turn_diagonal_time
	Config.data.gravity_turn_diagonal_time = 0.0
	board.set_gravity(Vector2i.LEFT)
	var diagonal_orb: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		1,
		Vector2(0.0, -300.0)
	)
	var diagonal_body: RigidBody3D = diagonal_orb.get_physics_body()
	diagonal_body.freeze = true
	diagonal_orb.linear_velocity = Vector2.ZERO
	Config.data.gravity_turn_diagonal_time = configured_time
	board.set_gravity(Vector2i.DOWN)
	diagonal_body.freeze = false
	diagonal_body.sleeping = false
	await _wait_physics_frames(
		maxi(ceili(configured_time * float(Engine.physics_ticks_per_second)) / 2, 1)
	)
	var diagonal_direction: Vector2 = board.actual_gravity_direction()
	if diagonal_direction.distance_to(Vector2(-1.0, 1.0).normalized()) > 0.001:
		_fail("JELLY left-to-down capture must use left-down gravity")
	await _capture("61_jelly_gravity_left_down_diagonal.png")
	print(
		"JELLY_GRAVITY_DIAGONAL direction=(%.6f,%.6f) position=(%.3f,%.3f) speed=%.3f" % [
			diagonal_direction.x,
			diagonal_direction.y,
			diagonal_orb.position.x,
			diagonal_orb.position.y,
			diagonal_orb.linear_velocity.length(),
		]
	)

	var left_pile: Dictionary = await _capture_gravity_turn_pile(
		board,
		Vector2i.LEFT,
		"62_jelly_gravity_left_down_rest.png"
	)
	var right_pile: Dictionary = await _capture_gravity_turn_pile(
		board,
		Vector2i.RIGHT,
		"63_jelly_gravity_right_down_rest.png"
	)
	print(
		(
			"JELLY_GRAVITY_PILES left_com_x=%.3f left_width=%.3f left_height=%.3f "
			+ "left_line=%d right_com_x=%.3f right_width=%.3f right_height=%.3f "
			+ "right_line=%d jitter_seed=%d"
		) % [
			float(left_pile["center_of_mass_x"]),
			float(left_pile["width"]),
			float(left_pile["height"]),
			int(left_pile["longest_line"]),
			float(right_pile["center_of_mass_x"]),
			float(right_pile["width"]),
			float(right_pile["height"]),
			int(right_pile["longest_line"]),
			PILE_JITTER_SEED,
		]
	)
	Config.data.gravity_turn_diagonal_time = configured_time
	resolver._pending.clear()
	manager._set_state(TurnManager.State.WAITING_INPUT)
	InputRouter.set_locked(false)


func _capture_gravity_turn_pile(
	board: Board3D,
	initial_direction: Vector2i,
	file_name: String
) -> Dictionary:
	board.clear()
	board.set_turn_resting(false)
	var pile_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	pile_rng.seed = PILE_JITTER_SEED
	for orb_index: int in range(40):
		var column: int = orb_index % 8
		var row: int = orb_index / 8
		board.spawn_orb(
			orb_index % JellyOrbArt.PALETTE.size(),
			1,
			Vector2(
				-315.0 + float(column) * 90.0 + pile_rng.randf_range(-10.0, 10.0),
				-360.0 + float(row) * 78.0
			)
		)
	var settle_directions: Array[Vector2i] = [
		Vector2i.DOWN,
		-initial_direction,
		Vector2i.UP,
		initial_direction,
	]
	for direction: Vector2i in settle_directions:
		board.set_gravity(direction)
		await _wait_physics_seconds(1.2)
	board.set_gravity(Vector2i.DOWN)
	var settle_frames: int = await _wait_gravity_pile_stable(board, 5.0)
	if settle_frames >= Engine.physics_ticks_per_second * 5:
		_fail("JELLY gravity turn pile did not settle before timeout")
	var contacts: int = _count_actual_orb_contact_pairs(board)
	if contacts <= 0:
		_fail("JELLY gravity turn pile must retain physical contacts")
	board.set_turn_resting(true)
	await get_tree().create_timer(0.25).timeout
	await _capture(file_name)
	return {
		"center_of_mass_x": _pile_center_of_mass_x(board),
		"width": _pile_width(board),
		"height": _pile_height(board),
		"longest_line": _longest_pile_support_line(board, Vector2i.DOWN),
		"contacts": contacts,
		"settle_frames": settle_frames,
	}


func _wait_gravity_pile_stable(board: Board3D, timeout_seconds: float) -> int:
	var stable_frames: int = 0
	var required_frames: int = ceili(
		Config.data.stable_duration * float(Engine.physics_ticks_per_second)
	)
	var maximum_frames: int = ceili(timeout_seconds * float(Engine.physics_ticks_per_second))
	for frame_index: int in range(maximum_frames):
		await get_tree().physics_frame
		var stable: bool = not board.is_gravity_transition_active()
		if stable:
			for orb: Orb3D in board.get_orbs():
				if (
					orb.linear_velocity.length() > Config.data.stable_linear_speed
					or absf(orb.angular_velocity) > Config.data.stable_angular_speed
				):
					stable = false
					break
		stable_frames = stable_frames + 1 if stable else 0
		if stable_frames >= required_frames:
			return frame_index + 1
	return maximum_frames


func _capture_landing_frame(
	landing: Orb3D,
	frame_index: int,
	state_keys: Dictionary,
	scale_keys: Dictionary
) -> void:
	await _capture("%02d_jelly_motion_land_%02d.png" % [44 + frame_index, frame_index + 1])
	var body_scale: Vector3 = landing.visual_stretch_scale()
	var position_value: Vector2 = landing.position
	var velocity_value: Vector2 = landing.linear_velocity
	var contact_count: int = landing.get_physics_body().get_colliding_bodies().size()
	var state_key: String = "%.3f|%.3f|%.4f|%.4f" % [
		position_value.x,
		position_value.y,
		body_scale.x,
		body_scale.y,
	]
	var scale_key: String = "%.4f|%.4f" % [body_scale.x, body_scale.y]
	state_keys[state_key] = true
	scale_keys[scale_key] = true
	print(
		(
			"JELLY_LANDING_FRAME index=%02d position_y=%.3f speed=%.3f "
			+ "scale_x=%.6f scale_y=%.6f contacts=%d"
		) % [
			frame_index + 1,
			position_value.y,
			velocity_value.length(),
			body_scale.x,
			body_scale.y,
			contact_count,
		]
	)


func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await get_tree().physics_frame


func _wait_physics_seconds(duration: float) -> void:
	await _wait_physics_frames(ceili(maxf(duration, 0.0) * Engine.physics_ticks_per_second))


func _count_actual_orb_contact_pairs(board: Board3D) -> int:
	var pair_keys: Dictionary = {}
	for first: Orb3D in board.get_orbs():
		for second: Orb3D in first.get_colliding_orbs():
			if not is_instance_valid(second) or second.consumed:
				continue
			var first_id: int = first.get_instance_id()
			var second_id: int = second.get_instance_id()
			var pair_key: String = "%d:%d" % [mini(first_id, second_id), maxi(first_id, second_id)]
			pair_keys[pair_key] = true
	return pair_keys.size()


func _count_pile_boundary_contacts(board: Board3D) -> Dictionary:
	var half_size: float = Config.data.board_size * 0.5
	var tolerance: float = Config.data.floor_contact_tolerance + 4.0
	var floor_contacts: int = 0
	var wall_contacts: int = 0
	var corner_contacts: int = 0
	for orb: Orb3D in board.get_orbs():
		var radius: float = orb.get_current_radius()
		var touches_floor: bool = orb.position.y + radius >= half_size - tolerance
		var touches_side: bool = absf(orb.position.x) + radius >= half_size - tolerance
		if touches_floor:
			floor_contacts += 1
		if touches_side:
			wall_contacts += 1
		if touches_floor and touches_side:
			corner_contacts += 1
	return {
		"floor": floor_contacts,
		"walls": wall_contacts,
		"corners": corner_contacts,
	}


func _pile_height(board: Board3D) -> float:
	var minimum_y: float = INF
	var maximum_y: float = -INF
	for orb: Orb3D in board.get_orbs():
		var radius: float = orb.get_current_radius()
		minimum_y = minf(minimum_y, orb.position.y - radius)
		maximum_y = maxf(maximum_y, orb.position.y + radius)
	return maximum_y - minimum_y


func _pile_width(board: Board3D) -> float:
	var minimum_x: float = INF
	var maximum_x: float = -INF
	for orb: Orb3D in board.get_orbs():
		var radius: float = orb.get_current_radius()
		minimum_x = minf(minimum_x, orb.position.x - radius)
		maximum_x = maxf(maximum_x, orb.position.x + radius)
	return maximum_x - minimum_x


func _pile_center_of_mass_x(board: Board3D) -> float:
	var weighted_x: float = 0.0
	var total_mass: float = 0.0
	for orb: Orb3D in board.get_orbs():
		var mass: float = orb.get_physics_body().mass
		weighted_x += orb.position.x * mass
		total_mass += mass
	return weighted_x / total_mass if total_mass > 0.0 else 0.0


func _longest_pile_support_line(board: Board3D, gravity_direction: Vector2i) -> int:
	var orbs: Array[Orb3D] = board.get_orbs()
	var orb_by_id: Dictionary = {}
	var support_by_id: Dictionary = {}
	var gravity: Vector2 = Vector2(gravity_direction).normalized()
	var minimum_alignment: float = cos(deg_to_rad(10.0))
	for orb: Orb3D in orbs:
		orb_by_id[orb.get_instance_id()] = orb
		var best_support: Orb3D = null
		var best_distance: float = INF
		for candidate: Orb3D in orbs:
			if candidate == orb:
				continue
			var delta: Vector2 = candidate.position - orb.position
			var distance: float = delta.length()
			var contact_distance: float = (
				orb.get_current_radius()
				+ candidate.get_current_radius()
				+ Config.data.floor_contact_tolerance
			)
			if (
				distance > 0.001
				and distance <= contact_distance
				and delta.normalized().dot(gravity) >= minimum_alignment
				and distance < best_distance
			):
				best_support = candidate
				best_distance = distance
		if best_support != null:
			support_by_id[orb.get_instance_id()] = best_support.get_instance_id()
	var longest: int = 0
	for orb: Orb3D in orbs:
		var line_length: int = 1
		var current_id: int = orb.get_instance_id()
		var visited: Dictionary = {current_id: true}
		while support_by_id.has(current_id):
			var support_id: int = int(support_by_id[current_id])
			if visited.has(support_id) or not orb_by_id.has(support_id):
				break
			visited[support_id] = true
			line_length += 1
			current_id = support_id
		longest = maxi(longest, line_length)
	return longest


func _measure_hud_face_overlap(_main: Main, _board: Board3D, hud: Hud) -> void:
	for popup: ScorePopup in hud.active_score_popups():
		popup.deactivate()
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._show_callout("NICE!", 0)
	var callout_face_maximum: float = 0.0
	var callout_face_frames: int = 0
	var callout_board_maximum: float = 0.0
	var callout_board_frames: int = 0
	var sample_frames: int = 120
	var board_rect: Rect2 = hud._projected_board_rect()
	for _frame_index: int in range(sample_frames):
		await get_tree().process_frame
		if not hud._callout_label.visible:
			continue
		var callout_rect: Rect2 = hud._callout_label.get_global_rect()
		var face_ratio: float = _maximum_face_overlap_ratio(
			hud._orb_face_rects(),
			callout_rect
		)
		callout_face_maximum = maxf(callout_face_maximum, face_ratio)
		if face_ratio > 0.0:
			callout_face_frames += 1
		var board_overlap: Rect2 = callout_rect.intersection(board_rect)
		var board_ratio: float = (
			board_overlap.get_area() / maxf(callout_rect.get_area(), 1.0)
			if board_overlap.has_area()
			else 0.0
		)
		callout_board_maximum = maxf(callout_board_maximum, board_ratio)
		if board_ratio > 0.0:
			callout_board_frames += 1
	print(
		(
			"JELLY_CALLOUT_OVERLAP face_max_ratio=%.4f face_seconds=%.3f "
			+ "board_max_ratio=%.4f board_seconds=%.3f sampled_seconds=1.000"
		) % [
			callout_face_maximum,
			float(callout_face_frames) / 120.0,
			callout_board_maximum,
			float(callout_board_frames) / 120.0,
		]
	)
	if callout_face_maximum > 0.0 or callout_board_maximum > 0.0:
		_fail("JELLY callout must not overlap faces or the board")
	if hud._callout_tween != null and hud._callout_tween.is_valid():
		hud._callout_tween.kill()
	hud._hide_callout_label()

	hud._on_reaction_scored({
		"type": ReactionRules.Type.MERGE,
		"result_color": OrbTypes.OrbColor.GREEN,
		"result_level": 3,
		"position": Vector2.ZERO,
		"points": 1280,
		"base_points": 1280,
		"combo_multiplier": 1.0,
	})
	var popup_maximum_ratio: float = 0.0
	var popup_overlap_frames: int = 0
	var popup_outside_maximum: float = 0.0
	for _frame_index: int in range(sample_frames):
		await get_tree().process_frame
		var frame_overlap: bool = false
		for popup: ScorePopup in hud.active_score_popups():
			var popup_rect: Rect2 = popup.visual_global_rect()
			var popup_ratio: float = _maximum_face_overlap_ratio(
				hud._orb_face_rects(),
				popup_rect
			)
			popup_maximum_ratio = maxf(popup_maximum_ratio, popup_ratio)
			frame_overlap = frame_overlap or popup_ratio > 0.0
			popup_outside_maximum = maxf(
				popup_outside_maximum,
				maxf(
					popup_rect.get_area() - popup_rect.intersection(board_rect).get_area(),
					0.0
				)
			)
		if frame_overlap:
			popup_overlap_frames += 1
	print(
		(
			"JELLY_POPUP_FACE_OVERLAP max_ratio=%.4f overlap_seconds=%.3f "
			+ "outside_max_area=%.3f sampled_seconds=1.000"
		) % [
			popup_maximum_ratio,
			float(popup_overlap_frames) / 120.0,
			popup_outside_maximum,
		]
	)
	if popup_outside_maximum > 0.01:
		_fail("JELLY popup must remain inside the physical board")
	for popup: ScorePopup in hud.active_score_popups():
		popup.deactivate()


func _maximum_face_overlap_ratio(face_rects: Array[Rect2], target_rect: Rect2) -> float:
	var maximum_ratio: float = 0.0
	for face_rect: Rect2 in face_rects:
		var overlap: Rect2 = face_rect.intersection(target_rect)
		if overlap.has_area():
			maximum_ratio = maxf(
				maximum_ratio,
				overlap.get_area() / maxf(face_rect.get_area(), 1.0)
			)
	return maximum_ratio


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


func _spawn_l6_normal_and_l8_blast_faces(board: Board3D) -> void:
	_spawn_specs(board, [
		{"color": OrbTypes.OrbColor.RED, "level": 6, "mass": 11.0, "position": Vector2(-260.0, -150.0)},
		{"color": OrbTypes.OrbColor.BLUE, "level": 6, "mass": 11.0, "position": Vector2(-60.0, -150.0)},
		{"color": OrbTypes.OrbColor.GREEN, "level": 8, "mass": 27.0, "position": Vector2(-180.0, 150.0)},
		{"color": OrbTypes.OrbColor.YELLOW, "level": 8, "mass": 27.0, "position": Vector2(180.0, 150.0)},
	])


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


func _report_callout_fit(scene_name: String, hud: Hud) -> void:
	var label: Label = hud._callout_label
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var layout: Dictionary = Hud.hud_layout(
		viewport_size,
		hud._logical_safe_area(viewport_size)
	)
	var callout_rect: Rect2 = hud._callout_layout_rect(viewport_size, layout)
	var base_font_size: int = clampi(
		roundi(callout_rect.size.y * 0.48),
		Hud.CALLOUT_FONT_MIN,
		Hud.CALLOUT_FONT_MAX
	)
	var text_width: float = hud._callout_text_width()
	var local_left: Vector2 = Vector2((label.size.x - text_width) * 0.5, label.size.y * 0.5)
	var local_right: Vector2 = local_left + Vector2(text_width, 0.0)
	var canvas_transform: Transform2D = label.get_global_transform_with_canvas()
	var text_left: float = (canvas_transform * local_left).x
	var text_right: float = (canvas_transform * local_right).x
	var left_margin: float = text_left
	var right_margin: float = viewport_size.x - text_right
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	var pixel_scale_x: float = window_size.x / viewport_size.x
	print(
		(
			"CALLOUT_FIT_CAPTURE scene=%s viewport=%.2fx%.2f font=%d base=%d "
			+ "text_width=%.2f rect_width=%.2f left_margin=%.2f right_margin=%.2f "
			+ "left_margin_px=%.2f right_margin_px=%.2f"
		) % [
			scene_name,
			viewport_size.x,
			viewport_size.y,
			label.get_theme_font_size("font_size"),
			base_font_size,
			text_width,
			callout_rect.size.x,
			left_margin,
			right_margin,
			left_margin * pixel_scale_x,
			right_margin * pixel_scale_x,
		]
	)
	if left_margin < -0.5 or right_margin < -0.5:
		_fail("callout text is outside the viewport in %s" % scene_name)


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
