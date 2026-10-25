class_name FeedbackDirector
extends Node

const BLAST_LIGHT_DURATION: float = 0.20
const DEBRIS_LIFETIME: float = 0.72
const WHITE_SPARK_COUNT: int = 16
const MERGE_STARDUST_COUNT: int = 12
const BIRTH_ACCRETION_COUNT: int = 14
const SUPERNOVA_STAR_COUNT: int = 10
const BIRTH_ACCRETION_DURATION: float = 0.25
const BIRTH_NOVA_DURATION: float = 0.80
const LOCAL_FLASH_DURATION: float = 0.18
const L4_NEBULA_DURATION: float = 0.40
const SUPERNOVA_DURATION: float = 1.20
const FULL_FLASH_WINDOW_MSEC: int = 1000
const FULL_FLASH_LIMIT: int = 3
const FULL_FLASH_MAX_ALPHA: float = 0.15
const PREWARM_PARTICLE_COUNT: int = 23
const PREWARM_LIGHT_COUNT: int = 3
const PREWARM_FLASH_COUNT: int = 3
const PREWARM_GLOW_COUNT: int = 7
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
var _blast_effect_pools: Dictionary = {
	"particles": [],
	"light": [],
	"flash": [],
	"glow": [],
}
var _effect_quad_mesh: QuadMesh
var _effect_glow_shader: Shader
var _effect_particle_shader: Shader
var _resources_prewarmed: bool = false
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
var _full_flash_times_msec: Array[int] = []
var _full_flash_accepted_total: int = 0
var _full_flash_skipped_total: int = 0


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
	_initialize_blast_effect_pool()
	call_deferred("_prewarm_visual_resources_offscreen")
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
	if (
		game_manager is TurnManager
		and not game_manager.state_changed.is_connected(_on_turn_state_changed)
	):
		game_manager.state_changed.connect(_on_turn_state_changed)


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


func _on_turn_state_changed(next_state: int) -> void:
	if next_state != int(TurnManager.State.WAITING_INPUT):
		return
	_sfx_bank.play_turn_ready()
	_haptics.play_turn_ready()


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
	if (
		Config.data.game_mode == GameConfig.GameMode.JELLY
		and reaction_type == ReactionRules.Type.MAX_CLEAR
	):
		var jackpot_origin: Vector2 = reaction.get("position", Vector2.ZERO) as Vector2
		var jackpot_color: int = int(reaction.get("result_color", 0))
		_create_jelly_max_feedback(
			jackpot_origin,
			_display_color(jackpot_color, Config.data.orb_max_level),
			Config.data.radius_for_level(Config.data.orb_max_level) / Orb3D.PIXELS_PER_METER
		)
	else:
		_play_blast_feedback(reaction, level, intensity)
	if reaction_type == ReactionRules.Type.MAX_CLEAR:
		_play_color_effect_visual(reaction, COLOR_JACKPOT_INTENSITY)
	if not finale and _hitstop_enabled_for_mode():
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
	if not _hitstop_enabled_for_mode() or duration <= 0.0:
		return
	_hitstop_generation += 1
	var generation: int = _hitstop_generation
	Engine.time_scale = Config.data.fx_hitstop_scale
	_release_hitstop_after(duration, generation)


func _hitstop_enabled_for_mode() -> bool:
	return Config.data.fx_hitstop_enabled


func _release_hitstop_after(duration: float, generation: int) -> void:
	await get_tree().create_timer(duration, true, false, true).timeout
	if generation == _hitstop_generation:
		Engine.time_scale = 1.0


func active_particle_count() -> int:
	return _active_effect_count("particles")


func active_light_count() -> int:
	return _active_effect_count("light")


func active_flash_count() -> int:
	return _active_effect_count("flash")


func active_glow_count() -> int:
	return _active_effect_count("glow")


func full_screen_flash_count_last_second() -> int:
	_prune_full_flash_history(Time.get_ticks_msec())
	return _full_flash_times_msec.size()


func full_screen_flash_accepted_total() -> int:
	return _full_flash_accepted_total


func full_screen_flash_skipped_total() -> int:
	return _full_flash_skipped_total


func blast_effect_pool_count(kind: String = "") -> int:
	if not kind.is_empty():
		return _effect_pool(kind).size()
	var total: int = 0
	for pool_value: Variant in _blast_effect_pools.values():
		total += (pool_value as Array).size()
	return total


func resources_prewarmed() -> bool:
	return _resources_prewarmed


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
	for effect: Dictionary in _effects.duplicate():
		_release_blast_effect(effect)
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
			_release_blast_effect(effect)
			_effects.remove_at(index)
		else:
			_effects[index] = effect


func _play_merge_feedback(reaction: Dictionary) -> void:
	var result_orb: Variant = reaction.get("result_orb")
	if is_instance_valid(result_orb):
		var color_mode: GameConfig.ShockMode = color_effect_mode_for_color(
			int(reaction.get("result_color", 0))
		)
		if Config.data.game_mode == GameConfig.GameMode.JELLY:
			result_orb.play_visual_punch(1.0, 0.18)
		elif (
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
	var color_value: Color = _display_color(color_index, int(reaction.get("result_level", 1)))
	var origin: Vector2 = reaction.get("position", Vector2.ZERO) as Vector2
	var result_level: int = clampi(
		int(reaction.get("result_level", 2)),
		1,
		Config.data.orb_max_level
	)
	var result_radius_m: float = (
		Config.data.radius_for_level(result_level) / Orb3D.PIXELS_PER_METER
	)
	if is_instance_valid(result_orb) and result_orb.has_method("get_current_radius"):
		result_radius_m = float(result_orb.get_current_radius()) / Orb3D.PIXELS_PER_METER
	if Config.data.game_mode == GameConfig.GameMode.JELLY:
		_create_particles(
			origin,
			color_value,
			MERGE_STARDUST_COUNT,
			1.0,
			"JellyMergeStardust",
			"stardust"
		)
		if bool(reaction.get("jelly_absorption", false)):
			_create_jelly_absorption_trails(reaction, origin)
		if result_level >= Config.data.orb_max_level:
			_create_jelly_max_feedback(origin, color_value, result_radius_m)
	elif result_level <= 5:
		_create_particles(
			origin,
			color_value,
			MERGE_STARDUST_COUNT,
			1.0,
			"MergeStardust",
			"stardust"
		)
	else:
		_create_birth_feedback(origin, color_value, result_level, result_radius_m)
	_play_color_effect_visual(reaction)


func _create_birth_feedback(
	origin: Vector2,
	color_value: Color,
	level: int,
	result_radius_m: float
) -> void:
	var half_count: int = BIRTH_ACCRETION_COUNT / 2
	_create_particles(
		origin,
		color_value,
		half_count,
		1.0,
		"BirthAccretionColor",
		"accretion",
		result_radius_m
	)
	_create_particles(
		origin,
		Color.WHITE,
		BIRTH_ACCRETION_COUNT - half_count,
		1.0,
		"BirthAccretionWhite",
		"accretion",
		result_radius_m
	)
	_create_glow(
		origin,
		Color.WHITE,
		color_value,
		result_radius_m * 2.5,
		BIRTH_ACCRETION_DURATION,
		BIRTH_NOVA_DURATION,
		result_radius_m * 0.48,
		"BirthNova"
	)
	_start_reaction_shake(4, 0.5)


func _create_jelly_max_feedback(
	origin: Vector2,
	color_value: Color,
	radius_m: float
) -> void:
	_create_particles(
		origin,
		Color.WHITE,
		WHITE_SPARK_COUNT,
		1.15,
		"JellyMaxSparkle",
		"stars"
	)
	_create_glow(
		origin,
		Color.WHITE,
		color_value,
		radius_m * 2.0,
		0.0,
		BIRTH_NOVA_DURATION,
		radius_m * 0.72,
		"JellyMaxCloudPulse"
	)


func _create_jelly_absorption_trails(reaction: Dictionary, target: Vector2) -> void:
	var positions: Array = reaction.get("source_positions", []) as Array
	var radii: Array = reaction.get("source_radii", []) as Array
	var colors: Array = reaction.get("colors", []) as Array
	var levels: Array = reaction.get("levels", []) as Array
	for index: int in range(mini(positions.size(), radii.size())):
		var start: Vector2 = positions[index] as Vector2
		if start.distance_squared_to(target) < 1.0:
			continue
		var color_index: int = int(colors[index]) if index < colors.size() else 0
		var source_level: int = int(levels[index]) if index < levels.size() else 1
		_create_jelly_absorption_trail(
			start,
			target,
			float(radii[index]) / Orb3D.PIXELS_PER_METER,
			_display_color(color_index, source_level)
		)


func _create_jelly_absorption_trail(
	start: Vector2,
	target: Vector2,
	radius_m: float,
	color_value: Color
) -> void:
	var glow: MeshInstance3D = _acquire_blast_effect("glow") as MeshInstance3D
	glow.name = "JellyAbsorptionTrail"
	glow.position = Orb3D.plane_position_to_world(start, -0.22)
	glow.scale = Vector3.ONE * radius_m
	var material: ShaderMaterial = glow.material_override as ShaderMaterial
	material.set_shader_parameter("inner_color", color_value.lightened(0.34))
	material.set_shader_parameter("outer_color", color_value)
	material.set_shader_parameter("effect_alpha", 0.82)
	material.set_shader_parameter("noise_seed", float(_effects.size() % 11) * 0.37)
	_effects.append({
		"node": glow,
		"kind": "glow",
		"elapsed": 0.0,
		"duration": 0.24,
		"delay": 0.0,
		"start_scale": radius_m,
		"end_scale": radius_m * 0.36,
		"material": material,
		"motion_start": start,
		"motion_target": target,
	})


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
		_display_color(color_index, level),
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
		Config.data.board_size
		* Config.data.blast_push_radius_factor_for_level(level)
		/ Orb3D.PIXELS_PER_METER
	)
	var colors: Array = reaction.get("colors", []) as Array
	var mixed_color: Color = _mixed_color(colors)
	var nebula_inner: Color = mixed_color
	var nebula_outer: Color = mixed_color
	if not colors.is_empty():
		nebula_inner = _display_color(int(colors[0]), level)
	if colors.size() > 1:
		nebula_outer = _display_color(int(colors[1]), level)
	for color_value: Variant in colors:
		var color_index: int = int(color_value)
		_create_particles(
			origin,
			_display_color(color_index, level),
			maxi(roundi(float(Config.data.fx_debris_per_orb) * intensity), 1),
			level_scale,
			"BlastDebris",
			"debris"
		)
	_create_particles(
		origin,
		Color.WHITE,
		maxi(roundi(float(WHITE_SPARK_COUNT) * intensity), 1),
		level_scale,
		"BlastSparks",
		"debris"
	)
	if level == 4:
		_create_glow(
			origin,
			nebula_inner,
			nebula_outer,
			radius_m,
			0.0,
			L4_NEBULA_DURATION,
			radius_m * 0.24,
			"BlastNebulaL4"
		)
	else:
		_create_glow(
			origin,
			nebula_inner,
			nebula_outer,
			radius_m,
			0.0,
			SUPERNOVA_DURATION,
			radius_m * 0.18,
			"BlastSupernova"
		)
		_create_glow(
			origin,
			Color.WHITE,
			Color.WHITE,
			radius_m * 0.34,
			0.0,
			LOCAL_FLASH_DURATION,
			radius_m * 0.08,
			"BlastLocalFlash"
		)
		_create_particles(
			origin,
			Color.WHITE,
			SUPERNOVA_STAR_COUNT,
			level_scale,
			"BlastTwinklingStars",
			"stars"
		)
	_create_light(origin, level_scale * intensity)
	if level >= 6:
		_create_flash(intensity)
	_start_reaction_shake(level, intensity * (0.5 if level == 4 else 1.0))


func _start_reaction_shake(level: int, intensity: float) -> void:
	var level_scale: float = maxf(1.0, 1.0 + 0.25 * float(level - 4))
	_shake_elapsed = 0.0
	_shake_duration = maxf(Config.data.fx_shake_time * intensity, 0.001)
	_shake_strength_m = (
		Config.data.fx_shake_px / Orb3D.PIXELS_PER_METER * level_scale * intensity
	)


func _create_particles(
	origin: Vector2,
	color_value: Color,
	amount: int,
	level_scale: float,
	node_name: String,
	style: String = "debris",
	emission_radius: float = 0.0
) -> void:
	var particles: CPUParticles3D = _acquire_blast_effect("particles") as CPUParticles3D
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = DEBRIS_LIFETIME
	particles.lifetime_randomness = 0.30
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.position = Orb3D.plane_position_to_world(origin, 0.55)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
	particles.emission_sphere_radius = 0.0
	particles.direction = Vector3.RIGHT
	particles.spread = 180.0
	particles.flatness = 0.0
	particles.initial_velocity_min = 6.0 * level_scale
	particles.initial_velocity_max = 14.0 * level_scale
	particles.radial_accel_min = 0.0
	particles.radial_accel_max = 0.0
	particles.orbit_velocity_min = 0.0
	particles.orbit_velocity_max = 0.0
	particles.gravity = _particle_gravity()
	particles.scale_amount_min = 0.45
	particles.scale_amount_max = 1.0
	if style == "stardust":
		particles.lifetime = 0.72
		particles.lifetime_randomness = 0.18
		particles.initial_velocity_min = 2.5
		particles.initial_velocity_max = 6.0
		particles.gravity = Vector3.ZERO
		particles.scale_amount_min = 0.22
		particles.scale_amount_max = 0.62
	elif style == "accretion":
		particles.lifetime = BIRTH_ACCRETION_DURATION
		particles.lifetime_randomness = 0.05
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = emission_radius * 2.0
		particles.initial_velocity_min = 0.0
		particles.initial_velocity_max = 0.2
		particles.radial_accel_min = -80.0
		particles.radial_accel_max = -58.0
		particles.orbit_velocity_min = 0.75
		particles.orbit_velocity_max = 1.15
		particles.gravity = Vector3.ZERO
		particles.scale_amount_min = 0.30
		particles.scale_amount_max = 0.65
	elif style == "stars":
		particles.lifetime = SUPERNOVA_DURATION
		particles.lifetime_randomness = 0.28
		particles.initial_velocity_min = 1.2 * level_scale
		particles.initial_velocity_max = 4.0 * level_scale
		particles.gravity = Vector3.ZERO
		particles.scale_amount_min = 0.18
		particles.scale_amount_max = 0.72
	var quad: QuadMesh = particles.mesh as QuadMesh
	var material: ShaderMaterial = quad.material as ShaderMaterial
	material.set_shader_parameter("particle_color", color_value)
	particles.restart()
	particles.emitting = true
	_effects.append({
		"node": particles,
		"kind": "particles",
		"elapsed": 0.0,
		"duration": particles.lifetime + 0.20,
	})


func _create_light(origin: Vector2, intensity: float) -> void:
	var light: OmniLight3D = _acquire_blast_effect("light") as OmniLight3D
	light.name = "BlastLight"
	light.position = Orb3D.plane_position_to_world(origin, 1.5)
	light.light_color = Color.WHITE
	light.light_energy = 6.0 * intensity
	light.omni_range = 6.0
	_effects.append({
		"node": light,
		"kind": "light",
		"elapsed": 0.0,
		"duration": BLAST_LIGHT_DURATION,
		"start_energy": light.light_energy,
	})


func _create_glow(
	origin: Vector2,
	inner_color: Color,
	outer_color: Color,
	final_radius: float,
	delay: float,
	duration: float,
	start_radius: float,
	node_name: String
) -> void:
	var glow: MeshInstance3D = _acquire_blast_effect("glow") as MeshInstance3D
	glow.name = node_name
	# Transparent depth testing keeps this layer behind every opaque orb while
	# leaving it above the board glass at z=-0.31.
	glow.position = Orb3D.plane_position_to_world(origin, -0.24)
	glow.scale = Vector3.ONE * start_radius
	var material: ShaderMaterial = glow.material_override as ShaderMaterial
	material.set_shader_parameter("inner_color", inner_color)
	material.set_shader_parameter("outer_color", outer_color)
	material.set_shader_parameter("effect_alpha", 0.0 if delay > 0.0 else 1.0)
	material.set_shader_parameter("noise_seed", float(_effects.size() % 11) * 0.37)
	_effects.append({
		"node": glow,
		"kind": "glow",
		"elapsed": 0.0,
		"duration": duration,
		"delay": delay,
		"start_scale": start_radius,
		"end_scale": final_radius,
		"material": material,
	})


func _create_flash(intensity: float) -> void:
	if _overlay == null:
		return
	var now_msec: int = Time.get_ticks_msec()
	_prune_full_flash_history(now_msec)
	if _full_flash_times_msec.size() >= FULL_FLASH_LIMIT:
		_full_flash_skipped_total += 1
		return
	_full_flash_times_msec.append(now_msec)
	_full_flash_accepted_total += 1
	var flash: ColorRect = _acquire_blast_effect("flash") as ColorRect
	flash.name = "BlastScreenFlash"
	flash.color = Color(
		1.0,
		1.0,
		1.0,
		minf(Config.data.fx_flash_alpha * intensity, FULL_FLASH_MAX_ALPHA)
	)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effects.append({
		"node": flash,
		"kind": "flash",
		"elapsed": 0.0,
		"duration": maxf(Config.data.fx_flash_time * intensity, 0.001),
		"start_alpha": flash.color.a,
	})


func _prune_full_flash_history(now_msec: int) -> void:
	while (
		not _full_flash_times_msec.is_empty()
		and now_msec - _full_flash_times_msec[0] >= FULL_FLASH_WINDOW_MSEC
	):
		_full_flash_times_msec.pop_front()


func _initialize_blast_effect_pool() -> void:
	_effect_quad_mesh = QuadMesh.new()
	_effect_quad_mesh.size = Vector2(2.0, 2.0)
	_effect_glow_shader = _new_effect_glow_shader()
	_effect_particle_shader = _new_effect_particle_shader()
	for _index: int in range(PREWARM_PARTICLE_COUNT):
		_pool_blast_node("particles", _new_particle_node())
	for _index: int in range(PREWARM_LIGHT_COUNT):
		_pool_blast_node("light", _new_light_node())
	if _overlay != null:
		for _index: int in range(PREWARM_FLASH_COUNT):
			_pool_blast_node("flash", _new_flash_node())
	for _index: int in range(PREWARM_GLOW_COUNT):
		_pool_blast_node("glow", _new_glow_node())


func _new_particle_node() -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.emitting = false
	particles.lifetime = DEBRIS_LIFETIME
	particles.lifetime_randomness = 0.30
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.RIGHT
	particles.spread = 180.0
	particles.flatness = 0.0
	particles.scale_amount_min = 0.45
	particles.scale_amount_max = 1.0
	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = scale_curve
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _effect_particle_shader
	quad.material = material
	particles.mesh = quad
	_effects_root.add_child(particles)
	return particles


func _new_light_node() -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color.WHITE
	light.omni_range = 6.0
	_effects_root.add_child(light)
	return light


func _new_flash_node() -> ColorRect:
	var flash: ColorRect = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return flash


func _new_glow_node() -> MeshInstance3D:
	var glow: MeshInstance3D = MeshInstance3D.new()
	glow.mesh = _effect_quad_mesh
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _effect_glow_shader
	glow.material_override = material
	_effects_root.add_child(glow)
	return glow


func _new_effect_glow_shader() -> Shader:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 inner_color : source_color = vec4(1.0);
uniform vec4 outer_color : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform float effect_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float noise_seed = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32 + noise_seed);
	return fract(p.x * p.y);
}

float value_noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float radius = length(p);
	float coarse = value_noise2(p * 3.1 + vec2(noise_seed, -noise_seed * 0.7));
	float fine = value_noise2(p * 7.3 + vec2(8.4 - noise_seed, 3.7 + noise_seed));
	float mottle = coarse * 0.68 + fine * 0.32;
	float soft_cloud = (1.0 - smoothstep(0.04, 0.96, radius)) * 0.09;
	float mask = soft_cloud * mix(0.72, 1.0, mottle);
	vec3 color = mix(inner_color.rgb, outer_color.rgb, smoothstep(0.24, 0.76, mottle));
	ALBEDO = color;
	EMISSION = color * 0.62;
	ALPHA = mask * effect_alpha;
}
"""
	return shader


func _new_effect_particle_shader() -> Shader:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 particle_color : source_color = vec4(1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
}
void fragment() {
	vec2 p = abs(UV * 2.0 - vec2(1.0));
	float radius = length(p);
	float core = 1.0 - smoothstep(0.18, 0.66, radius);
	float ray_x = (1.0 - smoothstep(0.05, 0.18, p.y)) * (1.0 - smoothstep(0.35, 1.0, p.x));
	float ray_y = (1.0 - smoothstep(0.05, 0.18, p.x)) * (1.0 - smoothstep(0.35, 1.0, p.y));
	float mask = max(core, max(ray_x, ray_y) * 0.82);
	ALBEDO = particle_color.rgb;
	EMISSION = particle_color.rgb * (1.2 + core);
	ALPHA = mask * particle_color.a;
}
"""
	return shader


func _acquire_blast_effect(kind: String) -> Node:
	var pool: Array = _effect_pool(kind)
	var node: Node
	if not pool.is_empty():
		node = pool.pop_back() as Node
	else:
		match kind:
			"particles":
				node = _new_particle_node()
			"light":
				node = _new_light_node()
			"flash":
				node = _new_flash_node()
			"glow":
				node = _new_glow_node()
	_set_effect_node_visible(node, true)
	var group_name: StringName = _effect_group(kind)
	if not node.is_in_group(group_name):
		node.add_to_group(group_name)
	return node


func _release_blast_effect(effect: Dictionary) -> void:
	var node: Node = effect.get("node") as Node
	var kind: String = str(effect.get("kind", ""))
	if not is_instance_valid(node) or not _blast_effect_pools.has(kind):
		return
	if node is CPUParticles3D:
		(node as CPUParticles3D).emitting = false
	var group_name: StringName = _effect_group(kind)
	if node.is_in_group(group_name):
		node.remove_from_group(group_name)
	_pool_blast_node(kind, node)


func _pool_blast_node(kind: String, node: Node) -> void:
	_set_effect_node_visible(node, false)
	var pool: Array = _effect_pool(kind)
	if not pool.has(node):
		pool.append(node)


func _set_effect_node_visible(node: Node, visible_value: bool) -> void:
	if node is Node3D:
		(node as Node3D).visible = visible_value
	elif node is CanvasItem:
		(node as CanvasItem).visible = visible_value


func _effect_pool(kind: String) -> Array:
	return _blast_effect_pools[kind] as Array


func _effect_group(kind: String) -> StringName:
	match kind:
		"particles":
			return &"feedback_particles"
		"light":
			return &"feedback_light"
		"flash":
			return &"feedback_flash"
		"glow":
			return &"feedback_glow"
		_:
			return &"feedback_effect"


func _active_effect_count(kind: String) -> int:
	var count: int = 0
	for effect: Dictionary in _effects:
		if str(effect.get("kind", "")) == kind:
			count += 1
	return count


func _prewarm_visual_resources_offscreen(force_render_path: bool = false) -> void:
	Orb3D.prewarm_shared_resources(Config.data)
	if not is_inside_tree():
		return
	if DisplayServer.get_name() == "headless" and not force_render_path:
		_resources_prewarmed = true
		return
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	var viewport: SubViewport = SubViewport.new()
	viewport.name = "VisualResourcePrewarmer"
	viewport.size = Vector2i(64, 64)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var prewarm_root: Node3D = Node3D.new()
	viewport.add_child(prewarm_root)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	camera.position = Vector3(0.0, 0.0, 10.0)
	camera.current = true
	prewarm_root.add_child(camera)
	var combination_index: int = 0
	for color_index: int in range(Config.data.color_display.size()):
		for level_index: int in range(1, Config.data.orb_max_level + 1):
			var mesh_instance: MeshInstance3D = MeshInstance3D.new()
			mesh_instance.mesh = Orb3D.shared_mesh_for_level(Config.data, level_index)
			mesh_instance.material_override = Orb3D.shared_visual_material_for_color(
				Config.data,
				color_index,
				level_index
			)
			mesh_instance.position = Vector3(
				float(combination_index % 7) - 3.0,
				float(combination_index / 7) - 2.5,
				0.0
			)
			mesh_instance.scale = Vector3.ONE * 0.15
			prewarm_root.add_child(mesh_instance)
			combination_index += 1
	var particle_pool: Array = _effect_pool("particles")
	if not particle_pool.is_empty():
		var pooled_particles: CPUParticles3D = particle_pool[0] as CPUParticles3D
		var particle_sample: MeshInstance3D = MeshInstance3D.new()
		particle_sample.mesh = pooled_particles.mesh
		particle_sample.position = Vector3(4.0, 4.0, 0.0)
		prewarm_root.add_child(particle_sample)
	var glow_pool: Array = _effect_pool("glow")
	if not glow_pool.is_empty():
		var pooled_glow: MeshInstance3D = glow_pool[0] as MeshInstance3D
		var glow_sample: MeshInstance3D = MeshInstance3D.new()
		glow_sample.mesh = pooled_glow.mesh
		glow_sample.material_override = pooled_glow.material_override
		glow_sample.position = Vector3(0.0, 4.0, 0.0)
		prewarm_root.add_child(glow_sample)
	var color_effects: Array[ColorEffectVisual] = []
	for mode_value: int in range(4):
		var color_effect: ColorEffectVisual = ColorEffectVisual.new()
		prewarm_root.add_child(color_effect)
		color_effects.append(color_effect)
	await scene_tree.process_frame
	if not is_inside_tree():
		return
	var lift_targets: Array[Dictionary] = [{"position": Vector2(20.0, 20.0)}]
	for mode_value: int in range(color_effects.size()):
		color_effects[mode_value].play(
			mode_value as GameConfig.ShockMode,
			Vector2.ZERO,
			Config.data.color_display[mode_value % Config.data.color_display.size()],
			25.0,
			100.0,
			1.0,
			Vector2.UP,
			lift_targets
		)
	await RenderingServer.frame_post_draw
	if not is_inside_tree() or not is_instance_valid(viewport):
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.queue_free()
	_resources_prewarmed = true


func _update_effect(effect: Dictionary, progress: float) -> void:
	var kind: String = str(effect["kind"])
	if kind == "light":
		var light: OmniLight3D = effect["node"] as OmniLight3D
		light.light_energy = float(effect["start_energy"]) * (1.0 - progress)
	elif kind == "flash":
		var flash: ColorRect = effect["node"] as ColorRect
		var flash_color: Color = flash.color
		flash_color.a = float(effect["start_alpha"]) * (1.0 - progress)
		flash.color = flash_color
	elif kind == "glow":
		var glow: MeshInstance3D = effect["node"] as MeshInstance3D
		if effect.has("motion_start"):
			var start: Vector2 = effect["motion_start"] as Vector2
			var target: Vector2 = effect["motion_target"] as Vector2
			var eased: float = 1.0 - pow(1.0 - progress, 3.0)
			glow.position = Orb3D.plane_position_to_world(start.lerp(target, eased), -0.22)
		var glow_radius: float = lerpf(
			float(effect["start_scale"]),
			float(effect["end_scale"]),
			1.0 - pow(1.0 - progress, 2.0)
		)
		glow.scale = Vector3.ONE * glow_radius
		var glow_material: ShaderMaterial = effect["material"] as ShaderMaterial
		var alpha: float = (
			smoothstep(0.0, 0.12, progress)
			* (1.0 - smoothstep(0.42, 1.0, progress))
		)
		glow_material.set_shader_parameter("effect_alpha", alpha)


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
		var display: Color = _display_color(int(color_value), 1)
		red += display.r
		green += display.g
		blue += display.b
	var divisor: float = float(colors.size())
	return Color(red / divisor, green / divisor, blue / divisor, 1.0)


func _display_color(color_index: int, level: int = 1) -> Color:
	if Config.data.game_mode == GameConfig.GameMode.JELLY:
		return JellyOrbArt.color_for(color_index, level)
	return Config.data.color_display[color_index]


func _particle_gravity() -> Vector3:
	if _board == null:
		return Vector3.ZERO
	var direction_value: Variant = _board.get("_gravity_direction")
	if direction_value == null:
		return Vector3.ZERO
	var gravity_px: Vector2 = Vector2(direction_value) * Config.data.gravity_strength
	return Orb3D.plane_vector_to_world(gravity_px)
