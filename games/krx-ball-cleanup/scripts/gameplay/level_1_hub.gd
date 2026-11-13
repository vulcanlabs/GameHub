class_name Level1Hub
extends Node3D
## Level 1, the Playroom: a 40 m x 30 m x 7 m kids' hall with three ball pits.
##
## Crayon pictures hang on painted walls. Six classroom doors stay locked until those rooms exist.
## x runs west to east (-20 to 20), z runs north to south (-15 to 15), the floor is y = 0.
##
## The door to Level 2 is in the middle of the east wall. It is solid until Level 1 is empty, then you walk
## through into the poolroom. Balls can only be deposited in this playroom.

const LEVEL_INDEX := 0
const WIDTH := 40.0
const DEPTH := 30.0
const HEIGHT := 7.0
const WALL := 0.4
const PIT := Rect2(-4.5, -4.5, 9.0, 9.0)
const PITS: Array[Rect2] = [PIT]
const DOOR_WIDTH := 3.0
const DOOR_HEIGHT := 3.15
const PILLAR := 0.75
const PILLAR_TOP := 6.15
const PILLARS := [
	Vector2(-14.0, -8.0), Vector2(-7.0, -8.0), Vector2(7.0, -8.0), Vector2(14.0, -8.0),
	Vector2(-14.0, 8.0), Vector2(-7.0, 8.0), Vector2(7.0, 8.0), Vector2(14.0, 8.0),
]
const LIGHT_COLUMNS := [-16.0, -8.0, 0.0, 8.0, 16.0]
const LIGHT_ROWS := [-11.0, -3.7, 3.7, 11.0]
const LIGHT_HEIGHT := 6.88
const BENCH := Vector3(2.4, 0.42, 0.9)
const BENCHES := [
	Vector2(-6.0, -14.4), Vector2(6.0, -14.4),
	Vector2(-6.0, 14.4), Vector2(6.0, 14.4),
	Vector2(-18.6, -10.0), Vector2(-18.6, 2.0),
]
const BALL_SEED := 20261112
const Drawings := preload("res://scripts/gameplay/kid_drawings.gd")
const PlayroomsDecor := preload("res://scripts/gameplay/playrooms_environment_decor.gd")

## Mounds the playtest aims at. Peak is in layers, so the balls stack into hills.
var PILES: Array[Vector4] = []

@onready var pit: CollectionPit = $CollectionPit
@onready var pits: Array[CollectionPit] = []

var _white: Material = preload("res://assets/materials/wall_tile_white.tres")
var _blue: Material = preload("res://assets/materials/tile_blue.tres")
var _floor: Material = preload("res://assets/materials/floor_tile_white.tres")
var _concrete: Material = preload("res://assets/materials/concrete.tres")
var _steel: Material = preload("res://assets/materials/steel_brushed.tres")
var _galvanized: Material = preload("res://assets/materials/steel_galvanized.tres")
var _dark_steel: Material = preload("res://assets/materials/steel_painted_dark.tres")
var _door_paint: Material = preload("res://assets/materials/door_paint.tres")
var _sign_font: Font = preload("res://assets/fonts/BarlowCondensed-Bold.ttf")

var _plaster: StandardMaterial3D
var _mold: StandardMaterial3D
var _mat: StandardMaterial3D
var _foam: StandardMaterial3D
var _plastic_cache := {}
var _environment: Environment
var _spots: Array[SpotLight3D] = []
var _doors: Array[Dictionary] = []
var _deny_wait := 0.0
var _cloud_tex: ImageTexture
var _flicker: OmniLight3D
var _time := 0.0


func _enter_tree() -> void:
	if PILES.is_empty():
		PILES = _scatter_piles()


func _ready() -> void:
	var tile: Material = preload("res://assets/materials/wall_tile_white.tres")
	_plaster = _tinted(tile, Color(0.62, 0.61, 0.58))
	_plaster.roughness = 0.9
	_plaster.ao_enabled = true
	_mold = _tinted(tile, Color(0.48, 0.28, 0.16))
	_mat = _tinted(_white, Color(0.9, 0.78, 0.28))
	_foam = _plastic(Color(0.28, 0.64, 0.36))
	pits.clear()
	for child in get_children():
		if child is CollectionPit:
			pits.append(child)
	var pool := Level2Pool.new()
	pool.name = "Pool"
	add_child(pool)
	_build_doors()
	_build_environment()
	Settings.changed.connect(_on_setting_changed)
	GameState.level_unlocked.connect(_on_level_unlocked)
	GameState.run_reset.connect(_show_door_state)
	_apply_graphics()
	_show_door_state()


func spawn_point() -> Vector3:
	return Vector3(0.0, 0.05, 11.0)


## Facing north, toward the pit.
func spawn_yaw() -> float:
	return 0.0


## The floor area balls may lie on, a little inside the walls.
func ball_bounds() -> Rect2:
	return Rect2(-WIDTH * 0.5 + 0.15, -DEPTH * 0.5 + 0.15, WIDTH - 0.3, DEPTH - 0.3)


## Floor that must stay clear of balls: the pits and their kerbs, pillars, foam blocks, the doorways.
func blocked_areas() -> Array[Rect2]:
	var areas: Array[Rect2] = []
	for at: Vector2 in BENCHES:
		var wide := absf(at.x) > 16.0
		var w := BENCH.z if wide else BENCH.x
		var d := BENCH.x if wide else BENCH.z
		areas.append(Rect2(at.x - w * 0.5, at.y - d * 0.5, w, d).grow(0.28))
	areas.append(Rect2(WIDTH * 0.5 - 1.2, -DOOR_WIDTH * 0.5 - 0.3, 1.2, DOOR_WIDTH + 0.6))
	areas.append(Rect2(-WIDTH * 0.5, -DOOR_WIDTH * 0.5 - 0.3, 1.2, DOOR_WIDTH + 0.6))
	areas.append(Rect2(-11.0, -7.0, 22.0, 16.0))
	return areas


## Circles the balls must not sit in: the hole, the pillars, and the slide footprints.
func blocked_circles() -> Array:
	var circles: Array = [Vector3(0.0, 0.0, 4.25)]
	for at: Vector2 in PILLARS:
		circles.append(Vector3(at.x, at.y, PILLAR * 0.85))
	return circles


func _scatter_piles() -> Array[Vector4]:
	# No mounds. These marks only name a few spots; height 0 adds nothing.
	# The rest of the 4,000 balls are placed one by one on empty floor.
	return [
		Vector4(0.0, 6.2, 0.0, 1.0),
		Vector4(6.0, 0.0, 0.0, 1.0),
		Vector4(-6.0, -4.0, 0.0, 1.0),
	]


func _paint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.metallic = 0.0
	return material


func _tinted(base: Material, color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = (base as StandardMaterial3D).duplicate()
	material.albedo_color = color
	return material


func _plastic(color: Color) -> StandardMaterial3D:
	if _plastic_cache.has(color):
		return _plastic_cache[color]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = load("res://assets/textures/Plastic018B/Plastic018B_2K-JPG_Color.jpg")
	material.normal_enabled = true
	material.normal_texture = load("res://assets/textures/Plastic018B/Plastic018B_2K-JPG_NormalGL.jpg")
	material.roughness_texture = load("res://assets/textures/Plastic018B/Plastic018B_2K-JPG_Roughness.jpg")
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_scale = Vector3(1.8, 1.8, 1.8)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_plastic_cache[color] = material
	return material


# ---------------------------------------------------------------- structure

# Vinyl floor with a hole for each ball pit.
func _build_floor() -> void:
	var vinyl := _paint(Color(0.92, 0.84, 0.68))
	vinyl.albedo_texture = load("res://assets/textures/carpet/carpet.jpg")
	vinyl.roughness = 0.94
	vinyl.uv1_scale = Vector3(3.2, 3.2, 3.2)
	vinyl.uv1_triplanar = true
	vinyl.uv1_world_triplanar = true
	vinyl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var csg := CSGCombiner3D.new()
	csg.use_collision = true
	csg.collision_layer = LevelKit.WORLD_LAYER
	csg.collision_mask = 0
	var slab := CSGBox3D.new()
	slab.size = Vector3(WIDTH, 0.4, DEPTH)
	slab.position = Vector3(0.0, -0.2, 0.0)
	slab.material = vinyl
	csg.add_child(slab)
	for hole in PITS:
		var cut := CSGCylinder3D.new()
		cut.operation = CSGShape3D.OPERATION_SUBTRACTION
		cut.radius = minf(hole.size.x, hole.size.y) * 0.38
		cut.height = 1.4
		cut.sides = 48
		cut.position = Vector3(hole.get_center().x, 0.05, hole.get_center().y)
		csg.add_child(cut)
	add_child(csg)


func _build_foam_mats() -> void:
	var colors := [
		Color(0.86, 0.16, 0.2), Color(0.95, 0.78, 0.14), Color(0.16, 0.55, 0.28),
		Color(0.16, 0.36, 0.82), Color(0.55, 0.2, 0.72), Color(0.95, 0.46, 0.14),
	]
	var tile := 1.0
	var torn := {
		Vector2i(-8, 4): true, Vector2i(6, -6): true, Vector2i(14, 2): true,
		Vector2i(-15, -9): true, Vector2i(3, 10): true,
	}
	var x0 := -WIDTH * 0.5
	var z0 := -DEPTH * 0.5
	var i := 0
	var x := x0
	while x < WIDTH * 0.5 - 0.02:
		var j := 0
		var z := z0
		while z < DEPTH * 0.5 - 0.02:
			var cx := x + tile * 0.5
			var cz := z + tile * 0.5
			var cell := Rect2(x + 0.02, z + 0.02, tile - 0.04, tile - 0.04)
			var blocked := false
			for hole in PITS:
				if hole.grow(CollectionPit.KERB_WIDTH + 0.05).intersects(cell):
					blocked = true
					break
			if not blocked and absf(cx) < WIDTH * 0.5 - 0.35 and absf(cz) < DEPTH * 0.5 - 0.35:
				var pad := _pad_mat(colors[(i + j * 2) % colors.size()])
				if torn.has(Vector2i(i, j)):
					_shred(Vector3(cx, 0.02, cz), pad)
				else:
					LevelKit.box(self, Vector3(tile - 0.012, 0.045, tile - 0.012), Vector3(cx, 0.028, cz), pad, false)
			j += 1
			z += tile
		i += 1
		x += tile


func _build_walls() -> void:
	var x := WIDTH * 0.5
	var z := DEPTH * 0.5
	# North wall, with one arch cut into the face. South wall, waiting room and ball pit.
	_build_north_wall()
	_wall_with_gaps(-x - WALL, x + WALL, z, z + WALL, [-11.5, -8.5])
	# West wall, doorway to the office.
	_wall(-x - WALL, -x, -z, -DOOR_WIDTH * 0.5)
	_wall(-x - WALL, -x, DOOR_WIDTH * 0.5, z)
	_wall(-x - WALL, -x, -DOOR_WIDTH * 0.5, DOOR_WIDTH * 0.5, DOOR_HEIGHT)
	# East wall, doorway to the hotel.
	_wall(x, x + WALL, -z, -DOOR_WIDTH * 0.5)
	_wall(x, x + WALL, DOOR_WIDTH * 0.5, z)
	_wall(x, x + WALL, -DOOR_WIDTH * 0.5, DOOR_WIDTH * 0.5, DOOR_HEIGHT)


## The far wall is one piece: full width, up to the ceiling, with a shallow arch in its face.
func _build_north_wall() -> void:
	var x := WIDTH * 0.5
	var z := DEPTH * 0.5
	var csg := CSGCombiner3D.new()
	csg.use_collision = true
	csg.collision_layer = LevelKit.WORLD_LAYER
	csg.collision_mask = 0
	var wall := CSGBox3D.new()
	wall.size = Vector3(WIDTH + WALL * 2.0, HEIGHT, WALL)
	wall.position = Vector3(0.0, HEIGHT * 0.5, -z - WALL * 0.5)
	wall.material = _plaster
	csg.add_child(wall)
	var crown := HEIGHT
	var half := x + WALL
	var cy := (half * half - crown * crown) / (2.0 * crown)
	var radius := crown - cy
	var recess := CSGCylinder3D.new()
	recess.operation = CSGShape3D.OPERATION_SUBTRACTION
	recess.radius = radius
	recess.height = 0.22
	recess.sides = 64
	recess.position = Vector3(0.0, -cy, -z - 0.11)
	recess.rotation.x = PI * 0.5
	csg.add_child(recess)
	var doors := [Vector2(-11.5, -8.5), Vector2(8.5, 11.5)]
	for gap: Vector2 in doors:
		var hole := CSGBox3D.new()
		hole.operation = CSGShape3D.OPERATION_SUBTRACTION
		hole.size = Vector3(gap.y - gap.x, DOOR_HEIGHT, WALL + 0.3)
		hole.position = Vector3((gap.x + gap.y) * 0.5, DOOR_HEIGHT * 0.5, -z - WALL * 0.5)
		csg.add_child(hole)
	add_child(csg)


func _build_pillars() -> void:
	var radius := PILLAR * 0.5
	for at: Vector2 in PILLARS:
		var shaft := CylinderMesh.new()
		shaft.top_radius = radius
		shaft.bottom_radius = radius * 1.04
		shaft.height = PILLAR_TOP
		shaft.radial_segments = 24
		var column := MeshInstance3D.new()
		column.mesh = shaft
		column.material_override = _plaster
		column.position = Vector3(at.x, PILLAR_TOP * 0.5, at.y)
		add_child(column)
		var cap := SphereMesh.new()
		cap.radius = radius * 1.15
		cap.height = radius * 1.3
		cap.radial_segments = 24
		cap.rings = 12
		var crown := MeshInstance3D.new()
		crown.mesh = cap
		crown.material_override = _plaster
		crown.position = Vector3(at.x, PILLAR_TOP - radius * 0.15, at.y)
		add_child(crown)
		var body := StaticBody3D.new()
		body.collision_layer = LevelKit.WORLD_LAYER
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius
		cylinder.height = PILLAR_TOP
		shape.shape = cylinder
		shape.position = Vector3(at.x, PILLAR_TOP * 0.5, at.y)
		body.add_child(shape)
		add_child(body)


# Painted plaster wall or pillar between two corners. A dark dado at knee height.
func _wall(x0: float, x1: float, z0: float, z1: float, from := 0.0, to := HEIGHT) -> void:
	var size := Vector3(x1 - x0, to - from, z1 - z0)
	if size.x < 0.01 or size.y < 0.01 or size.z < 0.01:
		return
	var centre := Vector3((x0 + x1) * 0.5, (from + to) * 0.5, (z0 + z1) * 0.5)
	LevelKit.box(self, size, centre, _plaster)


# Bare ceiling. Pipes and fluorescent fittings are added separately.
func _build_ceiling() -> void:
	var ceiling := _paint(Color(0.78, 0.8, 0.74))
	ceiling.roughness = 0.88
	LevelKit.box(self, Vector3(WIDTH + WALL * 2.0, 0.3, DEPTH + WALL * 2.0), Vector3(0.0, HEIGHT + 0.15, 0.0), ceiling)


## A flat white cloud painted on the wall. `facing` points into the room.
func _cloud_poster(at: Vector3, facing: Vector3) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(3.4, 1.8)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.albedo_texture = _cloud_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = mat
	node.position = at
	node.rotation.y = atan2(facing.x, facing.z)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _cloud_texture() -> ImageTexture:
	if _cloud_tex != null:
		return _cloud_tex
	var image := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var blobs := [Vector2(70, 78), Vector2(110, 62), Vector2(150, 76), Vector2(188, 70), Vector2(128, 88)]
	var radii := [38.0, 34.0, 40.0, 30.0, 28.0]
	for n in blobs.size():
		var c: Vector2 = blobs[n]
		var radius: float = radii[n]
		for y in 128:
			for x in 256:
				if Vector2(x, y).distance_to(c) <= radius:
					image.set_pixel(x, y, Color.WHITE)
	_cloud_tex = ImageTexture.create_from_image(image)
	return _cloud_tex


# Long fluorescent troffers, the usual Backrooms ceiling light.
func _build_lights() -> void:
	var housing := _paint(Color(0.72, 0.74, 0.7))
	housing.roughness = 0.45
	housing.metallic = 0.35
	var tube := LevelKit.glow(Color(0.9, 0.97, 0.82), 2.2)
	for z: float in LIGHT_ROWS:
		for x: float in LIGHT_COLUMNS:
			LevelKit.box(self, Vector3(1.7, 0.08, 0.42), Vector3(x, LIGHT_HEIGHT, z), housing, false)
			LevelKit.box(self, Vector3(1.52, 0.02, 0.1), Vector3(x, LIGHT_HEIGHT - 0.05, z - 0.08), tube, false)
			LevelKit.box(self, Vector3(1.52, 0.02, 0.1), Vector3(x, LIGHT_HEIGHT - 0.05, z + 0.08), tube, false)
			var spot := SpotLight3D.new()
			spot.position = Vector3(x, LIGHT_HEIGHT - 0.12, z)
			spot.rotation.x = -PI * 0.5
			spot.light_color = Color(0.86, 0.95, 0.78)
			spot.light_energy = 5.4
			spot.spot_range = 12.0
			spot.spot_angle = 62.0
			spot.spot_angle_attenuation = 0.7
			spot.spot_attenuation = 1.05
			spot.shadow_bias = 0.04
			spot.shadow_blur = 1.4
			add_child(spot)
			_spots.append(spot)


# ---------------------------------------------------------------- classroom doors
# `facing` points into the hall. The leaf is a thin slab on that wall, not a box standing in the room.

func _wall_with_gaps(x0: float, x1: float, z0: float, z1: float, gaps: Array) -> void:
	var cursor := x0
	for i in range(0, gaps.size(), 2):
		_wall(cursor, gaps[i], z0, z1)
		_wall(gaps[i], gaps[i + 1], z0, z1, DOOR_HEIGHT, HEIGHT)
		cursor = gaps[i + 1]
	_wall(cursor, x1, z0, z1)


func _build_doors() -> void:
	_classroom_door(Vector3(WIDTH * 0.5, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0), 1)
	_classroom_door(Vector3(-WIDTH * 0.5, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), 2)
	_classroom_door(Vector3(-10.0, 0.0, -DEPTH * 0.5), Vector3(0.0, 0.0, 1.0), 3)
	_classroom_door(Vector3(10.0, 0.0, -DEPTH * 0.5), Vector3(0.0, 0.0, 1.0), 4)
	_classroom_door(Vector3(-10.0, 0.0, DEPTH * 0.5), Vector3(0.0, 0.0, -1.0), 5)


func _classroom_door(at: Vector3, facing: Vector3, level: int) -> void:
	var along := Vector3(-facing.z, 0.0, facing.x)
	var leaf_w := 1.15
	var leaf_h := 2.2
	var red := _paint(Color(0.72, 0.07, 0.09))
	red.roughness = 0.42
	var frame := _paint(Color(0.9, 0.91, 0.93))
	var glass := _paint(Color(0.72, 0.76, 0.8))
	glass.roughness = 0.12
	var bar := _paint(Color(0.06, 0.06, 0.07))
	var parts: Array[Node3D] = []
	# The wall hole is wider and taller than the door. Plug everything except the door itself.
	var outward := -facing
	var spare := (DOOR_WIDTH - leaf_w) * 0.5
	var wall_mid := at + outward * (WALL * 0.5)
	for side: float in [-1.0, 1.0]:
		var fill_at := wall_mid + along * side * (leaf_w * 0.5 + spare * 0.5) + Vector3(0.0, DOOR_HEIGHT * 0.5, 0.0)
		_slab(spare + 0.08, DOOR_HEIGHT, WALL + 0.04, fill_at, along, facing, _plaster, true)
	var header_h := DOOR_HEIGHT - leaf_h
	_slab(DOOR_WIDTH + 0.2, header_h, WALL + 0.04, wall_mid + Vector3(0.0, leaf_h + header_h * 0.5, 0.0), along, facing, _plaster, true)
	_slab(leaf_w + 0.16, 0.08, 0.1, at + Vector3(0.0, leaf_h + 0.02, 0.0) + facing * 0.04, along, facing, frame, false)
	var leaf_at := at + facing * 0.05 + Vector3(0.0, leaf_h * 0.5, 0.0)
	parts.append(_slab(leaf_w, leaf_h, 0.06, leaf_at, along, facing, red, false))
	# Narrow window on the right-hand side of the door, as you face it.
	var window_at := leaf_at + along * (leaf_w * 0.28) + Vector3(0.0, 0.28, 0.0) + facing * 0.02
	parts.append(_slab(0.1, 1.35, 0.04, window_at, along, facing, bar, false))
	parts.append(_slab(0.22, 1.15, 0.02, window_at + facing * 0.02, along, facing, glass, false))
	parts.append(_slab(leaf_w * 0.72, 0.08, 0.05, leaf_at + Vector3(0.0, -0.05, 0.0) + facing * 0.045, along, facing, bar, false))
	parts.append(_slab(0.28, 0.08, 0.08, leaf_at + Vector3(0.0, leaf_h * 0.5 - 0.08, 0.0) + facing * 0.05, along, facing, bar, false))
	for side: float in [-1.0, 1.0]:
		_slab(0.06, leaf_h + 0.06, 0.08, at + along * side * (leaf_w * 0.5 + 0.04) + facing * 0.03 + Vector3(0.0, leaf_h * 0.5, 0.0), along, facing, frame, false)
	var gate_size := Vector3(absf(facing.x) * 0.2 + absf(along.x) * leaf_w, leaf_h, absf(facing.z) * 0.2 + absf(along.z) * leaf_w)
	var gate := LevelKit.collider(self, gate_size, at + facing * 0.05 + Vector3(0.0, leaf_h * 0.5, 0.0))
	var lamp := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.09
	bulb.height = 0.18
	lamp.mesh = bulb
	lamp.position = at + facing * 0.08 + Vector3(0.0, leaf_h + 0.48, 0.0)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.material_override = LevelKit.glow(Color(1.0, 0.05, 0.05), 4.0)
	add_child(lamp)
	var glow := OmniLight3D.new()
	glow.position = lamp.position
	glow.light_color = Color(1.0, 0.08, 0.06)
	glow.light_energy = 2.2
	glow.omni_range = 2.4
	add_child(glow)
	var number := _wall_sign(str(level + 1), 72, at + facing * 0.12 + Vector3(0.0, leaf_h + 0.55, 0.0), facing)
	number.modulate = Color(0.96, 0.96, 0.98)
	var plate_at := at + facing * 0.16 + Vector3(0.0, 1.22, 0.0)
	var plate := _slab(0.82, 0.24, 0.02, plate_at, along, facing, _paint(Color(0.05, 0.05, 0.06)), false)
	plate.visible = false
	var status := _wall_sign("", 64, plate_at + facing * 0.02, facing)
	status.pixel_size = 0.0028
	status.outline_size = 10
	status.modulate = Color.WHITE
	status.visible = false
	_doors.append({
		"level": level, "at": at, "gate": gate, "parts": parts, "lamp": lamp, "glow": glow,
		"plate": plate, "status": status, "opened": false,
	})


## A box whose width runs along the wall and whose thickness sticks out toward the hall.
func _slab(width: float, height: float, thick: float, centre: Vector3, along: Vector3, facing: Vector3, material: Material, solid: bool) -> MeshInstance3D:
	var size := Vector3(absf(facing.x) * thick + absf(along.x) * width, height, absf(facing.z) * thick + absf(along.z) * width)
	return LevelKit.box(self, size, centre, material, solid)


func _wall_sign(text: String, size: int, at: Vector3, facing: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = _sign_font
	label.font_size = size
	label.pixel_size = 0.003
	label.outline_size = 8
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.7)
	label.shaded = true
	label.double_sided = false
	label.position = at
	label.rotation.y = atan2(facing.x, facing.z)
	add_child(label)
	return label


func _process(delta: float) -> void:
	_time += delta
	if _flicker != null:
		var hum := 2.05 + 0.08 * sin(_time * 1.7)
		if sin(_time * 0.21) > 0.985:
			hum *= 0.78
		_flicker.light_energy = hum
	_deny_wait = maxf(_deny_wait - delta, 0.0)
	_update_door_prompts()


func _update_door_prompts() -> void:
	var body := get_parent().get_node_or_null("Player")
	var at_pit := false
	for pit in pits:
		if pit.player_in_range:
			at_pit = true
			break
	var pressed := Input.is_action_just_pressed("unload")
	for door in _doors:
		var status: Label3D = door["status"]
		var plate: MeshInstance3D = door["plate"]
		if bool(door["opened"]) or body == null or at_pit:
			status.visible = false
			plate.visible = false
			continue
		var at: Vector3 = door["at"]
		var near: bool = body.global_position.distance_to(at) < 2.4
		status.visible = false
		plate.visible = false
		if not near or not pressed or _deny_wait > 0.0:
			continue
		if GameState.unlocked[int(door["level"])]:
			_swing_open(door)


func _swing_open(door: Dictionary) -> void:
	door["opened"] = true
	(door["gate"] as StaticBody3D).collision_layer = 0
	for part in door["parts"]:
		(part as Node3D).visible = false
	(door["status"] as Label3D).visible = false
	(door["plate"] as MeshInstance3D).visible = false


func _show_door_state() -> void:
	for door in _doors:
		var allowed: bool = GameState.unlocked[int(door["level"])]
		var color := Color(0.25, 1.0, 0.35) if allowed else Color(1.0, 0.05, 0.05)
		(door["lamp"] as MeshInstance3D).material_override = LevelKit.glow(color, 4.0)
		var glow := door["glow"] as OmniLight3D
		glow.light_color = color


func _on_level_unlocked(_level: int) -> void:
	_show_door_state()


# ---------------------------------------------------------------- fittings

## Indoor-play slides from the photos. The pit in the middle of the room is left alone.
func _build_slides() -> void:
	var cream := _slide_plastic(Color(0.86, 0.74, 0.5))
	var yellow := _slide_plastic(Color(0.88, 0.7, 0.1))
	var teal := _slide_plastic(Color(0.2, 0.44, 0.36))
	var blue := _paint(Color(0.3, 0.46, 0.72))
	blue.roughness = 0.58
	_wall_slide(Vector3(12.4, 0.0, 14.35), PI, cream, blue)
	_low_slide(Vector3(-12.8, 0.0, 12.6), 0.2, teal)
	_play_tower(Vector3(-16.8, 0.0, -12.4), yellow)


func _wall_slide(at: Vector3, yaw: float, chute: Material, panel: Material) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	add_child(root)
	LevelKit.box(root, Vector3(2.6, 3.2, 0.38), Vector3(0.0, 1.6, 0.22), panel)
	var dark := _paint(Color(0.08, 0.06, 0.06))
	LevelKit.box(root, Vector3(1.12, 0.92, 0.16), Vector3(0.0, 2.12, 0.04), dark, false)
	_hole_frame(root, Vector3(0.0, 2.12, 0.02), 1.18, 0.98, 0.08, chute)
	_cyl(root, Vector3(0.0, 2.12, 0.08), 0.52, 0.18, chute)
	var points: Array[Vector3] = []
	for n in 28:
		var t := float(n) / 27.0
		var drop := t * (2.0 - t)
		points.append(Vector3(0.0, lerpf(2.06, 0.08, drop), lerpf(0.16, -4.7, t)))
	_u_run(root, points, chute, 0.62, 0.22, 0.05)
	_slide_landing(root, points[points.size() - 1])
	LevelKit.collider(root, Vector3(0.9, 0.35, 4.2), Vector3(0.0, 0.55, -2.2))


func _low_slide(at: Vector3, yaw: float, chute: Material) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	add_child(root)
	var points: Array[Vector3] = []
	for n in 22:
		var t := float(n) / 21.0
		var drop := t * (2.0 - t)
		points.append(Vector3(0.0, lerpf(1.18, 0.08, drop), lerpf(0.0, -3.4, t)))
	_u_run(root, points, chute, 0.7, 0.24, 0.055)
	_cyl(root, Vector3(0.0, 1.18, 0.05), 0.48, 0.16, chute)
	_slide_landing(root, points[points.size() - 1])
	LevelKit.collider(root, Vector3(1.0, 0.4, 3.2), Vector3(0.0, 0.4, -1.6))


func _play_tower(at: Vector3, chute: Material) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = 0.7
	add_child(root)
	var yellow := chute
	var green := _powder_coat(Color(0.22, 0.58, 0.28))
	var blue := _powder_coat(Color(0.18, 0.38, 0.76))
	var steel_y := _powder_coat(Color(0.9, 0.74, 0.12))
	_pole(root, Vector3(0.0, 1.45, 0.0), 2.9, 0.08, steel_y)
	_pole(root, Vector3(-0.7, 1.35, 0.55), 2.7, 0.06, green)
	_pole(root, Vector3(0.65, 1.2, 0.5), 2.4, 0.06, blue)
	_pole(root, Vector3(0.2, 1.1, -0.7), 2.2, 0.06, green)
	_cyl(root, Vector3(0.0, 0.55, 0.0), 0.11, 1.1, _foam_pad(Color(0.8, 0.66, 0.16)))
	_cyl(root, Vector3(-0.7, 0.5, 0.55), 0.09, 1.0, _foam_pad(Color(0.28, 0.56, 0.3)))
	_cyl(root, Vector3(0.65, 0.48, 0.5), 0.09, 0.96, _foam_pad(Color(0.22, 0.38, 0.7)))
	LevelKit.box(root, Vector3(1.35, 0.12, 1.15), Vector3(0.0, 2.55, 0.05), _foam_pad(Color(0.8, 0.66, 0.16)), false)
	LevelKit.box(root, Vector3(1.15, 0.7, 0.08), Vector3(0.0, 2.9, -0.5), blue, false)
	_hole_frame(root, Vector3(0.0, 2.48, -0.42), 0.9, 0.7, 0.07, yellow)
	var spiral: Array[Vector3] = []
	for n in 40:
		var t := float(n) / 39.0
		var angle := t * TAU * 1.7 + 0.4
		spiral.append(Vector3(cos(angle) * 1.05, lerpf(2.48, 0.1, t), sin(angle) * 1.05))
	_u_run(root, spiral, yellow, 0.58, 0.2, 0.045)
	var straight: Array[Vector3] = []
	for n in 22:
		var t := float(n) / 21.0
		var drop := t * (2.0 - t)
		straight.append(Vector3(lerpf(0.15, 3.4, t), lerpf(2.45, 0.08, drop), lerpf(-0.2, 1.8, t)))
	_u_run(root, straight, yellow, 0.62, 0.22, 0.05)
	_slide_landing(root, straight[straight.size() - 1])
	LevelKit.collider(root, Vector3(2.6, 0.4, 2.6), Vector3(0.0, 0.35, 0.0))
	LevelKit.collider(root, Vector3(3.2, 0.35, 1.3), Vector3(1.6, 0.45, 0.8))


func _pole(parent: Node3D, at: Vector3, height: float, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)


func _slide_plastic(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.3
	material.metallic = 0.04
	material.clearcoat_enabled = true
	material.clearcoat = 0.5
	material.clearcoat_roughness = 0.36
	material.normal_enabled = true
	material.normal_texture = load("res://assets/textures/Plastic018B/Plastic018B_2K-JPG_NormalGL.jpg")
	material.roughness_texture = load("res://assets/textures/Plastic018B/Plastic018B_2K-JPG_Roughness.jpg")
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_scale = Vector3(2.2, 2.2, 2.2)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	return material


func _powder_coat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.22
	material.roughness = 0.46
	material.normal_enabled = true
	material.normal_texture = load("res://assets/textures/Metal012/Metal012_2K-JPG_NormalGL.jpg")
	material.roughness_texture = load("res://assets/textures/Metal012/Metal012_2K-JPG_Roughness.jpg")
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_scale = Vector3(1.4, 1.4, 1.4)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	return material


func _u_run(parent: Node3D, points: Array[Vector3], material: Material, width: float, rail: float, thick: float) -> void:
	if points.size() < 2:
		return
	var path := Path3D.new()
	path.name = "SlidePath%d" % parent.get_child_count()
	var curve := Curve3D.new()
	curve.bake_interval = 0.05
	for i in points.size():
		var inn := Vector3.ZERO
		var outt := Vector3.ZERO
		if i > 0 and i < points.size() - 1:
			var tan: Vector3 = (points[i + 1] - points[i - 1]) * 0.22
			inn = -tan
			outt = tan
		curve.add_point(points[i], inn, outt)
	path.curve = curve
	parent.add_child(path)
	var poly := CSGPolygon3D.new()
	poly.mode = CSGPolygon3D.MODE_PATH
	poly.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	poly.path_interval = 0.05
	poly.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH
	poly.path_local = true
	poly.smooth_faces = true
	poly.material = material
	poly.polygon = _slide_profile(width, rail, thick)
	parent.add_child(poly)
	poly.path_node = NodePath("../%s" % path.name)
	_slide_mouth(parent, points[0], points[1], width, rail, material)


func _slide_profile(width: float, rail: float, wall: float) -> PackedVector2Array:
	var hw := width * 0.5
	var inner := hw - wall
	var pts := PackedVector2Array()
	pts.append(Vector2(-hw, 0.0))
	pts.append(Vector2(-hw, rail * 0.72))
	pts.append(Vector2(-hw - wall * 0.08, rail))
	pts.append(Vector2(-hw + wall * 0.45, rail + wall * 0.35))
	pts.append(Vector2(-inner, rail))
	pts.append(Vector2(-inner, wall * 2.0))
	pts.append(Vector2(-inner + wall * 0.85, wall * 0.85))
	pts.append(Vector2(0.0, wall * 0.72))
	pts.append(Vector2(inner - wall * 0.85, wall * 0.85))
	pts.append(Vector2(inner, wall * 2.0))
	pts.append(Vector2(inner, rail))
	pts.append(Vector2(hw - wall * 0.45, rail + wall * 0.35))
	pts.append(Vector2(hw + wall * 0.08, rail))
	pts.append(Vector2(hw, rail * 0.72))
	pts.append(Vector2(hw, 0.0))
	return pts


func _slide_mouth(parent: Node3D, at: Vector3, ahead: Vector3, width: float, rail: float, material: Material) -> void:
	var along := ahead - at
	if along.length() < 0.001:
		return
	var lip := TorusMesh.new()
	lip.inner_radius = width * 0.18
	lip.outer_radius = width * 0.36
	lip.rings = 14
	lip.ring_segments = 20
	var node := MeshInstance3D.new()
	node.mesh = lip
	node.material_override = material
	node.position = at + Vector3(0.0, rail * 0.35, 0.0)
	node.scale = Vector3(1.0, 0.72, 1.0)
	var look := along.normalized()
	if absf(look.dot(Vector3.UP)) < 0.95:
		node.quaternion = Quaternion(Vector3.UP, look)
	parent.add_child(node)


func _slide_landing(parent: Node3D, at: Vector3) -> void:
	var mat := _foam_pad(Color(0.18, 0.34, 0.68))
	LevelKit.box(parent, Vector3(1.15, 0.05, 0.95), at + Vector3(0.0, -0.02, 0.15), mat, false)


func _hole_frame(parent: Node3D, at: Vector3, width: float, height: float, thick: float, material: Material) -> void:
	LevelKit.box(parent, Vector3(width, thick, thick), at + Vector3(0.0, height * 0.5, 0.0), material, false)
	LevelKit.box(parent, Vector3(width, thick, thick), at + Vector3(0.0, -height * 0.5, 0.0), material, false)
	LevelKit.box(parent, Vector3(thick, height, thick), at + Vector3(-width * 0.5, 0.0, 0.0), material, false)
	LevelKit.box(parent, Vector3(thick, height, thick), at + Vector3(width * 0.5, 0.0, 0.0), material, false)


## Extra play-centre props. Nothing already in the room is moved or replaced.
func _build_decorations() -> void:
	var decor := PlayroomsDecor.new()
	add_child(decor)
	decor.build()


func _foam_pad(color: Color) -> StandardMaterial3D:
	var material := _paint(color)
	material.roughness = 0.9
	return material



func _loose_ball(at: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.085
	mesh.height = 0.17
	mesh.radial_segments = 10
	mesh.rings = 6
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _plastic(BallManager.PALETTE[wrapi(int(at.x * 7.0 + at.z * 5.0), 0, BallManager.PALETTE.size())])
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _cyl(parent: Node3D, at: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)


## One large arch on the far (north) wall, between the doors.
func _build_arches() -> void:
	_arch_wall(0.0, -14.55, 12.4, 5.8, 3.6)


func _arch_wall(x: float, z: float, width: float, height: float, radius: float) -> void:
	var csg := CSGCombiner3D.new()
	csg.use_collision = true
	csg.collision_layer = LevelKit.WORLD_LAYER
	csg.collision_mask = 0
	var wall := CSGBox3D.new()
	wall.size = Vector3(width, height, 0.46)
	wall.position = Vector3(x, height * 0.5, z)
	wall.material = _plaster
	csg.add_child(wall)
	var cut := CSGCylinder3D.new()
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.radius = radius
	cut.height = 1.2
	cut.sides = 48
	cut.position = Vector3(x, 0.15, z)
	cut.rotation.x = PI * 0.5
	csg.add_child(cut)
	add_child(csg)
	var trim := _paint(Color(0.42, 0.42, 0.4))
	trim.roughness = 0.7
	var pier := (width - radius * 2.0) * 0.5
	LevelKit.box(self, Vector3(pier, 0.12, 0.52), Vector3(x - width * 0.5 + pier * 0.5, 0.06, z), trim, false)
	LevelKit.box(self, Vector3(pier, 0.12, 0.52), Vector3(x + width * 0.5 - pier * 0.5, 0.06, z), trim, false)


func _build_fittings() -> void:
	var y := 6.35
	for z: float in [-8.0, 0.0, 8.0]:
		LevelKit.pipe(self, Vector3(-19.2, y, z), Vector3(19.2, y, z), 0.09, _galvanized, 12)
		var x := -16.0
		while x <= 16.0:
			LevelKit.pipe(self, Vector3(x, y, z), Vector3(x, HEIGHT - 0.05, z), 0.025, _dark_steel, 8)
			x += 8.0
	for x: float in [-12.0, 12.0]:
		LevelKit.pipe(self, Vector3(x, y + 0.16, -14.2), Vector3(x, y + 0.16, 14.2), 0.07, _galvanized, 12)
	for at_x: float in [-10.0, 10.0]:
		var hum := AudioStreamPlayer3D.new()
		hum.stream = Sfx.stream("room_hum")
		hum.bus = "Environment"
		hum.position = Vector3(at_x, 5.5, 0.0)
		hum.unit_size = 14.0
		hum.volume_db = -16.0
		hum.autoplay = true
		add_child(hum)


func _cloth(color: Color) -> StandardMaterial3D:
	var material := _paint(color)
	material.roughness = 0.86
	return material


func _couch(at: Vector2, facing: Vector3, cloth: Material) -> void:
	var along := Vector3(-facing.z, 0.0, facing.x)
	var seat := Vector3(absf(along.x) * BENCH.x + absf(facing.x) * BENCH.z, BENCH.y, absf(along.z) * BENCH.x + absf(facing.z) * BENCH.z)
	LevelKit.box(self, seat, Vector3(at.x, BENCH.y * 0.5, at.y), cloth)
	var back_at := Vector3(at.x, 0.55, at.y) - facing * (BENCH.z * 0.5 - 0.12)
	for n in 4:
		var t := float(n) / 3.0 - 0.5
		_soft(back_at + along * t * (BENCH.x - 0.4) + Vector3(0.0, 0.15, 0.0), 0.28, cloth)
	for side: float in [-1.0, 1.0]:
		var arm_at := Vector3(at.x, 0.32, at.y) + along * side * (BENCH.x * 0.5 - 0.12)
		_soft(arm_at, 0.22, cloth)
		_soft(arm_at + Vector3(0.0, 0.16, 0.0), 0.16, cloth)


func _soft(at: Vector3, radius: float, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.55
	mesh.radial_segments = 16
	mesh.rings = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.scale = Vector3(1.0, 0.85, 1.0)
	add_child(node)


func _corner_mess(at: Vector2) -> void:
	var wood := _paint(Color(0.42, 0.28, 0.16))
	wood.roughness = 0.7
	var origin := Vector3(at.x, 0.0, at.y)
	var table := Node3D.new()
	table.position = origin + Vector3(-0.4, 0.35, 0.2)
	table.rotation = Vector3(0.9, 0.4, 0.15)
	add_child(table)
	LevelKit.box(table, Vector3(1.1, 0.06, 0.7), Vector3(0, 0.4, 0), wood, false)
	for corner in [Vector3(-0.45, 0.2, -0.28), Vector3(0.45, 0.2, -0.28), Vector3(-0.45, 0.2, 0.28), Vector3(0.45, 0.2, 0.28)]:
		LevelKit.box(table, Vector3(0.06, 0.4, 0.06), corner, wood, false)
	var chair := Node3D.new()
	chair.position = origin + Vector3(0.55, 0.0, -0.35)
	chair.rotation.z = 0.55
	chair.rotation.y = 0.8
	add_child(chair)
	LevelKit.box(chair, Vector3(0.42, 0.06, 0.42), Vector3(0, 0.48, 0), wood, false)
	LevelKit.box(chair, Vector3(0.42, 0.5, 0.06), Vector3(0, 0.75, -0.18), wood, false)
	for leg in [Vector3(-0.16, 0.24, -0.16), Vector3(0.16, 0.24, -0.16), Vector3(-0.16, 0.24, 0.16), Vector3(0.16, 0.24, 0.16)]:
		LevelKit.box(chair, Vector3(0.04, 0.48, 0.04), leg, wood, false)
	var phone := _paint(Color(0.08, 0.08, 0.09))
	LevelKit.box(self, Vector3(0.07, 0.012, 0.14), origin + Vector3(0.15, 0.02, 0.45), phone, false)
	LevelKit.box(self, Vector3(0.05, 0.014, 0.1), origin + Vector3(0.15, 0.03, 0.45), LevelKit.glow(Color(0.15, 0.55, 0.35), 1.2), false)


func _pad_mat(color: Color) -> StandardMaterial3D:
	var material := _paint(color)
	material.roughness = 0.72
	return material


func _shred(at: Vector3, pad: Material) -> void:
	var scraps := [Vector3(0.34, 0.02, 0.22), Vector3(0.18, 0.015, 0.28), Vector3(0.12, 0.012, 0.1)]
	var offsets := [Vector3(-0.16, 0.02, 0.08), Vector3(0.2, 0.015, -0.12), Vector3(0.05, 0.01, 0.18)]
	var yaws := [0.4, -0.7, 1.1]
	for n in scraps.size():
		var piece := LevelKit.box(self, scraps[n], at + offsets[n], pad, false)
		piece.rotation.y = yaws[n]


func _hang_drawings() -> void:
	var spots := [
		Vector3(4.5, 0.06, 6.5),
		Vector3(-7.2, 0.07, -6.0),
		Vector3(11.0, 0.08, 8.5),
		Vector3(-12.5, 0.06, 4.0),
	]
	var yaws := [0.15, 0.9, -0.55, 2.2]
	var pitches := [0.0, 0.22, -0.18, 0.35]
	for n in spots.size():
		var quad := QuadMesh.new()
		quad.size = Vector2(1.15, 0.86)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = Drawings.sheet(n)
		mat.roughness = 0.95
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var node := MeshInstance3D.new()
		node.mesh = quad
		node.material_override = mat
		node.position = spots[n]
		node.rotation.y = yaws[n]
		node.rotation.x = -PI * 0.5 + pitches[n]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


# ---------------------------------------------------------------- light and atmosphere

func _build_environment() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.62, 0.68, 0.58)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.82, 0.9, 0.76)
	_environment.ambient_light_energy = 0.85
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.tonemap_white = 5.0
	_environment.ssao_radius = 0.5
	_environment.ssao_intensity = 1.6
	_environment.ssao_power = 1.5
	_environment.ssr_max_steps = 48
	_environment.ssr_fade_in = 0.2
	_environment.ssr_fade_out = 2.5
	_environment.glow_intensity = 0.22
	_environment.glow_bloom = 0.012
	_environment.glow_hdr_threshold = 1.25
	# A trace of haze so the far end of the hall sits back.
	_environment.fog_enabled = true
	_environment.fog_light_color = Color(0.78, 0.86, 0.72)
	_environment.fog_density = 0.0004
	_flicker = OmniLight3D.new()
	_flicker.position = Vector3(6.0, 4.2, -4.0)
	_flicker.light_color = Color(0.96, 0.97, 0.92)
	_flicker.light_energy = 2.05
	_flicker.omni_range = 10.0
	add_child(_flicker)
	for at: Vector3 in [Vector3(-12.0, 3.2, 0.0), Vector3(12.0, 3.2, 0.0), Vector3(0.0, 3.0, -10.0), Vector3(0.0, 3.0, 10.0)]:
		var extra := OmniLight3D.new()
		extra.position = at
		extra.light_color = Color(0.96, 0.97, 0.93)
		extra.light_energy = 1.55
		extra.omni_range = 11.0
		extra.light_specular = 0.18
		add_child(extra)
	var world := WorldEnvironment.new()
	world.environment = _environment
	add_child(world)

	# One baked reflection of the empty hall for the glazed tiles and the balls. Balls are on render layer 2
	# and left out, so a pile that has been vacuumed up does not linger in the floor's reflection.
	var probe := ReflectionProbe.new()
	probe.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	probe.size = Vector3(WIDTH, HEIGHT, DEPTH)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.cull_mask = 1
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = _environment.ambient_light_color
	probe.ambient_color_energy = _environment.ambient_light_energy
	add_child(probe)


# Shadows: off, low (the four pendants around the pit, small maps) or high (all twelve).
# Screen-space reflections on High and Ultra. Glow from Medium up.
func _apply_graphics() -> void:
	var shadows: int = Settings.get_value("graphics", "shadows")
	var quality: int = Settings.get_value("graphics", "quality")
	for n in _spots.size():
		var around_pit: bool = absf(_spots[n].position.x) < 6.0 and absf(_spots[n].position.z) > 5.0
		_spots[n].shadow_enabled = shadows == Settings.Shadows.HIGH or (shadows == Settings.Shadows.LOW and around_pit)
	# Sixteen equal squares. With the default mixed sizes the twelve pendants compete for the few large
	# squares and are redrawn every frame; with equal squares each keeps its own until something under it moves.
	var viewport := get_viewport()
	viewport.positional_shadow_atlas_size = 4096 if shadows == Settings.Shadows.HIGH else 2048
	for quadrant in 4:
		viewport.set_positional_shadow_atlas_quadrant_subdiv(quadrant, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4)
	_environment.ssao_enabled = Settings.get_value("graphics", "ambient_occlusion")
	_environment.ssr_enabled = quality >= Settings.Quality.HIGH
	_environment.glow_enabled = quality >= Settings.Quality.MEDIUM


func _on_setting_changed(section: String, _key: String) -> void:
	if section == "graphics":
		_apply_graphics()


func shadow_lights() -> int:
	var count := 0
	for spot in _spots:
		if spot.shadow_enabled:
			count += 1
	return count


func environment() -> Environment:
	return _environment
