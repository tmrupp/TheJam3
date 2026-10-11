extends TestKit
## Stills of a sky temple's lock (Temple, TempleArt): none lit, the first lit, all but the last lit,
## the sequence broken (its medallions flashing pink as they go out), and opened, its hoard of star clusters in
## its hall; written as one sheet (temple_lock.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_temple_lock.gd


func run() -> void:
	window()
	var place: Vector2i = Vector2i.ZERO
	for world: int in range(28, 40):
		for k: int in range(NextWorldDef.BAND):
			var at: Vector2i = Vector2i(world, NextWorldDef.band_row(&"sky", k))
			if place == Vector2i.ZERO and not build(at).temples.is_empty():
				place = at
	await boot(place.x)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	info.coord = place
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	var temple: Temple = placed("temple.tscn")[0] as Temple
	var box: Rect2i = info.world.temples[0]["box"]
	var middle: Vector2 = (info.cell_position(box.position) + info.cell_position(box.end - Vector2i.ONE)) * 0.5 + Vector2(0.0, -60.0)
	player.global_position = middle + Vector2(0.0, -1200.0)
	info.loader.wake_around(middle)
	var shots: Array[Image] = []
	var seq: Array[int] = temple.sequence
	var steps: Array[Callable] = [
		func() -> void: pass,
		func() -> void: _on(seq[0]),
		func() -> void:
			for i: int in range(1, seq.size() - 1):
				_on(seq[i]),
		func() -> void: _on(-seq[seq.size() - 1]),
	]
	for k: int in range(steps.size()):
		(steps[k] as Callable).call()
		var wait: int = 4 if k == 3 else 30
		for f: int in range(wait):
			camera.global_position = middle
			camera.reset_smoothing()
			await process_frame
		shots.append(_crop(get_root().get_texture().get_image()))
	for i: int in range(seq.size() + 1):
		if temple.all_lit():
			break
		_on(seq[temple.progress()])
	await frames(5)
	temple.use()
	for f: int in range(50):
		camera.global_position = middle
		camera.reset_smoothing()
		await process_frame
	shots.append(_crop(get_root().get_texture().get_image()))
	var size: Vector2i = shots[0].get_size()
	var sheet: Image = Image.create(size.x * 3, size.y * 2, false, shots[0].get_format())
	for k: int in range(shots.size()):
		@warning_ignore("integer_division")
		sheet.blit_rect(shots[k], Rect2i(Vector2i.ZERO, size), Vector2i((k % 3) * size.x, (k / 3) * size.y))
	save_still("temple_lock.png", sheet)
	RunState.delete_save()
	finish()


var _made: int = 0


## Switch on a vane pointing `way`: a new made-up one each time.
func _on(way: int) -> void:
	_made += 1
	info.switch_vane(Vector2i(10000 + _made, 0), way)


## The middle of a still, around the temple.
func _crop(image: Image) -> Image:
	@warning_ignore("integer_division")
	var c: Vector2i = image.get_size() / 2
	return image.get_region(Rect2i(c.x - 260, c.y - 230, 520, 460))
