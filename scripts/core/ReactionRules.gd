class_name ReactionRules
extends RefCounted

enum Type { NONE, MERGE, MAX_CLEAR, ANNIHILATE, BLAST }


static func classify(
	color_a: int,
	level_a: int,
	color_b: int,
	level_b: int,
	cfg: GameConfig,
	mass_a: float = -1.0,
	mass_b: float = -1.0
) -> Dictionary:
	if cfg.game_mode == GameConfig.GameMode.JELLY:
		return _classify_jelly(color_a, level_a, color_b, level_b, cfg, mass_a, mass_b)
	if color_a == color_b and level_a == level_b:
		if level_a == cfg.orb_max_level:
			return _result(Type.MAX_CLEAR, 0, color_a)
		return _result(Type.MERGE, level_a + 1, color_a)

	if cfg.is_opposite(color_a, color_b):
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

	if (
		cfg.blast_enabled
		and level_a == level_b
		and level_a >= cfg.active_blast_min_level()
	):
		return _result(Type.BLAST, 0, color_a)
	return _result(Type.NONE, 0, color_a)


static func _classify_jelly(
	color_a: int,
	level_a: int,
	color_b: int,
	level_b: int,
	cfg: GameConfig,
	mass_a: float,
	mass_b: float
) -> Dictionary:
	if color_a == color_b and absi(level_a - level_b) <= 1:
		if level_a == cfg.orb_max_level and level_b == cfg.orb_max_level:
			return _result(Type.MAX_CLEAR, 0, color_a)
		var resolved_mass_a: float = (
			mass_a if mass_a > 0.0 else cfg.jelly_mass_for_level(level_a)
		)
		var resolved_mass_b: float = (
			mass_b if mass_b > 0.0 else cfg.jelly_mass_for_level(level_b)
		)
		var result_mass: float = minf(
			resolved_mass_a + resolved_mass_b,
			cfg.jelly_mass_for_level(cfg.orb_max_level)
		)
		var absorber: int = 0
		if level_a > level_b:
			absorber = 1
		elif level_b > level_a:
			absorber = 2
		var result: Dictionary = _result(
			Type.MERGE,
			cfg.jelly_level_for_mass(result_mass),
			color_a,
			absorber
		)
		result["result_mass"] = result_mass
		result["absorber"] = absorber
		result["jelly_absorption"] = level_a != level_b
		result["absorbed_level"] = mini(level_a, level_b)
		return result
	if color_a != color_b and level_a == level_b and cfg.blast_enabled_for_level(level_a):
		return _result(Type.BLAST, 0, color_a)
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
		"result_mass": 0.0,
		"absorber": 0,
		"jelly_absorption": false,
		"absorbed_level": 0,
	}
