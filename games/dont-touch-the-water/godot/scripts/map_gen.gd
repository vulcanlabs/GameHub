extends RefCounted

const LEVEL_COUNT := 8
const GAPS := [
	{"gmin": 2.9, "gmax": 4.3, "wmin": 3.4},
	{"gmin": 4.0, "gmax": 5.6, "wmin": 2.9},
	{"gmin": 5.0, "gmax": 6.7, "wmin": 2.4},
	{"gmin": 6.0, "gmax": 8.0, "wmin": 2.0},
]

static func build(parent: Node, diff_i: int, level_i: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "Course"
	parent.add_child(root)
	var level := clampi(level_i, 0, LEVEL_COUNT - 1)
	var jumps := 12 + level * 2
	var gap: Dictionary = GAPS[clampi(diff_i, 0, GAPS.size() - 1)]
	var tile := _pool_tile(Color("9c9478"))
	var goal_mat := _pool_tile(Color("7f8c68"), Color("24301a"))
	var slide_mat := _pool_tile(Color("6d8a82"))
	var wall := _pool_tile(Color("6e6856"))
	var plats: Array = []
	var hazards: Array = []
	var x := 0.0
	var z := 0.0
	var pw := 5.0
	var heading := PI
	var slides_left := 1 + level / 2
	var spins_left := 1 + level / 2
	for i in jumps + 1:
		var w := 6.4 if i == 0 else float(gap.wmin) + 1.4 + randf() * 1.1
		var prev_x := x
		var prev_z := z
		if i > 0:
			heading += (randf() - 0.5) * 0.45
			heading = clampf(heading, PI - 1.1, PI + 1.1)
			var step := pw / 2.0 + float(gap.gmin) + randf() * (float(gap.gmax) - float(gap.gmin)) + w / 2.0
			x += sin(heading) * step
			z += cos(heading) * step
			x = clampf(x, -80.0, 80.0)
		var goal := i == jumps
		var slide := i > 1 and i < jumps and slides_left > 0 and i % 3 == 0
		if slide:
			slides_left -= 1
		var top := 1.15 + float(i % 3) * 0.18
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(w, 5.0, w)
		mesh.mesh = box
		mesh.material_override = goal_mat if goal else (slide_mat if slide else tile)
		mesh.position = Vector3(x, top - 2.5, z)
		root.add_child(mesh)
		var across := Vector2(cos(heading), -sin(heading))
		if across.length() < 0.001:
			across = Vector2.RIGHT
		across = across.normalized()
		var plat := {
			"x": x,
			"z": z,
			"ox": x,
			"oz": z,
			"h": w / 2.0,
			"top": top,
			"top0": top,
			"goal": goal,
			"mesh": mesh,
			"slide_amp": 0.85 if slide else 0.0,
			"slide_speed": 1.3 + randf() * 0.6,
			"phase": randf() * TAU,
			"axis_x": across.x,
			"axis_z": across.y,
		}
		plats.append(plat)
		pw = w
		if i > 0 and spins_left > 0 and i % 2 == 0:
			spins_left -= 1
			var mid := Vector3((prev_x + x) * 0.5, 1.25, (prev_z + z) * 0.5)
			var spin := Node3D.new()
			spin.position = mid
			root.add_child(spin)
			var arm := MeshInstance3D.new()
			var bar := BoxMesh.new()
			var reach := maxf(2.2, Vector2(x - prev_x, z - prev_z).length() * 0.42)
			bar.size = Vector3(reach * 2.0, 0.28, 0.28)
			arm.mesh = bar
			var sm := _mat(Color("7a2e2e"))
			sm.emission_enabled = true
			sm.emission = Color("3a1010")
			sm.emission_energy_multiplier = 0.6
			arm.material_override = sm
			spin.add_child(arm)
			var hub := MeshInstance3D.new()
			var ball := SphereMesh.new()
			ball.radius = 0.35
			ball.height = 0.7
			hub.mesh = ball
			hub.material_override = sm
			spin.add_child(hub)
			hazards.append({
				"node": spin,
				"reach": reach,
				"speed": 1.6 + float(level) * 0.18,
			})
	for i in 40:
		var s := 0.9 + randf() * 0.7
		var pillar := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(s, 4.5, s)
		pillar.mesh = pb
		pillar.material_override = wall
		var along: Dictionary = plats[randi() % plats.size()]
		var side := -1.0 if randf() < 0.5 else 1.0
		pillar.position = Vector3(
			float(along.x) + side * (12.0 + randf() * 22.0),
			2.15,
			float(along.z) + (randf() - 0.5) * 16.0
		)
		root.add_child(pillar)
	return {"root": root, "plats": plats, "hazards": hazards}


static func _pool_tile(color: Color, glow: Color = Color(0, 0, 0)) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nuniform vec4 albedo : source_color;\nuniform vec4 glow : source_color;\nvoid fragment() {\n\tvec2 uv = UV * 4.0;\n\tvec2 g = abs(fract(uv) - 0.5);\n\tfloat seam = step(0.46, max(g.x, g.y));\n\tfloat stain = 0.9 + 0.1 * sin(UV.x * 18.0 + UV.y * 11.0);\n\tvec3 tile = albedo.rgb * stain;\n\tALBEDO = mix(tile, tile * 0.45, seam);\n\tROUGHNESS = 0.72;\n\tEMISSION = glow.rgb;\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("glow", glow)
	return mat


static func _mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
