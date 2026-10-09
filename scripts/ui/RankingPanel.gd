class_name RankingPanel
extends Control

signal closed

const GOLD: Color = Color("#FFD54A")
const SILVER: Color = Color("#D5DEE8")
const BRONZE: Color = Color("#CD8B62")
const DEFAULT_ROW_COLOR: Color = Color("#E5EDF8")
const HEADER_COLOR: Color = Color("#8CAED6")
const COLUMN_NAMES: Array[String] = ["Rank", "Score", "Stat", "Date"]
const COLUMN_WIDTHS: Array[float] = [100.0, 250.0, 250.0, 300.0]

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
var _header_columns: Dictionary = {}
var _row_columns: Array[Dictionary] = []
var _pulse_elapsed: float = 0.0


func _ready() -> void:
	_header.text = ""
	_header_columns = _create_columns(_header, true)
	for rank: int in range(1, SaveStore.RANKING_LIMIT + 1):
		_rows.append(get_node("Panel/Content/Rows/RankingRow%d" % rank) as PanelContainer)
		var row_host: Label = get_node(
			"Panel/Content/Rows/RankingRow%d/Text" % rank
		) as Label
		row_host.text = ""
		_row_columns.append(_create_columns(row_host, false))
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
	(_header_columns["Rank"] as Label).text = "순위"
	(_header_columns["Score"] as Label).text = "점수"
	(_header_columns["Stat"] as Label).text = "최대 체인" if blitz_mode else "최대 콤보"
	(_header_columns["Date"] as Label).text = "날짜"
	var rankings: Array[Dictionary] = SaveStore.load_rankings(_save_path, _mode)
	var active_rank: int = highlighted_rank()
	for index: int in range(_rows.size()):
		var rank: int = index + 1
		var row: PanelContainer = _rows[index]
		var columns: Dictionary = _row_columns[index]
		row.add_theme_stylebox_override(
			"panel",
			highlight_style if rank == active_rank else row_style
		)
		(columns["Rank"] as Label).text = str(rank)
		if index >= rankings.size():
			(columns["Score"] as Label).text = "—"
			(columns["Stat"] as Label).text = ""
			(columns["Date"] as Label).text = ""
		else:
			var record: Dictionary = rankings[index]
			var stat_key: String = "max_chain" if blitz_mode else "max_combo"
			(columns["Score"] as Label).text = _format_score(int(record["score"]))
			(columns["Stat"] as Label).text = str(int(record[stat_key]))
			(columns["Date"] as Label).text = _short_date(str(record["date"]))
		for column_name: String in COLUMN_NAMES:
			(columns[column_name] as Label).add_theme_color_override(
				"font_color",
				_rank_color(rank)
			)


func _create_columns(host: Control, header: bool) -> Dictionary:
	var columns_container: HBoxContainer = HBoxContainer.new()
	columns_container.name = "Columns"
	columns_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns_container.alignment = BoxContainer.ALIGNMENT_CENTER
	columns_container.add_theme_constant_override("separation", 0)
	host.add_child(columns_container)
	columns_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var columns: Dictionary = {}
	for index: int in range(COLUMN_NAMES.size()):
		var label: Label = Label.new()
		label.name = COLUMN_NAMES[index]
		label.custom_minimum_size = Vector2(COLUMN_WIDTHS[index], 0.0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_RIGHT
			if COLUMN_NAMES[index] == "Score"
			else HORIZONTAL_ALIGNMENT_CENTER
		)
		label.add_theme_font_size_override("font_size", 25 if header else 30)
		if header:
			label.add_theme_color_override("font_color", HEADER_COLOR)
		columns_container.add_child(label)
		columns[COLUMN_NAMES[index]] = label
	return columns


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
