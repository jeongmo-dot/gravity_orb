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
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.rng_seed = 5050
	await _capture_shell_scenes()
	await _capture_gameplay_scenes()
	_verify_user_save_unchanged()
	_remove_file(_temp_save_path)
	for file_name: String in CAPTURE_FILES:
		if not FileAccess.file_exists(_output_directory.path_join(file_name)):
			_fail("Missing capture %s" % file_name)
	print("SCREEN_CAPTURE_SUITE exit=%d files=%d" % [1 if _failed else 0, CAPTURE_FILES.size()])
	get_tree().quit(1 if _failed else 0)


func _capture_shell_scenes() -> void:
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
	var main: Main = await _create_main(false)
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
	await _destroy_main(main)


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
