class_name OrbSymbols
extends RefCounted

const SYMBOL_COUNT: int = 6
const SYMBOL_ALPHA: float = 0.92
const SYMBOL_SIZE_FACTOR: float = 0.45
const TEXTURE_SIZE: int = 128
const OUTLINE_RADIUS_PX: int = 6
const OUTLINE_COLOR: Color = Color(0.015, 0.025, 0.065, 0.96)
const SYMBOL_NAMES: Array[String] = [
	"triangle",
	"circle",
	"square",
	"diamond",
	"star",
	"plus",
]

static var _symbol_meshes: Array[QuadMesh] = []
static var _symbol_materials: Array[StandardMaterial3D] = []
static var _symbol_textures: Array[ImageTexture] = []


static func symbol_name_for_color(color: int) -> String:
	if color < 0 or color >= SYMBOL_NAMES.size():
		return ""
	return SYMBOL_NAMES[color]


static func polygons_for_color(color: int) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	match color:
		OrbTypes.OrbColor.RED:
			polygons.append(PackedVector2Array([
				Vector2(0.0, -0.48),
				Vector2(0.45, 0.40),
				Vector2(-0.45, 0.40),
			]))
		OrbTypes.OrbColor.BLUE:
			polygons.append(_regular_polygon(24, 0.25, -PI * 0.5))
		OrbTypes.OrbColor.GREEN:
			polygons.append(PackedVector2Array([
				Vector2(-0.34, -0.34),
				Vector2(0.34, -0.34),
				Vector2(0.34, 0.34),
				Vector2(-0.34, 0.34),
			]))
		OrbTypes.OrbColor.YELLOW:
			polygons.append(PackedVector2Array([
				Vector2(0.0, -0.47),
				Vector2(0.42, 0.0),
				Vector2(0.0, 0.47),
				Vector2(-0.42, 0.0),
			]))
		OrbTypes.OrbColor.PURPLE:
			polygons.append(_star_polygon())
		OrbTypes.OrbColor.CYAN:
			polygons.append(PackedVector2Array([
				Vector2(-0.13, -0.46),
				Vector2(0.13, -0.46),
				Vector2(0.13, -0.13),
				Vector2(0.46, -0.13),
				Vector2(0.46, 0.13),
				Vector2(0.13, 0.13),
				Vector2(0.13, 0.46),
				Vector2(-0.13, 0.46),
				Vector2(-0.13, 0.13),
				Vector2(-0.46, 0.13),
				Vector2(-0.46, -0.13),
				Vector2(-0.13, -0.13),
			]))
	return polygons


static func mesh_for_color(color: int) -> QuadMesh:
	_ensure_shared_resources()
	if color < 0 or color >= _symbol_meshes.size():
		return null
	return _symbol_meshes[color]


static func material_for_color(color: int) -> StandardMaterial3D:
	_ensure_shared_resources()
	if color < 0 or color >= _symbol_materials.size():
		return null
	return _symbol_materials[color]


static func shared_mesh_count() -> int:
	_ensure_shared_resources()
	return _symbol_meshes.size()


static func shared_material_count() -> int:
	_ensure_shared_resources()
	return _symbol_materials.size()


static func shared_texture_count() -> int:
	_ensure_shared_resources()
	return _symbol_textures.size()


static func prewarm_shared_resources() -> void:
	_ensure_shared_resources()


static func _ensure_shared_resources() -> void:
	if _symbol_meshes.size() == SYMBOL_COUNT:
		return
	_symbol_meshes.clear()
	_symbol_materials.clear()
	_symbol_textures.clear()
	for color: int in range(SYMBOL_COUNT):
		var texture: ImageTexture = _create_texture(color)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.resource_name = "orb_symbol_%s_material" % symbol_name_for_color(color)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(1.0, 1.0, 1.0, SYMBOL_ALPHA)
		material.albedo_texture = texture
		material.emission_enabled = true
		material.emission = Color.WHITE
		material.emission_texture = texture
		var mesh: QuadMesh = QuadMesh.new()
		mesh.resource_name = "orb_symbol_%s_mesh" % symbol_name_for_color(color)
		mesh.size = Vector2.ONE
		mesh.orientation = PlaneMesh.FACE_Z
		mesh.material = material
		_symbol_textures.append(texture)
		_symbol_materials.append(material)
		_symbol_meshes.append(mesh)


static func _create_texture(color: int) -> ImageTexture:
	var image: Image = Image.create(
		TEXTURE_SIZE,
		TEXTURE_SIZE,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(Color.TRANSPARENT)
	var polygons: Array[PackedVector2Array] = polygons_for_color(color)
	var inside_mask: PackedByteArray = PackedByteArray()
	inside_mask.resize(TEXTURE_SIZE * TEXTURE_SIZE)
	for y: int in range(TEXTURE_SIZE):
		for x: int in range(TEXTURE_SIZE):
			var point: Vector2 = Vector2(
				(float(x) + 0.5) / float(TEXTURE_SIZE) - 0.5,
				(float(y) + 0.5) / float(TEXTURE_SIZE) - 0.5
			)
			inside_mask[y * TEXTURE_SIZE + x] = (
				1 if _is_inside_any_polygon(point, polygons) else 0
			)
	for y: int in range(TEXTURE_SIZE):
		for x: int in range(TEXTURE_SIZE):
			if inside_mask[y * TEXTURE_SIZE + x] == 1:
				image.set_pixel(x, y, Color.WHITE)
				continue
			if _has_inside_neighbor(inside_mask, x, y):
				image.set_pixel(x, y, OUTLINE_COLOR)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	texture.resource_name = "orb_symbol_%s_texture" % symbol_name_for_color(color)
	return texture


static func _has_inside_neighbor(mask: PackedByteArray, x: int, y: int) -> bool:
	for offset_y: int in range(-OUTLINE_RADIUS_PX, OUTLINE_RADIUS_PX + 1):
		for offset_x: int in range(-OUTLINE_RADIUS_PX, OUTLINE_RADIUS_PX + 1):
			if offset_x * offset_x + offset_y * offset_y > OUTLINE_RADIUS_PX * OUTLINE_RADIUS_PX:
				continue
			var sample_x: int = x + offset_x
			var sample_y: int = y + offset_y
			if (
				sample_x >= 0
				and sample_x < TEXTURE_SIZE
				and sample_y >= 0
				and sample_y < TEXTURE_SIZE
				and mask[sample_y * TEXTURE_SIZE + sample_x] == 1
			):
				return true
	return false


static func _is_inside_any_polygon(
	point: Vector2,
	polygons: Array[PackedVector2Array]
) -> bool:
	for polygon: PackedVector2Array in polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


static func _regular_polygon(
	point_count: int,
	radius: float,
	start_angle: float
) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(point_count):
		var angle: float = start_angle + TAU * float(index) / float(point_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _star_polygon() -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(10):
		var radius: float = 0.47 if index % 2 == 0 else 0.21
		var angle: float = -PI * 0.5 + TAU * float(index) / 10.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
