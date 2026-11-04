extends TestCase


func test_level_eight_to_ten_tap_blast_uses_source_level_score_and_multipliers() -> void:
	var cfg: GameConfig = GameConfig.new()
	var expected: Dictionary = {8: 27, 9: 42, 10: 64}
	for level: int in [8, 9, 10]:
		var reaction: Dictionary = {
			"type": ReactionRules.Type.TAP_BLAST,
			"levels": [level],
			"combo": 1,
			"occupancy": 0.0,
		}
		assert_eq(
			ScoreManager.points_for(reaction, cfg),
			int(expected[level]),
			"tap blast scores half of L%d at combo one" % level
		)


func test_yellow_tap_clean_bonus_example_scores_one_thousand_fifty_seven() -> void:
	var cfg: GameConfig = GameConfig.new()
	var reaction: Dictionary = {
		"type": ReactionRules.Type.TAP_BLAST,
		"levels": [8],
		"clean_levels": [1, 1, 1, 1, 1, 1, 2, 2, 2, 3],
		"tap_effect": GameConfig.JellyTapEffect.BONUS,
		"combo": 1,
		"occupancy": 0.0,
	}
	assert_eq(ScoreManager.points_for(reaction, cfg), 1057, "specified yellow base score")
	assert_eq(reaction["base_points"], 1057, "yellow source clean and bonus sum")
	reaction["occupancy"] = 0.5
	assert_eq(ScoreManager.points_for(reaction, cfg), 2114, "danger doubles yellow score")

const CONFIG_RESOURCE: GameConfig = preload("res://config/default_config.tres")
const TOLERANCE: float = 1.0e-6


func test_same_turn_merge_example_scores_twenty() -> void:
	var cfg: GameConfig = _config()
	var first: Dictionary = _reaction(
		ReactionRules.Type.MERGE,
		1,
		[1, 1],
		2,
		0.20
	)
	var second: Dictionary = _reaction(
		ReactionRules.Type.MERGE,
		2,
		[2, 2],
		3,
		0.20
	)
	assert_eq(ScoreManager.points_for(first, cfg), 4, "first L2 merge")
	assert_eq(ScoreManager.points_for(second, cfg), 12, "second L3 merge")
	assert_eq(int(first["points"]) + int(second["points"]), 16, "same-turn total")


func test_max_clear_uses_bonus_combo_and_danger_multipliers() -> void:
	var cfg: GameConfig = _config()
	var levels: Array[int] = [cfg.orb_max_level, cfg.orb_max_level]
	var base_reaction: Dictionary = _reaction(
		ReactionRules.Type.MAX_CLEAR,
		1,
		levels,
		0,
		0.20
	)
	assert_eq(ScoreManager.points_for(base_reaction, cfg), 5120, "L10 jackpot base score")
	assert_eq(base_reaction["base_points"], 5120, "maximum clear base points")
	var reaction: Dictionary = _reaction(
		ReactionRules.Type.MAX_CLEAR,
		3,
		levels,
		0,
		0.70
	)
	assert_eq(ScoreManager.points_for(reaction, cfg), 81920, "third L10 jackpot at danger")
	assert_eq(reaction["base_points"], 5120, "maximum clear multiplied base")
	assert_near(float(reaction["combo_multiplier"]), 4.0, TOLERANCE, "combo multiplier")
	assert_near(float(reaction["danger_multiplier"]), 4.0, TOLERANCE, "danger multiplier")


func test_danger_multiplier_boundaries() -> void:
	var cfg: GameConfig = _config()
	var expected: Dictionary = {
		0.299: 1.0,
		0.30: 1.0,
		0.50: 2.0,
		0.70: 4.0,
	}
	for occupancy_value: Variant in expected:
		var occupancy: float = float(occupancy_value)
		assert_near(
			ScoreManager.danger_multiplier_for(occupancy, cfg),
			float(expected[occupancy_value]),
			TOLERANCE,
			"danger multiplier at %.1f%%" % (occupancy * 100.0)
		)


func test_annihilation_uses_original_levels_and_combo() -> void:
	var reaction: Dictionary = _reaction(
		ReactionRules.Type.ANNIHILATE,
		2,
		[2, 1],
		0,
		0.20
	)
	assert_eq(ScoreManager.points_for(reaction, _config()), 6, "annihilation combo two")
	assert_eq(reaction["base_points"], 3, "annihilation base")


func test_blast_uses_both_levels_combo_and_danger_multipliers() -> void:
	var cfg: GameConfig = _config()
	var exact_cases: Array[Dictionary] = [
		{"levels": [8, 8], "points": 1620},
		{"levels": [8, 10], "points": 2730},
		{"levels": [10, 10], "points": 3840},
	]
	for exact_case: Dictionary in exact_cases:
		var levels: Array[int] = []
		levels.assign(exact_case["levels"] as Array)
		var reaction: Dictionary = _reaction(
			ReactionRules.Type.BLAST,
			1,
			levels,
			0,
			0.20
		)
		assert_eq(
			ScoreManager.points_for(reaction, cfg),
			int(exact_case["points"]),
			"L%d+L%d blast" % [levels[0], levels[1]]
		)
	var multiplied: Dictionary = _reaction(
		ReactionRules.Type.BLAST,
		2,
		[5, 5],
		0,
		0.50
	)
	assert_eq(ScoreManager.points_for(multiplied, cfg), 1680, "blast combo and danger")
	assert_eq(multiplied["base_points"], 420, "blast base points")


func test_scoring_populates_reaction_dictionary() -> void:
	var reaction: Dictionary = _reaction(
		ReactionRules.Type.MERGE,
		2,
		[2, 2],
		3,
		0.50
	)
	assert_eq(ScoreManager.points_for(reaction, _config()), 24, "scored points")
	for key: String in [
		"base_points",
		"combo_multiplier",
		"danger_multiplier",
		"points",
	]:
		assert_true(reaction.has(key), "scored reaction key %s" % key)


func test_turn_combo_multiplier_caps_at_one_hundred_twenty_eight() -> void:
	var cfg: GameConfig = _config()
	var expected: Dictionary = {
		7: 64.0,
		8: 128.0,
		9: 128.0,
		20: 128.0,
	}
	for combo_value: Variant in expected:
		var combo: int = int(combo_value)
		var reaction: Dictionary = _reaction(
			ReactionRules.Type.MERGE,
			combo,
			[1, 1],
			2,
			0.20
		)
		ScoreManager.points_for(reaction, cfg)
		assert_near(
			float(reaction["combo_multiplier"]),
			float(expected[combo]),
			TOLERANCE,
			"combo %d multiplier" % combo
		)


func test_jelly_merge_scores_new_level_and_absorption_scores_eaten_level() -> void:
	var cfg: GameConfig = _config()
	cfg.game_mode = GameConfig.GameMode.JELLY
	var leveled: Dictionary = _reaction(
		ReactionRules.Type.MERGE,
		1,
		[2, 2],
		3,
		0.20
	)
	leveled["jelly_absorption"] = false
	assert_eq(ScoreManager.points_for(leveled, cfg), 6, "JELLY level-up scores L3")
	var absorbed: Dictionary = _reaction(
		ReactionRules.Type.MERGE,
		1,
		[3, 2],
		3,
		0.20
	)
	absorbed["jelly_absorption"] = true
	absorbed["absorbed_level"] = 2
	assert_eq(ScoreManager.points_for(absorbed, cfg), 4, "JELLY unchanged level scores eaten L2")
	var absorption_level_up: Dictionary = _reaction(
		ReactionRules.Type.MERGE,
		1,
		[3, 2],
		4,
		0.20
	)
	absorption_level_up["jelly_absorption"] = true
	absorption_level_up["absorbed_level"] = 2
	assert_eq(
		ScoreManager.points_for(absorption_level_up, cfg),
		10,
		"JELLY absorption that raises level scores new L4"
	)


func _config() -> GameConfig:
	return CONFIG_RESOURCE.duplicate(true) as GameConfig


func _reaction(
	type: ReactionRules.Type,
	combo: int,
	levels: Array[int],
	result_level: int,
	occupancy: float
) -> Dictionary:
	return {
		"type": type,
		"combo": combo,
		"levels": levels,
		"result_level": result_level,
		"occupancy": occupancy,
	}
