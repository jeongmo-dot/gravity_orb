class_name GameConfig
extends Resource

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
@export var debug_test_orb_count: int = 5
@export var swipe_min_distance: float = 80.0
@export var swipe_dominance_ratio: float = 1.5


func radius_for_level(level: int) -> float:
	return orb_base_radius * pow(orb_radius_growth, level - 1)


func mass_for_level(level: int) -> float:
	var radius_ratio: float = radius_for_level(level) / orb_base_radius
	return orb_base_mass * radius_ratio * radius_ratio
