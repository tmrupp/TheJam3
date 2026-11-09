extends TestKit
## The sealed way on at each of the garden's gates (Bosses, ExitArt), the worm's below and the
## bramble's above: close up (sealed_<boss>.png) and at the game's own zoom (sealed_<boss>_game.png),
## to look at its bars, its boss's seal and the chevrons in its crown, each clear of the others.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_sealed_door.gd

## How much closer than the game's camera the close-up is, and the size of each still's crop.
const CLOSE: float = 3.0
const CROP: Vector2i = Vector2i(720, 600)
const CROP_GAME: Vector2i = Vector2i(320, 260)

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	var base: Vector2 = camera.zoom
	for boss: StringName in [&"worm", &"bramble"]:
		var row: int = Bosses.row_of(boss)
		if row == 0:
			continue
		await go(Vector2i(28, row))
		var door: LevelExit = null
		for n: Node in placed("level_exit.tscn"):
			if (n as LevelExit).sealed() != &"":
				door = n as LevelExit
		check(door != null, "the %s's gate has a sealed way on" % boss)
		if door == null:
			continue
		player.global_position = door.global_position + Vector2(-400, 0)
		for zoom: float in [CLOSE, 1.0]:
			camera.zoom = base * zoom
			for i: int in range(20):
				camera.global_position = door.global_position + Vector2(0, -60)
				camera.reset_smoothing()
				await process_frame
			var whole: Image = root.get_texture().get_image()
			var size: Vector2i = CROP if zoom > 1.0 else CROP_GAME
			var still: Image = whole.get_region(Rect2i((whole.get_size() - size) / 2, size))
			save_still("sealed_%s%s.png" % [boss, "" if zoom > 1.0 else "_game"], still)
		camera.zoom = base
	finish()
