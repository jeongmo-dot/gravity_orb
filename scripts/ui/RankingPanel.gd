class_name RankingPanel
extends Control

signal closed

const TRANSITION_SECONDS: float = 0.25
const SLIDE_OFFSET: float = 48.0
const COLUMN_NAMES: Array[String] = ["Rank", "Score", "Stat", "Turns", "Chain", "Max", "Date"]
const COLUMN_WIDTHS: Array[float] = [78.0, 250.0, 190.0, 150.0, 130.0, 110.0, 180.0]
const HEADER_COLOR: Color = Color("#8CA7CC")
const GOLD: Color = Color("#FFD54A")
const SILVER: Color = Color("#C9D3E6")
const BRONZE: Color = Color("#D89A68")
const DEFAULT_ROW_COLOR: Color = Color("#E8EEFF")
const PANEL_VERTICAL_CONTENT_MARGIN: float = 72.0

@export var row_style: StyleBoxFlat
@export var highlight_style: StyleBoxFlat

@onready var _panel: PanelContainer = $Panel
@onready var _header: Label = %RankingHeader
@onready var _close_button: Button = %RankingCloseButton
@onready var _content: VBoxContainer = $Panel/Content

var _save_path: String = ""
var _highlight_rank: int = 0
var _rows: Array[PanelContainer] = []
var _header_columns: Dictionary = {}
var _row_columns: Array[Dictionary] = []
var _pulse_elapsed: float = 0.0
var _transitioning: bool = false
var _rest_position: Vector2 = Vector2.ZERO


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
	_close_button.pressed.connect(_on_close_pressed)
	ButtonMotion.bind(_close_button)
	if not resized.is_connected(_apply_layout):
		resized.connect(_apply_layout)
	_apply_layout()
	visible = false
	set_process(false)


func bind(save_path: String) -> void:
	_save_path = save_path


func open(_mode: GameConfig.GameMode, highlight_rank: int = 0) -> void:
	var was_visible: bool = visible
	_highlight_rank = highlight_rank
	_pulse_elapsed = 0.0
	visible = true
	set_process(true)
	_refresh()
	if was_visible:
		return
	_transitioning = true
	_rest_position = _panel.position
	_panel.position = _rest_position + Vector2(0.0, SLIDE_OFFSET)
	_panel.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "position", _rest_position, TRANSITION_SECONDS)
	tween.tween_property(_panel, "modulate:a", 1.0, TRANSITION_SECONDS)
	await tween.finished
	_transitioning = false


func current_mode() -> GameConfig.GameMode:
	return GameConfig.GameMode.JELLY


func highlighted_rank() -> int:
	return _highlight_rank


func _process(delta: float) -> void:
	_pulse_elapsed += delta
	for index: int in range(_rows.size()):
		if index + 1 == _highlight_rank:
			var alpha: float = 0.88 + 0.12 * (0.5 + 0.5 * sin(_pulse_elapsed * TAU * 1.5))
			_rows[index].modulate = Color(1.0, 1.0, 1.0, alpha)
		else:
			_rows[index].modulate = Color.WHITE


func _refresh() -> void:
	_set_jelly_column_visibility()
	(_header_columns["Rank"] as Label).text = "순위"
	(_header_columns["Score"] as Label).text = "점수"
	(_header_columns["Stat"] as Label).text = "최대 콤보"
	(_header_columns["Turns"] as Label).text = "턴"
	(_header_columns["Date"] as Label).text = "날짜"
	var rankings: Array[Dictionary] = SaveStore.load_rankings(
		_save_path, GameConfig.GameMode.JELLY
	)
	for index: int in range(_rows.size()):
		var rank: int = index + 1
		var row: PanelContainer = _rows[index]
		var columns: Dictionary = _row_columns[index]
		row.add_theme_stylebox_override(
			"panel", highlight_style if rank == _highlight_rank else row_style
		)
		(columns["Rank"] as Label).text = str(rank)
		if index >= rankings.size():
			for column_name: String in COLUMN_NAMES:
				(columns[column_name] as Label).text = (
					"—" if column_name in ["Rank", "Score"] else ""
				)
			(columns["Rank"] as Label).text = str(rank)
		else:
			var record: Dictionary = rankings[index]
			(columns["Score"] as Label).text = _format_score(int(record["score"]))
			(columns["Stat"] as Label).text = "콤보 %d" % int(record["max_combo"])
			(columns["Turns"] as Label).text = str(int(record["turns"]))
			(columns["Date"] as Label).text = _short_date(str(record["date"]))
		for column_name: String in COLUMN_NAMES:
			(columns[column_name] as Label).add_theme_color_override(
				"font_color", _rank_color(rank)
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
		var font_size: int = 25
		if not header:
			match COLUMN_NAMES[index]:
				"Score":
					font_size = 32
					label.theme_type_variation = &"HudDisplayBold"
				"Date":
					font_size = 24
				"Stat":
					font_size = 26
				_:
					font_size = 30
		label.add_theme_font_size_override("font_size", font_size)
		if header:
			label.add_theme_color_override("font_color", HEADER_COLOR)
		columns_container.add_child(label)
		columns[COLUMN_NAMES[index]] = label
	return columns


func _set_jelly_column_visibility() -> void:
	for columns: Dictionary in [_header_columns] + _row_columns:
		(columns["Stat"] as Label).visible = true
		(columns["Turns"] as Label).visible = true
		(columns["Chain"] as Label).visible = false
		(columns["Max"] as Label).visible = false


func _on_close_pressed() -> void:
	if _transitioning or not visible:
		return
	_transitioning = true
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(
		_panel,
		"position",
		_rest_position + Vector2(0.0, SLIDE_OFFSET),
		TRANSITION_SECONDS
	)
	tween.tween_property(_panel, "modulate:a", 0.0, TRANSITION_SECONDS)
	await tween.finished
	_panel.position = _rest_position
	_panel.modulate.a = 1.0
	visible = false
	set_process(false)
	_transitioning = false
	closed.emit()


func _apply_layout() -> void:
	var viewport_size: Vector2 = size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var margin_x: float = maxf(32.0, viewport_size.x * 0.05)
	var scale_factor: float = viewport_size.x / 1080.0
	var content_height: float = _content.get_combined_minimum_size().y
	var panel_height: float = minf(
		maxf(content_height + PANEL_VERTICAL_CONTENT_MARGIN * scale_factor, 1280.0 * scale_factor),
		viewport_size.y - 96.0 * scale_factor
	)
	var margin_y: float = (viewport_size.y - panel_height) * 0.5
	_panel.position = Vector2(margin_x, margin_y)
	_panel.size = Vector2(viewport_size.x - margin_x * 2.0, panel_height)
	_rest_position = _panel.position


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
