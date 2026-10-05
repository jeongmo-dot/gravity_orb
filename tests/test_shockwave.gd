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
		Vector2(
			Config.data.radius_for_level(7) * Config.data.shock_radius_factor * 0.5,
			0.0
		)
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


func test_color_modes_use_expected_screen_directions_in_2d() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_color_effects()
	var board: Board = BOARD_2D_SCENE.instantiate() as Board
	tree.root.add_child(board)
	await tree.process_frame
	board.set_gravity(Vector2i.DOWN)
	var excluded: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 2, Vector2.ZERO)
	var target: Orb = board.spawn_orb(OrbTypes.OrbColor.GREEN, 1, Vector2(50.0, 0.0))
	excluded.exit_ghost_state()
	target.exit_ghost_state()

	var push: Array[Dictionary] = board.apply_shockwave(
		Vector2.ZERO,
		2,
		excluded,
		false,
		OrbTypes.OrbColor.RED
	)
	var pull: Array[Dictionary] = board.apply_shockwave(
		Vector2.ZERO,
		2,
		excluded,
		false,
		OrbTypes.OrbColor.BLUE
	)
	var lift_down: Array[Dictionary] = board.apply_shockwave(
		Vector2.ZERO,
		2,
		excluded,
		false,
		OrbTypes.OrbColor.YELLOW
	)
	board.set_gravity(Vector2i.LEFT)
	var lift_left: Array[Dictionary] = board.apply_shockwave(
		Vector2.ZERO,
		2,
		excluded,
		false,
		OrbTypes.OrbColor.YELLOW
	)

	assert_true((push[0]["impulse"] as Vector2).x > 0.0, "PUSH points screen-right")
	assert_true((pull[0]["impulse"] as Vector2).x < 0.0, "PULL points screen-left")
	assert_true((lift_down[0]["impulse"] as Vector2).y < 0.0, "DOWN LIFT points screen-up")
	assert_true((lift_left[0]["impulse"] as Vector2).x > 0.0, "LEFT LIFT points screen-right")
	board.queue_free()
	await tree.process_frame
	_restore_config(snapshot)


func test_color_modes_keep_screen_directions_in_3d_plane() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_color_effects()
	var board: Board3D = BOARD_3D_SCENE.instantiate() as Board3D
	tree.root.add_child(board)
	await tree.process_frame
	board.set_gravity(Vector2i.DOWN)
	var excluded: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 2, Vector2.ZERO)
	var target: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		1,
		Vector2(50.0, 0.0)
	)
	var pull: Array[Dictionary] = board.apply_shockwave(
		Vector2.ZERO,
		2,
		excluded,
		false,
		OrbTypes.OrbColor.BLUE
	)
	var lift: Array[Dictionary] = board.apply_shockwave(
		Vector2.ZERO,
		2,
		excluded,
		false,
		OrbTypes.OrbColor.YELLOW
	)
	assert_eq(pull[0]["orb"], target, "3D PULL target")
	assert_true((pull[0]["impulse"] as Vector2).x < 0.0, "3D PULL uses screen-left")
	assert_true((lift[0]["impulse"] as Vector2).y < 0.0, "3D LIFT uses screen-up")
	board.queue_free()
	await tree.process_frame
	_restore_config(snapshot)


func test_shake_is_global_mass_independent_capped_and_seed_deterministic() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_color_effects()
	Config.data.green_shake_speed = 150.0
	Config.data.green_shake_max_speed = 600.0
	var board: Board3D = BOARD_3D_SCENE.instantiate() as Board3D
	tree.root.add_child(board)
	await tree.process_frame
	board.set_gravity(Vector2i.ZERO)
	var level_one: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(430.0, 0.0)
	)
	var level_seven: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		7,
		Vector2(-250.0, 0.0)
	)
	var first_spawner: Spawner = Spawner.new()
	var second_spawner: Spawner = Spawner.new()
	tree.root.add_child(first_spawner)
	tree.root.add_child(second_spawner)
	first_spawner.init_rng(25101)
	second_spawner.init_rng(25101)
	var targets: Array[Dictionary] = board.apply_shockwave(
		Vector2.ZERO,
		7,
		null,
		false,
		OrbTypes.OrbColor.GREEN,
		Callable(first_spawner, "next_shake_direction")
	)
	assert_eq(targets.size(), 2, "SHAKE reaches all normal orbs beyond radial range")
	if targets.size() == 2:
		var first_delta: Vector2 = targets[0]["velocity_change"] as Vector2
		var second_delta: Vector2 = targets[1]["velocity_change"] as Vector2
		assert_near(first_delta.length(), 420.0, TOLERANCE, "L7 SHAKE speed")
		assert_near(second_delta.length(), 420.0, TOLERANCE, "SHAKE ignores target mass")
		assert_true(
			not is_equal_approx(
				level_one.get_physics_body().mass,
				level_seven.get_physics_body().mass
			),
			"SHAKE test uses different masses"
		)
		assert_eq(
			first_delta,
			second_spawner.next_shake_direction() * 420.0,
			"same seed first SHAKE direction"
		)
		assert_eq(
			second_delta,
			second_spawner.next_shake_direction() * 420.0,
			"same seed second SHAKE direction"
		)
	first_spawner.queue_free()
	second_spawner.queue_free()
	board.queue_free()
	await tree.process_frame
	_restore_config(snapshot)


func test_shake_rng_does_not_advance_spawn_sequence() -> void:
	var baseline: Spawner = Spawner.new()
	var shaken: Spawner = Spawner.new()
	tree.root.add_child(baseline)
	tree.root.add_child(shaken)
	baseline.init_rng(25102)
	shaken.init_rng(25102)
	for _index: int in range(8):
		shaken.next_shake_direction()
	var baseline_candidate: Dictionary = baseline.call("_draw_candidate") as Dictionary
	var shaken_candidate: Dictionary = shaken.call("_draw_candidate") as Dictionary
	assert_eq(shaken_candidate, baseline_candidate, "effect RNG leaves spawn RNG untouched")
	baseline.queue_free()
	shaken.queue_free()
	await tree.process_frame


func test_radial_color_modes_exclude_non_targets() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_color_effects()
	for mode_color: int in [
		OrbTypes.OrbColor.RED,
		OrbTypes.OrbColor.BLUE,
		OrbTypes.OrbColor.YELLOW,
	]:
		var board: Board = BOARD_2D_SCENE.instantiate() as Board
		tree.root.add_child(board)
		await tree.process_frame
		board.set_gravity(Vector2i.DOWN)
		var result: Orb = board.spawn_orb(mode_color, 2, Vector2.ZERO)
		var target: Orb = board.spawn_orb(OrbTypes.OrbColor.GREEN, 1, Vector2(50.0, 0.0))
		var outside: Orb = board.spawn_orb(OrbTypes.OrbColor.GREEN, 1, Vector2(300.0, 0.0))
		var ghost: Orb = board.spawn_orb(OrbTypes.OrbColor.GREEN, 1, Vector2(-50.0, 0.0))
		var waiting: Orb = board.spawn_orb(OrbTypes.OrbColor.GREEN, 1, Vector2(0.0, 50.0))
		result.exit_ghost_state()
		target.exit_ghost_state()
		outside.exit_ghost_state()
		waiting.enter_entrance_wait(waiting.position, Vector2i.DOWN)
		var targets: Array[Dictionary] = board.apply_shockwave(
			Vector2.ZERO,
			2,
			result,
			false,
			mode_color
		)
		assert_eq(targets.size(), 1, "radial mode %d target count" % mode_color)
		if targets.size() == 1:
			assert_eq(targets[0]["orb"], target, "radial mode target")
		assert_true(ghost.is_ghost, "ghost remains excluded")
		assert_true(waiting.is_waiting_at_entrance, "entrance waiter remains excluded")
		board.queue_free()
		await tree.process_frame
	_restore_config(snapshot)


func test_color_mode_jackpot_multiplies_effect_strength() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_color_effects()
	var board: Board3D = BOARD_3D_SCENE.instantiate() as Board3D
	tree.root.add_child(board)
	await tree.process_frame
	board.set_gravity(Vector2i.DOWN)
	var regular_target: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(100.0, 0.0)
	)
	var regular: Array[Dictionary] = board.apply_shockwave(
		Vector2.ZERO,
		7,
		null,
		false,
		OrbTypes.OrbColor.YELLOW
	)
	board.remove_orb(regular_target)
	var jackpot_target: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(100.0, 0.0)
	)
	var jackpot: Array[Dictionary] = board.apply_shockwave(
		Vector2.ZERO,
		7,
		null,
		true,
		OrbTypes.OrbColor.YELLOW
	)
	assert_eq(jackpot[0]["orb"], jackpot_target, "jackpot target")
	assert_near(
		(jackpot[0]["impulse"] as Vector2).length(),
		(regular[0]["impulse"] as Vector2).length() * Config.data.shock_jackpot_scale,
		TOLERANCE,
		"MAX_CLEAR color effect jackpot scale"
	)
	board.queue_free()
	await tree.process_frame
	_restore_config(snapshot)


func _configure_test_shock() -> void:
	Config.data.color_effects_enabled = false
	Config.data.shock_impulse = 300.0
	Config.data.shock_radius_factor = 2.5
	Config.data.shock_level_scale = 0.3
	Config.data.shock_jackpot_scale = 3.0


func _configure_color_effects() -> void:
	Config.data.color_effects_enabled = true
	Config.data.shock_impulse = 300.0
	Config.data.shock_level_scale = 0.3
	Config.data.shock_jackpot_scale = 3.0
	Config.data.shock_color_modes = PackedInt32Array([
		GameConfig.ShockMode.PUSH,
		GameConfig.ShockMode.PULL,
		GameConfig.ShockMode.SHAKE,
		GameConfig.ShockMode.LIFT,
	])
	Config.data.shock_color_impulse_scale = PackedFloat32Array([1.0, 1.0, 0.0, 1.0])
	Config.data.shock_color_radius_factor = PackedFloat32Array([3.0, 3.0, 0.0, 3.0])


func _snapshot_config() -> Dictionary:
	return {
		"color_effects_enabled": Config.data.color_effects_enabled,
		"shock_impulse": Config.data.shock_impulse,
		"shock_radius_factor": Config.data.shock_radius_factor,
		"shock_level_scale": Config.data.shock_level_scale,
		"shock_jackpot_scale": Config.data.shock_jackpot_scale,
		"shock_color_modes": Config.data.shock_color_modes.duplicate(),
		"shock_color_impulse_scale": Config.data.shock_color_impulse_scale.duplicate(),
		"shock_color_radius_factor": Config.data.shock_color_radius_factor.duplicate(),
		"green_shake_speed": Config.data.green_shake_speed,
		"green_shake_max_speed": Config.data.green_shake_max_speed,
	}


func _restore_config(snapshot: Dictionary) -> void:
	Config.data.color_effects_enabled = bool(snapshot["color_effects_enabled"])
	Config.data.shock_impulse = float(snapshot["shock_impulse"])
	Config.data.shock_radius_factor = float(snapshot["shock_radius_factor"])
	Config.data.shock_level_scale = float(snapshot["shock_level_scale"])
	Config.data.shock_jackpot_scale = float(snapshot["shock_jackpot_scale"])
	Config.data.shock_color_modes = snapshot["shock_color_modes"] as PackedInt32Array
	Config.data.shock_color_impulse_scale = snapshot["shock_color_impulse_scale"] as PackedFloat32Array
	Config.data.shock_color_radius_factor = snapshot["shock_color_radius_factor"] as PackedFloat32Array
	Config.data.green_shake_speed = float(snapshot["green_shake_speed"])
	Config.data.green_shake_max_speed = float(snapshot["green_shake_max_speed"])
