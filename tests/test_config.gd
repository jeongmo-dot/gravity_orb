extends TestCase

const CONFIG_RESOURCE: GameConfig = preload("res://config/default_config.tres")
const EXPECTED_RADII: Array[float] = [
	50.0,
	62.5,
	78.125,
	97.65625,
	122.0703125,
	152.587890625,
	190.73486328125,
]
const TOLERANCE: float = 1.0e-3


func test_radius_for_levels_one_through_seven() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_eq(config.orb_max_level, EXPECTED_RADII.size(), "expected radius count")
	for index: int in range(EXPECTED_RADII.size()):
		var level: int = index + 1
		assert_near(
			config.radius_for_level(level),
			EXPECTED_RADII[index],
			TOLERANCE,
			"radius for level %d" % level
		)


func test_mass_for_level_two() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_near(config.mass_for_level(2), 1.5625, TOLERANCE, "mass for level 2")


func test_m2_swipe_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_near(config.swipe_min_distance, 80.0, TOLERANCE, "swipe minimum distance")
	assert_near(config.swipe_dominance_ratio, 1.5, TOLERANCE, "swipe dominance ratio")


func test_m3_turn_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_near(config.stable_linear_speed, 30.0, TOLERANCE, "stable linear speed")
	assert_near(config.stable_angular_speed, 3.0, TOLERANCE, "stable angular speed")
	assert_near(config.stable_duration, 0.33, TOLERANCE, "stable duration")
	assert_near(config.max_settle_time, 1.5, TOLERANCE, "maximum settle time")
	assert_eq(config.allow_same_direction_swipe, true, "same direction default")


func test_m4_spawn_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_eq(config.spawn_level_weights, PackedFloat32Array([0.9, 0.1]), "level weights")
	assert_eq(config.spawn_color_weights, PackedFloat32Array([1.0, 1.0, 1.0]), "color weights")
	assert_eq(config.spawn_position_mode, GameConfig.SpawnPositionMode.RANDOM, "position mode")
	assert_near(config.spawn_margin, 4.0, TOLERANCE, "spawn margin")
	assert_eq(config.rng_seed, 0, "random seed default")
	assert_eq(config.initial_orb_count, 2, "initial orb count")


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
	assert_near(config.grow_duration, 0.0, TOLERANCE, "growth duration")
	assert_near(config.grow_start_ratio, 1.0, TOLERANCE, "growth start ratio")
