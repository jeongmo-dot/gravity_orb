extends TestCase

const BOARD_2D_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const BOARD_3D_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const TOLERANCE: float = 1.0e-3


func test_2d_board_shockwave_uses_impulse_falloff_and_exclusions() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_test_shock()
	var board: Board = BOARD_2D_SCENE.instantiate() as Board
	tree.root.add_child(board)
	await tree.process_frame
	board.set_gravity(Vector2i.ZERO)
	var excluded: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 2, Vector2.ZERO)
	var target: Orb = board.spawn_orb(OrbTypes.OrbColor.GREEN, 1, Vector2(50.0, 0.0))
	var ghost: Orb = board.spawn_orb(OrbTypes.OrbColor.YELLOW, 1, Vector2(-50.0, 0.0))
	excluded.exit_ghost_state()
	target.exit_ghost_state()

	var targets: Array[Dictionary] = board.apply_shockwave(
		Vector2.ZERO,
		2,
		excluded,
		false
	)
	assert_eq(targets.size(), 1, "2D only normal non-result target")
	if targets.size() == 1:
		assert_eq(targets[0]["orb"], target, "2D target reference")
		assert_near((targets[0]["impulse"] as Vector2).x, 195.0, TOLERANCE, "2D impulse")
		assert_near((targets[0]["impulse"] as Vector2).y, 0.0, TOLERANCE, "2D impulse axis")
	assert_true(ghost.is_ghost, "2D ghost remains excluded")
	board.queue_free()
	await tree.process_frame
	_restore_config(snapshot)


func test_3d_board_shockwave_uses_same_plane_units() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_test_shock()
	var board: Board3D = BOARD_3D_SCENE.instantiate() as Board3D
	tree.root.add_child(board)
	await tree.process_frame
	board.set_gravity(Vector2i.ZERO)
	var excluded: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 2, Vector2(300.0, 0.0))
	var target: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		1,
		Vector2(50.0, 0.0)
	)

	var targets: Array[Dictionary] = board.apply_shockwave(
		Vector2.ZERO,
		2,
		excluded,
		false
	)
	assert_eq(targets.size(), 1, "3D only non-result target")
	if targets.size() == 1:
		assert_eq(targets[0]["orb"], target, "3D target reference")
		assert_near((targets[0]["impulse"] as Vector2).x, 195.0, TOLERANCE, "3D plane impulse")
	board.queue_free()
	await tree.process_frame
	_restore_config(snapshot)


func test_max_clear_applies_level_and_jackpot_multipliers() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_test_shock()
	var board: Board3D = BOARD_3D_SCENE.instantiate() as Board3D
	tree.root.add_child(board)
	await tree.process_frame
	board.set_gravity(Vector2i.ZERO)
	var target: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		1,
		Vector2(237.5, 0.0)
	)
	var targets: Array[Dictionary] = board.apply_shockwave(
		Vector2.ZERO,
		7,
		null,
		true
	)
	assert_eq(targets.size(), 1, "jackpot target")
	if targets.size() == 1:
		assert_eq(targets[0]["orb"], target, "jackpot target reference")
		assert_near(
			(targets[0]["impulse"] as Vector2).x,
			1260.0,
			TOLERANCE,
			"jackpot impulse"
		)
	board.queue_free()
	await tree.process_frame
	_restore_config(snapshot)


func _configure_test_shock() -> void:
	Config.data.shock_impulse = 300.0
	Config.data.shock_radius_factor = 2.5
	Config.data.shock_level_scale = 0.3
	Config.data.shock_jackpot_scale = 3.0


func _snapshot_config() -> Dictionary:
	return {
		"shock_impulse": Config.data.shock_impulse,
		"shock_radius_factor": Config.data.shock_radius_factor,
		"shock_level_scale": Config.data.shock_level_scale,
		"shock_jackpot_scale": Config.data.shock_jackpot_scale,
	}


func _restore_config(snapshot: Dictionary) -> void:
	Config.data.shock_impulse = float(snapshot["shock_impulse"])
	Config.data.shock_radius_factor = float(snapshot["shock_radius_factor"])
	Config.data.shock_level_scale = float(snapshot["shock_level_scale"])
	Config.data.shock_jackpot_scale = float(snapshot["shock_jackpot_scale"])
