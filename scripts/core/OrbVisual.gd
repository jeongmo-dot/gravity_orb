class_name OrbVisual
extends Node2D

const JELLY_FACE_COLOR: Color = Color("17203c")

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
var _jelly_level: int = 0
var _jelly_color_index: int = 0
var _planet_animation_elapsed: float = 0.0


func setup(
	display_color: Color,
	radius: float,
	symbol_color: int = -1,
	symbols_enabled: bool = true
) -> void:
	_celestial_level = 0
	_jelly_level = 0
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
	_jelly_level = 0
	_planet_animation_elapsed = 0.0
	_display_color = display_color
	_symbol_color = symbol_color
	_symbols_enabled = symbols_enabled
	_symbol_polygons = OrbSymbols.polygons_for_color(_symbol_color)
	_update_processing()
	set_radius(radius)


func setup_jelly_preview(
	color_index: int,
	radius: float,
	level: int,
	symbols_enabled: bool = true
) -> void:
	_celestial_level = 0
	_jelly_level = clampi(level, 1, 7)
	_jelly_color_index = clampi(color_index, 0, JellyOrbArt.PALETTE.size() - 1)
	_planet_animation_elapsed = 0.0
	_display_color = JellyOrbArt.color_for(_jelly_color_index, _jelly_level)
	_symbol_color = _jelly_color_index
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


func jelly_level() -> int:
	return _jelly_level


func display_color() -> Color:
	return _display_color


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
	if _celestial_level >= 6 or _jelly_level > 0:
		_planet_animation_elapsed += delta
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
	if _jelly_level > 0:
		_draw_jelly()
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


func _draw_jelly() -> void:
	var texture: Texture2D = JellyOrbArt.preview_texture_for(
		_jelly_color_index,
		_jelly_level
	)
	draw_texture_rect(
		texture,
		Rect2(Vector2.ONE * -_radius, Vector2.ONE * _radius * 2.0),
		false,
		Color(1.0, 1.0, 1.0, _display_color.a)
	)
	_draw_jelly_face()
	if _blast_armed:
		_draw_blast_rim(_radius * 0.96, _display_color)


func _draw_jelly_face() -> void:
	var level_index: int = _jelly_level - 1
	var eye_size: float = clampf(3.8 + float(level_index) * 0.75, 3.8, 7.6)
	var eye_y: float = -0.12 * _radius
	var spacing: float = 0.30 * _radius
	if _jelly_level >= 7:
		for sign_value: float in [-1.0, 1.0]:
			draw_arc(
				Vector2(sign_value * spacing, eye_y + 2.0),
				eye_size + 2.5,
				PI + 0.22,
				TAU - 0.22,
				18,
				JELLY_FACE_COLOR,
				4.0,
				true
			)
		draw_circle(
			Vector2(-0.48 * _radius, 0.11 * _radius),
			7.5,
			Color(1.0, 0.373, 0.529, 0.52 * _display_color.a)
		)
		draw_circle(
			Vector2(0.48 * _radius, 0.11 * _radius),
			7.5,
			Color(1.0, 0.373, 0.529, 0.52 * _display_color.a)
		)
		draw_arc(
			Vector2(0.0, 0.12 * _radius),
			0.105 * _radius,
			0.16,
			PI - 0.16,
			18,
			JELLY_FACE_COLOR,
			4.0,
			true
		)
		return
	var blink: bool = sin(_planet_animation_elapsed * 2.35 + float(_jelly_color_index) * 0.91) > 0.985
	var half_width: float = eye_size * 0.72
	var half_height: float = eye_size * lerpf(1.08, 1.42, float(level_index) / 6.0)
	for sign_value: float in [-1.0, 1.0]:
		var center: Vector2 = Vector2(sign_value * spacing, eye_y)
		if blink:
			draw_line(
				center - Vector2(eye_size, 0.0),
				center + Vector2(eye_size, 0.0),
				JELLY_FACE_COLOR,
				3.0,
				true
			)
		else:
			_draw_jelly_capsule_eye(center, half_width, half_height)
			draw_circle(
				center + Vector2(-0.28 * half_width, -0.40 * half_height),
				maxf(1.0, 0.27 * half_width),
				Color(1.0, 1.0, 1.0, 0.88 * _display_color.a)
			)


func _draw_jelly_capsule_eye(
	center: Vector2,
	half_width: float,
	half_height: float
) -> void:
	var inner_height: float = maxf(0.0, half_height - half_width)
	draw_rect(
		Rect2(
			center.x - half_width,
			center.y - inner_height,
			half_width * 2.0,
			inner_height * 2.0
		),
		JELLY_FACE_COLOR,
		true
	)
	draw_circle(center - Vector2(0.0, inner_height), half_width, JELLY_FACE_COLOR)
	draw_circle(center + Vector2(0.0, inner_height), half_width, JELLY_FACE_COLOR)


func _draw_celestial() -> void:
	var alpha: float = _display_color.a
	var base: Color = _display_color
	base.a = alpha
	var body_radius: float = _radius * CelestialOrbArt.body_radius_ratio(_celestial_level)
	if _celestial_level >= 6:
		_draw_planet_halo(_radius, body_radius, base, _celestial_level == 7)
	_draw_planet_body(body_radius, base)
	_draw_spherical_lighting(body_radius, base, false)

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
		if _celestial_level == 4 or _celestial_level == 5:
			_draw_blast_rim(body_radius, base)


func _draw_planet_body(radius: float, base: Color) -> void:
	draw_circle(Vector2.ZERO, radius, _with_alpha(base.darkened(0.08), base.a))
	var detail: bool = _celestial_level >= 3
	var phase: float = _planet_animation_elapsed if _celestial_level >= 6 else 0.0
	match _symbol_color:
		OrbTypes.OrbColor.RED:
			_draw_mars(radius, base, detail, phase)
		OrbTypes.OrbColor.BLUE:
			_draw_earth(radius, base, detail, phase)
		OrbTypes.OrbColor.GREEN:
			_draw_uranus(radius, base, detail, phase)
		OrbTypes.OrbColor.YELLOW:
			_draw_venus(radius, base, detail, phase)
		OrbTypes.OrbColor.PURPLE:
			_draw_neptune(radius, base, detail, phase)
		OrbTypes.OrbColor.CYAN:
			_draw_mercury(radius, base, detail, phase)


func _draw_mars(radius: float, base: Color, detail: bool, phase: float) -> void:
	var dust_shift: float = sin(phase * 0.22) * radius * 0.04
	if detail:
		_draw_soft_ellipse(
			Vector2(-0.27, 0.18) * radius + Vector2(dust_shift, 0.0),
			Vector2(0.36, 0.20) * radius,
			-0.24,
			_with_alpha(base.darkened(0.30), 0.42 * base.a)
		)
		_draw_soft_ellipse(
			Vector2(0.34, -0.30) * radius + Vector2(dust_shift * 0.6, 0.0),
			Vector2(0.23, 0.15) * radius,
			0.38,
			_with_alpha(Color("#7D3025"), 0.38 * base.a)
		)
		var canyon: Color = _with_alpha(Color("#873B30"), 0.62 * base.a)
		var canyon_points: PackedVector2Array = PackedVector2Array([
			Vector2(-0.50, 0.05) * radius,
			Vector2(-0.35, 0.09) * radius,
			Vector2(-0.18, 0.12) * radius,
			Vector2(-0.02, 0.17) * radius,
			Vector2(0.17, 0.20) * radius,
			Vector2(0.34, 0.25) * radius,
			Vector2(0.50, 0.31) * radius,
		])
		var canyon_widths: Array[float] = [0.032, 0.052, 0.043, 0.064, 0.048, 0.026]
		var canyon_alphas: Array[float] = [0.30, 0.72, 1.0, 0.88, 0.62, 0.26]
		for segment_index: int in range(canyon_points.size() - 1):
			draw_line(
				canyon_points[segment_index],
				canyon_points[segment_index + 1],
				_with_alpha(canyon, canyon.a * canyon_alphas[segment_index]),
				maxf(1.0, radius * canyon_widths[segment_index]),
				true
			)
		var canyon_branch: PackedVector2Array = PackedVector2Array([
			Vector2(-0.15, 0.13) * radius,
			Vector2(-0.25, 0.01) * radius,
			Vector2(-0.36, -0.06) * radius,
		])
		draw_line(
			canyon_branch[0],
			canyon_branch[1],
			_with_alpha(canyon, canyon.a * 0.72),
			maxf(1.0, radius * 0.040),
			true
		)
		draw_line(
			canyon_branch[1],
			canyon_branch[2],
			_with_alpha(canyon, canyon.a * 0.28),
			maxf(1.0, radius * 0.024),
			true
		)
		var crater_centers: Array[Vector2] = [
			Vector2(-0.50, -0.34),
			Vector2(0.18, -0.51),
			Vector2(0.44, 0.08),
			Vector2(-0.13, 0.52),
		]
		var crater_radii: Array[Vector2] = [
			Vector2(0.052, 0.040),
			Vector2(0.078, 0.054),
			Vector2(0.043, 0.032),
			Vector2(0.064, 0.046),
		]
		var crater_rotations: Array[float] = [
			0.18,
			-0.27,
			0.42,
			-0.12,
		]
		for crater_index: int in range(crater_centers.size()):
			_draw_soft_ellipse(
				crater_centers[crater_index] * radius,
				crater_radii[crater_index] * radius,
				crater_rotations[crater_index],
				_with_alpha(base.darkened(0.42), 0.58 * base.a)
			)
	_draw_mars_polar_cap(
		radius,
		_with_alpha(Color("#F2ECE4"), 0.86 * base.a)
	)


func _draw_mars_polar_cap(radius: float, color_value: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	const POINT_COUNT: int = 32
	for point_index: int in range(POINT_COUNT + 1):
		var progress: float = float(point_index) / float(POINT_COUNT)
		var angle: float = progress * TAU
		var x: float = cos(angle)
		var boundary_noise: float = (
			sin(x * 10.0 + 0.35) * 0.024
			+ sin(x * 21.0 - 0.80) * 0.016
		)
		points.append(Vector2(
			x * 0.36,
			-0.60 + sin(angle) * 0.20 + boundary_noise
		) * radius)
	draw_colored_polygon(points, color_value)


func _draw_earth(radius: float, base: Color, detail: bool, phase: float) -> void:
	var land: Color = _with_alpha(Color("#287A50"), 0.90 * base.a)
	_draw_organic_blob(
		Vector2(-0.24, -0.04) * radius,
		Vector2(0.40, 0.50) * radius,
		-0.28,
		land,
		0.4
	)
	if detail:
		_draw_organic_blob(
			Vector2(0.36, 0.17) * radius,
			Vector2(0.28, 0.25) * radius,
			0.34,
			land,
			2.1
		)
		_draw_organic_blob(
			Vector2(0.19, -0.48) * radius,
			Vector2(0.16, 0.12) * radius,
			-0.16,
			land,
			4.3
		)
	var cloud: Color = _with_alpha(Color("#F4FAFF"), 0.70 * base.a)
	var cloud_shift: float = sin(phase * 0.32) * radius * 0.09
	draw_arc(Vector2(cloud_shift, -radius * 0.18), radius * 0.72, 3.48, 5.62, 32, cloud, maxf(1.2, radius * 0.060), true)
	if detail:
		draw_arc(Vector2(-cloud_shift, radius * 0.24), radius * 0.60, 0.34, 2.72, 30, cloud, maxf(1.0, radius * 0.045), true)
		draw_arc(Vector2(radius * 0.17 + cloud_shift * 0.4, -radius * 0.02), radius * 0.34, -1.34, 1.28, 22, _with_alpha(cloud, 0.56 * base.a), maxf(0.8, radius * 0.032), true)


func _draw_uranus(radius: float, base: Color, detail: bool, phase: float) -> void:
	var band_color: Color = _with_alpha(base.lightened(0.05), 0.34 * base.a)
	var shift: float = sin(phase * 0.26) * radius * 0.025
	for band: int in range(-1, 2):
		var y: float = float(band) * radius * 0.32 + shift
		var half_width: float = sqrt(maxf(radius * radius - y * y, 0.0)) * 0.84
		_draw_soft_ellipse(
			Vector2(0.0, y),
			Vector2(half_width, radius * 0.105),
			0.0,
			band_color
		)
	draw_arc(
		Vector2.ZERO,
		radius * 0.93,
		0.0,
		TAU,
		48,
		_with_alpha(base.lightened(0.12), 0.44 * base.a),
		maxf(1.0, radius * 0.045),
		true
	)
	if detail:
		_draw_tilted_atmosphere_ring(
			radius,
			_with_alpha(Color("#E3FFF3"), 0.72 * base.a)
		)


func _draw_soft_ellipse(
	center: Vector2,
	radii: Vector2,
	rotation_value: float,
	color_value: Color
) -> void:
	draw_set_transform(center, rotation_value, radii)
	draw_circle(Vector2.ZERO, 1.0, color_value)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_organic_blob(
	center: Vector2,
	radii: Vector2,
	rotation_value: float,
	color_value: Color,
	seed_phase: float
) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for point_index: int in range(32):
		var angle: float = TAU * float(point_index) / 32.0
		var coast: float = (
			1.0
			+ sin(angle * 3.0 + seed_phase) * 0.075
			+ sin(angle * 5.0 - seed_phase * 0.7) * 0.045
			+ sin(angle * 7.0 + seed_phase * 1.3) * 0.024
		)
		var local_point: Vector2 = Vector2(
			cos(angle) * radii.x,
			sin(angle) * radii.y
		) * coast
		points.append(center + local_point.rotated(rotation_value))
	draw_colored_polygon(points, color_value)


func _draw_tilted_atmosphere_ring(radius: float, color_value: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for point_index: int in range(49):
		var angle: float = TAU * float(point_index) / 48.0
		var point: Vector2 = Vector2(
			cos(angle) * radius * 0.79,
			sin(angle) * radius * 0.30
		).rotated(-CelestialOrbArt.RING_TILT_RADIANS)
		points.append(point)
	draw_polyline(points, color_value, maxf(1.0, radius * 0.035), true)


func _draw_venus(radius: float, base: Color, detail: bool, phase: float) -> void:
	var cloud: Color = _with_alpha(base.lightened(0.34), 0.76 * base.a)
	var shift: float = sin(phase * 0.30) * radius * 0.05
	for band: int in [-1, 1]:
		_draw_body_band(radius, float(band) * radius * 0.28 + shift, cloud, true)
	if detail:
		_draw_body_band(radius, -shift, base, false)
		draw_arc(Vector2(radius * 0.14, 0.0), radius * 0.55, -1.10, 1.52, 22, cloud, maxf(1.0, radius * 0.055), true)


func _draw_neptune(radius: float, base: Color, detail: bool, phase: float) -> void:
	var wind: Color = _with_alpha(base.lightened(0.34), 0.72 * base.a)
	var y: float = sin(phase * 0.25) * radius * 0.06
	_draw_body_band(radius, y - radius * 0.18, base, true)
	if detail:
		_draw_body_band(radius, y + radius * 0.24, base, false)
		draw_circle(Vector2(0.39, 0.15) * radius, radius * 0.17, _with_alpha(base.darkened(0.62), 0.90 * base.a))
		draw_arc(Vector2(0.39, 0.15) * radius, radius * 0.17, 0.0, TAU, 22, wind, maxf(1.0, radius * 0.028), true)


func _draw_mercury(radius: float, base: Color, detail: bool, phase: float) -> void:
	var reflection: float = 0.10 + 0.06 * sin(phase * 0.62)
	draw_circle(Vector2(-0.30, -0.22) * radius, radius * 0.22, _with_alpha(base.darkened(0.38), 0.78 * base.a))
	draw_circle(Vector2(0.34, 0.18) * radius, radius * 0.16, _with_alpha(base.darkened(0.46), 0.76 * base.a))
	draw_circle(Vector2(-0.02, 0.48) * radius, radius * 0.11, _with_alpha(base.darkened(0.34), 0.72 * base.a))
	if detail:
		draw_circle(Vector2(0.18, -0.52) * radius, radius * 0.08, _with_alpha(base.darkened(0.44), 0.70 * base.a))
	draw_circle(Vector2(-0.28, -0.31) * radius, radius * 0.24, _with_alpha(Color.WHITE, reflection * base.a))


func _draw_planet_halo(radius: float, body_radius: float, base: Color, legendary: bool) -> void:
	var ring_count: int = 5 if legendary else 3
	var twinkle: float = 0.88 + 0.12 * sin(_planet_animation_elapsed * (1.24 if legendary else 0.62))
	for index: int in range(ring_count, 0, -1):
		var progress: float = float(index) / float(ring_count)
		var halo_radius: float = lerpf(body_radius, radius * 0.98, progress)
		var halo_alpha: float = (0.09 if legendary else 0.045) * (1.15 - progress * 0.42) * twinkle
		draw_circle(Vector2.ZERO, halo_radius, _with_alpha(base.lightened(0.26 if legendary else 0.12), halo_alpha * base.a))
	if legendary:
		var ray_color: Color = _with_alpha(base.lightened(0.48), 0.34 * twinkle * base.a)
		draw_line(Vector2(-radius * 0.98, 0.0), Vector2(radius * 0.98, 0.0), ray_color, maxf(1.0, radius * 0.022), true)
		draw_line(Vector2(0.0, -radius * 0.98), Vector2(0.0, radius * 0.98), ray_color, maxf(1.0, radius * 0.022), true)


func _draw_meteor(radius: float, base: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var factors: Array[float] = [0.92, 1.04, 0.91, 1.01, 0.93, 1.05, 0.94, 1.06, 0.91, 1.02, 0.92, 1.04]
	for index: int in range(factors.size()):
		var angle: float = -PI * 0.5 + TAU * float(index) / float(factors.size())
		points.append(Vector2(cos(angle), sin(angle)) * radius * factors[index])
	draw_colored_polygon(points, _with_alpha(base.darkened(0.54), base.a))
	var spot_color: Color = _with_alpha(base.darkened(0.72), 0.70 * base.a)
	draw_circle(Vector2(-0.34, -0.22) * radius, radius * 0.19, spot_color)
	draw_circle(Vector2(0.35, 0.25) * radius, radius * 0.14, spot_color)
	draw_circle(Vector2(0.18, -0.48) * radius, radius * 0.09, spot_color)
	draw_circle(Vector2(-0.46, 0.42) * radius, radius * 0.08, spot_color)
	var scratch_color: Color = _with_alpha(base.lightened(0.18), 0.34 * base.a)
	draw_line(
		Vector2(-0.10, -0.14) * radius,
		Vector2(0.20, 0.04) * radius,
		scratch_color,
		maxf(0.8, radius * 0.026),
		true
	)
	draw_line(
		Vector2(-0.48, 0.16) * radius,
		Vector2(-0.30, 0.34) * radius,
		scratch_color,
		maxf(0.7, radius * 0.022),
		true
	)


func _draw_moon(radius: float, base: Color) -> void:
	draw_circle(Vector2.ZERO, radius, _with_alpha(base.lightened(0.17), base.a))
	var crater_color: Color = _with_alpha(base.darkened(0.33), 0.72 * base.a)
	draw_circle(Vector2(-0.30, -0.22) * radius, radius * 0.22, crater_color)
	draw_circle(Vector2(0.34, 0.18) * radius, radius * 0.16, crater_color)
	draw_circle(Vector2(-0.02, 0.48) * radius, radius * 0.11, crater_color)
	draw_circle(Vector2(0.14, -0.51) * radius, radius * 0.08, crater_color)
	var crater_rim: Color = _with_alpha(base.lightened(0.28), 0.45 * base.a)
	draw_arc(Vector2(-0.30, -0.22) * radius, radius * 0.22, 0.0, TAU, 28, crater_rim, maxf(1.0, radius * 0.025), true)
	draw_arc(Vector2(0.34, 0.18) * radius, radius * 0.16, PI, TAU, 20, crater_rim, maxf(1.0, radius * 0.022), true)


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
	draw_circle(
		Vector2.ZERO,
		radius,
		_with_alpha(base.lightened(0.46 if solar else 0.12), base.a)
	)
	var cell_color: Color = _with_alpha(
		Color.WHITE.lerp(base.lightened(0.58), 0.34 if solar else 0.58),
		(0.82 if solar else 0.62) * base.a
	)
	var cell_count: int = 13 if solar else 7
	for index: int in range(cell_count):
		var angle: float = TAU * float(index) / float(cell_count) + float(index % 3) * 0.21
		var distance: float = radius * (0.28 + 0.36 * float((index * 7) % 5) / 4.0)
		var cell_radius: float = radius * (0.07 + 0.025 * float(index % 3))
		var cell_position: Vector2 = Vector2(cos(angle), sin(angle)) * distance
		if solar:
			_draw_elliptic_cell(
				cell_position,
				cell_radius,
				angle + PI * 0.32,
				cell_color
			)
		else:
			draw_circle(cell_position, cell_radius, cell_color)
	if solar:
		draw_circle(Vector2(-0.08, -0.10) * radius, radius * 0.46, _with_alpha(Color.WHITE, 0.38 * base.a))
		draw_circle(Vector2(-0.10, -0.12) * radius, radius * 0.20, _with_alpha(Color.WHITE, 0.42 * base.a))
	else:
		draw_circle(Vector2(-0.10, -0.12) * radius, radius * 0.52, _with_alpha(Color.WHITE, 0.40 * base.a))
		draw_circle(Vector2(-0.12, -0.14) * radius, radius * 0.25, _with_alpha(Color.WHITE, 0.34 * base.a))


func _draw_planet_ring(radius: float, base: Color, front: bool) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var start_angle: float = 0.0 if front else PI
	for index: int in range(34):
		var angle: float = start_angle + PI * float(index) / 33.0
		var point: Vector2 = Vector2(cos(angle) * radius * 0.98, sin(angle) * radius * 0.27)
		points.append(point.rotated(CelestialOrbArt.RING_TILT_RADIANS))
	var layer_alpha: float = 0.96 if front else 0.48
	draw_polyline(points, _with_alpha(base.darkened(0.28), layer_alpha * base.a), maxf(2.0, radius * 0.085), true)
	draw_polyline(points, _with_alpha(base.lightened(0.35), layer_alpha * base.a), maxf(1.0, radius * 0.038), true)


func _draw_halo(
	radius: float,
	body_radius: float,
	base: Color,
	solar: bool,
	pulse: float
) -> void:
	var ring_count: int = 5 if solar else 4
	var pulse_scale: float = lerpf(0.94, 1.0, pulse) if pulse > 0.0 else 0.96
	for index: int in range(ring_count, 0, -1):
		var progress: float = float(index) / float(ring_count)
		var halo_radius: float = lerpf(body_radius, radius * pulse_scale, progress)
		var halo_alpha: float = (
			0.07 + 0.10 * (1.0 - progress) + pulse * 0.10 * (1.0 - progress * 0.45)
		) * base.a
		draw_circle(Vector2.ZERO, halo_radius, _with_alpha(base, halo_alpha))
	if solar:
		var slow_drift: float = _blast_blink_elapsed * 0.22
		var flare_angles: Array[float] = [
			-2.36 + sin(slow_drift) * 0.055,
			-0.38 + cos(slow_drift * 0.83) * 0.045,
			1.30 + sin(slow_drift * 0.71) * 0.050,
		]
		var flare_widths: Array[float] = [0.085, 0.125, 0.100]
		var flare_heights: Array[float] = [0.16, 0.25, 0.20]
		for index: int in range(flare_angles.size()):
			_draw_prominence_loop(
				body_radius,
				radius,
				flare_angles[index],
				flare_widths[index],
				flare_heights[index],
				_with_alpha(
					Color.WHITE.lerp(base.lightened(0.54), 0.38),
					(0.48 + pulse * 0.14) * base.a
				)
			)
	else:
		var ray_color: Color = _with_alpha(base.lightened(0.38), (0.26 + pulse * 0.22) * base.a)
		draw_line(Vector2(-radius * pulse_scale, 0.0), Vector2(radius * pulse_scale, 0.0), ray_color, maxf(1.0, radius * 0.022), true)
		draw_line(Vector2(0.0, -radius * pulse_scale), Vector2(0.0, radius * pulse_scale), ray_color, maxf(1.0, radius * 0.022), true)


func _draw_elliptic_cell(
	position_value: Vector2,
	radius: float,
	rotation_value: float,
	color_value: Color
) -> void:
	draw_set_transform(position_value, rotation_value, Vector2(1.65, 0.62))
	draw_circle(Vector2.ZERO, radius, color_value)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_prominence_loop(
	body_radius: float,
	halo_radius: float,
	angle: float,
	width_ratio: float,
	height_ratio: float,
	color_value: Color
) -> void:
	var radial: Vector2 = Vector2(cos(angle), sin(angle))
	var tangent: Vector2 = radial.orthogonal()
	var points: PackedVector2Array = PackedVector2Array()
	for point_index: int in range(25):
		var t: float = PI * float(point_index) / 24.0
		points.append(
			radial * (body_radius * 0.91 + sin(t) * halo_radius * height_ratio)
			+ tangent * cos(t) * halo_radius * width_ratio
		)
	for point_index: int in range(points.size() - 1):
		var segment_progress: float = (float(point_index) + 0.5) / float(points.size() - 1)
		var taper: float = pow(sin(segment_progress * PI), 0.72)
		draw_line(
			points[point_index],
			points[point_index + 1],
			_with_alpha(color_value, color_value.a * taper),
			maxf(0.7, halo_radius * lerpf(0.008, 0.022, taper)),
			true
		)


func _draw_spherical_lighting(radius: float, base: Color, luminous: bool) -> void:
	if luminous:
		draw_arc(
			Vector2.ZERO,
			radius * 0.86,
			-0.20,
			PI * 0.82,
			32,
			_with_alpha(base.darkened(0.36), 0.28 * base.a),
			maxf(1.5, radius * 0.13),
			true
		)
		return
	draw_arc(
		Vector2.ZERO,
		radius * 0.84,
		-0.18,
		PI * 0.82,
		32,
		_with_alpha(Color.BLACK, 0.30 * base.a),
		maxf(2.0, radius * 0.20),
		true
	)
	draw_arc(
		Vector2.ZERO,
		radius * 0.92,
		PI * 0.92,
		PI * 1.65,
		26,
		_with_alpha(base.lightened(0.44), 0.52 * base.a),
		maxf(1.5, radius * 0.055),
		true
	)
	if _celestial_level >= 2:
		draw_circle(
			Vector2(-0.34, -0.36) * radius,
			radius * 0.11,
			_with_alpha(Color.WHITE, 0.20 * base.a)
		)


func _draw_blast_rim(radius: float, base: Color) -> void:
	var pulse: float = blast_brightness()
	for index: int in range(3):
		var inset: float = float(index) * radius * 0.025
		var alpha: float = pulse * (0.34 - float(index) * 0.08) * base.a
		draw_arc(
			Vector2.ZERO,
			radius - inset,
			0.0,
			TAU,
			64,
			_with_alpha(base.lightened(0.40), alpha),
			maxf(1.0, radius * (0.055 + float(index) * 0.02)),
			true
		)


func _draw_body_band(
	radius: float,
	y: float,
	base: Color,
	bright: bool
) -> void:
	var half_width: float = sqrt(maxf(radius * radius - y * y, 0.0)) * 0.96
	var color_value: Color = base.lightened(0.25) if bright else base.darkened(0.28)
	color_value.a = 0.78 * base.a
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(17):
		var ratio: float = -1.0 + 2.0 * float(index) / 16.0
		var curve_direction: float = 1.0 if y >= 0.0 else -1.0
		var curve: float = (1.0 - ratio * ratio) * radius * 0.055 * curve_direction
		var turbulence: float = sin(ratio * 8.0 + y * 0.11) * radius * 0.012
		points.append(Vector2(ratio * half_width, y + curve + turbulence))
	draw_polyline(points, color_value, maxf(2.0, radius * 0.105), true)


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
	var symbol_offset: Vector2 = Vector2.ZERO
	if _jelly_level > 0:
		scale_factor *= 0.42
		symbol_offset = Vector2(0.0, _radius * 0.54)
	for normalized_polygon: PackedVector2Array in _symbol_polygons:
		var scaled_polygon: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in normalized_polygon:
			scaled_polygon.append(point * scale_factor + symbol_offset)
		if _celestial_level > 0 or _jelly_level > 0:
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
	set_process(
		_waiting_at_entrance
		or _blast_armed
		or _celestial_level >= 6
		or _jelly_level > 0
	)
