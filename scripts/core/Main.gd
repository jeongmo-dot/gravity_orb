class_name Main
extends Node

const BACKGROUND_COLOR: Color = Color.BLACK
const SEED_PREFIX: String = "--jolt-seed="
const MODE_PREFIX: String = "--mode="

static var _has_debug_mode_override: bool = false
static var _debug_mode_override: GameConfig.GameMode = GameConfig.GameMode.TURN

@onready var _board: Variant = $Board
@onready var _turn_manager: TurnManager = %TurnManager
@onready var _blitz_manager: BlitzManager = %BlitzManager
@onready var _spawner: Spawner = %Spawner
@onready var _collision_resolver: CollisionResolver = %CollisionResolver
@onready var _score_manager: ScoreManager = %ScoreManager

var _game_manager: Variant


func _enter_tree() -> void:
	if _has_debug_mode_override:
		Config.data.game_mode = _debug_mode_override
	else:
		Config.data.game_mode = _mode_from_arguments(Config.data.game_mode)


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	var blitz_mode: bool = Config.data.game_mode == GameConfig.GameMode.BLITZ
	_game_manager = _blitz_manager if blitz_mode else _turn_manager
	if blitz_mode:
		_turn_manager.set_physics_process(false)
		if _collision_resolver.reaction_applied.is_connected(_turn_manager.on_reaction):
			_collision_resolver.reaction_applied.disconnect(_turn_manager.on_reaction)
	InputRouter.swipe.connect(_game_manager.on_swipe)
	InputRouter.restart_requested.connect(restart)
	_game_manager.reaction_ready.connect(_score_manager.on_reaction)
	_spawner.orb_spawned.connect(_score_manager.on_orb_spawned)
	# TEMP(M6): M9 디버그 패널이 규칙 선택을 대체할 때 제거한다.
	if OS.is_debug_build():
		InputRouter.debug_cycle_annihilation_rule.connect(
			_cycle_annihilation_rule
		)
		# TEMP(M7): M9 디버그 패널이 생성 수 선택을 대체할 때 제거한다.
		if not blitz_mode:
			InputRouter.debug_cycle_spawn_count.connect(_cycle_spawn_count)
		InputRouter.debug_toggle_game_mode.connect(_toggle_game_mode)
	_spawner.set_blitz_mode(blitz_mode)
	_spawner.init_rng(_seed_from_arguments(Config.data.rng_seed))
	_spawner.spawn_initial(_board, Vector2i.DOWN)
	_game_manager.start_game()


func restart() -> void:
	get_tree().reload_current_scene()


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
	Config.data.game_mode = (
		GameConfig.GameMode.BLITZ
		if Config.data.game_mode == GameConfig.GameMode.TURN
		else GameConfig.GameMode.TURN
	)
	_has_debug_mode_override = true
	_debug_mode_override = Config.data.game_mode
	restart()


func _seed_from_arguments(fallback_seed: int) -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SEED_PREFIX):
			return argument.trim_prefix(SEED_PREFIX).to_int()
	return fallback_seed


func _mode_from_arguments(fallback_mode: GameConfig.GameMode) -> GameConfig.GameMode:
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with(MODE_PREFIX):
			continue
		var mode_name: String = argument.trim_prefix(MODE_PREFIX).to_lower()
		if mode_name == "blitz":
			return GameConfig.GameMode.BLITZ
		if mode_name == "turn":
			return GameConfig.GameMode.TURN
	return fallback_mode
