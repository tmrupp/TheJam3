extends TestKit
## Stills of the light gates (LightGate) on a cemetery floor, a sun gate and a shade gate side by
## side with the wizard between them: with the flame lit (the sun gate up, the shade gate down) and
## snuffed (the other way round) (light_gates_lit.png, light_gates_snuffed.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_light_gates.gd

var camera: Camera2D
var zoom: Vector2 = Vector2.ONE


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	zoom = camera.zoom * 1.3
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"cemetery"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.get_node("CameraControl").set_process(false)
	(main.get_node("RisoDecor") as CanvasItem).visible = false
	for scene: String in ["skeleton_enemy.tscn", "moths.tscn", "wraith_enemy.tscn"]:
		for n: Node in placed(scene, true):
			n.queue_free()
	var a: Vector2i = _run()
	var gates: Array[LightGate] = []
	for k: int in range(2):
		var v: Vector2i = a + Vector2i(k * 3, 0)
		var gate: LightGate = (load("res://prefabs/light_gate.tscn") as PackedScene).instantiate() as LightGate
		info.map_elements.add_child(gate)
		gate.global_position = info.cell_position(v)
		gate.setup(info, v, k == 0)
		gates.append(gate)
	player.global_position = info.cell_position(a + Vector2i(1, 0)) + Vector2(64, 0)
	player.set_physics_process(true)
	var at: Vector2 = info.cell_position(a + Vector2i(1, 0)) + Vector2(64, -30)
	for i: int in range(420):
		_hold(at)
		await process_frame
	save_still("light_gates_lit.png")
	info.snuff(player.global_position)
	for i: int in range(60):
		_hold(at)
		await process_frame
	save_still("light_gates_snuffed.png")
	RunState.delete_save()
	finish()


func _hold(at: Vector2) -> void:
	camera.global_position = at
	camera.zoom = zoom
	camera.reset_smoothing()


## A floor cell out on the terraces with four more open floor cells to its right (open over them
## too).
func _run() -> Vector2i:
	var w: LevelGen = info.world
	var pools: Array = []
	pools.append(w.free_floors())
	for pool: Array in pools:
		for v: Vector2i in pool:
			var ok: bool = true
			for k: int in range(5):
				var c: Vector2i = v + Vector2i(k, 0)
				if not w.is_valid(c) or w.is_ground(c) or not w.ground_below(c) or w.is_ground(c + Vector2i.UP):
					ok = false
					break
			if ok:
				return v
	return w.free_floors()[0]
