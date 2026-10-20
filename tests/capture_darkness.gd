extends TestKit
## Stills of the cemetery's darkness (docs/DEEPER_PLAN.md, "Darkness charges"), in a level with an
## ossuary door: on a terrace, a sun block and a shade block, a font full and one run dry, with the
## flame lit and snuffed (darkness_terrace_lit.png, darkness_terrace_dark.png), the blocks and the
## fonts close up (darkness_blocks_lit.png, darkness_blocks_dark.png, darkness_fonts.png); the lantern carried
## with its beads of darkness (darkness_lantern.png) and the sitting card's count
## (darkness_card.png); a crypt's stairs turned to blocks, lit and snuffed (darkness_stairs_lit.png,
## darkness_stairs_dark.png); a shade floor over thorns (darkness_floor_lit.png,
## darkness_floor_dark.png); the flame's light and a flare (darkness_flare_off.png,
## darkness_flare_on.png); an ossuary door part fed, close up built each way
## (darkness_ossuary_0.png .. _2.png), and opened (darkness_ossuary.png, darkness_ossuary_open.png); and the level's map (darkness_map.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_darkness.gd

var camera: Camera2D
## Where the camera is held, and how far it is zoomed against the game's own zoom.
var hold: Vector2 = Vector2.ZERO
var zoom: float = 1.0
var base_zoom: Vector2 = Vector2.ONE
## A flare kept burning while set (the camera holds it at its height).
var flaring: bool = false


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	base_zoom = camera.zoom
	var at: Vector2i = Vector2i(5, NextWorldDef.band_row(&"cemetery", 4))
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.get_node("CameraControl").set_process(false)
	await _wait(5.0)
	for scene: String in ["skeleton_enemy.tscn", "moths.tscn", "wraith_enemy.tscn", "sleep_fog.tscn"]:
		for n: Node in placed(scene, true):
			n.queue_free()
	await _terrace()
	await _stairs()
	await _floor()
	await _ossuary()
	await _map()
	RunState.delete_save()
	finish()


## On a terrace: a sun block, a shade block, a full font and a dry one, the wizard among them.
func _terrace() -> void:
	var a: Vector2i = _run(5)
	var dry_font: Vector2i = a + Vector2i(4, 0)
	_stage("res://prefabs/phase_block.tscn", a, true)
	_stage("res://prefabs/phase_block.tscn", a + Vector2i(1, 0), false)
	_stage("res://prefabs/snuffer.tscn", a + Vector2i(3, 0), null)
	_stage("res://prefabs/snuffer.tscn", dry_font, null)
	info.record().fonts[dry_font] = 0
	info.run.dark_charges = 4
	player.global_position = info.cell_position(a + Vector2i(2, 0))
	player.set_physics_process(true)
	var mid: Vector2 = info.cell_position(a + Vector2i(2, 0)) + Vector2(0, -60)
	await _look(mid, 1.2, "darkness_terrace_lit.png")
	await _look(player.global_position + Vector2(0, -50), 3.0, "darkness_lantern.png")
	await _look(info.cell_position(a + Vector2i(1, 0)) + Vector2(64, -40), 2.2, "darkness_blocks_lit.png")
	await _look(info.cell_position(a + Vector2i(3, 0)) + Vector2(64, -40), 3.0, "darkness_fonts.png")
	info.snuff(player.global_position)
	await _look(mid, 1.2, "darkness_terrace_dark.png", 1.5)
	await _look(info.cell_position(a + Vector2i(1, 0)) + Vector2(64, -40), 2.2, "darkness_blocks_dark.png")
	info.relight()
	Input.action_press(&"Down")
	await _look(player.global_position + Vector2(0, -120), 2.0, "darkness_card.png", 2.0)
	Input.action_release(&"Down")


## A crypt's stairs turned to blocks, the wizard at their foot, lit and snuffed; then the flame's
## light there, and a flare.
func _stairs() -> void:
	var best: Array[Vector2i] = []
	for crypt: Dictionary in info.world.crypts:
		var steps: Array[Vector2i] = []
		for s: Vector2i in crypt["stairs"]:
			if info.world.get_cell(s).type == LevelGen.Type.PHASE_BLOCK:
				steps.append(s)
		if steps.size() > best.size():
			best = steps
	if best.is_empty():
		return
	best.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)
	# On the step halfway up, the camera on them.
	var on: Vector2i = best[best.size() / 2]
	player.global_position = info.cell_position(on + Vector2i.UP)
	info.loader.wake_around(player.global_position)
	var mid: Vector2 = info.cell_position(on) + Vector2(0, -40)
	await _look(mid, 1.5, "darkness_stairs_lit.png", 1.5)
	info.snuff(player.global_position)
	await _look(mid, 1.5, "darkness_stairs_dark.png", 1.5)
	info.relight()
	await _look(mid, 1.0, "darkness_flare_off.png", 1.0)
	flaring = true
	await _look(mid, 1.0, "darkness_flare_on.png", 1.0)
	flaring = false


## A shade floor over thorns, lit (the blocks a ghost, the wizard among the thorns) and snuffed.
func _floor() -> void:
	var w: LevelGen = info.world
	for v: Vector2i in w.objects_of(LevelGen.Type.PHASE_BLOCK):
		if bool(w.get_cell(v).extra_info) or w.get_cell(v + Vector2i.DOWN).type != LevelGen.Type.SPIKES:
			continue
		player.global_position = info.cell_position(v + Vector2i(-1, 0))
		info.loader.wake_around(player.global_position)
		await _look(info.cell_position(v), 1.4, "darkness_floor_lit.png", 1.5)
		info.snuff(player.global_position)
		await _look(info.cell_position(v), 1.4, "darkness_floor_dark.png", 1.5)
		info.relight()
		return


## An ossuary door from outside, part fed, then fed its fill and sunk open.
func _ossuary() -> void:
	var doors: Array[Node] = placed("ossuary_door.tscn")
	if doors.is_empty():
		return
	var door: OssuaryDoor = doors[0] as OssuaryDoor
	var out: int = -1 if info.world.get_cell(door.cell + Vector2i.LEFT).type == LevelGen.Type.EMPTY and not info.world.interiors.has(door.cell + Vector2i.LEFT) else 1
	player.global_position = door.global_position + Vector2(out * 150, 0)
	info.loader.wake_around(player.global_position)
	info.run.dark_charges = door.fill / 2
	door.pour()
	await _look(door.global_position + Vector2(out * 60, -40), 1.8, "darkness_ossuary.png", 1.0)
	var dealt: OssuaryDoor.Style = door.style
	for style: int in range(OssuaryDoor.STYLES):
		door.style = style as OssuaryDoor.Style
		await _look(door.global_position + Vector2(0, -30), 3.2, "darkness_ossuary_%d.png" % style, 0.5)
	door.style = dealt
	info.run.dark_charges = door.fill
	door.pour()
	await _look(door.global_position + Vector2(out * 60, -40), 1.8, "darkness_ossuary_open.png", 2.0)


## The level's map, all of it inked.
func _map() -> void:
	info.ink_whole_map()
	var map: Node = main.get_node("RisoMap")
	map.call("toggle")
	await _wait(1.0)
	save_still("darkness_map.png")
	map.call("toggle")


## A prefab set at cell `v` as the loader would place it, set up with `extra` (null for two).
func _stage(scene: String, v: Vector2i, extra: Variant) -> Node2D:
	var node: Node2D = (load(scene) as PackedScene).instantiate() as Node2D
	node.set_meta(&"cell", v)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(v)
	if extra == null:
		node.call("setup", info, v)
	else:
		node.call("setup", info, v, extra)
	return node


## Hold the camera on `at` at `z` times the game's zoom for `seconds`, then save `file`.
func _look(at: Vector2, z: float, file: String, seconds: float = 1.0) -> void:
	hold = at
	zoom = z
	await _wait(seconds)
	save_still(file)


func _wait(seconds: float) -> void:
	for i: int in range(roundi(seconds * 60.0)):
		camera.global_position = hold
		camera.zoom = base_zoom * zoom
		camera.reset_smoothing()
		if flaring:
			info.flare = Lamplight.FLARE_TIME * 0.5
		await process_frame


## A floor out on the terraces (not in a crypt) with `n` - 1 more floor cells to its right, open
## over them and holding nothing that stays (what lives there is taken away for the stills).
func _run(n: int) -> Vector2i:
	var w: LevelGen = info.world
	var clear: Array[LevelGen.Type] = [LevelGen.Type.EMPTY, LevelGen.Type.FOG, LevelGen.Type.MOTHS, LevelGen.Type.WRAITH, LevelGen.Type.COIN]
	for x: int in range(w.size.x - n):
		for y: int in range(1, w.size.y - 1):
			var ok: bool = true
			for k: int in range(n):
				var c: Vector2i = Vector2i(x + k, y)
				if w.is_ground(c) or not w.ground_below(c) or w.is_ground(c + Vector2i.UP) or w.interiors.has(c) or not w.get_cell(c).type in clear:
					ok = false
					break
			if ok:
				return Vector2i(x, y)
	return w.free_floors()[0]
