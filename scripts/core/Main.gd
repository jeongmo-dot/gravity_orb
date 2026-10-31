class_name Main
extends Node

const BACKGROUND_COLOR: Color = Color.BLACK
const SEED_PREFIX: String = "--jolt-seed="
const MODE_PREFIX: String = "--mode="
const FULL_BOARD_PERFORMANCE_ARGUMENT: String = "--full-board-performance"
const FULL_BOARD_PERFORMANCE_RUNNER: Script = preload(
	"res://scripts/platform/FullBoardPerformanceMeasurement.gd"
)
const NO_MODE: int = -1
const BASE_VERTICAL_FOV_DEGREES: float = 25.0
const BASE_ASPECT_WIDTH_OVER_HEIGHT: float = 9.0 / 16.0

static var _queued_mode: int = NO_MODE
static var _force_start_screen: bool = false

@onready var _board: Variant = $Board
@onready var _turn_manager: TurnManager = %TurnManager
@onready var _spawner: Spawner = %Spawner
@onready var _score_manager: ScoreManager = %ScoreManager
@onready var _feedback_director: FeedbackDirector = %FeedbackDirector
@onready var _ui: DebugHud = $UI
@onready var _space_backdrop: SpaceBackdrop = get_node_or_null("SpaceBackdrop") as SpaceBackdrop
@onready var _camera_3d: Camera3D = get_node_or_null("Camera3D") as Camera3D

var _game_manager: Variant
var _launch_game_on_ready: bool = false
var _game_started: bool = false
var _embedded_launch_mode: int = NO_MODE


func _enter_tree() -> void:
	Config.data.game_mode = GameConfig.GameMode.JELLY
	if _force_start_screen:
		_force_start_screen = false
		_prepare_start_screen()
		return
	if _embedded_launch_mode != NO_MODE:
		_launch_game_on_ready = true
		return
	if _queued_mode != NO_MODE:
		_queued_mode = NO_MODE
		_launch_game_on_ready = true
		return
	var argument_mode: int = _mode_from_arguments(OS.get_cmdline_user_args())
	if argument_mode != NO_MODE:
		_launch_game_on_ready = true
		return
	if _full_board_performance_requested():
		_launch_game_on_ready = true
		return
	_prepare_start_screen()


func _prepare_start_screen() -> void:
	Config.data.game_mode = GameConfig.GameMode.JELLY
	_launch_game_on_ready = false
	InputRouter.set_accept_release_after_unlock(false)


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	if _camera_3d != null:
		if not get_viewport().size_changed.is_connected(_apply_camera_aspect):
			get_viewport().size_changed.connect(_apply_camera_aspect)
		_apply_camera_aspect()
	_bind_space_visuals()
	_game_manager = _turn_manager
	InputRouter.restart_requested.connect(restart)
	_ui.bind_start_screen(_save_path())
	_ui.start_screen().mode_selected.connect(_on_mode_selected)
	_ui.start_screen().ranking_requested.connect(_ui.show_ranking)
	var game_over_panel: GameOverPanel = (
		get_node("UI/Hud/GameOverPanel") as GameOverPanel
	)
	game_over_panel.mode_select_requested.connect(_show_mode_selection)
	game_over_panel.ranking_requested.connect(_ui.show_ranking)
	_bind_debug_controls()
	if not _launch_game_on_ready:
		_turn_manager.set_physics_process(false)
		InputRouter.set_locked(true)
		_ui.show_start_screen()
		return
	_start_gameplay()
	if _full_board_performance_requested():
		call_deferred("_start_full_board_performance_measurement")


func _exit_tree() -> void:
	InputRouter.set_accept_release_after_unlock(false)
	if (
		_camera_3d != null
		and get_viewport().size_changed.is_connected(_apply_camera_aspect)
	):
		get_viewport().size_changed.disconnect(_apply_camera_aspect)


func _apply_camera_aspect() -> void:
	configure_camera_for_viewport(_camera_3d, get_viewport().get_visible_rect().size)


static func configure_camera_for_viewport(camera: Camera3D, viewport_size: Vector2) -> void:
	if camera == null or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var aspect: float = viewport_size.x / viewport_size.y
	if aspect < BASE_ASPECT_WIDTH_OVER_HEIGHT:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = base_horizontal_fov_degrees()
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = BASE_VERTICAL_FOV_DEGREES


static func base_horizontal_fov_degrees() -> float:
	return rad_to_deg(
		2.0 * atan(
			tan(deg_to_rad(BASE_VERTICAL_FOV_DEGREES) * 0.5)
			* BASE_ASPECT_WIDTH_OVER_HEIGHT
		)
	)


func _bind_space_visuals() -> void:
	if _space_backdrop == null:
		return
	var board_3d: Board3D = _board as Board3D
	if board_3d == null:
		return
	if not board_3d.visual_gravity_changed.is_connected(
		_space_backdrop.set_gravity_direction
	):
		board_3d.visual_gravity_changed.connect(_space_backdrop.set_gravity_direction)
	if not board_3d.danger_visual_changed.is_connected(_space_backdrop.set_danger_state):
		board_3d.danger_visual_changed.connect(_space_backdrop.set_danger_state)


func launch_immediately(_mode: GameConfig.GameMode) -> void:
	_embedded_launch_mode = int(GameConfig.GameMode.JELLY)


static func queue_mode(_mode: GameConfig.GameMode) -> void:
	_queued_mode = int(GameConfig.GameMode.JELLY)
	_force_start_screen = false


static func queue_start_screen() -> void:
	_queued_mode = NO_MODE
	_force_start_screen = true


func _start_gameplay() -> void:
	Config.data.game_mode = GameConfig.GameMode.JELLY
	InputRouter.set_accept_release_after_unlock(true)
	_game_manager = _turn_manager
	_turn_manager.set_physics_process(true)
	InputRouter.swipe.connect(_game_manager.on_swipe)
	_game_manager.reaction_ready.connect(_score_manager.on_reaction)
	_feedback_director.bind(_game_manager, _board)
	_spawner.orb_spawned.connect(_score_manager.on_orb_spawned)
	_spawner.init_rng(_seed_from_arguments(Config.data.rng_seed))
	_ui.show_gameplay()
	_spawner.spawn_initial(_board, Vector2i.DOWN)
	_game_manager.start_game()
	_game_started = true


func restart() -> void:
	if not _game_started:
		return
	_queued_mode = int(GameConfig.GameMode.JELLY)
	get_tree().reload_current_scene()


func _on_mode_selected(_mode: GameConfig.GameMode) -> void:
	_queued_mode = int(GameConfig.GameMode.JELLY)
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
	InputRouter.debug_cycle_spawn_count.connect(_cycle_spawn_count)


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
		if mode_name == "jelly":
			return int(GameConfig.GameMode.JELLY)
	return NO_MODE


func _save_path() -> String:
	var score_manager: ScoreManager = get_node_or_null("ScoreManager") as ScoreManager
	return score_manager.save_path if score_manager != null else ""


func _full_board_performance_requested() -> bool:
	return (
		OS.is_debug_build()
		and OS.get_cmdline_user_args().has(FULL_BOARD_PERFORMANCE_ARGUMENT)
	)


func _start_full_board_performance_measurement() -> void:
	var runner: Node = FULL_BOARD_PERFORMANCE_RUNNER.new() as Node
	add_child(runner)
	runner.call("configure", self)
