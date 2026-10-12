extends TestKit
## Stills of the damage spells that strike round the wizard (Slash, Nova, Push; SpellMark), each
## cast at wisps on open floor and caught mid-swing; and the Fool carrying a damage spell in the
## bag. Written as one sheet (damage_spells.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_damage_spells.gd

const SIZE: int = 420


func open_cell(v: Vector2i) -> bool:
	return info.world.is_valid(v) and info.world.get_cell(v).type not in [LevelGen.Type.GROUND, LevelGen.Type.CRACKED, LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.SPIKES, LevelGen.Type.LASER]


func spot() -> Vector2i:
	var w: LevelGen = info.world
	for v: Vector2i in w.free_floors():
		# Away from the level's edges, where the camera cannot centre on it.
		var ok: bool = v.x > 6 and v.x < w.size.x - 6 and v.y > 4 and v.y < w.size.y - 4
		for dx: int in range(-2, 3):
			ok = ok and open_cell(v + Vector2i(dx, 0)) and w.is_ground(v + Vector2i(dx, 1))
		if ok:
			return v
	return Vector2i(-1, -1)


func wisp(at: Vector2i, off: float) -> Node2D:
	var e: Node2D = Placeables.scene(LevelGen.Type.ENEMY).instantiate() as Node2D
	LevelLoader.arm(e, info.here.depth)
	info.map_elements.add_child(e)
	e.get_node("Mover").set_physics_process(false)
	e.global_position = info.cell_position(at) + Vector2(off, 16.0)
	return e


func run() -> void:
	window()
	await boot()
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	var at: Vector2i = spot()
	player.set_physics_process(false)
	player.global_position = info.cell_position(at) + Vector2(0, 16 - 31)
	var shots: Array[Image] = []
	for spell: StringName in [&"slash", &"nova", &"push"]:
		Abilities.set_tier(player, spell, 2)
		var foes: Array[Node2D] = [wisp(at, 95.0), wisp(at, -140.0)]
		for i: int in range(12):
			camera.global_position = player.global_position + Vector2(20, -20)
			camera.reset_smoothing()
			await process_frame
		var node: Node = player.get_node(String(Abilities.ABILITIES[spell]["node"]))
		if spell == &"nova":
			(node as Nova).cast()
		else:
			node.call("cast", Vector2.RIGHT)
		await frames(4)
		shots.append(await _shot(camera, player.global_position + Vector2(20, -20)))
		for e: Node2D in foes:
			if is_instance_valid(e):
				e.queue_free()
		await frames(30)
	# The Fool with a damage spell in the bag (a utility spell shows nothing on the figure).
	Abilities.set_tier(player, &"awareness", 1)
	player.end_invulnerable()
	for i: int in range(150):
		camera.global_position = player.global_position + Vector2(0, -30)
		camera.reset_smoothing()
		await process_frame
	shots.append(_zoom(await _shot(camera, player.global_position + Vector2(0, -30)), 3))
	var sheet: Image = Image.create(SIZE * shots.size(), SIZE, false, shots[0].get_format())
	for k: int in range(shots.size()):
		sheet.blit_rect(shots[k], Rect2i(0, 0, SIZE, SIZE), Vector2i(k * SIZE, 0))
	save_still("damage_spells.png", sheet)
	RunState.delete_save()
	finish()


## The middle of `image` blown up `k` times.
func _zoom(image: Image, k: int) -> Image:
	@warning_ignore("integer_division")
	var crop: int = SIZE / k
	@warning_ignore("integer_division")
	var out: Image = image.get_region(Rect2i(SIZE / 2 - crop / 2, SIZE / 2 - crop / 2, crop, crop))
	out.resize(SIZE, SIZE, Image.INTERPOLATE_NEAREST)
	return out


## A close-up round `at`, the camera on it.
func _shot(camera: Camera2D, at: Vector2) -> Image:
	for i: int in range(3):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	var sp: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * at)
	@warning_ignore("integer_division")
	var x: int = clampi(int(sp.x) - SIZE / 2, 0, 1280 - SIZE)
	@warning_ignore("integer_division")
	var y: int = clampi(int(sp.y) - SIZE / 2, 0, 720 - SIZE)
	return root.get_texture().get_image().get_region(Rect2i(x, y, SIZE, SIZE))
