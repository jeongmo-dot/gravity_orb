class_name GameConfig
extends Resource

enum SpawnPositionMode { RANDOM, CENTER }
enum AnnihilationRule { A_BOTH, B_SAME_LEVEL, C_REMAINDER }

@export var board_size: float = 960.0
@export var wall_thickness: float = 256.0
@export var orb_base_radius: float = 50.0
@export var orb_radius_growth: float = 1.25
@export var orb_max_level: int = 7
@export var orb_base_mass: float = 1.0
@export var gravity_strength: float = 2400.0
@export var orb_friction: float = 0.3
@export var orb_bounce: float = 0.15
@export var wall_friction: float = 0.3
@export var wall_bounce: float = 0.1
@export var orb_linear_damp: float = 0.1
@export var orb_angular_damp: float = 1.0
@export var color_display: PackedColorArray = PackedColorArray(
	[Color("#E5484D"), Color("#3E7BFA"), Color("#30A46C")]
)
@export var swipe_min_distance: float = 80.0
@export var swipe_dominance_ratio: float = 1.5
@export var stable_linear_speed: float = 12.0
@export var stable_angular_speed: float = 1.0
@export var stable_duration: float = 0.33
@export var max_settle_time: float = 3.0
@export var allow_same_direction_swipe: bool = true
@export var spawn_level_weights: PackedFloat32Array = PackedFloat32Array([0.9, 0.1])
@export var spawn_color_weights: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0])
@export var spawn_position_mode: SpawnPositionMode = SpawnPositionMode.RANDOM
@export var spawn_margin: float = 4.0
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
@export var opposite_pairs: Array[Vector2i] = [
	Vector2i(OrbTypes.OrbColor.RED, OrbTypes.OrbColor.BLUE),
]
@export var annihilation_rule: AnnihilationRule = AnnihilationRule.B_SAME_LEVEL


func radius_for_level(level: int) -> float:
	return orb_base_radius * pow(orb_radius_growth, level - 1)


func mass_for_level(level: int) -> float:
	var radius_ratio: float = radius_for_level(level) / orb_base_radius
	return orb_base_mass * radius_ratio * radius_ratio


func is_opposite(c1: int, c2: int) -> bool:
	for pair: Vector2i in opposite_pairs:
		if (pair.x == c1 and pair.y == c2) or (pair.x == c2 and pair.y == c1):
			return true
	return false
