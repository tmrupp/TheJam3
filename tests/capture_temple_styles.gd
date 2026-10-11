extends TestKit
## Stills of a sky temple (SkyArchetype.build_temples, TempleArt) dressed in each of
## TempleArt.STYLES, the same temple, opened, side by side (temple_styles.png), and each alone
## (temple_<style>.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_temple_styles.gd


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
	var middle: Vector2 = (info.cell_position(box.position) + info.cell_position(box.end - Vector2i.ONE)) * 0.5
	player.global_position = info.cell_position(temple.get_meta(&"cell")) + Vector2(-260.0, 0.0)
	for i: int in range(Temple.SPAN):
		var rec: LevelRecord = info.run.record(temple.place_of(i))
		rec.vanes_on = {Vector2i(1, 1): temple.winds[i]}
		rec.wind_way = temple.winds[i]
	temple.use()
	camera.zoom *= 0.75
	info.loader.wake_around(middle)
	var shots: Array[Image] = []
	for s: StringName in TempleArt.STYLES:
		TempleArt.style = s
		for f: int in range(40):
			camera.global_position = middle + Vector2(0.0, -40.0)
			camera.reset_smoothing()
			await process_frame
		var image: Image = get_root().get_texture().get_image()
		save_still("temple_%s.png" % s, image)
		shots.append(image)
	var size: Vector2i = shots[0].get_size()
	var sheet: Image = Image.create(size.x, size.y, false, shots[0].get_format())
	@warning_ignore("integer_division")
	var half: Vector2i = size / 2
	for k: int in range(shots.size()):
		var small: Image = shots[k].duplicate() as Image
		small.resize(half.x, half.y)
		sheet.blit_rect(small, Rect2i(Vector2i.ZERO, half), Vector2i((k % 2) * half.x, (k / 2) * half.y))
	save_still("temple_styles.png", sheet)
	RunState.delete_save()
	finish()
