extends TestKit
## A close-up sheet of a wisp lurching at the wizard (Mover.LURCH_SIGHT, WispArt), world 28's first
## level: walking, then its wind-up (the head rearing, the glow flaring, the body shivering), the
## lurch and the rest after, laid out COLUMNS across in wisp_lurch.png; and the wizard's feather
## popping as it fills again (RisoCostume.RECHARGE_TIME), in feather_pop.png.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_wisp_lurch.gd

const COLUMNS: int = 4
## The still's size (px) and the camera's zoom against the game's own.
const SHOT: Vector2i = Vector2i(600, 300)
const ZOOM: float = 2.0
## The feather's stills: their size, zoom, and how many physics steps apart.
const FEATHER_SHOT: Vector2i = Vector2i(240, 240)
const FEATHER_ZOOM: float = 3.5
const FEATHER_EVERY: int = 3

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	var base: Vector2 = camera.zoom
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	player.end_invulnerable()
	player.global_position = Vector2(-9000, -9000)
	for other: Node in placed("mover_enemy.tscn").slice(1):
		other.queue_free()
	await process_frame
	var w: Node2D = placed("mover_enemy.tscn")[0] as Node2D
	var mover: Mover = w.get_node("Mover") as Mover
	var spot: Vector2i = Vector2i(-1, -1)
	for v: Vector2i in info.world.free_floors():
		var ok: bool = true
		for k: int in range(4):
			var c: Vector2i = v + Vector2i.RIGHT * k
			ok = ok and info.world.is_valid(c) and info.world.ground_below(c) and info.world.get_cell(c).type not in [LevelGen.Type.GROUND, LevelGen.Type.CRACKED, LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.SPIKES, LevelGen.Type.PLATFORM, LevelGen.Type.LASER]
		if ok:
			spot = v
			break
	camera.zoom = base * ZOOM
	mover.set_physics_process(false)
	w.global_position = info.cell_position(spot)
	var middle: Vector2 = w.global_position + Vector2(110, -40)
	look(middle)
	await until(func() -> bool: return info.loader.is_awake(w))
	await frames(2)
	if mover.direction != 1:
		mover.turn()
	mover.turn_left = 0.0
	mover.lurch_wait = 0.0
	mover.set_physics_process(true)
	for i: int in range(40):
		look(middle)
		await physics_frame
	var shots: Array[Image] = []
	shots.append(shot(SHOT))
	player.global_position = w.global_position + Vector2(190, -15)
	# The wind-up, at a quarter, half, three quarters and nearly done; the lurch; the rest.
	for want: float in [0.25, 0.5, 0.75, 0.97]:
		await within(func() -> bool: return mover.winding >= want or mover.lurching >= 0.0, 1.0)
		await process_frame
		shots.append(shot(SHOT))
	for want: float in [0.15, 0.4]:
		await within(func() -> bool: return mover.lurching >= want or mover.resting > 0.0, 1.0)
		await process_frame
		shots.append(shot(SHOT))
	await within(func() -> bool: return mover.resting > 0.0, 1.0)
	await frames(8)
	shots.append(shot(SHOT))
	save_still("wisp_lurch.png", sheet(shots, SHOT))

	# The feather filling again, the wizard standing still.
	player.global_position = info.respawn_marker.global_position
	player.set_physics_process(true)
	await until(func() -> bool: return player.is_on_floor())
	player.set_physics_process(false)
	camera.zoom = base * FEATHER_ZOOM
	var hat: Vector2 = player.global_position + Vector2(-10, -80)
	look(hat)
	player.dash.acted = true
	await frames(10)
	var pops: Array[Image] = [shot(FEATHER_SHOT)]
	player.dash.acted = false
	for i: int in range(7):
		await frames(FEATHER_EVERY)
		look(hat)
		pops.append(shot(FEATHER_SHOT))
	save_still("feather_pop.png", sheet(pops, FEATHER_SHOT))
	finish()


func look(at: Vector2) -> void:
	camera.global_position = at
	camera.reset_smoothing()


## The middle `size` of the window as drawn now.
func shot(size: Vector2i) -> Image:
	var whole: Image = root.get_texture().get_image()
	return whole.get_region(Rect2i((whole.get_size() - size) / 2, size))


## `shots` laid out COLUMNS across.
func sheet(shots: Array[Image], size: Vector2i) -> Image:
	var rows: int = ceili(float(shots.size()) / float(COLUMNS))
	var out: Image = Image.create(size.x * COLUMNS, size.y * rows, false, shots[0].get_format())
	for k: int in range(shots.size()):
		out.blit_rect(shots[k], Rect2i(Vector2i.ZERO, size), Vector2i((k % COLUMNS) * size.x, (k / COLUMNS) * size.y))
	return out
