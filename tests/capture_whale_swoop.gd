extends TestKit
## Frames of the whale taking the wizard, for an animation: the trapped whale's underside coming
## into view along the top of its level, its warning, its lunge down and scoop up, the wizard
## swallowed, and the wizard arriving in its belly. The wizard stands on a perch high under open sky
## (found from the level's cells); the camera leads a little toward the whale until the swallow,
## then follows the wizard as in play. Frames go to whale_swoop/ in the stills folder, every
## EVERY physics frames; assemble them with, for example,
## ffmpeg -framerate 15 -i whale_swoop/f_%04d.png whale_swoop.gif
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_whale_swoop.gd

## Physics frames between saved frames (60 a second: 4 makes 15 frames a second).
const EVERY: int = 4
## How far the camera sits behind the wizard, toward the whale (px), and how much farther out it
## looks than in play.
const LEAD: float = 600.0
const ZOOM: float = 0.7

var camera: Camera2D
## Frames saved so far, and physics frames run since the whale was let go.
var frame: int = 0
var tick: int = 0
## The perch: a floor cell's open air above it, high under open sky (see whale_test).
var _perch: Vector2i = Vector2i(-1, -1)


func run() -> void:
	window()
	var row: int = WhaleHunt.row()
	var x: int = _world_with_perch(row)
	if x < 0:
		check(false, "a whale level with a high perch under open sky")
		finish()
		return
	await boot(x)
	camera = main.get_node("Camera2D") as Camera2D
	player.health.max_health = 99
	player.health.health = 99
	for side: int in [-1, 1]:
		var rec: LevelRecord = info.run.record(Vector2i(x + side, row))
		rec.vanes_on = {Vector2i(1, 1): -side}
		rec.wind_way = -side
	info.run.whale_x = x
	info.coord = Vector2i(x, row)
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var whale: Whale = placed("whale.tscn")[0] as Whale
	whale.set_physics_process(false)
	player.global_position = info.cell_position(_perch)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	await until(func() -> bool: return player.is_on_floor())
	# Let the level's title pass before the first frame.
	await frames(300)
	var control: Node = player.get_node("CameraControl")
	control.set_process(false)
	var was: Vector2 = camera.zoom
	camera.zoom = was * ZOOM
	var at: Vector2 = player.global_position
	var view: Vector2 = Vector2(root.content_scale_size) / camera.zoom
	# Its nose just out of view to the left, rested and coming on.
	whale.phase = Whale.Phase.CRUISE
	whale.facing = 1.0
	whale.since = 99.0
	whale.global_position.x = at.x - LEAD - view.x * 0.5 - 100.0 - Whale.LENGTH * 0.5
	whale.set_physics_process(true)
	print("approach")
	while not Worlds.is_side(info.coord):
		camera.global_position = at + Vector2(-LEAD, -150.0)
		camera.reset_smoothing()
		await _step()
		if tick > 60 * 20:
			check(false, "the whale swallows the wizard within 20 s")
			finish()
			return
	print("swallowed")
	camera.zoom = was
	control.set_process(true)
	await until(func() -> bool: return not info.travelling)
	print("in the belly")
	for i: int in range(150):
		await _step()
	print("FRAMES ", frame)
	RunState.delete_save()
	finish()


## One frame on, saving it if it is one of every EVERY.
func _step() -> void:
	await process_frame
	tick += 1
	if tick % EVERY == 0:
		save_still("whale_swoop/f_%04d.png" % frame)
		frame += 1



## The first world from 28 whose level on the whale's row has a perch: a floor three cells wide in
## the high rows, open sky straight above its middle. -1 if none of the first few has.
func _world_with_perch(row: int) -> int:
	for x: int in range(28, 60):
		var w: LevelGen = build(Vector2i(x, row))
		for cx: int in range(2, w.size.x - 2):
			for cy: int in range(2, Whale.HIGH_ROWS):
				var v: Vector2i = Vector2i(cx, cy)
				if _floor(w, v) and _open_above(w, v):
					_perch = v + Vector2i.UP
					return x
	return -1


## The kinds of cell that shelter a wizard from the whale (as MapInfo.solid_at takes them, shut).
const COVER: Array[LevelGen.Type] = [LevelGen.Type.GROUND, LevelGen.Type.CRACKED, LevelGen.Type.DOOR, LevelGen.Type.TRAPDOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.LIGHT_GATE, LevelGen.Type.OSSUARY_DOOR]


## Whether `v` and the cells either side are rock with room to stand over each: open air, or
## something floating there to be picked up (a star, a moon).
func _floor(w: LevelGen, v: Vector2i) -> bool:
	for dx: int in [-1, 0, 1]:
		var at: Vector2i = v + Vector2i(dx, 0)
		var over: LevelGen.Type = w.get_cell(at + Vector2i.UP).type
		if not w.is_ground(at) or not (over == LevelGen.Type.EMPTY or Placeables.has_flag(over, &"floats")):
			return false
	return true


## Whether nothing straight above `v`, up to the level's top, shelters it (COVER).
func _open_above(w: LevelGen, v: Vector2i) -> bool:
	for y: int in range(0, v.y):
		if w.get_cell(Vector2i(v.x, y)).type in COVER:
			return false
	return true
