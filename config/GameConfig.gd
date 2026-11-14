class_name GameConfig
extends Resource

enum SpawnPositionMode { RANDOM, CENTER }
enum AnnihilationRule { A_BOTH, B_SAME_LEVEL, C_REMAINDER }
enum ShockMode { PUSH, PULL, SHAKE, LIFT }
enum JellyTapEffect { PUSH, NONE, BOMB, QUAKE, GROW, BONUS, MAGNET, REST }
enum GameMode {
	TURN = 0, # Legacy: kept for save compatibility and shared JELLY foundations.
	BLITZ = 1, # Legacy: kept for save compatibility only.
	SLIME = 2, # Legacy: kept for save compatibility only.
	JELLY = 3,
}

@export var game_mode: GameMode = GameMode.TURN
@export var board_size: float = 960.0
@export var wall_thickness: float = 256.0
@export var level_radii: PackedFloat32Array = PackedFloat32Array(
	[25.0, 40.0, 52.0, 68.0, 80.0, 92.0, 102.0, 115.0, 128.0, 140.0]
)
@export var orb_max_level: int = 10
@export var jelly_level_masses: PackedFloat32Array = PackedFloat32Array(
	[1.0, 2.0, 3.0, 5.0, 7.0, 11.0, 17.0, 27.0, 42.0, 64.0]
)
@export var orb_base_mass: float = 1.0
@export var mass_exponent: float = 2.0
@export var gravity_strength: float = 3600.0
@export var gravity_level_scale: float = 0.0333
@export var gravity_turn_diagonal_time: float = 0.15
@export var orb_friction: float = 0.3
@export var orb_friction_by_level: PackedFloat32Array = PackedFloat32Array(
	[0.3, 0.3, 0.3, 0.4, 0.4, 0.4, 0.4, 0.5, 0.5, 0.5]
)
@export var orb_bounce: float = 0.06
@export var wall_friction: float = 0.3
@export var wall_bounce: float = 0.06
@export var orb_linear_damp: float = 0.1
@export var orb_angular_damp: float = 15.0
@export var color_display: PackedColorArray = PackedColorArray(
	[
		Color("#D0503A"),
		Color("#2F6FD6"),
		Color("#35B97C"),
		Color("#E9C46A"),
		Color("#6C5CE7"),
		Color("#DCE3EC"),
	]
)
@export var orb_symbols_enabled: bool = false
@export var swipe_min_distance: float = 80.0
@export var swipe_dominance_ratio: float = 1.5
@export var stable_linear_speed: float = 12.0
@export var stable_angular_speed: float = 1.0
@export var stable_duration: float = 0.33
@export var max_settle_time: float = 3.0
@export var allow_same_direction_swipe: bool = false
@export var spawn_level_weights: PackedFloat32Array = PackedFloat32Array([0.9, 0.1])
@export var spawn_level_costs: PackedInt32Array = PackedInt32Array([1, 2])
@export var spawn_color_weights: PackedFloat32Array = PackedFloat32Array(
	[1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
)
@export var spawn_count_per_turn: int = 1
@export var preview_turns: int = 2
@export var spawn_count_ramp_turns: int = 10
@export var spawn_count_max: int = 4
@export var turn_start_colors: int = 4
@export var turn_color_unlock_turns: Array[int] = []
@export var spawn_position_mode: SpawnPositionMode = SpawnPositionMode.RANDOM
@export var spawn_margin: float = 4.0
@export var spawn_probe_step: float = 5.0
@export var rng_seed: int = 0
@export var initial_orb_count: int = 2
@export var contact_max_reported: int = 16
@export var rolling_resistance: float = 0.0
@export var rest_speed: float = 0.0
@export var rest_damp: float = 0.0
@export var floor_contact_tolerance: float = 2.0
@export var escape_guard_depth: float = 25.0
@export var grow_duration: float = 0.06
@export var grow_start_ratio: float = 0.3
@export var ghost_exit_overlap: float = 4.0
@export var ghost_max_time: float = 0.6
@export var ghost_alpha: float = 0.55
@export var wall_penetration_limit: float = 16.0
@export var opposite_pairs: Array[Vector2i] = []
@export var annihilation_rule: AnnihilationRule = AnnihilationRule.B_SAME_LEVEL
@export var level_scores: PackedInt32Array = PackedInt32Array(
	[2, 4, 6, 10, 14, 22, 34, 54, 84, 128]
)
@export var annihilation_score_factor: float = 0.5
@export var max_merge_bonus_factor: float = 40.0
@export var combo_multiplier_base: float = 2.0
@export var combo_multiplier_max: float = 128.0
@export var danger_start: float = 0.30
@export var danger_doubling: float = 0.20
@export var shock_impulse: float = 600.0
@export var shock_radius_factor: float = 2.5
@export var shock_level_scale: float = 0.2
@export var shock_jackpot_scale: float = 3.0
@export var color_effects_enabled: bool = true
@export var shock_color_modes: PackedInt32Array = PackedInt32Array(
	[
		ShockMode.PUSH,
		ShockMode.SHAKE,
		ShockMode.PUSH,
		ShockMode.LIFT,
		ShockMode.PULL,
		ShockMode.PUSH,
	]
)
@export var shock_color_impulse_scale: PackedFloat32Array = PackedFloat32Array(
	[1.5, 0.0, 1.0, 1.0, 0.8, 1.0]
)
@export var shock_color_radius_factor: PackedFloat32Array = PackedFloat32Array(
	[3.0, 0.0, 2.5, 3.0, 3.0, 2.5]
)
@export var green_shake_speed: float = 150.0
@export var green_shake_max_speed: float = 600.0
@export var chain_reaction_delay: float = 0.2
@export var jelly_merge_duration: float = 0.3
@export var jelly_merge_extension_max: float = 1.5
@export var jelly_merge_level_gap: int = 1
@export var jelly_merge_wide_gap_min_level: int = 0
@export var jelly_timed_enabled: bool = true
@export var jelly_timed_first_turn: int = 20
@export var jelly_timed_interval_turns: int = 12
@export var jelly_timed_level: int = 5
@export var jelly_timed_turns: int = 4
@export var jelly_timed_turns_min: int = 5
@export var jelly_timed_turns_max: int = 10
@export var jelly_timed_burst_count: int = 10
@export var jelly_timed_stone_enabled: bool = true
@export var jelly_timed_stone_turns: int = 18
@export var jelly_timed_fail_mode: int = 2
@export var jelly_timed_scatter_count: int = 5
@export var jelly_timed_bonus_levels: int = 1
@export var blast_enabled: bool = true
@export var blast_min_level: int = 4
@export var jelly_blast_min_level: int = 8
@export var jelly_blast_requires_same_level: bool = false
@export var blast_push_radius_by_level: PackedFloat32Array = PackedFloat32Array(
	[0.0, 0.0, 0.0, 0.3, 0.55, 1.0, 1.0, 1.0, 1.0, 1.0]
)
@export var jelly_tap_blast_min_level: int = 8
@export var jelly_tap_blast_radius_factor: float = 0.3
@export var jelly_tap_blast_score_factor: float = 0.5
@export var jelly_tap_blast_uses_turn: bool = true
@export var jelly_tap_blast_touch_margin: float = 16.0
@export var jelly_tap_clean_max_level: int = 1
@export var jelly_tap_clean_score_factor: float = 1.0
@export var jelly_tap_clean_visual_time: float = 0.25
@export var jelly_tap_clean_zone_rule: bool = true
@export var jelly_tap_grow_min_clean: int = 3
@export var jelly_tap_effect_modes: PackedInt32Array = PackedInt32Array(
	[
		JellyTapEffect.BOMB,
		JellyTapEffect.QUAKE,
		JellyTapEffect.REST,
		JellyTapEffect.MAGNET,
		JellyTapEffect.NONE,
		JellyTapEffect.NONE,
	]
)
@export var jelly_tap_quake_speed: float = 900.0
@export var jelly_tap_quake_floor_margin: float = 8.0
@export var jelly_tap_bonus_points_per_orb: int = 100
@export var jelly_tap_magnet_time: float = 0.5
@export var jelly_tap_rest_clean_count: int = 2
@export var jelly_tap_rest_clean_band_factor: float = 0.4
@export var jelly_tap_magnet_clean_radius_factor: float = 0.5
@export var jelly_tap_common_push: bool = true
@export var jelly_tap_lift_speed: float = 0.0
@export var jelly_tap_push_radius_factor: float = 0.5
@export var jelly_tap_push_speed: float = 1800.0
@export var blast_gravity_pause_time: float = 0.2
@export var blast_speed: float = 1350.0
@export var blast_far_factor: float = 0.5
@export var blast_score_factor: float = 15.0
@export var blast_blink_period: float = 0.8
@export var fx_enabled: bool = true
@export var fx_hitstop_enabled: bool = true
@export var fx_hitstop_scale: float = 0.12
@export var fx_hitstop_time: float = 0.07
@export var fx_shake_px: float = 16.0
@export var fx_shake_time: float = 0.4
@export var fx_flash_alpha: float = 0.35
@export var fx_flash_time: float = 0.15
@export var fx_debris_per_orb: int = 24
@export var fx_score_popups_enabled: bool = true
@export var fx_popup_max: int = 16
@export var fx_color_effect_visuals_enabled: bool = true
@export var fx_callouts_enabled: bool = true
@export var fx_tilt_degrees: float = 6.0
@export var fx_tilt_duration: float = 0.3
@export var fx_swipe_trail_enabled: bool = true
@export var fx_orb_stretch_enabled: bool = false
@export var haptics_enabled: bool = true
@export var sfx_enabled: bool = true
@export var sfx_volume_db: float = 0.0
@export var sfx_chain_semitones_max: int = 12
@export var sfx_pitch_jitter: float = 0.03


func radius_for_level(level: int) -> float:
	return level_radii[level - 1]


func mass_for_level(level: int) -> float:
	var radius_ratio: float = radius_for_level(level) / radius_for_level(1)
	return orb_base_mass * pow(radius_ratio, mass_exponent)


func jelly_mass_for_level(level: int) -> float:
	var safe_level: int = clampi(level, 1, orb_max_level)
	if jelly_level_masses.size() == orb_max_level:
		return jelly_level_masses[safe_level - 1]
	return pow(2.0, float(safe_level - 1))


func jelly_level_for_mass(mass: float) -> int:
	var clamped_mass: float = clampf(
		mass,
		jelly_mass_for_level(1),
		jelly_mass_for_level(orb_max_level)
	)
	if jelly_level_masses.size() != orb_max_level:
		return clampi(floori(log(clamped_mass) / log(2.0)) + 1, 1, orb_max_level)
	var resolved_level: int = 1
	for level: int in range(2, orb_max_level + 1):
		if jelly_mass_for_level(level) <= clamped_mass + 0.0001:
			resolved_level = level
		else:
			break
	return resolved_level


func jelly_fill_fraction_for_mass(mass: float) -> float:
	var level: int = jelly_level_for_mass(mass)
	if level >= orb_max_level:
		return 0.0
	var base_mass: float = jelly_mass_for_level(level)
	var next_mass: float = jelly_mass_for_level(level + 1)
	return clampf((mass - base_mass) / maxf(next_mass - base_mass, 0.0001), 0.0, 0.999999)


func jelly_radius_for_mass(mass: float) -> float:
	var clamped_mass: float = clampf(
		mass,
		jelly_mass_for_level(1),
		jelly_mass_for_level(orb_max_level)
	)
	return radius_for_level(jelly_level_for_mass(clamped_mass))


func mass_for_radius(radius: float) -> float:
	var radius_ratio: float = radius / radius_for_level(1)
	return orb_base_mass * pow(radius_ratio, mass_exponent)


func gravity_for_level(level: int) -> float:
	return gravity_strength * (1.0 + gravity_level_scale * float(level - 1))


func orb_friction_for_level(level: int) -> float:
	if game_mode != GameMode.JELLY or orb_friction_by_level.size() != orb_max_level:
		return orb_friction
	return orb_friction_by_level[clampi(level, 1, orb_max_level) - 1]


func score_for_level(level: int) -> int:
	return level_scores[level - 1]


func active_blast_min_level() -> int:
	if game_mode == GameMode.JELLY:
		return jelly_blast_min_level
	return blast_min_level


func blast_enabled_for_level(level: int) -> bool:
	var minimum_level: int = active_blast_min_level()
	return blast_enabled and minimum_level > 0 and level >= minimum_level


func jelly_blast_enabled_for_pair(level_a: int, level_b: int) -> bool:
	if jelly_blast_requires_same_level and level_a != level_b:
		return false
	return blast_enabled_for_level(level_a) and blast_enabled_for_level(level_b)


func jelly_tap_blast_enabled_for_level(level: int) -> bool:
	return jelly_tap_blast_min_level > 0 and level >= jelly_tap_blast_min_level


func jelly_tap_effect_for_color(color: int) -> JellyTapEffect:
	if color < 0 or color >= jelly_tap_effect_modes.size():
		return JellyTapEffect.PUSH
	var raw_mode: int = int(jelly_tap_effect_modes[color])
	if raw_mode < JellyTapEffect.PUSH or raw_mode > JellyTapEffect.REST:
		return JellyTapEffect.PUSH
	return raw_mode as JellyTapEffect


func blast_push_radius_factor_for_level(level: int) -> float:
	var index: int = level - 1
	if index < 0 or index >= blast_push_radius_by_level.size():
		return 0.0
	return maxf(blast_push_radius_by_level[index], 0.0)


func spawn_count_for_turn(turn_index: int) -> int:
	if spawn_count_ramp_turns <= 0:
		return spawn_count_per_turn
	var completed_ramps: int = floori(
		float(maxi(turn_index, 1) - 1) / float(spawn_count_ramp_turns)
	)
	var ramped_count: int = spawn_count_per_turn + completed_ramps
	if spawn_count_max <= 0:
		return ramped_count
	return mini(ramped_count, spawn_count_max)


func spawn_cost_for_level(level: int) -> int:
	var index: int = level - 1
	if index < 0 or index >= spawn_level_costs.size():
		return 1
	return maxi(spawn_level_costs[index], 1)


func color_count_for_turn(turn_index: int) -> int:
	var available_colors: int = spawn_color_weights.size()
	var count: int = clampi(turn_start_colors, 1, available_colors)
	for unlock_turn: int in turn_color_unlock_turns:
		if turn_index >= unlock_turn:
			count += 1
	return mini(count, available_colors)


func newly_unlocked_color_for_turn(turn_index: int) -> int:
	var unlocked_before: int = clampi(turn_start_colors, 1, spawn_color_weights.size())
	for unlock_turn: int in turn_color_unlock_turns:
		if turn_index == unlock_turn and unlocked_before < spawn_color_weights.size():
			return unlocked_before
		if turn_index > unlock_turn:
			unlocked_before += 1
	return -1


func is_opposite(c1: int, c2: int) -> bool:
	for pair: Vector2i in opposite_pairs:
		if (pair.x == c1 and pair.y == c2) or (pair.x == c2 and pair.y == c1):
			return true
	return false
