class_name Main
extends Node

const BACKGROUND_COLOR: Color = Color.BLACK
const SEED_PREFIX: String = "--jolt-seed="
const MODE_PREFIX: String = "--mode="
const NO_MODE: int = -1

static var _queued_mode: int = NO_MODE
static var _force_start_screen: bool = false

@onready var _board: Variant = $Board
@onready var _turn_manager: TurnManager = %TurnManager
@onready var _blitz_manager: BlitzManager = %BlitzManager
@onready var _spawner: Spawner = %Spawner
@onready var _collision_resolver: CollisionResolver = %CollisionResolver
@onready var _score_manager: ScoreManager = %ScoreManager
@onready var _feedback_director: FeedbackDirector = %FeedbackDirector
@onready var _ui: DebugHud = $UI

var _game_manager: Variant
var _launch_game_on_ready: bool = false
var _game_started: bool = false
var _embedded_launch_mode: int = NO_MODE


func _enter_tree() -> void:
	if _force_start_screen:
		_force_start_screen = false
		_prepare_start_screen()
		return
	if _embedded_launch_mode != NO_MODE:
		Config.data.game_mode = _as_game_mode(_embedded_launch_mode)
		_launch_game_on_ready = true
		return
	if _queued_mode != NO_MODE:
		Config.data.game_mode = _as_game_mode(_queued_mode)
		_queued_mode = NO_MODE
		_launch_game_on_ready = true
		return
	var argument_mode: int = _mode_from_arguments(OS.get_cmdline_user_args())
	if argument_mode != NO_MODE:
		Config.data.game_mode = _as_game_mode(argument_mode)
		_launch_game_on_ready = true
		return
	_prepare_start_screen()


func _prepare_start_screen() -> void:
	Config.data.game_mode = SaveStore.load_last_mode(
		_save_path(),
		Config.data.game_mode
	)
	_launch_game_on_ready = false


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	_game_manager = (
		_blitz_manager
		if Config.data.game_mode == GameConfig.GameMode.BLITZ
		else _turn_manager
	)
	InputRouter.restart_requested.connect(restart)
	_ui.bind_start_screen(_save_path())
	_ui.start_screen().mode_selected.connect(_on_mode_selected)
	var game_over_panel: GameOverPanel = (
		get_node("UI/Hud/GameOverPanel") as GameOverPanel
	)
	game_over_panel.mode_select_requested.connect(_show_mode_selection)
	_bind_debug_controls()
	if not _launch_game_on_ready:
		_turn_manager.set_physics_process(false)
		_blitz_manager.set_physics_process(false)
		InputRouter.set_locked(true)
		_ui.show_start_screen()
		return
	_start_gameplay()


func launch_immediately(mode: GameConfig.GameMode) -> void:
	_embedded_launch_mode = int(mode)


func _start_gameplay() -> void:
	var blitz_mode: bool = Config.data.game_mode == GameConfig.GameMode.BLITZ
	_game_manager = _blitz_manager if blitz_mode else _turn_manager
	_turn_manager.set_physics_process(not blitz_mode)
	if blitz_mode:
		if _collision_resolver.reaction_applied.is_connected(_turn_manager.on_reaction):
			_collision_resolver.reaction_applied.disconnect(_turn_manager.on_reaction)
	InputRouter.swipe.connect(_game_manager.on_swipe)
	_game_manager.reaction_ready.connect(_score_manager.on_reaction)
	_feedback_director.bind(_game_manager, _board)
	_spawner.orb_spawned.connect(_score_manager.on_orb_spawned)
	_spawner.set_blitz_mode(blitz_mode)
	_spawner.init_rng(_seed_from_arguments(Config.data.rng_seed))
	_ui.show_gameplay()
	_spawner.spawn_initial(_board, Vector2i.DOWN)
	_game_manager.start_game()
	_game_started = true


func restart() -> void:
	if not _game_started:
		return
	_queued_mode = int(Config.data.game_mode)
	get_tree().reload_current_scene()


func _on_mode_selected(mode: GameConfig.GameMode) -> void:
	SaveStore.save_last_mode(_save_path(), mode)
	_queued_mode = int(mode)
	_force_start_screen = false
	get_tree().reload_current_scene()


func _show_mode_selection() -> void:
	_queued_mode = NO_MODE
	_force_start_screen = true
	get_tree().reload_current_scene()


func _bind_debug_controls() -> void:
	if not OS.is_debug_build():
		return
	# TEMP(M6): M9 디버그 패널이 규칙 선택을 대체할 때 제거한다.
	InputRouter.debug_cycle_annihilation_rule.connect(_cycle_annihilation_rule)
	# TEMP(M7): M9 디버그 패널이 생성 수 선택을 대체할 때 제거한다.
	if Config.data.game_mode != GameConfig.GameMode.BLITZ:
		InputRouter.debug_cycle_spawn_count.connect(_cycle_spawn_count)
	InputRouter.debug_toggle_game_mode.connect(_toggle_game_mode)


func _cycle_annihilation_rule() -> void:
	match Config.data.annihilation_rule:
		GameConfig.AnnihilationRule.A_BOTH:
			Config.data.annihilation_rule = GameConfig.AnnihilationRule.B_SAME_LEVEL
		GameConfig.AnnihilationRule.B_SAME_LEVEL:
			Config.data.annihilation_rule = GameConfig.AnnihilationRule.C_REMAINDER
		_:
			Config.data.annihilation_rule = GameConfig.AnnihilationRule.A_BOTH


func _cycle_spawn_count() -> void:
	# TEMP(M7): M9 디버그 패널이 생성 수 선택을 대체할 때 제거한다.
	Config.data.spawn_count_per_turn = Config.data.spawn_count_per_turn % 3 + 1
	_spawner.sync_next_batch_size(_turn_manager.turn_index + 1)


func _toggle_game_mode() -> void:
	var next_mode: GameConfig.GameMode = (
		GameConfig.GameMode.BLITZ
		if Config.data.game_mode == GameConfig.GameMode.TURN
		else GameConfig.GameMode.TURN
	)
	_queued_mode = int(next_mode)
	_force_start_screen = false
	get_tree().reload_current_scene()


func _seed_from_arguments(fallback_seed: int) -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SEED_PREFIX):
			return argument.trim_prefix(SEED_PREFIX).to_int()
	return fallback_seed


func _mode_from_arguments(arguments: PackedStringArray) -> int:
	for argument: String in arguments:
		if not argument.begins_with(MODE_PREFIX):
			continue
		var mode_name: String = argument.trim_prefix(MODE_PREFIX).to_lower()
		if mode_name == "blitz":
			return int(GameConfig.GameMode.BLITZ)
		if mode_name == "turn":
			return int(GameConfig.GameMode.TURN)
	return NO_MODE


func _save_path() -> String:
	var score_manager: ScoreManager = get_node_or_null("ScoreManager") as ScoreManager
	return score_manager.save_path if score_manager != null else ""


func _as_game_mode(value: int) -> GameConfig.GameMode:
	if value == int(GameConfig.GameMode.BLITZ):
		return GameConfig.GameMode.BLITZ
	return GameConfig.GameMode.TURN
