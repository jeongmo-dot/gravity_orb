extends TestCase

const CONFIG_RESOURCE: GameConfig = preload("res://config/default_config.tres")
const EXPECTED_RADII: Array[float] = [
	25.0,
	40.0,
	60.0,
	85.0,
	100.0,
	120.0,
	140.0,
]
const TOLERANCE: float = 1.0e-3


func test_radius_for_levels_one_through_seven() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_eq(config.orb_max_level, EXPECTED_RADII.size(), "expected radius count")
	assert_eq(config.level_radii.size(), EXPECTED_RADII.size(), "configured radius count")
	for index: int in range(EXPECTED_RADII.size()):
		var level: int = index + 1
		assert_near(
			config.radius_for_level(level),
			EXPECTED_RADII[index],
			TOLERANCE,
			"radius for level %d" % level
		)


func test_mass_for_candidate_exponents() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	var radius_ratio: float = EXPECTED_RADII[1] / EXPECTED_RADII[0]
	for exponent: float in [2.0, 1.5, 1.0]:
		config.mass_exponent = exponent
		assert_near(
			config.mass_for_level(2),
			config.orb_base_mass * pow(radius_ratio, exponent),
			TOLERANCE,
			"mass for level 2 at exponent %.1f" % exponent
		)
	assert_near(
		CONFIG_RESOURCE.mass_exponent,
		2.0,
		TOLERANCE,
		"default mass exponent"
	)


func test_m2_swipe_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_near(config.swipe_min_distance, 80.0, TOLERANCE, "swipe minimum distance")
	assert_near(config.swipe_dominance_ratio, 1.5, TOLERANCE, "swipe dominance ratio")


func test_m3_turn_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_near(config.gravity_strength, 1800.0, TOLERANCE, "gravity strength")
	assert_near(config.gravity_level_scale, 0.1, TOLERANCE, "gravity level scale")
	assert_near(config.gravity_for_level(1), 1800.0, TOLERANCE, "level one gravity")
	config.gravity_level_scale = 0.1
	assert_near(config.gravity_for_level(7), 2880.0, TOLERANCE, "level seven gravity")
	assert_near(config.stable_linear_speed, 30.0, TOLERANCE, "stable linear speed")
	assert_near(config.stable_angular_speed, 3.0, TOLERANCE, "stable angular speed")
	assert_near(config.stable_duration, 0.33, TOLERANCE, "stable duration")
	assert_near(config.max_settle_time, 1.5, TOLERANCE, "maximum settle time")
	assert_eq(config.allow_same_direction_swipe, true, "same direction default")


func test_m4_spawn_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_eq(config.color_display.size(), 4, "display color count")
	assert_eq(config.color_display[OrbTypes.OrbColor.YELLOW], Color("#F5C542"), "yellow display")
	assert_eq(config.spawn_level_weights, PackedFloat32Array([0.9, 0.1]), "level weights")
	assert_eq(
		config.spawn_color_weights,
		PackedFloat32Array([1.0, 1.0, 1.0, 1.0]),
		"color weights"
	)
	assert_eq(config.spawn_count_per_turn, 1, "spawn count per turn")
	assert_eq(config.preview_turns, 2, "preview turns")
	assert_eq(config.spawn_count_ramp_turns, 0, "spawn count ramp disabled")
	assert_eq(config.spawn_count_max, 3, "spawn count maximum")
	assert_eq(config.spawn_position_mode, GameConfig.SpawnPositionMode.RANDOM, "position mode")
	assert_near(config.spawn_margin, 4.0, TOLERANCE, "spawn margin")
	assert_near(config.spawn_probe_step, 5.0, TOLERANCE, "spawn probe step")
	assert_eq(config.rng_seed, 0, "random seed default")
	assert_eq(config.initial_orb_count, 2, "initial orb count")


func test_spawn_count_ramp_turn_boundaries() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	config.spawn_count_per_turn = 1
	config.spawn_count_ramp_turns = 40
	config.spawn_count_max = 3
	var expected: Dictionary = {1: 1, 40: 1, 41: 2, 81: 3, 121: 3}
	for turn_value: Variant in expected:
		var turn_index: int = int(turn_value)
		assert_eq(
			config.spawn_count_for_turn(turn_index),
			int(expected[turn_index]),
			"spawn count at turn %d" % turn_index
		)


func test_m5_contact_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_eq(config.contact_max_reported, 6, "maximum reported contacts")


func test_m5_plus_tuning_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_near(config.rolling_resistance, 0.0, TOLERANCE, "rolling resistance")
	assert_near(config.rest_speed, 0.0, TOLERANCE, "rest speed")
	assert_near(config.rest_damp, 0.0, TOLERANCE, "rest damping")
	assert_near(config.floor_contact_tolerance, 2.0, TOLERANCE, "floor contact tolerance")
	assert_near(config.escape_guard_depth, 25.0, TOLERANCE, "escape guard depth")
	assert_near(config.grow_duration, 0.06, TOLERANCE, "growth duration")
	assert_near(config.grow_start_ratio, 0.3, TOLERANCE, "growth start ratio")
	assert_near(config.ghost_exit_overlap, 4.0, TOLERANCE, "ghost exit overlap")
	assert_near(config.ghost_max_time, 0.6, TOLERANCE, "ghost maximum time")
	assert_near(config.ghost_alpha, 0.55, TOLERANCE, "ghost alpha")
	assert_near(
		config.wall_penetration_limit,
		16.0,
		TOLERANCE,
		"wall penetration limit"
	)


func test_m6_annihilation_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_eq(config.opposite_pairs.size(), 0, "opposite pairs disabled by default")
	assert_eq(
		config.annihilation_rule,
		GameConfig.AnnihilationRule.B_SAME_LEVEL,
		"default annihilation rule"
	)
	assert_true(
		not config.is_opposite(OrbTypes.OrbColor.RED, OrbTypes.OrbColor.BLUE),
		"red-blue is not opposite by default"
	)
	assert_true(
		not config.is_opposite(OrbTypes.OrbColor.GREEN, OrbTypes.OrbColor.YELLOW),
		"green-yellow is not an opposite pair"
	)
	assert_true(
		not config.is_opposite(OrbTypes.OrbColor.YELLOW, OrbTypes.OrbColor.GREEN),
		"yellow-green is not an opposite pair"
	)


func test_m7_score_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_eq(
		config.level_scores,
		PackedInt32Array([2, 4, 8, 16, 32, 64, 128]),
		"level scores"
	)
	assert_near(
		config.annihilation_score_factor,
		0.5,
		TOLERANCE,
		"annihilation score factor"
	)
	assert_near(
		config.max_merge_bonus_factor,
		5.0,
		TOLERANCE,
		"maximum merge bonus factor"
	)
	assert_near(config.combo_multiplier_base, 2.0, TOLERANCE, "combo multiplier base")
	assert_near(config.danger_start, 0.30, TOLERANCE, "danger start")
	assert_near(config.danger_doubling, 0.20, TOLERANCE, "danger doubling")
	assert_near(config.shock_impulse, 600.0, TOLERANCE, "shock impulse")
	assert_near(config.shock_radius_factor, 2.5, TOLERANCE, "shock radius factor")
	assert_near(config.shock_level_scale, 0.3, TOLERANCE, "shock level scale")
	assert_near(config.shock_jackpot_scale, 3.0, TOLERANCE, "shock jackpot scale")
	assert_true(config.color_effects_enabled, "color effects enabled")
	assert_eq(
		config.shock_color_modes,
		PackedInt32Array([
			GameConfig.ShockMode.PUSH,
			GameConfig.ShockMode.PULL,
			GameConfig.ShockMode.SHAKE,
			GameConfig.ShockMode.LIFT,
		]),
		"color effect modes"
	)
	assert_eq(
		config.shock_color_impulse_scale,
		PackedFloat32Array([1.5, 0.8, 0.0, 1.0]),
		"color impulse scales"
	)
	assert_eq(
		config.shock_color_radius_factor,
		PackedFloat32Array([3.0, 3.0, 0.0, 3.0]),
		"color radius factors"
	)
	assert_near(config.green_shake_speed, 150.0, TOLERANCE, "green shake speed")
	assert_near(config.green_shake_max_speed, 600.0, TOLERANCE, "green shake cap")
	assert_near(config.chain_reaction_delay, 0.2, TOLERANCE, "chain reaction delay")
	for level: int in range(1, config.orb_max_level + 1):
		assert_eq(
			config.score_for_level(level),
			config.level_scores[level - 1],
			"score for level %d" % level
		)


func test_m9_blast_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_true(config.blast_enabled, "blast enabled")
	assert_eq(config.blast_min_level, 6, "blast minimum level")
	assert_near(config.blast_speed, 900.0, TOLERANCE, "blast speed")
	assert_near(config.blast_far_factor, 0.4, TOLERANCE, "blast far factor")
	assert_near(config.blast_score_factor, 5.0, TOLERANCE, "blast score factor")
	assert_near(config.blast_blink_period, 0.8, TOLERANCE, "blast blink period")
