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


func test_jelly_mass_level_and_level_fixed_radius() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_eq(int(GameConfig.GameMode.JELLY), 3, "JELLY enum keeps prior values stable")
	for level: int in range(1, config.orb_max_level + 1):
		var mass: float = pow(2.0, float(level - 1))
		assert_near(config.jelly_mass_for_level(level), mass, TOLERANCE, "mass L%d" % level)
		assert_eq(config.jelly_level_for_mass(mass), level, "level from exact mass L%d" % level)
		assert_near(
			config.jelly_radius_for_mass(mass),
			config.radius_for_level(level),
			TOLERANCE,
			"exact mass radius L%d" % level
		)
	assert_eq(config.jelly_level_for_mass(6.0), 3, "mass 6 remains L3")
	assert_near(
		config.jelly_radius_for_mass(6.0),
		config.radius_for_level(3),
		TOLERANCE,
		"mass 6 keeps the L3 radius"
	)
	assert_near(
		config.jelly_radius_for_mass(7.0),
		config.radius_for_level(3),
		TOLERANCE,
		"mass 7 still keeps the L3 radius"
	)


func test_m2_swipe_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_near(config.swipe_min_distance, 80.0, TOLERANCE, "swipe minimum distance")
	assert_near(config.swipe_dominance_ratio, 1.5, TOLERANCE, "swipe dominance ratio")


func test_m3_turn_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_near(config.gravity_strength, 3600.0, TOLERANCE, "gravity strength")
	assert_near(config.gravity_level_scale, 0.05, TOLERANCE, "gravity level scale")
	assert_near(config.gravity_turn_diagonal_time, 0.15, TOLERANCE, "gravity diagonal time")
	assert_near(config.orb_bounce, 0.06, TOLERANCE, "orb bounce")
	assert_near(config.wall_bounce, 0.06, TOLERANCE, "wall bounce")
	assert_near(config.orb_friction, 0.3, TOLERANCE, "orb friction")
	assert_near(config.wall_friction, 0.3, TOLERANCE, "wall friction")
	assert_near(config.orb_angular_damp, 15.0, TOLERANCE, "orb angular damp")
	assert_near(
		config.gravity_for_level(1),
		config.gravity_strength,
		TOLERANCE,
		"level one gravity"
	)
	assert_near(
		config.gravity_for_level(7),
		config.gravity_strength * (1.0 + config.gravity_level_scale * 6.0),
		TOLERANCE,
		"level seven gravity"
	)
	assert_near(config.stable_linear_speed, 30.0, TOLERANCE, "stable linear speed")
	assert_near(config.stable_angular_speed, 3.0, TOLERANCE, "stable angular speed")
	assert_near(config.stable_duration, 0.33, TOLERANCE, "stable duration")
	assert_near(config.max_settle_time, 1.5, TOLERANCE, "maximum settle time")
	assert_eq(config.allow_same_direction_swipe, true, "same direction default")


func test_m4_spawn_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_eq(config.color_display.size(), 6, "display color count")
	var planet_colors: Array[Color] = [
		Color("#D0503A"),
		Color("#2F6FD6"),
		Color("#35B97C"),
		Color("#E9C46A"),
		Color("#6C5CE7"),
		Color("#DCE3EC"),
	]
	for color_index: int in range(planet_colors.size()):
		assert_eq(config.color_display[color_index], planet_colors[color_index], "planet display %d" % color_index)
	assert_eq(config.spawn_level_weights, PackedFloat32Array([0.9, 0.1]), "level weights")
	assert_eq(
		config.spawn_color_weights,
		PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0]),
		"turn color weights"
	)
	assert_eq(config.spawn_count_per_turn, 1, "spawn count per turn")
	assert_eq(config.preview_turns, 2, "preview turns")
	assert_eq(config.spawn_count_ramp_turns, 10, "spawn count ramp interval")
	assert_eq(config.spawn_count_max, 0, "non-positive spawn count maximum is uncapped")
	assert_eq(config.turn_start_colors, 4, "turn mode starts with four colors")
	assert_eq(config.turn_color_unlock_turns, [30, 60], "turn color unlock schedule")
	assert_eq(config.spawn_position_mode, GameConfig.SpawnPositionMode.RANDOM, "position mode")
	assert_near(config.spawn_margin, 4.0, TOLERANCE, "spawn margin")
	assert_near(config.spawn_probe_step, 5.0, TOLERANCE, "spawn probe step")
	assert_eq(config.rng_seed, 0, "random seed default")
	assert_eq(config.initial_orb_count, 2, "initial orb count")


func test_spawn_count_ramp_turn_boundaries() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	var expected: Dictionary = {
		1: 1,
		10: 1,
		11: 2,
		20: 2,
		21: 3,
		50: 5,
		51: 6,
		100: 10,
		101: 11,
	}
	for turn_value: Variant in expected:
		var turn_index: int = int(turn_value)
		assert_eq(
			config.spawn_count_for_turn(turn_index),
			int(expected[turn_index]),
			"spawn count at turn %d" % turn_index
		)
	config.spawn_count_max = -1
	assert_eq(config.spawn_count_for_turn(101), 11, "negative maximum is also uncapped")
	config.spawn_count_max = 3
	assert_eq(config.spawn_count_for_turn(101), 3, "positive maximum permits third orb")
	assert_eq(config.spawn_count_for_turn(151), 3, "positive maximum caps later turns")
	assert_eq(config.spawn_count_for_turn(201), 3, "positive maximum remains capped")


func test_turn_color_unlock_boundaries_follow_color_order() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	config.turn_start_colors = 4
	config.turn_color_unlock_turns = [30, 60]
	assert_eq(config.color_count_for_turn(29), 4, "four colors before first unlock")
	assert_eq(config.color_count_for_turn(30), 5, "fifth color unlocks at turn 30")
	assert_eq(config.color_count_for_turn(60), 6, "sixth color unlocks at turn 60")
	assert_eq(config.newly_unlocked_color_for_turn(30), 4, "fifth color index")
	assert_eq(config.newly_unlocked_color_for_turn(60), 5, "sixth color index")
	assert_eq(config.newly_unlocked_color_for_turn(31), -1, "no forced color after unlock turn")


func test_m5_contact_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_eq(config.contact_max_reported, 16, "maximum reported contacts")


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
	assert_near(config.combo_multiplier_max, 128.0, TOLERANCE, "combo multiplier maximum")
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
			GameConfig.ShockMode.SHAKE,
			GameConfig.ShockMode.PUSH,
			GameConfig.ShockMode.LIFT,
			GameConfig.ShockMode.PULL,
			GameConfig.ShockMode.PUSH,
		]),
		"color effect modes"
	)
	assert_eq(
		config.shock_color_impulse_scale,
		PackedFloat32Array([1.5, 0.0, 1.0, 1.0, 0.8, 1.0]),
		"color impulse scales"
	)
	assert_eq(
		config.shock_color_radius_factor,
		PackedFloat32Array([3.0, 0.0, 2.5, 3.0, 3.0, 2.5]),
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
	assert_eq(config.blast_min_level, 4, "shared blast minimum level")
	assert_eq(config.jelly_blast_min_level, 5, "JELLY blast starts at L5 by default")
	assert_eq(
		config.blast_push_radius_by_level,
		PackedFloat32Array([0.0, 0.0, 0.0, 0.3, 0.55, 1.0, 1.0]),
		"blast push radius by level"
	)
	assert_near(config.blast_speed, 900.0, TOLERANCE, "blast speed")
	assert_near(config.blast_far_factor, 0.4, TOLERANCE, "blast far factor")
	assert_near(config.blast_score_factor, 5.0, TOLERANCE, "blast score factor")
	assert_near(config.blast_blink_period, 0.8, TOLERANCE, "blast blink period")


func test_m8_feedback_defaults() -> void:
	var config: GameConfig = CONFIG_RESOURCE.duplicate(true) as GameConfig
	assert_true(not config.orb_symbols_enabled, "orb symbols disabled by default")
	assert_true(config.fx_enabled, "FX enabled")
	assert_true(config.fx_hitstop_enabled, "hitstop enabled")
	assert_near(config.fx_hitstop_scale, 0.12, TOLERANCE, "hitstop time scale")
	assert_near(config.fx_hitstop_time, 0.07, TOLERANCE, "hitstop duration")
	assert_near(config.fx_shake_px, 16.0, TOLERANCE, "camera shake pixels")
	assert_near(config.fx_shake_time, 0.4, TOLERANCE, "camera shake duration")
	assert_near(config.fx_flash_alpha, 0.35, TOLERANCE, "flash alpha")
	assert_near(config.fx_flash_time, 0.15, TOLERANCE, "flash duration")
	assert_eq(config.fx_debris_per_orb, 24, "debris count per orb")
	assert_true(config.fx_score_popups_enabled, "score popups enabled")
	assert_eq(config.fx_popup_max, 16, "score popup capacity")
	assert_true(config.fx_color_effect_visuals_enabled, "color effect visuals enabled")
	assert_true(config.fx_callouts_enabled, "callouts enabled")
	assert_near(config.fx_tilt_degrees, 6.0, TOLERANCE, "tilt degrees")
	assert_near(config.fx_tilt_duration, 0.3, TOLERANCE, "tilt duration")
	assert_true(config.fx_swipe_trail_enabled, "swipe trail enabled")
	assert_true(not config.fx_orb_stretch_enabled, "orb stretch disabled by default")
	assert_true(config.haptics_enabled, "haptics enabled")
	assert_true(config.sfx_enabled, "SFX enabled")
	assert_near(config.sfx_volume_db, 0.0, TOLERANCE, "SFX volume")
	assert_eq(config.sfx_chain_semitones_max, 12, "chain pitch cap")
	assert_near(config.sfx_pitch_jitter, 0.03, TOLERANCE, "pitch jitter")
