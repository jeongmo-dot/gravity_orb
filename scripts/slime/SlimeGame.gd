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
@onready var _view: Variant = %SlimeView
@onready var _hud: Variant = %SlimeHud

var _sim: SlimeSim
var _accumulator: float = 0.0


func _ready() -> void:
	_sim = SlimeSim.new(slime_config, _seed_from_arguments(), true, true)
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
	_content.position = (viewport_size - CONTENT_SIZE * CONTENT_SCALE) * 0.5


func _seed_from_arguments() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SEED_PREFIX):
			return argument.trim_prefix(SEED_PREFIX).to_int()
	return 0
