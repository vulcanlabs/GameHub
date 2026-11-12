class_name BallManager
extends Node3D
## Every ball in one level: where it is, whether it is still there, and how it is drawn.
##
## There are no physics bodies. The floor is divided into a hexagonal grid of columns, 12.5 cm apart, and each
## column holds a stack of balls. The whole registry is one byte per column: its height. A ball is identified
## by (column, layer), and its exact position and colour are derived from that with a hash, so nothing else
## has to be stored and a save file only needs the heights.
##
## Three rules make the stacks behave like a pile of balls:
##   1. Balls only leave from the top of a column, so nothing is ever left floating.
##   2. A column 2 or more balls taller than a neighbour sheds a ball onto it (a sandpile). Digging into a
##      mound makes the sides slide in. A few hundred columns are checked per physics tick, so a collapse
##      plays out over several frames instead of stalling one.
##   3. Only the top SHELL layers of a column are drawn. Rule 2 keeps neighbours within one ball of each
##      other, so deeper balls are hidden behind the ones on top. They are still counted and still become
##      visible as the pile is dug out. Nothing is dropped from the count to save frame time.
##
## Drawing uses one MultiMesh per 32 x 32 block of columns (4 m x 3.5 m), with the sphere detail picked by
## distance from the viewer.

const BALL_RADIUS := 0.085
const SPACING := 0.125                      # distance between columns in a row (m)
const ROW := SPACING * 0.8660254            # distance between rows (m)
const LAYER_HEIGHT := 0.12                  # rise per layer. Balls are 17 cm across and sit snug in the 12.5 cm grid
const JITTER := 0.03                        # how far a ball may sit off its lattice point, side to side (m)
const SHELL := 3                            # layers drawn per column, counted from the top
const MAX_LAYERS := 48                      # tallest column, about 5.8 m. Stays under the 7 m ceiling
const SLOPE := 2                            # height difference at which a ball rolls to the lower column
const CHUNK := 32                           # columns along one side of a draw block
const CHUNK_CAPACITY := CHUNK * CHUNK * SHELL
const SETTLE_BUDGET := 400                  # columns checked for sliding per physics tick
const SUCTION_RADIUS_NEAR := 0.75           # width of the area cleared right at the nozzle (m)
const SUCTION_RADIUS_FAR := 1.6             # width at full reach (m)
const NO_TARGET := Vector3(INF, INF, INF)

const PALETTE := [Color("#F06B68"), Color("#6BA3F0"), Color("#F7E07A"), Color("#7ED99A"), Color("#F5A35C")]

## Sphere detail by distance: [radial segments, rings].
const LOD_SHAPES := [[16, 8], [10, 5], [6, 3]]
## Per graphics quality (low, medium, high, ultra): where full detail ends, where medium detail ends,
## and how far away balls still cast shadows (m).
const LOD_NEAR := [5.0, 8.0, 11.0, 16.0]
const LOD_MID := [12.0, 20.0, 28.0, 45.0]
const SHADOW_RANGE := [0.0, 10.0, 22.0, 60.0]

# The six neighbours of a column as (column step, row step). Odd rows sit half a column to the right.
const NEIGHBOURS_EVEN: PackedInt32Array = [-1, 0, 1, 0, -1, -1, 0, -1, -1, 1, 0, 1]
const NEIGHBOURS_ODD: PackedInt32Array = [-1, 0, 1, 0, 0, -1, 1, -1, 0, 1, 1, 1]


class Chunk:
	var multimesh: MultiMesh
	var node: MultiMeshInstance3D
	var first_column := 0
	var first_row := 0
	var count := 0
	var keys := PackedInt32Array()          # draw slot -> packed (column, layer)
	var slot_of := {}                       # packed (column, layer) -> draw slot
	var lod := -1
	var centre := Vector2.ZERO


var level_index := 0
var columns := 0
var rows := 0
## The camera. Sets which blocks get full sphere detail.
var viewer: Node3D

var _origin := Vector2.ZERO                 # world x, z of the grid corner
var _floor_y := 0.0
var _height := PackedByteArray()
var _blocked := PackedByteArray()
var _count := 0
var _chunk_columns := 0
var _chunk_rows := 0
var _chunks: Array[Chunk] = []
var _queue := PackedInt32Array()
var _queued := PackedByteArray()
var _visual := true
var _meshes: Array[SphereMesh] = []
var _material: Material = preload("res://assets/materials/ball_plastic.tres")
var _disc_even := PackedInt32Array()        # (column step, row step, distance in mm), nearest first
var _disc_odd := PackedInt32Array()
var _lod_wait := 0.0


func _ready() -> void:
	for shape: Array in LOD_SHAPES:
		var mesh := SphereMesh.new()
		mesh.radius = BALL_RADIUS
		mesh.height = BALL_RADIUS * 2.0
		mesh.radial_segments = shape[0]
		mesh.rings = shape[1]
		mesh.material = _material
		_meshes.append(mesh)
	_disc_even = _build_disc(0)
	_disc_odd = _build_disc(1)
	Settings.changed.connect(_on_setting_changed)


## Lays the grid over `bounds` (x, z in metres) at floor height `floor_y`.
## Columns whose centre is inside one of `blocked` (pit, pillars, furniture) never hold a ball.
func setup(level: int, bounds: Rect2, floor_y: float, blocked: Array[Rect2]) -> void:
	level_index = level
	_origin = bounds.position
	_floor_y = floor_y
	columns = int(bounds.size.x / SPACING) - 1   # the last column is given up to the half-column shift
	rows = int(bounds.size.y / ROW)
	_height.resize(columns * rows)
	_blocked.resize(columns * rows)
	_queued.resize(columns * rows)
	_height.fill(0)
	_blocked.fill(0)
	_queued.fill(0)
	for j in rows:
		for i in columns:
			var at := column_centre(i, j)
			for rect in blocked:
				if rect.has_point(at):
					_blocked[j * columns + i] = 1
					break
	_chunk_columns = ceili(float(columns) / CHUNK)
	_chunk_rows = ceili(float(rows) / CHUNK)
	for chunk in _chunks:
		if chunk != null:
			chunk.node.queue_free()
	_chunks.clear()
	_chunks.resize(_chunk_columns * _chunk_rows)
	_count = 0


## Fills the level with exactly `total` balls: mounds first, loose patches for the rest.
## Each pile is Vector4(x, z, peak height in layers, radius in metres). The same seed gives the same layout.
func populate(total: int, piles: Array[Vector4], rng_seed: int) -> void:
	_wipe()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_visual = false
	var placed := 0
	for pile in piles:
		placed += _raise_mound(Vector2(pile.x, pile.y), pile.z, pile.w, rng, total - placed)
	placed += _scatter(total - placed, rng)
	placed += _top_up(total - placed)
	if placed != total:
		push_error("Level %d has room for only %d of %d balls" % [level_index + 1, placed, total])
	# Let the mounds slump to a stable slope before anything is drawn.
	for c in _height.size():
		if _height[c] > 0:
			_enqueue_neighbours(c % columns, c / columns)
	_settle(1 << 40)
	_visual = true
	for c in _height.size():
		var h := _height[c]
		for layer in range(maxi(0, h - SHELL), h):
			_show(c % columns, c / columns, layer)
	_count = placed
	_lod_wait = 0.0
	GameState.set_level_remaining(level_index, _count)


## Removes every ball from the level and reports the level as empty.
func clear_all() -> void:
	_wipe()
	GameState.set_level_remaining(level_index, 0)


func _wipe() -> void:
	_height.fill(0)
	_queued.fill(0)
	_queue.clear()
	for chunk in _chunks:
		if chunk != null:
			chunk.count = 0
			chunk.slot_of.clear()
			chunk.multimesh.visible_instance_count = 0
	_count = 0


func count() -> int:
	return _count


func settling() -> bool:
	return not _queue.is_empty()


func _physics_process(delta: float) -> void:
	if not _queue.is_empty():
		_settle(SETTLE_BUDGET)
	_lod_wait -= delta
	if _lod_wait <= 0.0:
		_lod_wait = 0.25
		_update_detail()


# ---------------------------------------------------------------- suction

## Removes up to `max_take` balls from around the point the vacuum is aimed at, nearest first.
## The position and colour of each removed ball are appended to the two arrays, so the caller can animate it.
func suck(origin: Vector3, direction: Vector3, reach: float, max_take: int,
		out_positions: PackedVector3Array, out_colors: PackedColorArray) -> int:
	if max_take <= 0 or _count == 0:
		return 0
	var target := aim_point(origin, direction, reach)
	if target == NO_TARGET:
		return 0
	var radius := lerpf(SUCTION_RADIUS_NEAR, SUCTION_RADIUS_FAR, clampf(origin.distance_to(target) / reach, 0.0, 1.0))
	var radius_mm := int(radius * 1000.0)
	var centre_row := clampi(floori((target.z - _origin.y) / ROW), 0, rows - 1)
	var centre_column := clampi(floori((target.x - _origin.x) / SPACING - 0.5 * (centre_row & 1)), 0, columns - 1)
	var disc := _disc_odd if centre_row & 1 else _disc_even
	var taken := 0
	# One pass clears the top ball of each column in the mouth. Further passes take the next
	# layer down when that mouth does not hold enough balls for this tick.
	for _pass in 6:
		var got := 0
		for k in range(0, disc.size(), 3):
			if disc[k + 2] > radius_mm:
				break
			var i := centre_column + disc[k]
			var j := centre_row + disc[k + 1]
			if i < 0 or j < 0 or i >= columns or j >= rows:
				continue
			var c := j * columns + i
			var h := _height[c]
			if h == 0:
				continue
			out_positions.append(ball_position(i, j, h - 1))
			out_colors.append(ball_color(i, j, h - 1))
			_take_top(i, j, c)
			_enqueue(c)
			taken += 1
			got += 1
			if taken >= max_take:
				break
		if got == 0 or taken >= max_take:
			break
	if taken > 0:
		_count -= taken
		GameState.set_level_remaining(level_index, _count)
	return taken


## Where the suction lands: the first ball surface or floor the aim line meets within `reach`.
## Aiming flat, or at a wall or pillar, falls back to the floor below the furthest clear point.
## Returns NO_TARGET when aiming well above the horizon.
func aim_point(origin: Vector3, direction: Vector3, reach: float) -> Vector3:
	var last := origin
	var t := 0.3
	while t <= reach:
		var p := origin + direction * t
		var c := column_at(p.x, p.z)
		if c < 0 or _blocked[c] == 1:
			break
		if p.y <= surface_height(c):
			return p
		last = p
		t += 0.15
	if direction.y > 0.4:
		return NO_TARGET
	return Vector3(last.x, _floor_y, last.z)


# ---------------------------------------------------------------- the grid

## The column containing world point (x, z), or -1 outside the level.
func column_at(x: float, z: float) -> int:
	var j := floori((z - _origin.y) / ROW)
	if j < 0 or j >= rows:
		return -1
	var i := floori((x - _origin.x) / SPACING - 0.5 * (j & 1))
	if i < 0 or i >= columns:
		return -1
	return j * columns + i


func column_centre(i: int, j: int) -> Vector2:
	return Vector2(_origin.x + (i + 0.5 + 0.5 * (j & 1)) * SPACING, _origin.y + (j + 0.5) * ROW)


func column_height(c: int) -> int:
	return _height[c]


func is_blocked(c: int) -> bool:
	return _blocked[c] == 1


## Top of the balls in a column, or the floor when it is empty (world y).
func surface_height(c: int) -> float:
	var h := _height[c]
	if h == 0:
		return _floor_y
	return _floor_y + (h - 1) * LAYER_HEIGHT + BALL_RADIUS * 2.0


## Centre of the ball at `layer` of column (i, j). Odd layers sit in the hollows of the layer below.
func ball_position(i: int, j: int, layer: int) -> Vector3:
	var bits := _hash(i, j, layer)
	var odd := layer & 1
	return Vector3(
		_origin.x + (i + 0.5 + 0.5 * (j & 1) + 0.5 * odd) * SPACING + ((bits & 255) / 255.0 - 0.5) * JITTER,
		_floor_y + BALL_RADIUS + layer * LAYER_HEIGHT + (((bits >> 16) & 15) / 15.0 - 0.5) * 0.014,
		_origin.y + (j + 0.5) * ROW + odd * SPACING * 0.2886751 + (((bits >> 8) & 255) / 255.0 - 0.5) * JITTER)


## One of the five ball colours, shifted slightly lighter or darker so no two neighbours match exactly.
func ball_color(i: int, j: int, layer: int) -> Color:
	var bits := _hash(i, j, layer)
	var base: Color = PALETTE[(bits >> 20) % PALETTE.size()]
	var shade := ((bits >> 24) & 127) / 127.0 * 2.0 - 1.0
	return base.lightened(shade * 0.07) if shade > 0.0 else base.darkened(-shade * 0.09)


func _hash(i: int, j: int, layer: int) -> int:
	var n := ((i * 73856093) ^ (j * 19349663) ^ (layer * 83492791)) & 0x7FFFFFFF
	n = ((n ^ (n >> 15)) * 2246822519) & 0x7FFFFFFF
	n = ((n ^ (n >> 13)) * 3266489917) & 0x7FFFFFFF
	return n ^ (n >> 16)


# ---------------------------------------------------------------- filling

func _raise_mound(centre: Vector2, peak: float, radius: float, rng: RandomNumberGenerator, budget: int) -> int:
	var added := 0
	var j0 := maxi(floori((centre.y - radius - _origin.y) / ROW), 0)
	var j1 := mini(ceili((centre.y + radius - _origin.y) / ROW), rows - 1)
	var i0 := maxi(floori((centre.x - radius - _origin.x) / SPACING) - 1, 0)
	var i1 := mini(ceili((centre.x + radius - _origin.x) / SPACING), columns - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var c := j * columns + i
			if _blocked[c] == 1:
				continue
			var d := column_centre(i, j).distance_to(centre)
			if d >= radius:
				continue
			# The random part dithers the edge so the mound does not end in a clean circle.
			var want := mini(int(peak * (1.0 - d / radius) + rng.randf()), MAX_LAYERS)
			var gain := mini(want - _height[c], budget - added)
			if gain > 0:
				_height[c] += gain
				added += gain
	return added


# One ball on random free columns, so they lie as a thin carpet instead of heaps.
func _scatter(wanted: int, rng: RandomNumberGenerator) -> int:
	if wanted <= 0:
		return 0
	var free: Array[int] = []
	for c in _height.size():
		if _blocked[c] == 0 and _height[c] == 0:
			free.append(c)
	for n in range(free.size() - 1, 0, -1):
		var other := rng.randi_range(0, n)
		var held := free[n]
		free[n] = free[other]
		free[other] = held
	var placed := mini(wanted, free.size())
	for n in placed:
		_height[free[n]] = 1
	return placed


# Last resort when the patches could not hold everything: one more ball on every free column, in order.
func _top_up(wanted: int) -> int:
	var placed := 0
	while placed < wanted:
		var before := placed
		for c in _height.size():
			if placed >= wanted:
				break
			if _blocked[c] == 0 and _height[c] < MAX_LAYERS:
				_height[c] += 1
				placed += 1
		if placed == before:
			break
	return placed


# ---------------------------------------------------------------- sliding

func _enqueue(c: int) -> void:
	if _queued[c] == 0 and _blocked[c] == 0:
		_queued[c] = 1
		_queue.append(c)


func _enqueue_neighbours(i: int, j: int) -> void:
	var steps := NEIGHBOURS_ODD if j & 1 else NEIGHBOURS_EVEN
	for k in range(0, 12, 2):
		var ni := i + steps[k]
		var nj := j + steps[k + 1]
		if ni >= 0 and nj >= 0 and ni < columns and nj < rows:
			_enqueue(nj * columns + ni)


# Each queued column pulls one ball from a neighbour that stands SLOPE or more above it.
func _settle(budget: int) -> void:
	while budget > 0 and not _queue.is_empty():
		var last := _queue.size() - 1
		var c := _queue[last]
		_queue.remove_at(last)
		_queued[c] = 0
		budget -= 1
		var i := c % columns
		var j := c / columns
		var h := _height[c]
		var steps := NEIGHBOURS_ODD if j & 1 else NEIGHBOURS_EVEN
		var first := (c * 7 + h) % 6            # vary which side feeds first, so piles slump evenly
		for k in 6:
			var s := ((k + first) % 6) * 2
			var ni := i + steps[s]
			var nj := j + steps[s + 1]
			if ni < 0 or nj < 0 or ni >= columns or nj >= rows:
				continue
			var n := nj * columns + ni
			if _height[n] >= h + SLOPE:
				_take_top(ni, nj, n)
				_put_top(i, j, c)
				_enqueue(n)                     # it lost a ball and may now pull from its own neighbours
				_enqueue_neighbours(i, j)       # this column grew and may now stand above one of them
				_enqueue(c)
				break


func _take_top(i: int, j: int, c: int) -> void:
	var h := _height[c]
	_height[c] = h - 1
	if _visual:
		_hide(i, j, h - 1)
		if h - 1 - SHELL >= 0:
			_show(i, j, h - 1 - SHELL)


func _put_top(i: int, j: int, c: int) -> void:
	var h := _height[c]
	_height[c] = h + 1
	if _visual:
		_show(i, j, h)
		if h - SHELL >= 0:
			_hide(i, j, h - SHELL)


# ---------------------------------------------------------------- drawing

func _chunk_for(i: int, j: int) -> Chunk:
	var index := (j / CHUNK) * _chunk_columns + (i / CHUNK)
	var chunk := _chunks[index]
	if chunk != null:
		return chunk
	chunk = Chunk.new()
	chunk.first_column = (i / CHUNK) * CHUNK
	chunk.first_row = (j / CHUNK) * CHUNK
	chunk.keys.resize(CHUNK_CAPACITY)
	var corner := Vector3(_origin.x + chunk.first_column * SPACING, _floor_y, _origin.y + chunk.first_row * ROW)
	var size := Vector3((CHUNK + 1.5) * SPACING, MAX_LAYERS * LAYER_HEIGHT + 0.2, (CHUNK + 1.0) * ROW)
	chunk.centre = Vector2(corner.x + size.x * 0.5, corner.z + size.z * 0.5)
	chunk.multimesh = MultiMesh.new()
	chunk.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	chunk.multimesh.use_colors = true
	chunk.multimesh.mesh = _meshes[1]
	chunk.multimesh.instance_count = CHUNK_CAPACITY
	chunk.multimesh.visible_instance_count = 0
	chunk.multimesh.custom_aabb = AABB(corner - Vector3(0.1, 0.0, 0.1), size + Vector3(0.2, 0.0, 0.2))
	chunk.node = MultiMeshInstance3D.new()
	chunk.node.multimesh = chunk.multimesh
	chunk.node.layers = 2                   # render layer "Balls": left out of the baked reflection
	add_child(chunk.node)
	_chunks[index] = chunk
	return chunk


func _key(chunk: Chunk, i: int, j: int, layer: int) -> int:
	return (((j - chunk.first_row) * CHUNK + (i - chunk.first_column)) << 6) | layer


func _show(i: int, j: int, layer: int) -> void:
	var chunk := _chunk_for(i, j)
	var slot := chunk.count
	var key := _key(chunk, i, j, layer)
	chunk.multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY, ball_position(i, j, layer)))
	chunk.multimesh.set_instance_color(slot, ball_color(i, j, layer))
	chunk.keys[slot] = key
	chunk.slot_of[key] = slot
	chunk.count = slot + 1
	chunk.multimesh.visible_instance_count = chunk.count


# Removes one drawn ball by moving the last drawn ball of the block into its slot.
func _hide(i: int, j: int, layer: int) -> void:
	var chunk := _chunk_for(i, j)
	var key := _key(chunk, i, j, layer)
	var slot: int = chunk.slot_of[key]
	var last := chunk.count - 1
	if slot != last:
		var moved := chunk.keys[last]
		var moved_layer := moved & 63
		var moved_i := chunk.first_column + ((moved >> 6) % CHUNK)
		var moved_j := chunk.first_row + ((moved >> 6) / CHUNK)
		chunk.multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY, ball_position(moved_i, moved_j, moved_layer)))
		chunk.multimesh.set_instance_color(slot, ball_color(moved_i, moved_j, moved_layer))
		chunk.keys[slot] = moved
		chunk.slot_of[moved] = slot
	chunk.slot_of.erase(key)
	chunk.count = last
	chunk.multimesh.visible_instance_count = last


func _update_detail() -> void:
	var quality: int = Settings.get_value("graphics", "quality")
	var shadows_on: bool = Settings.get_value("graphics", "shadows") != Settings.Shadows.OFF
	var eye := Vector2.ZERO
	if viewer != null:
		eye = Vector2(viewer.global_position.x, viewer.global_position.z)
	for chunk in _chunks:
		if chunk == null:
			continue
		# Every change here makes the lights over the chunk redraw their shadows, so only real changes are sent.
		if chunk.node.visible != (chunk.count > 0):
			chunk.node.visible = chunk.count > 0
		if chunk.count == 0:
			continue
		var distance := eye.distance_to(chunk.centre)
		var lod := 0 if distance < LOD_NEAR[quality] else (1 if distance < LOD_MID[quality] else 2)
		if lod != chunk.lod:
			chunk.lod = lod
			chunk.multimesh.mesh = _meshes[lod]
		var cast: bool = shadows_on and distance < SHADOW_RANGE[quality]
		var setting := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if chunk.node.cast_shadow != setting:
			chunk.node.cast_shadow = setting


func _on_setting_changed(section: String, _key_name: String) -> void:
	if section == "graphics":
		_lod_wait = 0.0


# Column steps inside the widest suction area, nearest first, for a centre on an even (0) or odd (1) row.
func _build_disc(parity: int) -> PackedInt32Array:
	var reach := ceili(SUCTION_RADIUS_FAR / ROW) + 1
	var found: Array[Vector3i] = []
	for dj in range(-reach, reach + 1):
		for di in range(-reach, reach + 1):
			var dx := (di + 0.5 * ((parity + dj) & 1) - 0.5 * parity) * SPACING
			var dz := dj * ROW
			var mm := int(sqrt(dx * dx + dz * dz) * 1000.0)
			if mm <= int(SUCTION_RADIUS_FAR * 1000.0):
				found.append(Vector3i(di, dj, mm))
	found.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.z < b.z)
	var packed := PackedInt32Array()
	for step in found:
		packed.append(step.x)
		packed.append(step.y)
		packed.append(step.z)
	return packed


# ---------------------------------------------------------------- checks (used by the automatic test)

## Empty string when the registry is consistent, otherwise what is wrong.
func validate() -> String:
	var total := 0
	var drawn := 0
	for c in _height.size():
		var h := _height[c]
		total += h
		drawn += mini(h, SHELL)
		if h > 0 and _blocked[c] == 1:
			return "column %d is blocked but holds %d balls" % [c, h]
	if total != _count:
		return "heights add up to %d, counter says %d" % [total, _count]
	var instances := 0
	for chunk in _chunks:
		if chunk != null:
			instances += chunk.count
			if chunk.count != chunk.slot_of.size():
				return "a block draws %d balls but indexes %d" % [chunk.count, chunk.slot_of.size()]
	if instances != drawn:
		return "%d balls drawn, expected %d" % [instances, drawn]
	return ""


## Largest height difference between two neighbouring free columns. At rest this is below SLOPE.
func steepest_step() -> int:
	var worst := 0
	for j in rows:
		var steps := NEIGHBOURS_ODD if j & 1 else NEIGHBOURS_EVEN
		for i in columns:
			var c := j * columns + i
			if _blocked[c] == 1:
				continue
			for k in range(0, 12, 2):
				var ni := i + steps[k]
				var nj := j + steps[k + 1]
				if ni < 0 or nj < 0 or ni >= columns or nj >= rows:
					continue
				var n := nj * columns + ni
				if _blocked[n] == 0:
					worst = maxi(worst, _height[n] - _height[c])
	return worst


## A fingerprint of where every ball is. Two layouts are the same exactly when this matches.
func layout_hash() -> int:
	return hash(_height)


func drawn_count() -> int:
	var instances := 0
	for chunk in _chunks:
		if chunk != null:
			instances += chunk.count
	return instances
