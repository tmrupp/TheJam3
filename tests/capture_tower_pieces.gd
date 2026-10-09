extends TestKit
## Stills of the crag towers' pieces close up, in the first crag level holding all three: a
## watchtower's roof with its trapdoor shut and the wizard on the roof beside it
## (tower_piece_trapdoor.png); a rock-bug nest with the wizard near, as it hatches a bug and once
## the bug is out (tower_piece_nest_0.png, _1); and a mending draught with the wizard by it
## (tower_piece_draught.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_tower_pieces.gd

var camera: Camera2D


func run() -> void:
	window()
	var row: int = 0
	for k: int in range(NextWorldDef.BAND):
		var w: LevelGen = build(Vector2i(28, NextWorldDef.band_row(&"crags", k)))
		if [LevelGen.Type.TRAPDOOR, LevelGen.Type.NEST, LevelGen.Type.DRAUGHT].all(func(t: LevelGen.Type) -> bool: return not w.objects_of(t).is_empty()):
			row = NextWorldDef.band_row(&"crags", k)
			break
	await boot(28)
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	info.coord = Vector2i(28, row)
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	camera.zoom *= 1.5
	var cell: float = info.cell_position(Vector2i(1, 0)).x - info.cell_position(Vector2i.ZERO).x
	var door: Node2D = placed("trapdoor.tscn")[0] as Node2D
	player.set_physics_process(true)
	player.velocity = Vector2.ZERO
	player.global_position = door.global_position + Vector2(-cell * 1.5, -cell)
	await frames(40)
	player.set_physics_process(false)
	await look_at(door.global_position, "tower_piece_trapdoor.png")
	var host: BugNest = placed("bug_nest.tscn")[0] as BugNest
	player.global_position = host.global_position + Vector2(cell * 2.0, 0.0)
	await until(func() -> bool: return host.hatching > BugNest.HATCH * 0.5, 8000)
	await look_at(host.global_position, "tower_piece_nest_0.png")
	await until(func() -> bool: return not host.brood.is_empty(), 4000)
	await frames(20)
	await look_at(host.global_position, "tower_piece_nest_1.png")
	var drop: Node2D = placed("draught.tscn")[0] as Node2D
	player.global_position = drop.global_position + Vector2(-cell, 0.0)
	await look_at(drop.global_position, "tower_piece_draught.png")
	RunState.delete_save()
	finish()


## The camera on `at` for a moment, then a still of the window as `file`.
func look_at(at: Vector2, file: String) -> void:
	for i: int in range(20):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	save_still(file)
