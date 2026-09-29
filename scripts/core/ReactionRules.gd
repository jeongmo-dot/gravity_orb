class_name ReactionRules
extends RefCounted

enum Type { NONE, MERGE, MAX_CLEAR, ANNIHILATE }


static func classify(
	color_a: int,
	level_a: int,
	color_b: int,
	level_b: int,
	cfg: GameConfig
) -> Dictionary:
	if color_a == color_b and level_a == level_b:
		if level_a == cfg.orb_max_level:
			return _result(Type.MAX_CLEAR, 0, color_a)
		return _result(Type.MERGE, level_a + 1, color_a)

	if not cfg.is_opposite(color_a, color_b):
		return _result(Type.NONE, 0, color_a)

	match cfg.annihilation_rule:
		GameConfig.AnnihilationRule.A_BOTH:
			return _result(Type.ANNIHILATE, 0, color_a)
		GameConfig.AnnihilationRule.B_SAME_LEVEL:
			if level_a == level_b:
				return _result(Type.ANNIHILATE, 0, color_a)
		GameConfig.AnnihilationRule.C_REMAINDER:
			if level_a == level_b:
				return _result(Type.ANNIHILATE, 0, color_a)
			if level_a > level_b:
				return _result(Type.ANNIHILATE, level_a - level_b, color_a, 1)
			return _result(Type.ANNIHILATE, level_b - level_a, color_b, 2)
	return _result(Type.NONE, 0, color_a)


static func _result(
	type: Type,
	result_level: int,
	result_color: int,
	survivor: int = 0
) -> Dictionary:
	return {
		"type": type,
		"result_level": result_level,
		"result_color": result_color,
		"survivor": survivor,
	}
