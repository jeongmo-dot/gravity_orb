class_name ScoreManager
extends Node

signal score_changed(score: int, best: int)
signal reaction_scored(reaction: Dictionary)

@export var save_path: String = "user://save.cfg"

var score: int = 0
var best_score: int = 0
var max_level_reached: int = 0
var last_ranking_result: Dictionary = {"rank": 0, "record": {}}


func _ready() -> void:
	_load_best_score()
	reset()


func reset() -> void:
	score = 0
	max_level_reached = 0
	last_ranking_result = {"rank": 0, "record": {}}
	score_changed.emit(score, best_score)


func on_reaction(reaction: Dictionary) -> void:
	var points: int = points_for(reaction, Config.data)
	score += points
	if int(reaction["type"]) == ReactionRules.Type.MERGE:
		max_level_reached = maxi(max_level_reached, int(reaction["result_level"]))
	if score > best_score:
		best_score = score
	score_changed.emit(score, best_score)
	reaction_scored.emit(reaction)


func on_orb_spawned(level: int) -> void:
	max_level_reached = maxi(max_level_reached, level)


func commit() -> void:
	_save_best_score()


func commit_ranking(
	mode: GameConfig.GameMode,
	stats: Dictionary,
	date_override: String = ""
) -> Dictionary:
	last_ranking_result = SaveStore.add_ranking(
		save_path,
		mode,
		score,
		stats,
		date_override
	)
	var rankings: Array[Dictionary] = SaveStore.load_rankings(save_path, mode)
	if not rankings.is_empty():
		best_score = int(rankings[0]["score"])
	score_changed.emit(score, best_score)
	return last_ranking_result.duplicate(true)


static func points_for(reaction: Dictionary, cfg: GameConfig) -> int:
	var base_points: int = 0
	var finale: bool = bool(reaction.get("finale", false))
	var reaction_type: ReactionRules.Type = reaction["type"] as ReactionRules.Type
	match reaction_type:
		ReactionRules.Type.MERGE:
			base_points = cfg.score_for_level(int(reaction["result_level"]))
		ReactionRules.Type.ANNIHILATE:
			var levels: Array[int] = reaction["levels"] as Array[int]
			base_points = int(
				float(cfg.score_for_level(levels[0]) + cfg.score_for_level(levels[1]))
				* cfg.annihilation_score_factor
			)
		ReactionRules.Type.MAX_CLEAR:
			base_points = int(
				float(cfg.score_for_level(cfg.orb_max_level))
				* cfg.max_merge_bonus_factor
			)
		ReactionRules.Type.BLAST:
			var levels: Array[int] = reaction["levels"] as Array[int]
			if finale:
				base_points = int(
					float(cfg.score_for_level(levels[0])) * cfg.blast_score_factor
				)
			else:
				base_points = int(
					float(cfg.score_for_level(levels[0]) + cfg.score_for_level(levels[1]))
					* cfg.blast_score_factor
				)
		_:
			return 0
	var combo: int = maxi(int(reaction.get("combo", 1)), 1)
	var occupancy: float = float(reaction.get("occupancy", 0.0))
	var combo_multiplier: float = float(
		reaction.get("combo_multiplier", pow(cfg.combo_multiplier_base, float(combo - 1)))
	)
	var danger_multiplier: float = danger_multiplier_for(occupancy, cfg)
	var fever_multiplier: float = (
		cfg.blitz_fever_multiplier if bool(reaction.get("fever", false)) else 1.0
	)
	if finale:
		combo_multiplier = 1.0
		danger_multiplier = 1.0
		fever_multiplier = 1.0
	var raw_points: float = (
		float(base_points) * combo_multiplier * danger_multiplier * fever_multiplier
	)
	var nearest_integer: float = round(raw_points)
	if is_equal_approx(raw_points, nearest_integer):
		raw_points = nearest_integer
	var points: int = floori(raw_points)
	reaction["base_points"] = base_points
	reaction["combo_multiplier"] = combo_multiplier
	reaction["danger_multiplier"] = danger_multiplier
	reaction["fever_multiplier"] = fever_multiplier
	reaction["points"] = points
	return points


static func danger_multiplier_for(occupancy: float, cfg: GameConfig) -> float:
	if occupancy < cfg.danger_start:
		return 1.0
	return pow(
		2.0,
		(occupancy - cfg.danger_start) / cfg.danger_doubling
	)


func _load_best_score() -> void:
	best_score = SaveStore.load_best_score(save_path, Config.data.game_mode)


func _save_best_score() -> void:
	if save_path.is_empty():
		return
	SaveStore.save_best_score(save_path, Config.data.game_mode, best_score)
