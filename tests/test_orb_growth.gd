extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const RADIUS_TOLERANCE: float = 0.001
const TEST_DURATION: float = 0.12
const TEST_START_RATIO: float = 0.6


func test_spawned_orb_grows_collision_and_visual_radius_to_final_size() -> void:
	var snapshot: Dictionary = _snapshot_growth_config()
	Config.data.grow_duration = TEST_DURATION
	Config.data.grow_start_ratio = TEST_START_RATIO
	var board: Board = await _create_board()
	var orb: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 2, Vector2.ZERO)
	var final_radius: float = Config.data.radius_for_level(2)
	var start_radius: float = final_radius * TEST_START_RATIO
	var circle: CircleShape2D = (
		orb.get_node("CollisionShape2D") as CollisionShape2D
	).shape as CircleShape2D
	var visual: OrbVisual = orb.get_node("Visual") as OrbVisual

	assert_near(orb.get_radius(), final_radius, RADIUS_TOLERANCE, "final radius API")
	assert_near(
		orb.get_current_radius(),
		start_radius,
		RADIUS_TOLERANCE,
		"initial current radius"
	)
	assert_near(circle.radius, start_radius, RADIUS_TOLERANCE, "initial collision radius")
	assert_near(visual.get_radius(), start_radius, RADIUS_TOLERANCE, "initial visual radius")
	assert_near(
		orb.mass,
		Config.data.mass_for_level(2),
		RADIUS_TOLERANCE,
		"mass starts at final value"
	)

	var elapsed_frames: int = 0
	var expected_frames: int = ceili(
		TEST_DURATION * float(Engine.physics_ticks_per_second)
	)
	while (
		orb.get_current_radius() < final_radius - RADIUS_TOLERANCE
		and elapsed_frames <= expected_frames + 1
	):
		await tree.physics_frame
		elapsed_frames += 1

	assert_true(
		absi(elapsed_frames - expected_frames) <= 1,
		"growth duration within one physics tick"
	)
	assert_near(
		orb.get_current_radius(),
		final_radius,
		RADIUS_TOLERANCE,
		"final current radius"
	)
	assert_near(circle.radius, final_radius, RADIUS_TOLERANCE, "final collision radius")
	assert_near(visual.get_radius(), final_radius, RADIUS_TOLERANCE, "final visual radius")

	await _cleanup_board(board)
	_restore_growth_config(snapshot)


func test_zero_duration_spawns_at_final_radius() -> void:
	var snapshot: Dictionary = _snapshot_growth_config()
	Config.data.grow_duration = 0.0
	Config.data.grow_start_ratio = 0.3
	var board: Board = await _create_board()
	var orb: Orb = board.spawn_orb(OrbTypes.OrbColor.BLUE, 1, Vector2.ZERO)
	assert_near(
		orb.get_current_radius(),
		orb.get_radius(),
		RADIUS_TOLERANCE,
		"zero duration disables growth"
	)

	await _cleanup_board(board)
	_restore_growth_config(snapshot)


func test_new_color_2d_visuals_match_display_table() -> void:
	var board: Board = await _create_board()
	var colors: Array[int] = [
		OrbTypes.OrbColor.PURPLE,
		OrbTypes.OrbColor.CYAN,
	]
	for index: int in range(colors.size()):
		var color: int = colors[index]
		var orb: Orb = board.spawn_orb(
			color,
			1,
			Vector2(float(index * 100), 0.0)
		)
		orb.exit_ghost_state()
		var visual: OrbVisual = orb.get_node("Visual") as OrbVisual
		assert_eq(
			visual._display_color,
			Config.data.color_display[color],
			"2D visual uses configured new color"
		)
	await _cleanup_board(board)


func _create_board() -> Board:
	var board: Board = BOARD_SCENE.instantiate() as Board
	tree.root.add_child(board)
	await tree.process_frame
	return board


func _cleanup_board(board: Board) -> void:
	board.queue_free()
	await tree.process_frame


func _snapshot_growth_config() -> Dictionary:
	return {
		"grow_duration": Config.data.grow_duration,
		"grow_start_ratio": Config.data.grow_start_ratio,
	}


func _restore_growth_config(snapshot: Dictionary) -> void:
	Config.data.grow_duration = float(snapshot["grow_duration"])
	Config.data.grow_start_ratio = float(snapshot["grow_start_ratio"])
