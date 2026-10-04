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
	var color_counts: Array[int] = []
	color_counts.resize(Config.data.spawn_color_weights.size())
	color_counts.fill(0)
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
			1.0 / float(color_counts.size()),
			DISTRIBUTION_TOLERANCE,
			"color %d ratio" % color
		)
	print(
		"Spawner distribution: level1=%.4f colors=[%.4f, %.4f, %.4f, %.4f]" % [
			level_one_ratio,
			float(color_counts[0]) / float(DISTRIBUTION_COUNT),
			float(color_counts[1]) / float(DISTRIBUTION_COUNT),
			float(color_counts[2]) / float(DISTRIBUTION_COUNT),
			float(color_counts[3]) / float(DISTRIBUTION_COUNT),
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


func test_count_two_batch_sequence_matches_continuous_count_one_sequence() -> void:
	var snapshot: Dictionary = _snapshot_spawn_config()
	var count_one: Array[Dictionary] = _draw_batched_sequence(2468, 1, 6)
	var count_two: Array[Dictionary] = _draw_batched_sequence(2468, 2, 3)
	assert_eq(count_two, count_one, "count 2 preserves level, color, t RNG order")
	_restore_spawn_config(snapshot)


func test_ramp_draws_next_turn_batch_sizes_at_boundaries() -> void:
	var snapshot: Dictionary = _snapshot_spawn_config()
	Config.data.spawn_count_per_turn = 1
	Config.data.spawn_count_ramp_turns = 40
	Config.data.spawn_count_max = 3
	var spawner: Spawner = Spawner.new()
	spawner.init_rng(8642)
	var expected: Dictionary = {1: 1, 40: 1, 41: 2, 81: 3, 121: 3}
	for turn_value: Variant in expected:
		var turn_index: int = int(turn_value)
		assert_eq(
			spawner._draw_batch(turn_index).size(),
			int(expected[turn_index]),
			"batch size at turn %d" % turn_index
		)
	spawner.free()
	_restore_spawn_config(snapshot)


func test_preview_turns_one_keeps_single_next_batch() -> void:
	var snapshot: Dictionary = _snapshot_spawn_config()
	Config.data.preview_turns = 1
	Config.data.spawn_count_per_turn = 1
	var spawner: Spawner = Spawner.new()
	spawner.init_rng(9753)
	spawner.sync_next_batch_size(1)
	var preview: Array = spawner.peek_preview()
	assert_eq(preview.size(), 1, "single preview batch")
	assert_eq(preview[0], spawner.peek_next(), "single preview matches next batch")
	spawner.free()
	_restore_spawn_config(snapshot)


func test_ramp_preview_batches_use_each_future_turn_number() -> void:
	var snapshot: Dictionary = _snapshot_spawn_config()
	Config.data.preview_turns = 2
	Config.data.spawn_count_per_turn = 1
	Config.data.spawn_count_ramp_turns = 40
	Config.data.spawn_count_max = 3
	var spawner: Spawner = Spawner.new()
	spawner.init_rng(8642)
	spawner.sync_next_batch_size(40)
	var preview: Array = spawner.peek_preview()
	assert_eq(preview.size(), 2, "two preview turns")
	assert_eq((preview[0] as Array).size(), 1, "turn 40 preview size")
	assert_eq((preview[1] as Array).size(), 2, "turn 41 preview size")
	spawner.free()
	_restore_spawn_config(snapshot)


func test_sync_next_batch_size_updates_all_preview_batches() -> void:
	var snapshot: Dictionary = _snapshot_spawn_config()
	Config.data.preview_turns = 2
	Config.data.spawn_count_per_turn = 1
	Config.data.spawn_count_ramp_turns = 0
	var spawner: Spawner = Spawner.new()
	spawner.init_rng(6420)
	spawner.sync_next_batch_size(1)
	var before: Array = spawner.peek_preview()
	Config.data.spawn_count_per_turn = 3
	spawner.sync_next_batch_size(1)
	var after: Array = spawner.peek_preview()
	for index: int in range(after.size()):
		assert_eq((after[index] as Array).size(), 3, "expanded batch %d" % index)
		assert_eq(
			(after[index] as Array)[0],
			(before[index] as Array)[0],
			"existing candidate preserved in batch %d" % index
		)
	spawner.free()
	_restore_spawn_config(snapshot)


func _draw_batched_sequence(seed: int, batch_size: int, batch_count: int) -> Array[Dictionary]:
	Config.data.spawn_count_per_turn = batch_size
	Config.data.spawn_count_ramp_turns = 0
	var spawner: Spawner = Spawner.new()
	spawner.init_rng(seed)
	var sequence: Array[Dictionary] = []
	for _batch_index: int in range(batch_count):
		sequence.append_array(spawner._draw_batch())
	spawner.free()
	return sequence


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
		"spawn_count_per_turn": Config.data.spawn_count_per_turn,
		"preview_turns": Config.data.preview_turns,
		"spawn_count_ramp_turns": Config.data.spawn_count_ramp_turns,
		"spawn_count_max": Config.data.spawn_count_max,
	}


func _restore_spawn_config(snapshot: Dictionary) -> void:
	Config.data.spawn_level_weights = snapshot["spawn_level_weights"] as PackedFloat32Array
	Config.data.spawn_color_weights = snapshot["spawn_color_weights"] as PackedFloat32Array
	Config.data.spawn_position_mode = int(snapshot["spawn_position_mode"]) as GameConfig.SpawnPositionMode
	Config.data.spawn_count_per_turn = int(snapshot["spawn_count_per_turn"])
	Config.data.preview_turns = int(snapshot["preview_turns"])
	Config.data.spawn_count_ramp_turns = int(snapshot["spawn_count_ramp_turns"])
	Config.data.spawn_count_max = int(snapshot["spawn_count_max"])
