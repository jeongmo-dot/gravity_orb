class_name SlimeHud
extends Node2D

const FONT: FontFile = preload("res://assets/fonts/NotoSansKR-Medium-KSX1001.ttf")
const ORBITRON: FontFile = preload("res://assets/fonts/Orbitron[wght].ttf")
const TITLE_COLOR: Color = Color("dfe8ff")
const BEST_COLOR: Color = Color("ffe77a")
const SCORE_COLOR: Color = Color("75e6a4")
const TURN_COLOR: Color = Color("b8c6ed")
const GRAVITY_COLOR: Color = Color("ffc75f")
const FINAL_COLOR: Color = Color("ff7595")
const FINAL_WARNING_COLOR: Color = Color("ffcf66")
const FACE_COLOR: Color = Color("17203c")

var _sim: SlimeSim
var _chain_text: String = ""
var _chain_left: float = 0.0


func bind(simulation: SlimeSim) -> void:
	_sim = simulation
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func handle_events(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		var event_type: String = str(event.get("type", ""))
		if event_type != "absorbed" and event_type != "max_clear":
			continue
		var chain_value: int = int(event.get("chain", 0))
		if chain_value < 2:
			continue
		var steps: int = mini(chain_value - 1, _sim.config.chain_multiplier_max_steps)
		var multiplier: float = 1.0 + float(steps) * _sim.config.chain_multiplier_step
		_chain_text = "%d CHAIN  x%.2f" % [chain_value, multiplier]
		_chain_left = 1.15


func advance_visuals(delta: float) -> void:
	_chain_left = maxf(0.0, _chain_left - delta)


func status_texts() -> Dictionary:
	return {
		"best": "BEST %06d" % _sim.score,
		"score": "SCORE %06d" % _sim.score,
		"turn": "TURN %02d" % _sim.turn,
		"info": "SLIME %d · C %d/7 · MAX %d/7" % [_sim.slimes.size(), _sim.active_color_count, _sim.completed_colors.size()],
	}


func _draw() -> void:
	if _sim == null:
		return
	var status: Dictionary = status_texts()
	draw_string(ORBITRON, Vector2(30.0, 34.0), "GRAVITY SLIME", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 25, TITLE_COLOR)
	draw_string(ORBITRON, Vector2(390.0, 33.0), str(status["best"]), HORIZONTAL_ALIGNMENT_LEFT, 220.0, 15, BEST_COLOR)
	draw_string(ORBITRON, Vector2(30.0, 72.0), str(status["score"]), HORIZONTAL_ALIGNMENT_LEFT, 195.0, 20, SCORE_COLOR)
	draw_string(ORBITRON, Vector2(230.0, 72.0), str(status["turn"]), HORIZONTAL_ALIGNMENT_LEFT, 130.0, 19, TURN_COLOR)
	draw_string(ORBITRON, Vector2(365.0, 72.0), "GRAVITY", HORIZONTAL_ALIGNMENT_LEFT, 132.0, 19, GRAVITY_COLOR)
	draw_string(FONT, Vector2(495.0, 72.0), _gravity_arrow(), HORIZONTAL_ALIGNMENT_LEFT, 50.0, 19, GRAVITY_COLOR)
	draw_string(ORBITRON, Vector2(30.0, 116.0), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, 70.0, 17, TURN_COLOR)
	for index: int in range(_sim.next_slimes.size()):
		var entry: Dictionary = _sim.next_slimes[index]
		_draw_preview(
			Vector2(115.0 + 62.0 * float(index), 123.0),
			int(entry.get("level", 0)),
			int(entry.get("color", 0))
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(
		ORBITRON,
		Vector2(350.0, 122.0),
		str(status["info"]),
		HORIZONTAL_ALIGNMENT_LEFT,
		280.0,
		14,
		TURN_COLOR
	)
	draw_string(FONT, Vector2(30.0, 166.0), _sim.message, HORIZONTAL_ALIGNMENT_LEFT, 580.0, 17, TITLE_COLOR)
	if _sim.final_move_pending:
		_draw_final_move()
	if _chain_left > 0.0:
		var alpha: float = clampf(_chain_left / 0.30, 0.0, 1.0)
		draw_string(
			ORBITRON,
			Vector2(_sim.config.board_rect.position.x, _sim.config.board_rect.position.y + 52.0),
			_chain_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			_sim.config.board_rect.size.x,
			25,
			Color(1.0, 0.941, 0.627, alpha)
		)


func _draw_preview(center: Vector2, level_value: int, color_index: int) -> void:
	var radius: float = _sim.radius_for_level(level_value) * 0.5
	var rotation_value: float = Vector2(_sim.gravity_direction).angle() - PI * 0.5
	draw_set_transform(center, rotation_value, Vector2.ONE)
	draw_texture_rect(
		SlimeView.material_texture(_sim.config, color_index, level_value),
		Rect2(Vector2(-radius, -radius), Vector2.ONE * radius * 2.0),
		false
	)
	_draw_preview_face(radius, level_value)


func _draw_preview_face(radius: float, level_value: int) -> void:
	var eye: float = clampf(3.8 + float(level_value) * 0.75, 3.8, 7.6)
	var eye_y: float = -0.12 * radius
	var spacing: float = 0.30 * radius
	if level_value >= _sim.config.radii.size() - 1:
		for sign_value: float in [-1.0, 1.0]:
			draw_arc(Vector2(sign_value * spacing, eye_y + 2.0), eye + 2.5, PI + 0.22, TAU - 0.22, 18, FACE_COLOR, 4.0, true)
		draw_circle(Vector2(-0.48 * radius, 0.11 * radius), 7.5, Color(1.0, 0.373, 0.529, 0.52))
		draw_circle(Vector2(0.48 * radius, 0.11 * radius), 7.5, Color(1.0, 0.373, 0.529, 0.52))
		draw_arc(Vector2(0.0, 0.12 * radius), 0.105 * radius, 0.16, PI - 0.16, 18, FACE_COLOR, 4.0, true)
		return
	var half_width: float = eye * 0.72
	var half_height: float = eye * lerpf(1.08, 1.42, float(level_value) / 6.0)
	var inner_height: float = maxf(0.0, half_height - half_width)
	for sign_value: float in [-1.0, 1.0]:
		var position := Vector2(sign_value * spacing, eye_y)
		draw_rect(Rect2(position.x - half_width, position.y - inner_height, half_width * 2.0, inner_height * 2.0), FACE_COLOR, true)
		draw_circle(position - Vector2(0.0, inner_height), half_width, FACE_COLOR)
		draw_circle(position + Vector2(0.0, inner_height), half_width, FACE_COLOR)
		draw_circle(position + Vector2(-0.28 * half_width, -0.40 * half_height), maxf(1.0, 0.27 * half_width), Color(1.0, 1.0, 1.0, 0.88))


func _draw_final_move() -> void:
	var final_box := Rect2(145.0, _sim.config.board_rect.position.y + 22.0, 350.0, 62.0)
	var pulse: float = 0.82 + sin(float(Time.get_ticks_msec()) * 0.008) * 0.18
	draw_rect(final_box, Color(0.08, 0.05, 0.10, 0.78), true)
	draw_rect(final_box, Color(FINAL_WARNING_COLOR, pulse), false, 3.0)
	draw_string(ORBITRON, Vector2(final_box.position.x, final_box.position.y + 40.0), "FINAL MOVE", HORIZONTAL_ALIGNMENT_CENTER, final_box.size.x, 28, FINAL_WARNING_COLOR)


func _gravity_arrow() -> String:
	if _sim.gravity_direction == Vector2i.UP:
		return "↑"
	if _sim.gravity_direction == Vector2i.LEFT:
		return "←"
	if _sim.gravity_direction == Vector2i.RIGHT:
		return "→"
	return "↓"
