class_name KidDrawings
extends RefCounted
## Crayon pictures for the playroom walls. Drawn in code so they look like a child made them:
## wobbly lines, too much pressure, and a few that are wrong in a quiet way.


static func sheet(kind: int) -> ImageTexture:
	var image := Image.create(512, 384, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.93, 0.89, 0.8, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000 + kind
	_paper_grain(image, rng)
	match kind % 8:
		0:
			_sun(image, Vector2(400, 70), 48.0, Color(0.95, 0.72, 0.12), rng)
			_house(image, Vector2(80, 210), rng)
			_stick(image, Vector2(300, 250), 70.0, Color(0.15, 0.18, 0.4), false, rng)
			_stick(image, Vector2(360, 255), 52.0, Color(0.7, 0.2, 0.25), false, rng)
		1:
			_scribble(image, Vector2(250, 190), 140.0, Color(0.2, 0.45, 0.75), rng, 40)
			_stick(image, Vector2(140, 240), 90.0, Color(0.12, 0.12, 0.12), true, rng)
			_caption(image, "MY FREND", Vector2i(40, 340), Color(0.2, 0.15, 0.1))
		2:
			_sun(image, Vector2(90, 70), 40.0, Color(0.9, 0.55, 0.1), rng)
			_flower(image, Vector2(240, 260), rng)
			_flower(image, Vector2(340, 250), rng)
			_stick(image, Vector2(430, 230), 80.0, Color(0.35, 0.1, 0.12), true, rng)
		3:
			_house(image, Vector2(160, 180), rng)
			_scribble(image, Vector2(380, 160), 90.0, Color(0.05, 0.05, 0.06), rng, 55)
			_caption(image, "DONT LOOK", Vector2i(30, 40), Color(0.45, 0.08, 0.08))
		4:
			_stick(image, Vector2(180, 220), 100.0, Color(0.18, 0.16, 0.14), false, rng)
			_stick(image, Vector2(280, 225), 95.0, Color(0.18, 0.16, 0.14), true, rng)
			_stick(image, Vector2(380, 210), 130.0, Color(0.08, 0.08, 0.1), true, rng)
			_caption(image, "FAMILY", Vector2i(40, 340), Color(0.25, 0.2, 0.12))
		5:
			_ball_pit(image, rng)
			_caption(image, "BALLS", Vector2i(180, 40), Color(0.8, 0.15, 0.2))
		6:
			_scribble(image, Vector2(256, 200), 170.0, Color(0.55, 0.05, 0.08), rng, 70)
			_eye(image, Vector2(200, 160), 28.0, rng)
			_eye(image, Vector2(300, 155), 34.0, rng)
			_eye(image, Vector2(255, 230), 18.0, rng)
		_:
			_caption(image, "I LIVE HERE", Vector2i(60, 80), Color(0.12, 0.12, 0.14))
			_stick(image, Vector2(250, 250), 60.0, Color(0.1, 0.1, 0.12), false, rng)
			_scribble(image, Vector2(400, 300), 80.0, Color(0.05, 0.05, 0.05), rng, 30)
	var tex := ImageTexture.create_from_image(image)
	return tex


static func _paper_grain(image: Image, rng: RandomNumberGenerator) -> void:
	for i in 1800:
		var x := rng.randi_range(0, 511)
		var y := rng.randi_range(0, 383)
		var c := image.get_pixel(x, y)
		c = c.darkened(rng.randf() * 0.04)
		image.set_pixel(x, y, c)


static func _dot(image: Image, at: Vector2, radius: float, color: Color) -> void:
	var r := int(radius)
	var cx := int(at.x)
	var cy := int(at.y)
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x < 0 or y < 0 or x >= 512 or y >= 384:
				continue
			if Vector2(x - cx, y - cy).length() <= radius:
				image.set_pixel(x, y, color)


static func _stroke(image: Image, a: Vector2, b: Vector2, color: Color, width: float, rng: RandomNumberGenerator) -> void:
	var steps := maxi(int(a.distance_to(b)), 2)
	for n in steps:
		var t := float(n) / steps
		var p := a.lerp(b, t) + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2))
		_dot(image, p, width * (0.7 + rng.randf() * 0.5), color)


static func _stick(image: Image, feet: Vector2, height: float, color: Color, extra_limb: bool, rng: RandomNumberGenerator) -> void:
	var head := feet + Vector2(rng.randf_range(-6, 6), -height)
	_dot(image, head, height * 0.12, color)
	if extra_limb:
		_dot(image, head + Vector2(height * 0.1, 0.0), height * 0.07, color)
	_stroke(image, head, feet + Vector2(0, -height * 0.15), color, 3.2, rng)
	_stroke(image, head + Vector2(0, height * 0.28), feet + Vector2(-height * 0.22, -height * 0.45), color, 2.6, rng)
	_stroke(image, head + Vector2(0, height * 0.28), feet + Vector2(height * 0.24, -height * 0.42), color, 2.6, rng)
	if extra_limb:
		_stroke(image, head + Vector2(0, height * 0.2), feet + Vector2(height * 0.05, -height * 0.9), color, 2.2, rng)
	_stroke(image, feet + Vector2(0, -height * 0.15), feet + Vector2(-height * 0.12, 4), color, 2.8, rng)
	_stroke(image, feet + Vector2(0, -height * 0.15), feet + Vector2(height * 0.14, 4), color, 2.8, rng)


static func _house(image: Image, at: Vector2, rng: RandomNumberGenerator) -> void:
	var c := Color(0.25, 0.22, 0.35)
	_stroke(image, at, at + Vector2(140, 8), c, 3.0, rng)
	_stroke(image, at, at + Vector2(8, 110), c, 3.0, rng)
	_stroke(image, at + Vector2(140, 0), at + Vector2(132, 118), c, 3.0, rng)
	_stroke(image, at + Vector2(0, 110), at + Vector2(140, 118), c, 3.0, rng)
	_stroke(image, at + Vector2(-10, 8), at + Vector2(70, -70), c, 3.2, rng)
	_stroke(image, at + Vector2(150, 8), at + Vector2(70, -70), c, 3.2, rng)
	_stroke(image, at + Vector2(55, 118), at + Vector2(55, 50), c, 2.4, rng)
	_stroke(image, at + Vector2(55, 50), at + Vector2(90, 50), c, 2.4, rng)
	_stroke(image, at + Vector2(90, 50), at + Vector2(90, 118), c, 2.4, rng)
	_dot(image, at + Vector2(30, 40), 8.0, Color(0.15, 0.12, 0.1))


static func _sun(image: Image, at: Vector2, radius: float, color: Color, rng: RandomNumberGenerator) -> void:
	_dot(image, at, radius * 0.45, color)
	for n in 10:
		var a := TAU * n / 10.0 + rng.randf() * 0.2
		_stroke(image, at + Vector2.from_angle(a) * radius * 0.5, at + Vector2.from_angle(a) * radius, color, 2.2, rng)


static func _flower(image: Image, at: Vector2, rng: RandomNumberGenerator) -> void:
	var stem := Color(0.2, 0.45, 0.18)
	_stroke(image, at, at + Vector2(4, 90), stem, 2.4, rng)
	for n in 6:
		var a := TAU * n / 6.0
		_dot(image, at + Vector2.from_angle(a) * 22.0, 10.0, Color(0.85, 0.25, 0.4))
	_dot(image, at, 8.0, Color(0.95, 0.85, 0.2))


static func _scribble(image: Image, at: Vector2, radius: float, color: Color, rng: RandomNumberGenerator, strokes: int) -> void:
	for n in strokes:
		var a := at + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius * 0.7, radius * 0.7))
		var b := at + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius * 0.7, radius * 0.7))
		_stroke(image, a, b, color, rng.randf_range(1.5, 4.0), rng)


static func _eye(image: Image, at: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	_dot(image, at, radius, Color(0.95, 0.95, 0.92))
	_dot(image, at + Vector2(rng.randf_range(-3, 3), 2), radius * 0.45, Color(0.08, 0.08, 0.1))


static func _ball_pit(image: Image, rng: RandomNumberGenerator) -> void:
	_stroke(image, Vector2(80, 280), Vector2(430, 280), Color(0.7, 0.15, 0.18), 4.0, rng)
	_stroke(image, Vector2(80, 280), Vector2(80, 200), Color(0.7, 0.15, 0.18), 3.0, rng)
	_stroke(image, Vector2(430, 280), Vector2(430, 200), Color(0.7, 0.15, 0.18), 3.0, rng)
	for n in 40:
		var c: Color = [Color(0.9, 0.2, 0.2), Color(0.2, 0.45, 0.9), Color(0.95, 0.8, 0.15), Color(0.25, 0.75, 0.35)][n % 4]
		_dot(image, Vector2(rng.randf_range(100, 410), rng.randf_range(160, 270)), rng.randf_range(8, 16), c)


static func _caption(image: Image, text: String, at: Vector2i, color: Color) -> void:
	# Block letters so we do not need a font on the Image.
	var glyphs := {
		"A": ["010", "101", "111", "101", "101"],
		"B": ["110", "101", "110", "101", "110"],
		"D": ["110", "101", "101", "101", "110"],
		"E": ["111", "100", "110", "100", "111"],
		"F": ["111", "100", "110", "100", "100"],
		"H": ["101", "101", "111", "101", "101"],
		"I": ["111", "010", "010", "010", "111"],
		"K": ["101", "101", "110", "101", "101"],
		"L": ["100", "100", "100", "100", "111"],
		"M": ["101", "111", "111", "101", "101"],
		"N": ["110", "101", "101", "101", "101"],
		"O": ["010", "101", "101", "101", "010"],
		"R": ["110", "101", "110", "101", "101"],
		"S": ["011", "100", "010", "001", "110"],
		"T": ["111", "010", "010", "010", "010"],
		"V": ["101", "101", "101", "101", "010"],
		"Y": ["101", "101", "010", "010", "010"],
		" ": ["000", "000", "000", "000", "000"],
	}
	var cursor := at
	for ch in text:
		var rows: Array = glyphs.get(ch, glyphs[" "])
		for j in rows.size():
			var row: String = rows[j]
			for i in row.length():
				if row[i] == "1":
					for dy in 4:
						for dx in 4:
							var x := cursor.x + i * 5 + dx
							var y := cursor.y + j * 6 + dy
							if x >= 0 and y >= 0 and x < 512 and y < 384:
								image.set_pixel(x, y, color)
		cursor.x += 18
