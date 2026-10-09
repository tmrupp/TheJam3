extends TestKit
## Stills of rock-bugs in a crag level, round its gondola at its open station: one on its cable, one
## crawling in through the hatch in the car's roof, one crawling along the inside of the roof, one halfway round an outer corner of rock, and ones on a
## floor, a wall and a ceiling (where there are any near); and a sheet of them, each cropped round
## the bug and blown up.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_rockbug.gd

## How much closer than play the camera looks, and the size of each bug's crop on the sheet (pixels
## of the window).
const CLOSER: float = 1.5
const CROP: Vector2i = Vector2i(200, 150)

var camera: Camera2D


func run() -> void:
	window()
	await boot(28)
	info.coord = Vector2i(28, NextWorldDef.band_row(&"crags", 1))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	var g: Gondola = placed("gondola.tscn")[0] as Gondola
	# The wizard out of the way, on the car's landing.
	player.global_position = g.posts[g.at_station].global_position + Vector2(float(g.inner[g.at_station]) * 60.0, 0.0)
	player.set_physics_process(false)
	var bugs: Array[RockBug] = []
	var cabled: RockBug = _spawn()
	cabled.ride_track(g, g.s + 1.9 if g.s + 1.9 <= float(g.path.size() - 1) else g.s - 1.9)
	bugs.append(cabled)
	var entering: RockBug = _spawn()
	entering.ride_track(g, g.s)
	bugs.append(entering)
	var inside: RockBug = _spawn()
	inside.ride_track(g, g.s)
	bugs.append(inside)
	var near: Vector2i = info.cell_at(g.center())
	var cornering: RockBug = null
	var corner: Variant = _outer_corner(near)
	if corner != null:
		cornering = _spawn()
		bugs.append(cornering)
	for want: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var spot: Variant = _cell_against(near, want)
		if spot != null:
			var b: RockBug = _spawn()
			b.placed = true
			b._cling(spot)
			bugs.append(b)
	await frames(6)
	# Hold them all still where they are shown.
	entering.mode = RockBug.Mode.ENTER
	entering.rel = Vector2(Gondola.HATCH_X, -g.cell_px * 2.0 - 12.0)
	entering.rb.global_position = g.to_global(entering.rel)
	entering.up = Vector2.RIGHT
	inside.mode = RockBug.Mode.CAR
	inside.face = RockBug.Face.ROOF
	inside.way = -1
	inside.rel = Vector2(-60.0, inside._roof_y())
	inside.rb.global_position = g.to_global(inside.rel)
	inside.up = Vector2.DOWN
	inside.heading = Vector2.LEFT
	if cornering != null:
		cornering.placed = true
		cornering._cling(corner)
		# Walking right along a floor: way -1 (a quarter turn back from the rock's way).
		cornering.way = -1
		cornering._plan_step(-1)
		cornering.heading = Vector2(1.0, 1.0).normalized()
		cornering.step_d = cornering.step_len * 0.5
		cornering.rb.global_position = cornering._along_step(cornering.step_d)
		cornering.up = Vector2(1.0, -1.0).normalized()
	for b: RockBug in bugs:
		b.set_physics_process(false)
	var zoom: Vector2 = camera.zoom
	camera.zoom = zoom * CLOSER
	for i: int in range(6):
		camera.global_position = g.center() + Vector2(0.0, -150.0)
		camera.reset_smoothing()
		await process_frame
	var still: Image = root.get_texture().get_image()
	save_still("rockbug.png", still)
	var sheet: Image = Image.create(CROP.x * 2 * bugs.size(), CROP.y * 2, false, still.get_format())
	for b: int in range(bugs.size()):
		for i: int in range(3):
			camera.global_position = bugs[b].rb.global_position
			camera.reset_smoothing()
			await process_frame
		var shot: Image = root.get_texture().get_image()
		var at: Vector2 = bugs[b].rb.get_global_transform_with_canvas().origin * float(shot.get_width()) / root.get_visible_rect().size.x
		var crop: Image = shot.get_region(Rect2i(Vector2i(at) - CROP / 2, CROP))
		crop.resize(CROP.x * 2, CROP.y * 2, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, CROP * 2), Vector2i(b * CROP.x * 2, 0))
	save_still("rockbug_sheet.png", sheet)
	camera.zoom = zoom
	RunState.delete_save()
	finish()


func _spawn() -> RockBug:
	var foe: Node2D = Placeables.scene(LevelGen.Type.BUG).instantiate() as Node2D
	info.map_elements.add_child(foe)
	return foe.get_node("RockBug") as RockBug


func _open(v: Vector2i) -> bool:
	return info.world.is_valid(v) and not info.solid_at(info.cell_position(v))


## The open cell nearest `from` (within a few cells) over a floor whose end it is: open to its right
## and down to the right, so a bug walking right wraps round the corner there; or null.
func _outer_corner(from: Vector2i) -> Variant:
	return _nearest(from, func(v: Vector2i) -> bool: return _open(v) and not _open(v + Vector2i.DOWN) and _open(v + Vector2i.RIGHT) and _open(v + Vector2i(1, 1)) and not info.world.keep_clear.has(v))


## The open cell nearest `from` (within a few cells) whose only rock among its four sides is the way
## `n` (a floor, a wall or a ceiling to cling to), or null.
func _cell_against(from: Vector2i, n: Vector2i) -> Variant:
	return _nearest(from, func(v: Vector2i) -> bool:
		if not _open(v) or info.world.keep_clear.has(v):
			return false
		for d: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			if _open(v + d) == (d == n):
				return false
		return true)


func _nearest(from: Vector2i, test: Callable) -> Variant:
	var best: Variant = null
	var best_d: int = 99
	for dx: int in range(-6, 7):
		for dy: int in range(-4, 5):
			var v: Vector2i = from + Vector2i(dx, dy)
			if absi(dx) + absi(dy) < best_d and test.call(v):
				best_d = absi(dx) + absi(dy)
				best = v
	return best
