extends TestCase

const CONFIG: SlimeConfig = preload("res://config/slime_config.tres")


func test_slime_config_matches_ported_core_values() -> void:
	assert_true(CONFIG.board_rect.is_equal_approx(Rect2(45.0, 180.0, 550.0, 700.0)), "board")
	assert_near(CONFIG.gravity_acceleration, 2220.0, 1.0e-6, "gravity")
	assert_near(CONFIG.damping, 0.981, 1.0e-6, "damping")
	assert_near(CONFIG.lateral_damping, 0.935, 1.0e-6, "lateral damping")
	assert_near(CONFIG.rest_speed, 34.0, 1.0e-6, "rest speed")
	assert_near(CONFIG.settle_hold, 0.18, 1.0e-6, "settle hold")
	assert_near(CONFIG.soft_stop_start, 1.34, 1.0e-6, "soft stop start")
	assert_near(CONFIG.max_simulation_time, 1.85, 1.0e-6, "simulation cap")
	assert_eq(CONFIG.solver_iterations, 4, "solver passes")
	assert_eq(CONFIG.max_mass, 64, "max mass")
	assert_true(CONFIG.max_growth_enabled, "max growth enabled")
	assert_near(CONFIG.max_growth_exponent, 0.2, 1.0e-6, "max growth exponent")
	assert_near(CONFIG.max_growth_radius_cap, 165.0, 1.0e-6, "max growth radius cap")
	assert_eq(CONFIG.max_slimes, 40, "slime cap")
	assert_eq(CONFIG.radii.size(), 7, "radius count")
	assert_near(CONFIG.radii[0], 31.5, 1.0e-6, "first radius")
	assert_near(CONFIG.radii[6], 112.0, 1.0e-6, "max radius")
	assert_near(CONFIG.pre_max_radius, 108.0, 1.0e-6, "pre-max radius")
	assert_eq(CONFIG.unlock_scores, PackedInt32Array([50000, 150000, 300000, 500000]), "unlock scores")
	assert_eq(CONFIG.color_unlock_mode, "turn", "turn unlock is default")
	assert_eq(CONFIG.color_unlock_turns, [20, 40, 60, 80], "turn unlock schedule")
	assert_eq(
		CONFIG.turn_floor_steps,
		[Vector2i(20, 2), Vector2i(40, 3), Vector2i(60, 4)],
		"turn floor defaults"
	)
	assert_eq(CONFIG.minimum_spawn_count_for_turn(19), 1, "floor before turn 20")
	assert_eq(CONFIG.minimum_spawn_count_for_turn(20), 2, "turn 20 floor")
	assert_eq(CONFIG.minimum_spawn_count_for_turn(40), 3, "turn 40 floor")
	assert_eq(CONFIG.minimum_spawn_count_for_turn(60), 4, "turn 60 floor")
	assert_eq(CONFIG.initial_levels, PackedInt32Array([0, 0, 0, 1]), "initial levels")
	assert_eq(CONFIG.slime_colors.size(), 7, "color count")


func test_radius_interpolation_and_mass_level_boundaries() -> void:
	var sim := SlimeSim.new(CONFIG, 7, false, false)
	for level: int in range(CONFIG.radii.size()):
		var mass: int = 1 << level
		assert_eq(sim.level_for_mass(mass), level, "mass level %d" % mass)
		assert_near(sim.radius_for_mass(mass), CONFIG.radii[level], 1.0e-6, "mass radius %d" % mass)
	assert_near(sim.radius_for_mass(40), 102.75, 1.0e-6, "32..64 uses pre-max radius")
	assert_near(sim.radius_for_mass(63), 107.78125, 1.0e-6, "mass 63 interpolation")
	assert_near(sim.radius_for_mass(64), 112.0, 1.0e-6, "max snaps to max radius")
	assert_near(sim.radius_for_mass(128), 128.65, 0.05, "mass 128 grows beyond max")
	assert_near(sim.radius_for_mass(192), 139.53, 0.05, "mass 192 growth")
	assert_near(sim.radius_for_mass(256), 147.78, 0.05, "mass 256 growth")
	assert_near(sim.radius_for_mass(450), 165.0, 1.0e-6, "large mass caps radius")
