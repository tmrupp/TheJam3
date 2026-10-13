extends TestKit
## Frames for a GIF of the skeleton (SkeletonArt) on a crypt floor: asleep, woken by the light of
## the wizard standing a little way off with their flame lit, rising, and walking at them. Written
## to the stills folder's skeleton_gif/ as frame_NNN.png, a frame every EVERY game frames; put
## together into a GIF elsewhere (any tool).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_skeleton_gif.gd

## How far off the wizard stands (px), how many frames are taken, and how many game frames apart.
const OFF: float = 250.0
const FRAMES: int = 90
const EVERY: int = 3

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"cemetery"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	(main.get_node("RisoDecor") as CanvasItem).visible = false
	var start: Vector2 = info.cell_position(_run())
	# The others the light would wake or draw (skeletons, moths that sting the wizard and flash them
	# pink, wraiths) go.
	for scene: String in ["skeleton_enemy.tscn", "moths.tscn", "wraith_enemy.tscn"]:
		for n: Node in placed(scene, true):
			n.queue_free()
	# The wizard stands out of reach until the title card has gone, then steps up.
	player.global_position = start + Vector2(OFF * 4.0, 0)
	var zoom: Vector2 = camera.zoom * 2.4
	var middle: Vector2 = start + Vector2(OFF * 0.5, -60)
	for i: int in range(300):
		_hold(middle, zoom)
		await process_frame
	var node: Node2D = (load("res://prefabs/skeleton_enemy.tscn") as PackedScene).instantiate() as Node2D
	info.map_elements.add_child(node)
	node.global_position = start
	# Harmless, so the wizard is not struck (and flashing) as it comes.
	(node.get_node("HitBox/CollisionShape2D") as CollisionShape2D).set_deferred("disabled", true)
	(node.get_node("Skeleton") as Skeleton).facing = 1.0
	for i: int in range(20):
		_hold(middle, zoom)
		await process_frame
	player.global_position = start + Vector2(OFF, 0)
	# Standing on the floor (it falls onto it, and no input moves it).
	player.set_physics_process(true)
	var dir: String = ProjectSettings.globalize_path(STILLS).path_join("skeleton_gif")
	DirAccess.make_dir_recursive_absolute(dir)
	# While it walks: how far its feet are, on average, ahead of its hip (art units; near 0 when they
	# straddle it, below 0 when they trail it), printed to check the gait.
	var art: SkeletonArt = node.get_node_or_null("RisoArt") as SkeletonArt
	var ahead: float = 0.0
	var counted: int = 0
	var was_x: float = node.global_position.x
	for k: int in range(FRAMES):
		for i: int in range(EVERY):
			_hold(middle, zoom)
			await process_frame
			if art != null and art.feet.size() == 2 and node.global_position.x - was_x > 0.05:
				ahead += ((art._foot(0).x + art._foot(1).x) * 0.5 - node.global_position.x) / SkeletonArt.SCALE - 1.0
				counted += 1
			was_x = node.global_position.x
		root.get_texture().get_image().save_png(dir.path_join("frame_%03d.png" % k))
	print("CAPTURED %d frames" % FRAMES)
	if counted > 0:
		print("feet ahead of the hip while walking, on average: %.2f art units (stride %.0f)" % [ahead / float(counted), SkeletonArt.STEP])
	RunState.delete_save()
	finish()


func _hold(at: Vector2, zoom: Vector2) -> void:
	camera.global_position = at
	camera.zoom = zoom
	camera.reset_smoothing()


## A floor cell with four more open floor cells to its right, in a crypt if one has room.
func _run() -> Vector2i:
	var w: LevelGen = info.world
	var pools: Array = []
	for crypt: Dictionary in w.crypts:
		pools.append(crypt["floors"])
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
