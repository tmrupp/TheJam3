extends TestKit
## Stills of the shrine's third station (Shrine.station): free mending (no price), which way the boss
## lies with its price and the key it takes, the same with no key carried (the key faint), and the
## spent bowl's chevron pointing the way; then the worlds map with the way marked on the gate row;
## then, in a level with no way on, the doorway it sells and the door bought.
## Written to ../art-captures/riso-frames/shrine_station_*.png.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_shrine_station.gd


func run() -> void:
	window()
	await boot(28)
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	var shrine: Shrine = placed("shrine.tscn")[0] as Shrine
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	camera.global_position = shrine.global_position + Vector2(60, -60)
	camera.reset_smoothing()
	var at: Vector2 = (shrine.get_node("Mend") as Node2D).global_position
	# At the station, for its pop-up, but hidden, so the wizard covers none of it.
	player.global_position = at
	player.visible = false
	player.health.health = 1
	await settle(40)
	save_still("shrine_station_mend.png")

	# Asked as if from a column whose shrine sells the boss's way.
	var home: Vector2i = info.coord
	var bx: int = home.x
	for x: int in range(home.x + 1, home.x + 80):
		if Shrine.sells_boss_at(Vector2i(x, home.y)):
			bx = x
			break
	info.coord = Vector2i(bx, home.y)
	player.health.health = player.health.max_health
	player.collect(500)
	Abilities.set_tier(player, &"keyring", 1)
	player.keyring.set_all([0, 2])
	await settle(40)
	save_still("shrine_station_boss.png")
	player.keyring.clear()
	await settle(10)
	save_still("shrine_station_boss_nokey.png")
	player.keyring.set_all([0, 2])
	shrine.buy_mend()
	player.global_position = at + Vector2(-400, 0)
	await settle(40)
	save_still("shrine_station_told.png")
	print("told way ", shrine.told_way(), " boss column ", Bosses.column(shrine.boss() if shrine.boss() != &"" else Bosses.ahead(home.y), info.run.run_seed))
	info.coord = home

	var map: Node = main.get_node("RisoMap")
	map.call("toggle")
	map.call("page", 1)
	# The gate level in the column asked from, where the way told is marked.
	map.set("selected", Vector2i(bx, Bosses.row_of(Bosses.ahead(home.y))))
	await settle(30)
	save_still("shrine_station_map.png")
	map.call("toggle")

	# A level the labyrinth left with no way on, whose shrine sells one: the doorway medallion, then
	# the door it puts in.
	var want: Vector2i = Vector2i(-1, -1)
	for k: int in range(2, Bands.garden_rows()):
		for x: int in range(20, 60):
			var c: Vector2i = Vector2i(x, k)
			if want == Vector2i(-1, -1) and not Rules.maze_has(c, MapInfo.Exit.DEEPER) and Shrine.sells_door_at(c) and Bosses.gate_at(c.y) == &"":
				want = c
	info.jump_to(want)
	await settle(40)
	player.set_physics_process(false)
	player.visible = false
	var sold: Shrine = placed("shrine.tscn")[0] as Shrine
	var to: Vector2 = info.cell_position(info.world.exits[MapInfo.Exit.DEEPER])
	player.get_node("CameraControl").set_process(false)
	player.global_position = (sold.get_node("Mend") as Node2D).global_position
	player.health.health = player.health.max_health
	player.collect(500)
	player.keyring.set_all([0, 2])
	await settle(10)
	camera.global_position = sold.global_position + Vector2(60, -60)
	camera.reset_smoothing()
	await settle(30)
	save_still("shrine_station_door.png")
	sold.buy_mend()
	player.global_position = to + Vector2(0, -2000)
	camera.global_position = to + Vector2(0, -40)
	camera.reset_smoothing()
	await settle(30)
	save_still("shrine_station_dug.png")
	print("door sold at ", want, " shrine ", sold.global_position, " door at ", to)
	finish()
