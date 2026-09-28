class_name Main
extends Node2D

const BACKGROUND_COLOR: Color = Color.BLACK
const DEBUG_LEVEL_VARIANTS: int = 4

@onready var _board: Board = $Board

# TEMP(M1): M4에서 Spawner로 교체
var _test_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	_board.set_gravity(Vector2i.DOWN)
	_spawn_test_orbs()


# TEMP(M1): M2에서 InputRouter로 교체
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_UP:
			_board.set_gravity(Vector2i.UP)
		KEY_DOWN:
			_board.set_gravity(Vector2i.DOWN)
		KEY_LEFT:
			_board.set_gravity(Vector2i.LEFT)
		KEY_RIGHT:
			_board.set_gravity(Vector2i.RIGHT)


func _spawn_test_orbs() -> void:
	var count: int = Config.data.debug_test_orb_count
	if count <= 0:
		return

	_test_rng.randomize()
	var columns: int = ceili(sqrt(float(count)))
	var rows: int = ceili(float(count) / float(columns))
	var cell_width: float = Config.data.board_size / float(columns)
	var cell_height: float = Config.data.board_size / float(rows)
	var half: float = _board.half_size()
	var color_count: int = Config.data.color_display.size()
	var level_count: int = mini(DEBUG_LEVEL_VARIANTS, Config.data.orb_max_level)

	for index: int in range(count):
		var color: int = index % color_count
		var level: int = index % level_count + 1
		var radius: float = Config.data.radius_for_level(level)
		var column: int = index % columns
		var row: int = int(index / columns)
		var cell_center: Vector2 = Vector2(
			-half + (float(column) + 0.5) * cell_width,
			-half + (float(row) + 0.5) * cell_height
		)
		var max_offset: Vector2 = Vector2(
			maxf(cell_width * 0.5 - radius, 0.0),
			maxf(cell_height * 0.5 - radius, 0.0)
		)
		var offset: Vector2 = Vector2(
			_test_rng.randf_range(-max_offset.x, max_offset.x),
			_test_rng.randf_range(-max_offset.y, max_offset.y)
		)
		_board.spawn_orb(color, level, cell_center + offset)
