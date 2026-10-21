extends TestKit
## The resurrect spell (Resurrect), a crypt's rite (Crypts): no shrine offers it and the institute
## does not teach it until it is found; learned from its paper at tier I, in the utility slot. Cast
## standing, it raises a grave mark; a death in that level raises the wizard there at full health,
## untouchable a moment, with nothing lost (no lantern burned, no ghost, the stars kept), the rite
## spent and the mark gone; thorns after send them back to it. With no rite left nothing is cast; a
## lantern gives the rites back, and the save keeps them. Leaving the level loses the mark, and a
## death then is a death.
## godot --headless --path . --script res://tests/resurrect_test.gd


func run() -> void:
	await boot()

	print("found, not taught")
	var offered: bool = false
	for s: int in range(400):
		offered = offered or Abilities.offers(s, player, 3).has(Crypts.RITE)
	check(not offered and Abilities.found_first(Crypts.RITE), "no shrine offers resurrect before it is found")
	check(not info.teaches(Crypts.RITE), "nor does the institute teach it")
	check(Abilities.slot_of(Crypts.RITE) == &"utility" and Abilities.is_spell(Crypts.RITE), "it is a utility spell")
	check(RisoGlyph.of(Crypts.RITE, Vector2.ZERO, 0.0).size() >= 2, "it has a mark of its own (a headstone and a spark)")

	print("learning the rite")
	var rite: int = KeyRing.paper(Crypts.RITE, 1)
	player.keyring.take(rite)
	check(info.learn_paper(rite, player.global_position), "its paper is learned")
	check(Abilities.tier(player, Crypts.RITE) == 1 and Abilities.spell(player, &"utility") == Crypts.RITE, "resurrect at tier I, in the utility slot")
	var spell: Resurrect = player.get_node("Resurrect") as Resurrect
	check(spell != null and spell.rites() == 1 and spell.readiness() == 1.0, "one rite, ready")
	check(info.teaches(Crypts.RITE), "known, its higher tiers can be taught")

	print("binding and rising")
	await until(func() -> bool: return player.is_on_floor())
	check(Abilities.cast(player, &"utility"), "cast standing, it binds the soul")
	await process_frame
	var marks: Array[Node] = placed("grave_mark.tscn")
	check(spell.marked() and marks.size() == 1, "a grave mark stands where the wizard stood")
	var at: Vector2 = (marks[0] as Node2D).global_position
	player.set_physics_process(false)
	player.collect(7)
	var stars: int = player.coins.coins
	player.global_position = at + Vector2(400, -200)
	player.health.modify_health(-player.health.health)
	check(player.global_position.distance_to(at) < 1.0, "a death raises them at the mark")
	check(player.health.health == player.health.max_health and player.graced.is_acting(), "at full health, untouchable a moment")
	check(not info.run.vulnerable and not info.run.has_ghost and player.coins.coins == stars, "nothing lost: the lantern still protects them, no ghost, the stars kept")
	check(spell.rites() == 0 and spell.readiness() == 0.0, "the rite is spent")
	await process_frame
	check(not spell.marked() and placed("grave_mark.tscn").is_empty(), "and the mark is gone")
	check(player.footing == at and player.footing_at == info.coord, "thorns after send them back to it")
	player.set_physics_process(true)
	await until(func() -> bool: return player.is_on_floor())
	check(not Abilities.cast(player, &"utility"), "with no rite left, nothing is cast")

	print("a lantern gives the rites back")
	var lantern: Node = info.map_elements.get_children().filter(func(n: Node) -> bool: return n is Checkpoint).filter(info.is_respawn_lantern)[0]
	info.light_lantern(lantern)
	check(spell.rites() == 1, "lighting a lantern gives the rite back")
	player.resurrect_rites = 0
	check(int(player.to_save().get("resurrect_rites", -9)) == 0, "the save keeps the rites left")
	player.from_save(player.to_save())
	check(spell.rites() == 0, "and takes them back up")
	info.light_lantern(lantern)

	print("leaving loses the mark")
	await until(func() -> bool: return player.is_on_floor())
	check(Abilities.cast(player, &"utility") and spell.marked(), "bound again")
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	check(not spell.marked(), "another level: the mark is lost")
	player.set_physics_process(false)
	player.health.modify_health(-player.health.health)
	check(info.run.vulnerable and spell.rites() == 1, "a death there is a death, the rite kept")
	await settle()
	RunState.delete_save()
	finish()
