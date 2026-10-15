extends TestKit
## What an animated kind's art costs when a crowd of it is on screen: CROWD of each kind placed
## together in its band's first level (world 28; abominations of five blobs), the camera on them,
## and each one's art _process timed over 30 frames, as a total a frame and each. To judge which
## kinds are worth putting on a rig (InkCanvas.rig; tests/bench_rig.gd times the ones that are).
## godot --path . --windowed --resolution 1280x720 --script res://tests/bench_crowd.gd

## How many of each kind are placed.
const CROWD: int = 8

var camera: Camera2D

func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	var cases: Array = [
		[&"institute", "abomination.tscn"], [&"cemetery", "skeleton_enemy.tscn"], [&"cemetery", "wraith_enemy.tscn"],
		[&"garden", "hopper_enemy.tscn"], [&"sky", "bird_enemy.tscn"], [&"crags", "rock_bug.tscn"], [&"institute", "student.tscn"]]
	for c: Array in cases:
		var band: StringName = c[0]
		info.coord = Vector2i(28, NextWorldDef.first_depth(band) if band != &"garden" else 1)
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		player.get_node("CameraControl").set_process(false)
		var w: LevelGen = info.world
		var floors: Array[Vector2i] = w.free_floors()
		var at: Vector2i = floors[floors.size() / 2]
		var spawned: Array[Node2D] = []
		for i: int in range(CROWD):
			var n: Node2D = (load("res://prefabs/" + String(c[1])) as PackedScene).instantiate() as Node2D
			LevelLoader.arm(n, info.here.depth)
			if n is Abomination:
				(n as Abomination).sprout(5)
			info.map_elements.add_child(n)
			n.global_position = info.cell_position(at) + Vector2(float(i % 4) * 90.0 - 135.0, -float(i / 4) * 90.0)
			if n is Scholar:
				(n as Scholar).setup(info, at, {"ability": &"", "hall": -1})
			spawned.append(n)
		player.global_position = info.cell_position(at) + Vector2(0, -60)
		player.phasing = true
		for i: int in range(40):
			camera.global_position = info.cell_position(at) + Vector2(0, -80)
			camera.reset_smoothing()
			await process_frame
		var arts: Array[Node] = []
		for n: Node2D in spawned:
			if not is_instance_valid(n):
				continue
			for ch: Node in n.get_children():
				if ch is RisoProp:
					arts.append(ch)
		var total: float = 0.0
		var reps: int = 0
		for f: int in range(30):
			camera.global_position = info.cell_position(at) + Vector2(0, -80)
			await process_frame
			for a: Node in arts:
				var t: int = Time.get_ticks_usec()
				a.call(&"_process", 1.0 / 60.0)
				total += float(Time.get_ticks_usec() - t) / 1000.0
			reps += 1
		var name: String = (arts[0].get_script() as Script).resource_path.get_file() if not arts.is_empty() else "?"
		print("CROWD %-22s %d on screen: %.3f ms a frame for all, %.3f ms each" % [name, arts.size(), total / float(reps), total / float(reps) / maxf(1.0, float(arts.size()))])
		for n: Node2D in spawned:
			if is_instance_valid(n):
				n.queue_free()
		player.phasing = false
	RunState.delete_save()
	finish()
