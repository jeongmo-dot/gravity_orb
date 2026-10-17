extends TestCase

const CONFIG: SlimeConfig = preload("res://config/slime_config.tres")
const DT: float = 1.0 / 60.0


func test_same_color_max_absorbs_and_different_color_max_clears() -> void:
	var same_color := _empty_sim(10)
	same_color.turn = 1
	var radius: float = same_color.radius_for_mass(64)
	same_color.add_slime(Vector2(190.0, 500.0), 6, 0, Vector2.ZERO, 64)
	same_color.add_slime(Vector2(190.0 + radius * 2.0, 500.0), 6, 0, Vector2.ZERO, 64)
	same_color.resolve_pairs()
	assert_eq(same_color.slimes.size(), 1, "same-color max slimes absorb")
	assert_eq(same_color.slimes[0].mass, 128, "max masses add without cap")
	assert_eq(same_color.slimes[0].level, 6, "grown max remains level six")
	assert_near(same_color.slimes[0].radius, 128.65, 0.05, "mass 128 radius")
	assert_eq(same_color.score, 128 * 25, "grown max scores raw mass without bonus")
	assert_eq(same_color.max_completions, 0, "grown max does not complete twice")

	var different_color := _empty_sim(11)
	different_color.turn = 1
	different_color.add_slime(Vector2(190.0, 500.0), 6, 0, Vector2.ZERO, 64)
	different_color.add_slime(Vector2(190.0 + radius * 2.0, 500.0), 6, 1, Vector2.ZERO, 64)
	different_color.resolve_pairs()
	assert_eq(different_color.slimes.size(), 0, "different-color max slimes disappear")
	assert_eq(different_color.score, 7500, "different-color max clear score")
	assert_eq(different_color.chain, 1, "max clear starts chain")


func test_max_absorbs_smaller_same_color_without_second_completion_bonus() -> void:
	var sim := _empty_sim(12)
	sim.turn = 1
	var max_radius: float = sim.radius_for_mass(64)
	var small_radius: float = sim.radius_for_mass(1)
	sim.add_slime(Vector2(190.0, 500.0), 6, 1, Vector2.ZERO, 64)
	sim.add_slime(Vector2(190.0 + max_radius + small_radius, 500.0), 0, 1)
	sim.resolve_pairs()
	assert_eq(sim.slimes.size(), 1, "max absorbs smaller slime")
	assert_eq(sim.slimes[0].mass, 65, "mass 65 retained")
	assert_near(sim.slimes[0].radius, sim.radius_for_mass(65), 1.0e-6, "mass 65 radius")
	assert_eq(sim.score, 65 * 25, "no second max bonus")
	assert_eq(sim.max_completions, 0, "no second max completion")
	assert_true(sim.completed_colors.is_empty(), "no completed color added after prior max")


func test_overflow_merge_caps_mass_and_scores_raw_mass() -> void:
	var sim := _empty_sim_with_growth(20, false)
	sim.turn = 1
	var a_radius: float = sim.radius_for_mass(40)
	var b_radius: float = sim.radius_for_mass(30)
	sim.add_slime(Vector2(190.0, 500.0), sim.level_for_mass(40), 2, Vector2.ZERO, 40)
	sim.add_slime(Vector2(190.0 + a_radius + b_radius, 500.0), sim.level_for_mass(30), 2, Vector2.ZERO, 30)
	sim.resolve_pairs()
	assert_eq(sim.slimes.size(), 1, "overflow merges")
	assert_eq(sim.slimes[0].mass, 64, "mass caps at 64")
	assert_eq(sim.score, 70 * 25 + 2500, "raw mass plus max bonus")
	assert_eq(sim.max_completions, 1, "max completion observed")
	var events: Array[Dictionary] = sim.drain_events()
	var max_event_count: int = 0
	for event: Dictionary in events:
		if event.get("type", "") == "max_completed":
			max_event_count += 1
	assert_eq(max_event_count, 1, "max completion emits its own event")


func test_max_slime_does_not_absorb_smaller_same_color() -> void:
	var sim := _empty_sim_with_growth(21, false)
	var max_radius: float = sim.radius_for_mass(64)
	var small_radius: float = sim.radius_for_mass(1)
	sim.add_slime(Vector2(190.0, 500.0), 6, 1, Vector2.ZERO, 64)
	sim.add_slime(Vector2(190.0 + max_radius + small_radius, 500.0), 0, 1)
	sim.resolve_pairs()
	assert_eq(sim.slimes.size(), 2, "max and small remain separate")
	assert_eq(sim.score, 0, "no score")


func test_disabled_max_growth_restores_same_color_max_clear() -> void:
	var sim := _empty_sim_with_growth(211, false)
	sim.turn = 1
	var radius: float = sim.radius_for_mass(64)
	sim.add_slime(Vector2(190.0, 500.0), 6, 3, Vector2.ZERO, 64)
	sim.add_slime(Vector2(190.0 + radius * 2.0, 500.0), 6, 3, Vector2.ZERO, 64)
	sim.resolve_pairs()
	assert_eq(sim.slimes.size(), 0, "disabled flag restores original same-color max clear")
	assert_eq(sim.score, 7500, "disabled flag restores max clear score")


func test_chain_multiplier_rounding_and_turn_zero_exclusion() -> void:
	var sim := _empty_sim(22)
	sim.turn = 1
	_add_touching_pair(sim, Vector2(130.0, 300.0), 0)
	sim.resolve_pairs()
	_add_touching_pair(sim, Vector2(400.0, 700.0), 1)
	sim.resolve_pairs()
	assert_eq(sim.chain, 2, "two reactions form chain")
	assert_eq(sim.score, 113, "50 + round(62.5)")
	assert_eq(sim.run_best_chain, 2, "run best chain")

	var admission := _empty_sim(23)
	_add_touching_pair(admission, Vector2(240.0, 500.0), 0)
	admission.resolve_pairs()
	assert_eq(admission.score, 50, "turn zero base score")
	assert_eq(admission.chain, 0, "turn zero excluded from chain")


func test_entry_blocking_all_directions_and_final_move_results() -> void:
	var blocked := _empty_sim(30)
	_add_entry_blockers(blocked)
	assert_true(blocked.all_entries_blocked(), "all four level-zero entries blocked")
	blocked.moving = true
	blocked.final_move_active = true
	blocked.turn = 8
	blocked.finish_turn()
	assert_true(blocked.game_over, "blocked final move ends game")
	assert_true(blocked.next_slimes.is_empty(), "game over clears preview")

	var survived := _empty_sim(31)
	survived.add_slime(Vector2(320.0, 700.0), 0, 0)
	survived.moving = true
	survived.final_move_active = true
	survived.turn = 8
	survived.finish_turn()
	assert_true(not survived.game_over, "open entry survives final move")
	assert_eq(survived.final_move_success_count, 1, "success observed")


func test_each_blocked_entry_waits_then_enters_and_final_move_spawns_nothing() -> void:
	for direction: Vector2i in SlimeSim.DIRECTIONS:
		var sim := _empty_sim(32 + direction.x * 3 + direction.y)
		var radius: float = sim.radius_for_level(0)
		var blocker: SlimeSim.SlimeBody = sim.add_slime(sim.entry_position_for(direction, radius), 0, 0)
		sim.set_next_slimes([{"level": 0, "color": 1}])
		assert_true(sim.start_turn(direction), "blocked direction still starts")
		sim._update_intro(0.04)
		assert_eq(sim.intro_queue.size(), 1, "blocked entry waits for %s" % direction)
		assert_eq(sim.slimes.size(), 1, "blocked entry cannot overlap")
		blocker.position = sim.config.board_rect.get_center()
		sim._update_intro(0.01)
		assert_true(sim.intro_queue.is_empty(), "waiting slime enters after opening")
		assert_eq(sim.slimes.size(), 2, "one waiting slime entered")

	var final_move := _empty_sim(39)
	final_move.final_move_pending = true
	final_move.set_next_slimes([{"level": 0, "color": 2}])
	assert_true(final_move.start_turn(Vector2i.DOWN), "final move starts")
	assert_true(final_move.intro_queue.is_empty(), "final move creates no admission queue")
	assert_eq(final_move.next_slimes.size(), 1, "final move preserves NEXT")


func test_color_bag_has_two_of_each_and_unlock_forces_first_two() -> void:
	var bag_sim := _empty_sim(40)
	var counts: Array[int] = [0, 0, 0]
	for index: int in range(6):
		var color_index: int = bag_sim.roll_color()
		counts[color_index] += 1
	assert_eq(counts, [2, 2, 2], "two copies per active color")

	var unlock_sim := _empty_sim(41)
	unlock_sim.score = 50000
	unlock_sim.roll_next_batch()
	assert_eq(unlock_sim.active_color_count, 4, "fourth color unlocks")
	assert_eq(unlock_sim.next_slimes.size(), 2, "unlock grace caps the batch")
	for entry: Dictionary in unlock_sim.next_slimes:
		assert_eq(int(entry["color"]), 3, "new color forced into both slots")


func test_all_unlock_score_boundaries() -> void:
	var sim := _empty_sim(42)
	for index: int in range(CONFIG.unlock_scores.size()):
		var expected_before: int = CONFIG.start_colors + index
		sim.score = CONFIG.unlock_scores[index] - 1
		sim._check_color_unlocks()
		assert_eq(sim.active_color_count, expected_before, "threshold minus one stays locked")
		sim.score = CONFIG.unlock_scores[index]
		sim._check_color_unlocks()
		assert_eq(sim.active_color_count, expected_before + 1, "exact threshold unlocks")


func test_level_distribution_is_70_25_5_within_tolerance() -> void:
	var sim := _empty_sim(50)
	var counts: Array[int] = [0, 0, 0]
	for index: int in range(10000):
		counts[sim.roll_level()] += 1
	assert_near(float(counts[0]) / 10000.0, 0.70, 0.015, "level zero distribution")
	assert_near(float(counts[1]) / 10000.0, 0.25, 0.015, "level one distribution")
	assert_near(float(counts[2]) / 10000.0, 0.05, 0.015, "level two distribution")


func test_batch_count_crowding_turn_floors_and_cap() -> void:
	var medium := _empty_sim(60)
	_add_separated_slimes(medium, 10)
	medium.roll_next_batch()
	assert_eq(medium.next_slimes.size(), 2, "medium crowd count")

	var high := _empty_sim(61)
	_add_separated_slimes(high, 16)
	high.turn = 1
	high.roll_next_batch()
	assert_eq(high.next_slimes.size(), 1, "high crowd count")
	high.turn = 30
	high.roll_next_batch()
	assert_eq(high.next_slimes.size(), 2, "turn 30 floor")
	high.turn = 60
	high.roll_next_batch()
	assert_eq(high.next_slimes.size(), 3, "turn 60 floor")

	var capped := _empty_sim(62)
	_add_separated_slimes(capped, 39)
	capped.turn = 60
	capped.roll_next_batch()
	assert_eq(capped.next_slimes.size(), 1, "40 slime cap")


func test_batch_count_table_and_unlock_grace() -> void:
	for slime_count: int in [9, 10, 15, 16]:
		var sim := _empty_sim(63 + slime_count)
		_add_separated_slimes(sim, slime_count)
		sim.turn = 29
		var base_count: int = sim._roll_batch_count()
		if slime_count == 9:
			assert_true(base_count == 3 or base_count == 4, "low crowd rolls 3 or 4")
		elif slime_count < 16:
			assert_eq(base_count, 2, "10..15 crowd rolls 2")
		else:
			assert_eq(base_count, 1, "16+ crowd rolls 1")
		sim.turn = 30
		assert_true(sim._roll_batch_count() >= 2, "turn 30 minimum 2")
		sim.turn = 60
		assert_true(sim._roll_batch_count() >= 3, "turn 60 minimum 3")
		sim.unlock_grace_waves_left = 1
		sim.roll_next_batch()
		assert_true(sim.next_slimes.size() <= 2, "unlock grace caps at two")


func test_intro_wait_abandons_entire_batch_after_point_nine_seconds() -> void:
	var sim := _empty_sim(70)
	var spawn_position: Vector2 = sim.entry_position_for(Vector2i.DOWN, sim.radius_for_level(0), 0.5)
	sim.add_slime(spawn_position, 0, 0)
	sim.gravity_direction = Vector2i.DOWN
	sim.intro_queue = [
		{"delay": 0.0, "lane": 0.5, "color": 1, "level": 0},
		{"delay": 0.3, "lane": 0.5, "color": 2, "level": 0},
	]
	sim._update_intro(0.91)
	assert_true(sim.intro_queue.is_empty(), "whole waiting batch cancelled")
	assert_eq(sim.intro_cancel_count, 1, "cancellation observed")
	assert_eq(sim.slimes.size(), 1, "no queued slime entered")


func test_entry_stage_threshold_boundaries() -> void:
	var sim := _empty_sim(71)
	var radius: float = sim.radius_for_level(0)
	var entry: Vector2 = sim.entry_position_for(Vector2i.DOWN, radius)
	sim.add_slime(entry + Vector2(0.0, radius * 2.0 + sim.config.entry_margin + 14.999), 0, 0)
	assert_eq(sim.entry_stage_for(Vector2i.DOWN), 2, "below 15 is danger")
	sim.slimes[0].position = entry + Vector2(0.0, radius * 2.0 + sim.config.entry_margin + 15.0)
	assert_eq(sim.entry_stage_for(Vector2i.DOWN), 1, "15 is caution")
	sim.slimes[0].position = entry + Vector2(0.0, radius * 2.0 + sim.config.entry_margin + 70.0)
	assert_eq(sim.entry_stage_for(Vector2i.DOWN), 0, "70 is safe")


func test_stack_slip_acts_for_all_gravity_directions() -> void:
	for direction: Vector2i in SlimeSim.DIRECTIONS:
		var sim := _empty_sim(80 + direction.x * 3 + direction.y)
		sim.gravity_direction = direction
		var tangent := Vector2(-direction.y, direction.x)
		var center := Vector2(320.0, 520.0)
		var target: float = sim.radius_for_level(0) * 2.0
		var upper: SlimeSim.SlimeBody = sim.add_slime(center - Vector2(direction) * (target - 1.0) * 0.5, 0, 0)
		var lower: SlimeSim.SlimeBody = sim.add_slime(center + Vector2(direction) * (target - 1.0) * 0.5, 0, 1)
		sim.resolve_pairs()
		assert_true(absf(upper.velocity.dot(tangent)) > 0.0, "upper slips for %s" % direction)
		assert_true(absf(lower.velocity.dot(tangent)) > 0.0, "lower receives share for %s" % direction)


func test_mass_growth_is_monotonic_and_eight_plus_sixteen_is_twenty_four() -> void:
	var sim := _empty_sim(89)
	var previous_radius: float = 0.0
	for mass_value: int in range(1, CONFIG.max_mass + 1):
		var radius: float = sim.radius_for_mass(mass_value)
		assert_true(radius >= previous_radius, "radius monotonic at mass %d" % mass_value)
		previous_radius = radius
	sim.turn = 1
	var radius_eight: float = sim.radius_for_mass(8)
	var radius_sixteen: float = sim.radius_for_mass(16)
	sim.add_slime(Vector2(170.0, 500.0), 3, 2, Vector2.ZERO, 8)
	sim.add_slime(Vector2(170.0 + radius_eight + radius_sixteen, 500.0), 4, 2, Vector2.ZERO, 16)
	sim.resolve_pairs()
	assert_eq(sim.slimes.size(), 1, "8 + 16 merge")
	assert_eq(sim.slimes[0].mass, 24, "unequal mass sum retained")
	assert_near(sim.slimes[0].radius, sim.radius_for_mass(24), 1.0e-6, "mass formula radius")


func test_max_growth_radius_is_monotonic_capped_and_wall_safe() -> void:
	var sim := _empty_sim(891)
	var previous_radius: float = sim.radius_for_mass(CONFIG.max_mass)
	for mass_value: int in range(CONFIG.max_mass + 1, 1025):
		var radius: float = sim.radius_for_mass(mass_value)
		assert_true(radius >= previous_radius, "grown radius monotonic at mass %d" % mass_value)
		assert_true(radius <= CONFIG.max_growth_radius_cap, "grown radius cap at mass %d" % mass_value)
		previous_radius = radius
	assert_near(sim.radius_for_mass(1024), 165.0, 1.0e-6, "grown radius reaches cap")
	var body: SlimeSim.SlimeBody = sim.add_slime(Vector2(-500.0, 2000.0), 6, 0, Vector2.ZERO, 1024)
	sim._resolve_wall(body)
	var board: Rect2 = CONFIG.board_rect
	assert_true(body.position.x - body.radius >= board.position.x - 1.0e-6, "large max stays inside left wall")
	assert_true(body.position.y + body.radius <= board.end.y + 1.0e-6, "large max stays inside bottom wall")


func test_max_completion_bonus_and_color_apply_only_on_first_crossing() -> void:
	var sim := _empty_sim(892)
	sim.turn = 1
	var radius_32: float = sim.radius_for_mass(32)
	sim.add_slime(Vector2(190.0, 500.0), 5, 2, Vector2.ZERO, 32)
	sim.add_slime(Vector2(190.0 + radius_32 * 2.0, 500.0), 5, 2, Vector2.ZERO, 32)
	sim.resolve_pairs()
	assert_eq(sim.score, 64 * 25 + 2500, "first crossing receives completion bonus")
	assert_eq(sim.max_completions, 1, "first crossing counted once")
	assert_true(sim.completed_colors.has(2), "first crossing completes color")
	var radius_64: float = sim.radius_for_mass(64)
	var radius_1: float = sim.radius_for_mass(1)
	var score_before_growth: int = sim.score
	sim.slimes[0].position = Vector2(190.0, 500.0)
	sim.add_slime(Vector2(190.0 + radius_64 + radius_1, 500.0), 0, 2)
	sim.resolve_pairs()
	assert_eq(sim.score - score_before_growth, roundi(65.0 * 25.0 * 1.25), "later growth gets raw mass chain score without max bonus")
	assert_eq(sim.max_completions, 1, "later growth does not repeat completion")


func test_chain_multiplier_caps_at_two_point_seven_five_from_eighth() -> void:
	var sim := _empty_sim(90)
	sim.turn = 1
	var previous_score: int = 0
	for index: int in range(10):
		sim._add_chain_score(100)
		var gained: int = sim.score - previous_score
		previous_score = sim.score
		if index >= 7:
			assert_eq(gained, 275, "chain multiplier capped from eighth reaction")


func test_same_seed_inputs_and_visual_toggle_keep_identical_physics() -> void:
	var first := SlimeSim.new(CONFIG, 91, true, true)
	var second := SlimeSim.new(CONFIG, 91, true, true)
	var no_visuals := SlimeSim.new(CONFIG, 91, false, true)
	var directions: Array[Vector2i] = [Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT]
	_settle(first)
	_settle(second)
	_settle(no_visuals)
	for index: int in range(30):
		if first.game_over:
			break
		var direction: Vector2i = directions[index % directions.size()]
		assert_true(first.start_turn(direction), "first turn starts")
		assert_true(second.start_turn(direction), "second turn starts")
		assert_true(no_visuals.start_turn(direction), "no-visual turn starts")
		_settle(first)
		_settle(second)
		_settle(no_visuals)
		assert_eq(first.state_hash(), second.state_hash(), "same seed/input determinism")
		assert_eq(first.state_hash(), no_visuals.state_hash(), "visual state cannot affect simulation")


func test_fixed_step_accumulation_matches_60_and_120_hz() -> void:
	var at_sixty := SlimeSim.new(CONFIG, 92, false, true)
	var at_one_twenty := SlimeSim.new(CONFIG, 92, false, true)
	var accumulator_sixty: float = 0.0
	var accumulator_one_twenty: float = 0.0
	for frame: int in range(300):
		accumulator_sixty = _advance_accumulator(at_sixty, accumulator_sixty, DT)
	for frame: int in range(600):
		accumulator_one_twenty = _advance_accumulator(at_one_twenty, accumulator_one_twenty, DT * 0.5)
	assert_eq(at_sixty.state_hash(), at_one_twenty.state_hash(), "render rate independent fixed simulation")


func _empty_sim(seed_value: int) -> SlimeSim:
	return SlimeSim.new(CONFIG, seed_value, false, false)


func _empty_sim_with_growth(seed_value: int, enabled: bool) -> SlimeSim:
	var local_config: SlimeConfig = CONFIG.duplicate(true) as SlimeConfig
	local_config.max_growth_enabled = enabled
	return SlimeSim.new(local_config, seed_value, false, false)


func _add_touching_pair(sim: SlimeSim, center: Vector2, color_index: int) -> void:
	var radius: float = sim.radius_for_level(0)
	sim.add_slime(center - Vector2(radius, 0.0), 0, color_index)
	sim.add_slime(center + Vector2(radius, 0.0), 0, color_index)


func _add_entry_blockers(sim: SlimeSim) -> void:
	var radius: float = sim.radius_for_level(0)
	for direction: Vector2i in SlimeSim.DIRECTIONS:
		sim.add_slime(sim.entry_position_for(direction, radius), 0, 0)


func _add_separated_slimes(sim: SlimeSim, count: int) -> void:
	for index: int in range(count):
		var column: int = index % 8
		var row: int = index / 8
		sim.add_slime(Vector2(85.0 + column * 64.0, 300.0 + row * 80.0), 0, index % 3)


func _settle(sim: SlimeSim) -> void:
	var safety: int = 0
	while sim.moving and safety < 240:
		sim.step(DT)
		safety += 1
	assert_true(not sim.moving, "simulation settles within cap")


func _advance_accumulator(sim: SlimeSim, accumulator: float, elapsed: float) -> float:
	accumulator += elapsed
	while accumulator + 1.0e-9 >= DT:
		sim.step(DT)
		accumulator -= DT
	return accumulator
