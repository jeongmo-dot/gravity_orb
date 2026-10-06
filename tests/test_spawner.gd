extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const SEQUENCE_COUNT: int = 50
const DISTRIBUTION_COUNT: int = 10000
const DISTRIBUTION_TOLERANCE: float = 0.02
const LEGACY_SEQUENCE_TOLERANCE: float = 1.0e-9


func test_turn_sequence_matches_pre_six_color_baseline_for_three_seeds() -> void:
	var snapshot: Dictionary = _snapshot_spawn_config()
	var expected_by_seed: Dictionary = {
		101: [
			[1, 2, 0.391725897789],
			[1, 1, 0.46784633398056],
			[1, 2, 0.41243773698807],
			[1, 1, 0.08886755257845],
			[1, 0, 0.40030378103256],
			[1, 1, 0.18263983726501],
			[1, 1, 0.32996472716331],
			[1, 1, 0.04768922179937],
		],
		777: [
			[1, 0, 0.80851691961288],
			[1, 3, 0.75154829025269],
			[1, 0, 0.9190845489502],
			[1, 1, 0.16851322352886],
			[1, 2, 0.45896261930466],
			[1, 2, 0.65874481201172],
			[1, 2, 0.17010578513145],
			[2, 0, 0.87970560789108],
		],
		4242: [
			[1, 3, 0.31177765130997],
			[1, 0, 0.31287559866905],
			[1, 2, 0.48825904726982],
			[1, 0, 0.06588395684958],
			[1, 1, 0.20683698356152],
			[1, 0, 0.91876804828644],
			[1, 3, 0.10133952647448],
			[1, 0, 0.609992146492],
		],
	}
	for seed_value: Variant in expected_by_seed:
		var seed: int = int(seed_value)
		var actual: Array[Dictionary] = _draw_sequence(
			seed,
			8,
			GameConfig.SpawnPositionMode.RANDOM
		)
		var expected: Array = expected_by_seed[seed] as Array
		for index: int in range(expected.size()):
			var item: Array = expected[index] as Array
			assert_eq(actual[index]["level"], item[0], "seed %d level %d" % [seed, index])
			assert_eq(actual[index]["color"], item[1], "seed %d color %d" % [seed, index])
			assert_near(
				float(actual[index]["t"]),
				float(item[2]),
				LEGACY_SEQUENCE_TOLERANCE,
				"seed %d position %d" % [seed, index]
			)
	_restore_spawn_config(snapshot)


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
	var total_color_weight: float = 0.0
	for weight: float in Config.data.spawn_color_weights:
		total_color_weight += weight
	for color: int in range(color_counts.size()):
		var color_ratio: float = float(color_counts[color]) / float(DISTRIBUTION_COUNT)
		assert_near(
			color_ratio,
			Config.data.spawn_color_weights[color] / total_color_weight,
			DISTRIBUTION_TOLERANCE,
			"color %d ratio" % color
		)
	assert_eq(color_counts[OrbTypes.OrbColor.PURPLE], 0, "TURN never spawns purple")
	assert_eq(color_counts[OrbTypes.OrbColor.CYAN], 0, "TURN never spawns cyan")
	print("TURN Spawner distribution: level1=%.4f colors=%s" % [level_one_ratio, str(color_counts)])
	spawner.free()
	_restore_spawn_config(snapshot)


func test_blitz_weighted_distribution_uses_all_six_colors() -> void:
	var snapshot: Dictionary = _snapshot_spawn_config()
	var spawner: Spawner = Spawner.new()
	spawner.set_blitz_mode(true)
	spawner.init_rng(3401)
	var color_counts: Array[int] = []
	color_counts.resize(Config.data.blitz_spawn_color_weights.size())
	color_counts.fill(0)
	for _index: int in range(DISTRIBUTION_COUNT):
		var candidate: Dictionary = spawner._draw_candidate()
		color_counts[int(candidate["color"])] += 1
	for color: int in range(color_counts.size()):
		assert_true(color_counts[color] > 0, "BLITZ color %d appears" % color)
		assert_near(
			float(color_counts[color]) / float(DISTRIBUTION_COUNT),
			1.0 / float(color_counts.size()),
			DISTRIBUTION_TOLERANCE,
			"BLITZ color %d ratio" % color
		)
	print("BLITZ Spawner distribution: colors=%s" % str(color_counts))
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


func test_blitz_candidate_order_is_independent_of_batch_grouping() -> void:
	var snapshot: Dictionary = _snapshot_spawn_config()
	var first: Array[Dictionary] = await _draw_blitz_grouped_sequence(
		3636,
		[1, 3, 2]
	)
	var second: Array[Dictionary] = await _draw_blitz_grouped_sequence(
		3636,
		[3, 1, 2]
	)
	assert_eq(first, second, "BLITZ candidate line ignores batch grouping")
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


func _draw_blitz_grouped_sequence(seed: int, group_sizes: Array[int]) -> Array[Dictionary]:
	var board: Board = BOARD_SCENE.instantiate() as Board
	tree.root.add_child(board)
	await tree.process_frame
	var spawner: Spawner = Spawner.new()
	spawner.set_blitz_mode(true)
	spawner.init_rng(seed)
	var sequence: Array[Dictionary] = []
	for group_size: int in group_sizes:
		spawner.sync_blitz_next_batch_size(group_size)
		var internal_batch: Array = spawner._preview_batches[0] as Array
		for candidate: Dictionary in internal_batch:
			sequence.append(candidate.duplicate())
		spawner.try_spawn(board, Vector2i.DOWN)
	board.queue_free()
	await tree.process_frame
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
		"blitz_spawn_color_weights": Config.data.blitz_spawn_color_weights.duplicate(),
		"spawn_position_mode": Config.data.spawn_position_mode,
		"spawn_count_per_turn": Config.data.spawn_count_per_turn,
		"preview_turns": Config.data.preview_turns,
		"spawn_count_ramp_turns": Config.data.spawn_count_ramp_turns,
		"spawn_count_max": Config.data.spawn_count_max,
	}


func _restore_spawn_config(snapshot: Dictionary) -> void:
	Config.data.spawn_level_weights = snapshot["spawn_level_weights"] as PackedFloat32Array
	Config.data.spawn_color_weights = snapshot["spawn_color_weights"] as PackedFloat32Array
	Config.data.blitz_spawn_color_weights = (
		snapshot["blitz_spawn_color_weights"] as PackedFloat32Array
	)
	Config.data.spawn_position_mode = int(snapshot["spawn_position_mode"]) as GameConfig.SpawnPositionMode
	Config.data.spawn_count_per_turn = int(snapshot["spawn_count_per_turn"])
	Config.data.preview_turns = int(snapshot["preview_turns"])
	Config.data.spawn_count_ramp_turns = int(snapshot["spawn_count_ramp_turns"])
	Config.data.spawn_count_max = int(snapshot["spawn_count_max"])
