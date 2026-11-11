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
# Jump limits (see player.gd): the jump peaks about 1.52 m, so a top of 1.40 m can be climbed from the grass.
# Keep gaps under 2.1 m for a walking jump and under 2.8 m for a sprint. The generator stays inside that.
extends RefCounted

const TOTAL_LEVELS := 50

const LEVEL_1 := {
	"room": Vector3(40.0, 5.0, 26.0),
	"platforms": [
		{"at": Vector2(-16.0, -7.0), "size": Vector2(3.0, 3.0), "top": 1.15},
		{"at": Vector2(-12.0, -5.6), "size": Vector2(2.2, 2.2), "top": 1.15},
		{"at": Vector2(-9.4, -1.8), "size": Vector2(2.0, 2.0), "top": 1.15},
		{"at": Vector2(-6.2, 1.4), "size": Vector2(2.4, 1.8), "top": 1.22},
		{"at": Vector2(-2.4, 3.2), "size": Vector2(2.0, 2.0), "top": 1.32},
		{"at": Vector2(-0.4, -1.2), "size": Vector2(1.4, 3.4), "top": 1.32},
		{"at": Vector2(0.6, -6.5), "size": Vector2(2.2, 2.2), "top": 1.38},
		{"at": Vector2(4.4, -7.0), "size": Vector2(2.0, 2.0), "top": 1.38},
		{"at": Vector2(7.8, -4.2), "size": Vector2(2.0, 2.0), "top": 1.32},
		{"at": Vector2(10.6, -0.6), "size": Vector2(1.6, 2.6), "top": 1.32},
		{"at": Vector2(12.4, 3.8), "size": Vector2(2.0, 2.0), "top": 1.32},
		{"at": Vector2(15.4, 6.4), "size": Vector2(3.2, 3.2), "top": 1.32},
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

# Levels 2 to 50 are built from a fixed seed, so a level is the same every time and different from its neighbours.
static var _cache: Dictionary = {}


static func has_level(number: int) -> bool:
	return number >= 1 and number <= TOTAL_LEVELS


static func get_level(number: int) -> Dictionary:
	if number <= 1:
		return LEVEL_1
	if _cache.has(number):
		return _cache[number]
	var built := _generate(number)
	_cache[number] = built
	return built


static func _band(number: int) -> String:
	if number <= 10:
		return "easy"
	if number <= 24:
		return "mid"
	if number <= 35:
		return "spider"
	return "hard"


static func _generate(number: int) -> Dictionary:
	var last := {}
	var rng := RandomNumberGenerator.new()
	for attempt in 40:
		rng.seed = number * 7919 + attempt * 104729
		last = _attempt(number, rng)
		if _problem(last) == "":
			return last
	push_warning("Level %d used a straight fallback layout." % number)
	return _fallback(number)


static func _attempt(number: int, rng: RandomNumberGenerator) -> Dictionary:
	var band := _band(number)
	var count := 9 + (number % 3)
	var room := Vector3(50.0, 5.0, 36.0)
	var gap_max := 1.8
	var min_size := 1.8
	if band == "mid":
		gap_max = 2.05
		min_size = 1.6
	elif band == "spider":
		gap_max = 2.2
		min_size = 1.5
	elif band == "hard":
		gap_max = 2.35
		min_size = 1.4
	var sizes: Array[Vector2] = []
	for i in count:
		if i == 0 or i == count - 1:
			sizes.append(Vector2(3.0, 3.0))
		else:
			sizes.append(Vector2(rng.randf_range(min_size, min_size + 0.8), rng.randf_range(min_size, min_size + 0.6)))
	var pads: Array[Dictionary] = []
	var pos := Vector2(-room.x * 0.5 + 3.4, rng.randf_range(-2.0, 2.0))
	var horizontal := true
	for i in count:
		var entry := {
			"at": pos,
			"size": sizes[i],
			"top": rng.randf_range(1.15, 1.36),
		}
		if number >= 11 and i > 1 and i < count - 1 and i % 5 == 3:
			var slide_axis := "z" if horizontal else "x"
			var reach := 1.1
			var offset := Vector2(0.0, reach) if slide_axis == "z" else Vector2(reach, 0.0)
			if _inside(pos + offset, sizes[i], room) and _inside(pos - offset, sizes[i], room):
				entry["move"] = {"axis": slide_axis, "distance": reach, "seconds": rng.randf_range(3.2, 4.4)}
		pads.append(entry)
		if i == count - 1:
			break
		var gap := rng.randf_range(1.2, gap_max)
		if rng.randf() < 0.55:
			horizontal = not horizontal
		pos = _step(pos, sizes[i], sizes[i + 1], gap, horizontal, room, rng)
	var data := {
		"room": room,
		"platforms": pads,
		"walls": [],
		"lintels": [],
		"columns": [],
		"lights": _lights(rng, room),
		"enemies": _enemies(number, rng, room, pads),
		"portals": _portals(number, pads),
	}
	return data


static func _step(pos: Vector2, size: Vector2, next_size: Vector2, gap: float, horizontal: bool, room: Vector3, rng: RandomNumberGenerator) -> Vector2:
	var axis := Vector2(1.0, 0.0) if horizontal else Vector2(0.0, 1.0)
	var reach := (size.x if horizontal else size.y) * 0.5 + (next_size.x if horizontal else next_size.y) * 0.5 + gap
	var sign := 1.0 if rng.randf() < 0.5 else -1.0
	for _flip in 2:
		var nxt := pos + axis * reach * sign
		if _inside(nxt, next_size, room):
			return nxt
		sign = -sign
	var other := Vector2(0.0, 1.0) if horizontal else Vector2(1.0, 0.0)
	var reach_other := (size.y if horizontal else size.x) * 0.5 + (next_size.y if horizontal else next_size.x) * 0.5 + gap
	for _flip in 2:
		var nxt := pos + other * reach_other * sign
		if _inside(nxt, next_size, room):
			return nxt
		sign = -sign
	return pos + axis * reach


static func _fallback(number: int) -> Dictionary:
	var pads: Array[Dictionary] = []
	for i in 10:
		pads.append({
			"at": Vector2(-16.0 + float(i) * 4.0, 0.0),
			"size": Vector2(2.5, 2.5),
			"top": 1.2,
		})
	var enemies: Array = [{"type": "ant", "at": Vector2(0.0, 6.0)}]
	if number >= 25:
		enemies.push_front({"type": "spider", "at": Vector2(4.0, -6.0)})
	return {
		"room": Vector3(48.0, 5.0, 24.0),
		"platforms": pads,
		"walls": [],
		"lintels": [],
		"columns": [],
		"lights": _lights(RandomNumberGenerator.new(), Vector3(48.0, 5.0, 24.0)),
		"enemies": enemies,
		"portals": [],
	}


static func _inside(center: Vector2, size: Vector2, room: Vector3) -> bool:
	var margin := 1.6
	return absf(center.x) + size.x * 0.5 < room.x * 0.5 - margin and absf(center.y) + size.y * 0.5 < room.z * 0.5 - margin


static func _rect(entry: Dictionary) -> Rect2:
	var at: Vector2 = entry["at"]
	var size: Vector2 = entry["size"]
	return Rect2(at - size * 0.5, size)


static func _blocks_route(footprint: Rect2, pads: Array[Dictionary]) -> bool:
	for i in pads.size():
		if _rect(pads[i]).grow(1.1).intersects(footprint):
			return true
		if i == 0:
			continue
		var a: Vector2 = pads[i - 1]["at"]
		var b: Vector2 = pads[i]["at"]
		for step in 8:
			if footprint.grow(0.5).has_point(a.lerp(b, float(step) / 7.0)):
				return true
	return false


static func _obstacles(rng: RandomNumberGenerator, room: Vector3, pads: Array[Dictionary], walls: bool) -> Array:
	var out: Array = []
	var want := 3 if walls else 6
	for _try in want * 8:
		if out.size() >= want:
			break
		var item: Variant
		if walls:
			item = Rect2(rng.randf_range(-room.x * 0.4, room.x * 0.4), rng.randf_range(-room.z * 0.4, room.z * 0.4), 0.4, rng.randf_range(2.0, 4.0))
		else:
			var c := Vector2(rng.randf_range(-room.x * 0.42, room.x * 0.42), rng.randf_range(-room.z * 0.42, room.z * 0.42))
			item = c
		var footprint: Rect2 = item if walls else Rect2(item - Vector2(0.6, 0.6), Vector2(1.2, 1.2))
		if not _blocks_route(footprint, pads):
			out.append(item)
	return out


static func _lights(rng: RandomNumberGenerator, room: Vector3) -> Dictionary:
	var columns := maxi(4, int(room.x / 4.8))
	var rows := maxi(3, int(room.z / 4.8))
	var dead: Array[Vector2i] = []
	var flicker: Array[Vector2i] = []
	for x in columns:
		for y in rows:
			var roll := rng.randf()
			if roll < 0.22:
				dead.append(Vector2i(x, y))
			elif roll < 0.30:
				flicker.append(Vector2i(x, y))
	return {"spacing": 4.8, "columns": columns, "rows": rows, "dead": dead, "flicker": flicker}


static func _enemies(number: int, rng: RandomNumberGenerator, room: Vector3, pads: Array[Dictionary]) -> Array:
	var kinds: Array[String] = []
	if number >= 25:
		kinds.append("spider")
	kinds.append("ant")
	if number >= 18:
		kinds.append("ant")
	if number >= 36:
		kinds.append("ant")
	var out: Array = []
	for kind in kinds:
		var spot := Vector2.ZERO
		for _try in 30:
			spot = Vector2(rng.randf_range(-room.x * 0.4, room.x * 0.4), rng.randf_range(-room.z * 0.4, room.z * 0.4))
			var clear := spot.distance_to(pads[0]["at"]) > 6.0
			for pad in pads:
				if _rect(pad).grow(1.2).has_point(spot):
					clear = false
			if clear:
				break
		out.append({"type": kind, "at": spot})
	return out


static func _portals(number: int, pads: Array[Dictionary]) -> Array:
	if number < 16 or pads.size() < 6:
		return []
	var a: Dictionary = pads[2]
	var b: Dictionary = pads[pads.size() - 3]
	if a.has("move") or b.has("move"):
		return []
	return [
		{"at": _corner(a), "to": _center(b)},
		{"at": _corner(b), "to": _center(a)},
	]


static func _corner(entry: Dictionary) -> Vector3:
	var at: Vector2 = entry["at"]
	var size: Vector2 = entry["size"]
	return Vector3(at.x + size.x * 0.32, float(entry["top"]), at.y + size.y * 0.32)


static func _center(entry: Dictionary) -> Vector3:
	var at: Vector2 = entry["at"]
	return Vector3(at.x, float(entry["top"]), at.y)


static func _problem(data: Dictionary) -> String:
	var room: Vector3 = data["room"]
	var pads: Array = data["platforms"]
	if pads.size() < 8:
		return "too few platforms"
	for i in pads.size():
		var pad: Dictionary = pads[i]
		var top: float = pad["top"]
		if top < 1.1 or top > 1.4:
			return "height"
		if not _inside(pad["at"], pad["size"], room):
			return "outside"
		for j in range(i + 1, pads.size()):
			if _rect(pad).grow(-0.05).intersects(_rect(pads[j])):
				return "overlap"
		if i == 0:
			continue
		var gap := _edge_gap(_rect(pads[i - 1]), _rect(pad))
		if gap < 0.9 or gap > 3.0:
			return "gap %.2f" % gap
	return ""


static func _edge_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()
