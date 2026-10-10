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
var _celestial_level: int = 0


func setup(
	display_color: Color,
	radius: float,
	symbol_color: int = -1,
	symbols_enabled: bool = true
) -> void:
	_celestial_level = 0
	_display_color = display_color
	_symbol_color = symbol_color
	_symbols_enabled = symbols_enabled
	_symbol_polygons = OrbSymbols.polygons_for_color(_symbol_color)
	_update_processing()
	set_radius(radius)


func setup_celestial_preview(
	display_color: Color,
	radius: float,
	level: int,
	symbol_color: int = -1,
	symbols_enabled: bool = true
) -> void:
	_celestial_level = clampi(level, 1, 7)
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


func celestial_level() -> int:
	return _celestial_level


func celestial_art_key() -> String:
	if _celestial_level <= 0:
		return ""
	return "%s:%d" % [CelestialOrbArt.level_name(_celestial_level), _symbol_color]


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
	if _celestial_level > 0:
		_draw_celestial()
		_draw_symbol()
		if _waiting_at_entrance:
			_draw_waiting_outline()
		return
	var draw_color: Color = _display_color
	if _blast_armed:
		var alpha: float = draw_color.a
		draw_color = draw_color.lerp(Color.WHITE, blast_brightness())
		draw_color.a = alpha
	draw_circle(Vector2.ZERO, _radius, draw_color)
	_draw_symbol()
	if _waiting_at_entrance:
		_draw_waiting_outline()


func _draw_celestial() -> void:
	var alpha: float = _display_color.a
	var base: Color = _display_color
	base.a = alpha
	var body_radius: float = _radius * CelestialOrbArt.body_radius_ratio(_celestial_level)
	if _celestial_level == 4:
		_draw_planet_ring(_radius, base)
	elif _celestial_level >= 6:
		_draw_halo(_radius, body_radius, base, _celestial_level == 7)

	match _celestial_level:
		1:
			_draw_meteor(body_radius, base)
		2:
			_draw_moon(body_radius, base)
		3:
			_draw_rocky_planet(body_radius, base)
		4:
			_draw_ringed_planet(body_radius, base)
		5:
			_draw_gas_giant(body_radius, base)
		6:
			_draw_star(body_radius, base, false)
		7:
			_draw_star(body_radius, base, true)

	draw_arc(
		Vector2.ZERO,
		body_radius * 0.98,
		0.0,
		TAU,
		64,
		_with_alpha(base.lightened(0.28), 0.92 * alpha),
		maxf(1.5, _radius * 0.035),
		true
	)
	if _blast_armed:
		var pulse_alpha: float = clampf(blast_brightness() * 1.7, 0.28, 0.95) * alpha
		draw_arc(
			Vector2.ZERO,
			_radius * 0.94,
			0.0,
			TAU,
			72,
			_with_alpha(base.lightened(0.22), pulse_alpha),
			maxf(2.0, _radius * 0.045),
			true
		)


func _draw_meteor(radius: float, base: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var factors: Array[float] = [0.92, 0.98, 0.91, 0.96, 0.89, 0.97, 0.93, 1.0, 0.90, 0.96, 0.91, 0.99]
	for index: int in range(factors.size()):
		var angle: float = -PI * 0.5 + TAU * float(index) / float(factors.size())
		points.append(Vector2(cos(angle), sin(angle)) * radius * factors[index])
	draw_colored_polygon(points, _with_alpha(base.darkened(0.54), base.a))
	var vein_color: Color = _with_alpha(base.lightened(0.34), 0.94 * base.a)
	draw_polyline(PackedVector2Array([
		Vector2(-0.58, -0.45) * radius,
		Vector2(-0.18, -0.10) * radius,
		Vector2(-0.34, 0.42) * radius,
		Vector2(0.10, 0.18) * radius,
		Vector2(0.52, 0.56) * radius,
	]), vein_color, maxf(1.4, radius * 0.075), true)
	draw_polyline(PackedVector2Array([
		Vector2(0.15, -0.68) * radius,
		Vector2(0.02, -0.23) * radius,
		Vector2(0.43, 0.02) * radius,
	]), vein_color, maxf(1.0, radius * 0.055), true)


func _draw_moon(radius: float, base: Color) -> void:
	draw_circle(Vector2.ZERO, radius, _with_alpha(base.lightened(0.17), base.a))
	var crater_color: Color = _with_alpha(base.darkened(0.33), 0.72 * base.a)
	draw_circle(Vector2(-0.30, -0.22) * radius, radius * 0.22, crater_color)
	draw_circle(Vector2(0.34, 0.18) * radius, radius * 0.16, crater_color)
	draw_circle(Vector2(-0.02, 0.48) * radius, radius * 0.11, crater_color)
	var crater_rim: Color = _with_alpha(base.lightened(0.28), 0.45 * base.a)
	draw_arc(Vector2(-0.30, -0.22) * radius, radius * 0.22, 0.0, TAU, 28, crater_rim, maxf(1.0, radius * 0.025), true)


func _draw_rocky_planet(radius: float, base: Color) -> void:
	draw_circle(Vector2.ZERO, radius, _with_alpha(base.darkened(0.44), base.a))
	var land: Color = _with_alpha(base.lightened(0.16), base.a)
	draw_circle(Vector2(-0.28, -0.20) * radius, radius * 0.43, land)
	draw_circle(Vector2(0.34, 0.16) * radius, radius * 0.35, land)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-0.70, 0.18) * radius,
		Vector2(-0.22, -0.04) * radius,
		Vector2(0.14, 0.34) * radius,
		Vector2(-0.12, 0.70) * radius,
		Vector2(-0.58, 0.58) * radius,
	]), land)
	draw_arc(Vector2.ZERO, radius * 0.93, PI * 1.02, PI * 1.88, 36, _with_alpha(base.lightened(0.38), 0.75 * base.a), maxf(1.5, radius * 0.045), true)


func _draw_ringed_planet(radius: float, base: Color) -> void:
	draw_circle(Vector2.ZERO, radius, _with_alpha(base.darkened(0.12), base.a))
	for band: int in range(-2, 3):
		_draw_body_band(radius, float(band) * radius * 0.24, base, band % 2 == 0)


func _draw_gas_giant(radius: float, base: Color) -> void:
	draw_circle(Vector2.ZERO, radius, _with_alpha(base.darkened(0.18), base.a))
	for band: int in range(-3, 4):
		_draw_body_band(radius, float(band) * radius * 0.21, base, band % 2 == 0)
	draw_circle(Vector2(0.38, 0.20) * radius, radius * 0.16, _with_alpha(base.lightened(0.42), 0.94 * base.a))
	draw_arc(Vector2(0.38, 0.20) * radius, radius * 0.16, 0.0, TAU, 30, _with_alpha(base.darkened(0.35), 0.72 * base.a), maxf(1.0, radius * 0.035), true)


func _draw_star(radius: float, base: Color, solar: bool) -> void:
	draw_circle(Vector2.ZERO, radius, _with_alpha(base.lightened(0.22 if solar else 0.14), base.a))
	var cell_color: Color = _with_alpha(base.lightened(0.52), 0.62 * base.a)
	var cell_count: int = 10 if solar else 7
	for index: int in range(cell_count):
		var angle: float = TAU * float(index) / float(cell_count) + float(index % 3) * 0.21
		var distance: float = radius * (0.28 + 0.36 * float((index * 7) % 5) / 4.0)
		var cell_radius: float = radius * (0.07 + 0.025 * float(index % 3))
		draw_circle(Vector2(cos(angle), sin(angle)) * distance, cell_radius, cell_color)


func _draw_planet_ring(radius: float, base: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(65):
		var angle: float = TAU * float(index) / 64.0
		var point: Vector2 = Vector2(cos(angle) * radius * 0.94, sin(angle) * radius * 0.30)
		points.append(point.rotated(CelestialOrbArt.RING_TILT_RADIANS))
	draw_polyline(points, _with_alpha(base.lightened(0.30), 0.86 * base.a), maxf(2.0, radius * 0.075), true)
	draw_polyline(points, _with_alpha(base.darkened(0.22), 0.56 * base.a), maxf(1.0, radius * 0.025), true)


func _draw_halo(radius: float, body_radius: float, base: Color, solar: bool) -> void:
	var ring_count: int = 5 if solar else 4
	for index: int in range(ring_count, 0, -1):
		var progress: float = float(index) / float(ring_count)
		var halo_radius: float = lerpf(body_radius, radius * 0.98, progress)
		var halo_alpha: float = (0.08 + 0.10 * (1.0 - progress)) * base.a
		draw_circle(Vector2.ZERO, halo_radius, _with_alpha(base, halo_alpha))
	if solar:
		for index: int in range(12):
			var angle: float = TAU * float(index) / 12.0
			var tangent: Vector2 = Vector2(cos(angle), sin(angle))
			var perpendicular: Vector2 = tangent.orthogonal()
			var flare: PackedVector2Array = PackedVector2Array([
				tangent * body_radius * 0.88 + perpendicular * radius * 0.035,
				tangent * radius * (0.94 if index % 3 == 0 else 0.86),
				tangent * body_radius * 0.88 - perpendicular * radius * 0.035,
			])
			draw_colored_polygon(flare, _with_alpha(base.lightened(0.22), 0.55 * base.a))


func _draw_body_band(
	radius: float,
	y: float,
	base: Color,
	bright: bool
) -> void:
	var half_width: float = sqrt(maxf(radius * radius - y * y, 0.0)) * 0.96
	var color_value: Color = base.lightened(0.25) if bright else base.darkened(0.28)
	color_value.a = 0.78 * base.a
	draw_line(
		Vector2(-half_width, y),
		Vector2(half_width, y),
		color_value,
		maxf(2.0, radius * 0.105),
		true
	)


func _draw_waiting_outline() -> void:
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
		if _celestial_level > 0:
			var outline_width: float = maxf(1.5, _radius * 0.035)
			var outline_color: Color = OrbSymbols.OUTLINE_COLOR
			outline_color.a *= _display_color.a
			for offset_index: int in range(8):
				var angle: float = TAU * float(offset_index) / 8.0
				var offset: Vector2 = Vector2(cos(angle), sin(angle)) * outline_width
				var outline_polygon: PackedVector2Array = PackedVector2Array()
				for point: Vector2 in scaled_polygon:
					outline_polygon.append(point + offset)
				draw_colored_polygon(outline_polygon, outline_color)
		draw_colored_polygon(scaled_polygon, symbol_color)


func _with_alpha(color_value: Color, alpha: float) -> Color:
	var result: Color = color_value
	result.a = clampf(alpha, 0.0, 1.0)
	return result


func _update_processing() -> void:
	set_process(_waiting_at_entrance or _blast_armed)
