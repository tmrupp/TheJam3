extends TestKit
## A sheet of a wraith darting each way (WraithArt: stretched along its way, its shroud streaming
## back), world 28's first cemetery level: a row a way (down, down and across, across, up), at the
## start of the dart, a third in and two thirds in, in wraith_dive.png. For checking the shroud
## stays whole however fast it goes and whichever way.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_wraith_dive.gd

## The ways it darts, and how far into the dart (Wraith.darting) each column is.
const WAYS: Array[Vector2] = [Vector2(0, 1), Vector2(0.7071, 0.7071), Vector2(1, 0), Vector2(0, -1)]
const STAGES: Array[float] = [0.0, 0.33, 0.66]
## The still's size (px) and the camera's zoom against the game's own.
const SHOT: Vector2i = Vector2i(360, 360)
const ZOOM: float = 1.6


func run() -> void:
	window()
	await boot()
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"cemetery"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	camera.zoom *= ZOOM
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	player.global_position = Vector2(-9000, -9000)
	var at: Vector2 = info.cell_position(_open_air())
	var node: Node2D = (load("res://prefabs/wraith_enemy.tscn") as PackedScene).instantiate() as Node2D
	LevelLoader.arm(node, info.here.depth)
	info.map_elements.add_child(node)
	node.global_position = at
	var ghost: Wraith = node.get_node("Wraith") as Wraith
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	camera.global_position = at + Vector2(0, -30)
	camera.reset_smoothing()
	await until(func() -> bool: return info.loader.is_awake(node))
	await frames(10)
	# Posed by hand: the wraith's own steps would move it on.
	ghost.set_physics_process(false)
	ghost.awake = true
	var shots: Array[Image] = []
	for way: Vector2 in WAYS:
		for stage: float in STAGES:
			ghost.darting = stage
			ghost.velocity = way * Wraith.DART_SPEED * (1.0 - stage)
			ghost.facing = signf(way.x) if way.x != 0.0 else 1.0
			await frames(4)
			var whole: Image = root.get_texture().get_image()
			shots.append(whole.get_region(Rect2i((whole.get_size() - SHOT) / 2, SHOT)))
	var out: Image = Image.create(SHOT.x * STAGES.size(), SHOT.y * WAYS.size(), false, shots[0].get_format())
	for k: int in range(shots.size()):
		@warning_ignore("integer_division")
		out.blit_rect(shots[k], Rect2i(Vector2i.ZERO, SHOT), Vector2i((k % STAGES.size()) * SHOT.x, (k / STAGES.size()) * SHOT.y))
	save_still("wraith_dive.png", out)
	finish()


## An open cell with open air two cells all round it, so nothing but the wraith is in the still.
func _open_air() -> Vector2i:
	var w: LevelGen = info.world
	for v: Vector2i in w.empties:
		var ok: bool = true
		for dx: int in range(-2, 3):
			for dy: int in range(-2, 3):
				var c: Vector2i = v + Vector2i(dx, dy)
				ok = ok and w.is_valid(c) and not w.is_ground(c)
		if ok:
			return v
	return Vector2i(5, 5)
