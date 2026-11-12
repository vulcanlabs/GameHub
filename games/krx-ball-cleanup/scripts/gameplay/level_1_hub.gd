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
const PIT := Rect2(-3.0, -2.4, 6.0, 4.8)
const PITS: Array[Rect2] = [
	PIT,
	Rect2(-17.8, 6.4, 3.6, 3.2),
	Rect2(14.2, 6.4, 3.6, 3.2),
]
const DOOR_WIDTH := 3.0
const DOOR_HEIGHT := 3.15
const PILLAR := 0.75
const PILLAR_TOP := 6.15
const PILLARS := [
	Vector2(-14.0, -8.0), Vector2(-7.0, -8.0), Vector2(7.0, -8.0), Vector2(14.0, -8.0),
	Vector2(-14.0, 8.0), Vector2(-7.0, 8.0), Vector2(7.0, 8.0), Vector2(14.0, 8.0),
]
const LIGHT_COLUMNS := [-15.0, -5.0, 5.0, 15.0]
const LIGHT_ROWS := [-10.0, 0.0, 10.0]
const LIGHT_HEIGHT := 5.45
const BENCH := Vector3(2.4, 0.42, 0.9)
const BENCHES := [
	Vector2(-6.0, -14.4), Vector2(6.0, -14.4),
	Vector2(-6.0, 14.4), Vector2(6.0, 14.4),
	Vector2(-18.6, -10.0), Vector2(-18.6, 2.0),
]
const BALL_SEED := 20261112
const Drawings := preload("res://scripts/gameplay/kid_drawings.gd")

## Low scatter over the floor, plus a few denser patches the tests aim at.
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
var _mat: StandardMaterial3D
var _foam: StandardMaterial3D
var _plastic_cache := {}
var _environment: Environment
var _spots: Array[SpotLight3D] = []
var _door_status: Label3D
var _door_lamp: MeshInstance3D
var _east_gate: StaticBody3D
var _east_leaves: Array[Node3D] = []
var _flicker: OmniLight3D
var _time := 0.0


func _enter_tree() -> void:
	if PILES.is_empty():
		PILES = _scatter_piles()


func _ready() -> void:
	_plaster = _tinted(_white, Color(0.72, 0.48, 0.78))
	_mat = _tinted(_white, Color(0.95, 0.82, 0.28))
	_foam = _plastic(Color(0.22, 0.72, 0.38))
	pits.clear()
	for child in get_children():
		if child is CollectionPit:
			pits.append(child)
	_build_floor()
	_build_foam_mats()
	_build_walls()
	_build_pillars()
	_build_ceiling()
	_build_lights()
	_build_doors()
	_build_rainbow_arch()
	_build_fittings()
	_hang_drawings()
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
	for hole in PITS:
		areas.append(hole.grow(CollectionPit.KERB_WIDTH + 0.22))
	for at: Vector2 in PILLARS:
		areas.append(Rect2(at - Vector2.ONE * PILLAR * 0.5, Vector2.ONE * PILLAR).grow(0.2))
	for at: Vector2 in BENCHES:
		var wide := absf(at.x) > 16.0
		var w := BENCH.z if wide else BENCH.x
		var d := BENCH.x if wide else BENCH.z
		areas.append(Rect2(at.x - w * 0.5, at.y - d * 0.5, w, d).grow(0.28))
	areas.append(Rect2(WIDTH * 0.5 - 1.2, -DOOR_WIDTH * 0.5 - 0.3, 1.2, DOOR_WIDTH + 0.6))
	areas.append(Rect2(-WIDTH * 0.5, -DOOR_WIDTH * 0.5 - 0.3, 1.2, DOOR_WIDTH + 0.6))
	return areas


func _scatter_piles() -> Array[Vector4]:
	return [
		Vector4(-12.5, -10.0, 5.0, 4.4), Vector4(12.0, -9.5, 5.0, 4.4),
		Vector4(-12.0, 3.5, 4.0, 3.8), Vector4(10.0, 2.0, 4.0, 3.8),
		Vector4(-8.0, -4.0, 1.0, 7.0), Vector4(8.0, 8.0, 1.0, 6.0),
		Vector4(0.0, -11.0, 1.0, 5.0), Vector4(-16.0, -8.0, 1.0, 4.0),
		Vector4(15.0, -10.0, 1.0, 4.0), Vector4(-4.0, 10.0, 1.0, 4.0),
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
	var vinyl: StandardMaterial3D = _tinted(_floor, Color(0.92, 0.88, 0.82))
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
		var cut := CSGBox3D.new()
		cut.operation = CSGShape3D.OPERATION_SUBTRACTION
		cut.size = Vector3(hole.size.x, 1.2, hole.size.y)
		cut.position = Vector3(hole.get_center().x, 0.1, hole.get_center().y)
		csg.add_child(cut)
	add_child(csg)


func _build_foam_mats() -> void:
	var colors := [
		Color(0.86, 0.18, 0.22), Color(0.95, 0.78, 0.12), Color(0.18, 0.55, 0.28),
		Color(0.15, 0.35, 0.82), Color(0.55, 0.18, 0.72), Color(0.95, 0.45, 0.12),
	]
	var tile := 1.5
	var x := -WIDTH * 0.5
	var n := 0
	while x < WIDTH * 0.5 - 0.05:
		var z := -DEPTH * 0.5
		while z < DEPTH * 0.5 - 0.05:
			var cx := x + tile * 0.5
			var cz := z + tile * 0.5
			var over_pit := false
			for hole in PITS:
				if hole.grow(0.05).has_point(Vector2(cx, cz)):
					over_pit = true
					break
			if not over_pit:
				LevelKit.box(self, Vector3(tile - 0.02, 0.03, tile - 0.02), Vector3(cx, 0.015, cz), _plastic(colors[n % colors.size()]), false)
			n += 1
			z += tile
		x += tile


func _build_walls() -> void:
	var x := WIDTH * 0.5
	var z := DEPTH * 0.5
	_wall(-x - WALL, x + WALL, -z - WALL, -z)
	_wall(-x - WALL, x + WALL, z, z + WALL)
	# West wall, doorway to Level 3.
	_wall(-x - WALL, -x, -z, -DOOR_WIDTH * 0.5)
	_wall(-x - WALL, -x, DOOR_WIDTH * 0.5, z)
	_wall(-x - WALL, -x, -DOOR_WIDTH * 0.5, DOOR_WIDTH * 0.5, DOOR_HEIGHT)
	# East wall, doorway to Level 2.
	_wall(x, x + WALL, -z, -DOOR_WIDTH * 0.5)
	_wall(x, x + WALL, DOOR_WIDTH * 0.5, z)
	_wall(x, x + WALL, -DOOR_WIDTH * 0.5, DOOR_WIDTH * 0.5, DOOR_HEIGHT)


func _build_pillars() -> void:
	var half := PILLAR * 0.5
	for at: Vector2 in PILLARS:
		_wall(at.x - half, at.x + half, at.y - half, at.y + half, 0.0, PILLAR_TOP)
		LevelKit.box(self, Vector3(PILLAR + 0.3, 0.25, PILLAR + 0.3), Vector3(at.x, PILLAR_TOP + 0.125, at.y), _mat, false)


# Painted plaster wall or pillar between two corners. A dark dado at knee height.
func _wall(x0: float, x1: float, z0: float, z1: float, from := 0.0, to := HEIGHT) -> void:
	var size := Vector3(x1 - x0, to - from, z1 - z0)
	if size.x < 0.01 or size.y < 0.01 or size.z < 0.01:
		return
	var centre := Vector3((x0 + x1) * 0.5, (from + to) * 0.5, (z0 + z1) * 0.5)
	LevelKit.box(self, size, centre, _plaster)
	if from < 0.12 and to > 0.12:
		LevelKit.box(self, Vector3(size.x + 0.01, 0.12, size.z + 0.01), Vector3(centre.x, 0.06, centre.z), _mat, false)


# Night-sky ceiling with a hanging lamp, stars and foam clouds.
func _build_ceiling() -> void:
	var night := _tinted(_concrete, Color(0.12, 0.13, 0.22))
	LevelKit.box(self, Vector3(WIDTH + WALL * 2.0, 0.3, DEPTH + WALL * 2.0), Vector3(0.0, HEIGHT + 0.15, 0.0), night)
	var star := LevelKit.glow(Color(1.0, 0.92, 0.45), 2.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	for n in 90:
		var sx := rng.randf_range(-WIDTH * 0.48, WIDTH * 0.48)
		var sz := rng.randf_range(-DEPTH * 0.48, DEPTH * 0.48)
		LevelKit.box(self, Vector3(0.08, 0.02, 0.08), Vector3(sx, HEIGHT - 0.04, sz), star, false)
	var cloud := _plastic(Color(0.93, 0.93, 0.96))
	for at: Vector2 in [Vector2(-8.0, -6.0), Vector2(7.0, 5.0), Vector2(-3.0, 8.0), Vector2(10.0, -8.0)]:
		_cloud(Vector3(at.x, HEIGHT - 1.1, at.y), cloud)
	var lamp := SphereMesh.new()
	lamp.radius = 0.45
	lamp.height = 0.9
	var globe := MeshInstance3D.new()
	globe.mesh = lamp
	globe.position = Vector3(0.0, HEIGHT - 1.6, 0.0)
	globe.material_override = LevelKit.glow(Color(0.75, 0.82, 1.0), 4.0)
	globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(globe)
	var hang := OmniLight3D.new()
	hang.position = Vector3(0.0, HEIGHT - 1.8, 0.0)
	hang.light_color = Color(1.0, 0.96, 0.9)
	hang.light_energy = 7.0
	hang.omni_range = 22.0
	add_child(hang)


func _cloud(at: Vector3, material: Material) -> void:
	for offset in [Vector3.ZERO, Vector3(0.55, 0.1, 0.1), Vector3(-0.5, 0.05, -0.15), Vector3(0.15, 0.2, 0.4)]:
		var mesh := SphereMesh.new()
		mesh.radius = 0.42
		mesh.height = 0.55
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.position = at + offset
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


# Twelve high-bay pendants. Each is a spot pointing down plus a faint fill so the roof structure is not black.
func _build_lights() -> void:
	var lens := LevelKit.glow(Color(1.0, 0.97, 0.9), 5.0)
	for z: float in LIGHT_ROWS:
		for x: float in LIGHT_COLUMNS:
			LevelKit.pipe(self, Vector3(x, LIGHT_HEIGHT + 0.3, z), Vector3(x, HEIGHT, z), 0.018, _dark_steel, 8)
			var shade := CylinderMesh.new()
			shade.top_radius = 0.14
			shade.bottom_radius = 0.42
			shade.height = 0.3
			shade.radial_segments = 28
			var housing := MeshInstance3D.new()
			housing.mesh = shade
			housing.material_override = _dark_steel
			housing.position = Vector3(x, LIGHT_HEIGHT + 0.15, z)
			add_child(housing)
			var disc := CylinderMesh.new()
			disc.top_radius = 0.36
			disc.bottom_radius = 0.36
			disc.height = 0.02
			disc.radial_segments = 28
			var glass := MeshInstance3D.new()
			glass.mesh = disc
			glass.material_override = lens
			glass.position = Vector3(x, LIGHT_HEIGHT + 0.005, z)
			glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(glass)

			var spot := SpotLight3D.new()
			spot.position = Vector3(x, LIGHT_HEIGHT - 0.03, z)
			spot.rotation.x = -PI * 0.5
			spot.light_color = Color(1.0, 0.95, 0.88)
			spot.light_energy = 5.8
			spot.spot_range = 13.0
			spot.spot_angle = 74.0
			spot.spot_angle_attenuation = 0.7
			spot.spot_attenuation = 1.1
			spot.shadow_bias = 0.04
			spot.shadow_blur = 1.5
			add_child(spot)
			_spots.append(spot)

			var fill := OmniLight3D.new()
			fill.position = Vector3(x, LIGHT_HEIGHT + 0.75, z)
			fill.light_color = Color(1.0, 0.94, 0.88)
			fill.light_energy = 1.6
			fill.omni_range = 12.0
			fill.light_specular = 0.0
			add_child(fill)


# ---------------------------------------------------------------- classroom doors
# `facing` points into the hall. The leaf is a thin slab on that wall, not a box standing in the room.

func _build_doors() -> void:
	_classroom_door(Vector3(WIDTH * 0.5, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0), 1, true)
	_classroom_door(Vector3(-WIDTH * 0.5, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), 2, false)
	LevelKit.collider(self, Vector3(WALL, DOOR_HEIGHT, DOOR_WIDTH), Vector3(-WIDTH * 0.5 - WALL * 0.5, DOOR_HEIGHT * 0.5, 0.0))
	_classroom_door(Vector3(-10.0, 0.0, -DEPTH * 0.5), Vector3(0.0, 0.0, 1.0), 3, false)
	_classroom_door(Vector3(10.0, 0.0, -DEPTH * 0.5), Vector3(0.0, 0.0, 1.0), 4, false)
	_classroom_door(Vector3(-10.0, 0.0, DEPTH * 0.5), Vector3(0.0, 0.0, -1.0), 5, false)
	_classroom_door(Vector3(10.0, 0.0, DEPTH * 0.5), Vector3(0.0, 0.0, -1.0), 6, false)


func _classroom_door(at: Vector3, facing: Vector3, level: int, tracked: bool) -> void:
	var along := Vector3(-facing.z, 0.0, facing.x)
	var leaf_h := DOOR_HEIGHT - 0.08
	var leaf_w := DOOR_WIDTH - 0.18
	var thick := 0.07
	var size := Vector3(absf(facing.x) * thick + absf(along.x) * leaf_w, leaf_h, absf(facing.z) * thick + absf(along.z) * leaf_w)
	var centre := at + facing * (thick * 0.5 + 0.01) + Vector3(0.0, leaf_h * 0.5, 0.0)
	var leaf := LevelKit.box(self, size, centre, _door_paint, false)
	if tracked:
		_east_leaves.append(leaf)
		_east_gate = LevelKit.collider(self, Vector3(WALL, DOOR_HEIGHT, DOOR_WIDTH), at + Vector3(-facing.x * WALL * 0.5, DOOR_HEIGHT * 0.5, -facing.z * WALL * 0.5))
	var frame_w := DOOR_WIDTH + 0.12
	var jamb := 0.08
	for side: float in [-1.0, 1.0]:
		var jamb_size := Vector3(absf(facing.x) * 0.1 + absf(along.x) * jamb, DOOR_HEIGHT, absf(facing.z) * 0.1 + absf(along.z) * jamb)
		LevelKit.box(self, jamb_size, at + along * side * (leaf_w * 0.5 + jamb * 0.5) + facing * 0.04 + Vector3(0.0, DOOR_HEIGHT * 0.5, 0.0), _steel, false)
	LevelKit.box(self, Vector3(absf(facing.x) * 0.1 + absf(along.x) * frame_w, 0.1, absf(facing.z) * 0.1 + absf(along.z) * frame_w),
		at + facing * 0.04 + Vector3(0.0, DOOR_HEIGHT - 0.04, 0.0), _steel, false)
	var handle := at + facing * 0.08 + along * (leaf_w * 0.32) + Vector3(0.0, 1.05, 0.0)
	LevelKit.box(self, Vector3(0.04, 0.14, 0.08), handle, _steel, false)
	var board_size := Vector3(absf(facing.x) * 0.04 + absf(along.x) * 2.5, 0.7, absf(facing.z) * 0.04 + absf(along.z) * 2.5)
	LevelKit.box(self, board_size, at + facing * 0.03 + Vector3(0.0, 3.62, 0.0), _dark_steel, false)
	var title := _wall_sign("LEVEL %d   %s" % [level + 1, GameState.level_name(level).to_upper()], 88, at + facing * 0.06 + Vector3(0.0, 3.78, 0.0), facing)
	title.modulate = Color(0.95, 0.93, 0.88)
	var status := _wall_sign("LOCKED", 64, at + facing * 0.06 + Vector3(0.0, 3.4, 0.0), facing)
	status.modulate = Color(1.0, 0.22, 0.16)
	var lamp := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.05
	bulb.height = 0.1
	lamp.mesh = bulb
	lamp.position = at + facing * 0.07 + along * -1.05 + Vector3(0.0, 3.4, 0.0)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.material_override = LevelKit.glow(Color(1.0, 0.2, 0.15), 3.2)
	add_child(lamp)
	if tracked:
		_door_status = status
		_door_lamp = lamp


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


func _show_door_state() -> void:
	var open: bool = GameState.unlocked[LEVEL_INDEX + 1]
	var color := Color(0.25, 1.0, 0.4) if open else Color(1.0, 0.2, 0.15)
	_door_status.text = "OPEN" if open else "LOCKED"
	_door_status.modulate = color
	_door_lamp.material_override = LevelKit.glow(color, 4.0)
	if _east_gate != null:
		_east_gate.collision_layer = 0 if open else LevelKit.WORLD_LAYER
	for leaf in _east_leaves:
		leaf.visible = not open


func _on_level_unlocked(level: int) -> void:
	if level == LEVEL_INDEX + 1:
		_show_door_state()


func _build_rainbow_arch() -> void:
	var bands := [
		Color(0.9, 0.15, 0.18), Color(0.95, 0.5, 0.1), Color(0.95, 0.85, 0.15),
		Color(0.2, 0.7, 0.3), Color(0.2, 0.4, 0.9), Color(0.5, 0.2, 0.75),
	]
	var x := WIDTH * 0.5 - 0.08
	for n in bands.size():
		var radius := 1.85 + n * 0.09
		var mat := _plastic(bands[n])
		for step in 11:
			var a := PI * 0.08 + PI * 0.84 * step / 10.0
			var y := 0.35 + sin(a) * radius
			var z := cos(a) * radius
			LevelKit.box(self, Vector3(0.12, 0.16, 0.16), Vector3(x, y, z), mat, false)


# ---------------------------------------------------------------- fittings

func _build_fittings() -> void:
	_couch(Vector2(-6.0, -14.4), Vector3(0.0, 0.0, 1.0), _plastic(Color(0.75, 0.22, 0.28)))
	_couch(Vector2(6.0, -14.4), Vector3(0.0, 0.0, 1.0), _plastic(Color(0.2, 0.38, 0.78)))
	_couch(Vector2(-6.0, 14.4), Vector3(0.0, 0.0, -1.0), _plastic(Color(0.2, 0.62, 0.38)))
	_couch(Vector2(6.0, 14.4), Vector3(0.0, 0.0, -1.0), _plastic(Color(0.9, 0.72, 0.18)))
	_couch(Vector2(-18.6, -10.0), Vector3(1.0, 0.0, 0.0), _plastic(Color(0.55, 0.28, 0.7)))
	_couch(Vector2(-18.6, 2.0), Vector3(1.0, 0.0, 0.0), _plastic(Color(0.9, 0.45, 0.18)))

	# Soft play cubes in the corners.
	var cube := _paint(Color(0.2, 0.45, 0.72))
	for at: Vector2 in [Vector2(-18.2, -12.8), Vector2(18.2, -12.8), Vector2(-18.2, 12.8), Vector2(18.2, 12.8)]:
		LevelKit.box(self, Vector3(0.7, 0.7, 0.7), Vector3(at.x, 0.35, at.y), cube)

	# Ventilation grilles high on the north and south walls.
	for z: float in [-DEPTH * 0.5, DEPTH * 0.5]:
		var inward := 1.0 if z < 0.0 else -1.0
		for x: float in [-10.0, 10.0]:
			LevelKit.box(self, Vector3(1.2, 0.6, 0.05), Vector3(x, 6.15, z + inward * 0.025), _dark_steel, false)
			for slat in 6:
				LevelKit.box(self, Vector3(1.1, 0.03, 0.03), Vector3(x, 5.92 + slat * 0.09, z + inward * 0.06), _galvanized, false)

	# Two service pipes along the north wall.
	var wall := -DEPTH * 0.5 + 0.11
	for y: float in [4.42, 4.66]:
		LevelKit.pipe(self, Vector3(-WIDTH * 0.5, y, wall), Vector3(WIDTH * 0.5, y, wall), 0.045, _galvanized, 12)
	var x := -18.0
	while x <= 18.0:
		LevelKit.box(self, Vector3(0.05, 0.42, 0.11), Vector3(x, 4.54, wall - 0.055), _dark_steel, false)
		x += 3.0

	# The hum of the light fittings, heard from two points under the roof.
	for at_x: float in [-10.0, 10.0]:
		var hum := AudioStreamPlayer3D.new()
		hum.stream = Sfx.stream("room_hum")
		hum.bus = "Environment"
		hum.position = Vector3(at_x, 5.5, 0.0)
		hum.unit_size = 14.0
		hum.volume_db = -16.0
		hum.autoplay = true
		add_child(hum)


func _couch(at: Vector2, facing: Vector3, cloth: Material) -> void:
	var along := Vector3(-facing.z, 0.0, facing.x)
	var seat := Vector3(absf(along.x) * BENCH.x + absf(facing.x) * BENCH.z, BENCH.y, absf(along.z) * BENCH.x + absf(facing.z) * BENCH.z)
	LevelKit.box(self, seat, Vector3(at.x, BENCH.y * 0.5, at.y), cloth)
	var back := Vector3(absf(along.x) * BENCH.x + absf(facing.x) * 0.16, 0.72, absf(along.z) * BENCH.x + absf(facing.z) * 0.16)
	var back_at := Vector3(at.x, 0.72 * 0.5 + 0.12, at.y) - facing * (BENCH.z * 0.5 - 0.08)
	LevelKit.box(self, back, back_at, cloth)
	for side: float in [-1.0, 1.0]:
		var arm := Vector3(absf(along.x) * 0.16 + absf(facing.x) * BENCH.z, 0.52, absf(along.z) * 0.16 + absf(facing.z) * BENCH.z)
		LevelKit.box(self, arm, Vector3(at.x, 0.32, at.y) + along * side * (BENCH.x * 0.5 - 0.08), cloth)


func _hang_drawings() -> void:
	var spots := [
		Vector3(-19.78, 1.7, -8.0), Vector3(-19.78, 1.85, 8.0),
		Vector3(19.78, 1.7, -8.0), Vector3(19.78, 1.9, 8.5),
		Vector3(-8.0, 1.75, -14.78), Vector3(8.0, 1.65, -14.78),
		Vector3(-8.0, 1.8, 14.78), Vector3(6.5, 1.7, 14.78),
	]
	var yaws := [PI * 0.5, PI * 0.5, -PI * 0.5, -PI * 0.5, 0.0, 0.0, PI, PI]
	for n in spots.size():
		var quad := QuadMesh.new()
		quad.size = Vector2(1.7, 1.28)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = Drawings.sheet(n)
		mat.roughness = 0.95
		mat.metallic = 0.0
		var node := MeshInstance3D.new()
		node.mesh = quad
		node.material_override = mat
		node.position = spots[n]
		node.rotation.y = yaws[n]
		node.rotation.z = 0.04 if n % 2 == 0 else -0.05
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


# ---------------------------------------------------------------- light and atmosphere

func _build_environment() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.55, 0.58, 0.62)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.95, 0.92, 0.88)
	_environment.ambient_light_energy = 0.85
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.tonemap_white = 5.0
	_environment.ssao_radius = 0.45
	_environment.ssao_intensity = 2.2
	_environment.ssao_power = 1.6
	_environment.ssr_max_steps = 48
	_environment.ssr_fade_in = 0.2
	_environment.ssr_fade_out = 2.5
	_environment.glow_intensity = 0.35
	_environment.glow_bloom = 0.02
	_environment.glow_hdr_threshold = 1.15
	# A trace of haze so the far end of the hall sits back.
	_environment.fog_enabled = true
	_environment.fog_light_color = Color(0.92, 0.9, 0.86)
	_environment.fog_density = 0.0015
	_flicker = OmniLight3D.new()
	_flicker.position = Vector3(6.0, 4.2, -4.0)
	_flicker.light_color = Color(1.0, 0.95, 0.85)
	_flicker.light_energy = 2.2
	_flicker.omni_range = 10.0
	add_child(_flicker)
	for at: Vector3 in [Vector3(-12.0, 3.2, 0.0), Vector3(12.0, 3.2, 0.0), Vector3(0.0, 3.0, -10.0), Vector3(0.0, 3.0, 10.0)]:
		var extra := OmniLight3D.new()
		extra.position = at
		extra.light_color = Color(1.0, 0.96, 0.9)
		extra.light_energy = 1.8
		extra.omni_range = 11.0
		extra.light_specular = 0.2
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


func _process(delta: float) -> void:
	_time += delta
	if _flicker != null:
		_flicker.light_energy = 2.0 + 0.3 * sin(_time * 1.4)
