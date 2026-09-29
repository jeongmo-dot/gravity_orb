class_name Main
extends Node2D

const BACKGROUND_COLOR: Color = Color.BLACK

@onready var _board: Board = $Board
@onready var _turn_manager: TurnManager = %TurnManager
@onready var _spawner: Spawner = %Spawner


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	InputRouter.swipe.connect(_turn_manager.on_swipe)
	# TEMP(M6): M9 디버그 패널이 규칙 선택을 대체할 때 제거한다.
	if OS.is_debug_build():
		InputRouter.debug_cycle_annihilation_rule.connect(
			_cycle_annihilation_rule
		)
	_spawner.init_rng(Config.data.rng_seed)
	_spawner.spawn_initial(_board, Vector2i.DOWN)
	_turn_manager.start_game()


func _cycle_annihilation_rule() -> void:
	match Config.data.annihilation_rule:
		GameConfig.AnnihilationRule.A_BOTH:
			Config.data.annihilation_rule = GameConfig.AnnihilationRule.B_SAME_LEVEL
		GameConfig.AnnihilationRule.B_SAME_LEVEL:
			Config.data.annihilation_rule = GameConfig.AnnihilationRule.C_REMAINDER
		_:
			Config.data.annihilation_rule = GameConfig.AnnihilationRule.A_BOTH
