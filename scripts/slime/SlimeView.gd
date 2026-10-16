class_name SlimeView
extends Node2D

const GRID_STEP: float = 40.0
const TEXTURE_SIZE: int = 384
const BOARD_FILL: Color = Color("111a38")
const BOARD_BORDER: Color = Color("5b72b8")
const GRID_COLOR: Color = Color(0.2, 0.3, 0.55, 0.10)
const ENTRY_SAFE: Color = Color("55e0bc")
const ENTRY_CAUTION: Color = Color("ffd166")
const ENTRY_DANGER: Color = Color("ff5878")
const ENTRY_BASE: Color = Color(0.02, 0.03, 0.08, 0.9)
const FACE_COLOR: Color = Color("17203c")
const POPUP_COLOR: Color = Color("fff4b5")
const GRAVITY_FLASH_COLOR: Color = Color("8ec8ff")
const POPUP_FONT: FontFile = preload("res://assets/fonts/NotoSansKR-Medium-KSX1001.ttf")

static var _material_textures: Dictionary = {}
static var _cache_users: int = 0

var _sim: SlimeSim
var _effects: Array[Dictionary] = []
var _registered_cache_user: bool = false


func bind(simulation: SlimeSim) -> void:
	_sim = simulation
	if not _registered_cache_user:
		_registered_cache_user = true
		_cache_users += 1
	queue_redraw()


func _exit_tree() -> void:
	if not _registered_cache_user:
		return
	_registered_cache_user = false
	_cache_users = maxi(0, _cache_users - 1)
	if _cache_users == 0:
		_material_textures.clear()


func refresh() -> void:
	queue_redraw()


func handle_events(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		var event_type: String = str(event.get("type", ""))
		if event_type == "absorbed":
			_add_reaction_effect(event, false)
		elif event_type == "max_clear":
			_add_reaction_effect(event, true)


func advance_visuals(delta: float) -> void:
	var index: int = _effects.size() - 1
	while index >= 0:
		var particles: Array = _effects[index].get("particles", []) as Array
		for particle_variant: Variant in particles:
			var particle: Dictionary = particle_variant as Dictionary
			particle["position"] = (particle.get("position", Vector2.ZERO) as Vector2) + (particle.get("velocity", Vector2.ZERO) as Vector2) * delta
			particle["velocity"] = (particle.get("velocity", Vector2.ZERO) as Vector2) * pow(0.90, delta * 60.0)
		_effects[index]["age"] = float(_effects[index].get("age", 0.0)) + delta
		if float(_effects[index]["age"]) >= 0.86:
			_effects.remove_at(index)
		index -= 1


func active_effect_count() -> int:
	return _effects.size()


func entry_bar_half_length(direction: Vector2i) -> float:
	return 35.0 if direction == _sim.gravity_direction else 27.0


static func material_texture(config: SlimeConfig, color_index: int, level_value: int) -> Texture2D:
	var safe_color: int = clampi(color_index, 0, config.slime_colors.size() - 1)
	var safe_level: int = clampi(level_value, 0, config.radii.size() - 1)
	var key: String = "%s:%d:%d" % [config.resource_path, safe_color, safe_level]
	if _material_textures.has(key):
		return _material_textures[key] as Texture2D
	var base_color: Color = config.slime_colors[safe_color].lightened(float(safe_level) * config.level_lighten)
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var light := Vector3(-0.20, -0.86, 0.48).normalized()
	var half := (light + Vector3(0.0, 0.0, 1.0)).normalized()
	for y: int in range(TEXTURE_SIZE):
		var unit_y: float = (float(y) + 0.5) / float(TEXTURE_SIZE) * 2.0 - 1.0
		for x: int in range(TEXTURE_SIZE):
			var unit_x: float = (float(x) + 0.5) / float(TEXTURE_SIZE) * 2.0 - 1.0
			var radial_squared: float = unit_x * unit_x + unit_y * unit_y
			if radial_squared >= 1.0:
				image.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var z: float = sqrt(1.0 - radial_squared)
			var normal := Vector3(unit_x, unit_y, z)
			var diffuse: float = maxf(0.0, normal.dot(light))
			var half_dot: float = maxf(0.0, normal.dot(half))
			var specular: float = pow(half_dot, 72.0)
			var broad: float = pow(half_dot, 11.0)
			var rim: float = pow(1.0 - z, 2.2)
			var scatter: float = maxf(0.0, unit_y) * (1.0 - z) * 0.15
			var illumination: float = 0.60 + diffuse * 0.34 + broad * 0.055
			image.set_pixel(x, y, Color(
				clampf(base_color.r * illumination + specular * 0.62 + rim * base_color.r * 0.10 + scatter * base_color.r, 0.0, 1.0),
				clampf(base_color.g * illumination + specular * 0.66 + rim * base_color.g * 0.11 + scatter * base_color.g, 0.0, 1.0),
				clampf(base_color.b * illumination + specular * 0.72 + rim * base_color.b * 0.13 + scatter * base_color.b, 0.0, 1.0),
				clampf((1.0 - sqrt(radial_squared)) * float(TEXTURE_SIZE) * 0.52, 0.0, 1.0)
			))
	var texture := ImageTexture.create_from_image(image)
	_material_textures[key] = texture
	return texture


func _draw() -> void:
	if _sim == null:
		return
	var board: Rect2 = _sim.config.board_rect
	_draw_board(board)
	_draw_gravity_transition(board)
	_draw_merge_trails()
	_draw_speed_trails()
	for slime: SlimeSim.SlimeBody in _sim.slimes:
		_draw_shadow(slime)
	for slime: SlimeSim.SlimeBody in _sim.slimes:
		_draw_slime(slime)
	_draw_reaction_effects()
	if not _sim.moving and not _sim.game_over:
		_draw_entry_bars(board)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_board(board: Rect2) -> void:
	draw_rect(board, BOARD_FILL, true)
	draw_rect(board, BOARD_BORDER, false, 4.0)
	var x: float = board.position.x + GRID_STEP
	while x < board.end.x:
		draw_line(Vector2(x, board.position.y), Vector2(x, board.end.y), GRID_COLOR, 1.0)
		x += GRID_STEP
	var y: float = board.position.y + GRID_STEP
	while y < board.end.y:
		draw_line(Vector2(board.position.x, y), Vector2(board.end.x, y), GRID_COLOR, 1.0)
		y += GRID_STEP


func _draw_gravity_transition(board: Rect2) -> void:
	if _sim.gravity_flash_left <= 0.0:
		return
	var progress: float = 1.0 - _sim.gravity_flash_left / _sim.config.gravity_flash_duration
	var color := Color(GRAVITY_FLASH_COLOR, sin(clampf(progress, 0.0, 1.0) * PI) * 0.22)
	var gravity := Vector2(_sim.gravity_direction)
	var side := Vector2(-gravity.y, gravity.x)
	var center: Vector2 = board.get_center()
	var start: Vector2 = center - gravity * 88.0
	var end: Vector2 = center + gravity * 88.0
	draw_line(start, end, color, 5.0, true)
	var tip: Vector2 = end + gravity * 21.0
	var base: Vector2 = end - gravity * 6.0
	draw_colored_polygon(PackedVector2Array([tip, base + side * 16.0, base - side * 16.0]), color)
	var wall_from: Vector2
	var wall_to: Vector2
	if _sim.gravity_direction == Vector2i.DOWN:
		wall_from = board.position + Vector2(0.0, board.size.y)
		wall_to = board.end
	elif _sim.gravity_direction == Vector2i.UP:
		wall_from = board.position
		wall_to = Vector2(board.end.x, board.position.y)
	elif _sim.gravity_direction == Vector2i.RIGHT:
		wall_from = Vector2(board.end.x, board.position.y)
		wall_to = board.end
	else:
		wall_from = board.position
		wall_to = Vector2(board.position.x, board.end.y)
	draw_line(wall_from, wall_to, color, 5.0, true)


func _draw_entry_bars(board: Rect2) -> void:
	_draw_entry_bar(Vector2i.DOWN, Vector2(board.get_center().x, board.position.y + 2.0), Vector2.RIGHT)
	_draw_entry_bar(Vector2i.UP, Vector2(board.get_center().x, board.end.y - 2.0), Vector2.RIGHT)
	_draw_entry_bar(Vector2i.RIGHT, Vector2(board.position.x + 2.0, board.get_center().y), Vector2.DOWN)
	_draw_entry_bar(Vector2i.LEFT, Vector2(board.end.x - 2.0, board.get_center().y), Vector2.DOWN)


func _draw_entry_bar(direction: Vector2i, center: Vector2, axis: Vector2) -> void:
	var half_length: float = entry_bar_half_length(direction)
	var from: Vector2 = center - axis * half_length
	var to: Vector2 = center + axis * half_length
	draw_line(from, to, ENTRY_BASE, 10.0, true)
	draw_line(from, to, _stage_color(_sim.entry_stage_for(direction)), 6.0, true)


func _draw_merge_trails() -> void:
	for effect: Dictionary in _effects:
		var age: float = float(effect.get("age", 0.0))
		if age >= 0.36:
			continue
		var progress: float = smoothstep(0.0, 1.0, age / 0.36)
		var center: Vector2 = effect.get("position", Vector2.ZERO) as Vector2
		var source_radius: float = maxf(float(effect.get("source_a_radius", 0.0)), float(effect.get("source_b_radius", 0.0)))
		var radius: float = source_radius * lerpf(1.0, 0.04, progress)
		var alpha: float = (1.0 - progress) * 0.78
		var color_a: Color = effect.get("color_a", Color.WHITE) as Color
		var color_b: Color = effect.get("color_b", color_a) as Color
		var source_a: Vector2 = effect.get("source_a_position", center) as Vector2
		var source_b: Vector2 = effect.get("source_b_position", center) as Vector2
		draw_circle(source_a.lerp(center, progress), radius, Color(color_a, alpha))
		draw_circle(source_b.lerp(center, progress), radius, Color(color_b, alpha))


func _draw_speed_trails() -> void:
	if not _sim.moving:
		return
	for slime: SlimeSim.SlimeBody in _sim.slimes:
		var speed: float = slime.velocity.length()
		if speed <= 190.0:
			continue
		var direction: Vector2 = slime.velocity / speed
		var side := Vector2(-direction.y, direction.x)
		var length: float = clampf(speed * 0.045, 12.0, 52.0)
		var alpha: float = clampf((speed - 190.0) / 950.0, 0.0, 0.16)
		var color: Color = _slime_color(slime.color_index, slime.level)
		for lane: int in range(-1, 2):
			var start: Vector2 = slime.position - direction * slime.radius * 0.58 + side * float(lane) * slime.radius * 0.28
			draw_line(start, start - direction * length, Color(color, alpha), 2.5 if lane == 0 else 1.5, true)


func _draw_shadow(slime: SlimeSim.SlimeBody) -> void:
	var radius: float = slime.radius * slime.visual_scale
	var draw_position: Vector2 = slime.position
	var stretch: Vector2 = slime.deform
	if not _sim.moving:
		draw_position -= Vector2(_sim.gravity_direction) * sin(slime.idle_phase) * 1.8
		var breathe: float = sin(slime.idle_phase) * 0.018
		stretch *= Vector2(1.0 + breathe, 1.0 - breathe)
	var rotation_value: float = slime.rotation + slime.roll
	var offset := Vector2(0.06 * radius, 0.58 * radius).rotated(rotation_value)
	draw_set_transform(draw_position + offset, rotation_value, stretch * Vector2(1.0, 0.27))
	draw_circle(Vector2.ZERO, 0.70 * radius, Color(0.015, 0.02, 0.06, 0.27))


func _draw_slime(slime: SlimeSim.SlimeBody) -> void:
	var radius: float = slime.radius * slime.visual_scale
	var bob: Vector2 = Vector2.ZERO
	var breathing := Vector2.ONE
	if not _sim.moving:
		bob = -Vector2(_sim.gravity_direction) * sin(slime.idle_phase) * 1.8
		var breathe: float = sin(slime.idle_phase) * 0.018
		breathing = Vector2(1.0 + breathe, 1.0 - breathe)
	draw_set_transform(slime.position + bob, slime.rotation + slime.roll, slime.deform * breathing)
	draw_texture_rect(material_texture(_sim.config, slime.color_index, slime.level), Rect2(Vector2(-radius, -radius), Vector2.ONE * radius * 2.0), false)
	if slime.merge_glow > 0.0:
		draw_circle(Vector2.ZERO, radius * (0.72 + slime.merge_glow * 0.2), Color(1.0, 1.0, 1.0, slime.merge_glow * 0.55))
	_draw_face(radius, slime.level, slime.color_index, not _sim.moving, slime.idle_phase)


func _draw_face(radius: float, level_value: int, color_index: int, waiting: bool, idle_phase: float) -> void:
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
	var blink: bool = waiting and sin(idle_phase * 0.73 + float(color_index)) > 0.985
	var half_width: float = eye * 0.72
	var half_height: float = eye * lerpf(1.08, 1.42, float(level_value) / 6.0)
	for sign_value: float in [-1.0, 1.0]:
		var center := Vector2(sign_value * spacing, eye_y)
		if blink:
			draw_line(center - Vector2(eye, 0.0), center + Vector2(eye, 0.0), FACE_COLOR, 3.0, true)
		else:
			_draw_capsule_eye(center, half_width, half_height)
			draw_circle(center + Vector2(-0.28 * half_width, -0.40 * half_height), maxf(1.0, 0.27 * half_width), Color(1.0, 1.0, 1.0, 0.88))


func _draw_capsule_eye(center: Vector2, half_width: float, half_height: float) -> void:
	var inner_height: float = maxf(0.0, half_height - half_width)
	draw_rect(Rect2(center.x - half_width, center.y - inner_height, half_width * 2.0, inner_height * 2.0), FACE_COLOR, true)
	draw_circle(center - Vector2(0.0, inner_height), half_width, FACE_COLOR)
	draw_circle(center + Vector2(0.0, inner_height), half_width, FACE_COLOR)


func _draw_reaction_effects() -> void:
	for effect: Dictionary in _effects:
		var age: float = float(effect.get("age", 0.0))
		var center: Vector2 = effect.get("position", Vector2.ZERO) as Vector2
		var is_clear: bool = bool(effect.get("clear", false))
		var color_a: Color = effect.get("color_a", Color.WHITE) as Color
		var color_b: Color = effect.get("color_b", color_a) as Color
		var effect_color: Color = color_a.lerp(color_b, 0.5) if is_clear else color_a
		var power: float = 1.65 if is_clear else 1.0
		if age < 0.68:
			_draw_reaction_waves(center, age / 0.68, power, effect_color, color_a, color_b, is_clear)
		if age < 0.75:
			_draw_reaction_particles(effect, age, color_a, color_b, is_clear)
		if age < 0.86:
			var alpha: float = 1.0 - age / 0.86
			var label: String = "MAX CLEAR  +%d" % int(effect.get("gained_score", 0)) if is_clear else "+%d" % int(effect.get("gained_score", 0))
			draw_string(POPUP_FONT, center + Vector2(-110.0, -42.0 * age), label, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 20, Color(POPUP_COLOR, alpha))


func _draw_reaction_waves(center: Vector2, progress: float, power: float, effect_color: Color, color_a: Color, color_b: Color, is_clear: bool) -> void:
	var p: float = clampf(progress, 0.0, 1.0)
	draw_circle(center, lerpf(20.0, 7.0, p) * power, Color(1.0, 1.0, 1.0, minf(1.0, pow(1.0 - p, 3.0) * 0.72 * power)))
	draw_arc(center, lerpf(10.0, 94.0, p) * power, 0.0, TAU, 56, Color(effect_color.lightened(0.35), 1.0 - p), lerpf(8.0, 1.2, p) * power, true)
	var q: float = clampf((p - 0.14) / 0.86, 0.0, 1.0)
	draw_arc(center, lerpf(8.0, 70.0, q) * power, 0.0, TAU, 44, Color(effect_color.lightened(0.55), (1.0 - q) * 0.48), lerpf(4.5, 1.0, q) * power, true)
	if is_clear:
		var clear_radius: float = lerpf(16.0, 112.0, p) * power
		var clear_width: float = lerpf(6.0, 1.0, p)
		draw_arc(center, clear_radius, PI, TAU, 28, Color(color_a.lightened(0.30), 1.0 - p), clear_width, true)
		draw_arc(center, clear_radius, 0.0, PI, 28, Color(color_b.lightened(0.30), 1.0 - p), clear_width, true)


func _draw_reaction_particles(effect: Dictionary, age: float, color_a: Color, color_b: Color, is_clear: bool) -> void:
	var progress: float = age / 0.75
	var particles: Array = effect.get("particles", []) as Array
	for particle_variant: Variant in particles:
		var particle: Dictionary = particle_variant as Dictionary
		var color: Color = particle.get("color", color_a if not is_clear else color_a.lerp(color_b, 0.5)) as Color
		var size: float = float(particle.get("size", 1.0)) * (1.0 - 0.45 * progress)
		draw_circle(particle.get("position", Vector2.ZERO) as Vector2, size, Color(color, 1.0 - progress))


func _add_reaction_effect(event: Dictionary, is_clear: bool) -> void:
	var color_a_index: int = int(event.get("color_a", event.get("color", 0)))
	var color_b_index: int = int(event.get("color_b", color_a_index))
	var seed_value: int = int(event.get("tick", 0)) * 131 + _effects.size() * 977 + 1
	var particles: Array[Dictionary] = _create_particles(
		event.get("position", Vector2.ZERO) as Vector2,
		is_clear,
		_slime_color(color_a_index, 6 if is_clear else int(event.get("level", 0))),
		_slime_color(color_b_index, 6 if is_clear else int(event.get("level", 0))),
		seed_value
	)
	_effects.append({
		"age": 0.0,
		"clear": is_clear,
		"position": event.get("position", Vector2.ZERO),
		"source_a_position": event.get("source_a_position", event.get("position", Vector2.ZERO)),
		"source_b_position": event.get("source_b_position", event.get("position", Vector2.ZERO)),
		"source_a_radius": float(event.get("source_a_radius", 0.0)),
		"source_b_radius": float(event.get("source_b_radius", 0.0)),
		"color_a": _slime_color(color_a_index, 6 if is_clear else int(event.get("level", 0))),
		"color_b": _slime_color(color_b_index, 6 if is_clear else int(event.get("level", 0))),
		"gained_score": int(event.get("gained_score", 0)),
		"particles": particles,
	})


func _create_particles(center: Vector2, is_clear: bool, color_a: Color, color_b: Color, seed_value: int) -> Array[Dictionary]:
	var particles: Array[Dictionary] = []
	var count: int = 26 if is_clear else 14
	for index: int in range(count):
		var jitter_limit: float = 0.12 if is_clear else 0.16
		var angle: float = TAU * float(index) / float(count) + lerpf(-jitter_limit, jitter_limit, _unit_hash(seed_value + index * 17))
		var speed_min: float = 150.0 if is_clear else 90.0
		var speed_max: float = 360.0 if is_clear else 230.0
		var base: Color = color_a if not is_clear or index % 2 == 0 else color_b
		var lighten_min: float = 0.08 if is_clear else 0.0
		var lighten_max: float = 0.45 if is_clear else 0.35
		var size_min: float = 4.0 if is_clear else 2.5
		var size_max: float = 9.0 if is_clear else 6.0
		particles.append({
			"position": center,
			"velocity": Vector2.from_angle(angle) * lerpf(speed_min, speed_max, _unit_hash(seed_value + index * 31 + 7)),
			"color": base.lightened(lerpf(lighten_min, lighten_max, _unit_hash(seed_value + index * 43 + 13))),
			"size": lerpf(size_min, size_max, _unit_hash(seed_value + index * 59 + 19)),
		})
	return particles


func _slime_color(color_index: int, level_value: int) -> Color:
	var safe_color: int = clampi(color_index, 0, _sim.config.slime_colors.size() - 1)
	return _sim.config.slime_colors[safe_color].lightened(float(level_value) * _sim.config.level_lighten)


func _stage_color(stage: int) -> Color:
	if stage == 2:
		return ENTRY_DANGER
	if stage == 1:
		return ENTRY_CAUTION
	return ENTRY_SAFE


func _unit_hash(value: int) -> float:
	var mixed: int = (abs(value) * 1664525 + 1013904223) & 0x7fffffff
	return float(mixed % 65536) / 65535.0
