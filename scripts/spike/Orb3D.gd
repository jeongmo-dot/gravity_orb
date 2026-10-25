class_name Orb3D
extends Node

const PIXELS_PER_METER: float = 100.0
const STRETCH_SPEED_MIN: float = 700.0
const STRETCH_SPEED_MAX: float = 1100.0
const STRETCH_ALONG_SCALE: float = 1.15
const STRETCH_PERPENDICULAR_SCALE: float = 0.92
const JELLY_BREATHE_AMOUNT: float = 0.018
const JELLY_FRAME_TURN_SPEED: float = 8.0
const JELLY_DEFORM_FOLLOW_SPEED: float = 11.0
const JELLY_STRETCH_SPEED_DIVISOR: float = 5800.0
const JELLY_STRETCH_MAX: float = 0.19
const JELLY_IMPACT_SPEED_DIVISOR: float = 1000.0
const JELLY_IMPACT_MINIMUM: float = 0.06
const JELLY_IMPACT_DECAY: float = 4.8
const JELLY_BREATH_BLEND_SPEED: float = 4.0
const JELLY_ABSORPTION_GROWTH_DURATION: float = 0.10
const JELLY_BELLY_TRANSITION_DURATION: float = 0.15

static var _shared_physics_materials: Dictionary = {}
static var _shared_shapes: Dictionary = {}
static var _shared_meshes: Dictionary = {}

@onready var _body: RigidBody3D = %Body
@onready var _collision_shape: CollisionShape3D = %CollisionShape3D
@onready var _mesh: MeshInstance3D = %Mesh
@onready var _adornment: MeshInstance3D = %Adornment
@onready var _blast_outline: MeshInstance3D = %BlastOutline
@onready var _belly: MeshInstance3D = %Belly
@onready var _face: MeshInstance3D = %Face
@onready var _symbol_mesh: MeshInstance3D = %Symbol

var color: int = 0
var level: int = 1
var generation: int = 0
var stable_spawn_id: int = 0
var jelly_mass: float = 1.0
var consumed: bool = false
var is_ghost: bool = false
var ghost_elapsed: float = 0.0
var is_waiting_at_entrance: bool = false
var entrance_preferred_position: Vector2 = Vector2.ZERO
var entrance_gravity: Vector2i = Vector2i.DOWN
var diagnostic_last_event: String = "spawn"
var diagnostic_last_event_physics_frame: int = 0
var _radius: float = 0.0
var _current_radius: float = 0.0
var _growth_start_radius: float = 0.0
var _growth_duration: float = 0.0
var _growth_elapsed: float = 0.0
var _contact_reporting_enabled: bool = true
var _continuous_cd_enabled: bool = true
var _allow_sleep: bool = false
var _progressive_growth_enabled: bool = false
var _blast_armed: bool = false
var _blast_blink_period: float = 0.8
var _blast_blink_elapsed: float = 0.0
var _visual_punch_tween: Tween
var _visual_punch_scale: Vector3 = Vector3.ONE:
	set(value):
		_visual_punch_scale = value
		_update_visual_transform()
var _render_clamp_enabled: bool = true
var _radius_resources_are_unique: bool = false
var _visual_alpha: float = 1.0
var _is_jelly_visual: bool = false
var _jelly_idle_elapsed: float = 0.0
var _jelly_frame_rotation: float = 0.0
var _jelly_frame_target_rotation: float = 0.0
var _jelly_frame_initialized: bool = false
var _jelly_deform: Vector2 = Vector2.ONE
var _jelly_impact: float = 0.0
var _jelly_breath_weight: float = 0.0
var _jelly_turn_resting: bool = false
var _jelly_previous_speed: float = 0.0
var _jelly_impact_start_count: int = 0
var _jelly_belly_start: float = 0.0
var _jelly_belly_fraction: float = 0.0
var _jelly_belly_target: float = 0.0
var _jelly_belly_elapsed: float = 0.0
var _previous_physics_position: Vector3 = Vector3.ZERO
var _current_physics_position: Vector3 = Vector3.ZERO
var _physics_position_initialized: bool = false

var position: Vector2:
	get:
		return world_position_to_plane(_body.position)
	set(value):
		_body.position = plane_position_to_world(value)
		_reset_visual_interpolation()
		_update_visual_transform()

var linear_velocity: Vector2:
	get:
		return world_vector_to_plane(_body.linear_velocity)
	set(value):
		_body.linear_velocity = plane_vector_to_world(value)
		_jelly_previous_speed = value.length()

var angular_velocity: float:
	get:
		return world_angular_velocity_to_plane(_body.angular_velocity.z)
	set(value):
		_body.angular_velocity = Vector3(
			0.0,
			0.0,
			plane_angular_velocity_to_world(value)
		)


static func plane_position_to_world(value: Vector2, z: float = 0.0) -> Vector3:
	return Vector3(
		value.x / PIXELS_PER_METER,
		-value.y / PIXELS_PER_METER,
		z
	)


static func world_position_to_plane(value: Vector3) -> Vector2:
	return Vector2(value.x, -value.y) * PIXELS_PER_METER


static func jelly_upright_deform_basis(
	frame_rotation: float,
	deform: Vector2,
	uniform_scale: float
) -> Basis:
	var cosine: float = cos(frame_rotation)
	var sine: float = sin(frame_rotation)
	var xx: float = cosine * cosine * deform.x + sine * sine * deform.y
	var xy: float = cosine * sine * (deform.x - deform.y)
	var yy: float = sine * sine * deform.x + cosine * cosine * deform.y
	return Basis(
		Vector3(xx * uniform_scale, xy * uniform_scale, 0.0),
		Vector3(xy * uniform_scale, yy * uniform_scale, 0.0),
		Vector3(0.0, 0.0, 1.0)
	)


static func plane_vector_to_world(value: Vector2) -> Vector3:
	return Vector3(
		value.x / PIXELS_PER_METER,
		-value.y / PIXELS_PER_METER,
		0.0
	)


static func world_vector_to_plane(value: Vector3) -> Vector2:
	return Vector2(value.x, -value.y) * PIXELS_PER_METER


static func plane_direction_to_world(value: Vector2i) -> Vector3:
	return Vector3(float(value.x), -float(value.y), 0.0)


static func plane_angular_velocity_to_world(value: float) -> float:
	return -value


static func world_angular_velocity_to_plane(value: float) -> float:
	return -value


static func prewarm_shared_resources(cfg: GameConfig) -> void:
	_shared_physics_material(cfg)
	for level_index: int in range(1, cfg.orb_max_level + 1):
		_shared_shape_for_level(cfg, level_index)
		_shared_mesh_for_level(cfg, level_index)
	CelestialOrbArt.prewarm(cfg)
	JellyOrbArt.prewarm(cfg)
	OrbSymbols.prewarm_shared_resources()


static func clear_shared_resource_cache() -> void:
	_shared_physics_materials.clear()
	_shared_shapes.clear()
	_shared_meshes.clear()
	CelestialOrbArt.clear_cache()
	JellyOrbArt.clear_cache()


static func shared_resource_counts() -> Dictionary:
	return {
		"physics_materials": _shared_physics_materials.size(),
		"shapes": _shared_shapes.size(),
		"meshes": _shared_meshes.size(),
		"visual_materials": CelestialOrbArt.shared_material_count(),
		"jelly_visual_materials": JellyOrbArt.shared_material_count(),
		"adornment_meshes": CelestialOrbArt.shared_mesh_count(),
	}


static func shared_mesh_for_level(cfg: GameConfig, level_index: int) -> SphereMesh:
	return _shared_mesh_for_level(cfg, level_index)


static func shared_visual_material_for_color(
	cfg: GameConfig,
	color_index: int,
	level_index: int = 1
) -> ShaderMaterial:
	return CelestialOrbArt.material_for(cfg, color_index, level_index)


func setup(p_color: int, p_level: int, cfg: GameConfig) -> void:
	color = p_color
	level = p_level
	jelly_mass = cfg.jelly_mass_for_level(level)
	_visual_alpha = 1.0
	_is_jelly_visual = cfg.game_mode == GameConfig.GameMode.JELLY
	_jelly_idle_elapsed = 0.0
	_jelly_frame_rotation = 0.0
	_jelly_frame_target_rotation = 0.0
	_jelly_frame_initialized = false
	_jelly_deform = Vector2.ONE
	_jelly_impact = 0.0
	_jelly_breath_weight = 0.0
	_jelly_turn_resting = false
	_jelly_previous_speed = 0.0
	_jelly_impact_start_count = 0
	_jelly_belly_start = 0.0
	_jelly_belly_fraction = 0.0
	_jelly_belly_target = 0.0
	_jelly_belly_elapsed = 0.0
	_blast_armed = cfg.blast_enabled_for_level(level)
	_blast_blink_period = maxf(cfg.blast_blink_period, 0.001)
	_blast_blink_elapsed = 0.0
	_radius = cfg.radius_for_level(level)
	_growth_duration = maxf(cfg.grow_duration, 0.0) if _progressive_growth_enabled else 0.0
	_growth_start_radius = _radius * clampf(cfg.grow_start_ratio, 0.0, 1.0)
	_current_radius = _radius if _growth_duration <= 0.0 else _growth_start_radius
	_growth_elapsed = 0.0
	diagnostic_last_event = "spawn"
	diagnostic_last_event_physics_frame = Engine.get_physics_frames()
	var radius_m: float = _current_radius / PIXELS_PER_METER

	_body.gravity_scale = 0.0
	_body.can_sleep = _allow_sleep
	_body.continuous_cd = _continuous_cd_enabled
	_body.contact_monitor = _contact_reporting_enabled
	_body.max_contacts_reported = cfg.contact_max_reported if _contact_reporting_enabled else 0
	_body.mass = cfg.mass_for_level(level)
	_body.linear_damp = cfg.orb_linear_damp
	_body.angular_damp = cfg.orb_angular_damp
	_body.axis_lock_linear_z = true
	_body.axis_lock_angular_x = true
	_body.axis_lock_angular_y = true
	_body.collision_layer = 2
	_body.collision_mask = 3

	_body.physics_material_override = _shared_physics_material(cfg)
	_collision_shape.shape = _shared_shape_for_level(cfg, level)
	_mesh.mesh = _shared_mesh_for_level(cfg, level)
	_radius_resources_are_unique = false
	var visual_material: ShaderMaterial = (
		JellyOrbArt.body_material_for(color, level)
		if _is_jelly_visual
		else CelestialOrbArt.material_for(cfg, color, level)
	)
	_mesh.material_override = visual_material
	_adornment.mesh = CelestialOrbArt.billboard_mesh(1)
	_adornment.material_override = visual_material
	_adornment.visible = not _is_jelly_visual and CelestialOrbArt.has_adornment(level)
	_blast_outline.mesh = CelestialOrbArt.billboard_mesh(2)
	_blast_outline.material_override = visual_material
	_blast_outline.visible = _blast_armed and not _is_jelly_visual
	_belly.mesh = JellyOrbArt.face_mesh()
	_belly.material_override = JellyOrbArt.belly_material_for(color, level)
	_belly.visible = false
	_face.mesh = JellyOrbArt.face_mesh()
	_face.material_override = JellyOrbArt.face_material_for(color, level, _blast_armed)
	_face.visible = _is_jelly_visual
	_apply_visual_transparency()
	if _is_jelly_visual or _current_radius < _radius:
		_ensure_unique_radius_resources()
		_apply_current_radius_to_resources(radius_m)
	_symbol_mesh.mesh = OrbSymbols.mesh_for_color(color)
	_symbol_mesh.visible = cfg.orb_symbols_enabled
	_symbol_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_symbol_mesh.transparency = 0.0
	_reset_visual_interpolation()
	_update_visual_transform()


func set_symbols_enabled(enabled: bool) -> void:
	_symbol_mesh.visible = enabled


func _physics_process(delta: float) -> void:
	_sample_physics_position()
	_advance_growth(delta)
	_advance_blast_blink(delta)
	_advance_jelly_impact(delta)



func _process(delta: float) -> void:
	if _is_jelly_visual:
		_jelly_idle_elapsed += maxf(delta, 0.0)
		_advance_jelly_visual(delta)
		_advance_jelly_belly(delta)
		JellyOrbArt.advance_animation(delta)
	_update_visual_transform()


func configure_physics_profile(
	contact_reporting_enabled: bool,
	continuous_cd_enabled: bool,
	allow_sleep: bool,
	progressive_growth_enabled: bool = false
) -> void:
	_contact_reporting_enabled = contact_reporting_enabled
	_continuous_cd_enabled = continuous_cd_enabled
	_allow_sleep = allow_sleep
	_progressive_growth_enabled = progressive_growth_enabled


func get_radius() -> float:
	return _radius


func get_current_radius() -> float:
	return _current_radius


func get_jelly_mass() -> float:
	return jelly_mass


func set_jelly_mass(
	next_mass: float,
	cfg: GameConfig,
	growth_start_radius_px: float = -1.0
) -> void:
	var gravity_direction: Vector2 = world_vector_to_plane(_body.constant_force).normalized()
	var previous_radius: float = _current_radius
	jelly_mass = clampf(
		next_mass,
		cfg.jelly_mass_for_level(1),
		cfg.jelly_mass_for_level(cfg.orb_max_level)
	)
	level = cfg.jelly_level_for_mass(jelly_mass)
	_radius = cfg.jelly_radius_for_mass(jelly_mass)
	if growth_start_radius_px >= 0.0:
		previous_radius = minf(growth_start_radius_px, _radius)
	_growth_start_radius = previous_radius
	_growth_duration = (
		JELLY_ABSORPTION_GROWTH_DURATION
		if _radius > previous_radius + 0.000001
		else 0.0
	)
	_growth_elapsed = 0.0
	_current_radius = previous_radius if _growth_duration > 0.0 else _radius
	_body.mass = cfg.mass_for_radius(_radius)
	if not gravity_direction.is_zero_approx():
		set_gravity(
			Vector2i(roundi(gravity_direction.x), roundi(gravity_direction.y)),
			cfg.gravity_strength
		)
	_blast_armed = cfg.blast_enabled_for_level(level)
	_blast_outline.visible = _blast_armed and not _is_jelly_visual
	var visual_material: ShaderMaterial = (
		JellyOrbArt.body_material_for(color, level)
		if _is_jelly_visual
		else CelestialOrbArt.material_for(cfg, color, level)
	)
	_mesh.material_override = visual_material
	_adornment.material_override = visual_material
	_adornment.visible = not _is_jelly_visual and CelestialOrbArt.has_adornment(level)
	_blast_outline.material_override = visual_material
	_belly.material_override = JellyOrbArt.belly_material_for(color, level)
	_set_jelly_belly_target(_jelly_fill_fraction_for_mass(jelly_mass, cfg))
	_face.material_override = JellyOrbArt.face_material_for(color, level, _blast_armed)
	_face.visible = _is_jelly_visual
	_apply_visual_transparency()
	_ensure_unique_radius_resources()
	_apply_current_radius_to_resources(_current_radius / PIXELS_PER_METER)
	_update_visual_transform()


func set_render_clamp_enabled(enabled: bool) -> void:
	_render_clamp_enabled = enabled
	_update_visual_transform()


func is_blast_armed() -> bool:
	return _blast_armed


func blast_emission_strength() -> float:
	if not _blast_armed:
		return 0.08
	if _is_jelly_visual:
		return 0.0
	return 0.20 + 0.80 * (
		0.5 + 0.5 * sin(TAU * _blast_blink_elapsed / _blast_blink_period)
	)


func play_visual_punch(scale_factor: float = 1.18, duration: float = 0.14) -> void:
	if _visual_punch_tween != null and _visual_punch_tween.is_valid():
		_visual_punch_tween.kill()
	var target_scale: Vector3 = Vector3.ONE * scale_factor
	var start_scale: Vector3 = (
		Vector3.ONE * 0.88
		if _is_jelly_visual
		else Vector3.ONE.lerp(target_scale, 0.02)
	)
	_visual_punch_scale = start_scale
	_visual_punch_tween = create_tween()
	_visual_punch_tween.set_trans(Tween.TRANS_BACK)
	_visual_punch_tween.set_ease(Tween.EASE_OUT)
	_visual_punch_tween.tween_method(
		_set_visual_punch_scale,
		start_scale,
		target_scale,
		duration * 0.45
	)
	_visual_punch_tween.set_trans(Tween.TRANS_QUAD)
	_visual_punch_tween.set_ease(Tween.EASE_IN_OUT)
	_visual_punch_tween.tween_method(
		_set_visual_punch_scale,
		target_scale,
		Vector3.ONE,
		duration * 0.55
	)


func jelly_impact_start_count() -> int:
	return _jelly_impact_start_count


func reset_jelly_motion_diagnostics() -> void:
	_jelly_impact_start_count = 0


func set_turn_resting(resting: bool) -> void:
	_jelly_turn_resting = resting


func play_visual_pull_punch(duration: float = 0.3) -> void:
	if _visual_punch_tween != null and _visual_punch_tween.is_valid():
		_visual_punch_tween.kill()
	var contracted_scale: Vector3 = Vector3.ONE / 1.18
	var expanded_scale: Vector3 = Vector3.ONE * 1.18
	var start_scale: Vector3 = Vector3.ONE.lerp(contracted_scale, 0.02)
	_visual_punch_scale = start_scale
	_visual_punch_tween = create_tween()
	_visual_punch_tween.set_trans(Tween.TRANS_QUAD)
	_visual_punch_tween.set_ease(Tween.EASE_OUT)
	_visual_punch_tween.tween_method(
		_set_visual_punch_scale,
		start_scale,
		contracted_scale,
		duration * 0.35
	)
	_visual_punch_tween.set_trans(Tween.TRANS_BACK)
	_visual_punch_tween.tween_method(
		_set_visual_punch_scale,
		contracted_scale,
		expanded_scale,
		duration * 0.30
	)
	_visual_punch_tween.set_trans(Tween.TRANS_QUAD)
	_visual_punch_tween.set_ease(Tween.EASE_IN_OUT)
	_visual_punch_tween.tween_method(
		_set_visual_punch_scale,
		expanded_scale,
		Vector3.ONE,
		duration * 0.35
	)


func _set_visual_punch_scale(value: Vector3) -> void:
	_visual_punch_scale = value


func enter_ghost_state(alpha: float) -> void:
	is_ghost = true
	ghost_elapsed = 0.0
	_body.collision_layer = 4
	_body.collision_mask = 1
	_set_visual_alpha(alpha)


func exit_ghost_state() -> void:
	is_ghost = false
	is_waiting_at_entrance = false
	_body.collision_layer = 2
	_body.collision_mask = 3
	_body.sleeping = false
	_set_visual_alpha(1.0)


func advance_ghost(delta: float) -> void:
	if is_ghost:
		ghost_elapsed += delta


func note_diagnostic_event(event_name: String, physics_frame: int = -1) -> void:
	diagnostic_last_event = event_name
	diagnostic_last_event_physics_frame = (
		Engine.get_physics_frames() if physics_frame < 0 else physics_frame
	)


func set_gravity(direction: Vector2i, strength: float) -> void:
	if is_waiting_at_entrance:
		_body.constant_force = Vector3.ZERO
		return
	var level_strength: float = strength * (
		1.0 + Config.data.gravity_level_scale * float(level - 1)
	)
	var acceleration_px: Vector2 = Vector2(direction) * level_strength
	_body.constant_force = plane_vector_to_world(acceleration_px) * _body.mass
	if _is_jelly_visual and direction != Vector2i.ZERO:
		_jelly_frame_target_rotation = atan2(float(direction.x), float(direction.y))
		if not _jelly_frame_initialized:
			_jelly_frame_rotation = _jelly_frame_target_rotation
			_jelly_frame_initialized = true
	_body.sleeping = false


func apply_plane_impulse(impulse: Vector2) -> void:
	_body.apply_central_impulse(plane_vector_to_world(impulse))
	_body.sleeping = false


func apply_plane_velocity_change(velocity_change: Vector2) -> void:
	apply_plane_impulse(velocity_change * _body.mass)


func enter_entrance_wait(preferred_position: Vector2, gravity: Vector2i) -> void:
	is_waiting_at_entrance = true
	entrance_preferred_position = preferred_position
	entrance_gravity = gravity
	position = preferred_position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_body.constant_force = Vector3.ZERO
	_body.collision_layer = 0
	_body.collision_mask = 0
	_body.freeze = true
	_set_waiting_visual(true)


func release_entrance_wait(
	spawn_position: Vector2,
	gravity: Vector2i,
	gravity_strength: float
) -> void:
	position = spawn_position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	is_waiting_at_entrance = false
	_body.collision_layer = 2
	_body.collision_mask = 3
	_body.freeze = false
	_set_waiting_visual(false)
	set_gravity(gravity, gravity_strength)
	note_diagnostic_event("entrance_release")


func disable_physics() -> void:
	_body.collision_layer = 0
	_body.collision_mask = 0
	_body.constant_force = Vector3.ZERO
	_body.freeze = true
	_reset_visual_interpolation()


func get_physics_body() -> RigidBody3D:
	return _body


func mesh_resource() -> SphereMesh:
	return _mesh.mesh as SphereMesh


func shape_resource() -> SphereShape3D:
	return _collision_shape.shape as SphereShape3D


func visual_material_resource() -> ShaderMaterial:
	return _mesh.material_override as ShaderMaterial


func celestial_art_key() -> String:
	return "%s:%d" % [CelestialOrbArt.level_name(level), color]


func adornment_mesh_resource() -> Mesh:
	return _adornment.mesh


func blast_outline_strength() -> float:
	return blast_emission_strength() if _blast_armed else 0.0


func blast_pulse_scale() -> float:
	if _is_jelly_visual:
		return 1.0
	if not _blast_armed or level < 6:
		return 1.0
	return lerpf(0.94, 1.0, blast_emission_strength())


func visual_stretch_scale() -> Vector3:
	if _is_jelly_visual:
		return Vector3(_jelly_deform.x, _jelly_deform.y, _jelly_deform.x)
	return _stretch_scale_for_ratio(_visual_stretch_ratio())


func _visual_stretch_ratio() -> float:
	if not Config.data.fx_enabled:
		return 0.0
	if _is_jelly_visual or not Config.data.fx_orb_stretch_enabled:
		return 0.0
	return smoothstep(STRETCH_SPEED_MIN, STRETCH_SPEED_MAX, linear_velocity.length())


func _stretch_scale_for_ratio(ratio: float) -> Vector3:
	return Vector3(
		lerpf(1.0, STRETCH_ALONG_SCALE, ratio),
		lerpf(1.0, STRETCH_PERPENDICULAR_SCALE, ratio),
		lerpf(1.0, STRETCH_PERPENDICULAR_SCALE, ratio)
	)


func visual_mesh_scale() -> Vector3:
	return _mesh.scale


func get_colliding_orbs() -> Array[Orb3D]:
	var result: Array[Orb3D] = []
	if not _body.contact_monitor:
		return result
	for body: Node3D in _body.get_colliding_bodies():
		var candidate: Orb3D = body.get_parent() as Orb3D
		if candidate != null:
			result.append(candidate)
	return result


func _set_waiting_visual(waiting: bool) -> void:
	_set_visual_alpha(0.45 if waiting else 1.0)


func _set_visual_alpha(alpha: float) -> void:
	alpha = clampf(alpha, 0.0, 1.0)
	if is_equal_approx(alpha, _visual_alpha):
		return
	_visual_alpha = alpha
	_apply_visual_transparency()


func _advance_blast_blink(delta: float) -> void:
	if not _blast_armed:
		return
	_blast_blink_elapsed += delta
	_apply_visual_transparency()


func _apply_visual_transparency() -> void:
	var base_transparency: float = 1.0 - clampf(_visual_alpha, 0.0, 1.0)
	_mesh.transparency = base_transparency
	_adornment.transparency = base_transparency
	_face.transparency = base_transparency
	_belly.transparency = 0.0
	_belly.set_instance_shader_parameter(
		"visual_alpha",
		clampf(_visual_alpha, 0.0, 1.0)
	)
	if _is_jelly_visual:
		_blast_outline.transparency = 1.0
	else:
		_blast_outline.transparency = 1.0 - clampf(
			_visual_alpha * blast_emission_strength(),
			0.0,
			1.0
		)
	_symbol_mesh.transparency = base_transparency


func _set_jelly_belly_target(target: float) -> void:
	var clamped_target: float = clampf(target, 0.0, 0.999999)
	if is_equal_approx(clamped_target, _jelly_belly_target):
		return
	_jelly_belly_start = _jelly_belly_fraction
	_jelly_belly_target = clamped_target
	_jelly_belly_elapsed = 0.0
	_apply_jelly_belly_fraction()


func _advance_jelly_belly(delta: float) -> void:
	if is_equal_approx(_jelly_belly_fraction, _jelly_belly_target):
		return
	_jelly_belly_elapsed = minf(
		_jelly_belly_elapsed + maxf(delta, 0.0),
		JELLY_BELLY_TRANSITION_DURATION
	)
	var progress: float = _jelly_belly_elapsed / JELLY_BELLY_TRANSITION_DURATION
	_jelly_belly_fraction = lerpf(_jelly_belly_start, _jelly_belly_target, progress)
	_apply_jelly_belly_fraction()


func _apply_jelly_belly_fraction() -> void:
	if not is_instance_valid(_belly):
		return
	_belly.set_instance_shader_parameter("fill_fraction", _jelly_belly_fraction)
	_belly.visible = _is_jelly_visual and _jelly_belly_fraction > 0.000001


func _jelly_fill_fraction_for_mass(value: float, cfg: GameConfig) -> float:
	var display_level: int = cfg.jelly_level_for_mass(value)
	var base_mass: float = cfg.jelly_mass_for_level(display_level)
	return clampf((value - base_mass) / base_mass, 0.0, 0.999999)


func _advance_growth(delta: float) -> void:
	if _current_radius >= _radius or _growth_duration <= 0.0:
		return
	_growth_elapsed = minf(_growth_elapsed + delta, _growth_duration)
	var progress: float = _growth_elapsed / _growth_duration
	_set_current_radius(lerpf(_growth_start_radius, _radius, progress))


func _advance_jelly_impact(delta: float) -> void:
	if not _is_jelly_visual:
		return
	_jelly_impact = maxf(0.0, _jelly_impact - maxf(delta, 0.0) * JELLY_IMPACT_DECAY)
	var current_speed: float = linear_velocity.length()
	var intensity: float = clampf(
		(_jelly_previous_speed - current_speed) / JELLY_IMPACT_SPEED_DIVISOR,
		0.0,
		1.0
	)
	if intensity >= JELLY_IMPACT_MINIMUM:
		if _jelly_impact <= 0.000001:
			_jelly_impact_start_count += 1
		_jelly_impact = maxf(_jelly_impact, intensity)
	_jelly_previous_speed = current_speed


func _advance_jelly_visual(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	_jelly_frame_rotation = lerp_angle(
		_jelly_frame_rotation,
		_jelly_frame_target_rotation,
		clampf(safe_delta * JELLY_FRAME_TURN_SPEED, 0.0, 1.0)
	)
	_jelly_breath_weight = move_toward(
		_jelly_breath_weight,
		1.0 if _jelly_turn_resting else 0.0,
		safe_delta * JELLY_BREATH_BLEND_SPEED
	)
	_jelly_deform = _jelly_deform.lerp(
		_jelly_target_deform(),
		clampf(safe_delta * JELLY_DEFORM_FOLLOW_SPEED, 0.0, 1.0)
	)


func _jelly_target_deform() -> Vector2:
	if _jelly_turn_resting:
		return Vector2.ONE
	if _jelly_impact > 0.0:
		return Vector2(
			1.0 + 0.18 * _jelly_impact,
			1.0 - 0.20 * _jelly_impact
		)
	var gravity_direction: Vector2 = world_vector_to_plane(_body.constant_force).normalized()
	var fall_speed: float = maxf(0.0, linear_velocity.dot(gravity_direction))
	var stretch: float = clampf(
		fall_speed / JELLY_STRETCH_SPEED_DIVISOR,
		0.0,
		JELLY_STRETCH_MAX
	)
	return Vector2(1.0 - 0.55 * stretch, 1.0 + stretch)


func _jelly_render_deform() -> Vector2:
	var breathe: float = (
		sin(_jelly_idle_elapsed * 1.8 + float(color))
		* JELLY_BREATHE_AMOUNT
		* _jelly_breath_weight
	)
	return _jelly_deform * Vector2(1.0 + breathe, 1.0 - breathe)


func _sample_physics_position() -> void:
	if not _physics_position_initialized:
		_reset_visual_interpolation()
		return
	_previous_physics_position = _current_physics_position
	_current_physics_position = _body.position


func _reset_visual_interpolation() -> void:
	if not is_instance_valid(_body):
		return
	_previous_physics_position = _body.position
	_current_physics_position = _body.position
	_physics_position_initialized = true


func interpolated_body_position(fraction: float) -> Vector3:
	if not _physics_position_initialized:
		return _body.position
	return _previous_physics_position.lerp(
		_current_physics_position,
		clampf(fraction, 0.0, 1.0)
	)


func _set_current_radius(radius_px: float) -> void:
	_current_radius = minf(radius_px, _radius)
	var radius_m: float = _current_radius / PIXELS_PER_METER
	_ensure_unique_radius_resources()
	_apply_current_radius_to_resources(radius_m)
	_update_visual_transform()


func _apply_current_radius_to_resources(radius_m: float) -> void:
	var sphere_shape: SphereShape3D = _collision_shape.shape as SphereShape3D
	if sphere_shape != null:
		sphere_shape.radius = radius_m
	var sphere_mesh: SphereMesh = _mesh.mesh as SphereMesh
	if sphere_mesh != null:
		var visual_radius_m: float = (
			radius_m
			if _is_jelly_visual
			else radius_m * CelestialOrbArt.body_radius_ratio(level)
		)
		sphere_mesh.radius = visual_radius_m
		sphere_mesh.height = visual_radius_m * 2.0


func _ensure_unique_radius_resources() -> void:
	if _radius_resources_are_unique:
		return
	var shared_shape: SphereShape3D = _collision_shape.shape as SphereShape3D
	if shared_shape != null:
		_collision_shape.shape = shared_shape.duplicate(true) as SphereShape3D
	var shared_mesh: SphereMesh = _mesh.mesh as SphereMesh
	if shared_mesh != null:
		_mesh.mesh = shared_mesh.duplicate(true) as SphereMesh
	_radius_resources_are_unique = true


static func _shared_physics_material(cfg: GameConfig) -> PhysicsMaterial:
	var key: String = "%.6f:%.6f" % [cfg.orb_friction, cfg.orb_bounce]
	if not _shared_physics_materials.has(key):
		var material: PhysicsMaterial = PhysicsMaterial.new()
		material.friction = cfg.orb_friction
		material.bounce = cfg.orb_bounce
		_shared_physics_materials[key] = material
	return _shared_physics_materials[key] as PhysicsMaterial


static func _shared_shape_for_level(cfg: GameConfig, level_index: int) -> SphereShape3D:
	var radius_m: float = cfg.radius_for_level(level_index) / PIXELS_PER_METER
	var key: String = "%.6f" % radius_m
	if not _shared_shapes.has(key):
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = radius_m
		_shared_shapes[key] = shape
	return _shared_shapes[key] as SphereShape3D


static func _shared_mesh_for_level(cfg: GameConfig, level_index: int) -> SphereMesh:
	var radius_m: float = cfg.radius_for_level(level_index) / PIXELS_PER_METER
	var visual_radius_m: float = radius_m * CelestialOrbArt.body_radius_ratio(level_index)
	var key: String = "%d:%.6f" % [level_index, visual_radius_m]
	if not _shared_meshes.has(key):
		var mesh: SphereMesh = SphereMesh.new()
		mesh.resource_name = "celestial_%s_mesh" % CelestialOrbArt.level_name(level_index)
		mesh.radius = visual_radius_m
		mesh.height = visual_radius_m * 2.0
		mesh.radial_segments = 14 if level_index == 1 else 32
		mesh.rings = 8 if level_index == 1 else 16
		_shared_meshes[key] = mesh
	return _shared_meshes[key] as SphereMesh


func _update_visual_transform() -> void:
	if (
		not is_instance_valid(_mesh)
		or not is_instance_valid(_symbol_mesh)
		or not is_instance_valid(_body)
	):
		return
	var radius_m: float = _current_radius / PIXELS_PER_METER
	var interpolated_position: Vector3 = interpolated_body_position(
		Engine.get_physics_interpolation_fraction()
	)
	var render_plane_position: Vector2 = world_position_to_plane(interpolated_position)
	if _render_clamp_enabled:
		var half: float = Config.data.board_size * 0.5
		var limit: float = maxf(half - _current_radius, 0.0)
		render_plane_position = Vector2(
			clampf(render_plane_position.x, -limit, limit),
			clampf(render_plane_position.y, -limit, limit)
		)
	var render_world_position: Vector3 = plane_position_to_world(
		render_plane_position,
		interpolated_position.z
	)
	var stretch_ratio: float = _visual_stretch_ratio()
	var stretch_scale: Vector3 = _stretch_scale_for_ratio(stretch_ratio)
	var jelly_deform: Vector2 = _jelly_render_deform() if _is_jelly_visual else Vector2.ONE
	var jelly_scale: Vector3 = Vector3(jelly_deform.x, jelly_deform.y, jelly_deform.x)
	_mesh.scale = _visual_punch_scale * stretch_scale * jelly_scale
	_mesh.position = render_world_position
	_adornment.position = render_world_position + Vector3(0.0, 0.0, 0.001)
	var body_front_offset: float = (
		radius_m * absf(_mesh.scale.z)
		if _is_jelly_visual
		else radius_m
	)
	_blast_outline.position = render_world_position + Vector3(0.0, 0.0, radius_m + 0.004)
	_belly.position = render_world_position + Vector3(0.0, 0.0, body_front_offset + 0.003)
	_face.position = render_world_position + Vector3(0.0, 0.0, body_front_offset + 0.006)
	if _is_jelly_visual:
		_mesh.rotation = Vector3(0.0, 0.0, _jelly_frame_rotation)
	elif stretch_ratio <= 0.0:
		_mesh.rotation = _body.rotation
	else:
		var world_velocity: Vector3 = _body.linear_velocity
		_mesh.rotation = Vector3(0.0, 0.0, atan2(world_velocity.y, world_velocity.x))
	_adornment.rotation = Vector3(
		0.0,
		0.0,
		CelestialOrbArt.RING_TILT_RADIANS if level == 4 else 0.0
	)
	_blast_outline.rotation = (
		Vector3.ZERO
	)
	_belly.rotation = Vector3(0.0, 0.0, _jelly_frame_rotation)
	var punch_scale: float = maxf(
		_visual_punch_scale.x,
		maxf(_visual_punch_scale.y, _visual_punch_scale.z)
	)
	_adornment.scale = Vector3(radius_m, radius_m, 1.0) * punch_scale
	_blast_outline.scale = (
		Vector3(
			radius_m * (jelly_deform.x if _is_jelly_visual else 1.0),
			radius_m * (jelly_deform.y if _is_jelly_visual else 1.0),
			1.0
		)
		* punch_scale
		* blast_pulse_scale()
	)
	_belly.scale = Vector3(
		radius_m * jelly_deform.x,
		radius_m * jelly_deform.y,
		1.0
	) * punch_scale
	var face_radius_ratio: float = (
		1.0
		if _is_jelly_visual and (level >= Config.data.orb_max_level or _blast_armed)
		else 0.62
	)
	var face_scale_m: float = radius_m * face_radius_ratio * punch_scale
	_face.basis = (
		jelly_upright_deform_basis(
			_jelly_frame_rotation,
			jelly_deform,
			face_scale_m
		)
		if _is_jelly_visual
		else Basis.from_scale(Vector3(face_scale_m, face_scale_m, 1.0))
	)
	var symbol_y_offset: float = radius_m * 0.54 if _is_jelly_visual else 0.0
	_symbol_mesh.position = (
		render_world_position
		+ Vector3(
			0.0,
			-symbol_y_offset,
			body_front_offset + (0.008 if _is_jelly_visual else 0.002)
		)
	)
	_symbol_mesh.rotation = Vector3.ZERO
	var symbol_size_m: float = radius_m * OrbSymbols.SYMBOL_SIZE_FACTOR * (
		0.42 if _is_jelly_visual else 1.0
	)
	_symbol_mesh.scale = Vector3(symbol_size_m, symbol_size_m, 1.0)
