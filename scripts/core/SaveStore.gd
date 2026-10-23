class_name SaveStore
extends RefCounted

const RECORDS_SECTION: String = "records"
const RANKINGS_SECTION: String = "rankings"
const SETTINGS_SECTION: String = "settings"
const TURN_BEST_KEY: String = "best_score"
const BLITZ_BEST_KEY: String = "blitz_best_score"
const BLITZ_SURVIVAL_BEST_KEY: String = "blitz_survival_best_score"
const SLIME_BEST_KEY: String = "slime_best_score"
const JELLY_BEST_KEY: String = "jelly_best_score"
const SLIME_BEST_TURNS_KEY: String = "slime_best_turns"
const SLIME_BEST_CHAIN_KEY: String = "slime_best_chain"
const TURN_RANKING_KEY: String = "turn"
const BLITZ_RANKING_KEY: String = "blitz"
const BLITZ_SURVIVAL_RANKING_KEY: String = "blitz_survival"
const SLIME_RANKING_KEY: String = "slime"
const JELLY_RANKING_KEY: String = "jelly"
const LAST_MODE_KEY: String = "last_mode"
const SFX_MUTED_KEY: String = "sfx_muted"
const ORB_SYMBOLS_ENABLED_KEY: String = "orb_symbols_enabled"
const RANKING_LIMIT: int = 10


static func load_best_score(path: String, mode: GameConfig.GameMode) -> int:
	if path.is_empty() or not FileAccess.file_exists(path):
		return 0
	var contents: String = FileAccess.get_file_as_string(path)
	if _has_section(contents, RANKINGS_SECTION):
		var save_file: ConfigFile = ConfigFile.new()
		if save_file.load(path) == OK:
			var ranking_key: String = ranking_key_for_mode(mode)
			if save_file.has_section_key(RANKINGS_SECTION, ranking_key):
				var rankings: Array[Dictionary] = _sanitize_rankings(
					save_file.get_value(RANKINGS_SECTION, ranking_key),
					mode
				)
				return int(rankings[0]["score"]) if not rankings.is_empty() else 0
	var record_key: String = record_key_for_mode(mode)
	var stored_score: Variant = _read_integer_entry(
		contents,
		RECORDS_SECTION,
		record_key
	)
	if stored_score == null:
		return 0
	return maxi(int(stored_score), 0)


static func save_best_score(
	path: String,
	mode: GameConfig.GameMode,
	best_score: int
) -> Error:
	return _save_value(
		path,
		RECORDS_SECTION,
		record_key_for_mode(mode),
		maxi(best_score, 0)
	)


static func load_rankings(path: String, mode: GameConfig.GameMode) -> Array[Dictionary]:
	var rankings: Array[Dictionary] = []
	if path.is_empty() or not FileAccess.file_exists(path):
		return rankings
	var save_file: ConfigFile = ConfigFile.new()
	if save_file.load(path) != OK:
		return rankings
	var ranking_key: String = ranking_key_for_mode(mode)
	if save_file.has_section_key(RANKINGS_SECTION, ranking_key):
		return _sanitize_rankings(save_file.get_value(RANKINGS_SECTION, ranking_key), mode)
	var legacy_best: int = load_best_score(path, mode)
	if legacy_best <= 0:
		return rankings
	rankings.append(_ranking_entry(mode, legacy_best, {}, "-"))
	_save_rankings_and_best(path, mode, rankings)
	return rankings


static func add_ranking(
	path: String,
	mode: GameConfig.GameMode,
	score: int,
	stats: Dictionary,
	date_override: String = ""
) -> Dictionary:
	var result: Dictionary = {"rank": 0, "record": {}}
	if path.is_empty():
		return result
	var rankings: Array[Dictionary] = load_rankings(path, mode)
	var entry: Dictionary = _ranking_entry(
		mode,
		maxi(score, 0),
		stats,
		date_override if not date_override.is_empty() else _current_local_minute()
	)
	var insertion_index: int = rankings.size()
	for index: int in range(rankings.size()):
		if int(entry["score"]) > int(rankings[index]["score"]):
			insertion_index = index
			break
	rankings.insert(insertion_index, entry)
	if rankings.size() > RANKING_LIMIT:
		rankings.resize(RANKING_LIMIT)
	var ranked: bool = insertion_index < RANKING_LIMIT
	_save_rankings_and_best(path, mode, rankings, stats)
	result["rank"] = insertion_index + 1 if ranked else 0
	result["record"] = entry.duplicate(true) if ranked else {}
	return result


static func load_last_mode(
	path: String,
	fallback: GameConfig.GameMode
) -> GameConfig.GameMode:
	if path.is_empty() or not FileAccess.file_exists(path):
		return fallback
	var stored_value: Variant = _read_value_text(
		FileAccess.get_file_as_string(path),
		SETTINGS_SECTION,
		LAST_MODE_KEY
	)
	if stored_value == null:
		return fallback
	var saved_mode: String = str(stored_value).trim_prefix('"').trim_suffix('"').to_lower()
	if saved_mode == "blitz":
		return GameConfig.GameMode.BLITZ
	if saved_mode == "turn":
		return GameConfig.GameMode.TURN
	if saved_mode == "slime":
		return GameConfig.GameMode.SLIME
	if saved_mode == "jelly":
		return GameConfig.GameMode.JELLY
	return fallback


static func save_last_mode(path: String, mode: GameConfig.GameMode) -> Error:
	return _save_value(
		path,
		SETTINGS_SECTION,
		LAST_MODE_KEY,
		_mode_name(mode)
	)


static func load_slime_records(path: String) -> Dictionary:
	return {
		"score": load_best_score(path, GameConfig.GameMode.SLIME),
		"turns": _load_non_negative_record(path, SLIME_BEST_TURNS_KEY),
		"max_chain": _load_non_negative_record(path, SLIME_BEST_CHAIN_KEY),
	}


static func load_sfx_muted(path: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var stored_value: Variant = _read_value_text(
		FileAccess.get_file_as_string(path),
		SETTINGS_SECTION,
		SFX_MUTED_KEY
	)
	return stored_value != null and str(stored_value).to_lower() == "true"


static func save_sfx_muted(path: String, muted: bool) -> Error:
	return _save_value(path, SETTINGS_SECTION, SFX_MUTED_KEY, muted)


static func load_orb_symbols_enabled(path: String, fallback: bool) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return fallback
	var stored_value: Variant = _read_value_text(
		FileAccess.get_file_as_string(path),
		SETTINGS_SECTION,
		ORB_SYMBOLS_ENABLED_KEY
	)
	if stored_value == null:
		return fallback
	var value_text: String = str(stored_value).to_lower()
	if value_text == "true":
		return true
	if value_text == "false":
		return false
	return fallback


static func save_orb_symbols_enabled(path: String, enabled: bool) -> Error:
	return _save_value(path, SETTINGS_SECTION, ORB_SYMBOLS_ENABLED_KEY, enabled)


static func record_key_for_mode(mode: GameConfig.GameMode) -> String:
	if mode == GameConfig.GameMode.SLIME:
		return SLIME_BEST_KEY
	if mode == GameConfig.GameMode.JELLY:
		return JELLY_BEST_KEY
	if mode == GameConfig.GameMode.BLITZ:
		if Config.data.blitz_survival_enabled:
			return BLITZ_SURVIVAL_BEST_KEY
		return BLITZ_BEST_KEY
	return TURN_BEST_KEY


static func ranking_key_for_mode(mode: GameConfig.GameMode) -> String:
	if mode == GameConfig.GameMode.SLIME:
		return SLIME_RANKING_KEY
	if mode == GameConfig.GameMode.JELLY:
		return JELLY_RANKING_KEY
	if mode == GameConfig.GameMode.BLITZ:
		if Config.data.blitz_survival_enabled:
			return BLITZ_SURVIVAL_RANKING_KEY
		return BLITZ_RANKING_KEY
	return TURN_RANKING_KEY


static func _ranking_entry(
	mode: GameConfig.GameMode,
	score: int,
	stats: Dictionary,
	date: String
) -> Dictionary:
	var entry: Dictionary = {
		"score": maxi(score, 0),
		"date": date,
	}
	if mode == GameConfig.GameMode.SLIME:
		entry["turns"] = maxi(int(stats.get("turns", 0)), 0)
		entry["max_chain"] = maxi(int(stats.get("max_chain", 0)), 0)
		entry["max_colors"] = maxi(int(stats.get("max_colors", 0)), 0)
	elif mode == GameConfig.GameMode.BLITZ:
		entry["max_chain"] = maxi(int(stats.get("max_chain", 0)), 0)
		entry["blasts"] = maxi(int(stats.get("blasts", 0)), 0)
		entry["fevers"] = maxi(int(stats.get("fevers", 0)), 0)
	else:
		entry["max_combo"] = maxi(int(stats.get("max_combo", 0)), 0)
		entry["turns"] = maxi(int(stats.get("turns", 0)), 0)
		entry["max_level"] = maxi(int(stats.get("max_level", 0)), 0)
		if mode == GameConfig.GameMode.JELLY:
			entry["final_moves"] = maxi(int(stats.get("final_moves", 0)), 0)
	return entry


static func _sanitize_rankings(
	stored_value: Variant,
	mode: GameConfig.GameMode
) -> Array[Dictionary]:
	var rankings: Array[Dictionary] = []
	if typeof(stored_value) != TYPE_ARRAY:
		return rankings
	for raw_entry: Variant in stored_value as Array:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		if not _ranking_entry_is_valid(entry, mode):
			continue
		var stats: Dictionary = {}
		if mode == GameConfig.GameMode.SLIME:
			stats = {
				"turns": entry["turns"],
				"max_chain": entry["max_chain"],
				"max_colors": entry["max_colors"],
			}
		elif mode == GameConfig.GameMode.BLITZ:
			stats = {
				"max_chain": entry["max_chain"],
				"blasts": entry["blasts"],
				"fevers": entry["fevers"],
			}
		else:
			stats = {
				"max_combo": entry["max_combo"],
				"turns": entry["turns"],
				"max_level": entry["max_level"],
			}
			if mode == GameConfig.GameMode.JELLY:
				stats["final_moves"] = entry["final_moves"]
		var sanitized: Dictionary = _ranking_entry(
			mode,
			int(entry["score"]),
			stats,
			str(entry["date"])
		)
		var insertion_index: int = rankings.size()
		for index: int in range(rankings.size()):
			if int(sanitized["score"]) > int(rankings[index]["score"]):
				insertion_index = index
				break
		rankings.insert(insertion_index, sanitized)
		if rankings.size() > RANKING_LIMIT:
			rankings.resize(RANKING_LIMIT)
	return rankings


static func _ranking_entry_is_valid(
	entry: Dictionary,
	mode: GameConfig.GameMode
) -> bool:
	if (
		not entry.has("score")
		or typeof(entry["score"]) != TYPE_INT
		or int(entry["score"]) < 0
		or not entry.has("date")
		or typeof(entry["date"]) != TYPE_STRING
		or not _ranking_date_is_valid(str(entry["date"]))
	):
		return false
	var stat_keys: Array[String] = []
	if mode == GameConfig.GameMode.SLIME:
		stat_keys.assign(["turns", "max_chain", "max_colors"])
	elif mode == GameConfig.GameMode.BLITZ:
		stat_keys.assign(["max_chain", "blasts", "fevers"])
	else:
		stat_keys.assign(["max_combo", "turns", "max_level"])
		if mode == GameConfig.GameMode.JELLY:
			stat_keys.append("final_moves")
	for key: String in stat_keys:
		if not entry.has(key) or typeof(entry[key]) != TYPE_INT or int(entry[key]) < 0:
			return false
	return true


static func _ranking_date_is_valid(date: String) -> bool:
	if date == "-":
		return true
	if (
		date.length() != 16
		or date[4] != "-"
		or date[7] != "-"
		or date[10] != " "
		or date[13] != ":"
	):
		return false
	var year_text: String = date.substr(0, 4)
	var month_text: String = date.substr(5, 2)
	var day_text: String = date.substr(8, 2)
	var hour_text: String = date.substr(11, 2)
	var minute_text: String = date.substr(14, 2)
	for field: String in [year_text, month_text, day_text, hour_text, minute_text]:
		if not _contains_only_digits(field):
			return false
	var year: int = year_text.to_int()
	var month: int = month_text.to_int()
	var day: int = day_text.to_int()
	var hour: int = hour_text.to_int()
	var minute: int = minute_text.to_int()
	if year <= 0 or month < 1 or month > 12 or hour > 23 or minute > 59:
		return false
	var days_in_month: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var leap_year: bool = year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
	if leap_year:
		days_in_month[1] = 29
	return day >= 1 and day <= days_in_month[month - 1]


static func _contains_only_digits(value: String) -> bool:
	for index: int in range(value.length()):
		var character: int = value.unicode_at(index)
		if character < 48 or character > 57:
			return false
	return not value.is_empty()


static func _save_rankings_and_best(
	path: String,
	mode: GameConfig.GameMode,
	rankings: Array[Dictionary],
	latest_stats: Dictionary = {}
) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	var save_file: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(path):
		save_file.load(path)
	save_file.set_value(RANKINGS_SECTION, ranking_key_for_mode(mode), rankings)
	var best_score: int = int(rankings[0]["score"]) if not rankings.is_empty() else 0
	save_file.set_value(RECORDS_SECTION, record_key_for_mode(mode), best_score)
	if mode == GameConfig.GameMode.SLIME:
		var best_turns: int = _non_negative_int_variant(
			save_file.get_value(RECORDS_SECTION, SLIME_BEST_TURNS_KEY, 0)
		)
		var best_chain: int = _non_negative_int_variant(
			save_file.get_value(RECORDS_SECTION, SLIME_BEST_CHAIN_KEY, 0)
		)
		for entry: Dictionary in rankings:
			best_turns = maxi(best_turns, int(entry.get("turns", 0)))
			best_chain = maxi(best_chain, int(entry.get("max_chain", 0)))
		best_turns = maxi(best_turns, _non_negative_int_variant(latest_stats.get("turns", 0)))
		best_chain = maxi(
			best_chain, _non_negative_int_variant(latest_stats.get("max_chain", 0))
		)
		save_file.set_value(RECORDS_SECTION, SLIME_BEST_TURNS_KEY, best_turns)
		save_file.set_value(RECORDS_SECTION, SLIME_BEST_CHAIN_KEY, best_chain)
	return save_file.save(path)


static func _load_non_negative_record(path: String, key: String) -> int:
	if path.is_empty() or not FileAccess.file_exists(path):
		return 0
	var stored_value: Variant = _read_integer_entry(
		FileAccess.get_file_as_string(path), RECORDS_SECTION, key
	)
	return maxi(int(stored_value), 0) if stored_value != null else 0


static func _non_negative_int_variant(value: Variant) -> int:
	return maxi(int(value), 0) if typeof(value) == TYPE_INT else 0


static func _mode_name(mode: GameConfig.GameMode) -> String:
	if mode == GameConfig.GameMode.BLITZ:
		return "blitz"
	if mode == GameConfig.GameMode.SLIME:
		return "slime"
	if mode == GameConfig.GameMode.JELLY:
		return "jelly"
	return "turn"


static func _current_local_minute() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d" % [
		int(now["year"]),
		int(now["month"]),
		int(now["day"]),
		int(now["hour"]),
		int(now["minute"]),
	]


static func _save_value(
	path: String,
	section: String,
	key: String,
	value: Variant
) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	var save_file: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(path):
		save_file.load(path)
	save_file.set_value(section, key, value)
	return save_file.save(path)


static func _read_integer_entry(
	contents: String,
	section: String,
	key: String
) -> Variant:
	var stored_value: Variant = _read_value_text(contents, section, key)
	if stored_value == null:
		return null
	var value_text: String = str(stored_value)
	return value_text.to_int() if value_text.is_valid_int() else null


static func _has_section(contents: String, section: String) -> bool:
	var section_header: String = "[%s]" % section
	for raw_line: String in contents.split("\n"):
		if raw_line.strip_edges() == section_header:
			return true
	return false


static func _read_value_text(
	contents: String,
	section: String,
	key: String
) -> Variant:
	var in_section: bool = false
	for raw_line: String in contents.split("\n"):
		var line: String = raw_line.strip_edges()
		if line == "[%s]" % section:
			in_section = true
			continue
		if line.begins_with("["):
			in_section = false
			continue
		var prefix: String = "%s=" % key
		if in_section and line.begins_with(prefix):
			return line.trim_prefix(prefix).strip_edges()
	return null


