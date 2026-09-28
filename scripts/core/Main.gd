class_name Main
extends Node2D

const BACKGROUND_COLOR: Color = Color.BLACK

@onready var _board: Board = $Board
@onready var _turn_manager: TurnManager = %TurnManager
@onready var _spawner: Spawner = %Spawner


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	InputRouter.swipe.connect(_turn_manager.on_swipe)
	_spawner.init_rng(Config.data.rng_seed)
	_spawner.spawn_initial(_board, Vector2i.DOWN)
	_turn_manager.start_game()
