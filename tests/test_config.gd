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
	assert_near(config.stable_linear_speed, 12.0, TOLERANCE, "stable linear speed")
	assert_near(config.stable_angular_speed, 1.0, TOLERANCE, "stable angular speed")
	assert_near(config.stable_duration, 0.33, TOLERANCE, "stable duration")
	assert_near(config.max_settle_time, 3.0, TOLERANCE, "maximum settle time")
	assert_eq(config.allow_same_direction_swipe, true, "same direction default")
