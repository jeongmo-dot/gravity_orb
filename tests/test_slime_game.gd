extends TestCase

const SLIME_SCENE: PackedScene = preload("res://scenes/SlimeMain.tscn")


func test_slime_scene_uses_fixed_content_scale_and_input_router() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.SLIME
	var game: Variant = SLIME_SCENE.instantiate()
	tree.root.add_child(game)
	await tree.process_frame
	assert_true(game != null, "slime scene instantiates")
	assert_eq(int(GameConfig.GameMode.SLIME), 2, "SLIME keeps enum value 2")
	var content: Node2D = game.get_node("Content") as Node2D
	assert_true(content.scale.is_equal_approx(Vector2.ONE * 1.6875), "original 640x920 content scale")
	var sim: SlimeSim = game.get_sim()
	assert_true(sim.moving, "initial admission starts immediately")
	var safety: int = 0
	while sim.moving and safety < 240:
		game.advance_elapsed(1.0 / 60.0)
		safety += 1
	assert_true(not sim.moving, "initial admission settles")
	InputRouter.swipe.emit(Vector2i.LEFT)
	assert_true(sim.moving, "InputRouter swipe starts slime turn")
	assert_eq(sim.gravity_direction, Vector2i.LEFT, "swipe changes gravity")
	game.queue_free()
	await tree.process_frame
	Config.data.game_mode = original_mode
