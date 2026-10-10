extends TestKit
## Stills of a crag tower's crossbow built into its wall (Crossbow), in the first crag level with
## one that has open air before its slit: from outside with the wizard in front of the slit as it
## draws (crossbow_out.png), as its arrow flies (crossbow_arrow.png), and from the room inside, by
## the wall it is set in (crossbow_in.png); and one in a keep's wall, from outside as it draws
## (keep_out.png) and from the hall (keep_in.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_crossbow.gd

var camera: Camera2D


func run() -> void:
	window()
	var place: Vector2i = Vector2i.ZERO
	var keep_place: Vector2i = Vector2i.ZERO
	for world: int in [29, 28, 30]:
		for k: int in range(NextWorldDef.BAND):
			var at: Vector2i = Vector2i(world, NextWorldDef.band_row(&"crags", k))
			var w: LevelGen = build(at)
			var bows: Array[Vector2i] = w.objects_of(LevelGen.Type.CROSSBOW)
			if place == Vector2i.ZERO and bows.any(func(v: Vector2i) -> bool: return crossbow_test_open(w, v) and _in(w, v) == &"tower"):
				place = at
			if keep_place == Vector2i.ZERO and bows.any(func(v: Vector2i) -> bool: return crossbow_test_open(w, v) and _in(w, v) == &"keep"):
				keep_place = at
	await boot(place.x)
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	info.coord = place
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var cell: float = info.cell_position(Vector2i(1, 0)).x - info.cell_position(Vector2i.ZERO).x
	var bow: Crossbow = null
	for n: Node in placed("crossbow.tscn"):
		var b: Crossbow = n as Crossbow
		if _in(info.world, b.cell) == &"tower" and range(2, 5).all(func(k: int) -> bool: return not info.solid_at(info.cell_position(b.cell) + Vector2(float(b.facing) * cell * float(k), 0.0))):
			bow = b
			break
	var room: Vector2 = info.cell_position(bow.cell)
	player.set_physics_process(false)
	var outside: Vector2 = room + Vector2(float(bow.facing) * cell * 3.5, 0.0)
	player.global_position = outside
	info.loader.wake_around(outside)
	var mid: Vector2 = (room + outside) * 0.5
	await within(func() -> bool: return bow.drawn > 0.7, Crossbow.DRAW + 2.0)
	await look_at(mid, "crossbow_out.png")
	await within(func() -> bool: return bow.since_shot < 0.15, Crossbow.DRAW + 2.0)
	await frames(3)
	await look_at(mid, "crossbow_arrow.png")
	player.global_position = room - Vector2(float(bow.facing) * cell * 0.4, 0.0)
	await frames(10)
	await look_at(room, "crossbow_in.png")
	# One in a keep's wall, the same way: from outside as it draws, and from the hall.
	if keep_place != place:
		info.coord = keep_place
		info._load_level()
		await settle()
	for n: Node in placed("crossbow.tscn"):
		var d: Crossbow = n as Crossbow
		if _in(info.world, d.cell) != &"keep" or not range(2, 5).all(func(k: int) -> bool: return not info.solid_at(info.cell_position(d.cell) + Vector2(float(d.facing) * cell * float(k), 0.0))):
			continue
		var hall: Vector2 = info.cell_position(d.cell)
		var out: Vector2 = hall + Vector2(float(d.facing) * cell * 3.0, 0.0)
		player.global_position = out
		info.loader.wake_around(out)
		await within(func() -> bool: return d.drawn > 0.7, Crossbow.DRAW + 2.0)
		await look_at((hall + out) * 0.5, "keep_out.png")
		player.global_position = hall - Vector2(float(d.facing) * cell * 0.4, 0.0)
		await frames(10)
		await look_at(hall, "keep_in.png")
		break
	RunState.delete_save()
	finish()


## The building whose wall crossbow `v` in `w` is set in.
static func _in(w: LevelGen, v: Vector2i) -> StringName:
	return w.structures.get(v + Vector2i(int((w.get_cell(v).extra_info as Dictionary)["facing"]), 0), &"")


## Whether crossbow `v` in `w` has three cells of open air before its slit.
static func crossbow_test_open(w: LevelGen, v: Vector2i) -> bool:
	var facing: int = int((w.get_cell(v).extra_info as Dictionary)["facing"])
	for k: int in range(2, 5):
		var c: Vector2i = v + Vector2i(facing * k, 0)
		if not w.is_valid(c) or w.is_ground(c):
			return false
	return true


## The camera on `at` for a moment, then a still of the window as `file`.
func look_at(at: Vector2, file: String) -> void:
	for i: int in range(20):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	save_still(file)
