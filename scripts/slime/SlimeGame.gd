class_name SlimeGame
extends Node2D

const FIXED_DELTA: float = 1.0 / 60.0
const MAX_STEPS_PER_FRAME: int = 4
const CONTENT_SIZE: Vector2 = Vector2(640.0, 920.0)
const CONTENT_SCALE: float = 1.6875
const SEED_PREFIX: String = "--jolt-seed="

@export var slime_config: SlimeConfig = preload("res://config/slime_config.tres")

@onready var _background: ColorRect = %Background
@onready var _content: Node2D = %Content
@onready var _view: SlimeView = %SlimeView
@onready var _hud: SlimeHud = %SlimeHud
@onready var _sfx: SfxBank = %SfxBank

var _sim: SlimeSim
var _accumulator: float = 0.0
var _content_base_position: Vector2 = Vector2.ZERO
var _shake_offset: Vector2 = Vector2.ZERO
var _shake_strength: float = 0.0
var _shake_left: float = 0.0
var _shake_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_sim = SlimeSim.new(slime_config, _seed_from_arguments(), true, true)
	_shake_rng.seed = _sim.get_seed_used() ^ 0x51A3E
	_view.bind(_sim)
	_hud.bind(_sim)
	if not InputRouter.swipe.is_connected(_on_swipe):
		InputRouter.swipe.connect(_on_swipe)
	if not InputRouter.restart_requested.is_connected(_on_restart_requested):
		InputRouter.restart_requested.connect(_on_restart_requested)
	if not get_viewport().size_changed.is_connected(_layout_content):
		get_viewport().size_changed.connect(_layout_content)
	InputRouter.set_accept_release_after_unlock(true)
	_layout_content()
	_consume_events()
	_sync_input_lock()


func _exit_tree() -> void:
	InputRouter.set_accept_release_after_unlock(false)
	if InputRouter.swipe.is_connected(_on_swipe):
		InputRouter.swipe.disconnect(_on_swipe)
	if InputRouter.restart_requested.is_connected(_on_restart_requested):
		InputRouter.restart_requested.disconnect(_on_restart_requested)


func _physics_process(delta: float) -> void:
	advance_elapsed(delta)


func advance_elapsed(delta: float) -> void:
	_accumulator += maxf(delta, 0.0)
	var steps: int = 0
	while _accumulator >= FIXED_DELTA and steps < MAX_STEPS_PER_FRAME:
		_sim.step(FIXED_DELTA)
		_consume_events()
		_view.advance_visuals(FIXED_DELTA)
		_hud.advance_visuals(FIXED_DELTA)
		_advance_shake(FIXED_DELTA)
		_accumulator -= FIXED_DELTA
		steps += 1
	if steps >= MAX_STEPS_PER_FRAME and _accumulator >= FIXED_DELTA:
		_accumulator = fmod(_accumulator, FIXED_DELTA)
	if steps > 0:
		refresh_presentation()
		_sync_input_lock()


func get_sim() -> SlimeSim:
	return _sim


func refresh_presentation() -> void:
	_consume_events()
	_view.refresh()
	_hud.refresh()


func _on_swipe(direction: Vector2i) -> void:
	if _sim.start_turn(direction):
		refresh_presentation()
		_sync_input_lock()


func _on_restart_requested() -> void:
	get_tree().reload_current_scene()


func _sync_input_lock() -> void:
	InputRouter.set_locked(_sim.moving or _sim.game_over)


func _layout_content() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_background.position = Vector2.ZERO
	_background.size = viewport_size
	_content.scale = Vector2.ONE * CONTENT_SCALE
	_content_base_position = (viewport_size - CONTENT_SIZE * CONTENT_SCALE) * 0.5
	_content.position = _content_base_position + _shake_offset


func _consume_events() -> void:
	var events: Array[Dictionary] = _sim.drain_events()
	if events.is_empty():
		return
	_view.handle_events(events)
	_hud.handle_events(events)
	for event: Dictionary in events:
		var event_type: String = str(event.get("type", ""))
		match event_type:
			"turn_started":
				_sfx.play_slime_gravity()
			"collision":
				_sfx.play_slime_impact(float(event.get("impact", 0.0)))
			"absorbed":
				if bool(event.get("reached_max", false)):
					_sfx.play_slime_max(int(event.get("chain", 0)))
				else:
					_sfx.play_slime_merge(int(event.get("chain", 0)))
			"max_completed":
				_start_shake(4.0, 0.16)
			"max_clear":
				_sfx.play_slime_clear()
				_start_shake(9.0, 0.34)
			"game_over":
				_sfx.play_slime_game_over()
				_start_shake(5.0, 0.24)
	_view.refresh()
	_hud.refresh()


func _start_shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_left = maxf(_shake_left, duration)


func _advance_shake(delta: float) -> void:
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		_shake_offset = Vector2(
			_shake_rng.randf_range(-_shake_strength, _shake_strength),
			_shake_rng.randf_range(-_shake_strength, _shake_strength)
		)
		_shake_strength = lerpf(_shake_strength, 0.0, minf(delta * 9.0, 1.0))
	else:
		_shake_offset = _shake_offset.lerp(Vector2.ZERO, minf(delta * 18.0, 1.0))
		if _shake_offset.length_squared() < 0.0001:
			_shake_offset = Vector2.ZERO
	_content.position = _content_base_position + _shake_offset


func _seed_from_arguments() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SEED_PREFIX):
			return argument.trim_prefix(SEED_PREFIX).to_int()
	return 0
