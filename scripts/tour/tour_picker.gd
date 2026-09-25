class_name TourPicker
extends Node3D
## The Big Picker: a human-sized range tractor (enormous to a rat) with a caged
## cab and a gang of spinning picker reels out front. Built from simple lit
## shapes so it reads as a real 3D machine at 480×270.

const SCALE := 2.6 ## yards; it's a big old machine and he's a very small rat
const REEL_COUNT := 5

var reels: Array[MeshInstance3D] = []
var wheels: Array[MeshInstance3D] = []
var _spin := 0.0


func _ready() -> void:
	var body_mat := _mat(Color("3f8f4e"))
	var body_dark := _mat(Color("2c6a3a"))
	var cage_mat := _mat(Color("c8ced2"))
	var tire_mat := _mat(Color("26262c"))
	var seat_mat := _mat(Color("e8d6b0"))
	var reel_mat := _mat(Color("f2c440"))
	var disc_mat := _mat(Color("383840"))
	var s := SCALE
	## Chassis + hood.
	_box(Vector3(1.4, 0.45, 2.2) * s, Vector3(0, 0.55, 0.2) * s, body_mat)
	_box(Vector3(1.2, 0.35, 0.9) * s, Vector3(0, 0.95, -0.55) * s, body_dark)
	_box(Vector3(0.5, 0.2, 0.4) * s, Vector3(0, 0.95, 0.5) * s, seat_mat)
	## Cage: four posts and a roof grid.
	for x in [-0.62, 0.62]:
		for z in [-0.1, 1.05]:
			_box(Vector3(0.06, 1.3, 0.06) * s, Vector3(x, 1.4, z) * s, cage_mat)
	_box(Vector3(1.36, 0.06, 1.25) * s, Vector3(0, 2.05, 0.47) * s, cage_mat)
	for i in 5:
		_box(Vector3(0.04, 0.9, 0.04) * s, Vector3(-0.62 + i * 0.31, 1.45, -0.1) * s, cage_mat)
	## Hopper basket behind.
	_box(Vector3(1.3, 0.5, 0.6) * s, Vector3(0, 0.9, 1.45) * s, cage_mat)
	## Wheels.
	for x in [-0.78, 0.78]:
		for z in [-0.45, 0.95]:
			var w := _cyl(0.38 * s, 0.26 * s, Vector3(x, 0.38, z) * s, tire_mat)
			w.rotation.z = PI * 0.5
			wheels.append(w)
	## Picker frame + gang of reels out front.
	_box(Vector3(3.4, 0.08, 0.08) * s, Vector3(0, 0.75, -1.2) * s, body_dark)
	for i in REEL_COUNT:
		var x := (float(i) - (REEL_COUNT - 1) * 0.5) * 0.66
		var r := _cyl(0.3 * s, 0.5 * s, Vector3(x, 0.3, -1.55) * s, reel_mat)
		r.rotation.z = PI * 0.5
		reels.append(r)
		for k in 3:
			var d := _cyl(0.31 * s, 0.05 * s, Vector3(0, (k - 1) * 0.16 * s, 0), disc_mat)
			r.add_child(d)
		_box(Vector3(0.05, 0.45, 0.05) * s, Vector3(x, 0.55, -1.35) * s, body_dark)


func spin(speed: float, delta: float) -> void:
	_spin += speed * delta
	for r in reels:
		r.rotation.x = _spin * 2.2
	for w in wheels:
		w.rotation.x = _spin


## World width of the reel gang (what it can pick up in one pass).
static func reach_width() -> float:
	return 3.4 * SCALE


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


func _cyl(radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 12
	mi.mesh = c
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi
