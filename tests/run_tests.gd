extends SceneTree

const TEST_DIRECTORIES: Array[String] = ["res://tests", "res://tests/scenarios"]
const TEST_FILE_PREFIX: String = "test_"
const TEST_FILE_SUFFIX: String = ".gd"
const TEST_METHOD_PREFIX: String = "test_"
const GROWTH_DURATION_PREFIX: String = "--growth-duration="
const GROWTH_RATIO_PREFIX: String = "--growth-ratio="
const GROWTH_SUITE_PREFIX: String = "--growth-suite="
const MASS_EXPONENT_PREFIX: String = "--mass-exponent="
const MASS_SUITE_PREFIX: String = "--mass-suite="
const SPAWN_COUNT_PREFIX: String = "--spawn-count="
const ACTIVE_COLORS_PREFIX: String = "--active-colors="
const SPAWN_SUITE_PREFIX: String = "--spawn-suite="
const SPAWN_CASE_PREFIX: String = "--spawn-case="
const GAME_OVER_SUITE_PREFIX: String = "--game-over-suite="
const PHYSICS_GRAVITY_PREFIX: String = "--physics-gravity="
const PHYSICS_FRICTION_PREFIX: String = "--physics-friction="
const PHYSICS_BOUNCE_PREFIX: String = "--physics-bounce="
const PHYSICS_CASE_PREFIX: String = "--physics-case="
const MEASUREMENT_FIXED_TESTS: Array[String] = [
	"res://tests/scenarios/test_board_physics.gd",
	"res://tests/scenarios/test_spawn_flow.gd",
	"res://tests/scenarios/test_turn_time.gd",
]

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	var measurement_suite: String = _apply_measurement_arguments()
	if measurement_suite == "fixed":
		for path: String in MEASUREMENT_FIXED_TESTS:
			await _run_test_file(path)
	elif measurement_suite == "realtime":
		await _run_test_file("res://tests/scenarios/test_turn_time.gd")
	elif measurement_suite == "spawn":
		await _run_test_file("res://tests/scenarios/test_turn_time.gd")
	elif measurement_suite == "game_over_unit":
		await _run_test_file("res://tests/scenarios/test_game_over.gd")
		await _run_test_file("res://tests/scenarios/test_score_flow.gd")
		await _run_test_file("res://tests/scenarios/test_spawn_flow.gd")
		await _run_test_file("res://tests/scenarios/test_turn_manager.gd")
		await _run_test_file("res://tests/scenarios/test_turn_time.gd")
	elif measurement_suite == "game_over_measurement":
		await _run_test_file("res://tests/scenarios/test_game_over_measurement.gd")
	else:
		for directory: String in TEST_DIRECTORIES:
			await _run_directory(directory)

	var total: int = _passed + _failed
	print("Tests: %d passed, %d failed, %d total" % [_passed, _failed, total])
	quit(1 if _failed > 0 else 0)


func _apply_measurement_arguments() -> String:
	var measurement_suite: String = ""
	var is_mass_measurement: bool = false
	var is_spawn_measurement: bool = false
	var config_node: Node = root.get_node("Config")
	var config_data: GameConfig = config_node.get("data") as GameConfig
	var active_colors: int = config_data.spawn_color_weights.size()
	var spawn_case: String = ""
	var physics_case: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(GROWTH_DURATION_PREFIX):
			config_data.grow_duration = argument.trim_prefix(GROWTH_DURATION_PREFIX).to_float()
		elif argument.begins_with(GROWTH_RATIO_PREFIX):
			config_data.grow_start_ratio = argument.trim_prefix(GROWTH_RATIO_PREFIX).to_float()
		elif argument.begins_with(GROWTH_SUITE_PREFIX):
			measurement_suite = argument.trim_prefix(GROWTH_SUITE_PREFIX)
		elif argument.begins_with(MASS_EXPONENT_PREFIX):
			config_data.mass_exponent = argument.trim_prefix(MASS_EXPONENT_PREFIX).to_float()
			is_mass_measurement = true
		elif argument.begins_with(MASS_SUITE_PREFIX):
			measurement_suite = argument.trim_prefix(MASS_SUITE_PREFIX)
			is_mass_measurement = true
		elif argument.begins_with(SPAWN_COUNT_PREFIX):
			config_data.spawn_count_per_turn = argument.trim_prefix(SPAWN_COUNT_PREFIX).to_int()
			is_spawn_measurement = true
		elif argument.begins_with(ACTIVE_COLORS_PREFIX):
			active_colors = argument.trim_prefix(ACTIVE_COLORS_PREFIX).to_int()
			is_spawn_measurement = true
		elif argument.begins_with(SPAWN_SUITE_PREFIX):
			measurement_suite = "spawn"
			is_spawn_measurement = true
		elif argument.begins_with(SPAWN_CASE_PREFIX):
			spawn_case = argument.trim_prefix(SPAWN_CASE_PREFIX).to_upper()
			measurement_suite = "spawn"
			is_spawn_measurement = true
		elif argument.begins_with(GAME_OVER_SUITE_PREFIX):
			measurement_suite = "game_over_%s" % argument.trim_prefix(
				GAME_OVER_SUITE_PREFIX
			)
		elif argument.begins_with(PHYSICS_GRAVITY_PREFIX):
			config_data.gravity_strength = argument.trim_prefix(
				PHYSICS_GRAVITY_PREFIX
			).to_float()
		elif argument.begins_with(PHYSICS_FRICTION_PREFIX):
			var friction: float = argument.trim_prefix(PHYSICS_FRICTION_PREFIX).to_float()
			config_data.orb_friction = friction
			config_data.wall_friction = friction
		elif argument.begins_with(PHYSICS_BOUNCE_PREFIX):
			config_data.orb_bounce = argument.trim_prefix(PHYSICS_BOUNCE_PREFIX).to_float()
		elif argument.begins_with(PHYSICS_CASE_PREFIX):
			physics_case = argument.trim_prefix(PHYSICS_CASE_PREFIX)
	if is_spawn_measurement:
		if not spawn_case.is_empty():
			active_colors = _apply_spawn_case(config_data, spawn_case)
		elif active_colors == 3:
			config_data.spawn_color_weights = PackedFloat32Array([1.0, 1.0, 1.0, 0.0])
		else:
			config_data.spawn_color_weights = PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
		print(
			"Spawn candidate case=%s count=%d ramp=%d max=%d active_colors=%d opposite_pairs=%s suite=%s" % [
				spawn_case,
				config_data.spawn_count_per_turn,
				config_data.spawn_count_ramp_turns,
				config_data.spawn_count_max,
				active_colors,
				str(config_data.opposite_pairs),
				measurement_suite,
			]
		)
	elif is_mass_measurement:
		print(
			"Mass candidate exponent=%.3f suite=%s" % [
				config_data.mass_exponent,
				measurement_suite,
			]
		)
	elif measurement_suite.begins_with("game_over_"):
		print(
			"Game-over suite=%s case=%s gravity=%.1f friction=%.3f bounce=%.3f" % [
				measurement_suite,
				physics_case,
				config_data.gravity_strength,
				config_data.orb_friction,
				config_data.orb_bounce,
			]
		)
	elif not measurement_suite.is_empty():
		print(
			"Growth candidate duration=%.3f ratio=%.3f suite=%s" % [
				config_data.grow_duration,
				config_data.grow_start_ratio,
				measurement_suite,
			]
		)
	return measurement_suite


func _apply_spawn_case(config_data: GameConfig, spawn_case: String) -> int:
	var active_colors: int = 4
	config_data.spawn_count_ramp_turns = 0
	config_data.spawn_count_max = 3
	match spawn_case:
		"A3":
			config_data.spawn_count_per_turn = 3
			active_colors = 3
		"B1":
			config_data.spawn_count_per_turn = 1
		"B2":
			config_data.spawn_count_per_turn = 2
		"B3":
			config_data.spawn_count_per_turn = 3
		"CA":
			config_data.spawn_count_per_turn = 1
			config_data.spawn_count_ramp_turns = 40
			active_colors = 3
		"CB":
			config_data.spawn_count_per_turn = 1
			config_data.spawn_count_ramp_turns = 40
		_:
			push_error("Unknown spawn measurement case: %s" % spawn_case)
	config_data.spawn_color_weights = (
		PackedFloat32Array([1.0, 1.0, 1.0, 0.0])
		if active_colors == 3
		else PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
	)
	var red_blue_only: Array[Vector2i] = [
		Vector2i(OrbTypes.OrbColor.RED, OrbTypes.OrbColor.BLUE),
	]
	config_data.opposite_pairs = red_blue_only
	return active_colors


func _run_directory(directory: String) -> void:
	var files: PackedStringArray = DirAccess.get_files_at(directory)
	files.sort()
	for file_name: String in files:
		if not file_name.begins_with(TEST_FILE_PREFIX) or not file_name.ends_with(TEST_FILE_SUFFIX):
			continue
		if file_name == "test_game_over_measurement.gd":
			continue
		await _run_test_file(directory.path_join(file_name))


func _run_test_file(path: String) -> void:
	var test_script: Script = load(path) as Script
	if test_script == null:
		_record_runner_failure(path, "could not load script")
		return
	if not test_script.can_instantiate():
		_record_runner_failure(path, "script has parse or compile errors")
		return

	var instance_value: Variant = test_script.new()
	if not (instance_value is TestCase):
		_record_runner_failure(path, "test script must extend TestCase")
		return

	var test_instance: TestCase = instance_value as TestCase
	test_instance.tree = self
	var method_names: Array[String] = []
	for method_info: Dictionary in test_instance.get_method_list():
		var method_name: String = str(method_info.get("name", ""))
		if method_name.begins_with(TEST_METHOD_PREFIX):
			method_names.append(method_name)
	method_names.sort()

	for method_name: String in method_names:
		var failures_before: int = test_instance.get_failure_count()
		await test_instance.call(method_name)
		var failures_after: int = test_instance.get_failure_count()
		if failures_after == failures_before:
			_passed += 1
			print("PASS %s::%s" % [path, method_name])
			continue

		_failed += 1
		print("FAIL %s::%s" % [path, method_name])
		for failure_index: int in range(failures_before, failures_after):
			print("  %s" % test_instance.failures[failure_index])


func _record_runner_failure(path: String, message: String) -> void:
	_failed += 1
	print("FAIL %s: %s" % [path, message])
