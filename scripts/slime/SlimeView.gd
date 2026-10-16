class_name SlimeView
extends Node2D

const GRID_STEP: float = 40.0
const BOARD_FILL: Color = Color("111a38")
const BOARD_BORDER: Color = Color("5b72b8")
const GRID_COLOR: Color = Color(0.35, 0.47, 0.72, 0.18)
const ENTRY_SAFE: Color = Color("53dcde")
const ENTRY_CAUTION: Color = Color("ffe77a")
const ENTRY_DANGER: Color = Color("ff7595")

var _sim: SlimeSim


func bind(simulation: SlimeSim) -> void:
	_sim = simulation
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if _sim == null:
		return
	var board: Rect2 = _sim.config.board_rect
	draw_rect(board, BOARD_FILL, true)
	var x: float = board.position.x + GRID_STEP
	while x < board.end.x:
		draw_line(Vector2(x, board.position.y), Vector2(x, board.end.y), GRID_COLOR, 1.0)
		x += GRID_STEP
	var y: float = board.position.y + GRID_STEP
	while y < board.end.y:
		draw_line(Vector2(board.position.x, y), Vector2(board.end.x, y), GRID_COLOR, 1.0)
		y += GRID_STEP
	draw_rect(board, BOARD_BORDER, false, 4.0)
	if not _sim.moving and not _sim.game_over:
		_draw_entry_bars(board)
	for slime: SlimeSim.SlimeBody in _sim.slimes:
		var base_color: Color = _sim.config.slime_colors[slime.color_index]
		var color: Color = base_color.lightened(float(slime.level) * _sim.config.level_lighten)
		draw_circle(slime.position, slime.radius, color)


func _draw_entry_bars(board: Rect2) -> void:
	var half_length: float = 55.0
	var center_x: float = board.position.x + board.size.x * 0.5
	var center_y: float = board.position.y + board.size.y * 0.5
	_draw_bar(
		Vector2(center_x - half_length, board.position.y + 2.0),
		Vector2(center_x + half_length, board.position.y + 2.0),
		_stage_color(_sim.entry_stage_for(Vector2i.DOWN))
	)
	_draw_bar(
		Vector2(center_x - half_length, board.end.y - 2.0),
		Vector2(center_x + half_length, board.end.y - 2.0),
		_stage_color(_sim.entry_stage_for(Vector2i.UP))
	)
	_draw_bar(
		Vector2(board.position.x + 2.0, center_y - half_length),
		Vector2(board.position.x + 2.0, center_y + half_length),
		_stage_color(_sim.entry_stage_for(Vector2i.RIGHT))
	)
	_draw_bar(
		Vector2(board.end.x - 2.0, center_y - half_length),
		Vector2(board.end.x - 2.0, center_y + half_length),
		_stage_color(_sim.entry_stage_for(Vector2i.LEFT))
	)


func _draw_bar(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, Color(color, 0.25), 14.0, true)
	draw_line(from, to, color, 5.0, true)


func _stage_color(stage: int) -> Color:
	if stage == 2:
		return ENTRY_DANGER
	if stage == 1:
		return ENTRY_CAUTION
	return ENTRY_SAFE
