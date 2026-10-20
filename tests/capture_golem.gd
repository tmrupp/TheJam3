extends TestKit
## Stills of the lodestone golem (Golem) in its hall (LodeHall), at the top of the crags' gate level:
## the golem asleep
## in its lair (slumped, dim, its eyes shut), the hall, the golem awake and whole, walking, its fists
## raised for a slam and its shockwave, stunned by a parried slam, a chunk held up to hurl,
## the spot a leap will land on marked, its chunks shattered and its heart bare and cracked, lode
## shards lying on the floor, and the recall's ways home. Written to golem_*.png.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_golem.gd


func run() -> void:
	window()
	await boot(28)
	info.coord = Vector2i(28, Bosses.row_of(&"golem"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var golem: Golem = placed("golem.tscn")[0] as Golem
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	player.set_physics_process(false)
	for bow: Node in placed("crossbow.tscn"):
		bow.set_physics_process(false)
	var box: Rect2i = info.world.keep["box"]
	# Asleep in its lair, the wizard out of the hall.
	player.global_position = Vector2(-9000.0, -9000.0)
	camera.global_position = golem.global_position + Vector2(0.0, -180.0)
	await frames(10)
	save_still("golem_asleep.png")
	# The hall, the wizard on the ground floor across from the golem.
	player.global_position = golem.global_position + Vector2(-500.0, -20.0)
	camera.global_position = info.cell_position(box.get_center())
	await frames(10)
	save_still("golem_hall.png")
	# The golem whole, close, awake.
	camera.global_position = golem.global_position + Vector2(0.0, -180.0)
	await within(func() -> bool: return golem.rise >= 1.0, 2.0)
	golem.state = Golem.State.REST
	golem.timer = INF
	await frames(6)
	save_still("golem_whole.png")
	# Walking after the wizard.
	golem.state = Golem.State.HUNT
	golem.hurl_wait = INF
	await within(func() -> bool: return golem.gait > 0.9 and absf(sin(golem.stride / Golem.STRIDE * TAU)) > 0.8, 3.0)
	camera.global_position = golem.global_position + Vector2(0.0, -180.0)
	await frames(2)
	save_still("golem_walk.png")
	# A slam: its fists raised (the warning), then down with the shockwave running each way.
	golem.hurl_wait = INF
	player.global_position = Vector2(golem.global_position.x - 260.0, golem.global_position.y - 64.0)
	await within(func() -> bool: return golem.state == Golem.State.SLAM_WARN and golem.timer < Golem.SLAM_WARN * 0.3, 5.0)
	save_still("golem_slam_warn.png")
	await within(func() -> bool: return golem.state == Golem.State.SLAM, 2.0)
	await frames(8)
	save_still("golem_slam.png")
	# Stunned by a parried slam: its chunks sag loose, stars over its head, shards flying out.
	await within(func() -> bool: return golem.state == Golem.State.SLAM, 4.0)
	(player.get_node("Parry") as Parry).parry(1, Vector2.ZERO, golem.fists.get_node("Damager"))
	await frames(20)
	save_still("golem_stunned.png")
	await within(func() -> bool: return golem.called.is_empty() and golem.shards.is_empty() and golem.state == Golem.State.HUNT, 12.0)
	# A chunk held up to hurl at the wizard far off.
	player.global_position = Vector2(golem.global_position.x - 900.0, golem.global_position.y - 64.0)
	player.end_invulnerable()
	await within(func() -> bool: return golem.state == Golem.State.HUNT, 3.0)
	golem.hurl_wait = 0.0
	await within(func() -> bool: return golem.state == Golem.State.HURL_WARN and golem.timer < Golem.HURL_WARN * 0.3, 3.0)
	save_still("golem_hurl.png")
	golem.hurl_wait = INF
	await within(func() -> bool: return golem.called.is_empty() and golem.stones.is_empty() and golem.state == Golem.State.HUNT, 12.0)
	# A leap marked: the wizard on the gallery over it.
	var floors: Array[int] = info.world.keep["floors"]
	var stair: Rect2i = (info.world.keep["stairs"] as Array[Rect2i])[1]
	player.global_position = info.cell_position(Vector2i(stair.position.x + (3 if stair.position.x < box.get_center().x else -2), floors[1] - 1))
	await within(func() -> bool: return golem.state == Golem.State.LEAP_WARN, 12.0)
	camera.global_position = (golem.global_position + golem.leap_to) * 0.5 + Vector2(0.0, -120.0)
	await frames(6)
	save_still("golem_leap_mark.png")
	await within(func() -> bool: return golem.state == Golem.State.REST, 4.0)
	golem.state = Golem.State.REST
	golem.timer = INF
	camera.global_position = golem.global_position + Vector2(0.0, -180.0)
	# Broken: an arm and the chest plate gone, its heart bare and wounded once.
	for i: int in [7, 2, 3, 4]:
		golem.shatter(i, Vector2.RIGHT)
	SpellStrike.strike(golem, Vector2.RIGHT, 1, &"slash", false, golem.heart_center() + Vector2(-260.0, 0.0))
	await frames(40)
	save_still("golem_broken.png")
	# Lode shards shed onto the floor.
	golem.shed_shards()
	await within(func() -> bool: return golem.shards.all(func(s: LodeShard) -> bool: return s.landed), 3.0)
	await frames(6)
	save_still("golem_shards.png")
	# The recall's warning: pink ways home through where the wizard stands.
	player.global_position = golem.global_position + Vector2(-420.0, -64.0)
	golem.state = Golem.State.HUNT
	golem.loose_t = Golem.RECALL_DELAY
	await within(func() -> bool: return golem.state == Golem.State.RECALL_WARN, 2.0)
	await frames(10)
	save_still("golem_recall.png")
	RunState.delete_save()
	finish()
