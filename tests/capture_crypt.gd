extends TestKit
## Stills of the cemetery's crypts and light (world 28): a crypt's doorway from outside with its
## snuffing font; inside it with the flame lit and snuffed; a skeleton asleep and one walking; a
## wraith frozen in the flame's light; and the necromancer in its crypt, in light and in the dark.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_crypt.gd

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	await _go(Vector2i(28, NextWorldDef.first_depth(&"cemetery")))
	var crypt: Dictionary = info.world.crypts[0]
	var box: Rect2i = crypt["box"]
	var step: Vector2i = (crypt["steps"] as Array)[0]
	# Outside, at its doorway, the font beside it.
	player.global_position = info.cell_position(step)
	var fonts: Array[Node] = placed("snuffer.tscn")
	var at: Vector2 = info.cell_position(step)
	if not fonts.is_empty():
		at = ((fonts[0] as Node2D).global_position + at) * 0.5
	await _look(at + Vector2(0, -60), "crypt_doorway.png")
	# Inside, lit and snuffed, the camera on the crypt's middle.
	var floors: Array[Vector2i] = crypt["floors"]
	var mid: Vector2 = info.cell_position(box.get_center())
	player.global_position = info.cell_position(floors[mini(4, floors.size() - 1)])
	await _look(mid, "crypt_inside_lit.png")
	info.snuff(player.global_position)
	await _look(mid, "crypt_inside_snuffed.png")
	# A skeleton asleep, close up, with the flame lit a little way off.
	var sleeper: Node2D = null
	for n: Node in placed("skeleton_enemy.tscn"):
		sleeper = n as Node2D
		break
	if sleeper != null:
		player.global_position = sleeper.global_position + Vector2(-400, 0)
		await _look(sleeper.global_position + Vector2(0, -40), "skeleton_asleep.png", 2.0)
		info.relight()
		player.global_position = sleeper.global_position + Vector2(-200, 0)
		for i: int in range(80):
			await process_frame
		await _look(sleeper.global_position + Vector2(0, -40), "skeleton_awake.png", 2.0)
	# A wraith frozen in the light, out on the terraces.
	info.relight()
	var wraith: Node2D = null
	for n: Node in placed("wraith_enemy.tscn"):
		wraith = n as Node2D
		break
	if wraith != null:
		player.global_position = wraith.global_position + Vector2(-200, 40)
		await _look(wraith.global_position + Vector2(-100, 0), "wraith_shy.png", 1.5)
	# The necromancer, in its crypt.
	MapInfo.debug = false
	await _go(Vector2i(28, Bosses.row_of(&"necromancer")))
	var found: Array[Node] = placed("necromancer.tscn")
	if not found.is_empty():
		var necro: Necromancer = found[0] as Necromancer
		necro.set_physics_process(false)
		player.global_position = necro.global_position + Vector2(-160, -40)
		await _look(necro.global_position + Vector2(-60, -100), "necromancer_lit.png", 1.5)
		info.snuff(player.global_position)
		await _look(necro.global_position + Vector2(-60, -100), "necromancer_dark.png", 1.5)
	RunState.delete_save()
	finish()


func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)


## Hold the camera on `at` at `zoom` for a while, then save the still.
func _look(at: Vector2, file: String, zoom: float = 1.0) -> void:
	var was: Vector2 = camera.zoom
	for i: int in range(40):
		camera.global_position = at
		camera.zoom = was * zoom
		camera.reset_smoothing()
		await process_frame
	save_still(file)
	camera.zoom = was
