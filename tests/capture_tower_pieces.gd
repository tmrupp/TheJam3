extends TestKit
## Stills of the crag towers' pieces close up, in the first crag level (of worlds 28, 1, 7 and 99)
## holding all three: a
## watchtower's roof with its trapdoor shut and the wizard on the roof beside it
## (tower_piece_trapdoor.png); a rock-bug nest with the wizard near, as it hatches a bug and once
## the bug is out (tower_piece_nest_0.png, _1); and a mending bowl with the hurt wizard by it
## (tower_piece_well.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_tower_pieces.gd

var camera: Camera2D
## The worlds searched for a crag level holding all three pieces.
const WORLDS: Array[int] = [28, 1, 7, 99]


func run() -> void:
	window()
	var at: Vector2i = Vector2i(-1, 0)
	for x: int in WORLDS:
		for k: int in range(Bands.rows_of(&"crags")):
			var w: LevelGen = build(Vector2i(x, NextWorldDef.band_row(&"crags", k)))
			if at.x < 0 and w != null and [LevelGen.Type.TRAPDOOR, LevelGen.Type.NEST, LevelGen.Type.WELL].all(func(t: LevelGen.Type) -> bool: return not w.objects_of(t).is_empty()):
				at = Vector2i(x, NextWorldDef.band_row(&"crags", k))
	check(at.x >= 0, "a crag level holds a trapdoor, a nest and a mending bowl")
	if at.x < 0:
		finish()
		return
	await boot(at.x)
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	sturdy()
	await go(at, false)
	camera.zoom *= 1.5
	var cell: float = info.cell_position(Vector2i(1, 0)).x - info.cell_position(Vector2i.ZERO).x
	var door: Node2D = placed("trapdoor.tscn")[0] as Node2D
	player.set_physics_process(true)
	player.velocity = Vector2.ZERO
	player.global_position = door.global_position + Vector2(-cell * 1.5, -cell)
	await frames(40)
	freeze()
	await look_at(door.global_position, "tower_piece_trapdoor.png")
	var host: BugNest = placed("bug_nest.tscn")[0] as BugNest
	player.global_position = host.global_position + Vector2(cell * 2.0, 0.0)
	await until(func() -> bool: return host.hatching > BugNest.HATCH * 0.5, 8000)
	await look_at(host.global_position, "tower_piece_nest_0.png")
	await until(func() -> bool: return not host.brood.is_empty(), 4000)
	await frames(20)
	await look_at(host.global_position, "tower_piece_nest_1.png")
	var drop: Node2D = placed("mend_well.tscn")[0] as Node2D
	player.health.health = player.health.max_health - 2
	player.global_position = drop.global_position + Vector2(-cell * 0.75, 0.0)
	await look_at(drop.global_position, "tower_piece_well.png")
	RunState.delete_save()
	finish()


## The camera on `at` for a moment, then a still of the window as `file`.
func look_at(at: Vector2, file: String) -> void:
	for i: int in range(20):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	save_still(file)
