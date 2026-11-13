class_name ThemedLevel
extends Node3D
## One of the rooms off the playroom: hotel, office, school, backrooms, waiting room, or ball pit.
##
## The node sits at the centre of the room. Balls stack into hills from `PILES`. The doorway that faces
## the playroom is left open so the matching door in Level 1 is the only lock.

var theme := "hotel"
var level_index := 1
var length := 32.0
var width := 6.0
var height := 3.4
var ball_seed := 1
## Which local wall has the opening back to the playroom: "west", "east", "south", "north".
var door_side := "west"
var PILES: Array[Vector4] = []

var _floor: StandardMaterial3D
var _wall: StandardMaterial3D
var _trim: StandardMaterial3D
var _accent: StandardMaterial3D


func _ready() -> void:
	_paint_theme()
	_shell()
	_props()
	_lights()
	if PILES.is_empty():
		PILES = _hills()


func spawn_point() -> Vector3:
	var inward := _inward()
	return global_position + inward * (2.2 - length * 0.5) + Vector3(0.0, 0.05, 0.0)


func spawn_yaw() -> float:
	var inward := _inward()
	return atan2(-inward.x, -inward.z)


func contains(at: Vector3) -> bool:
	var local := at - global_position
	var along := length * 0.5
	var across := width * 0.5
	if door_side == "west" or door_side == "east":
		return absf(local.x) < along and absf(local.z) < across
	return absf(local.z) < along and absf(local.x) < across


func ball_bounds() -> Rect2:
	var origin := Vector2(global_position.x, global_position.z)
	var size := Vector2(length, width) if door_side == "west" or door_side == "east" else Vector2(width, length)
	return Rect2(origin - size * 0.5 + Vector2(0.35, 0.35), size - Vector2(0.7, 0.7))


func blocked_areas() -> Array[Rect2]:
	return []


func _inward() -> Vector3:
	match door_side:
		"west":
			return Vector3(1, 0, 0)
		"east":
			return Vector3(-1, 0, 0)
		"south":
			return Vector3(0, 0, -1)
		_:
			return Vector3(0, 0, 1)


func _paint_theme() -> void:
	match theme:
		"hotel":
			_floor = _mat(Color(0.45, 0.28, 0.16), 0.7)
			_wall = _mat(Color(0.32, 0.18, 0.1), 0.65)
			_trim = _mat(Color(0.55, 0.32, 0.16), 0.5)
			_accent = _mat(Color(0.72, 0.16, 0.14), 0.4)
		"office":
			_floor = _mat(Color(0.35, 0.4, 0.42), 0.85)
			_wall = _mat(Color(0.82, 0.84, 0.86), 0.8)
			_trim = _mat(Color(0.25, 0.32, 0.4), 0.55)
			_accent = _mat(Color(0.15, 0.16, 0.18), 0.4)
		"school":
			_floor = _mat(Color(0.55, 0.56, 0.58), 0.75)
			_wall = _mat(Color(0.62, 0.66, 0.62), 0.8)
			_trim = _mat(Color(0.75, 0.12, 0.12), 0.35)
			_accent = _mat(Color(0.9, 0.9, 0.92), 0.3)
		"backrooms":
			_floor = _mat(Color(0.72, 0.62, 0.28), 0.9)
			_wall = _mat(Color(0.86, 0.75, 0.22), 0.85)
			_trim = _mat(Color(0.7, 0.58, 0.16), 0.8)
			_accent = _mat(Color(0.95, 0.9, 0.55), 0.4)
		"waiting":
			_floor = _mat(Color(0.42, 0.42, 0.44), 0.7)
			_wall = _mat(Color(0.72, 0.72, 0.74), 0.75)
			_trim = _mat(Color(0.18, 0.18, 0.2), 0.5)
			_accent = _mat(Color(0.12, 0.12, 0.13), 0.4)
		_:
			_floor = _mat(Color(0.18, 0.28, 0.72), 0.25)
			_wall = _mat(Color(0.72, 0.12, 0.38), 0.35)
			_trim = _mat(Color(0.85, 0.2, 0.42), 0.3)
			_accent = _mat(Color(0.15, 0.2, 0.55), 0.3)


func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	return material


func _shell() -> void:
	var along_x := door_side == "west" or door_side == "east"
	var sx := length if along_x else width
	var sz := width if along_x else length
	LevelKit.box(self, Vector3(sx, 0.3, sz), Vector3(0, -0.15, 0), _floor)
	LevelKit.collider(self, Vector3(sx + 6.0, 1.2, sz + 6.0), Vector3(0, -0.7, 0))
	var ceiling_color := Color(0.55, 0.32, 0.24) if theme == "hotel" else Color(0.9, 0.9, 0.92)
	LevelKit.box(self, Vector3(sx, 0.2, sz), Vector3(0, height, 0), _mat(ceiling_color, 0.8))
	_side_wall(Vector3(-sx * 0.5, height * 0.5, 0), Vector3(0.3, height, sz), "west")
	_side_wall(Vector3(sx * 0.5, height * 0.5, 0), Vector3(0.3, height, sz), "east")
	_side_wall(Vector3(0, height * 0.5, -sz * 0.5), Vector3(sx, height, 0.3), "north")
	_side_wall(Vector3(0, height * 0.5, sz * 0.5), Vector3(sx, height, 0.3), "south")


func _side_wall(centre: Vector3, size: Vector3, side: String) -> void:
	if side != door_side:
		LevelKit.box(self, size, centre, _wall)
		return
	var opening := 1.25
	var door_h := 2.2
	var header := size.y - door_h
	if size.x < size.z:
		LevelKit.box(self, Vector3(size.x, size.y, (size.z - opening) * 0.5), centre + Vector3(0, 0, (size.z + opening) * 0.25), _wall)
		LevelKit.box(self, Vector3(size.x, size.y, (size.z - opening) * 0.5), centre - Vector3(0, 0, (size.z + opening) * 0.25), _wall)
		LevelKit.box(self, Vector3(size.x, header, opening), centre + Vector3(0, door_h * 0.5, 0), _wall)
	else:
		LevelKit.box(self, Vector3((size.x - opening) * 0.5, size.y, size.z), centre + Vector3((size.x + opening) * 0.25, 0, 0), _wall)
		LevelKit.box(self, Vector3((size.x - opening) * 0.5, size.y, size.z), centre - Vector3((size.x + opening) * 0.25, 0, 0), _wall)
		LevelKit.box(self, Vector3(opening, header, size.z), centre + Vector3(0, door_h * 0.5, 0), _wall)


func _props() -> void:
	match theme:
		"hotel":
			_hotel()
		"office":
			_office()
		"school":
			_school()
		"backrooms":
			_backrooms()
		"waiting":
			_waiting()
		_:
			_ball_pit()


func _hotel() -> void:
	var numbers := [612, 614, 641, 708, 710, 712]
	var n := 0
	var x := -length * 0.5 + 4.0
	while x < length * 0.5 - 2.0 and n < numbers.size():
		for side in [-1.0, 1.0]:
			if n >= numbers.size():
				break
			_door(Vector3(x, 0, side * (width * 0.5 - 0.16)), str(numbers[n]), side > 0.0)
			n += 1
		x += 5.2
	var title := _sign("HOTEL", Vector3(0, 2.7, 0))
	title.font_size = 120


func _door(at: Vector3, number: String, positive_z: bool) -> void:
	LevelKit.box(self, Vector3(1.15, 2.4, 0.08), at + Vector3(0, 1.25, 0), _trim, false)
	var plate_z := 0.05 if positive_z else -0.05
	var plate := _sign(number, at + Vector3(0.85, 1.5, plate_z))
	plate.font_size = 42
	plate.rotation.y = 0.0 if positive_z else PI


func _office() -> void:
	var desk := _mat(Color(0.45, 0.5, 0.55), 0.6)
	var screen := _mat(Color(0.05, 0.08, 0.12), 0.3)
	for gx in range(-2, 3):
		for gz in range(-1, 2):
			var at := Vector3(gx * 4.6, 0, gz * 4.2)
			LevelKit.box(self, Vector3(0.08, 1.45, 3.4), at + Vector3(-1.5, 0.72, 0), _trim)
			LevelKit.box(self, Vector3(2.2, 0.08, 0.8), at + Vector3(0.1, 0.78, 0.9), desk, false)
			LevelKit.box(self, Vector3(0.55, 0.4, 0.05), at + Vector3(0.1, 1.05, 0.55), screen, false)


func _school() -> void:
	var run := length * 0.5 - 1.5
	for side in [-1.0, 1.0]:
		var z := -run
		while z < run:
			LevelKit.box(self, Vector3(0.45, 2.05, 0.85), Vector3(side * (width * 0.5 - 0.28), 1.05, z), _trim, false)
			LevelKit.box(self, Vector3(0.06, 0.5, 0.04), Vector3(side * (width * 0.5 - 0.52), 1.15, z), _accent, false)
			z += 0.95
	var locker_colors: Array[Color] = [Color(0.9, 0.2, 0.15), Color(0.2, 0.45, 0.9), Color(0.95, 0.8, 0.15), Color(0.2, 0.7, 0.3)]
	for ball_z in [-length * 0.35, 0.0, length * 0.35]:
		for i in 8:
			LevelKit.box(self, Vector3(0.22, 0.22, 0.22), Vector3(-width * 0.5 + 0.7 + i * 0.28, height - 0.35, ball_z), _mat(locker_colors[i % 4], 0.35), false)


func _backrooms() -> void:
	LevelKit.box(self, Vector3(width * 0.55, height, 0.2), _long(-length * 0.15, width * 0.15) + Vector3(0, height * 0.5, 0), _trim)
	LevelKit.box(self, Vector3(0.2, height, length * 0.35), _long(length * 0.1, -width * 0.1) + Vector3(0, height * 0.5, 0), _trim)


func _waiting() -> void:
	var along := -length * 0.5 + 3.5
	while along < length * 0.5 - 2.0:
		for side in [-1.0, 1.0]:
			var at := _long(along, side * (width * 0.5 - 0.16))
			var door_size := Vector3(0.08, 2.3, 1.1)
			if door_side == "west" or door_side == "east":
				door_size = Vector3(1.1, 2.3, 0.08)
			LevelKit.box(self, door_size, at + Vector3(0, 1.2, 0), _trim, false)
		along += 4.4
	var tv := _long(0.0, -width * 0.5 + 0.25)
	LevelKit.box(self, Vector3(0.08, 0.8, 1.4), tv + Vector3(0, 2.0, 0), _accent, false)
	LevelKit.box(self, Vector3(0.04, 0.55, 1.1), tv + Vector3(0.06, 2.0, 0), LevelKit.glow(Color(0.15, 0.15, 0.18), 0.4), false)


func _ball_pit() -> void:
	var foam := _wall
	var hx := width * 0.5 - 1.1
	var hz := length * 0.5 - 1.1
	LevelKit.box(self, Vector3(width - 1.4, 0.08, length - 1.4), Vector3(0, 0.05, 0), _floor, false)
	LevelKit.box(self, Vector3(0.7, 0.85, length), Vector3(hx, 0.45, 0), foam, false)
	LevelKit.box(self, Vector3(0.7, 0.85, length), Vector3(-hx, 0.45, 0), foam, false)
	LevelKit.box(self, Vector3(width, 0.85, 0.7), Vector3(0, 0.45, hz), foam, false)
	LevelKit.box(self, Vector3(0.7, 0.7, length - 1.4), Vector3(hx - 0.7, 1.15, 0), foam, false)
	LevelKit.box(self, Vector3(0.7, 0.7, length - 1.4), Vector3(-(hx - 0.7), 1.15, 0), foam, false)


func _long(distance: float, side: float) -> Vector3:
	if door_side == "west" or door_side == "east":
		return Vector3(distance, 0.0, side)
	return Vector3(side, 0.0, distance)


func _sign(text: String, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.004
	label.modulate = Color(0.95, 0.93, 0.88)
	label.outline_size = 8
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	return label


func _lights() -> void:
	var count := 4 if theme == "hotel" or theme == "school" or theme == "waiting" else 6
	for i in count:
		var t := (float(i) + 0.5) / float(count) - 0.5
		var at := Vector3(t * length * 0.8, height - 0.15, 0)
		if door_side == "north" or door_side == "south":
			at = Vector3(0, height - 0.15, t * length * 0.8)
		var lamp := OmniLight3D.new()
		lamp.position = at
		lamp.omni_range = 9.0
		lamp.light_energy = 1.4
		lamp.light_color = Color(0.9, 0.95, 1.0)
		if theme == "hotel":
			lamp.light_color = Color(1.0, 0.82, 0.55)
		elif theme == "backrooms":
			lamp.light_color = Color(1.0, 0.9, 0.45)
		add_child(lamp)
		LevelKit.box(self, Vector3(1.2, 0.06, 0.35), at + Vector3(0, 0.08, 0), LevelKit.glow(Color(1, 1, 0.95), 1.5), false)


func _hills() -> Array[Vector4]:
	var piles: Array[Vector4] = []
	var origin := global_position
	var span := length * 0.5 - 3.0
	var peak := 10.0 if theme == "ballpit" else 7.0
	for i in 5:
		var t := (float(i) / 4.0 - 0.5) * span * 2.0
		var at := origin + Vector3(t, 0, 0)
		if door_side == "north" or door_side == "south":
			at = origin + Vector3(0, 0, t)
		piles.append(Vector4(at.x, at.z, peak - float(i % 3), 2.4 + float(i % 2)))
	return piles
