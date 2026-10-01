extends SceneTree
## Phase 4 of docs/DEEPER_PLAN.md: one shrine per level near the deeper exit, offering the
## next tier of an ability (cheaper deeper) or healing to full (dearer deeper); taking either
## spends it. Tiers change the abilities and reset when the run ends.
## godot --headless --path . --script res://tests/shrine_test.gd

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
	while (info.world == null or info.travelling or info.run_ending > 0.0) and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in range(frames):
		await physics_frame
		await process_frame


func shrines() -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == "shrine.tscn" and not node.is_queued_for_deletion():
			found.append(node)
	return found


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
	player.set_physics_process(false)

	print("placement")
	check(not main.has_node("UpgradeMenu"), "the upgrade menu is gone")
	check(shrines().size() == 1, "one shrine in the level")
	var cell: Vector2i = info.world.shrine
	var deeper: Vector2i = info.world.exits[MapInfo.Exit.DEEPER]
	print("  shrine ", cell, " deeper exit ", deeper)
	check(absi(cell.x - deeper.x) + absi(cell.y - deeper.y) <= 14, "near the deeper exit")
	check(info.world.ground_below(cell) and info.world.ground_below(cell + Vector2i.RIGHT), "standing on two floor cells")

	print("starting abilities")
	check(player.tiers == Abilities.start_tiers() and Abilities.tier(player, &"dash") == 1 and player.MAX_JUMPS == 1 and not player.climable and player.health.max_health == 3 and not player.has_node("Blink") and not player.has_node("Hex"), "only the dash; 3 health")
	check(Abilities.ORDER.all(func(a: StringName) -> bool: return a == &"dash" or Abilities.tier(player, a) == 0), "parry, astral, hex and the rest are all still to find")
	check(Abilities.tier(player, Abilities.offer(MapInfo.level_seed(28, 0), player)) == 0, "a shrine offers something new before upgrades")
	var hurt_before: Callable = player.hurt_ability
	player.get_node("Parry").call("execute")
	check(player.hurt_ability == hurt_before, "a locked parry does nothing")
	var orbs: Array[Node] = info.map_elements.get_children().filter(func(n: Node) -> bool: return n.scene_file_path.get_file() == "astral_projection_point.tscn")
	check(orbs.size() > 0 and not bool(orbs[0].call("usable")), "astral orbs are dormant")
	orbs[0].call("astral_project")
	check(not is_instance_valid(player.get_node("AstralProjection").get("false_player_origin")), "and touching one does nothing")
	Abilities.grant(player, &"astral")
	check(bool(orbs[0].call("usable")), "until astral is learned")
	player.tiers[&"astral"] = 0
	Abilities.apply(player)

	print("learning at the shrine")
	var shrine: Node = shrines()[0]
	var offer: StringName = shrine.call("offer")
	var tier: int = Abilities.tier(player, offer)
	var price: int = int(shrine.call("offer_price"))
	check(offer == Abilities.offer(MapInfo.level_seed(28, 0), player) and price == Abilities.price(0, tier + 1), "offers %s %s for %d" % [offer, Abilities.roman(tier + 1), price])
	shrine.call("buy_boon")
	check(Abilities.tier(player, offer) == tier and not bool(shrine.call("used")), "too few stars: nothing learned")
	player.collect(price + 5)
	shrine.call("buy_boon")
	check(Abilities.tier(player, offer) == tier + 1 and player.coins.coins == 5, "paid and learned")
	check(bool(shrine.call("used")), "the shrine is spent")
	player.health.health = 1
	shrine.call("buy_mend")
	check(player.health.health == 1 and player.coins.coins == 5, "a spent shrine will not mend")

	print("mending instead")
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	player.set_physics_process(false)
	shrine = shrines()[0]
	player.health.health = player.health.max_health
	shrine.call("buy_mend")
	check(not bool(shrine.call("used")), "at full health mending costs nothing and waits")
	player.health.health = 1
	player.collect(Abilities.heal_price(0))
	var before: Dictionary = player.tiers.duplicate()
	shrine.call("buy_mend")
	check(player.health.health == player.health.max_health and bool(shrine.call("used")), "healed to full; the shrine is spent")
	player.collect(100)
	shrine.call("buy_boon")
	check(player.tiers == before, "so its ability is no longer on offer")
	player.collect(-player.coins.coins)
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	check(bool(shrines()[0].call("used")), "a spent shrine stays spent on a revisit")

	print("prices")
	check(Abilities.price(0, 2) > Abilities.price(5, 2) and Abilities.price(0, 3) > Abilities.price(0, 2), "learning: cheaper deeper, dearer per tier")
	check(Abilities.heal_price(5) > Abilities.heal_price(0), "mending: dearer deeper (%d at 0, %d at 5)" % [Abilities.heal_price(0), Abilities.heal_price(5)])

	print("tiers change the abilities")
	player.tiers = Abilities.start_tiers()
	Abilities.apply(player)
	for a: StringName in [&"dash", &"double_jump", &"wall_climb", &"blink", &"parry", &"astral", &"vigor"]:
		Abilities.grant(player, a)
	Abilities.grant(player, &"blink")
	check(is_equal_approx(player.dash.MAX_TIME, 0.32), "dash II dashes longer")
	check(player.MAX_JUMPS == 2, "double jump I")
	check(player.climable and is_equal_approx(player.climb.MAX_TIME, 3.0), "wall climb I")
	check(player.has_node("Blink") and int(player.get_node("Blink").get("distance")) == 400, "blink II reaches 400")
	Abilities.grant(player, &"parry")
	Abilities.grant(player, &"astral")
	check(is_equal_approx(float(player.get_node("Parry").get("duration")), 0.4), "parry II holds longer")
	check(is_equal_approx((player.get_node("AstralProjection").get("projection_timer") as ActionTimer).MAX_TIME, 7.0), "astral II lasts longer")
	check(player.health.max_health == 4, "vigor I adds a heart")
	for i: int in range(6):
		Abilities.grant(player, &"double_jump")
	check(Abilities.tier(player, &"double_jump") == 3, "tiers stop at their max")
	var only: Dictionary = {}
	for a: StringName in Abilities.ORDER:
		player.tiers[a] = int(Abilities.MAX[a])
	player.tiers[&"astral"] = 2
	check(Abilities.offer(MapInfo.level_seed(28, 0), player) == &"astral", "a shrine offers what is still left to learn")

	print("the run ending resets them")
	player.die()
	await settle(2)
	player.die()
	await settle()
	check(player.tiers == Abilities.start_tiers() and not player.has_node("Blink") and player.MAX_JUMPS == 1 and player.health.max_health == 3, "back to the starting abilities")
	check(info.world.shrine == cell, "and the same shrine in the same place")

	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: deeper phase 4")
		quit()
