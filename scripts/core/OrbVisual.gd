class_name OrbVisual
extends Node2D

var _display_color: Color = Color.WHITE
var _radius: float = 0.0
var _waiting_at_entrance: bool = false
var _waiting_blink_elapsed: float = 0.0
var _blast_armed: bool = false
var _blast_blink_period: float = 0.8
var _blast_blink_elapsed: float = 0.0
var _symbol_color: int = -1
var _symbols_enabled: bool = true
var _symbol_polygons: Array[PackedVector2Array] = []


func setup(
	display_color: Color,
	radius: float,
	symbol_color: int = -1,
	symbols_enabled: bool = true
) -> void:
	_display_color = display_color
	_symbol_color = symbol_color
	_symbols_enabled = symbols_enabled
	_symbol_polygons = OrbSymbols.polygons_for_color(_symbol_color)
	_update_processing()
	set_radius(radius)


func set_radius(radius: float) -> void:
	_radius = radius
	queue_redraw()


func get_radius() -> float:
	return _radius


func set_alpha(alpha: float) -> void:
	_display_color.a = clampf(alpha, 0.0, 1.0)
	queue_redraw()


func get_alpha() -> float:
	return _display_color.a


func symbol_color() -> int:
	return _symbol_color


func has_symbol() -> bool:
	return _symbols_enabled and not _symbol_polygons.is_empty()


func set_symbols_enabled(enabled: bool) -> void:
	_symbols_enabled = enabled
	queue_redraw()


func set_waiting_at_entrance(waiting: bool) -> void:
	_waiting_at_entrance = waiting
	_waiting_blink_elapsed = 0.0
	_update_processing()
	queue_redraw()


func set_blast_armed(armed: bool, blink_period: float) -> void:
	_blast_armed = armed
	_blast_blink_period = maxf(blink_period, 0.001)
	_blast_blink_elapsed = 0.0
	_update_processing()
	queue_redraw()


func is_blast_armed() -> bool:
	return _blast_armed


func blast_brightness() -> float:
	if not _blast_armed:
		return 0.0
	return 0.15 + 0.45 * (
		0.5 + 0.5 * sin(TAU * _blast_blink_elapsed / _blast_blink_period)
	)


func _process(delta: float) -> void:
	if _waiting_at_entrance:
		_waiting_blink_elapsed += delta
	if _blast_armed:
		_blast_blink_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if _radius <= 0.0:
		return
	var draw_color: Color = _display_color
	if _blast_armed:
		var alpha: float = draw_color.a
		draw_color = draw_color.lerp(Color.WHITE, blast_brightness())
		draw_color.a = alpha
	draw_circle(Vector2.ZERO, _radius, draw_color)
	_draw_symbol()
	if _waiting_at_entrance:
		var blink_alpha: float = 0.35 + 0.65 * absf(sin(_waiting_blink_elapsed * 8.0))
		draw_arc(
			Vector2.ZERO,
			_radius + 3.0,
			0.0,
			TAU,
			48,
			Color(1.0, 1.0, 1.0, blink_alpha),
			4.0,
			true
		)


func _draw_symbol() -> void:
	if not has_symbol():
		return
	var symbol_color: Color = Color(
		1.0,
		1.0,
		1.0,
		OrbSymbols.SYMBOL_ALPHA * _display_color.a
	)
	var scale_factor: float = _radius * OrbSymbols.SYMBOL_SIZE_FACTOR
	for normalized_polygon: PackedVector2Array in _symbol_polygons:
		var scaled_polygon: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in normalized_polygon:
			scaled_polygon.append(point * scale_factor)
		draw_colored_polygon(scaled_polygon, symbol_color)


func _update_processing() -> void:
	set_process(_waiting_at_entrance or _blast_armed)
