extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")
const SCORE_MANAGER_SCRIPT: Script = preload("res://scripts/core/ScoreManager.gd")
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.DOWN,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.LEFT,
]
const WAIT_TIMEOUT_SECONDS: float = 4.0
const PHYSICS_CYCLE_SECONDS_PER_DIRECTION: float = 2.0
const PHYSICS_CYCLE_LAPS: int = 4
const DIVERGENCE_SPEED: float = 5000.0
const DIVERGENCE_MARGIN: float = 100.0


func test_main_3d_uses_shared_core_and_full_ui() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	assert_true(main.get_node("TurnManager") is TurnManager, "shared TurnManager")
	assert_true(main.get_node("CollisionResolver") is CollisionResolver, "shared resolver")
	assert_true(main.get_node("Spawner") is Spawner, "shared spawner")
	assert_true(main.get_node("UI") is DebugHud, "shared debug HUD")
	assert_true(main.get_node("UI/Hud") is Hud, "shared HUD")
	assert_true(
		main.get_node("UI/Hud/GameOverPanel") is GameOverPanel,
		"shared game-over panel"
	)
	main.free()


func test_merge_result_ghost_can_be_enabled_and_disabled() -> void:
	var enabled_fixture: Dictionary = await _create_fixture(false, true)
	var enabled_board: Board3D = enabled_fixture["board"] as Board3D
	var enabled_resolver: CollisionResolver = enabled_fixture["resolver"] as CollisionResolver
	var first: Orb3D = enabled_board.spawn_orb(
		OrbTypes.OrbColor.GREEN, 1, Vector2(-25.0, 0.0)
	)
	var second: Orb3D = enabled_board.spawn_orb(
		OrbTypes.OrbColor.GREEN, 1, Vector2(25.0, 0.0)
	)
	enabled_resolver.report_contact(first, second)
	assert_eq(enabled_resolver.flush(), 1, "enabled merge reaction")
	var enabled_result: Orb3D = enabled_board.get_orbs()[0]
	assert_true(enabled_result.is_ghost, "merge result enters ghost state")
	assert_eq(enabled_result.get_physics_body().collision_layer, 4, "ghost passes through orbs")
	await tree.physics_frame
	await tree.physics_frame
	assert_true(not enabled_result.is_ghost, "clear merge result leaves ghost state")
	await _cleanup_fixture(enabled_fixture)

	var disabled_fixture: Dictionary = await _create_fixture(false, false)
	var disabled_board: Board3D = disabled_fixture["board"] as Board3D
	var disabled_resolver: CollisionResolver = disabled_fixture["resolver"] as CollisionResolver
	first = disabled_board.spawn_orb(OrbTypes.OrbColor.GREEN, 1, Vector2(-25.0, 0.0))
	second = disabled_board.spawn_orb(OrbTypes.OrbColor.GREEN, 1, Vector2(25.0, 0.0))
	disabled_resolver.report_contact(first, second)
	assert_eq(disabled_resolver.flush(), 1, "disabled merge reaction")
	var disabled_result: Orb3D = disabled_board.get_orbs()[0]
	assert_true(not disabled_result.is_ghost, "ghost toggle leaves result solid")
	await _cleanup_fixture(disabled_fixture)


func test_rule_c_remainder_uses_shared_score_and_ghost_path() -> void:
	var previous_rule: GameConfig.AnnihilationRule = Config.data.annihilation_rule
	Config.data.annihilation_rule = GameConfig.AnnihilationRule.C_REMAINDER
	var fixture: Dictionary = await _create_fixture(false, true)
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var score: ScoreManager = fixture["score"] as ScoreManager
	var larger: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 3, Vector2(-25.0, 0.0))
	var smaller: Orb3D = board.spawn_orb(OrbTypes.OrbColor.BLUE, 1, Vector2(25.0, 0.0))
	resolver.report_contact(larger, smaller)
	assert_eq(resolver.flush(), 1, "rule C reaction")
	var result: Orb3D = board.get_orbs()[0]
	assert_eq(result.color, OrbTypes.OrbColor.RED, "larger color survives")
	assert_eq(result.level, 2, "level difference survives")
	assert_true(result.is_ghost, "rule C survivor enters ghost state")
	assert_true(score.score > 0, "shared ScoreManager receives reaction")
	Config.data.annihilation_rule = previous_rule
	await _cleanup_fixture(fixture)


func test_reaction_ghost_times_out_without_position_correction() -> void:
	var fixture: Dictionary = await _create_fixture(false, true)
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var blocker: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2.ZERO)
	var first: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.GREEN, 1, Vector2(-25.0, 0.0)
	)
	var second: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.GREEN, 1, Vector2(25.0, 0.0)
	)
	resolver.report_contact(first, second)
	assert_eq(resolver.flush(), 1, "overlapped merge reaction")
	var result: Orb3D = null
	for orb: Orb3D in board.get_orbs():
		if orb != blocker:
			result = orb
			break
	assert_true(result != null and result.is_ghost, "overlapped merge result is ghost")
	assert_true(
		board.maximum_normal_overlap(result) > Config.data.ghost_exit_overlap,
		"blocker keeps result above exit overlap"
	)
	var timeout_frames: int = ceili(
		(Config.data.ghost_max_time + 0.05) * float(Engine.physics_ticks_per_second)
	)
	for _frame: int in range(timeout_frames):
		await tree.physics_frame
	assert_true(not result.is_ghost, "reaction result exits ghost at timeout")
	assert_eq(board.ghost_timeout_count, 1, "reaction ghost timeout is measured")
	assert_true(result.position.is_finite(), "timeout does not apply divergent correction")
	await _cleanup_fixture(fixture)


func test_shared_turn_path_completes_twenty_3d_turns() -> void:
	var fixture: Dictionary = await _create_fixture(true, true)
	var board: Board3D = fixture["board"] as Board3D
	var manager: TurnManager = fixture["manager"] as TurnManager
	assert_true(
		await _wait_for_state(manager, TurnManager.State.WAITING_INPUT),
		"initial 3D settle"
	)
	for turn_index: int in range(20):
		manager.on_swipe(DIRECTIONS[turn_index % DIRECTIONS.size()])
		assert_true(
			await _wait_for_ready_or_game_over(manager),
			"turn %d settles" % (turn_index + 1)
		)
		if manager.state == TurnManager.State.GAME_OVER:
			break
	assert_eq(manager.turn_index, 20, "twenty turns use the shared manager")
	assert_eq(manager.state, TurnManager.State.WAITING_INPUT, "twenty turns remain playable")
	for orb: Orb3D in board.get_orbs():
		var center_extent: float = maxf(absf(orb.position.x), absf(orb.position.y))
		assert_true(center_extent <= board.half_size() + 25.0, "3D orb remains near board")
		assert_true(orb.position.is_finite(), "3D position remains finite")
	await _cleanup_fixture(fixture)


func test_seed_101_completes_120_3d_turns_with_shared_score_flow() -> void:
	var fixture: Dictionary = await _create_fixture(true, true)
	var board: Board3D = fixture["board"] as Board3D
	var manager: TurnManager = fixture["manager"] as TurnManager
	var score: ScoreManager = fixture["score"] as ScoreManager
	assert_true(
		await _wait_for_state(manager, TurnManager.State.WAITING_INPUT),
		"initial 3D settle"
	)
	for turn_offset: int in range(120):
		manager.on_swipe(DIRECTIONS[turn_offset % DIRECTIONS.size()])
		assert_true(
			await _wait_for_ready_or_game_over(manager),
			"turn %d settles" % (turn_offset + 1)
		)
		if manager.state == TurnManager.State.GAME_OVER:
			break
	assert_eq(manager.turn_index, 120, "seed 101 reaches 120 turns")
	assert_eq(manager.state, TurnManager.State.WAITING_INPUT, "120 turns remain playable")
	assert_true(score.score > 0, "shared score path records reactions by turn 120")
	for orb: Orb3D in board.get_orbs():
		assert_true(orb.position.is_finite(), "120-turn 3D position remains finite")
		assert_true(
			maxf(absf(orb.position.x), absf(orb.position.y))
			<= board.half_size() + DIVERGENCE_MARGIN,
			"120-turn orb remains near board"
		)
	await _cleanup_fixture(fixture)


func test_twenty_two_seed_3d_gravity_cycles_have_no_departures_or_divergence() -> void:
	var seeds: Array[int] = []
	for seed: int in range(1000, 1020):
		seeds.append(seed)
	seeds.append(1047)
	seeds.append(2000)
	var total_departures: int = 0
	var total_divergences: int = 0
	var maximum_wall_penetration: float = 0.0
	var maximum_pair_overlap: float = 0.0
	for seed: int in seeds:
		var result: Dictionary = await _run_seeded_gravity_cycle(seed, seed == 2000)
		total_departures += int(result["departures"])
		total_divergences += int(result["divergences"])
		maximum_wall_penetration = maxf(
			maximum_wall_penetration,
			float(result["max_wall_penetration"])
		)
		maximum_pair_overlap = maxf(
			maximum_pair_overlap,
			float(result["max_pair_overlap"])
		)
	print(
		"Jolt 3D 22-seed cycle: departures=%d divergences=%d max_wall=%.4f max_pair=%.4f" % [
			total_departures,
			total_divergences,
			maximum_wall_penetration,
			maximum_pair_overlap,
		]
	)
	assert_eq(total_departures, 0, "22-seed 3D center departures")
	assert_eq(total_divergences, 0, "22-seed 3D divergent frames")


func test_blocked_3d_spawn_reaches_game_over_and_warning_edge_is_red() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.initial_orb_count = 0
	Config.data.spawn_position_mode = GameConfig.SpawnPositionMode.CENTER
	Config.data.spawn_count_per_turn = 1
	Config.data.spawn_count_ramp_turns = 0
	Config.data.stable_linear_speed = 1.0e9
	Config.data.stable_angular_speed = 1.0e9
	Config.data.stable_duration = 0.10
	Config.data.max_settle_time = 0.25
	var fixture: Dictionary = await _create_fixture(false, true)
	var board: Board3D = fixture["board"] as Board3D
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	_fill_spawn_wall(board, Vector2i.DOWN)
	_set_next_level_one_batch(spawner)
	manager.start_game()
	assert_true(
		await _wait_for_state(manager, TurnManager.State.WAITING_INPUT),
		"blocked fixture initial settle"
	)
	board.set_warning_directions([Vector2i.DOWN])
	var top_wall: MeshInstance3D = board.get_node("VisualTilt/VisualTop") as MeshInstance3D
	var top_material: StandardMaterial3D = top_wall.material_override as StandardMaterial3D
	assert_true(top_material.albedo_color.r > top_material.albedo_color.b, "top warning edge is red")
	manager.on_swipe(Vector2i.DOWN)
	assert_true(
		await _wait_for_state(manager, TurnManager.State.GAME_OVER),
		"blocked 3D spawn reaches game over"
	)
	assert_eq(board.entrance_waiting_orbs().size(), 1, "blocked orb waits at entrance")
	assert_true(InputRouter.is_locked(), "game over keeps input locked")
	_restore_config(snapshot)
	await _cleanup_fixture(fixture)


func _create_fixture(start_game: bool, reaction_ghost: bool) -> Dictionary:
	InputRouter.set_locked(false)
	var root: Node3D = Node3D.new()
	root.name = "JoltIntegrationFixture"
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.name = "Board"
	board.unique_name_in_owner = true
	board.reaction_ghost_enabled = reaction_ghost
	root.add_child(board)
	board.owner = root
	var resolver: CollisionResolver = RESOLVER_SCRIPT.new() as CollisionResolver
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	root.add_child(resolver)
	resolver.owner = root
	var spawner: Spawner = SPAWNER_SCRIPT.new() as Spawner
	spawner.name = "Spawner"
	spawner.unique_name_in_owner = true
	root.add_child(spawner)
	spawner.owner = root
	var manager: TurnManager = TURN_MANAGER_SCRIPT.new() as TurnManager
	manager.name = "TurnManager"
	root.add_child(manager)
	manager.owner = root
	var score: ScoreManager = SCORE_MANAGER_SCRIPT.new() as ScoreManager
	score.name = "ScoreManager"
	score.save_path = ""
	root.add_child(score)
	score.owner = root
	tree.root.add_child(root)
	await tree.process_frame
	resolver.reaction_applied.connect(score.on_reaction)
	spawner.orb_spawned.connect(score.on_orb_spawned)
	spawner.init_rng(101)
	if start_game:
		spawner.spawn_initial(board, Vector2i.DOWN)
		manager.start_game()
	return {
		"root": root,
		"board": board,
		"resolver": resolver,
		"spawner": spawner,
		"manager": manager,
		"score": score,
	}


func _fill_spawn_wall(board: Board3D, gravity: Vector2i) -> void:
	var radius: float = Config.data.radius_for_level(1)
	var line: Dictionary = board.spawn_line(gravity, radius)
	var origin: Vector2 = line["origin"] as Vector2
	var axis: Vector2 = line["axis"] as Vector2
	var extent: float = float(line["extent"])
	var offset: float = -extent
	while offset <= extent:
		var orb: Orb3D = board.spawn_orb(
			OrbTypes.OrbColor.GREEN,
			1,
			origin + axis * offset
		)
		orb.get_physics_body().freeze = true
		offset += 45.0
	if offset - 45.0 < extent:
		var edge_orb: Orb3D = board.spawn_orb(
			OrbTypes.OrbColor.GREEN,
			1,
			origin + axis * extent
		)
		edge_orb.get_physics_body().freeze = true


func _run_seeded_gravity_cycle(seed: int, worst_case: bool) -> Dictionary:
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.reaction_ghost_enabled = false
	tree.root.add_child(board)
	await tree.process_frame
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var levels: Array[int] = []
	if worst_case:
		levels.append_array([4, 4, 4, 4, 1, 1, 1, 1])
	else:
		levels.append_array([1, 2, 3, 4, 1])
	_spawn_seeded_grid(board, rng, levels)
	var departures: int = 0
	var divergences: int = 0
	var max_wall_penetration: float = 0.0
	var max_pair_overlap: float = 0.0
	var frames_per_direction: int = ceili(
		float(Engine.physics_ticks_per_second) * PHYSICS_CYCLE_SECONDS_PER_DIRECTION
	)
	for _lap: int in range(PHYSICS_CYCLE_LAPS):
		for direction: Vector2i in DIRECTIONS:
			board.set_gravity(direction)
			for _frame: int in range(frames_per_direction):
				await tree.physics_frame
				var orbs: Array[Orb3D] = board.get_orbs()
				for index: int in range(orbs.size()):
					var orb: Orb3D = orbs[index]
					var center_extent: float = maxf(
						absf(orb.position.x),
						absf(orb.position.y)
					)
					var penetration: float = maxf(
						center_extent + orb.get_current_radius() - board.half_size(),
						0.0
					)
					max_wall_penetration = maxf(max_wall_penetration, penetration)
					if center_extent > board.half_size():
						departures += 1
					if (
						orb.linear_velocity.length() > DIVERGENCE_SPEED
						or center_extent > board.half_size() + DIVERGENCE_MARGIN
					):
						divergences += 1
					for other_index: int in range(index + 1, orbs.size()):
						var other: Orb3D = orbs[other_index]
						var overlap: float = maxf(
							orb.get_current_radius()
							+ other.get_current_radius()
							- orb.position.distance_to(other.position),
							0.0
						)
						max_pair_overlap = maxf(max_pair_overlap, overlap)
	board.queue_free()
	await tree.process_frame
	return {
		"departures": departures,
		"divergences": divergences,
		"max_wall_penetration": max_wall_penetration,
		"max_pair_overlap": max_pair_overlap,
	}


func _spawn_seeded_grid(
	board: Board3D,
	rng: RandomNumberGenerator,
	levels: Array[int]
) -> void:
	var count: int = levels.size()
	var columns: int = ceili(sqrt(float(count)))
	var rows: int = ceili(float(count) / float(columns))
	var cell_width: float = Config.data.board_size / float(columns)
	var cell_height: float = Config.data.board_size / float(rows)
	var half: float = board.half_size()
	for index: int in range(count):
		var level: int = levels[index]
		var radius: float = Config.data.radius_for_level(level)
		var column: int = index % columns
		var row: int = int(index / columns)
		var cell_center: Vector2 = Vector2(
			-half + (float(column) + 0.5) * cell_width,
			-half + (float(row) + 0.5) * cell_height
		)
		var max_offset: Vector2 = Vector2(
			maxf(cell_width * 0.5 - radius, 0.0),
			maxf(cell_height * 0.5 - radius, 0.0)
		)
		var offset: Vector2 = Vector2(
			rng.randf_range(-max_offset.x, max_offset.x),
			rng.randf_range(-max_offset.y, max_offset.y)
		)
		board.spawn_orb(
			index % Config.data.color_display.size(),
			level,
			cell_center + offset
		)


func _set_next_level_one_batch(spawner: Spawner) -> void:
	spawner._next_batch = [
		{
			"color": OrbTypes.OrbColor.YELLOW,
			"level": 1,
			"t": 0.5,
		}
	]


func _wait_for_ready_or_game_over(manager: TurnManager) -> bool:
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		if (
			manager.state == TurnManager.State.WAITING_INPUT
			or manager.state == TurnManager.State.GAME_OVER
		):
			return true
		await tree.physics_frame
	return false


func _wait_for_state(manager: TurnManager, target: TurnManager.State) -> bool:
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		if manager.state == target:
			return true
		await tree.physics_frame
	return manager.state == target


func _snapshot_config() -> Dictionary:
	return {
		"initial_orb_count": Config.data.initial_orb_count,
		"spawn_position_mode": Config.data.spawn_position_mode,
		"spawn_count_per_turn": Config.data.spawn_count_per_turn,
		"spawn_count_ramp_turns": Config.data.spawn_count_ramp_turns,
		"stable_linear_speed": Config.data.stable_linear_speed,
		"stable_angular_speed": Config.data.stable_angular_speed,
		"stable_duration": Config.data.stable_duration,
		"max_settle_time": Config.data.max_settle_time,
	}


func _restore_config(snapshot: Dictionary) -> void:
	Config.data.initial_orb_count = int(snapshot["initial_orb_count"])
	Config.data.spawn_position_mode = int(snapshot["spawn_position_mode"]) as GameConfig.SpawnPositionMode
	Config.data.spawn_count_per_turn = int(snapshot["spawn_count_per_turn"])
	Config.data.spawn_count_ramp_turns = int(snapshot["spawn_count_ramp_turns"])
	Config.data.stable_linear_speed = float(snapshot["stable_linear_speed"])
	Config.data.stable_angular_speed = float(snapshot["stable_angular_speed"])
	Config.data.stable_duration = float(snapshot["stable_duration"])
	Config.data.max_settle_time = float(snapshot["max_settle_time"])


func _cleanup_fixture(fixture: Dictionary) -> void:
	InputRouter.set_locked(false)
	var root: Node = fixture["root"] as Node
	if is_instance_valid(root):
		root.queue_free()
	await tree.process_frame
