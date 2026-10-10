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
	_enable_red_blue(cfg)
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
	cfg.blast_enabled = false
	_enable_red_blue(cfg)
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
	_enable_red_blue(cfg)
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


func test_default_red_blue_same_level_has_no_reaction() -> void:
	var cfg: GameConfig = GameConfig.new()
	var result: Dictionary = ReactionRules.classify(
		OrbTypes.OrbColor.RED,
		1,
		OrbTypes.OrbColor.BLUE,
		1,
		cfg
	)
	assert_eq(result["type"], ReactionRules.Type.NONE, "default red-blue disabled")


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


func test_new_blitz_colors_merge_and_blast() -> void:
	var cfg: GameConfig = GameConfig.new()
	cfg.game_mode = GameConfig.GameMode.BLITZ
	for color: int in [OrbTypes.OrbColor.PURPLE, OrbTypes.OrbColor.CYAN]:
		var merge: Dictionary = ReactionRules.classify(color, 3, color, 3, cfg)
		assert_eq(merge["type"], ReactionRules.Type.MERGE, "new color merge")
		assert_eq(merge["result_color"], color, "new color merge result")
	var blast: Dictionary = ReactionRules.classify(
		OrbTypes.OrbColor.PURPLE,
		6,
		OrbTypes.OrbColor.CYAN,
		6,
		cfg
	)
	assert_eq(blast["type"], ReactionRules.Type.BLAST, "new colors BLITZ blast")


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
	_enable_red_blue(cfg)
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


func test_blast_requires_same_level_different_color_and_minimum_level() -> void:
	var cfg: GameConfig = GameConfig.new()
	cfg.blast_min_level = 5
	var cases: Array[Dictionary] = [
		{"colors": [0, 1], "levels": [5, 5], "type": ReactionRules.Type.BLAST},
		{"colors": [0, 0], "levels": [5, 5], "type": ReactionRules.Type.MERGE},
		{"colors": [0, 0], "levels": [5, 6], "type": ReactionRules.Type.NONE},
		{"colors": [0, 1], "levels": [5, 6], "type": ReactionRules.Type.NONE},
		{"colors": [0, 2], "levels": [6, 6], "type": ReactionRules.Type.BLAST},
		{"colors": [2, 2], "levels": [6, 6], "type": ReactionRules.Type.MERGE},
		{"colors": [0, 1], "levels": [4, 4], "type": ReactionRules.Type.NONE},
		{"colors": [0, 1], "levels": [5, 7], "type": ReactionRules.Type.NONE},
		{"colors": [0, 3], "levels": [7, 7], "type": ReactionRules.Type.BLAST},
		{"colors": [3, 3], "levels": [7, 7], "type": ReactionRules.Type.MAX_CLEAR},
	]
	for item: Dictionary in cases:
		var colors: Array = item["colors"] as Array
		var levels: Array = item["levels"] as Array
		var result: Dictionary = ReactionRules.classify(
			int(colors[0]),
			int(levels[0]),
			int(colors[1]),
			int(levels[1]),
			cfg
		)
		assert_eq(result["type"], item["type"], "blast table %s" % str(item))


func test_blast_toggle_and_minimum_level_preserve_old_behavior() -> void:
	var cfg: GameConfig = GameConfig.new()
	cfg.blast_enabled = false
	var disabled: Dictionary = ReactionRules.classify(0, 5, 1, 5, cfg)
	assert_eq(disabled["type"], ReactionRules.Type.NONE, "disabled blast")
	cfg.blast_enabled = true
	cfg.blast_min_level = 6
	var level_five: Dictionary = ReactionRules.classify(0, 5, 1, 5, cfg)
	var level_six: Dictionary = ReactionRules.classify(0, 6, 1, 6, cfg)
	assert_eq(level_five["type"], ReactionRules.Type.NONE, "minimum excludes L5")
	assert_eq(level_six["type"], ReactionRules.Type.BLAST, "minimum includes L6")


func test_default_blast_minimum_excludes_level_five() -> void:
	var cfg: GameConfig = GameConfig.new()
	var level_five: Dictionary = ReactionRules.classify(0, 5, 1, 5, cfg)
	var level_six: Dictionary = ReactionRules.classify(0, 6, 1, 6, cfg)
	assert_eq(level_five["type"], ReactionRules.Type.NONE, "default excludes L5")
	assert_eq(level_six["type"], ReactionRules.Type.BLAST, "default includes L6")


func test_blitz_and_turn_use_level_six_blast_with_lower_same_color_merges() -> void:
	var cfg: GameConfig = GameConfig.new()
	var turn_level_five: Dictionary = ReactionRules.classify(0, 5, 1, 5, cfg)
	var turn_level_six: Dictionary = ReactionRules.classify(0, 6, 1, 6, cfg)
	assert_eq(turn_level_five["type"], ReactionRules.Type.NONE, "turn L5 remains none")
	assert_eq(turn_level_six["type"], ReactionRules.Type.BLAST, "turn L6 still blasts")
	cfg.game_mode = GameConfig.GameMode.BLITZ
	for level: int in [4, 5]:
		var different_colors: Dictionary = ReactionRules.classify(0, level, 1, level, cfg)
		var same_color: Dictionary = ReactionRules.classify(0, level, 0, level, cfg)
		assert_eq(
			different_colors["type"],
			ReactionRules.Type.NONE,
			"BLITZ different-color L%d does not react" % level
		)
		assert_eq(
			same_color["type"],
			ReactionRules.Type.MERGE,
			"BLITZ same-color L%d merges" % level
		)
	var blitz_level_six: Dictionary = ReactionRules.classify(0, 6, 1, 6, cfg)
	assert_eq(blitz_level_six["type"], ReactionRules.Type.BLAST, "BLITZ L6 blasts")


func _enable_red_blue(cfg: GameConfig) -> void:
	cfg.opposite_pairs = [
		Vector2i(OrbTypes.OrbColor.RED, OrbTypes.OrbColor.BLUE),
	]


func _assert_annihilation(
	result: Dictionary,
	expected_level: int,
	expected_survivor: int,
	message: String
) -> void:
	assert_eq(result["type"], ReactionRules.Type.ANNIHILATE, "%s type" % message)
	assert_eq(result["result_level"], expected_level, "%s level" % message)
	assert_eq(result["survivor"], expected_survivor, "%s survivor" % message)
