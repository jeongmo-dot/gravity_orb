extends TestCase

const SEQUENCE_COUNT: int = 50
const DISTRIBUTION_COUNT: int = 10000
const DISTRIBUTION_TOLERANCE: float = 0.02


func test_same_seed_produces_identical_fifty_item_sequence() -> void:
	var snapshot: Dictionary = _snapshot_spawn_config()
	var first: Array[Dictionary] = _draw_sequence(
		1234,
		SEQUENCE_COUNT,
		GameConfig.SpawnPositionMode.RANDOM
	)
	var second: Array[Dictionary] = _draw_sequence(
		1234,
		SEQUENCE_COUNT,
		GameConfig.SpawnPositionMode.RANDOM
	)
	assert_eq(first, second, "same seed level, color, and position sequence")
	_restore_spawn_config(snapshot)


func test_different_seeds_produce_different_sequence() -> void:
	var snapshot: Dictionary = _snapshot_spawn_config()
	var first: Array[Dictionary] = _draw_sequence(
		1234,
		SEQUENCE_COUNT,
		GameConfig.SpawnPositionMode.RANDOM
	)
	var second: Array[Dictionary] = _draw_sequence(
		1235,
		SEQUENCE_COUNT,
		GameConfig.SpawnPositionMode.RANDOM
	)
	assert_true(first != second, "different seeds must diverge")
	_restore_spawn_config(snapshot)


func test_weighted_distribution_matches_config() -> void:
	var snapshot: Dictionary = _snapshot_spawn_config()
	var spawner: Spawner = Spawner.new()
	spawner.init_rng(42)
	var level_one_count: int = 0
	var color_counts: Array[int] = [0, 0, 0]
	for _index: int in range(DISTRIBUTION_COUNT):
		var candidate: Dictionary = spawner._draw_candidate()
		if int(candidate["level"]) == 1:
			level_one_count += 1
		color_counts[int(candidate["color"])] += 1

	var level_one_ratio: float = float(level_one_count) / float(DISTRIBUTION_COUNT)
	assert_near(level_one_ratio, 0.9, DISTRIBUTION_TOLERANCE, "level 1 ratio")
	for color: int in range(color_counts.size()):
		var color_ratio: float = float(color_counts[color]) / float(DISTRIBUTION_COUNT)
		assert_near(
			color_ratio,
			1.0 / 3.0,
			DISTRIBUTION_TOLERANCE,
			"color %d ratio" % color
		)
	print(
		"Spawner distribution: level1=%.4f colors=[%.4f, %.4f, %.4f]" % [
			level_one_ratio,
			float(color_counts[0]) / float(DISTRIBUTION_COUNT),
			float(color_counts[1]) / float(DISTRIBUTION_COUNT),
			float(color_counts[2]) / float(DISTRIBUTION_COUNT),
		]
	)
	spawner.free()
	_restore_spawn_config(snapshot)


func test_center_mode_consumes_position_and_preserves_item_sequence() -> void:
	var snapshot: Dictionary = _snapshot_spawn_config()
	var random_sequence: Array[Dictionary] = _draw_sequence(
		1234,
		SEQUENCE_COUNT,
		GameConfig.SpawnPositionMode.RANDOM
	)
	var center_sequence: Array[Dictionary] = _draw_sequence(
		1234,
		SEQUENCE_COUNT,
		GameConfig.SpawnPositionMode.CENTER
	)
	for index: int in range(SEQUENCE_COUNT):
		assert_eq(
			random_sequence[index]["level"],
			center_sequence[index]["level"],
			"level at index %d" % index
		)
		assert_eq(
			random_sequence[index]["color"],
			center_sequence[index]["color"],
			"color at index %d" % index
		)
	_restore_spawn_config(snapshot)


func test_zero_seed_randomizes_and_reports_actual_seed() -> void:
	var spawner: Spawner = Spawner.new()
	var actual_seed: int = spawner.init_rng(0)
	assert_true(actual_seed != 0, "randomized seed must be nonzero")
	assert_eq(spawner.seed_used, actual_seed, "reported seed")
	spawner.free()


func _draw_sequence(seed: int, count: int, mode: GameConfig.SpawnPositionMode) -> Array[Dictionary]:
	Config.data.spawn_position_mode = mode
	var spawner: Spawner = Spawner.new()
	spawner.init_rng(seed)
	var sequence: Array[Dictionary] = []
	for _index: int in range(count):
		sequence.append(spawner._draw_candidate())
	spawner.free()
	return sequence


func _snapshot_spawn_config() -> Dictionary:
	return {
		"spawn_level_weights": Config.data.spawn_level_weights.duplicate(),
		"spawn_color_weights": Config.data.spawn_color_weights.duplicate(),
		"spawn_position_mode": Config.data.spawn_position_mode,
	}


func _restore_spawn_config(snapshot: Dictionary) -> void:
	Config.data.spawn_level_weights = snapshot["spawn_level_weights"] as PackedFloat32Array
	Config.data.spawn_color_weights = snapshot["spawn_color_weights"] as PackedFloat32Array
	Config.data.spawn_position_mode = int(snapshot["spawn_position_mode"]) as GameConfig.SpawnPositionMode
