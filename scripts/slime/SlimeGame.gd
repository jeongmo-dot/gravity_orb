class_name SlimeGame
extends Node2D

signal slime_game_over_committed(result: Dictionary)

const FIXED_DELTA: float = 1.0 / 60.0
const MAX_STEPS_PER_FRAME: int = 4
const CONTENT_SIZE: Vector2 = Vector2(640.0, 920.0)
const CONTENT_SCALE: float = 1.6875
const SEED_PREFIX: String = "--jolt-seed="
const MAIN_SCENE_PATH: String = "res://scenes/Main3D.tscn"
const UI_SCENE: PackedScene = preload("res://scenes/UI.tscn")
const UI_THEME: Theme = preload("res://assets/ui/gravity_orb_theme.tres")
const SPEAKER_ON: Texture2D = preload("res://assets/ui/speaker_on.svg")
const SPEAKER_OFF: Texture2D = preload("res://assets/ui/speaker_off.svg")

@export var slime_config: SlimeConfig = preload("res://config/slime_config.tres")
@export var save_path: String = "user://save.cfg"
@export var shell_enabled: bool = true

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
var _shell_layer: CanvasLayer
var _shell_root: Control
var _turn_indicator: TurnInputIndicator
var _game_over_panel: GameOverPanel
var _ranking_panel: RankingPanel
var _result_dimmer: ColorRect
var _sound_button: Button
var _haptics: Haptics
var _was_ready: bool = false
var _game_over_committed: bool = false
var _game_over_rank: int = 0
var _lock_orbit_progress: float = 0.0
var _lock_intro_last_scheduled: float = 0.0
var _lock_intro_empty_time: float = -1.0


func _enter_tree() -> void:
	Config.data.game_mode = GameConfig.GameMode.SLIME
	var bank: SfxBank = get_node_or_null("SfxBank") as SfxBank
	if bank != null:
		bank.save_path = save_path


func _ready() -> void:
	_sim = SlimeSim.new(slime_config, _seed_from_arguments(), true, true)
	_shake_rng.seed = _sim.get_seed_used() ^ 0x51A3E
	_view.bind(_sim)
	_hud.bind(_sim)
	if shell_enabled:
		_setup_shell()
	if not InputRouter.swipe.is_connected(_on_swipe):
		InputRouter.swipe.connect(_on_swipe)
	if not InputRouter.restart_requested.is_connected(_on_restart_requested):
		InputRouter.restart_requested.connect(_on_restart_requested)
	if OS.is_debug_build() and not InputRouter.debug_toggle_game_mode.is_connected(
		_on_debug_toggle_game_mode
	):
		InputRouter.debug_toggle_game_mode.connect(_on_debug_toggle_game_mode)
	if not get_viewport().size_changed.is_connected(_layout_content):
		get_viewport().size_changed.connect(_layout_content)
	InputRouter.set_accept_release_after_unlock(true)
	_layout_content()
	_consume_events()
	_begin_lock_orbit_clock()
	_sync_input_lock()


func _exit_tree() -> void:
	InputRouter.set_accept_release_after_unlock(false)
	if InputRouter.swipe.is_connected(_on_swipe):
		InputRouter.swipe.disconnect(_on_swipe)
	if InputRouter.restart_requested.is_connected(_on_restart_requested):
		InputRouter.restart_requested.disconnect(_on_restart_requested)
	if InputRouter.debug_toggle_game_mode.is_connected(_on_debug_toggle_game_mode):
		InputRouter.debug_toggle_game_mode.disconnect(_on_debug_toggle_game_mode)


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
		_begin_lock_orbit_clock()
		if _haptics != null:
			_haptics.play_swipe()
		refresh_presentation()
		_sync_input_lock()


func _on_restart_requested() -> void:
	get_tree().reload_current_scene()


func _sync_input_lock() -> void:
	var ready: bool = not _sim.moving and not _sim.game_over
	InputRouter.set_locked(not ready)
	if _turn_indicator != null:
		_turn_indicator.set_slime_state(
			ready,
			not _sim.game_over,
			_update_lock_orbit_progress()
		)
	if ready and not _was_ready:
		_sfx.play_turn_ready()
		if _haptics != null:
			_haptics.play_turn_ready()
	_was_ready = ready


func _begin_lock_orbit_clock() -> void:
	_lock_orbit_progress = 0.0
	_lock_intro_empty_time = -1.0
	_lock_intro_last_scheduled = 0.0
	for entry: Dictionary in _sim.intro_queue:
		_lock_intro_last_scheduled = maxf(
			_lock_intro_last_scheduled,
			float(entry.get("delay", 0.0))
		)
	if _sim.intro_queue.is_empty():
		_lock_intro_empty_time = 0.0


func _update_lock_orbit_progress() -> float:
	if not _sim.moving:
		return _lock_orbit_progress
	var maximum_simulation: float = maxf(_sim.config.max_simulation_time, 0.001)
	var current_progress: float = 0.0
	if not _sim.intro_queue.is_empty():
		current_progress = _sim.intro_elapsed / (
			_lock_intro_last_scheduled + maximum_simulation
		)
	else:
		if _lock_intro_empty_time < 0.0:
			_lock_intro_empty_time = _sim.intro_elapsed
		current_progress = (
			_lock_intro_empty_time + _sim.simulation_elapsed
		) / (_lock_intro_empty_time + maximum_simulation)
	_lock_orbit_progress = maxf(
		_lock_orbit_progress,
		clampf(current_progress, 0.0, 1.0)
	)
	return _lock_orbit_progress


func lock_orbit_progress() -> float:
	return _lock_orbit_progress


func _layout_content() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_background.position = Vector2.ZERO
	_background.size = viewport_size
	_content.scale = Vector2.ONE * CONTENT_SCALE
	_content_base_position = (viewport_size - CONTENT_SIZE * CONTENT_SCALE) * 0.5
	_content.position = _content_base_position + _shake_offset
	_layout_shell()


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
				_commit_game_over_once()
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


func _setup_shell() -> void:
	_haptics = Haptics.new()
	_haptics.name = "Haptics"
	add_child(_haptics)

	var template: CanvasLayer = UI_SCENE.instantiate() as CanvasLayer
	var template_hud: Control = template.get_node("Hud") as Control
	_result_dimmer = template_hud.get_node("ResultDimmer") as ColorRect
	_game_over_panel = template_hud.get_node("GameOverPanel") as GameOverPanel
	_sound_button = template_hud.get_node("HudSoundButton") as Button
	_ranking_panel = template.get_node("RankingPanel") as RankingPanel
	for node: Node in [_result_dimmer, _game_over_panel, _sound_button]:
		template_hud.remove_child(node)
		_clear_owner_recursive(node)
	template.remove_child(_ranking_panel)
	_clear_owner_recursive(_ranking_panel)

	_shell_layer = CanvasLayer.new()
	_shell_layer.name = "SlimeShell"
	_shell_layer.layer = 20
	_shell_root = Control.new()
	_shell_root.name = "ShellRoot"
	_shell_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shell_root.theme = UI_THEME
	_shell_layer.add_child(_shell_root)
	for node: Node in [
		_result_dimmer,
		_turn_indicator_for_shell(),
		_sound_button,
		_game_over_panel,
		_ranking_panel,
	]:
		_shell_root.add_child(node)
		_assign_owner_recursive(node, _shell_root)
	template.free()
	add_child(_shell_layer)

	_sound_button.pressed.connect(_sfx.toggle_mute)
	_sfx.mute_changed.connect(_on_mute_changed)
	_on_mute_changed(_sfx.is_muted())
	_game_over_panel.bind_slime()
	_game_over_panel.mode_select_requested.connect(_on_mode_select_requested)
	_game_over_panel.ranking_requested.connect(_on_ranking_requested)
	_ranking_panel.bind(save_path)
	_ranking_panel.closed.connect(_on_ranking_closed)
	_turn_indicator.bind_slime(Rect2(Vector2.ZERO, Vector2.ONE))
	_layout_shell()


func _turn_indicator_for_shell() -> TurnInputIndicator:
	_turn_indicator = TurnInputIndicator.new()
	_turn_indicator.name = "TurnInputIndicator"
	_turn_indicator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return _turn_indicator


func _assign_owner_recursive(node: Node, new_owner: Node) -> void:
	node.owner = new_owner
	for child: Node in node.get_children():
		_assign_owner_recursive(child, new_owner)


func _clear_owner_recursive(node: Node) -> void:
	node.owner = null
	for child: Node in node.get_children():
		_clear_owner_recursive(child)


func _layout_shell() -> void:
	if _shell_root == null or _sim == null:
		return
	var board_rect: Rect2 = Rect2(
		_content_base_position + slime_config.board_rect.position * CONTENT_SCALE,
		slime_config.board_rect.size * CONTENT_SCALE
	)
	if _turn_indicator != null:
		_turn_indicator.set_slime_board_rect(
			board_rect.grow(4.0 * CONTENT_SCALE),
			board_rect
		)
	if _sound_button != null:
		var button_size: Vector2 = Vector2.ONE * 104.0
		_sound_button.position = Vector2(
			board_rect.get_center().x - button_size.x * 0.5,
			board_rect.end.y + 30.0
		)
		_sound_button.size = button_size
	if _game_over_panel != null:
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var panel_size: Vector2 = Vector2(788.0, 1040.0)
		var scale_factor: float = minf(viewport_size.x / 1080.0, viewport_size.y / 1920.0)
		_game_over_panel.size = panel_size * scale_factor
		_game_over_panel.position = (viewport_size - _game_over_panel.size) * 0.5


func _commit_game_over_once() -> void:
	if _game_over_committed:
		return
	_game_over_committed = true
	var stats: Dictionary = {
		"turns": _sim.turn,
		"max_chain": _sim.run_best_chain,
		"max_colors": _sim.completed_colors.size(),
	}
	var ranking: Dictionary = SaveStore.add_ranking(
		save_path, GameConfig.GameMode.SLIME, _sim.score, stats
	)
	SaveStore.save_last_mode(save_path, GameConfig.GameMode.SLIME)
	_game_over_rank = int(ranking.get("rank", 0))
	slime_game_over_committed.emit(ranking.duplicate(true))
	_show_game_over_after_feedback(ranking)


func _show_game_over_after_feedback(ranking: Dictionary) -> void:
	await get_tree().create_timer(SfxBank.SLIME_GAME_OVER_DURATION).timeout
	if not is_inside_tree() or _game_over_panel == null:
		return
	_game_over_panel.show_slime_result(
		_sim.score,
		_sim.turn,
		_sim.run_best_chain,
		_sim.completed_colors.size(),
		ranking,
		SaveStore.load_slime_records(save_path)
	)


func _on_ranking_requested(mode: GameConfig.GameMode, highlight_rank: int) -> void:
	if mode != GameConfig.GameMode.SLIME:
		return
	_game_over_panel.visible = false
	_result_dimmer.visible = false
	_sound_button.visible = false
	_ranking_panel.open(mode, highlight_rank)


func _on_ranking_closed() -> void:
	_game_over_panel.visible = true
	_result_dimmer.visible = true
	_sound_button.visible = true
	_game_over_panel.restore_actions_after_ranking()


func _on_mode_select_requested() -> void:
	Main.queue_start_screen()
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_debug_toggle_game_mode() -> void:
	Main.queue_mode(GameConfig.GameMode.TURN)
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_mute_changed(muted: bool) -> void:
	_sound_button.icon = SPEAKER_OFF if muted else SPEAKER_ON
	_sound_button.text = ""
	_sound_button.tooltip_text = "소리 켜기" if muted else "소리 끄기"


func game_over_panel() -> GameOverPanel:
	return _game_over_panel


func ranking_panel() -> RankingPanel:
	return _ranking_panel


func turn_input_indicator() -> TurnInputIndicator:
	return _turn_indicator


func sound_button() -> Button:
	return _sound_button


func haptics() -> Haptics:
	return _haptics


func _seed_from_arguments() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SEED_PREFIX):
			return argument.trim_prefix(SEED_PREFIX).to_int()
	return 0
