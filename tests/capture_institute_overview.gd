extends TestKit
## Pulled-out stills of whole institute levels, each with its printed map: the level photographed
## in tiles at a far zoom (TILES across, enough rows to cover it) and stitched into one image
## (institute_overview_<world>_<row>.png, TestKit.overview_still), then its map's level page with
## the whole level inked (institute_overview_<world>_<row>_map.png). capture_overview.gd does the
## same for every band and as many worlds as asked.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_institute_overview.gd

## The levels shown: [world, row into the institute's band].
const LEVELS: Array[Vector2i] = [Vector2i(28, 0), Vector2i(7, 3)]
## Tiles across a level.
const TILES: int = 3


func run() -> void:
	window()
	await boot()
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
		await overview_still(name + ".png", TILES)
		info.ink_whole_map()
		var map: Node = main.get_node("RisoMap")
		map.call("toggle")
		await _wait(30)
		save_still(name + "_map.png")
		map.call("toggle")
		await _wait(10)
	RunState.delete_save()
	finish()


func _wait(count: int) -> void:
	for i: int in range(count):
		await process_frame
