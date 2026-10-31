extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const COLLISION_RESOLVER_SCRIPT: Script = preload(
	"res://scripts/core/CollisionResolver.gd"
)
const POSITION_TOLERANCE: float = 0.001


func test_spawn_slot_intervals_match_brute_force_positions() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	for row: int in range(5):
		for column: int in range(9):
			_spawn_normal(
				board,
				(column + row) % 4,
				1 + ((column + row) % 2),
				Vector2(-360.0 + float(column) * 90.0, -360.0 + float(row) * 180.0)
			)
	var occupancy: Dictionary = board._normal_spawn_occupancy()
	var positions: PackedVector2Array = occupancy["positions"] as PackedVector2Array
	var radii: PackedFloat32Array = occupancy["radii"] as PackedFloat32Array
	for direction: Vector2i in OrbTypes.DIRECTIONS:
		for level: int in range(1, 4):
			var radius: float = Config.data.radius_for_level(level)
			for preferred_t: float in [-0.9, -0.37, 0.0, 0.41, 0.9]:
				var line: Dictionary = board.spawn_line(direction, radius)
				var preferred: Vector2 = (
					line["origin"] as Vector2
					+ (line["axis"] as Vector2) * float(line["extent"]) * preferred_t
				)
				var optimized: Dictionary = board._find_free_spawn_slot_in_occupancy(
					direction,
					radius,
					positions,
					radii,
					preferred
				)
				var reference: Dictionary = _brute_spawn_slot(
					board,
					direction,
					radius,
					positions,
					radii,
					preferred
				)
				assert_eq(
					optimized["found"],
					reference["found"],
					"optimized spawn found flag matches brute force"
				)
				assert_near(
					(optimized["position"] as Vector2).distance_to(
						reference["position"] as Vector2
					),
					0.0,
					POSITION_TOLERANCE,
					"optimized spawn position matches brute force"
				)
	await _cleanup_fixture(fixture)


func test_geometric_touching_pairs_match_brute_force_pairs() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	for row: int in range(4):
		for column: int in range(8):
			_spawn_normal(
				board,
				(column + row) % 4,
				1 + ((column * 2 + row) % 3),
				Vector2(-350.0 + float(column) * 100.0, -240.0 + float(row) * 160.0)
			)
	resolver._scan_geometric_contacts(false, true)
	var actual: Array[String] = []
	for pair_key_value: Variant in resolver._measurement_active_contacts.keys():
		actual.append(str(pair_key_value))
	actual.sort()
	var expected: Array[String] = _brute_reaction_pairs(board.get_orbs())
	assert_eq(actual, expected, "optimized touching reaction pairs match brute force")
	await _cleanup_fixture(fixture)


func test_pending_reaction_fast_path_matches_classification() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	for color_a: int in range(Config.data.color_display.size()):
		for color_b: int in range(Config.data.color_display.size()):
			for level_a: int in range(1, Config.data.orb_max_level + 1):
				for level_b: int in range(1, Config.data.orb_max_level + 1):
					var classified: Dictionary = ReactionRules.classify(
						color_a,
						level_a,
						color_b,
						level_b,
						Config.data
					)
					assert_eq(
						ReactionRules.can_react(
							color_a,
							level_a,
							color_b,
							level_b,
							Config.data
						),
						int(classified["type"]) != ReactionRules.Type.NONE,
						"fast reaction predicate matches classification"
					)
	var first: Orb3D = _spawn_normal(board, 0, 1, Vector2(-24.0, 0.0))
	var second: Orb3D = _spawn_normal(board, 0, 1, Vector2(24.0, 0.0))
	resolver._lock_reaction_result(first)
	assert_true(resolver.has_pending_reactions(), "touching locked pair remains pending")
	second.position = Vector2(300.0, 0.0)
	assert_true(not resolver.has_pending_reactions(), "separated locked pair is not pending")
	await _cleanup_fixture(fixture)


func test_ghost_overlap_snapshot_preserves_release_result() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var blocker: Orb3D = _spawn_normal(board, 1, 2, Vector2.ZERO)
	var ghost: Orb3D = _spawn_normal(board, 2, 1, Vector2(40.0, 0.0))
	ghost.enter_ghost_state(Config.data.ghost_alpha)
	var active_orbs: Array[Orb3D] = board.get_orbs()
	var brute_overlap: float = _brute_maximum_overlap(ghost, active_orbs)
	assert_near(
		board._maximum_normal_overlap_in(ghost, active_orbs),
		brute_overlap,
		POSITION_TOLERANCE,
		"ghost snapshot overlap matches brute force"
	)
	board._update_ghost_orbs(1.0 / 120.0)
	assert_true(ghost.is_ghost, "overlapping ghost remains ghost")
	blocker.position = Vector2(-300.0, 0.0)
	board._update_ghost_orbs(1.0 / 120.0)
	assert_true(not ghost.is_ghost, "cleared ghost releases on the same update")
	await _cleanup_fixture(fixture)


func _brute_spawn_slot(
	board: Board3D,
	gravity: Vector2i,
	radius: float,
	positions: PackedVector2Array,
	radii: PackedFloat32Array,
	preferred_position: Vector2
) -> Dictionary:
	var line: Dictionary = board.spawn_line(gravity, radius)
	var origin: Vector2 = line["origin"] as Vector2
	var axis: Vector2 = line["axis"] as Vector2
	var extent: float = float(line["extent"])
	var preferred_offset: float = clampf(
		(preferred_position - origin).dot(axis),
		-extent,
		extent
	)
	var preferred_candidate: Vector2 = origin + axis * preferred_offset
	if _brute_spawn_clear(preferred_candidate, radius, positions, radii):
		return {"found": true, "position": preferred_candidate}
	var step: float = maxf(Config.data.spawn_probe_step, 0.001)
	var sample_count: int = ceili(extent * 2.0 / step)
	var normalized_index: float = (preferred_offset + extent) / step
	var left_index: int = clampi(floori(normalized_index), 0, sample_count)
	var right_index: int = left_index + 1
	while left_index >= 0 or right_index <= sample_count:
		var choose_left: bool = right_index > sample_count
		var left_offset: float = INF
		var right_offset: float = INF
		if left_index >= 0:
			left_offset = minf(-extent + float(left_index) * step, extent)
		if right_index <= sample_count:
			right_offset = minf(-extent + float(right_index) * step, extent)
		if left_index >= 0 and right_index <= sample_count:
			var left_distance: float = absf(left_offset - preferred_offset)
			var right_distance: float = absf(right_offset - preferred_offset)
			choose_left = (
				left_distance < right_distance
				or (
					is_equal_approx(left_distance, right_distance)
					and left_offset < right_offset
				)
			)
		var offset: float = left_offset if choose_left else right_offset
		if choose_left:
			left_index -= 1
		else:
			right_index += 1
		if is_equal_approx(offset, preferred_offset):
			continue
		var candidate_position: Vector2 = origin + axis * offset
		if _brute_spawn_clear(candidate_position, radius, positions, radii):
			return {"found": true, "position": candidate_position}
	return {"found": false, "position": preferred_position}


func _brute_spawn_clear(
	candidate_position: Vector2,
	radius: float,
	positions: PackedVector2Array,
	radii: PackedFloat32Array
) -> bool:
	for index: int in range(positions.size()):
		var minimum_distance: float = radius + radii[index] - Config.data.ghost_exit_overlap
		if (
			minimum_distance > 0.0
			and candidate_position.distance_squared_to(positions[index])
			< minimum_distance * minimum_distance
		):
			return false
	return true


func _brute_reaction_pairs(orbs: Array[Orb3D]) -> Array[String]:
	var result: Array[String] = []
	for first_index: int in range(orbs.size()):
		var first: Orb3D = orbs[first_index]
		if first.is_ghost or first.is_waiting_at_entrance:
			continue
		for second_index: int in range(first_index + 1, orbs.size()):
			var second: Orb3D = orbs[second_index]
			if second.is_ghost or second.is_waiting_at_entrance:
				continue
			var contact_distance: float = (
				first.get_current_radius()
				+ second.get_current_radius()
				+ CollisionResolver.GEOMETRIC_CONTACT_TOLERANCE
			)
			if first.position.distance_squared_to(second.position) > contact_distance * contact_distance:
				continue
			var classified: Dictionary = ReactionRules.classify(
				first.color,
				first.level,
				second.color,
				second.level,
				Config.data,
				first.jelly_mass,
				second.jelly_mass
			)
			if int(classified["type"]) == ReactionRules.Type.NONE:
				continue
			result.append("%d:%d" % [first.stable_spawn_id, second.stable_spawn_id])
	result.sort()
	return result


func _brute_maximum_overlap(ghost: Orb3D, orbs: Array[Orb3D]) -> float:
	var maximum_overlap: float = 0.0
	for other: Orb3D in orbs:
		if other == ghost or other.is_ghost:
			continue
		maximum_overlap = maxf(
			maximum_overlap,
			ghost.get_current_radius()
			+ other.get_current_radius()
			- ghost.position.distance_to(other.position)
		)
	return maximum_overlap


func _spawn_normal(
	board: Board3D,
	color: int,
	level: int,
	position: Vector2
) -> Orb3D:
	var orb: Orb3D = board.spawn_orb(color, level, position)
	orb.exit_ghost_state()
	orb.set_gravity_vector(Vector2.ZERO, 0.0)
	orb.linear_velocity = Vector2.ZERO
	orb.angular_velocity = 0.0
	return orb


func _create_fixture() -> Dictionary:
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var fixture_root: Node3D = Node3D.new()
	fixture_root.name = "FullBoardPerformanceFixture"
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.name = "Board"
	board.unique_name_in_owner = true
	fixture_root.add_child(board)
	board.owner = fixture_root
	var resolver: CollisionResolver = COLLISION_RESOLVER_SCRIPT.new() as CollisionResolver
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	fixture_root.add_child(resolver)
	resolver.owner = fixture_root
	tree.root.add_child(fixture_root)
	await tree.process_frame
	board.set_physics_process(false)
	return {"root": fixture_root, "board": board, "resolver": resolver}


func _cleanup_fixture(fixture: Dictionary) -> void:
	var fixture_root: Node = fixture["root"] as Node
	fixture_root.queue_free()
	await tree.process_frame
