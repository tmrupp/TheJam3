extends TestKit
## Pulled-out stills of whole institute levels, each with its printed map: the level photographed
## in tiles at a far zoom (TILES across, enough rows to cover it) and stitched into one image
## (institute_overview_<world>_<row>.png), light by sight off so every tile prints alike, then its
## map's level page with the whole level inked (institute_overview_<world>_<row>_map.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_institute_overview.gd

## The levels shown: [world, row into the institute's band].
const LEVELS: Array[Vector2i] = [Vector2i(28, 0), Vector2i(7, 3)]
## Tiles across a level.
const TILES: int = 3

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	for place: Vector2i in LEVELS:
		var at: Vector2i = Vector2i(place.x, NextWorldDef.band_row(&"institute", place.y))
		info.coord = at
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		player.set_physics_process(false)
		player.get_node("CameraControl").set_process(false)
		# Long enough for the region's title card to come and go.
		await _wait(420)
		var name: String = "institute_overview_%d_%d" % [at.x, at.y]
		# Light and shade by sight off, so every tile prints alike however far it is from the wizard.
		RisoLight.by_sight = false
		await _overview(name + ".png")
		RisoLight.by_sight = true
		info.ink_whole_map()
		var map: Node = main.get_node("RisoMap")
		map.call("toggle")
		await _wait(30)
		save_still(name + "_map.png")
		map.call("toggle")
		await _wait(10)
	RunState.delete_save()
	finish()


## The whole level (with a cell of its border) in tiles, stitched into `file`.
func _overview(file: String) -> void:
	var half: float = float(info.tile_map.tile_set.tile_size.x) * info.tile_map.global_scale.x * 0.5
	var top_left: Vector2 = info.cell_position(Vector2i(-1, -1)) - Vector2(half, half)
	var size: Vector2 = Vector2(info.world.size + Vector2i(2, 2)) * half * 2.0
	var base: Vector2 = Vector2(get_root().content_scale_size)
	if base.x < 1.0:
		base = Vector2(root.size)
	var was: Vector2 = camera.zoom
	# The zoom at which TILES views span the level across.
	var view: Vector2 = Vector2(size.x / float(TILES), size.x / float(TILES) * base.y / base.x)
	var zoom: float = base.x / view.x
	var rows: int = ceili(size.y / view.y)
	for limit: String in ["limit_left", "limit_top"]:
		camera.set(limit, -10000000)
	for limit: String in ["limit_right", "limit_bottom"]:
		camera.set(limit, 10000000)
	var sheet: Image = null
	for j: int in range(rows):
		for i: int in range(TILES):
			var center: Vector2 = top_left + Vector2((float(i) + 0.5) * view.x, (float(j) + 0.5) * view.y)
			for k: int in range(45):
				camera.zoom = Vector2(zoom, zoom)
				camera.global_position = center
				camera.reset_smoothing()
				await process_frame
			var shot: Image = root.get_texture().get_image()
			if sheet == null:
				sheet = Image.create(shot.get_width() * TILES, shot.get_height() * rows, false, shot.get_format())
			sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i(i * shot.get_width(), j * shot.get_height()))
	camera.zoom = was
	# Cropped to the level, and scaled down to something easy to look at.
	var px: float = float(sheet.get_width()) / (view.x * float(TILES))
	sheet = sheet.get_region(Rect2i(0, 0, sheet.get_width(), mini(sheet.get_height(), ceili(size.y * px))))
	sheet.resize(sheet.get_width() / 2, sheet.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	save_still(file, sheet)


func _wait(count: int) -> void:
	for i: int in range(count):
		await process_frame
