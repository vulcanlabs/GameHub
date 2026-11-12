class_name Level2Pool
extends Node3D
## Level 2, the Poolroom: a tiled indoor pool hall east of the playroom.
##
## White 15 cm wall tiles, 30 cm floor tiles, a shallow pool, a stair into the water, and square pillars.
## There is no pit here. Deposit only happens back through the west door, in Level 1.
## The node is placed so its west doorway lines up with Level 1's east doorway.

const LEVEL_INDEX := 1
const WIDTH := 40.0
const DEPTH := 30.0
const HEIGHT := 7.0
const WALL := 0.4
const DOOR_WIDTH := 3.0
const DOOR_HEIGHT := 3.15
const BALL_SEED := 20261113
const POOL := Rect2(-11.0, -7.0, 22.0, 16.0)
const POOL_FLOOR := -1.35

var PILES: Array[Vector4] = []

var _tile: Material = preload("res://assets/materials/wall_tile_white.tres")
var _floor: Material = preload("res://assets/materials/floor_tile_white.tres")
var _sign_font: Font = preload("res://assets/fonts/BarlowCondensed-Bold.ttf")


func _enter_tree() -> void:
	if PILES.is_empty():
		PILES = [
			Vector4(-16.0, -11.0, 2.0, 5.0), Vector4(16.0, -11.0, 2.0, 5.0),
			Vector4(-16.0, 11.0, 2.0, 5.0), Vector4(16.0, 11.0, 2.0, 5.0),
			Vector4(0.0, -12.5, 1.0, 7.0), Vector4(0.0, 12.5, 1.0, 6.0),
		]


func _ready() -> void:
	_build_shell()
	_build_pool()
	_build_stairs()
	_build_pillars()
	_build_lights()
	_build_door_sign()


func spawn_point() -> Vector3:
	return global_position + Vector3(-WIDTH * 0.5 + 2.2, 0.05, 0.0)


func spawn_yaw() -> float:
	return -PI * 0.5


func ball_bounds() -> Rect2:
	var origin := Vector2(global_position.x, global_position.z)
	return Rect2(origin.x - WIDTH * 0.5 + 0.2, origin.y - DEPTH * 0.5 + 0.2, WIDTH - 0.4, DEPTH - 0.4)


func blocked_areas() -> Array[Rect2]:
	var origin := Vector2(global_position.x, global_position.z)
	var pool := Rect2(origin + POOL.position, POOL.size).grow(0.15)
	return [
		pool,
		Rect2(origin.x - WIDTH * 0.5, origin.y - DOOR_WIDTH * 0.5 - 0.3, 1.4, DOOR_WIDTH + 0.6),
	]


func _build_shell() -> void:
	var x := WIDTH * 0.5
	var z := DEPTH * 0.5
	var csg := CSGCombiner3D.new()
	csg.use_collision = true
	csg.collision_layer = LevelKit.WORLD_LAYER
	csg.collision_mask = 0
	var slab := CSGBox3D.new()
	slab.size = Vector3(WIDTH, 0.4, DEPTH)
	slab.position = Vector3(0.0, -0.2, 0.0)
	slab.material = _floor
	csg.add_child(slab)
	var cut := CSGBox3D.new()
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.size = Vector3(POOL.size.x, 1.2, POOL.size.y)
	cut.position = Vector3(POOL.get_center().x, 0.1, POOL.get_center().y)
	csg.add_child(cut)
	add_child(csg)
	_wall(-x - WALL, x + WALL, -z - WALL, -z)
	_wall(-x - WALL, x + WALL, z, z + WALL)
	_wall(x, x + WALL, -z, z)
	_wall(-x - WALL, -x, -z, -DOOR_WIDTH * 0.5)
	_wall(-x - WALL, -x, DOOR_WIDTH * 0.5, z)
	_wall(-x - WALL, -x, -DOOR_WIDTH * 0.5, DOOR_WIDTH * 0.5, DOOR_HEIGHT)
	LevelKit.box(self, Vector3(WIDTH + WALL * 2.0, 0.3, DEPTH + WALL * 2.0), Vector3(0.0, HEIGHT + 0.15, 0.0), _tile)


func _wall(x0: float, x1: float, z0: float, z1: float, from := 0.0, to := HEIGHT) -> void:
	var size := Vector3(x1 - x0, to - from, z1 - z0)
	if size.x < 0.01 or size.y < 0.01 or size.z < 0.01:
		return
	LevelKit.box(self, size, Vector3((x0 + x1) * 0.5, (from + to) * 0.5, (z0 + z1) * 0.5), _tile)


func _build_pool() -> void:
	var half := POOL.size * 0.5
	var centre := Vector3(POOL.get_center().x, 0.0, POOL.get_center().y)
	LevelKit.box(self, Vector3(POOL.size.x + 0.4, absf(POOL_FLOOR), 0.25),
		centre + Vector3(0.0, POOL_FLOOR * 0.5, half.y + 0.05), _tile, false)
	LevelKit.box(self, Vector3(POOL.size.x + 0.4, absf(POOL_FLOOR), 0.25),
		centre + Vector3(0.0, POOL_FLOOR * 0.5, -half.y - 0.05), _tile, false)
	LevelKit.box(self, Vector3(0.25, absf(POOL_FLOOR), POOL.size.y),
		centre + Vector3(half.x + 0.05, POOL_FLOOR * 0.5, 0.0), _tile, false)
	LevelKit.box(self, Vector3(0.25, absf(POOL_FLOOR), POOL.size.y),
		centre + Vector3(-half.x - 0.05, POOL_FLOOR * 0.5, 0.0), _tile, false)
	LevelKit.box(self, Vector3(POOL.size.x, 0.2, POOL.size.y),
		Vector3(centre.x, POOL_FLOOR - 0.1, centre.z), _tile)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.12, 0.55, 0.52, 0.62)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.06
	water.metallic = 0.22
	water.normal_enabled = true
	water.normal_texture = load("res://assets/textures/Tiles133B/Tiles133B_2K-JPG_NormalGL.jpg")
	water.normal_scale = 0.35
	water.uv1_scale = Vector3(0.35, 0.35, 0.35)
	water.uv1_triplanar = true
	water.uv1_world_triplanar = true
	water.refraction_enabled = true
	water.refraction_scale = 0.06
	var mesh := PlaneMesh.new()
	mesh.size = POOL.size
	var plane := MeshInstance3D.new()
	plane.mesh = mesh
	plane.position = Vector3(centre.x, -0.08, centre.z)
	plane.material_override = water
	add_child(plane)


func _build_stairs() -> void:
	var start := Vector3(POOL.get_center().x, 0.0, POOL.position.y)
	for n in 8:
		var t := float(n)
		var size := Vector3(3.2, 0.16, 0.55)
		var at := start + Vector3(0.0, -0.16 * (n + 1) * 0.5, 0.4 + n * 0.48)
		at.y = -0.16 * (n + 1)
		LevelKit.box(self, Vector3(size.x, 0.16, size.z), Vector3(at.x, at.y + 0.08, at.z), _tile)


func _build_pillars() -> void:
	for at: Vector2 in [Vector2(-6.0, -2.0), Vector2(6.0, -2.0), Vector2(-6.0, 4.0), Vector2(6.0, 4.0)]:
		var h := HEIGHT - POOL_FLOOR
		LevelKit.box(self, Vector3(1.1, h, 1.1), Vector3(at.x, POOL_FLOOR + h * 0.5, at.y), _tile)


func _build_lights() -> void:
	for at: Vector3 in [Vector3(-10.0, 5.6, -8.0), Vector3(10.0, 5.6, -8.0), Vector3(-10.0, 5.6, 8.0), Vector3(10.0, 5.6, 8.0), Vector3(0.0, 5.8, 0.0)]:
		var light := OmniLight3D.new()
		light.position = at
		light.light_color = Color(1.0, 0.98, 0.9)
		light.light_energy = 5.2
		light.omni_range = 18.0
		light.light_color = Color(1.0, 0.98, 0.94)
		add_child(light)


func _build_door_sign() -> void:
	var x := -WIDTH * 0.5
	LevelKit.box(self, Vector3(0.05, 0.7, 2.6), Vector3(x + 0.08, 3.7, 0.0), _tile, false)
	var label := Label3D.new()
	label.text = "LEVEL 1   PLAYROOM"
	label.font = _sign_font
	label.font_size = 90
	label.pixel_size = 0.003
	label.position = Vector3(x + 0.12, 3.85, 0.0)
	label.rotation.y = PI * 0.5
	label.shaded = true
	label.double_sided = false
	label.outline_size = 8
	label.modulate = Color(0.12, 0.14, 0.16)
	add_child(label)
	var back := Label3D.new()
	back.text = "DEPOSIT BALLS HERE"
	back.font = _sign_font
	back.font_size = 64
	back.pixel_size = 0.003
	back.position = Vector3(x + 0.12, 3.45, 0.0)
	back.rotation.y = PI * 0.5
	back.shaded = true
	back.double_sided = false
	back.outline_size = 8
	back.modulate = Color(0.18, 0.5, 0.32)
	add_child(back)
	var probe := ReflectionProbe.new()
	probe.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	probe.size = Vector3(WIDTH, HEIGHT, DEPTH)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)
