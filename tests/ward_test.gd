extends TestKit
## The ward perk (Ward): a charge takes a hit for the wizard (no heart lost, knocked back and
## untouchable for a moment), the next hit wounds, the charge grows back after its recharge, tier
## II grows it back sooner and tier III holds two; a parry is tried before the ward. And the
## enemy shield's plates (Shield, RisoWard): one for each bolt it can still take.
## godot --headless --path . --script res://tests/ward_test.gd


func run() -> void:
	await boot(28)
	player.set_physics_process(false)
	var wisp: Node = placed("mover_enemy.tscn")[0]
	var hit_by: Node = wisp.get_node("HitBox/Damager")
	check(player.get_node_or_null("Ward") == null, "a run starts without the ward")
	Abilities.grant(player, &"ward")
	var ward: Ward = player.get_node("Ward") as Ward
	check(ward != null and ward.charges == 1 and ward.charges_max == 1, "learning it gives one charge")

	print("taking a hit")
	Abilities.set_tier(player, &"parry", 0)
	player.end_invulnerable()
	var hp: int = player.health.health
	player.hurt(-1, Vector2.RIGHT * 300.0, hit_by)
	check(player.health.health == hp and ward.charges == 0, "a hit breaks the charge, and no heart is lost")
	check(player.is_invulnerable() and player.invulnerable.acting <= Ward.SAFE + 0.001 and player.knock == Vector2.RIGHT * 300.0, "the wizard is knocked back and untouchable for a moment")
	player.end_invulnerable()
	player.hurt(-1, Vector2.RIGHT * 300.0, hit_by)
	check(player.health.health == hp - 1, "with the charge spent, the next hit wounds")

	print("growing back")
	ward._process(Ward.RECHARGE * 0.5)
	check(ward.charges == 0 and absf(ward.regrowth() - 0.5) < 0.01, "half way through its recharge it is half grown")
	ward._process(Ward.RECHARGE * 0.5 + 0.01)
	check(ward.charges == 1 and ward.regrowth() == 0.0, "after %d s it is whole again" % int(Ward.RECHARGE))
	Abilities.grant(player, &"ward")
	check(is_equal_approx(ward.recharge, Ward.RECHARGE_II), "tier II grows back in %d s" % int(Ward.RECHARGE_II))
	Abilities.grant(player, &"ward")
	check(ward.charges == 2 and ward.charges_max == 2, "tier III holds two charges")

	print("the parry first")
	Abilities.set_tier(player, &"parry", 1)
	player.end_invulnerable()
	player.parry.emit()
	player.hurt(-1, Vector2.RIGHT * 300.0, hit_by)
	check(ward.charges == 2, "a parried hit leaves the ward whole")
	Engine.time_scale = 1.0

	print("an enemy's shield")
	var shield: Shield = Shield.new()
	main.add_child(shield)
	await process_frame
	check(shield.holds() and shield.full == Shield.HP, "a shield starts with %d plates" % Shield.HP)
	shield.absorb(false, Vector2.RIGHT)
	check(shield.hp == Shield.HP - 1 and shield._broken.size() == 1, "a bolt breaks one plate")
	shield.absorb(true, Vector2.RIGHT)
	check(not shield.holds() and shield._broken.size() == Shield.HP, "a parried shot breaks the rest at once")

	print("parrying a shielded enemy")
	# One the earlier parry did not touch.
	var wisps: Array[Node] = placed("mover_enemy.tscn")
	var guarded: Node = wisps[wisps.size() - 1]
	check(wisps.size() > 1 and not bool(guarded.get_node("Mover").get("stunned")), "a fresh wisp to shield")
	var plates: Shield = Shield.new()
	plates.name = "Shield"
	guarded.add_child(plates)
	await process_frame
	var wound: Wound = guarded.get_node("Wound") as Wound
	var hp_before: int = wound.hp
	player.end_invulnerable()
	var guard: Parry = player.get_node("Parry") as Parry
	await until(func() -> bool: return not guard.cooldown.acted, 3000)
	player.parry.emit()
	player.hurt(-1, Vector2.RIGHT * 300.0, guarded.get_node("HitBox/Damager"))
	Engine.time_scale = 1.0
	check(plates.hp == Shield.HP - 1, "a parried touch breaks one plate of its shield")
	check(wound.hp == hp_before and not bool(guarded.get_node("Mover").get("stunned")), "and does not reach the enemy behind it")
	finish()
