class_name GameConfig
extends Resource

enum SpawnPositionMode { RANDOM, CENTER }
enum AnnihilationRule { A_BOTH, B_SAME_LEVEL, C_REMAINDER }
enum ShockMode { PUSH, PULL, SHAKE, LIFT }
enum GameMode { TURN, BLITZ }

@export var game_mode: GameMode = GameMode.TURN
@export var board_size: float = 960.0
@export var wall_thickness: float = 256.0
@export var level_radii: PackedFloat32Array = PackedFloat32Array(
	[25.0, 40.0, 60.0, 85.0, 100.0, 120.0, 140.0]
)
@export var orb_max_level: int = 7
@export var orb_base_mass: float = 1.0
@export var mass_exponent: float = 2.0
@export var gravity_strength: float = 1800.0
@export var gravity_level_scale: float = 0.1
@export var orb_friction: float = 0.3
@export var orb_bounce: float = 0.15
@export var wall_friction: float = 0.3
@export var wall_bounce: float = 0.1
@export var orb_linear_damp: float = 0.1
@export var orb_angular_damp: float = 1.0
@export var color_display: PackedColorArray = PackedColorArray(
	[
		Color("#E5484D"),
		Color("#3E7BFA"),
		Color("#30A46C"),
		Color("#F5C542"),
		Color("#A35CF0"),
		Color("#22C7D9"),
	]
)
@export var orb_symbols_enabled: bool = true
@export var swipe_min_distance: float = 80.0
@export var swipe_dominance_ratio: float = 1.5
@export var stable_linear_speed: float = 12.0
@export var stable_angular_speed: float = 1.0
@export var stable_duration: float = 0.33
@export var max_settle_time: float = 3.0
@export var allow_same_direction_swipe: bool = true
@export var spawn_level_weights: PackedFloat32Array = PackedFloat32Array([0.9, 0.1])
@export var spawn_color_weights: PackedFloat32Array = PackedFloat32Array(
	[1.0, 1.0, 1.0, 1.0, 0.0, 0.0]
)
@export var spawn_count_per_turn: int = 1
@export var preview_turns: int = 2
@export var spawn_count_ramp_turns: int = 0
@export var spawn_count_max: int = 3
@export var spawn_position_mode: SpawnPositionMode = SpawnPositionMode.RANDOM
@export var spawn_margin: float = 4.0
@export var spawn_probe_step: float = 5.0
@export var rng_seed: int = 0
@export var initial_orb_count: int = 2
@export var contact_max_reported: int = 6
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
@export var level_scores: PackedInt32Array = PackedInt32Array([2, 4, 8, 16, 32, 64, 128])
@export var annihilation_score_factor: float = 0.5
@export var max_merge_bonus_factor: float = 5.0
@export var combo_multiplier_base: float = 2.0
@export var danger_start: float = 0.30
@export var danger_doubling: float = 0.20
@export var shock_impulse: float = 600.0
@export var shock_radius_factor: float = 2.5
@export var shock_level_scale: float = 0.3
@export var shock_jackpot_scale: float = 3.0
@export var color_effects_enabled: bool = true
@export var shock_color_modes: PackedInt32Array = PackedInt32Array(
	[
		ShockMode.PUSH,
		ShockMode.PULL,
		ShockMode.SHAKE,
		ShockMode.LIFT,
		ShockMode.PUSH,
		ShockMode.PUSH,
	]
)
@export var shock_color_impulse_scale: PackedFloat32Array = PackedFloat32Array(
	[1.5, 0.8, 0.0, 1.0, 1.0, 1.0]
)
@export var shock_color_radius_factor: PackedFloat32Array = PackedFloat32Array(
	[3.0, 3.0, 0.0, 3.0, 2.5, 2.5]
)
@export var green_shake_speed: float = 150.0
@export var green_shake_max_speed: float = 600.0
@export var chain_reaction_delay: float = 0.2
@export var blast_enabled: bool = true
@export var blast_min_level: int = 6
@export var blast_speed: float = 900.0
@export var blast_far_factor: float = 0.4
@export var blast_score_factor: float = 5.0
@export var blast_blink_period: float = 0.8
@export var blitz_duration: float = 90.0
@export var blitz_swipe_cooldown: float = 0.12
@export var blitz_spawn_on_swipe: bool = true
@export var blitz_min_spawn_per_swipe: int = 1
@export var blitz_max_spawn_per_swipe: int = 8
@export var blitz_spawn_interval: float = 0.8
@export var blitz_spawn_level_weights: PackedFloat32Array = PackedFloat32Array(
	[0.7, 0.25, 0.05]
)
@export var blitz_spawn_color_weights: PackedFloat32Array = PackedFloat32Array(
	[1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
)
@export var blitz_initial_occupancy: float = 0.35
@export var blitz_target_occupancy: float = 0.40
@export var blitz_refill_interval: float = 0.15
@export var blitz_ready_time: float = 1.5
@export var blitz_chain_window: float = 1.0
@export var blitz_chain_idle: float = 2.0
@export var blitz_chain_step: float = 0.25
@export var blitz_chain_max_multiplier: float = 5.0
@export var blitz_fever_chain: int = 6
@export var blitz_fever_duration: float = 3.0
@export var blitz_fever_multiplier: float = 2.0
@export var blitz_time_bonus_blast: float = 1.0
@export var blitz_time_bonus_jackpot: float = 3.0
@export var blitz_time_bonus_cap: float = 20.0
@export var blitz_blast_min_level: int = 4
@export var blitz_finale_interval: float = 0.3
@export var fx_enabled: bool = true
@export var fx_hitstop_enabled: bool = true
@export var fx_hitstop_scale: float = 0.12
@export var fx_hitstop_time: float = 0.07
@export var fx_shake_px: float = 16.0
@export var fx_shake_time: float = 0.4
@export var fx_flash_alpha: float = 0.35
@export var fx_flash_time: float = 0.15
@export var fx_ring_radius_factor: float = 4.0
@export var fx_debris_per_orb: int = 24
@export var sfx_enabled: bool = true
@export var sfx_volume_db: float = 0.0
@export var sfx_chain_semitones_max: int = 12
@export var sfx_pitch_jitter: float = 0.03


func radius_for_level(level: int) -> float:
	return level_radii[level - 1]


func mass_for_level(level: int) -> float:
	var radius_ratio: float = radius_for_level(level) / radius_for_level(1)
	return orb_base_mass * pow(radius_ratio, mass_exponent)


func gravity_for_level(level: int) -> float:
	return gravity_strength * (1.0 + gravity_level_scale * float(level - 1))


func score_for_level(level: int) -> int:
	return level_scores[level - 1]


func active_blast_min_level() -> int:
	if game_mode == GameMode.BLITZ:
		return blitz_blast_min_level
	return blast_min_level


func spawn_count_for_turn(turn_index: int) -> int:
	if spawn_count_ramp_turns <= 0:
		return spawn_count_per_turn
	var completed_ramps: int = floori(
		float(maxi(turn_index, 1) - 1) / float(spawn_count_ramp_turns)
	)
	return mini(spawn_count_per_turn + completed_ramps, spawn_count_max)


func is_opposite(c1: int, c2: int) -> bool:
	for pair: Vector2i in opposite_pairs:
		if (pair.x == c1 and pair.y == c2) or (pair.x == c2 and pair.y == c1):
			return true
	return false
