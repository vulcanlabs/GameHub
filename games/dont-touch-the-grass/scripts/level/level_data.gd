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
# Jump peaks about 1.50 m. Start/finish stay climbable from the grass. Mid pads can sit higher.
# Each level picks a route shape: straight, zigzag, U, snake, switchback, stairs.
# Some mid pads slide. Some vanish if you stand on them.
extends RefCounted

const TOTAL_LEVELS := 50
const MIN_TOP := 1.32
const STEP := 5.2
const INSET := 5.2

# Levels 2 to 50 are built from a fixed seed, so a level is the same every time and different from its neighbours.
static var _cache: Dictionary = {}


static func has_level(number: int) -> bool:
	return number >= 1 and number <= TOTAL_LEVELS


static func get_level(number: int) -> Dictionary:
	if number <= 1:
		number = 1
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


static func _shape(number: int) -> String:
	var kinds: Array[String] = ["straight", "zag", "u", "snake", "switchback", "stairs"]
	return kinds[(number - 1) % kinds.size()]


static func _attempt(number: int, rng: RandomNumberGenerator) -> Dictionary:
	var band := _band(number)
	var shape := _shape(number)
	var count := 20
	var min_size := 2.7
	var top_hi := 1.72
	if band == "mid":
		min_size = 2.65
		top_hi = 1.95
	elif band == "spider":
		min_size = 2.6
		top_hi = 2.15
		count = 22
	elif band == "hard":
		min_size = 2.55
		top_hi = 2.35
		count = 22
	var room := _room_for(shape, count)
	var spots := _scatter(_route(shape, count, room, rng), room, rng)
	var pads: Array[Dictionary] = []
	for i in spots.size():
		var size := Vector2(3.8, 3.8) if i == 0 or i == spots.size() - 1 else Vector2(
			rng.randf_range(min_size, min_size + 0.2),
			rng.randf_range(min_size, min_size + 0.2)
		)
		var top := MIN_TOP
		if i > 0 and i < spots.size() - 1:
			if shape == "stairs":
				var t := float(i) / float(spots.size() - 1)
				top = MIN_TOP + (1.0 - absf(t * 2.0 - 1.0)) * (top_hi - MIN_TOP)
			else:
				top = rng.randf_range(MIN_TOP, top_hi)
		var entry := {
			"at": spots[i],
			"size": size,
			"top": top,
		}
		if number >= 8 and i > 2 and i < spots.size() - 3 and i % 6 == 3 and not entry.has("vanish"):
			var slide_axis := "z" if shape == "straight" or i % 2 == 0 else "x"
			var reach := 0.85
			var offset := Vector2(0.0, reach) if slide_axis == "z" else Vector2(reach, 0.0)
			if _inside(spots[i] + offset, size, room) and _inside(spots[i] - offset, size, room):
				entry["move"] = {"axis": slide_axis, "distance": reach, "seconds": rng.randf_range(3.0, 4.5)}
		if number >= 4 and i > 2 and i < spots.size() - 3 and i % 5 == 2 and not entry.has("move"):
			entry["vanish"] = {"stand": 1.5, "gone": 2.8}
		pads.append(entry)
	var data := {
		"room": room,
		"platforms": pads,
		"walls": _side_walls(shape, room, pads, rng),
		"lintels": [],
		"columns": _side_columns(shape, room, pads, rng),
		"lights": _lights(rng, room),
		"enemies": _enemies(number, rng, room, pads),
		"portals": [],
	}
	return data


static func _room_for(shape: String, count: int) -> Vector3:
	if shape == "straight":
		return Vector3(float(count - 1) * STEP + INSET * 2.0, 6.5, 26.0)
	if shape == "u":
		var arm := maxi(6, count / 3 + 1)
		return Vector3(float(arm) * STEP + INSET * 2.0, 6.5, float(arm) * STEP + INSET * 2.0)
	if shape == "snake":
		var cols := ceili(float(count) / 3.0)
		return Vector3(float(cols - 1) * STEP + INSET * 2.0, 6.5, 2.0 * STEP + INSET * 2.0)
	if shape == "switchback":
		var cols_s := ceili(float(count) / 4.0)
		return Vector3(float(cols_s - 1) * STEP + INSET * 2.0, 6.5, 3.0 * STEP + INSET * 2.0)
	return Vector3(float(count - 1) * STEP * 0.88 + INSET * 2.0, 6.5, 32.0)


static func _route(shape: String, count: int, room: Vector3, rng: RandomNumberGenerator) -> Array[Vector2]:
	if shape == "straight":
		return _line(count, room, 0.0)
	if shape == "u":
		return _u(count, room)
	if shape == "snake":
		return _rows(count, room, 3)
	if shape == "switchback":
		return _rows(count, room, 4)
	return _zag(count, room, rng)


# Keep the route, knock pads off the ruler line so each jump is a real aim.
static func _scatter(spots: Array[Vector2], room: Vector3, rng: RandomNumberGenerator) -> Array[Vector2]:
	if spots.size() < 3:
		return spots
	var out: Array[Vector2] = spots.duplicate()
	for i in range(1, spots.size() - 1):
		var along := out[i + 1] - out[i - 1] if i + 1 < out.size() else out[i] - out[i - 1]
		if along.length() < 0.2:
			along = Vector2(1.0, 0.0)
		along = along.normalized()
		var perp := Vector2(-along.y, along.x)
		var cand := out[i] + perp * rng.randf_range(-1.55, 1.55) + along * rng.randf_range(-0.15, 0.35)
		if not _inside(cand, Vector2(2.8, 2.8), room):
			continue
		var prev_gap := _edge_gap(Rect2(out[i - 1] - Vector2(1.35, 1.35), Vector2(2.7, 2.7)), Rect2(cand - Vector2(1.35, 1.35), Vector2(2.7, 2.7)))
		if prev_gap < 1.25 or prev_gap > 2.72:
			continue
		out[i] = cand
	return out


static func _line(count: int, room: Vector3, z: float) -> Array[Vector2]:
	var left := -room.x * 0.5 + INSET
	var right := room.x * 0.5 - INSET
	var out: Array[Vector2] = []
	for i in count:
		var t := 0.0 if count == 1 else float(i) / float(count - 1)
		out.append(Vector2(lerpf(left, right, t), z))
	return out


static func _zag(count: int, room: Vector3, rng: RandomNumberGenerator) -> Array[Vector2]:
	var left := -room.x * 0.5 + INSET
	var right := room.x * 0.5 - INSET
	var north := -room.z * 0.5 + INSET + 2.0
	var south := room.z * 0.5 - INSET - 2.0
	var mid := rng.randf_range(north * 0.25, south * 0.25)
	var out: Array[Vector2] = []
	for i in count:
		var t := 0.0 if count == 1 else float(i) / float(count - 1)
		var z := mid + (1.23 if i % 2 == 0 else -1.23)
		out.append(Vector2(lerpf(left, right, t), clampf(z, north, south)))
	return out


static func _u(count: int, room: Vector3) -> Array[Vector2]:
	var left := -room.x * 0.5 + INSET
	var north := -room.z * 0.5 + INSET
	var east := count / 3
	var south := maxi(3, (count - east) / 2)
	var out: Array[Vector2] = []
	var at := Vector2(left, north)
	out.append(at)
	for _i in east:
		at += Vector2(STEP, 0.0)
		out.append(at)
		if out.size() >= count:
			return out
	for _i in south:
		at += Vector2(0.0, STEP)
		out.append(at)
		if out.size() >= count:
			return out
	while out.size() < count:
		at += Vector2(-STEP, 0.0)
		out.append(at)
	return out


static func _rows(count: int, room: Vector3, rows: int) -> Array[Vector2]:
	var left := -room.x * 0.5 + INSET
	var right := room.x * 0.5 - INSET
	var north := -room.z * 0.5 + INSET
	var south := room.z * 0.5 - INSET
	var cols := ceili(float(count) / float(rows))
	var out: Array[Vector2] = []
	var n := 0
	for r in rows:
		var zt := 0.0 if rows == 1 else float(r) / float(rows - 1)
		var z := lerpf(north, south, zt)
		var east := r % 2 == 0
		for c in cols:
			if n >= count:
				break
			var xt := 0.0 if cols == 1 else float(c) / float(cols - 1)
			if not east:
				xt = 1.0 - xt
			out.append(Vector2(lerpf(left, right, xt), z))
			n += 1
	return out


static func _along(legs: Array[Vector2], lens: Array[float], dist: float) -> Vector2:
	for i in lens.size():
		if dist <= lens[i]:
			var t := 0.0 if lens[i] < 0.001 else dist / lens[i]
			return legs[i].lerp(legs[i + 1], t)
		dist -= lens[i]
	return legs[legs.size() - 1]


static func _side_walls(shape: String, room: Vector3, pads: Array[Dictionary], rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var want := 3 if shape == "straight" else 5
	for _try in want * 10:
		if out.size() >= want:
			break
		var item := Rect2(rng.randf_range(-room.x * 0.35, room.x * 0.35), rng.randf_range(-room.z * 0.35, room.z * 0.35), 0.4, rng.randf_range(2.4, 5.5))
		if not _blocks_route(item, pads):
			out.append(item)
	return out


static func _side_columns(shape: String, room: Vector3, pads: Array[Dictionary], rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var want := 4 if shape == "straight" else 7
	for _try in want * 10:
		if out.size() >= want:
			break
		var c := Vector2(rng.randf_range(-room.x * 0.4, room.x * 0.4), rng.randf_range(-room.z * 0.4, room.z * 0.4))
		if not _blocks_route(Rect2(c - Vector2(0.6, 0.6), Vector2(1.2, 1.2)), pads):
			out.append(c)
	return out


static func _fallback(number: int) -> Dictionary:
	var shape := _shape(number)
	var room := _room_for(shape, 20)
	var rng := RandomNumberGenerator.new()
	rng.seed = number * 13
	var spots := _scatter(_route(shape, 20, room, rng), room, rng)
	var pads: Array[Dictionary] = []
	for i in spots.size():
		pads.append({
			"at": spots[i],
			"size": Vector2(3.8, 3.8) if i == 0 or i == spots.size() - 1 else Vector2(2.7, 2.7),
			"top": MIN_TOP if i == 0 or i == spots.size() - 1 else MIN_TOP + float(i % 3) * 0.22,
		})
	var enemies: Array = [{"type": "ant", "at": Vector2(0.0, 8.0)}]
	if number >= 25:
		enemies.push_front({"type": "spider", "at": Vector2(4.0, -8.0)})
	return {
		"room": room,
		"platforms": pads,
		"walls": [],
		"lintels": [],
		"columns": [],
		"lights": _lights(RandomNumberGenerator.new(), room),
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
	var want := 4 if walls else 6
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


static func _problem(data: Dictionary) -> String:
	var room: Vector3 = data["room"]
	var pads: Array = data["platforms"]
	if pads.size() < 16:
		return "too few platforms"
	for i in pads.size():
		var pad: Dictionary = pads[i]
		var top: float = pad["top"]
		if top < 1.28 or top > 2.6:
			return "height"
		if not _inside(pad["at"], pad["size"], room):
			return "outside"
		for j in range(i + 1, pads.size()):
			if _rect(pad).grow(-0.05).intersects(_rect(pads[j])):
				return "overlap"
		if i == 0:
			continue
		var gap := _edge_gap(_rect(pads[i - 1]), _rect(pad))
		if gap < 1.15 or gap > 2.85:
			return "gap %.2f" % gap
	return ""


static func _edge_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()
