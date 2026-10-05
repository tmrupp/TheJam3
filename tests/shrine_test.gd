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
	MapInfo.save_path = "user://shrine_test.save"
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

	print("one interactable at a time")
	var stations: Node = shrines()[0]
	var boon: Interactable = stations.get_node("Boon/Interactable") as Interactable
	var boon2: Interactable = stations.get_node("Boon2/Interactable") as Interactable
	boon.touching = true
	boon2.touching = true
	player.global_position = (boon2.get_parent() as Node2D).global_position + Vector2(12, 0)
	check(Interactable.focused(self) == boon2 and boon2.is_focused() and not boon.is_focused(), "touching two stations, only the nearer is focused")
	var hits: Array[int] = []
	boon.interacted.connect(func() -> void: hits.append(0))
	boon2.interacted.connect(func() -> void: hits.append(1))
	var coins: int = player.coins.coins
	player.collect(-coins)
	var press: InputEventAction = InputEventAction.new()
	press.action = &"Discover"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	await process_frame
	check(hits == [1], "one press uses only the focused station (%s)" % [hits])
	player.collect(coins)
	boon.touching = false
	boon2.touching = false

	print("always a strict upgrade")
	var all_good: bool = true
	var saw_swap: bool = false
	var saved_tiers: Dictionary = player.tiers.duplicate()
	for setup: int in range(3):
		# Fresh but for a spell held, most perks known, and everything but spells maxed.
		player.tiers = Abilities.start_tiers()
		player.tiers[&"hex"] = 1
		if setup >= 1:
			for a: StringName in [&"double_jump", &"wall_climb", &"vigor", &"speed"]:
				player.tiers[a] = int(Abilities.MAX[a]) if setup == 2 else 1
			player.tiers[&"dash"] = int(Abilities.MAX[&"dash"]) if setup == 2 else 1
			player.tiers[&"blink"] = int(Abilities.MAX[&"blink"]) if setup == 2 else 0
		for level_seed: int in range(200):
			var picks: Array[StringName] = Abilities.offers(level_seed, player, 2)
			saw_swap = saw_swap or picks.any(func(a: StringName) -> bool: return Abilities.is_swap(player, a))
			if not picks.is_empty() and not picks.any(func(a: StringName) -> bool: return not Abilities.is_swap(player, a)):
				all_good = false
	player.tiers = saved_tiers
	Abilities.apply(player)
	check(all_good and saw_swap, "every shrine offers at least one strict upgrade (swaps still appear beside one)")

	print("starting abilities")
	check(player.tiers == Abilities.start_tiers() and Abilities.tier(player, &"dash") == 1 and player.MAX_JUMPS == 1 and not player.climable and player.health.max_health == 3 and not player.has_node("Blink") and not player.has_node("Hex") and Abilities.spell(player) == &"" and player.has_node("DashStrike"), "the dash (which strikes) and no spell; 3 health")
	check(Abilities.ORDER.all(func(a: StringName) -> bool: return a in [&"dash", &"hex"] or Abilities.tier(player, a) == 0), "parry, astral and the rest are all still to find")
	check(Abilities.tier(player, Abilities.offer(MapInfo.level_seed(28, 0), player)) == 0, "a shrine offers something new before upgrades")
	var hurt_before: Callable = player.hurt_ability
	player.get_node("Parry").call("execute")
	check(player.hurt_ability == hurt_before, "a locked parry does nothing")
	var projection: Node = player.get_node("AstralProjection")
	projection.call("toggle")
	check(not bool(projection.call("projecting")), "astral projection does nothing until learned")

	print("learning at the shrine")
	var shrine: Node = shrines()[0]
	var offer: StringName = shrine.call("offer")
	var tier: int = Abilities.tier(player, offer)
	var price: int = int(shrine.call("offer_price"))
	check(offer == Abilities.offers(MapInfo.level_seed(28, 0), player, 2)[0] and price == Abilities.price(0, tier + 1), "offers %s %s for %d" % [offer, Abilities.roman(tier + 1), price])
	shrine.call("buy_boon")
	check(Abilities.tier(player, offer) == tier and not bool(shrine.call("used")), "too few stars: nothing learned")
	player.collect(price + 5)
	shrine.call("buy_boon")
	check(Abilities.tier(player, offer) == tier + 1 and player.coins.coins == 5, "paid and learned")
	check(bool(shrine.call("used")), "the shrine is spent")
	player.health.health = 1
	shrine.call("buy_mend")
	check(player.health.health == 1 and player.coins.coins == 5, "a spent shrine will not mend")

	print("a second ability instead")
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	player.set_physics_process(false)
	shrine = shrines()[0]
	var first: StringName = shrine.call("offer", 0)
	var second: StringName = shrine.call("offer", 1)
	check(first != &"" and second != &"" and first != second, "two different abilities on offer: %s and %s" % [first, second])
	var before_second: int = Abilities.tier(player, second)
	player.collect(int(shrine.call("offer_price", 1)))
	shrine.call("buy_boon", 1)
	check(Abilities.tier(player, second) == before_second + 1 and Abilities.tier(player, first) == (1 if first == &"dash" else 0) * Abilities.tier(player, first), "taking the second learns it")
	check(bool(shrine.call("used")), "and spends the shrine")
	player.collect(100)
	shrine.call("buy_boon", 0)
	check(Abilities.tier(player, first) == 0 or first == &"dash", "so the first is no longer for sale")
	player.collect(-player.coins.coins)
	info.travel(MapInfo.Exit.BACK)
	await settle()
	player.set_physics_process(false)

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
	for a: StringName in [&"dash", &"double_jump", &"wall_climb", &"blink", &"vigor"]:
		Abilities.grant(player, a)
	Abilities.grant(player, &"blink")
	check(is_equal_approx(player.dash.MAX_TIME, 0.32), "dash II dashes longer")
	check(player.MAX_JUMPS == 2, "double jump I")
	check(player.climable and is_equal_approx(player.climb.MAX_TIME, 1.0), "wall climb I holds for 1 s")
	check(player.has_node("Blink") and int(player.get_node("Blink").get("distance")) == 400, "blink II reaches 400")
	Abilities.grant(player, &"parry")
	Abilities.grant(player, &"parry")
	check(is_equal_approx(float(player.get_node("Parry").get("duration")), 0.45), "parry II holds longer")
	check(Abilities.spell(player) == &"parry", "parry sits in the spell slot")
	check(Abilities.is_swap(player, &"astral") and not Abilities.is_swap(player, &"parry") and not Abilities.is_swap(player, &"vigor"), "a different spell would be a swap; perks never are")
	Abilities.grant(player, &"astral")
	check(Abilities.spell(player) == &"astral" and Abilities.tier(player, &"parry") == 0, "learning astral replaces parry: one spell at a time")
	Abilities.grant(player, &"astral")
	check(is_equal_approx((player.get_node("AstralProjection").get("projection_timer") as ActionTimer).MAX_TIME, 7.0), "astral II lasts longer")
	check(player.has_node("Blink") and player.MAX_JUMPS == 2 and player.climable, "perks are untouched by the swap")
	check(player.health.max_health == 4, "vigor I adds a heart")
	for i: int in range(6):
		Abilities.grant(player, &"double_jump")
	check(Abilities.tier(player, &"double_jump") == 3, "tiers stop at their max")
	for a: StringName in Abilities.ORDER:
		player.tiers[a] = int(Abilities.MAX[a])
	player.tiers[&"astral"] = 2
	check(Abilities.offer(MapInfo.level_seed(28, 0), player) == &"astral", "a shrine offers what is still left to learn")

	print("a swap leaves the old spell at the shrine")
	var stand: Node = shrines()[0]
	info.record()["shrine_used"] = false
	info.record().erase("left_spell")
	for a: StringName in Abilities.ORDER:
		player.tiers[a] = 0 if a in Abilities.SPELLS else int(Abilities.MAX[a])
	player.tiers[&"hex"] = 2
	Abilities.apply(player)
	player.collect(500)
	var k: int = -1
	for i: int in range(2):
		if bool(stand.call("swap", i)):
			k = i
	check(k >= 0, "with hex II held, the shrine offers another spell (a swap)")
	if k >= 0:
		var got: StringName = stand.call("offer", k)
		stand.call("buy_boon", k)
		check(Abilities.spell(player) == got and stand.call("left_spell", k) == [&"hex", 2] and bool(stand.call("used")), "learning %s leaves hex II in its niche" % got)
		stand.call("buy_boon", 1 - k)
		check(Abilities.spell(player) == got, "the spent shrine sells nothing else")
		var coins_before: int = player.coins.coins
		stand.call("buy_boon", k)
		check(Abilities.spell(player) == &"hex" and Abilities.tier(player, &"hex") == 2 and stand.call("left_spell", k) == [got, 1] and player.coins.coins == coins_before, "taking hex back is free, keeps its tier, and leaves %s there" % got)
		stand.call("buy_boon", k)
		check(Abilities.spell(player) == got and stand.call("left_spell", k) == [&"hex", 2], "and it swaps back again")

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
