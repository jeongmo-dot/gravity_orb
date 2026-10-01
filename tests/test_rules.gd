extends TestCase


func test_same_color_same_level_one_through_six_merge() -> void:
	var cfg: GameConfig = GameConfig.new()
	for color: int in range(cfg.color_display.size()):
		for level: int in range(1, cfg.orb_max_level):
			var result: Dictionary = ReactionRules.classify(
				color,
				level,
				color,
				level,
				cfg
			)
			assert_eq(result["type"], ReactionRules.Type.MERGE, "merge type")
			assert_eq(result["result_level"], level + 1, "merge result level")
			assert_eq(result["result_color"], color, "merge result color")
			assert_eq(result["survivor"], 0, "merge survivor")


func test_same_color_max_level_clears_both() -> void:
	var cfg: GameConfig = GameConfig.new()
	for color: int in range(cfg.color_display.size()):
		var result: Dictionary = ReactionRules.classify(
			color,
			cfg.orb_max_level,
			color,
			cfg.orb_max_level,
			cfg
		)
		assert_eq(result["type"], ReactionRules.Type.MAX_CLEAR, "maximum clear type")
		assert_eq(result["result_level"], 0, "maximum clear result level")
		assert_eq(result["result_color"], color, "maximum clear result color")
		assert_eq(result["survivor"], 0, "maximum clear survivor")


func test_rule_a_annihilates_every_red_blue_level_pair() -> void:
	var cfg: GameConfig = GameConfig.new()
	cfg.annihilation_rule = GameConfig.AnnihilationRule.A_BOTH
	for red_level: int in range(1, cfg.orb_max_level + 1):
		for blue_level: int in range(1, cfg.orb_max_level + 1):
			var result: Dictionary = ReactionRules.classify(
				OrbTypes.OrbColor.RED,
				red_level,
				OrbTypes.OrbColor.BLUE,
				blue_level,
				cfg
			)
			_assert_annihilation(result, 0, 0, "rule A %d/%d" % [red_level, blue_level])


func test_rule_b_annihilates_only_equal_red_blue_levels() -> void:
	var cfg: GameConfig = GameConfig.new()
	cfg.annihilation_rule = GameConfig.AnnihilationRule.B_SAME_LEVEL
	for red_level: int in range(1, cfg.orb_max_level + 1):
		for blue_level: int in range(1, cfg.orb_max_level + 1):
			var result: Dictionary = ReactionRules.classify(
				OrbTypes.OrbColor.RED,
				red_level,
				OrbTypes.OrbColor.BLUE,
				blue_level,
				cfg
			)
			var expected_type: ReactionRules.Type = (
				ReactionRules.Type.ANNIHILATE
				if red_level == blue_level
				else ReactionRules.Type.NONE
			)
			assert_eq(result["type"], expected_type, "rule B %d/%d" % [red_level, blue_level])
			assert_eq(result["survivor"], 0, "rule B survivor")


func test_rule_c_uses_larger_orb_color_level_difference_and_input_side() -> void:
	var cfg: GameConfig = GameConfig.new()
	cfg.annihilation_rule = GameConfig.AnnihilationRule.C_REMAINDER
	var red_larger: Dictionary = ReactionRules.classify(
		OrbTypes.OrbColor.RED,
		4,
		OrbTypes.OrbColor.BLUE,
		1,
		cfg
	)
	_assert_annihilation(red_larger, 3, 1, "rule C survivor a")
	assert_eq(red_larger["result_color"], OrbTypes.OrbColor.RED, "survivor a color")

	var red_larger_on_b: Dictionary = ReactionRules.classify(
		OrbTypes.OrbColor.BLUE,
		2,
		OrbTypes.OrbColor.RED,
		5,
		cfg
	)
	_assert_annihilation(red_larger_on_b, 3, 2, "rule C survivor b")
	assert_eq(red_larger_on_b["result_color"], OrbTypes.OrbColor.RED, "survivor b color")

	var equal: Dictionary = ReactionRules.classify(
		OrbTypes.OrbColor.RED,
		3,
		OrbTypes.OrbColor.BLUE,
		3,
		cfg
	)
	_assert_annihilation(equal, 0, 0, "rule C equal")


func test_green_yellow_level_one_has_no_reaction_under_rule_b() -> void:
	var cfg: GameConfig = GameConfig.new()
	cfg.annihilation_rule = GameConfig.AnnihilationRule.B_SAME_LEVEL
	var result: Dictionary = ReactionRules.classify(
		OrbTypes.OrbColor.GREEN,
		1,
		OrbTypes.OrbColor.YELLOW,
		1,
		cfg
	)
	assert_eq(result["type"], ReactionRules.Type.NONE, "green-yellow rule B")


func test_yellow_same_level_merges() -> void:
	var cfg: GameConfig = GameConfig.new()
	var result: Dictionary = ReactionRules.classify(
		OrbTypes.OrbColor.YELLOW,
		1,
		OrbTypes.OrbColor.YELLOW,
		1,
		cfg
	)
	assert_eq(result["type"], ReactionRules.Type.MERGE, "yellow merge type")
	assert_eq(result["result_level"], 2, "yellow merge result level")
	assert_eq(result["result_color"], OrbTypes.OrbColor.YELLOW, "yellow merge color")


func test_same_color_merge_has_precedence_over_configured_opposite_pair() -> void:
	var cfg: GameConfig = GameConfig.new()
	cfg.opposite_pairs.append(Vector2i(OrbTypes.OrbColor.RED, OrbTypes.OrbColor.RED))
	var result: Dictionary = ReactionRules.classify(
		OrbTypes.OrbColor.RED,
		2,
		OrbTypes.OrbColor.RED,
		2,
		cfg
	)
	assert_eq(result["type"], ReactionRules.Type.MERGE, "merge precedence")
	assert_eq(result["result_level"], 3, "merge precedence level")


func test_rule_change_is_read_on_each_classification() -> void:
	var cfg: GameConfig = GameConfig.new()
	cfg.annihilation_rule = GameConfig.AnnihilationRule.A_BOTH
	var under_a: Dictionary = ReactionRules.classify(
		OrbTypes.OrbColor.RED,
		2,
		OrbTypes.OrbColor.BLUE,
		1,
		cfg
	)
	assert_eq(under_a["type"], ReactionRules.Type.ANNIHILATE, "rule A before change")

	cfg.annihilation_rule = GameConfig.AnnihilationRule.B_SAME_LEVEL
	var under_b: Dictionary = ReactionRules.classify(
		OrbTypes.OrbColor.RED,
		2,
		OrbTypes.OrbColor.BLUE,
		1,
		cfg
	)
	assert_eq(under_b["type"], ReactionRules.Type.NONE, "rule B after change")


func _assert_annihilation(
	result: Dictionary,
	expected_level: int,
	expected_survivor: int,
	message: String
) -> void:
	assert_eq(result["type"], ReactionRules.Type.ANNIHILATE, "%s type" % message)
	assert_eq(result["result_level"], expected_level, "%s level" % message)
	assert_eq(result["survivor"], expected_survivor, "%s survivor" % message)
