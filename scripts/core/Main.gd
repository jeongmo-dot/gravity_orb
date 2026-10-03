class_name Main
extends Node

const BACKGROUND_COLOR: Color = Color.BLACK
const SEED_PREFIX: String = "--jolt-seed="

@onready var _board: Variant = $Board
@onready var _turn_manager: TurnManager = %TurnManager
@onready var _spawner: Spawner = %Spawner
@onready var _collision_resolver: CollisionResolver = %CollisionResolver
@onready var _score_manager: ScoreManager = %ScoreManager


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	InputRouter.swipe.connect(_turn_manager.on_swipe)
	InputRouter.restart_requested.connect(restart)
	_collision_resolver.reaction_applied.connect(_score_manager.on_reaction)
	_spawner.orb_spawned.connect(_score_manager.on_orb_spawned)
	# TEMP(M6): M9 디버그 패널이 규칙 선택을 대체할 때 제거한다.
	if OS.is_debug_build():
		InputRouter.debug_cycle_annihilation_rule.connect(
			_cycle_annihilation_rule
		)
		# TEMP(M7): M9 디버그 패널이 생성 수 선택을 대체할 때 제거한다.
		InputRouter.debug_cycle_spawn_count.connect(_cycle_spawn_count)
	_spawner.init_rng(_seed_from_arguments(Config.data.rng_seed))
	_spawner.spawn_initial(_board, Vector2i.DOWN)
	_turn_manager.start_game()


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


func _seed_from_arguments(fallback_seed: int) -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SEED_PREFIX):
			return argument.trim_prefix(SEED_PREFIX).to_int()
	return fallback_seed
