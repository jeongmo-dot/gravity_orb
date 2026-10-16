extends SceneTree

const OUTPUT_PREFIX: String = "--output="

var _game_script: Script = preload("res://capture_game.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_path: String = _argument_value(OUTPUT_PREFIX)
	if output_path.is_empty():
		push_error("Missing --output=<absolute path>")
		quit(2)
		return
	var game: Variant = _game_script.new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.slimes.clear()
	game.intro_queue.clear()
	game.next_slimes.clear()
	game.merge_ghosts.clear()
	game.merge_rings.clear()
	game.merge_particles.clear()
	game.score_popups.clear()
	game.gravity_dir = Vector2.DOWN
	game.turn = 7
	game.score = 26150
	game.high_score = 26150
	game.active_color_count = 5
	game.completed_colors.clear()
	game.completed_colors.append(0)
	game.completed_colors.append(2)
	game.moving = false
	game.message = "다음 중력을 선택하세요"
	game.next_slimes.append({"level": 0, "color_id": 2})
	game.next_slimes.append({"level": 1, "color_id": 0})
	_add_showcase_slime(game, Vector2(168.0, 370.0), 0, 0, Vector2(210.0, 80.0))
	_add_showcase_slime(game, Vector2(305.0, 430.0), 2, 1, Vector2(-160.0, 50.0))
	_add_showcase_slime(game, Vector2(465.0, 520.0), 5, 2, Vector2.ZERO)
	_add_showcase_slime(game, Vector2(210.0, 690.0), 1, 3, Vector2(80.0, -130.0))
	_add_showcase_slime(game, Vector2(405.0, 760.0), 3, 4, Vector2(-90.0, -100.0))
	game.queue_redraw()
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(output_path)
	if error != OK:
		push_error("Could not save original capture: %s" % error_string(error))
		quit(2)
		return
	print("SLIME_ORIGINAL_CAPTURE file=%s size=%dx%d" % [output_path, image.get_width(), image.get_height()])
	quit(0)


func _add_showcase_slime(game: Variant, position: Vector2, level: int, color_id: int, velocity: Vector2) -> void:
	game._add_slime(position, level, color_id, velocity)
	var slime: Dictionary = game.slimes[-1]
	slime.visual_scale = 1.0
	slime.deform = Vector2(0.94, 1.10) if not velocity.is_zero_approx() else Vector2.ONE


func _argument_value(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
