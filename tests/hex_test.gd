extends SceneTree
## Phase 7 of docs/DEEPER_PLAN.md: the hex bolt, enemy health and cracked walls.
## godot --headless --path . --script res://tests/hex_test.gd

var main: Node
var info: MapInfo
var player: Player
var failed: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func settle(frames: int = 4) -> void:
	await process_frame
	var deadline: int = Time.get_ticks_msec() + 30000
	while (info.world == null or info.travelling) and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in range(frames):
		await physics_frame
		await process_frame
	player.set_physics_process(false)


func placed(scene: String) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == scene and not node.is_queued_for_deletion():
			found.append(node)
	return found


func open_cell(v: Vector2i) -> bool:
	return info.world.is_valid(v) and info.world.get_cell(v).type != MapInfo.Type.GROUND and info.world.get_cell(v).type != MapInfo.Type.CRACKED


## A bolt thrown from `from` toward `dir`, as the Hex ability would.
func fire(from: Vector2, dir: Vector2, damage: int = 1) -> Node2D:
	var bolt: Node2D = Node2D.new()
	bolt.set_script(preload("res://scripts/HexBolt.gd"))
	bolt.set("dir", dir)
	bolt.set("damage", damage)
	info.map_elements.add_child(bolt)
	bolt.global_position = from
	return bolt


## An enemy with open ground beside it, and the side to shoot from.
func target(scene: String, skip: Array[Node] = []) -> Array:
	for e: Node in placed(scene):
		if e in skip:
			continue
		var c: Vector2i = e.get_meta(&"cell")
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			if open_cell(c + side):
				return [e, Vector2(side)]
	return []


func wait_physics(frames: int) -> void:
	for i: int in range(frames):
		await physics_frame


func run() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://test_run.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player
	await settle()

	print("the hex")
	check(player.get_node_or_null("Hex") == null, "not known at the start")
	Abilities.grant(player, &"hex")
	var hex: Hex = player.get_node_or_null("Hex") as Hex
	check(hex != null and Abilities.tier(player, &"hex") == 1 and hex.charges == 1, "learned: one charge")
	check(InputMap.has_action("Cast"), "the Cast action exists")

	print("wounding enemies")
	var wisps: Array[Node] = placed("mover_enemy.tscn")
	check(wisps.size() > 0 and wisps.all(func(e: Node) -> bool: return e.has_node("Wound") and e.is_in_group(&"hex_target")), "%d wisps have wounds" % wisps.size())
	check(int(wisps[0].get_node("Wound").get("hp")) == Wound.hp_for(0) and Wound.hp_for(0) == 1 and Wound.hp_for(3) == 2 and Wound.hp_for(9) == 3, "1 HP near the surface, up to 3 deeper")
	var pick: Array = target("mover_enemy.tscn")
	var e: Node2D = pick[0]
	var side: Vector2 = pick[1]
	var cell: Vector2i = e.get_meta(&"cell")
	var stars_before: int = placed("coin.tscn").size()
	player.global_position = e.global_position + side * 70.0 + Vector2(0, 44)
	var bolt: Node2D = hex.cast(-side)
	check(bolt != null and hex.charges == 0, "casting spends the charge")
	await wait_physics(8)
	check(not is_instance_valid(e) or e.is_queued_for_deletion(), "the bolt destroys the wisp")
	check((info.record()["slain"] as Dictionary).has(cell), "the level records it slain")
	check(placed("coin.tscn").size() > stars_before, "it drops stars")
	check(hex.cast(Vector2.RIGHT) == null, "no charge, no bolt")
	await create_timer(Hex.COOLDOWN + 0.2).timeout
	check(hex.charges == 1, "the charge comes back after %.1f s" % Hex.COOLDOWN)
	hex.charges = 0
	placed("checkpoint.tscn")[0].call("interacted")
	check(hex.charges == hex.charges_max, "lighting a lantern refills the charges")

	print("stunned enemies take double")
	var pick2: Array = target("mover_enemy.tscn")
	var e2: Node2D = pick2[0]
	e2.get_node("Wound").set("hp", 2)
	e2.get_node("Stunner").call("stun", 5.0)
	e2.get_node("Wound").call("hit", 1, Vector2.RIGHT)
	await wait_physics(2)
	check(not is_instance_valid(e2) or e2.is_queued_for_deletion(), "a 2 HP wisp falls to one stunned hit")

	print("slain until death")
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	check(not placed("mover_enemy.tscn").any(func(n: Node) -> bool: return n.get_meta(&"cell") == cell), "a revisit keeps it slain")
	player.die()
	await settle()
	check(placed("mover_enemy.tscn").any(func(n: Node) -> bool: return n.get_meta(&"cell") == cell), "dying brings it back")

	print("rock stops the bolt")
	var from: Vector2 = Vector2.ZERO
	var into: Vector2 = Vector2.ZERO
	for v: Vector2i in info.world.empties:
		if open_cell(v) and info.world.is_ground(v + Vector2i.RIGHT):
			from = info.cell_position(v)
			into = Vector2.RIGHT
			break
	var stopped: Node2D = fire(from, into)
	await wait_physics(10)
	check(not is_instance_valid(stopped) or stopped.is_queued_for_deletion(), "a bolt into rock ends there")

	print("cracked walls")
	var cracked: Array[Vector2i] = []
	for v: Vector2i in info.world.objects:
		if info.world.get_cell(v).type == MapInfo.Type.CRACKED:
			cracked.append(v)
	cracked.sort()
	check(cracked.size() > 0 and placed("cracked_wall.tscn").size() == cracked.size(), "%d cracked cells, each a wall" % cracked.size())
	check(cracked.all(func(v: Vector2i) -> bool: return info.tile_map.get_cell_source_id(0, v) == -1), "they are not part of the rock tiles")
	var shot: Vector2i = Vector2i(-1, -1)
	var shot_from: Vector2 = Vector2.ZERO
	var shot_dir: Vector2 = Vector2.ZERO
	for v: Vector2i in cracked:
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if open_cell(v + d):
				shot = v
				shot_from = info.cell_position(v + d)
				shot_dir = -Vector2(d)
				break
		if shot.x >= 0:
			break
	fire(shot_from, shot_dir)
	await wait_physics(6)
	check(not placed("cracked_wall.tscn").any(func(n: Node) -> bool: return n.get_meta(&"cell") == shot), "a bolt breaks the wall")
	check((info.record()["broken"] as Dictionary).has(shot), "and the record keeps it broken")
	player.die()
	await settle()
	check(not placed("cracked_wall.tscn").any(func(n: Node) -> bool: return n.get_meta(&"cell") == shot), "it stays broken after a death")
	info.start_run(28)
	await settle()
	var again: Array[Vector2i] = []
	for v: Vector2i in info.world.objects:
		if info.world.get_cell(v).type == MapInfo.Type.CRACKED:
			again.append(v)
	again.sort()
	check(again == cracked, "the same cracked walls every time")

	print("tiers")
	if not player.has_node("Hex"):
		Abilities.grant(player, &"hex")
	hex = player.get_node("Hex") as Hex
	Abilities.grant(player, &"hex")
	check(hex.charges_max == 2, "hex II: two charges")
	Abilities.grant(player, &"hex")
	check(hex.damage == 2, "hex III: two damage")
	Abilities.grant(player, &"hex")
	check(hex.pierce, "hex IV: pierces")

	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: deeper phase 7")
		quit()
