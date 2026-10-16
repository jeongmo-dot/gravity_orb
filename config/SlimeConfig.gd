class_name SlimeConfig
extends Resource

@export_category("Board")
@export var board_rect: Rect2 = Rect2(45.0, 180.0, 550.0, 700.0)

@export_category("Physics")
@export var gravity_acceleration: float = 2220.0
@export var damping: float = 0.981
@export var lateral_damping: float = 0.935
@export var rest_speed: float = 34.0
@export var settle_hold: float = 0.18
@export var soft_stop_start: float = 1.34
@export var soft_stop_factor: float = 0.82
@export var max_simulation_time: float = 1.85
@export var wall_restitution: float = 0.23
@export var pair_impulse_factor: float = 0.61
@export var solver_iterations: int = 4
@export var touch_margin: float = 0.75
@export var turn_kick_speed: float = 80.0
@export var stack_slip_speed: float = 105.0
@export var stack_slip_alignment: float = 0.18
@export var stack_slip_min_axis: float = 0.72
@export var stack_slip_max_impulse: float = 24.0
@export var stack_slip_lower_share: float = 0.12
@export var stack_slip_nudge: float = 0.22

@export_category("Slimes")
@export var radii: PackedFloat32Array = PackedFloat32Array([31.5, 42.0, 54.0, 68.0, 84.0, 101.0, 112.0])
@export var pre_max_radius: float = 108.0
@export var max_mass: int = 64
@export var max_slimes: int = 40
@export var slime_colors: PackedColorArray = PackedColorArray([
	Color("59e2ab"),
	Color("72a7ff"),
	Color("ff7595"),
	Color("ffad63"),
	Color("bc86ff"),
	Color("ffe77a"),
	Color("53dcde"),
])
@export var level_lighten: float = 0.018

@export_category("Spawning")
@export var spawn_level_weights: PackedFloat32Array = PackedFloat32Array([0.70, 0.25, 0.05])
@export var crowd_thresholds: PackedInt32Array = PackedInt32Array([10, 16])
@export var low_crowd_spawn_count: int = 3
@export var low_crowd_bonus_chance: float = 0.30
@export var low_crowd_bonus_count: int = 4
@export var medium_crowd_spawn_count: int = 2
@export var high_crowd_spawn_count: int = 1
@export var turn_level_two_floor: int = 30
@export var turn_level_three_floor: int = 60
@export var color_bag_copies: int = 2
@export var spawn_speed: float = 90.0
@export var intro_initial_delay: float = 0.03
@export var intro_delay_step: float = 0.30
@export var intro_abandon_time: float = 0.90
@export var entry_margin: float = 5.0
@export var start_colors: int = 3
@export var unlock_scores: PackedInt32Array = PackedInt32Array([50000, 150000, 300000, 500000])
@export var unlock_grace_waves: int = 2
@export var unlock_grace_max_count: int = 2
@export var forced_new_color_slots: int = 2

@export_category("Scoring")
@export var score_per_mass: int = 25
@export var max_completion_bonus: int = 2500
@export var max_clear_score: int = 7500
@export var chain_multiplier_step: float = 0.25
@export var chain_multiplier_max_steps: int = 7
@export var merge_velocity_keep: float = 0.35
@export var max_clear_push_radius: float = 165.0
@export var max_clear_push_speed: float = 180.0

@export_category("Entry danger")
@export var entry_danger_clearance: float = 15.0
@export var entry_caution_clearance: float = 70.0

@export_category("Initial admission")
@export var initial_count: int = 4
@export var initial_levels: PackedInt32Array = PackedInt32Array([0, 0, 0, 1])
@export var initial_lanes: PackedFloat32Array = PackedFloat32Array([0.08, 0.22, 0.36, 0.50, 0.64, 0.78, 0.92])
@export var initial_lane_jitter: float = 0.035
@export var initial_lane_min: float = 0.07
@export var initial_lane_max: float = 0.93
@export var initial_delay: float = 0.10
@export var initial_delay_step: float = 0.105
@export var initial_delay_jitter: float = 0.055

@export_category("Feedback events")
@export var wall_impact_divisor: float = 900.0
@export var pair_impact_divisor: float = 850.0
@export var sound_impact_threshold: float = 0.22
@export var collision_sound_cooldown: float = 0.09
@export var gravity_flash_duration: float = 0.28
