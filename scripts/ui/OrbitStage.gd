class_name OrbitStage
extends Control

const HERO_LEVEL: int = 4
const HERO_RADIUS: float = 177.0
const HERO_DIAMETER: float = HERO_RADIUS * 2.0
const HERO_ROTATION_SECONDS: float = 20.0
const ORBIT_SECONDS: float = 12.0
const ORBIT_COLOR: Color = Color(0.27, 0.91, 1.0, 0.38)
const HERO_VIEWPORT_SIZE: int = 320
const HERO_CAMERA_SIZE: float = 1.8
const OUTER_ORBIT_RADII: Vector2 = Vector2(420.0, 168.0)
const INNER_ORBIT_RADII: Vector2 = Vector2(309.0, 129.0)
const OUTER_ORBIT_ROTATION: float = -0.14
const INNER_ORBIT_ROTATION: float = 0.22
const OUTER_ORBITER_RADIUS: float = 24.0
const INNER_ORBITER_RADIUS: float = 34.0
const ORBIT_SAMPLE_COUNT: int = 64
const RING_MINOR_TO_MAJOR_RATIO: float = 0.135 / 0.49

var _hero_viewport: SubViewport
var _hero_texture: TextureRect
var _hero_mesh: MeshInstance3D
var _hero_adornment: MeshInstance3D
var _hero_symbol: MeshInstance3D
var _orbiter_one: OrbVisual
var _orbiter_two: OrbVisual
var _elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_shader_hero()
	_orbiter_one = _create_orb(1, OUTER_ORBITER_RADIUS, OrbTypes.OrbColor.BLUE)
	_orbiter_two = _create_orb(2, INNER_ORBITER_RADIUS, OrbTypes.OrbColor.PURPLE)
	visibility_changed.connect(_sync_render_activity)
	_sync_render_activity()
	_apply_animation_pose()
	queue_redraw()


func set_symbols_enabled(enabled: bool) -> void:
	if _hero_symbol != null:
		_hero_symbol.visible = enabled
	for visual: OrbVisual in [_orbiter_one, _orbiter_two]:
		if visual != null:
			visual.set_symbols_enabled(enabled)


func set_animation_elapsed(seconds: float) -> void:
	_elapsed = maxf(seconds, 0.0)
	_apply_animation_pose()
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	_apply_animation_pose()
	queue_redraw()


func _apply_animation_pose() -> void:
	var center: Vector2 = size * 0.5
	_hero_texture.position = center - Vector2.ONE * HERO_RADIUS
	_hero_texture.size = Vector2.ONE * HERO_DIAMETER
	var polar_alignment: Quaternion = Quaternion(Vector3.UP, hero_rotation_axis())
	var polar_spin: Quaternion = Quaternion(
		Vector3.UP,
		TAU * _elapsed / HERO_ROTATION_SECONDS
	)
	_hero_mesh.quaternion = polar_alignment * polar_spin
	_orbiter_one.position = orbiter_center_for_phase(
		0,
		center,
		TAU * _elapsed / ORBIT_SECONDS
	)
	_orbiter_two.position = orbiter_center_for_phase(
		1,
		center,
		-TAU * _elapsed / (ORBIT_SECONDS * 1.08)
	)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	_draw_orbit(center, OUTER_ORBIT_RADII, OUTER_ORBIT_ROTATION, ORBIT_COLOR)
	_draw_orbit(
		center,
		INNER_ORBIT_RADII,
		INNER_ORBIT_ROTATION,
		Color(0.27, 0.91, 1.0, 0.28)
	)


func _draw_orbit(center: Vector2, radii: Vector2, rotation_angle: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(ORBIT_SAMPLE_COUNT + 1):
		var angle: float = TAU * float(index) / float(ORBIT_SAMPLE_COUNT)
		points.append(
			center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y).rotated(
				rotation_angle
			)
		)
	draw_polyline(points, color, 2.0, true)


func uses_celestial_shader() -> bool:
	if _hero_mesh == null:
		return false
	var material: ShaderMaterial = _hero_mesh.material_override as ShaderMaterial
	return material != null and material.shader != null and material.shader.resource_name == "celestial_orb_shader"


func hero_rect() -> Rect2:
	if _hero_texture == null:
		return Rect2()
	return Rect2(_hero_texture.position, _hero_texture.size)


static func hero_rotation_axis() -> Vector3:
	var projected_length: float = sqrt(
		1.0 - RING_MINOR_TO_MAJOR_RATIO * RING_MINOR_TO_MAJOR_RATIO
	)
	return Vector3(
		-sin(CelestialOrbArt.RING_TILT_RADIANS) * projected_length,
		cos(CelestialOrbArt.RING_TILT_RADIANS) * projected_length,
		RING_MINOR_TO_MAJOR_RATIO
	).normalized()


static func hero_body_diameter() -> float:
	var body_radius_m: float = (
		Config.data.radius_for_level(HERO_LEVEL)
		/ Orb3D.PIXELS_PER_METER
		* CelestialOrbArt.body_radius_ratio(HERO_LEVEL)
	)
	return HERO_DIAMETER * body_radius_m * 2.0 / HERO_CAMERA_SIZE


static func orbiter_center_for_phase(index: int, center: Vector2, phase: float) -> Vector2:
	var radii: Vector2 = OUTER_ORBIT_RADII if index == 0 else INNER_ORBIT_RADII
	var rotation_angle: float = (
		OUTER_ORBIT_ROTATION if index == 0 else INNER_ORBIT_ROTATION
	)
	return center + Vector2(cos(phase) * radii.x, sin(phase) * radii.y).rotated(
		rotation_angle
	)


static func orbiter_radius(index: int) -> float:
	return OUTER_ORBITER_RADIUS if index == 0 else INNER_ORBITER_RADIUS


static func orbiters_sweep_rect(center: Vector2) -> Rect2:
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	for orbiter_index: int in range(2):
		var radius: float = orbiter_radius(orbiter_index)
		for sample_index: int in range(ORBIT_SAMPLE_COUNT):
			var phase: float = TAU * float(sample_index) / float(ORBIT_SAMPLE_COUNT)
			var orbiter_center: Vector2 = orbiter_center_for_phase(
				orbiter_index,
				center,
				phase
			)
			minimum = minimum.min(orbiter_center - Vector2.ONE * radius)
			maximum = maximum.max(orbiter_center + Vector2.ONE * radius)
	return Rect2(minimum, maximum - minimum)


func _sync_render_activity() -> void:
	var active: bool = is_visible_in_tree()
	set_process(active)
	if _hero_viewport != null:
		_hero_viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
		)


func _create_shader_hero() -> void:
	_hero_viewport = SubViewport.new()
	_hero_viewport.name = "HeroViewport"
	_hero_viewport.size = Vector2i(HERO_VIEWPORT_SIZE, HERO_VIEWPORT_SIZE)
	_hero_viewport.transparent_bg = true
	_hero_viewport.own_world_3d = true
	_hero_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_hero_viewport)

	var camera: Camera3D = Camera3D.new()
	camera.name = "HeroCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = HERO_CAMERA_SIZE
	camera.position = Vector3(0.0, 0.0, 4.0)
	camera.current = true
	_hero_viewport.add_child(camera)

	var material: ShaderMaterial = CelestialOrbArt.material_for(
		Config.data,
		OrbTypes.OrbColor.CYAN,
		HERO_LEVEL
	)
	_hero_mesh = MeshInstance3D.new()
	_hero_mesh.name = "HeroBody"
	_hero_mesh.mesh = Orb3D.shared_mesh_for_level(Config.data, HERO_LEVEL)
	_hero_mesh.material_override = material
	_hero_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hero_viewport.add_child(_hero_mesh)

	var radius_m: float = Config.data.radius_for_level(HERO_LEVEL) / Orb3D.PIXELS_PER_METER
	_hero_adornment = MeshInstance3D.new()
	_hero_adornment.name = "HeroRing"
	_hero_adornment.mesh = CelestialOrbArt.billboard_mesh(1)
	_hero_adornment.material_override = material
	_hero_adornment.position = Vector3(0.0, 0.0, 0.001)
	_hero_adornment.rotation.z = CelestialOrbArt.RING_TILT_RADIANS
	_hero_adornment.scale = Vector3(radius_m, radius_m, 1.0)
	_hero_adornment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hero_viewport.add_child(_hero_adornment)

	_hero_symbol = MeshInstance3D.new()
	_hero_symbol.name = "HeroSymbol"
	_hero_symbol.mesh = OrbSymbols.mesh_for_color(OrbTypes.OrbColor.CYAN)
	_hero_symbol.position = Vector3(0.0, 0.0, radius_m + 0.002)
	var symbol_size_m: float = radius_m * OrbSymbols.SYMBOL_SIZE_FACTOR
	_hero_symbol.scale = Vector3(symbol_size_m, symbol_size_m, 1.0)
	_hero_symbol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hero_symbol.visible = Config.data.orb_symbols_enabled
	_hero_viewport.add_child(_hero_symbol)

	_hero_texture = TextureRect.new()
	_hero_texture.name = "HeroTexture"
	_hero_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_texture.texture = _hero_viewport.get_texture()
	_hero_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_texture.z_index = 1
	add_child(_hero_texture)


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
