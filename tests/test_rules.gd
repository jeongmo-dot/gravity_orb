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
		{"colors": [3, 3], "levels": [7, 7], "type": ReactionRules.Type.MERGE},
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


func test_default_blast_minimum_starts_at_level_four() -> void:
	var cfg: GameConfig = GameConfig.new()
	var level_three: Dictionary = ReactionRules.classify(0, 3, 1, 3, cfg)
	var level_four: Dictionary = ReactionRules.classify(0, 4, 1, 4, cfg)
	assert_eq(level_three["type"], ReactionRules.Type.NONE, "default excludes L3")
	assert_eq(level_four["type"], ReactionRules.Type.BLAST, "default includes L4")


func test_jelly_same_and_adjacent_levels_absorb_by_abstract_mass() -> void:
	var cfg: GameConfig = GameConfig.new()
	cfg.game_mode = GameConfig.GameMode.JELLY
	var equal: Dictionary = ReactionRules.classify(2, 3, 2, 3, cfg, 3.0, 3.0)
	assert_eq(equal["type"], ReactionRules.Type.MERGE, "JELLY L+L merges")
	assert_eq(equal["result_level"], 4, "JELLY L3+L3 reaches L4")
	assert_near(float(equal["result_mass"]), 6.0, 0.001, "JELLY equal mass sum")
	assert_eq(equal["absorber"], 0, "equal levels use midpoint")

	var adjacent: Dictionary = ReactionRules.classify(2, 3, 2, 2, cfg, 3.0, 2.0)
	assert_eq(adjacent["type"], ReactionRules.Type.MERGE, "JELLY L+(L-1) absorbs")
	assert_eq(adjacent["result_level"], 4, "B adjacent absorption levels up")
	assert_near(float(adjacent["result_mass"]), 5.0, 0.001, "adjacent mass sum")
	assert_eq(adjacent["absorber"], 1, "larger first orb keeps position")
	assert_true(bool(adjacent["jelly_absorption"]), "adjacent merge is absorption")

	var reversed: Dictionary = ReactionRules.classify(2, 2, 2, 3, cfg, 2.0, 3.0)
	assert_eq(reversed["absorber"], 2, "larger second orb keeps position")
	var gap: Dictionary = ReactionRules.classify(2, 4, 2, 2, cfg, 8.0, 2.0)
	assert_eq(gap["type"], ReactionRules.Type.NONE, "JELLY L+(L-2) does not react")


func test_jelly_level_ten_jackpot_and_capped_absorption() -> void:
	var cfg: GameConfig = GameConfig.new()
	cfg.game_mode = GameConfig.GameMode.JELLY
	var jackpot: Dictionary = ReactionRules.classify(1, 10, 1, 10, cfg, 64.0, 64.0)
	assert_eq(jackpot["type"], ReactionRules.Type.MAX_CLEAR, "JELLY L10+L10 jackpots")
	var capped: Dictionary = ReactionRules.classify(1, 10, 1, 9, cfg, 64.0, 42.0)
	assert_eq(capped["type"], ReactionRules.Type.MERGE, "JELLY L10 absorbs L9")
	assert_eq(capped["result_level"], 10, "capped absorption stays L10")
	assert_near(float(capped["result_mass"]), 64.0, 0.001, "JELLY mass caps at 64")


func test_jelly_merge_level_gap_controls_same_color_absorption_only() -> void:
	var cfg: GameConfig = GameConfig.new()
	cfg.game_mode = GameConfig.GameMode.JELLY
	cfg.jelly_merge_level_gap = 1
	var adjacent: Dictionary = ReactionRules.classify(2, 7, 2, 6, cfg, 17.0, 11.0)
	var gap_two_disabled: Dictionary = ReactionRules.classify(2, 7, 2, 5, cfg, 17.0, 7.0)
	assert_eq(adjacent["type"], ReactionRules.Type.MERGE, "gap one allows adjacent levels")
	assert_eq(gap_two_disabled["type"], ReactionRules.Type.NONE, "gap one rejects L+(L-2)")
	assert_true(ReactionRules.can_react(2, 7, 2, 6, cfg), "can_react allows gap one")
	assert_true(not ReactionRules.can_react(2, 7, 2, 5, cfg), "can_react rejects gap two")

	cfg.jelly_merge_level_gap = 2
	var gap_two: Dictionary = ReactionRules.classify(2, 7, 2, 5, cfg, 17.0, 7.0)
	var gap_three: Dictionary = ReactionRules.classify(2, 7, 2, 4, cfg, 17.0, 5.0)
	var capped: Dictionary = ReactionRules.classify(2, 10, 2, 8, cfg, 64.0, 27.0)
	var jackpot: Dictionary = ReactionRules.classify(2, 10, 2, 10, cfg, 64.0, 64.0)
	assert_eq(gap_two["type"], ReactionRules.Type.MERGE, "gap two allows L+(L-2)")
	assert_eq(gap_two["result_level"], 7, "L7+L5 remains L7 at mass 24")
	assert_near(float(gap_two["result_mass"]), 24.0, 0.001, "gap two preserves mass")
	assert_eq(gap_three["type"], ReactionRules.Type.NONE, "gap two rejects L+(L-3)")
	assert_eq(capped["type"], ReactionRules.Type.MERGE, "L10 absorbs L8 at gap two")
	assert_eq(capped["result_level"], 10, "L10+L8 remains capped at L10")
	assert_near(float(capped["result_mass"]), 64.0, 0.001, "L10+L8 caps mass")
	assert_eq(jackpot["type"], ReactionRules.Type.MAX_CLEAR, "L10+L10 remains jackpot")
	assert_true(ReactionRules.can_react(2, 7, 2, 5, cfg), "can_react follows gap two")

	cfg.jelly_blast_min_level = 8
	var different_l8: Dictionary = ReactionRules.classify(0, 8, 1, 8, cfg, 27.0, 27.0)
	var different_gap: Dictionary = ReactionRules.classify(0, 8, 1, 6, cfg, 27.0, 11.0)
	assert_eq(different_l8["type"], ReactionRules.Type.BLAST, "different-color same L8 blasts")
	assert_eq(different_gap["type"], ReactionRules.Type.NONE, "merge gap does not affect colors")


func test_jelly_blast_default_l10_threshold_and_absorption_precedence() -> void:
	var cfg: GameConfig = GameConfig.new()
	cfg.game_mode = GameConfig.GameMode.JELLY
	cfg.blast_enabled = true
	cfg.opposite_pairs = [Vector2i(0, 1)]
	var level_nine_default: Dictionary = ReactionRules.classify(0, 9, 1, 9, cfg, 42.0, 42.0)
	var level_ten_default: Dictionary = ReactionRules.classify(0, 10, 1, 10, cfg, 64.0, 64.0)
	var level_ten_jackpot: Dictionary = ReactionRules.classify(0, 10, 0, 10, cfg, 64.0, 64.0)
	assert_eq(level_nine_default["type"], ReactionRules.Type.NONE, "default leaves different-color L9")
	assert_eq(level_ten_default["type"], ReactionRules.Type.BLAST, "default blasts different-color L10")
	assert_eq(level_ten_jackpot["type"], ReactionRules.Type.MAX_CLEAR, "same-color L10 keeps jackpot precedence")
	cfg.jelly_blast_min_level = 0
	var disabled_result: Dictionary = ReactionRules.classify(0, 6, 1, 6, cfg, 32.0, 32.0)
	assert_eq(disabled_result["type"], ReactionRules.Type.NONE, "explicit J0 disables BLAST")

	cfg.jelly_blast_min_level = 5
	var level_four: Dictionary = ReactionRules.classify(0, 4, 1, 4, cfg, 8.0, 8.0)
	var level_five: Dictionary = ReactionRules.classify(0, 5, 1, 5, cfg, 16.0, 16.0)
	assert_eq(level_four["type"], ReactionRules.Type.NONE, "J5 leaves different-color L4 pair")
	assert_eq(level_five["type"], ReactionRules.Type.BLAST, "J5 blasts different-color L5 pair")

	cfg.jelly_blast_min_level = 4
	var partial_level_four: Dictionary = ReactionRules.classify(0, 4, 1, 4, cfg, 12.0, 8.0)
	assert_eq(
		partial_level_four["type"],
		ReactionRules.Type.BLAST,
		"J4 uses displayed levels even when abstract masses differ"
	)
	var same_color: Dictionary = ReactionRules.classify(0, 4, 0, 4, cfg, 12.0, 8.0)
	assert_eq(same_color["type"], ReactionRules.Type.MERGE, "same-color absorption precedes BLAST")
	var same_color_gap: Dictionary = ReactionRules.classify(0, 6, 0, 4, cfg, 32.0, 8.0)
	assert_eq(same_color_gap["type"], ReactionRules.Type.NONE, "same-color level gap does not BLAST")


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
