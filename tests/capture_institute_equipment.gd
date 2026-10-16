extends TestKit
## Stills of the institute's alchemy and ritual equipment (RisoDecor "alchemy" and "ritual"), found
## in the band's levels of world 28: ALCHEMY_SHOTS pieces of alchemy equipment close up, each made
## up its own way (institute_alchemy_0.png ...), each kind of ritual equipment close up
## (institute_ritual_0.png ... _3), and a laboratory and a sanctum at play size (institute_lab.png,
## institute_sanctum.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_institute_equipment.gd

## How many pieces of alchemy equipment to take close up.
const ALCHEMY_SHOTS: int = 10

var camera: Camera2D


func run() -> void:
	window()
	await boot(28)
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	var zoom: Vector2 = camera.zoom
	var seen: Dictionary = {}
	var wide: Dictionary = {}
	for k: int in range(NextWorldDef.BAND):
		info.coord = Vector2i(28, NextWorldDef.band_row(&"institute", k))
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		player.set_physics_process(false)
		player.global_position = info.cell_position(info.world.size / 2) + Vector2(0, -4000)
		await frames(240)
		var decor: RisoDecor = main.get_node("RisoDecor") as RisoDecor
		var s: int = Rules.level_seed(info.coord.x, info.coord.y)
		for item: Dictionary in decor.items:
			var kind: StringName = item["kind"]
			if kind != &"alchemy" and kind != &"ritual":
				continue
			var key: String = ""
			if kind == &"ritual":
				key = "ritual_%d" % (int(decor._r(s, item["cell"], 12) * float(RisoDecor.RITUAL)) % RisoDecor.RITUAL)
			else:
				var shots: int = seen.keys().filter(func(k: String) -> bool: return k.begins_with("alchemy")).size()
				if shots < ALCHEMY_SHOTS:
					key = "alchemy_%d" % shots
			var at: Vector2 = info.cell_position(item["cell"])
			if not wide.has(kind):
				wide[kind] = true
				camera.zoom = zoom
				await look(at + Vector2(0, -40), "institute_%s.png" % ("lab" if kind == &"alchemy" else "sanctum"))
			if key != "" and not seen.has(key):
				seen[key] = true
				camera.zoom = zoom * 3.0
				await look(at + Vector2(0, 10), "institute_%s.png" % key)
		if seen.size() >= ALCHEMY_SHOTS + RisoDecor.RITUAL:
			break
	camera.zoom = zoom
	print("found ", seen.keys())
	RunState.delete_save()
	finish()


## The camera on `at` for a moment, then a still as `file`.
func look(at: Vector2, file: String) -> void:
	info.loader.wake_around(at)
	for i: int in range(20):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	save_still(file)
