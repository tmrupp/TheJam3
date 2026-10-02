extends SceneTree
## Real prefabs: spell placement, pairing, replacement, cleanup and watcher sight range.

var info: MapInfo
var player: Player
var failed: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("  ok   ", message)
	else:
		failed = true
		push_error(message)

func settle() -> void:
	var deadline: int = Time.get_ticks_msec() + 30000
	await process_frame
	while (info.world == null or info.travelling) and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in range(8):
		await physics_frame
	check(info.world != null and not info.travelling, "level loaded")

func run() -> void:
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://rift_test.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player
	await settle()
	for i: int in range(30):
		await physics_frame
	Abilities.grant(player, &"rift")
	var rift: Rift = player.get_node("Rift") as Rift
	check(player.is_on_floor(), "standing to cast tier I")
	Abilities.cast(player)
	check(rift.ends.size() == 1 and not bool(rift.ends[0].get("linked")), "Spell places the first end, waiting for its partner")
	player.global_position += Vector2(0, -600)
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	check(rift.cast() == null and rift.ends.size() == 1, "tier I cannot place in midair")
	player.set_physics_process(false)
	Abilities.grant(player, &"rift")
	Abilities.cast(player)
	check(rift.ends.size() == 2 and bool(rift.ends[0].get("linked")) and bool(rift.ends[1].get("linked")), "tier II places in midair and links both ends")
	var first: Node2D = rift.ends[0]
	var second: Node2D = rift.ends[1]
	var world_a: Vector2i = info.coord
	var natural: Array[Node] = info.map_elements.get_children().filter(func(n: Node) -> bool: return n.scene_file_path.get_file() == "portal.tscn" and not n.has_meta(&"rift"))
	first.call("use_portal")
	check(player.global_position == second.global_position, "interaction travels to the partner")
	player.global_position += Vector2(700, 0)
	Abilities.cast(player)
	check(first.is_queued_for_deletion() and second.is_queued_for_deletion() and rift.ends.size() == 1, "third cast deletes both old ends and starts a new pair")
	var third: Node2D = rift.ends[0]
	check(not bool(third.get("linked")) and not bool(first.get("linked")) and not bool(second.get("linked")), "the new end waits for a partner and old ends stop working immediately")
	check(natural.all(func(n: Node) -> bool: return is_instance_valid(n) and not n.is_queued_for_deletion()), "recasting leaves generated teleporters alone")
	player.global_position += Vector2(700, 0)
	Abilities.cast(player)
	var fourth: Node2D = rift.ends[1]
	check(third.get("partner") == fourth and fourth.get("partner") == third, "fourth cast completes the new pair, linked both ways")
	var stand_at: Vector2 = fourth.global_position
	player.global_position = stand_at
	for i: int in range(6):
		await physics_frame
	check(player.global_position == stand_at, "standing in a rift does not send you through: E is always needed")
	fourth.call("use_portal")
	check(player.global_position == third.global_position, "interacting travels")
	var pair_a: Array = info.record()["rifts"].duplicate()
	Abilities.grant(player, &"hex")
	check(not third.is_queued_for_deletion() and not fourth.is_queued_for_deletion() and not player.has_node("Rift"), "the world keeps its pair when another spell is equipped")
	Abilities.grant(player, &"rift")
	Abilities.grant(player, &"rift")
	rift = player.get_node("Rift") as Rift
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	player.set_physics_process(false)
	var world_b: Vector2i = info.coord
	check(not is_instance_valid(third) and info.record(world_a)["rifts"] == pair_a, "unloading a world preserves its pair in the record")
	check(rift.ends.is_empty(), "another world starts with its own empty spell pair")
	Abilities.cast(player)
	check(rift.ends.size() == 1 and not bool(rift.ends[0].get("linked")), "new level starts with a fresh unpaired end")
	player.global_position += Vector2(0, -500)
	Abilities.cast(player)
	var pair_b: Array = info.record()["rifts"].duplicate()
	check(pair_b.size() == 2 and info.record(world_a)["rifts"] == pair_a, "placing a pair in world B leaves world A's pair intact")
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	player.set_physics_process(false)
	check(rift.ends.size() == 2 and rift.ends[0].global_position == pair_a[0] and rift.ends[1].global_position == pair_a[1], "returning to world A restores its exact pair")
	Abilities.cast(player)
	check(rift.ends.size() == 1 and info.record(world_b)["rifts"] == pair_b, "recasting in world A deletes only world A's old pair")
	player.global_position += Vector2(0, -400)
	Abilities.cast(player)
	pair_a = info.record()["rifts"].duplicate()
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	player.set_physics_process(false)
	check(rift.ends.size() == 2 and rift.ends[0].global_position == pair_b[0] and rift.ends[1].global_position == pair_b[1], "world B's original pair survives recasting elsewhere")
	info.save_run()
	var saved: Dictionary = MapInfo.read_save()
	check(saved["records"][world_a]["rifts"] == pair_a and saved["records"][world_b]["rifts"] == pair_b, "the saved run contains both worlds' independent pairs")
	check(info.continue_run(), "the saved run resumes")
	await settle()
	check(info.coord == world_a and rift.ends.size() == 2 and rift.ends[0].global_position == pair_a[0], "resuming at the lantern restores its world's pair")
	print("tier III: a link across worlds")
	player.set_physics_process(false)
	Abilities.set_tier(player, &"rift", 3)
	rift = player.get_node("Rift") as Rift
	var link_a: Node2D = rift.cast()
	var at_a: Vector2 = link_a.global_position
	check(info.rift_link.size() == 1 and not bool(link_a.get("linked")) and rift.ends.size() == 2, "tier III opens the link's first end, beside the world's own pair")
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	player.set_physics_process(false)
	var link_b: Node2D = rift.cast()
	check(bool(link_b.get("linked")) and link_b.get_meta(&"rift_far") == [world_a, at_a], "its partner, opened in another world, links back to the first world")
	check(rift.ends.size() == 2, "world B's own pair is untouched")
	info.save_run()
	check((MapInfo.read_save()["rift_link"] as Array).size() == 2, "the link is saved with the run")
	link_b.call("use_portal")
	await settle()
	player.set_physics_process(false)
	check(info.coord == world_a and absf(player.global_position.x - at_a.x) < 1.0 and player.global_position.distance_to(at_a) < 40.0, "using it travels to the other world, out of the other end (then lands)")
	var back_end: Array[Node2D] = Rift.link_ends(info)
	check(back_end.size() == 1 and back_end[0].get_meta(&"rift_far")[0] == world_b, "and the end there leads back")
	info.start_run(28)
	await settle()
	player.set_physics_process(false)
	check(not player.has_node("Rift") and Rift.current_ends(info).is_empty() and not info.record().has("rifts") and info.rift_link.is_empty(), "a new run clears the previous run's placed pairs and link")

	print("watcher detection")
	var watcher: RigidBody2D = load("res://prefabs/shooter_enemy.tscn").instantiate()
	watcher.freeze = true
	main.add_child(watcher)
	watcher.global_position = Vector2(20000, -1000)
	var eye: Node2D = watcher.get_node("Shooter")
	player.global_position = watcher.global_position + Vector2(800, -14)
	for i: int in range(5):
		await physics_frame
	check(bool(eye.call("can_see")), "eye sees the player at 800 px, beyond the former 520 px radius")
	var blocker: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(64, 400)
	collision.shape = shape
	blocker.add_child(collision)
	main.add_child(blocker)
	blocker.global_position = watcher.global_position + Vector2(400, -14)
	for i: int in range(3):
		await physics_frame
	check(not bool(eye.call("can_see")), "rock still blocks the expanded sight range")
	blocker.queue_free()
	player.global_position = watcher.global_position + Vector2(1550, -14)
	for i: int in range(3):
		await physics_frame
	check(not bool(eye.call("can_see")), "outside the new radius the eye cannot see the player")
	print("FAILED" if failed else "PASS: rift and watcher detection")
	quit(1 if failed else 0)
