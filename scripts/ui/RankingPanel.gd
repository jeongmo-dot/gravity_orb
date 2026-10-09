class_name RankingPanel
extends Control

signal closed

const GOLD: Color = Color("#FFD54A")
const SILVER: Color = Color("#D5DEE8")
const BRONZE: Color = Color("#CD8B62")
const DEFAULT_ROW_COLOR: Color = Color("#E5EDF8")

@export var row_style: StyleBoxFlat
@export var highlight_style: StyleBoxFlat

@onready var _blitz_tab: Button = %RankingBlitzTab
@onready var _classic_tab: Button = %RankingClassicTab
@onready var _header: Label = %RankingHeader
@onready var _close_button: Button = %RankingCloseButton

var _save_path: String = ""
var _mode: GameConfig.GameMode = GameConfig.GameMode.TURN
var _highlight_mode: GameConfig.GameMode = GameConfig.GameMode.TURN
var _highlight_rank: int = 0
var _rows: Array[PanelContainer] = []
var _row_labels: Array[Label] = []
var _pulse_elapsed: float = 0.0


func _ready() -> void:
	for rank: int in range(1, SaveStore.RANKING_LIMIT + 1):
		_rows.append(get_node("Panel/Content/Rows/RankingRow%d" % rank) as PanelContainer)
		_row_labels.append(
			get_node("Panel/Content/Rows/RankingRow%d/Text" % rank) as Label
		)
	_blitz_tab.pressed.connect(func() -> void: _show_mode(GameConfig.GameMode.BLITZ))
	_classic_tab.pressed.connect(func() -> void: _show_mode(GameConfig.GameMode.TURN))
	_close_button.pressed.connect(_on_close_pressed)
	visible = false
	set_process(false)


func bind(save_path: String) -> void:
	_save_path = save_path


func open(
	mode: GameConfig.GameMode,
	highlight_rank: int = 0
) -> void:
	_mode = mode
	_highlight_mode = mode
	_highlight_rank = highlight_rank
	_pulse_elapsed = 0.0
	visible = true
	set_process(true)
	_refresh()


func current_mode() -> GameConfig.GameMode:
	return _mode


func highlighted_rank() -> int:
	return _highlight_rank if _mode == _highlight_mode else 0


func _process(delta: float) -> void:
	_pulse_elapsed += delta
	var active_rank: int = highlighted_rank()
	for index: int in range(_rows.size()):
		if index + 1 == active_rank:
			var alpha: float = 0.88 + 0.12 * (0.5 + 0.5 * sin(_pulse_elapsed * TAU * 1.5))
			_rows[index].modulate = Color(1.0, 1.0, 1.0, alpha)
		else:
			_rows[index].modulate = Color.WHITE


func _show_mode(mode: GameConfig.GameMode) -> void:
	_mode = mode
	_refresh()


func _refresh() -> void:
	var blitz_mode: bool = _mode == GameConfig.GameMode.BLITZ
	_blitz_tab.set_pressed_no_signal(blitz_mode)
	_classic_tab.set_pressed_no_signal(not blitz_mode)
	_header.text = "순위        점수       %s       날짜" % (
		"최대 체인" if blitz_mode else "최대 콤보"
	)
	var rankings: Array[Dictionary] = SaveStore.load_rankings(_save_path, _mode)
	var active_rank: int = highlighted_rank()
	for index: int in range(_rows.size()):
		var rank: int = index + 1
		var row: PanelContainer = _rows[index]
		var label: Label = _row_labels[index]
		row.add_theme_stylebox_override(
			"panel",
			highlight_style if rank == active_rank else row_style
		)
		if index >= rankings.size():
			label.text = "%2d          —" % rank
		else:
			var record: Dictionary = rankings[index]
			var stat_key: String = "max_chain" if blitz_mode else "max_combo"
			label.text = "%2d    %10s       %4d       %s" % [
				rank,
				_format_score(int(record["score"])),
				int(record[stat_key]),
				_short_date(str(record["date"])),
			]
		label.add_theme_color_override("font_color", _rank_color(rank))


func _on_close_pressed() -> void:
	visible = false
	set_process(false)
	closed.emit()


func _short_date(date: String) -> String:
	if date == "-":
		return date
	return date.substr(5) if date.length() >= 16 else date


func _format_score(score: int) -> String:
	var digits: String = str(maxi(score, 0))
	var formatted: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits[index]
	return formatted


func _rank_color(rank: int) -> Color:
	match rank:
		1:
			return GOLD
		2:
			return SILVER
		3:
			return BRONZE
		_:
			return DEFAULT_ROW_COLOR
