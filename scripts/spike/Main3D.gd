class_name Main3D
extends Node3D

const BACKGROUND_COLOR: Color = Color("#060b18")
const SEED_PREFIX: String = "--jolt-seed="

@onready var _board: Board3D = %Board
@onready var _turn_manager: TurnManager3D = %TurnManager
@onready var _spawner: Spawner3D = %Spawner
@onready var _collision_resolver: CollisionResolver3D = %CollisionResolver
@onready var _score_manager: ScoreManager = %ScoreManager


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	InputRouter.swipe.connect(_turn_manager.on_swipe)
	InputRouter.restart_requested.connect(restart)
	_collision_resolver.reaction_applied.connect(_score_manager.on_reaction)
	_spawner.orb_spawned.connect(_score_manager.on_orb_spawned)
	_score_manager.save_path = ""
	var seed: int = _seed_from_arguments(Config.data.rng_seed)
	_spawner.init_rng(seed)
	_spawner.spawn_initial(_board, Vector2i.DOWN)
	_turn_manager.start_game()


func restart() -> void:
	get_tree().reload_current_scene()


func _seed_from_arguments(fallback_seed: int) -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SEED_PREFIX):
			return argument.trim_prefix(SEED_PREFIX).to_int()
	return fallback_seed
