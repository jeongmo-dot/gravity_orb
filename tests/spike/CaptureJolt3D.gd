extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const OUTPUT_DIRECTORY: String = "res://artifacts"
const CAPTURE_TURNS: Array[int] = [1, 60, 180]
const DIRECTION_PATTERN: Array[Vector2i] = [
	Vector2i.DOWN,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.RIGHT,
]
const WAIT_TIMEOUT_SECONDS: float = 3.5

var _failed: bool = false
var _max_capture_turn: int = CAPTURE_TURNS[-1]


func _ready() -> void:
	call_deferred("_capture_sequence")


func _capture_sequence() -> void:
	_apply_arguments()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var main: Main = MAIN_SCENE.instantiate() as Main
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	if not await _wait_until_ready(manager):
		push_error("Jolt capture failed to reach initial WAITING_INPUT")
		get_tree().quit(1)
		return

	for turn_number: int in range(1, _max_capture_turn + 1):
		var direction: Vector2i = DIRECTION_PATTERN[(turn_number - 1) % DIRECTION_PATTERN.size()]
		manager.on_swipe(direction)
		if turn_number == 60:
			await get_tree().create_timer(0.08).timeout
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_capture("jolt3d_seed101_tilt_turn060.png")
		if not await _wait_until_ready(manager):
			push_error("Jolt capture turn %d did not settle" % turn_number)
			_failed = true
			break
		if CAPTURE_TURNS.has(turn_number):
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_capture("jolt3d_seed101_turn_%03d.png" % turn_number)
		if manager.state == TurnManager.State.GAME_OVER and turn_number < CAPTURE_TURNS[-1]:
			push_error("Jolt capture game over at turn %d before turn 180" % turn_number)
			_failed = true
			break

	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _wait_until_ready(manager: TurnManager) -> bool:
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		if (
			manager.state == TurnManager.State.WAITING_INPUT
			or manager.state == TurnManager.State.GAME_OVER
		):
			return true
		await get_tree().physics_frame
	return false


func _capture(file_name: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = OUTPUT_DIRECTORY.path_join(file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		_failed = true
		push_error("Could not save capture %s: %s" % [path, error_string(error)])
		return
	print("JOLT3D_CAPTURE %s %dx%d" % [path, image.get_width(), image.get_height()])


func _apply_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--jolt-capture-until="):
			_max_capture_turn = clampi(
				argument.trim_prefix("--jolt-capture-until=").to_int(),
				1,
				CAPTURE_TURNS[-1]
			)
