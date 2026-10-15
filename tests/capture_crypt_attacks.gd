extends TestKit
## Close-up sheets of the cemetery's foes attacking (Skeleton.SWIPE_SIGHT, Wraith.DART_RANGE), world
## 28's first cemetery level, laid out COLUMNS across: a skeleton standing, winding up (its near arm
## raised, leaning back, its sockets burning), swiping (the arm sweeping down with a pink smear) and
## resting, in skeleton_swipe.png; a wraith hunting, swelling (its hem flaring, its eyes burning),
## darting (stretched along its way) and hanging after, in wraith_dart.png.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_crypt_attacks.gd

const COLUMNS: int = 4
## The still's size (px) and the camera's zoom against the game's own.
const SHOT: Vector2i = Vector2i(420, 300)
const ZOOM: float = 2.0
## How much further back the camera is for the wraith.
const WRAITH_BACK: float = 1.35

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"cemetery"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	camera.zoom *= ZOOM
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	var at: Vector2i = _run(3)
	await skeleton(at)
	await wraith(at)
	finish()


func skeleton(at: Vector2i) -> void:
	player.global_position = Vector2(-9000, -9000)
	var node: Node2D = (load("res://prefabs/skeleton_enemy.tscn") as PackedScene).instantiate() as Node2D
	var bones: Skeleton = node.get_node("Skeleton") as Skeleton
	bones.asleep = false
	LevelLoader.arm(node, info.here.depth)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(at)
	var middle: Vector2 = node.global_position + Vector2(50, -40)
	look(middle)
	await until(func() -> bool: return info.loader.is_awake(node))
	await frames(20)
	player.end_invulnerable()
	player.global_position = node.global_position + Vector2(100, -15)
	await frames(2)
	var shots: Array[Image] = [shot()]
	for want: float in [0.3, 0.65, 0.97]:
		await within(func() -> bool: return bones.winding >= want or bones.swiping >= 0.0, 1.0)
		await process_frame
		shots.append(shot())
	for want: float in [0.25, 0.55, 0.85]:
		await within(func() -> bool: return bones.swiping >= want or bones.resting > 0.0, 1.0)
		await process_frame
		shots.append(shot())
	await frames(10)
	shots.append(shot())
	save_still("skeleton_swipe.png", sheet(shots))
	node.queue_free()
	await until(gone(node))


func wraith(at: Vector2i) -> void:
	player.global_position = Vector2(-9000, -9000)
	var node: Node2D = (load("res://prefabs/wraith_enemy.tscn") as PackedScene).instantiate() as Node2D
	LevelLoader.arm(node, info.here.depth)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(at) + Vector2(60, -60)
	var ghost: Wraith = node.get_node("Wraith") as Wraith
	# Pulled back a little: swollen, it is big.
	camera.zoom /= WRAITH_BACK
	var middle: Vector2 = node.global_position + Vector2(100, -10)
	look(middle)
	await until(func() -> bool: return info.loader.is_awake(node))
	player.end_invulnerable()
	player.global_position = node.global_position + Vector2(240, 50)
	info.snuff(player.global_position)
	await frames(2)
	var shots: Array[Image] = [shot()]
	for want: float in [0.35, 0.7, 0.97]:
		await within(func() -> bool: return ghost.swelling >= want or ghost.darting >= 0.0, 1.5)
		await process_frame
		shots.append(shot())
	for want: float in [0.1, 0.3, 0.6]:
		await within(func() -> bool: return ghost.darting >= want or ghost.darting < 0.0, 1.0)
		await process_frame
		shots.append(shot())
	await frames(8)
	shots.append(shot())
	save_still("wraith_dart.png", sheet(shots))
	info.relight()


func look(at: Vector2) -> void:
	# Unclamped by the level's edges, so what is looked at is in the middle of the still.
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	camera.global_position = at
	camera.reset_smoothing()


## The middle SHOT of the window as drawn now.
func shot() -> Image:
	var whole: Image = root.get_texture().get_image()
	return whole.get_region(Rect2i((whole.get_size() - SHOT) / 2, SHOT))


## `shots` laid out COLUMNS across.
func sheet(shots: Array[Image]) -> Image:
	var rows: int = ceili(float(shots.size()) / float(COLUMNS))
	var out: Image = Image.create(SHOT.x * COLUMNS, SHOT.y * rows, false, shots[0].get_format())
	for k: int in range(shots.size()):
		out.blit_rect(shots[k], Rect2i(Vector2i.ZERO, SHOT), Vector2i((k % COLUMNS) * SHOT.x, (k / COLUMNS) * SHOT.y))
	return out


## A floor cell with `n` more open floor cells to its right in a row (open over them too).
func _run(n: int) -> Vector2i:
	var w: LevelGen = info.world
	for v: Vector2i in w.free_floors():
		var ok: bool = true
		for k: int in range(n + 1):
			var c: Vector2i = v + Vector2i(k, 0)
			if not w.is_valid(c) or w.is_ground(c) or not w.ground_below(c) or w.is_ground(c + Vector2i.UP):
				ok = false
				break
		if ok:
			return v
	return Vector2i(-1, -1)
