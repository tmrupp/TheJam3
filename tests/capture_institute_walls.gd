extends TestKit
## Stills of the institute's wall styles side by side (RisoPrint.wall_style: RisoTerrain.WALL_LOOKS
## and the decor's "panel" sketch): the same views of its first level (world 28) in each style
## (institute_walls_<style>_<view>.png): a room with its walls round it and the wizard in it, wide
## (0) and close up (1), and the side of a marble hall where the walls meet it (2).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_institute_walls.gd

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"institute"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	var room: Vector2 = info.cell_position(_room_floor())
	var views: Array[Vector2] = [room + Vector2(0, -120), room + Vector2(-60, 40)]
	var zooms: Array[float] = [1.15, 2.4]
	var side: Variant = _hall_side()
	if side != null:
		views.append(side)
		zooms.append(1.5)
	var was: Vector2 = camera.zoom
	# Long enough for the region's title card to go.
	for i: int in range(420):
		await process_frame
	for style: StringName in RisoPrint.WALL_STYLES:
		RisoPrint.instance.set_wall_style(style)
		for n: int in range(views.size()):
			player.global_position = room
			for i: int in range(30):
				camera.global_position = views[n]
				camera.zoom = was * zooms[n]
				camera.reset_smoothing()
				await process_frame
			save_still("institute_walls_%s_%d.png" % [style, n])
	RisoPrint.instance.set_wall_style(RisoPrint.WALL_STYLES[0])
	camera.zoom = was
	RunState.delete_save()
	finish()


## Where a marble hall's wall meets the rock round it: the middle of the side of a hall with the most
## plain rock (not built) just outside it, or null.
func _hall_side() -> Variant:
	var w: LevelGen = info.world
	var best: Variant = null
	var most: int = 0
	for hall: Dictionary in w.halls:
		var box: Rect2i = hall["box"]
		for side: int in [-1, 1]:
			var x: int = box.position.x - 1 if side < 0 else box.end.x
			var n: int = 0
			for y: int in range(box.position.y, box.end.y):
				if w.is_ground(Vector2i(x, y)) and not w.masonry.has(Vector2i(x, y)):
					n += 1
			if n > most:
				most = n
				var edge: Vector2i = Vector2i(box.position.x if side < 0 else box.end.x - 1, box.position.y + box.size.y / 2)
				best = info.cell_position(edge) + Vector2(64.0 * float(side), 0)
	return best


## A floor cell out of the halls with rock round it near: a room's floor, with open air over it and
## walls a few cells off either side, else the first free floor.
func _room_floor() -> Vector2i:
	var w: LevelGen = info.world
	for v: Vector2i in w.free_floors():
		if Institute.hall_at(w, v) >= 0 or v.y < 4:
			continue
		var open: int = 0
		while open < 4 and not w.is_ground(v + Vector2i(0, -open - 1)):
			open += 1
		var wide: int = 0
		while wide < 6 and not w.is_ground(v + Vector2i(wide + 1, 0)) and w.is_ground(v + Vector2i(wide + 1, 1)):
			wide += 1
		if open >= 2 and open <= 3 and wide >= 4:
			return v + Vector2i(2, 0)
	return w.free_floors()[0]
