extends TestKit
## Phase 4 of docs/DEEPER_PLAN.md: one shrine per level near the deeper exit, offering the
## next tier of an ability (cheaper deeper) or healing to full (dearer deeper); taking either
## spends it. Tiers change the abilities and reset when the run ends.
## godot --headless --path . --script res://tests/shrine_test.gd


func shrines() -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == "shrine.tscn" and not node.is_queued_for_deletion():
			found.append(node)
	return found


func run() -> void:
	await boot()
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
				player.tiers[a] = Abilities.max_tier(a) if setup == 2 else 1
			# Blink, maxed, in the dash's place in the movement slot.
			player.tiers[&"dash"] = 0 if setup == 2 else 1
			player.tiers[&"blink"] = Abilities.max_tier(&"blink") if setup == 2 else 0
		for level_seed: int in range(200):
			var picks: Array[StringName] = Abilities.offers(level_seed, player, 2)
			saw_swap = saw_swap or picks.any(func(a: StringName) -> bool: return Abilities.is_swap(player, a))
			if not picks.is_empty() and not picks.any(func(a: StringName) -> bool: return not Abilities.is_swap(player, a)):
				all_good = false
	player.tiers = saved_tiers
	Abilities.apply(player)
	check(all_good and saw_swap, "every shrine offers at least one strict upgrade (swaps still appear beside one)")

	print("starting abilities")
	check(player.tiers == Abilities.start_tiers() and Abilities.tier(player, &"dash") == 1 and player.MAX_JUMPS == 1 and not player.climable and player.health.max_health == 3 and not player.has_node("Blink") and not player.has_node("Hex") and Abilities.spell(player, &"damage") == &"slash" and player.has_node("Slash") and Abilities.spell(player, &"move") == &"dash" and Abilities.spell(player, &"utility") == &"mend" and player.has_node("DashStrike"), "slash in the damage slot, the dash in the movement slot, mend in the utility slot; 3 health")
	check(Abilities.ids().all(func(a: StringName) -> bool: return a in [&"dash", &"slash", &"mend"] or Abilities.tier(player, a) == 0), "astral and the rest are all still to find")
	check(not Abilities.ids().has(&"parry"), "parry is no ability of its own (every damage spell parries)")
	check(Abilities.tier(player, Abilities.offer(Rules.level_seed(28, 0), player)) == 0, "a shrine offers something new before upgrades")
	Abilities.set_tier(player, &"slash", 0)
	var hurt_before: Callable = player.hurt_ability
	(player.get_node("Parry") as Parry).execute()
	check(player.hurt_ability == hurt_before, "with no damage spell, no parry")
	Abilities.set_tier(player, &"slash", 1)
	var projection: Node = player.get_node("AstralProjection")
	projection.call("toggle")
	check(not bool(projection.call("projecting")), "astral projection does nothing until learned")

	print("learning at the shrine")
	var shrine: Node = shrines()[0]
	var offer: StringName = shrine.call("offer")
	var tier: int = Abilities.tier(player, offer)
	var price: int = int(shrine.call("offer_price"))
	check(offer == Abilities.offers(Rules.level_seed(28, 0), player, 2)[0] and price == Abilities.price(0, tier + 1), "offers %s %s for %d" % [offer, Abilities.roman(tier + 1), price])
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
	for a: StringName in [&"dash", &"double_jump", &"wall_climb", &"vigor"]:
		Abilities.grant(player, a)
	check(is_equal_approx(player.dash.MAX_TIME, 0.32), "dash II dashes longer")
	Abilities.grant(player, &"blink")
	Abilities.grant(player, &"blink")
	check(Abilities.spell(player, &"move") == &"blink" and Abilities.tier(player, &"dash") == 0 and player.dashes(), "blink takes the movement slot from the dash (and is done on the Dash button)")
	check(player.MAX_JUMPS == 2, "double jump I")
	check(player.climable and is_equal_approx(player.climb.MAX_TIME, 1.0), "wall climb I holds for 1 s")
	check(player.has_node("Blink") and int(player.get_node("Blink").get("distance")) == 400, "blink II reaches 400")
	Abilities.grant(player, &"slash")
	check(Abilities.tier(player, &"slash") == 2 and is_equal_approx((player.get_node("Slash") as Slash).reach, Slash.REACH_II), "slash II reaches further")
	check(Abilities.spell(player) == &"slash", "slash sits in the damage slot")
	check(Abilities.is_swap(player, &"hex") and Abilities.is_swap(player, &"astral") and not Abilities.is_swap(player, &"slash") and Abilities.is_swap(player, &"awareness") and not Abilities.is_swap(player, &"vigor"), "another spell for a held slot would be a swap (every slot is held from the start); more of the same, or a perk, never is")
	Abilities.grant(player, &"hex")
	check(Abilities.spell(player) == &"hex" and Abilities.tier(player, &"slash") == 0 and Abilities.spell(player, &"move") == &"blink", "learning hex replaces slash (one to a slot) and leaves the movement slot be")
	Abilities.grant(player, &"astral")
	Abilities.grant(player, &"astral")
	check(is_equal_approx((player.get_node("AstralProjection").get("projection_timer") as ActionTimer).MAX_TIME, 2.0), "astral II lasts two seconds")
	check(Abilities.spell(player, &"move") == &"astral" and not player.has_node("Blink") and Abilities.spell(player) == &"hex", "astral takes the movement slot from blink, the damage slot kept")
	check(player.MAX_JUMPS == 2 and player.climable, "perks are untouched by the swaps")
	check(player.health.max_health == 4, "vigor I adds a heart")
	for i: int in range(6):
		Abilities.grant(player, &"double_jump")
	check(Abilities.tier(player, &"double_jump") == 3, "tiers stop at their max")
	for a: StringName in Abilities.ids():
		player.tiers[a] = Abilities.max_tier(a)
	player.tiers[&"astral"] = 2
	check(Abilities.offer(Rules.level_seed(28, 0), player) == &"astral", "a shrine offers what is still left to learn")

	print("a swap hands the old spell back as a paper")
	var stand: Node = shrines()[0]
	info.record().shrine_used = false
	player.keyring.clear()
	# Every slot held (hex II, the dash, awareness), the perks maxed: whatever new it offers for a
	# slot is a swap.
	for a: StringName in Abilities.ids():
		player.tiers[a] = 0 if Abilities.slot_of(a) != &"" else Abilities.max_tier(a)
	player.tiers[&"hex"] = 2
	player.tiers[&"dash"] = 1
	player.tiers[&"awareness"] = 1
	Abilities.apply(player)
	player.collect(500)
	var k: int = -1
	for i: int in range(2):
		if bool(stand.call("swap", i)):
			k = i
	check(k >= 0, "with every slot held, the shrine offers something for one (a swap)")
	if k >= 0:
		var got: StringName = stand.call("offer", k)
		var slot: StringName = Abilities.slot_of(got)
		var old: StringName = Abilities.spell(player, slot)
		var old_tier: int = Abilities.tier(player, old)
		stand.call("buy_boon", k)
		check(Abilities.spell(player, slot) == got and bool(stand.call("used")), "learning %s puts %s out of its slot" % [got, old])
		var handed: Array[int] = [KeyRing.paper(old, old_tier)]
		check(player.keyring.papers() == handed, "and hands it back as a %s %d paper" % [old, old_tier])
		var coins_before: int = player.coins.coins
		stand.call("buy_boon", 1 - k)
		stand.call("buy_boon", k)
		check(Abilities.spell(player, slot) == got and player.coins.coins == coins_before, "the spent shrine sells nothing else")
		player.keyring.clear()

	print("the run ending resets them")
	player.die()
	await settle(2)
	player.die()
	await settle()
	check(player.tiers == Abilities.start_tiers() and not player.has_node("Blink") and player.MAX_JUMPS == 1 and player.health.max_health == 3, "back to the starting abilities")
	check(info.world.shrine == cell, "and the same shrine in the same place")

	finish()
