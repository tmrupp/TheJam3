extends SceneTree
## Stills of the printed level map for 16 random levels (seeded, so the same each run): every
## band, wholly inked, to check generated levels look well formed. Written to
## ../art-captures/map-samples/, one per level, named world_depth.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_map_samples.gd

## How many levels, and the seed that picks them.
const SAMPLES: int = 16
const PICK_SEED: int = 20261005


func _initialize() -> void:
	call_deferred("capture")


func frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://capture_map_samples.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	await frames(5)
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player") as Player
	var output: String = ProjectSettings.globalize_path("res://../art-captures/map-samples")
	DirAccess.make_dir_recursive_absolute(output)
	var map: Node = main.get_node("RisoMap")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = PICK_SEED
	for i: int in range(SAMPLES):
		# Depths spread over every band (garden, cemetery, sky) and the first two cycles.
		var at: Vector2i = Vector2i(rng.randi_range(1, 999), i % 12)
		info.coord = at
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		while info.world == null or info.travelling:
			await process_frame
		player.set_physics_process(false)
		info.ink_whole_map()
		await frames(5)
		map.call("toggle")
		await frames(20)
		root.get_texture().get_image().save_png(output.path_join("%03d_%d_%d.png" % [i, at.x, at.y]))
		map.call("toggle")
		await frames(3)
		print("  level ", MapInfo.where(at), ": ", info.world.size, ", vaults ", info.world.vaults.size())
	print("CAPTURED ", SAMPLES, " map samples to ", output)
	quit()
