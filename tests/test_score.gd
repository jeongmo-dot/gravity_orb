extends TestCase

const CONFIG_RESOURCE: GameConfig = preload("res://config/default_config.tres")


func test_merge_level_two_to_three_chain_one_scores_eight() -> void:
	assert_eq(
		ScoreManager.points_for(
			_reaction(ReactionRules.Type.MERGE, 1, [2, 2], 3),
			_config()
		),
		8,
		"merge L2 to L3 chain one"
	)


func test_merge_level_three_to_four_chain_two_scores_thirty_two() -> void:
	assert_eq(
		ScoreManager.points_for(
			_reaction(ReactionRules.Type.MERGE, 2, [3, 3], 4),
			_config()
		),
		32,
		"merge L3 to L4 chain two"
	)


func test_annihilation_level_two_and_one_chain_one_scores_three() -> void:
	assert_eq(
		ScoreManager.points_for(
			_reaction(ReactionRules.Type.ANNIHILATE, 1, [2, 1]),
			_config()
		),
		3,
		"annihilation L2 and L1 chain one"
	)


func test_rule_c_annihilation_uses_original_levels_before_chain() -> void:
	assert_eq(
		ScoreManager.points_for(
			_reaction(ReactionRules.Type.ANNIHILATE, 3, [4, 1], 3),
			_config()
		),
		27,
		"rule C annihilation L4 and L1 chain three"
	)


func test_maximum_clear_applies_bonus_then_chain() -> void:
	var cfg: GameConfig = _config()
	var levels: Array[int] = [cfg.orb_max_level, cfg.orb_max_level]
	assert_eq(
		ScoreManager.points_for(
			_reaction(ReactionRules.Type.MAX_CLEAR, 1, levels),
			cfg
		),
		640,
		"maximum clear chain one"
	)
	assert_eq(
		ScoreManager.points_for(
			_reaction(ReactionRules.Type.MAX_CLEAR, 2, levels),
			cfg
		),
		1280,
		"maximum clear chain two"
	)


func _config() -> GameConfig:
	return CONFIG_RESOURCE.duplicate(true) as GameConfig


func _reaction(
	type: ReactionRules.Type,
	chain: int,
	levels: Array[int],
	result_level: int = 0
) -> Dictionary:
	return {
		"type": type,
		"chain": chain,
		"levels": levels,
		"result_level": result_level,
	}
