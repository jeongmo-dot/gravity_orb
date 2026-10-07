class_name SaveStore
extends RefCounted

const RECORDS_SECTION: String = "records"
const SETTINGS_SECTION: String = "settings"
const TURN_BEST_KEY: String = "best_score"
const BLITZ_BEST_KEY: String = "blitz_best_score"
const LAST_MODE_KEY: String = "last_mode"
const SFX_MUTED_KEY: String = "sfx_muted"


static func load_best_score(path: String, mode: GameConfig.GameMode) -> int:
	if path.is_empty() or not FileAccess.file_exists(path):
		return 0
	var record_key: String = record_key_for_mode(mode)
	var stored_score: Variant = _read_integer_entry(
		FileAccess.get_file_as_string(path),
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
	return fallback


static func save_last_mode(path: String, mode: GameConfig.GameMode) -> Error:
	return _save_value(
		path,
		SETTINGS_SECTION,
		LAST_MODE_KEY,
		"blitz" if mode == GameConfig.GameMode.BLITZ else "turn"
	)


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


static func record_key_for_mode(mode: GameConfig.GameMode) -> String:
	if mode == GameConfig.GameMode.BLITZ:
		return BLITZ_BEST_KEY
	return TURN_BEST_KEY


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


