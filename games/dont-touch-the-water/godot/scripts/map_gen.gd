extends RefCounted

const PLATFORM_COUNT := 90
const CHECKPOINT_EVERY := 5
const GAPS := [
	{"gmin": 2.9, "gmax": 4.3, "wmin": 3.4},
	{"gmin": 4.0, "gmax": 5.6, "wmin": 2.9},
	{"gmin": 5.0, "gmax": 6.7, "wmin": 2.4},
	{"gmin": 6.0, "gmax": 8.0, "wmin": 2.0},
]

static func build(parent: Node, diff_i: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "Course"
	parent.add_child(root)
	var gap: Dictionary = GAPS[clampi(diff_i, 0, GAPS.size() - 1)]
	var plats: Array = []
	var cps: Array = []
	var tile := _mat(Color("e4ece6"))
	var gold := _mat(Color("ffd36b"))
	gold.emission_enabled = true
	gold.emission = Color("4a3a00")
	var wall := _mat(Color("6d6458"))
	var x := 0.0
	var z := 0.0
	var pw := 5.0
	var heading := PI
	for i in PLATFORM_COUNT + 1:
		var w := 5.0 if i == 0 else float(gap.wmin) + randf() * 1.1
		var cp := i % CHECKPOINT_EVERY == 0
		if i > 0:
			heading += (randf() - 0.5) * 0.55
			heading = clampf(heading, PI - 1.1, PI + 1.1)
			var step := pw / 2.0 + float(gap.gmin) + randf() * (float(gap.gmax) - float(gap.gmin)) + w / 2.0
			x += sin(heading) * step
			z += cos(heading) * step
			x = clampf(x, -40.0, 40.0)
		var top := 1.0 + float(i % 4) * 0.12
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(w, 5.0, w)
		mesh.mesh = box
		mesh.material_override = gold if cp else tile
		mesh.position = Vector3(x, top - 2.5, z)
		root.add_child(mesh)
		var cpi := -1
		if cp:
			cpi = cps.size()
			cps.append(plats.size())
			var beacon := MeshInstance3D.new()
			var pole := CylinderMesh.new()
			pole.top_radius = 0.06
			pole.bottom_radius = 0.06
			pole.height = 4.0
			beacon.mesh = pole
			beacon.material_override = _mat(Color("ffe27a"), true)
			beacon.position = Vector3(x, top + 2.0, z)
			root.add_child(beacon)
		plats.append({"x": x, "z": z, "h": w / 2.0, "top": top, "cpi": cpi})
		pw = w
	for i in 70:
		var s := 1.5 + randf() * 1.5
		var pillar := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(s, 19.0, s)
		pillar.mesh = pb
		pillar.material_override = wall
		var along: Dictionary = plats[randi() % plats.size()]
		var side := -1.0 if randf() < 0.5 else 1.0
		pillar.position = Vector3(
			float(along.x) + side * (10.0 + randf() * 22.0),
			5.5,
			float(along.z) + (randf() - 0.5) * 8.0
		)
		root.add_child(pillar)
	return {"root": root, "plats": plats, "cps": cps}


static func _mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
