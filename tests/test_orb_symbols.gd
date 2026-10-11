extends TestCase

const BOARD_2D_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const BOARD_3D_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const ORB_3D_SCENE: PackedScene = preload("res://scenes/Orb3D.tscn")
const EXPECTED_NAMES: Array[String] = [
	"triangle",
	"circle",
	"square",
	"diamond",
	"star",
	"plus",
]


func test_color_symbol_mapping_has_six_distinct_polygon_shapes() -> void:
	var point_counts: Array[int] = []
	for color: int in range(OrbSymbols.SYMBOL_COUNT):
		assert_eq(
			OrbSymbols.symbol_name_for_color(color),
			EXPECTED_NAMES[color],
			"symbol name %d" % color
		)
		var polygons: Array[PackedVector2Array] = OrbSymbols.polygons_for_color(color)
		assert_eq(polygons.size(), 1, "one polygon for color %d" % color)
		if not polygons.is_empty():
			point_counts.append(polygons[0].size())
	assert_eq(point_counts, [3, 24, 4, 4, 10, 12], "six symbol geometries")


func test_3d_symbol_texture_has_white_fill_and_dark_outline() -> void:
	for color: int in range(OrbSymbols.SYMBOL_COUNT):
		var texture: ImageTexture = OrbSymbols.material_for_color(color).albedo_texture as ImageTexture
		var image: Image = texture.get_image()
		var white_pixels: int = 0
		var outline_pixels: int = 0
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				var pixel: Color = image.get_pixel(x, y)
				if pixel.a <= 0.0:
					continue
				if pixel.r > 0.9 and pixel.g > 0.9 and pixel.b > 0.9:
					white_pixels += 1
				elif pixel.get_luminance() < 0.1:
					outline_pixels += 1
		assert_true(white_pixels > 0, "color %d has white symbol fill" % color)
		assert_true(outline_pixels > 0, "color %d has dark symbol outline" % color)


func test_2d_orbs_and_preview_use_color_symbols_and_toggle() -> void:
	var original_enabled: bool = Config.data.orb_symbols_enabled
	Config.data.orb_symbols_enabled = true
	var board: Board = BOARD_2D_SCENE.instantiate() as Board
	tree.root.add_child(board)
	await tree.process_frame
	for color: int in range(OrbSymbols.SYMBOL_COUNT):
		var orb: Orb = board.spawn_orb(color, 1, Vector2(float(color * 80), 0.0))
		var visual: OrbVisual = orb.get_node("Visual") as OrbVisual
		assert_eq(visual.symbol_color(), color, "2D orb symbol mapping %d" % color)
		assert_true(visual.has_symbol(), "2D orb symbol visible %d" % color)
		visual.set_symbols_enabled(false)
		assert_true(not visual.has_symbol(), "2D orb symbol toggle %d" % color)
	board.queue_free()
	await tree.process_frame

	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.TURN)
	(main.get_node("ScoreManager") as ScoreManager).save_path = ""
	(main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = ""
	tree.root.add_child(main)
	await tree.process_frame
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var next_batch: Array[Dictionary] = [
		{"color": OrbTypes.OrbColor.RED, "level": 1},
		{"color": OrbTypes.OrbColor.PURPLE, "level": 1},
		{"color": OrbTypes.OrbColor.CYAN, "level": 1},
	]
	var then_batch: Array[Dictionary] = [
		{"color": OrbTypes.OrbColor.BLUE, "level": 2},
	]
	hud._on_preview_changed([next_batch, then_batch])
	for index: int in range(next_batch.size()):
		var next_visual: OrbVisual = hud._next_preview.get_child(index) as OrbVisual
		assert_eq(
			next_visual.symbol_color(),
			int(next_batch[index]["color"]),
			"NEXT symbol %d" % index
		)
		assert_true(next_visual.has_symbol(), "NEXT symbol visible %d" % index)
	var then_visual: OrbVisual = hud._then_preview.get_child(0) as OrbVisual
	assert_eq(then_visual.symbol_color(), OrbTypes.OrbColor.BLUE, "THEN symbol")
	assert_true(then_visual.has_symbol(), "THEN symbol visible")
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.orb_symbols_enabled = original_enabled


func test_3d_symbols_share_exactly_six_resources_for_one_hundred_orbs() -> void:
	var original_enabled: bool = Config.data.orb_symbols_enabled
	Config.data.orb_symbols_enabled = true
	var root: Node3D = Node3D.new()
	tree.root.add_child(root)
	var mesh_ids: Dictionary = {}
	var material_ids: Dictionary = {}
	var texture_ids: Dictionary = {}
	for index: int in range(100):
		var orb: Orb3D = ORB_3D_SCENE.instantiate() as Orb3D
		root.add_child(orb)
		var color: int = index % OrbSymbols.SYMBOL_COUNT
		orb.setup(color, 1, Config.data)
		var symbol: MeshInstance3D = orb.get_node("Symbol") as MeshInstance3D
		var mesh: QuadMesh = symbol.mesh as QuadMesh
		var material: StandardMaterial3D = mesh.material as StandardMaterial3D
		mesh_ids[mesh.get_instance_id()] = true
		material_ids[material.get_instance_id()] = true
		texture_ids[material.albedo_texture.get_instance_id()] = true
	assert_eq(mesh_ids.size(), 6, "100 orbs reuse six symbol meshes")
	assert_eq(material_ids.size(), 6, "100 orbs reuse six symbol materials")
	assert_eq(texture_ids.size(), 6, "100 orbs reuse six symbol textures")
	assert_eq(OrbSymbols.shared_mesh_count(), 6, "shared mesh cache")
	assert_eq(OrbSymbols.shared_material_count(), 6, "shared material cache")
	assert_eq(OrbSymbols.shared_texture_count(), 6, "shared texture cache")
	root.queue_free()
	await tree.process_frame
	Config.data.orb_symbols_enabled = original_enabled


func test_3d_symbol_follows_position_without_inheriting_roll_and_keeps_blink() -> void:
	var original_enabled: bool = Config.data.orb_symbols_enabled
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.orb_symbols_enabled = true
	Config.data.game_mode = GameConfig.GameMode.BLITZ
	var board: Board3D = BOARD_3D_SCENE.instantiate() as Board3D
	tree.root.add_child(board)
	await tree.process_frame
	var orb: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.YELLOW,
		4,
		Vector2(120.0, -80.0)
	)
	var body: RigidBody3D = orb.get_physics_body()
	var symbol: MeshInstance3D = orb.get_node("Symbol") as MeshInstance3D
	assert_true(symbol.visible, "3D symbol enabled")
	assert_true(symbol.get_parent() == orb, "symbol is a body sibling")
	assert_near(
		symbol.position.z,
		body.position.z + orb.get_current_radius() / Orb3D.PIXELS_PER_METER + 0.002,
		0.0001,
		"symbol is on camera-facing surface"
	)
	body.rotation = Vector3(0.0, 0.0, 1.2)
	orb._physics_process(Config.data.blast_blink_period * 0.25)
	assert_eq(symbol.rotation, Vector3.ZERO, "symbol does not inherit body roll")
	assert_near(symbol.position.x, body.position.x, 0.0001, "symbol follows body x")
	assert_near(symbol.position.y, body.position.y, 0.0001, "symbol follows body y")
	var orb_material: ShaderMaterial = orb._mesh.material_override as ShaderMaterial
	assert_true(orb_material != null, "orb keeps celestial body material")
	assert_true(orb._blast_outline.visible, "armed pulse outline remains visible")
	assert_true(orb.blast_outline_strength() > 0.0, "armed pulse strength remains visible")
	board.queue_free()
	await tree.process_frame
	Config.data.orb_symbols_enabled = original_enabled
	Config.data.game_mode = original_mode


func test_disabled_config_hides_2d_and_3d_symbols() -> void:
	var original_enabled: bool = Config.data.orb_symbols_enabled
	Config.data.orb_symbols_enabled = false
	var board_2d: Board = BOARD_2D_SCENE.instantiate() as Board
	var board_3d: Board3D = BOARD_3D_SCENE.instantiate() as Board3D
	tree.root.add_child(board_2d)
	tree.root.add_child(board_3d)
	await tree.process_frame
	var orb_2d: Orb = board_2d.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2.ZERO)
	var orb_3d: Orb3D = board_3d.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2.ZERO)
	assert_true(not (orb_2d.get_node("Visual") as OrbVisual).has_symbol(), "2D symbol hidden")
	assert_true(not (orb_3d.get_node("Symbol") as MeshInstance3D).visible, "3D symbol hidden")
	board_2d.queue_free()
	board_3d.queue_free()
	await tree.process_frame
	Config.data.orb_symbols_enabled = original_enabled
