class_name SlimeHud
extends Node2D

const FONT: FontFile = preload("res://assets/fonts/NotoSansKR-Medium-KSX1001.ttf")
const TITLE_FONT: FontFile = preload("res://assets/fonts/Orbitron[wght].ttf")
const TEXT_COLOR: Color = Color("eff6ff")
const MUTED_COLOR: Color = Color("9eb2d9")
const ACCENT_COLOR: Color = Color("53dcde")
const FINAL_COLOR: Color = Color("ff7595")
const FINAL_WARNING_COLOR: Color = Color("ffcf66")

var _sim: SlimeSim


func bind(simulation: SlimeSim) -> void:
	_sim = simulation
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if _sim == null:
		return
	draw_string(TITLE_FONT, Vector2(30.0, 34.0), "GRAVITY SLIME", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 25, TEXT_COLOR)
	# 점수는 한 판 동안 감소하지 않으므로 저장 시스템(#81) 전까지 현재 판의 최고점이다.
	draw_string(FONT, Vector2(390.0, 33.0), "BEST %d" % _sim.score, HORIZONTAL_ALIGNMENT_LEFT, 220.0, 15, MUTED_COLOR)
	draw_string(FONT, Vector2(30.0, 72.0), "SCORE %d" % _sim.score, HORIZONTAL_ALIGNMENT_LEFT, 195.0, 20, TEXT_COLOR)
	draw_string(FONT, Vector2(230.0, 72.0), "TURN %d" % _sim.turn, HORIZONTAL_ALIGNMENT_LEFT, 130.0, 19, TEXT_COLOR)
	draw_string(FONT, Vector2(365.0, 72.0), "GRAVITY %s" % _gravity_arrow(), HORIZONTAL_ALIGNMENT_LEFT, 240.0, 19, ACCENT_COLOR)
	draw_string(FONT, Vector2(30.0, 116.0), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, 70.0, 16, MUTED_COLOR)
	for index: int in range(_sim.next_slimes.size()):
		var entry: Dictionary = _sim.next_slimes[index]
		var level_value: int = int(entry.get("level", 0))
		var color_index: int = int(entry.get("color", 0))
		var center := Vector2(115.0 + 62.0 * float(index), 123.0)
		var radius: float = _sim.radius_for_level(level_value) * 0.5
		var color: Color = _sim.config.slime_colors[color_index].lightened(float(level_value) * _sim.config.level_lighten)
		draw_circle(center, radius, color)
	draw_string(
		FONT,
		Vector2(350.0, 122.0),
		"COLORS %d  SLIMES %d" % [_sim.active_color_count, _sim.slimes.size()],
		HORIZONTAL_ALIGNMENT_LEFT,
		260.0,
		14,
		MUTED_COLOR
	)
	draw_string(FONT, Vector2(30.0, 166.0), _sim.message, HORIZONTAL_ALIGNMENT_LEFT, 570.0, 17, TEXT_COLOR)
	if _sim.final_move_pending or _sim.final_move_active:
		var final_box := Rect2(145.0, _sim.config.board_rect.position.y + 22.0, 350.0, 62.0)
		draw_rect(final_box, Color(0.08, 0.05, 0.10, 0.78), true)
		draw_rect(final_box, FINAL_WARNING_COLOR, false, 3.0)
		draw_string(
			TITLE_FONT,
			Vector2(final_box.position.x, final_box.position.y + 40.0),
			"FINAL MOVE",
			HORIZONTAL_ALIGNMENT_CENTER,
			final_box.size.x,
			28,
			FINAL_WARNING_COLOR
		)
	if _sim.game_over:
		_draw_result_box()


func _gravity_arrow() -> String:
	if _sim.gravity_direction == Vector2i.UP:
		return "↑"
	if _sim.gravity_direction == Vector2i.LEFT:
		return "←"
	if _sim.gravity_direction == Vector2i.RIGHT:
		return "→"
	return "↓"


func _draw_result_box() -> void:
	var box := Rect2(105.0, 405.0, 430.0, 250.0)
	draw_rect(box, Color("111a38"), true)
	draw_rect(box, FINAL_COLOR, false, 3.0)
	draw_string(TITLE_FONT, Vector2(105.0, 465.0), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, 430.0, 31, TEXT_COLOR)
	draw_string(FONT, Vector2(105.0, 520.0), "SCORE  %d" % _sim.score, HORIZONTAL_ALIGNMENT_CENTER, 430.0, 23, ACCENT_COLOR)
	draw_string(FONT, Vector2(105.0, 558.0), "TURN  %d    BEST CHAIN  %d" % [_sim.turn, _sim.run_best_chain], HORIZONTAL_ALIGNMENT_CENTER, 430.0, 16, MUTED_COLOR)
	draw_string(FONT, Vector2(105.0, 618.0), "R  다시 시작", HORIZONTAL_ALIGNMENT_CENTER, 430.0, 17, TEXT_COLOR)
