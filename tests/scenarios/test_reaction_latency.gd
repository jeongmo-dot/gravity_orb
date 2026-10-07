extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")

var _observed_reactions: Array[Dictionary] = []


func test_turn_dense_contact_merges_within_one_physics_tick() -> void:
	await _assert_dense_contact_reacts_within_one_tick(false)


func test_blitz_dense_contact_merges_within_one_physics_tick() -> void:
	await _assert_dense_contact_reacts_within_one_tick(true)


func test_proximity_reaction_order_is_deterministic() -> void:
	var first: String = await _deterministic_reaction_sequence()
	var second: String = await _deterministic_reaction_sequence()
	assert_eq(second, first, "same setup resolves proximity pairs in stable-id order")


func test_two_hundred_orb_proximity_scan_p95_is_below_one_millisecond() -> void:
	var fixture: Dictionary = await _create_fixture(false, false)
	var root: Node = fixture["root"] as Node
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	for index: int in range(200):
		var column: int = index % 20
		var row: int = index / 20
		var orb: Orb3D = board.spawn_orb(
			index % 6,
			1,
			Vector2(float(column) * 45.0 - 427.5, float(row) * 45.0 - 202.5)
		)
		orb.get_physics_body().freeze = true
	for _warmup: int in range(5):
		resolver.measure_proximity_scan_usec()
	var samples: Array[int] = []
	for _sample: int in range(40):
		samples.append(resolver.measure_proximity_scan_usec())
	samples.sort()
	var p95_index: int = roundi(float(samples.size() - 1) * 0.95)
	var p95_usec: int = samples[p95_index]
	print("REACTION_PROXIMITY_PERF orbs=200 p95_usec=%d max_usec=%d" % [
		p95_usec,
		samples[-1],
	])
	assert_true(p95_usec < 1000, "200-orb proximity scan p95 must be below 1ms")
	await _cleanup(root)


func _assert_dense_contact_reacts_within_one_tick(blitz: bool) -> void:
	var fixture: Dictionary = await _create_fixture(blitz, true)
	var root: Node = fixture["root"] as Node
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	_observed_reactions.clear()
	resolver.reaction_applied.connect(_record_reaction)
	var center: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 6, Vector2.ZERO)
	center.get_physics_body().freeze = true
	for neighbor_index: int in range(8):
		var angle: float = deg_to_rad(70.0 + float(neighbor_index) * (220.0 / 7.0))
		var neighbor: Orb3D = board.spawn_orb(
			OrbTypes.OrbColor.BLUE,
			1,
			Vector2.from_angle(angle) * 144.0
		)
		neighbor.get_physics_body().freeze = true
	var incoming: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		6,
		Vector2(240.0, 0.0)
	)
	incoming.get_physics_body().freeze = true
	var start_frame: int = Engine.get_physics_frames()
	await tree.physics_frame
	await tree.create_timer(0.0).timeout
	assert_eq(_observed_reactions.size(), 1, "dense new same pair reacts once")
	if not _observed_reactions.is_empty():
		var reaction: Dictionary = _observed_reactions[0]
		assert_eq(int(reaction["type"]), ReactionRules.Type.MERGE, "dense pair merges")
		assert_true(
			int(reaction["reaction_physics_frame"]) - start_frame <= 1,
			"dense pair reacts within one physics tick"
		)
		assert_true(
			str(reaction["contact_path"]) in ["body_entered", "proximity"],
			"dense pair uses immediate contact path"
		)
	await _cleanup(root)


func _deterministic_reaction_sequence() -> String:
	var fixture: Dictionary = await _create_fixture(false, true)
	var root: Node = fixture["root"] as Node
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	_observed_reactions.clear()
	resolver.reaction_applied.connect(_record_reaction)
	var positions: Array[Vector2] = [
		Vector2(-300.0, -100.0),
		Vector2(-250.0, -100.0),
		Vector2(250.0, 100.0),
		Vector2(300.0, 100.0),
	]
	for index: int in range(positions.size()):
		var orb: Orb3D = board.spawn_orb(
			OrbTypes.OrbColor.GREEN if index < 2 else OrbTypes.OrbColor.YELLOW,
			1,
			positions[index]
		)
		orb.get_physics_body().freeze = true
	await tree.physics_frame
	var sequence: Array[Dictionary] = []
	for reaction: Dictionary in _observed_reactions:
		sequence.append({
			"type": reaction["type"],
			"ids": reaction["stable_spawn_ids"],
			"result_color": reaction["result_color"],
			"result_level": reaction["result_level"],
		})
	var result: String = JSON.stringify(sequence)
	await _cleanup(root)
	return result


func _create_fixture(blitz: bool, active_manager: bool) -> Dictionary:
	InputRouter.set_locked(false)
	var root: Node3D = Node3D.new()
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.name = "Board"
	board.unique_name_in_owner = true
	board.orb_progressive_growth_enabled = false
	root.add_child(board)
	board.owner = root
	var resolver: CollisionResolver = CollisionResolver.new()
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	root.add_child(resolver)
	resolver.owner = root
	var spawner: Spawner = Spawner.new()
	spawner.name = "Spawner"
	spawner.unique_name_in_owner = true
	root.add_child(spawner)
	spawner.owner = root
	var score: ScoreManager = ScoreManager.new()
	score.name = "ScoreManager"
	score.unique_name_in_owner = true
	score.save_path = ""
	root.add_child(score)
	score.owner = root
	var manager: Node
	if blitz:
		var blitz_manager: BlitzManager = BlitzManager.new()
		blitz_manager.name = "BlitzManager"
		manager = blitz_manager
	else:
		var turn_manager: TurnManager = TurnManager.new()
		turn_manager.name = "TurnManager"
		manager = turn_manager
	root.add_child(manager)
	manager.owner = root
	tree.root.add_child(root)
	await tree.process_frame
	if blitz and active_manager:
		(manager as BlitzManager).start_game()
	return {
		"root": root,
		"board": board,
		"resolver": resolver,
		"spawner": spawner,
		"score": score,
		"manager": manager,
	}


func _record_reaction(reaction: Dictionary) -> void:
	_observed_reactions.append(reaction.duplicate(true))


func _cleanup(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await tree.process_frame
	await tree.physics_frame
	InputRouter.set_locked(false)
