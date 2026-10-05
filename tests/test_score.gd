extends TestCase

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
	assert_eq(ScoreManager.points_for(second, cfg), 16, "second L3 merge")
	assert_eq(int(first["points"]) + int(second["points"]), 20, "same-turn total")


func test_third_max_clear_at_seventy_percent_scores_10240() -> void:
	var cfg: GameConfig = _config()
	var levels: Array[int] = [cfg.orb_max_level, cfg.orb_max_level]
	var reaction: Dictionary = _reaction(
		ReactionRules.Type.MAX_CLEAR,
		3,
		levels,
		0,
		0.70
	)
	assert_eq(ScoreManager.points_for(reaction, cfg), 10240, "third L7 clear")
	assert_eq(reaction["base_points"], 640, "maximum clear base")
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
	for level: int in [5, 6, 7]:
		var reaction: Dictionary = _reaction(
			ReactionRules.Type.BLAST,
			1,
			[level, level],
			0,
			0.20
		)
		var expected: int = (cfg.score_for_level(level) * 2) * 5
		assert_eq(ScoreManager.points_for(reaction, cfg), expected, "L%d blast" % level)
	var multiplied: Dictionary = _reaction(
		ReactionRules.Type.BLAST,
		2,
		[5, 5],
		0,
		0.50
	)
	assert_eq(ScoreManager.points_for(multiplied, cfg), 1280, "blast combo and danger")
	assert_eq(multiplied["base_points"], 320, "blast base points")


func test_scoring_populates_reaction_dictionary() -> void:
	var reaction: Dictionary = _reaction(
		ReactionRules.Type.MERGE,
		2,
		[2, 2],
		3,
		0.50
	)
	assert_eq(ScoreManager.points_for(reaction, _config()), 32, "scored points")
	for key: String in [
		"base_points",
		"combo_multiplier",
		"danger_multiplier",
		"points",
	]:
		assert_true(reaction.has(key), "scored reaction key %s" % key)


func test_blitz_combo_fever_and_finale_scoring() -> void:
	var cfg: GameConfig = _config()
	var reaction: Dictionary = _reaction(
		ReactionRules.Type.MERGE,
		8,
		[3, 3],
		4,
		0.20
	)
	reaction["combo_multiplier"] = 2.4
	reaction["fever"] = true
	assert_eq(ScoreManager.points_for(reaction, cfg), 76, "blitz combo and fever")
	assert_near(float(reaction["fever_multiplier"]), 2.0, TOLERANCE, "fever x2")
	var finale: Dictionary = _reaction(
		ReactionRules.Type.BLAST,
		20,
		[5],
		0,
		0.80
	)
	finale["combo_multiplier"] = 5.0
	finale["fever"] = true
	finale["finale"] = true
	assert_eq(ScoreManager.points_for(finale, cfg), 160, "finale single-orb base only")
	assert_near(float(finale["combo_multiplier"]), 1.0, TOLERANCE, "finale combo ignored")
	assert_near(float(finale["danger_multiplier"]), 1.0, TOLERANCE, "finale danger ignored")
	assert_near(float(finale["fever_multiplier"]), 1.0, TOLERANCE, "finale fever ignored")


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
