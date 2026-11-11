# Level layouts as plain numbers. To design a level you only edit this file.
#
# Units are metres. Looking down on the room: x runs west (-) to east (+), z runs north (-) to south (+).
#
#   room        width (x), ceiling height, depth (z). The room is centred on 0,0.
#   platforms   in route order. The first is the start, the last carries the finish pad.
#               at = centre, size = width x depth, top = height of the walking surface above the grass.
#   walls       inner walls, floor to ceiling. Rect2(x, z, width, depth) of the footprint.
#   lintels     wall pieces above a doorway (the gap between two walls).
#   columns     centre of each square pillar.
#   lights      ceiling grid. dead / flicker list cells as Vector2i(column, row), counted from the north-west.
#   enemies     type + where it starts and returns to after a death.
#
# Jump limits (see player.gd): a walking jump clears about a 2.2 m gap, a sprint jump about 3.4 m.
# A platform top of 1.2 m or less can be climbed from the grass. Higher ones can only be reached from another platform.
extends RefCounted

const TOTAL_LEVELS := 50

const LEVEL_1 := {
	"room": Vector3(40.0, 5.0, 26.0),
	"platforms": [
		{"at": Vector2(-16.0, -7.0), "size": Vector2(3.0, 3.0), "top": 1.0},
		{"at": Vector2(-12.0, -5.6), "size": Vector2(2.2, 2.2), "top": 1.0},
		{"at": Vector2(-9.4, -1.8), "size": Vector2(2.0, 2.0), "top": 1.0},
		{"at": Vector2(-6.2, 1.4), "size": Vector2(2.4, 1.8), "top": 1.2},
		{"at": Vector2(-2.4, 3.2), "size": Vector2(2.0, 2.0), "top": 1.45},
		{"at": Vector2(-0.4, -1.2), "size": Vector2(1.4, 3.4), "top": 1.45},
		{"at": Vector2(0.6, -6.5), "size": Vector2(2.2, 2.2), "top": 1.6},
		{"at": Vector2(4.4, -7.0), "size": Vector2(2.0, 2.0), "top": 1.6},
		{"at": Vector2(7.8, -4.2), "size": Vector2(2.0, 2.0), "top": 1.45},
		{"at": Vector2(10.6, -0.6), "size": Vector2(1.6, 2.6), "top": 1.45},
		{"at": Vector2(12.4, 3.8), "size": Vector2(2.0, 2.0), "top": 1.45},
		{"at": Vector2(16.2, 7.8), "size": Vector2(3.2, 3.2), "top": 1.45},
	],
	"walls": [
		Rect2(-5.2, -13.0, 0.4, 3.6),
		Rect2(-5.2, -7.6, 0.4, 6.1),
		Rect2(4.8, 1.5, 0.4, 6.1),
		Rect2(4.8, 9.4, 0.4, 3.6),
	],
	"lintels": [
		Rect2(-5.2, -9.4, 0.4, 1.8),
		Rect2(4.8, 7.6, 0.4, 1.8),
	],
	"columns": [
		Vector2(-13.0, 1.5),
		Vector2(-13.5, 8.5),
		Vector2(-2.5, -10.6),
		Vector2(-1.5, 8.5),
		Vector2(3.5, -2.0),
		Vector2(12.5, -8.5),
		Vector2(16.5, -1.5),
		Vector2(10.0, 9.5),
	],
	"lights": {
		"spacing": 4.8,
		"columns": 8,
		"rows": 5,
		"dead": [
			Vector2i(1, 0), Vector2i(2, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0),
			Vector2i(3, 1), Vector2i(7, 1),
			Vector2i(1, 3), Vector2i(4, 3),
			Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(7, 4),
		],
		"flicker": [Vector2i(3, 0), Vector2i(0, 2), Vector2i(5, 3), Vector2i(6, 4)],
	},
	"enemies": [
		{"type": "ant", "at": Vector2(-11.0, 6.0)},
	],
}

# Add LEVEL_2, LEVEL_3, ... above and list them here in order.
const LEVELS := [LEVEL_1]


static func has_level(number: int) -> bool:
	return number >= 1 and number <= LEVELS.size()


static func get_level(number: int) -> Dictionary:
	return LEVELS[number - 1]
