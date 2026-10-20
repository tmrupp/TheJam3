extends TestKit
## A still of the skeleton (SkeletonArt) on a crypt floor in the wizard's light (the decor hidden):
## one asleep, one halfway up and one standing (skeleton_states.png). Its walk is a GIF's frames:
## tests/capture_skeleton_gif.gd.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_skeletons.gd

## How far apart the three stand (px), all within the wizard's light.
const SPACING: float = 110.0

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
	var a: Vector2i = _run()
	# The others the light would wake or draw (skeletons, moths that sting the wizard and flash them
	# pink, wraiths) go.
	for scene: String in ["skeleton_enemy.tscn", "moths.tscn", "wraith_enemy.tscn"]:
		for n: Node in placed(scene, true):
			n.queue_free()
	var middle: Vector2 = info.cell_position(a + Vector2i(1, 0))
	var shown: Array[Node2D] = []
	for i: int in range(3):
		var node: Node2D = (load("res://prefabs/skeleton_enemy.tscn") as PackedScene).instantiate() as Node2D
		info.map_elements.add_child(node)
		node.global_position = middle + Vector2(float(i - 1) * SPACING, 0)
		(node.get_node("HitBox/CollisionShape2D") as CollisionShape2D).set_deferred("disabled", true)
		shown.append(node)
	await physics_frame
	await physics_frame
	for i: int in range(3):
		var bones: Skeleton = shown[i].get_node("Skeleton") as Skeleton
		bones.set_physics_process(false)
		bones.facing = 1.0
		bones.grounded = true
		bones.asleep = i == 0
		bones.rising = Skeleton.RISE * 0.5 if i == 1 else 0.0
	player.global_position = middle + Vector2(0, -150)
	var zoom: Vector2 = camera.zoom * 1.6
	# Past the region's title card.
	for i: int in range(300):
		await process_frame
	for i: int in range(40):
		camera.global_position = middle + Vector2(0, -40)
		camera.zoom = zoom
		camera.reset_smoothing()
		await process_frame
	save_still("skeleton_states.png")
	RunState.delete_save()
	finish()


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
