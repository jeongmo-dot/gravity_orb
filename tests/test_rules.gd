extends TestCase


func test_same_color_same_level_one_through_six_merge() -> void:
	for color: int in range(Config.data.color_display.size()):
		for level: int in range(1, Config.data.orb_max_level):
			var result: Dictionary = ReactionRules.classify(
				color,
				level,
				color,
				level,
				Config.data
			)
			assert_eq(result["type"], ReactionRules.Type.MERGE, "merge type")
			assert_eq(result["result_level"], level + 1, "merge result level")
			assert_eq(result["result_color"], color, "merge result color")
			assert_eq(result["survivor"], 0, "merge survivor")


func test_same_color_max_level_clears_both() -> void:
	for color: int in range(Config.data.color_display.size()):
		var result: Dictionary = ReactionRules.classify(
			color,
			Config.data.orb_max_level,
			color,
			Config.data.orb_max_level,
			Config.data
		)
		assert_eq(result["type"], ReactionRules.Type.MAX_CLEAR, "maximum clear type")
		assert_eq(result["result_level"], 0, "maximum clear result level")
		assert_eq(result["result_color"], color, "maximum clear result color")
		assert_eq(result["survivor"], 0, "maximum clear survivor")


func test_nonmatching_pairs_have_no_reaction() -> void:
	var color_count: int = Config.data.color_display.size()
	for color: int in range(color_count):
		var unequal_level: Dictionary = ReactionRules.classify(
			color,
			1,
			color,
			2,
			Config.data
		)
		assert_eq(unequal_level["type"], ReactionRules.Type.NONE, "unequal levels")

		for other_color: int in range(color_count):
			if color == other_color:
				continue
			var unequal_color: Dictionary = ReactionRules.classify(
				color,
				1,
				other_color,
				1,
				Config.data
			)
			assert_eq(unequal_color["type"], ReactionRules.Type.NONE, "unequal colors")
