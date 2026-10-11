class_name OrbitStage
extends Control

const HERO_LEVEL: int = 4
const HERO_RADIUS: float = 118.0
const HERO_ROTATION_SECONDS: float = 20.0
const ORBIT_SECONDS: float = 12.0
const ORBIT_COLOR: Color = Color(0.27, 0.91, 1.0, 0.38)

var _hero: OrbVisual
var _orbiter_one: OrbVisual
var _orbiter_two: OrbVisual
var _elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero = _create_orb(HERO_LEVEL, HERO_RADIUS, OrbTypes.OrbColor.CYAN)
	_orbiter_one = _create_orb(1, 24.0, OrbTypes.OrbColor.BLUE)
	_orbiter_two = _create_orb(2, 34.0, OrbTypes.OrbColor.PURPLE)
	set_process(true)
	queue_redraw()


func set_symbols_enabled(enabled: bool) -> void:
	for visual: OrbVisual in [_hero, _orbiter_one, _orbiter_two]:
		if visual != null:
			visual.set_symbols_enabled(enabled)


func _process(delta: float) -> void:
	_elapsed += delta
	var center: Vector2 = size * 0.5
	_hero.position = center
	_hero.rotation = TAU * _elapsed / HERO_ROTATION_SECONDS
	_orbiter_one.position = center + Vector2(245.0, 0.0).rotated(
		TAU * _elapsed / ORBIT_SECONDS
	)
	_orbiter_two.position = center + Vector2(0.0, 142.0).rotated(
		-TAU * _elapsed / (ORBIT_SECONDS * 1.08)
	)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	_draw_orbit(center, Vector2(280.0, 112.0), -0.14, ORBIT_COLOR)
	_draw_orbit(center, Vector2(206.0, 86.0), 0.22, Color(0.27, 0.91, 1.0, 0.28))


func _draw_orbit(center: Vector2, radii: Vector2, rotation_angle: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(65):
		var angle: float = TAU * float(index) / 64.0
		points.append(
			center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y).rotated(
				rotation_angle
			)
		)
	draw_polyline(points, color, 2.0, true)


func _create_orb(level: int, radius: float, color_index: int) -> OrbVisual:
	var visual: OrbVisual = OrbVisual.new()
	visual.setup_celestial_preview(
		Config.data.color_display[color_index],
		radius,
		level,
		color_index,
		Config.data.orb_symbols_enabled
	)
	add_child(visual)
	return visual
