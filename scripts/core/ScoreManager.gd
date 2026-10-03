class_name ScoreManager
extends Node

signal score_changed(score: int, best: int)
signal reaction_scored(reaction: Dictionary)

@export var save_path: String = "user://save.cfg"

var score: int = 0
var best_score: int = 0
var max_level_reached: int = 0


func _ready() -> void:
	_load_best_score()
	reset()


func reset() -> void:
	score = 0
	max_level_reached = 0
	score_changed.emit(score, best_score)


func on_reaction(reaction: Dictionary) -> void:
	var points: int = points_for(reaction, Config.data)
	score += points
	if int(reaction["type"]) == ReactionRules.Type.MERGE:
		max_level_reached = maxi(max_level_reached, int(reaction["result_level"]))
	if score > best_score:
		best_score = score
		_save_best_score()
	score_changed.emit(score, best_score)
	reaction_scored.emit(reaction)


func on_orb_spawned(level: int) -> void:
	max_level_reached = maxi(max_level_reached, level)


func commit() -> void:
	_save_best_score()


static func points_for(reaction: Dictionary, cfg: GameConfig) -> int:
	var base_points: int = 0
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
		_:
			return 0
	var combo: int = maxi(int(reaction.get("combo", 1)), 1)
	var occupancy: float = float(reaction.get("occupancy", 0.0))
	var combo_multiplier: float = pow(cfg.combo_multiplier_base, float(combo - 1))
	var danger_multiplier: float = danger_multiplier_for(occupancy, cfg)
	var raw_points: float = float(base_points) * combo_multiplier * danger_multiplier
	var nearest_integer: float = round(raw_points)
	if is_equal_approx(raw_points, nearest_integer):
		raw_points = nearest_integer
	var points: int = floori(raw_points)
	reaction["base_points"] = base_points
	reaction["combo_multiplier"] = combo_multiplier
	reaction["danger_multiplier"] = danger_multiplier
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
	best_score = 0
	if save_path.is_empty() or not FileAccess.file_exists(save_path):
		return
	if not _has_valid_best_score_entry(FileAccess.get_file_as_string(save_path)):
		return
	var save_file: ConfigFile = ConfigFile.new()
	if save_file.load(save_path) != OK:
		return
	best_score = maxi(int(save_file.get_value("records", "best_score", 0)), 0)


func _save_best_score() -> void:
	if save_path.is_empty():
		return
	var save_file: ConfigFile = ConfigFile.new()
	save_file.set_value("records", "best_score", best_score)
	save_file.save(save_path)


func _has_valid_best_score_entry(contents: String) -> bool:
	var in_records_section: bool = false
	for raw_line: String in contents.split("\n"):
		var line: String = raw_line.strip_edges()
		if line == "[records]":
			in_records_section = true
			continue
		if line.begins_with("["):
			in_records_section = false
			continue
		if in_records_section and line.begins_with("best_score="):
			return line.trim_prefix("best_score=").strip_edges().is_valid_int()
	return false
