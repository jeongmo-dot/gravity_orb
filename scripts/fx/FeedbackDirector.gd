class_name FeedbackDirector
extends Node

const BLAST_RING_DURATION: float = 0.35
const SECOND_RING_DELAY: float = 0.08
const BLAST_LIGHT_DURATION: float = 0.20
const DEBRIS_LIFETIME: float = 0.72
const WHITE_SPARK_COUNT: int = 16
const MERGE_PARTICLE_COUNT: int = 10
const FINALE_INTENSITY: float = 0.6
const COLOR_JACKPOT_INTENSITY: float = 1.5
const COLOR_SHAKE_DURATION: float = 0.25
const COLOR_SHAKE_DISTANCE_PX: float = 6.0

var _game_manager: Variant
var _board: Variant
var _camera: Camera3D
var _sfx_bank: SfxBank
var _haptics: Haptics
var _effects_root: Node3D
var _overlay: CanvasLayer
var _effects: Array[Dictionary] = []
var _active_color_effects: Array[ColorEffectVisual] = []
var _color_effect_pool: Array[ColorEffectVisual] = []
var _active_swipe_trails: Array[SwipeTrail] = []
var _swipe_trail_pool: Array[SwipeTrail] = []
var _color_frame_shakes: Array[Dictionary] = []
var _shake_elapsed: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength_m: float = 0.0
var _hitstop_generation: int = 0
var _finale_sfx_index: int = 0


func _ready() -> void:
	_camera = get_parent().get_node_or_null("Camera3D") as Camera3D
	_sfx_bank = get_node_or_null("SfxBank") as SfxBank
	if _sfx_bank == null:
		_sfx_bank = SfxBank.new()
		_sfx_bank.name = "SfxBank"
		add_child(_sfx_bank)
	_haptics = Haptics.new()
	_haptics.name = "Haptics"
	add_child(_haptics)
	_effects_root = Node3D.new()
	_effects_root.name = "FeedbackEffects"
	add_child(_effects_root)
	if _camera != null:
		_overlay = CanvasLayer.new()
		_overlay.name = "FeedbackOverlay"
		_overlay.layer = 0
		add_child(_overlay)
	set_process(true)


func _exit_tree() -> void:
	_hitstop_generation += 1
	Engine.time_scale = 1.0
	_reset_camera()
	_reset_color_frame()


func bind(game_manager: Variant, board: Variant) -> void:
	_game_manager = game_manager
	_board = board
	if not game_manager.reaction_ready.is_connected(_on_reaction_ready):
		game_manager.reaction_ready.connect(_on_reaction_ready)
	if not game_manager.turn_started.is_connected(_on_turn_started):
		game_manager.turn_started.connect(_on_turn_started)


func _on_reaction_ready(reaction: Dictionary) -> void:
	_play_reaction_sfx(reaction)
	_play_reaction_haptics(reaction)
	call_deferred("play_reaction_visuals", reaction.duplicate())


func play_reaction(reaction: Dictionary) -> void:
	_play_reaction_sfx(reaction)
	_play_reaction_haptics(reaction)
	play_reaction_visuals(reaction)


func _on_turn_started(_turn_index: int, direction: Vector2i) -> void:
	_sfx_bank.play_swipe()
	_haptics.play_swipe()
	if (
		not Config.data.fx_enabled
		or not Config.data.fx_swipe_trail_enabled
		or _camera == null
	):
		return
	var trail: SwipeTrail = _acquire_swipe_trail()
	trail.play(direction, Config.data.board_size)
	_active_swipe_trails.append(trail)


func play_reaction_visuals(reaction: Dictionary) -> void:
	var reaction_type: ReactionRules.Type = reaction["type"] as ReactionRules.Type
	var finale: bool = bool(reaction.get("finale", false))
	if reaction_type == ReactionRules.Type.MERGE:
		_play_merge_feedback(reaction)
		return
	if (
		reaction_type != ReactionRules.Type.BLAST
		and reaction_type != ReactionRules.Type.MAX_CLEAR
	):
		return
	if not Config.data.fx_enabled or _camera == null:
		return
	var level: int = _effect_level(reaction)
	var intensity: float = FINALE_INTENSITY if finale else 1.0
	_play_blast_feedback(reaction, level, intensity)
	if reaction_type == ReactionRules.Type.MAX_CLEAR:
		_play_color_effect_visual(reaction, COLOR_JACKPOT_INTENSITY)
	if not finale and Config.data.fx_hitstop_enabled:
		var hitstop_time: float = (
			0.10
			if reaction_type == ReactionRules.Type.MAX_CLEAR
			else Config.data.fx_hitstop_time
		)
		begin_hitstop(hitstop_time)


func _play_reaction_sfx(reaction: Dictionary) -> void:
	var reaction_type: ReactionRules.Type = reaction["type"] as ReactionRules.Type
	if reaction_type == ReactionRules.Type.MERGE:
		var result_orb: Variant = reaction.get("result_orb")
		var stable_spawn_id: int = 0
		if is_instance_valid(result_orb):
			stable_spawn_id = int(result_orb.stable_spawn_id)
		_sfx_bank.play_merge(
			int(reaction.get("result_level", 2)),
			maxi(int(reaction.get("chain", reaction.get("combo", 1))), 1),
			stable_spawn_id,
			int(reaction.get("reaction_applied_usec", 0)),
			int(reaction.get("reaction_physics_frame", -1)),
			int(reaction.get("reaction_process_frame", -1))
		)
		return
	if (
		reaction_type != ReactionRules.Type.BLAST
		and reaction_type != ReactionRules.Type.MAX_CLEAR
	):
		return
	var finale: bool = bool(reaction.get("finale", false))
	if finale:
		_finale_sfx_index = int(reaction.get("finale_index", _finale_sfx_index + 1))
	else:
		_finale_sfx_index = 0
	_sfx_bank.play_blast(
		finale,
		maxi(_finale_sfx_index, 1),
		int(reaction.get("reaction_applied_usec", 0)),
		int(reaction.get("reaction_physics_frame", -1)),
		int(reaction.get("reaction_process_frame", -1))
	)


func _play_reaction_haptics(reaction: Dictionary) -> void:
	var reaction_type: ReactionRules.Type = reaction["type"] as ReactionRules.Type
	if reaction_type in [ReactionRules.Type.BLAST, ReactionRules.Type.MAX_CLEAR]:
		_haptics.play_blast()


func begin_hitstop(duration: float) -> void:
	if not Config.data.fx_hitstop_enabled or duration <= 0.0:
		return
	_hitstop_generation += 1
	var generation: int = _hitstop_generation
	Engine.time_scale = Config.data.fx_hitstop_scale
	_release_hitstop_after(duration, generation)


func _release_hitstop_after(duration: float, generation: int) -> void:
	await get_tree().create_timer(duration, true, false, true).timeout
	if generation == _hitstop_generation:
		Engine.time_scale = 1.0


func active_ring_count() -> int:
	return get_tree().get_nodes_in_group(&"feedback_ring").size()


func active_particle_count() -> int:
	return get_tree().get_nodes_in_group(&"feedback_particles").size()


func active_light_count() -> int:
	return get_tree().get_nodes_in_group(&"feedback_light").size()


func active_flash_count() -> int:
	return get_tree().get_nodes_in_group(&"feedback_flash").size()


func active_color_effect_count() -> int:
	return _active_color_effects.size()


func color_effect_pool_count() -> int:
	return _color_effect_pool.size()


func active_swipe_trail_count() -> int:
	return _active_swipe_trails.size()


func swipe_trail_pool_count() -> int:
	return _swipe_trail_pool.size()


func active_swipe_trails() -> Array[SwipeTrail]:
	return _active_swipe_trails.duplicate()


func active_color_effects() -> Array[ColorEffectVisual]:
	return _active_color_effects.duplicate()


func active_color_frame_shake_count() -> int:
	return _color_frame_shakes.size()


func color_effect_mode_for_color(color: int) -> GameConfig.ShockMode:
	if color < 0 or color >= Config.data.shock_color_modes.size():
		return GameConfig.ShockMode.PUSH
	return int(Config.data.shock_color_modes[color]) as GameConfig.ShockMode


func sfx_bank() -> SfxBank:
	return _sfx_bank


func haptics() -> Haptics:
	return _haptics


func clear_effects() -> void:
	for effect: Dictionary in _effects:
		var node: Node = effect.get("node") as Node
		if is_instance_valid(node):
			node.queue_free()
	_effects.clear()
	for color_effect: ColorEffectVisual in _active_color_effects.duplicate():
		_release_color_effect(color_effect)
	for trail: SwipeTrail in _active_swipe_trails.duplicate():
		_release_swipe_trail(trail)
	_color_frame_shakes.clear()
	_reset_camera()
	_reset_color_frame()


func _process(delta: float) -> void:
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	_update_shake(real_delta)
	_update_color_effects(real_delta)
	_update_swipe_trails(real_delta)
	_update_color_frame_shakes(real_delta)
	for index: int in range(_effects.size() - 1, -1, -1):
		var effect: Dictionary = _effects[index]
		effect["elapsed"] = float(effect["elapsed"]) + real_delta
		var elapsed: float = float(effect["elapsed"])
		var delay: float = float(effect.get("delay", 0.0))
		var duration: float = float(effect["duration"])
		var node: Node = effect.get("node") as Node
		if not is_instance_valid(node):
			_effects.remove_at(index)
			continue
		if elapsed < delay:
			if node is Node3D:
				(node as Node3D).visible = false
			continue
		if node is Node3D:
			(node as Node3D).visible = true
		var progress: float = clampf((elapsed - delay) / duration, 0.0, 1.0)
		_update_effect(effect, progress)
		if progress >= 1.0:
			node.queue_free()
			_effects.remove_at(index)
		else:
			_effects[index] = effect


func _play_merge_feedback(reaction: Dictionary) -> void:
	var result_orb: Variant = reaction.get("result_orb")
	if is_instance_valid(result_orb):
		var color_mode: GameConfig.ShockMode = color_effect_mode_for_color(
			int(reaction.get("result_color", 0))
		)
		if (
			_color_effect_visuals_enabled()
			and color_mode == GameConfig.ShockMode.PULL
			and result_orb.has_method("play_visual_pull_punch")
		):
			result_orb.play_visual_pull_punch(ColorEffectVisual.PUSH_PULL_DURATION)
		elif result_orb.has_method("play_visual_punch"):
			result_orb.play_visual_punch(1.18, 0.14)
	if not Config.data.fx_enabled or _camera == null:
		return
	var color_index: int = int(reaction.get("result_color", 0))
	var color_value: Color = Config.data.color_display[color_index]
	_create_particles(
		reaction.get("position", Vector2.ZERO) as Vector2,
		color_value,
		MERGE_PARTICLE_COUNT,
		1.0,
		"MergeDebris"
	)
	_play_color_effect_visual(reaction)


func _play_color_effect_visual(
	reaction: Dictionary,
	visual_intensity: float = 1.0
) -> void:
	if not _color_effect_visuals_enabled() or _camera == null:
		return
	var reaction_type: ReactionRules.Type = reaction.get(
		"type", ReactionRules.Type.NONE
	) as ReactionRules.Type
	if reaction_type not in [ReactionRules.Type.MERGE, ReactionRules.Type.MAX_CLEAR]:
		return
	var color_index: int = clampi(
		int(reaction.get("result_color", 0)),
		0,
		Config.data.color_display.size() - 1
	)
	var color_mode: GameConfig.ShockMode = color_effect_mode_for_color(color_index)
	var level: int = (
		Config.data.orb_max_level
		if reaction_type == ReactionRules.Type.MAX_CLEAR
		else clampi(int(reaction.get("result_level", 1)), 1, Config.data.orb_max_level)
	)
	var result_radius_px: float = Config.data.radius_for_level(level)
	var level_scale: float = 1.0 + Config.data.shock_level_scale * float(level - 1)
	var radius_factor: float = Config.data.shock_radius_factor
	if color_index < Config.data.shock_color_radius_factor.size():
		radius_factor = Config.data.shock_color_radius_factor[color_index]
	var effect_radius_px: float = result_radius_px * radius_factor
	if color_mode == GameConfig.ShockMode.SHAKE:
		effect_radius_px = Config.data.board_size * 0.5
	var strength_scale: float = level_scale
	if color_mode == GameConfig.ShockMode.SHAKE:
		strength_scale = (
			minf(
				Config.data.green_shake_speed * level_scale,
				Config.data.green_shake_max_speed
			)
			/ maxf(Config.data.green_shake_speed, 0.001)
		)
	elif color_index < Config.data.shock_color_impulse_scale.size():
		strength_scale *= Config.data.shock_color_impulse_scale[color_index]
	var gravity_direction: Vector2 = Vector2.DOWN
	if _board != null:
		var board_gravity: Variant = _board.get("_gravity_direction")
		if board_gravity != null:
			gravity_direction = Vector2(board_gravity).normalized()
	var effect: ColorEffectVisual = _acquire_color_effect()
	effect.play(
		color_mode,
		reaction.get("position", Vector2.ZERO) as Vector2,
		Config.data.color_display[color_index],
		result_radius_px,
		effect_radius_px,
		visual_intensity * strength_scale,
		-gravity_direction,
		reaction.get("shock_targets", []) as Array
	)
	_active_color_effects.append(effect)
	if color_mode == GameConfig.ShockMode.SHAKE:
		_color_frame_shakes.append({"elapsed": 0.0, "duration": COLOR_SHAKE_DURATION})


func _color_effect_visuals_enabled() -> bool:
	return (
		Config.data.fx_enabled
		and Config.data.color_effects_enabled
		and Config.data.fx_color_effect_visuals_enabled
	)


func _acquire_color_effect() -> ColorEffectVisual:
	if not _color_effect_pool.is_empty():
		return _color_effect_pool.pop_back()
	var effect: ColorEffectVisual = ColorEffectVisual.new()
	effect.name = "ColorEffectVisual%d" % (
		_active_color_effects.size() + _color_effect_pool.size()
	)
	_effects_root.add_child(effect)
	return effect


func _release_color_effect(effect: ColorEffectVisual) -> void:
	effect.deactivate()
	_active_color_effects.erase(effect)
	if not _color_effect_pool.has(effect):
		_color_effect_pool.append(effect)


func _acquire_swipe_trail() -> SwipeTrail:
	if not _swipe_trail_pool.is_empty():
		return _swipe_trail_pool.pop_back()
	var trail: SwipeTrail = SwipeTrail.new()
	trail.name = "SwipeTrail%d" % (
		_active_swipe_trails.size() + _swipe_trail_pool.size()
	)
	_effects_root.add_child(trail)
	return trail


func _release_swipe_trail(trail: SwipeTrail) -> void:
	trail.deactivate()
	_active_swipe_trails.erase(trail)
	if not _swipe_trail_pool.has(trail):
		_swipe_trail_pool.append(trail)


func _update_swipe_trails(delta: float) -> void:
	for index: int in range(_active_swipe_trails.size() - 1, -1, -1):
		var trail: SwipeTrail = _active_swipe_trails[index]
		if trail.advance(delta):
			_release_swipe_trail(trail)


func _update_color_effects(delta: float) -> void:
	for index: int in range(_active_color_effects.size() - 1, -1, -1):
		var effect: ColorEffectVisual = _active_color_effects[index]
		if effect.advance(delta):
			_release_color_effect(effect)


func _update_color_frame_shakes(delta: float) -> void:
	var offset_px: Vector2 = Vector2.ZERO
	for index: int in range(_color_frame_shakes.size() - 1, -1, -1):
		var shake: Dictionary = _color_frame_shakes[index]
		shake["elapsed"] = float(shake["elapsed"]) + delta
		var duration: float = float(shake["duration"])
		var progress: float = clampf(float(shake["elapsed"]) / duration, 0.0, 1.0)
		if progress >= 1.0:
			_color_frame_shakes.remove_at(index)
			continue
		var direction: Vector2 = Vector2(
			sin(progress * TAU * 3.0),
			cos(progress * TAU * 4.0)
		).normalized()
		offset_px += direction * COLOR_SHAKE_DISTANCE_PX * (1.0 - progress)
		_color_frame_shakes[index] = shake
	_set_color_frame_offset(offset_px.limit_length(COLOR_SHAKE_DISTANCE_PX))


func _set_color_frame_offset(offset_px: Vector2) -> void:
	var frame: Node = _color_frame_node()
	if frame is Node3D:
		(frame as Node3D).position = Orb3D.plane_vector_to_world(offset_px)
	elif frame is Node2D:
		(frame as Node2D).position = offset_px


func _reset_color_frame() -> void:
	_set_color_frame_offset(Vector2.ZERO)


func _color_frame_node() -> Node:
	if _board == null:
		return null
	if _board is Node3D:
		return (_board as Node3D).get_node_or_null("VisualTilt")
	if _board is Node2D:
		return (_board as Node2D).get_node_or_null("Frame")
	return null


func _play_blast_feedback(
	reaction: Dictionary,
	level: int,
	intensity: float
) -> void:
	var origin: Vector2 = reaction.get("position", Vector2.ZERO) as Vector2
	var level_scale: float = maxf(1.0, 1.0 + 0.25 * float(level - 4))
	var radius_m: float = (
		Config.data.fx_ring_radius_factor
		* Config.data.radius_for_level(level)
		/ Orb3D.PIXELS_PER_METER
		* intensity
	)
	var colors: Array = reaction.get("colors", []) as Array
	var mixed_color: Color = _mixed_color(colors)
	_create_ring(origin, Color.WHITE, radius_m, 0.0)
	_create_ring(origin, mixed_color, radius_m, SECOND_RING_DELAY)
	for color_value: Variant in colors:
		var color_index: int = int(color_value)
		_create_particles(
			origin,
			Config.data.color_display[color_index],
			maxi(roundi(float(Config.data.fx_debris_per_orb) * intensity), 1),
			level_scale,
			"BlastDebris"
		)
	_create_particles(
		origin,
		Color.WHITE,
		maxi(roundi(float(WHITE_SPARK_COUNT) * intensity), 1),
		level_scale,
		"BlastSparks"
	)
	_create_light(origin, level_scale * intensity)
	_create_flash(intensity)
	_shake_elapsed = 0.0
	_shake_duration = maxf(Config.data.fx_shake_time * intensity, 0.001)
	_shake_strength_m = (
		Config.data.fx_shake_px / Orb3D.PIXELS_PER_METER * level_scale * intensity
	)


func _create_ring(
	origin: Vector2,
	color_value: Color,
	final_radius: float,
	delay: float
) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "BlastRing"
	ring.add_to_group(&"feedback_ring")
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = 0.86
	mesh.outer_radius = 1.0
	mesh.rings = 48
	mesh.ring_segments = 8
	ring.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color_value
	material.emission_enabled = true
	material.emission = color_value
	ring.material_override = material
	ring.position = Orb3D.plane_position_to_world(origin, 0.45)
	ring.rotation_degrees.x = 90.0
	ring.scale = Vector3.ONE * 0.01
	_effects_root.add_child(ring)
	_effects.append({
		"node": ring,
		"kind": "ring",
		"elapsed": 0.0,
		"duration": BLAST_RING_DURATION,
		"delay": delay,
		"end_scale": final_radius,
		"color": color_value,
		"material": material,
	})


func _create_particles(
	origin: Vector2,
	color_value: Color,
	amount: int,
	level_scale: float,
	node_name: String
) -> void:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.name = node_name
	particles.add_to_group(&"feedback_particles")
	particles.amount = amount
	particles.lifetime = DEBRIS_LIFETIME
	particles.lifetime_randomness = 0.30
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.position = Orb3D.plane_position_to_world(origin, 0.55)
	particles.direction = Vector3.RIGHT
	particles.spread = 180.0
	particles.flatness = 1.0
	particles.initial_velocity_min = 6.0 * level_scale
	particles.initial_velocity_max = 14.0 * level_scale
	particles.gravity = _particle_gravity()
	particles.scale_amount_min = 0.45
	particles.scale_amount_max = 1.0
	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = scale_curve
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = color_value
	material.emission_enabled = true
	material.emission = color_value
	quad.material = material
	particles.mesh = quad
	_effects_root.add_child(particles)
	particles.emitting = true
	_effects.append({
		"node": particles,
		"kind": "particles",
		"elapsed": 0.0,
		"duration": DEBRIS_LIFETIME + 0.20,
	})


func _create_light(origin: Vector2, intensity: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "BlastLight"
	light.add_to_group(&"feedback_light")
	light.position = Orb3D.plane_position_to_world(origin, 1.5)
	light.light_color = Color.WHITE
	light.light_energy = 6.0 * intensity
	light.omni_range = 6.0
	_effects_root.add_child(light)
	_effects.append({
		"node": light,
		"kind": "light",
		"elapsed": 0.0,
		"duration": BLAST_LIGHT_DURATION,
		"start_energy": light.light_energy,
	})


func _create_flash(intensity: float) -> void:
	if _overlay == null:
		return
	var flash: ColorRect = ColorRect.new()
	flash.name = "BlastScreenFlash"
	flash.add_to_group(&"feedback_flash")
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1.0, 1.0, 1.0, Config.data.fx_flash_alpha * intensity)
	_overlay.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effects.append({
		"node": flash,
		"kind": "flash",
		"elapsed": 0.0,
		"duration": maxf(Config.data.fx_flash_time * intensity, 0.001),
		"start_alpha": flash.color.a,
	})


func _update_effect(effect: Dictionary, progress: float) -> void:
	var kind: String = str(effect["kind"])
	if kind == "ring":
		var ring: MeshInstance3D = effect["node"] as MeshInstance3D
		var radius: float = lerpf(0.01, float(effect["end_scale"]), progress)
		ring.scale = Vector3(radius, radius, radius * lerpf(1.0, 0.35, progress))
		var material: StandardMaterial3D = effect["material"] as StandardMaterial3D
		var color_value: Color = effect["color"] as Color
		color_value.a = 1.0 - progress
		material.albedo_color = color_value
		material.emission = Color(color_value.r, color_value.g, color_value.b) * (1.0 - progress)
	elif kind == "light":
		var light: OmniLight3D = effect["node"] as OmniLight3D
		light.light_energy = float(effect["start_energy"]) * (1.0 - progress)
	elif kind == "flash":
		var flash: ColorRect = effect["node"] as ColorRect
		var flash_color: Color = flash.color
		flash_color.a = float(effect["start_alpha"]) * (1.0 - progress)
		flash.color = flash_color


func _update_shake(delta: float) -> void:
	if _camera == null or _shake_duration <= 0.0:
		return
	_shake_elapsed = minf(_shake_elapsed + delta, _shake_duration)
	var progress: float = _shake_elapsed / _shake_duration
	var envelope: float = 1.0 - progress
	_camera.h_offset = sin(progress * TAU * 7.0) * _shake_strength_m * envelope
	_camera.v_offset = cos(progress * TAU * 11.0) * _shake_strength_m * envelope
	if _shake_elapsed >= _shake_duration:
		_shake_duration = 0.0
		_reset_camera()


func _reset_camera() -> void:
	if _camera != null:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0


func _effect_level(reaction: Dictionary) -> int:
	var levels: Array = reaction.get("levels", []) as Array
	var level: int = int(reaction.get("shock_level", 4))
	for level_value: Variant in levels:
		level = maxi(level, int(level_value))
	return clampi(level, 1, Config.data.orb_max_level)


func _mixed_color(colors: Array) -> Color:
	if colors.is_empty():
		return Color.WHITE
	var red: float = 0.0
	var green: float = 0.0
	var blue: float = 0.0
	for color_value: Variant in colors:
		var display: Color = Config.data.color_display[int(color_value)]
		red += display.r
		green += display.g
		blue += display.b
	var divisor: float = float(colors.size())
	return Color(red / divisor, green / divisor, blue / divisor, 1.0)


func _particle_gravity() -> Vector3:
	if _board == null:
		return Vector3.ZERO
	var direction_value: Variant = _board.get("_gravity_direction")
	if direction_value == null:
		return Vector3.ZERO
	var gravity_px: Vector2 = Vector2(direction_value) * Config.data.gravity_strength
	return Orb3D.plane_vector_to_world(gravity_px)
