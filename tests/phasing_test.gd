extends TestKit
## Astral projection drifts through rock: nothing solid stops it, it is kept inside the level,
## drifting into a secret room's rock opens the room, and ending inside rock (run out or snapped
## back) costs a heart and puts the wizard back in their body. Warp lands on a random floor, then
## recharges; at tier II on one not yet seen; at tier III in a secret room not yet opened, opening it.
## godot --headless --path . --script res://tests/phasing_test.gd


## A cell of rock with rock all round it.
func deep_rock() -> Vector2i:
	var w: LevelGen = info.world
	for x: int in range(1, w.size.x - 1):
		for y: int in range(1, w.size.y - 1):
			var v: Vector2i = Vector2i(x, y)
			var all: bool = true
			for dx: int in range(-1, 2):
				for dy: int in range(-1, 2):
					all = all and w.get_cell(v + Vector2i(dx, dy)).type == LevelGen.Type.GROUND
			if all:
				return v
	return Vector2i(-1, -1)


func run() -> void:
	await boot()

	print("astral projection through rock")
	Abilities.set_tier(player, &"astral", 1)
	var projection: Node = player.get_node("AstralProjection")
	var body_at: Vector2 = player.global_position
	projection.call("toggle")
	check(bool(projection.call("projecting")) and player.phasing and not player.get_collision_mask_value(3), "projected: phasing, and nothing solid stops it")
	var rock: Vector2i = deep_rock()
	player.global_position = info.cell_position(rock)
	await frames(4)
	check(info.cell_at(player.global_position) == rock and info.solid_at(player.global_position), "it rests inside solid rock at %s" % rock)
	player.global_position = Vector2(-99999, -99999)
	await frames(2)
	check(info.level_rect().grow(1.0).has_point(player.global_position), "and cannot leave the level")
	player.global_position = info.cell_position(rock)
	await frames(2)
	var hp: int = player.health.health
	player.end_invulnerable()
	(projection.get("projection_timer") as ActionTimer).elapse(60.0)
	await frames(2)
	check(not bool(projection.call("projecting")) and player.global_position.distance_to(body_at) < 4.0, "running out inside rock puts the wizard back in the body")
	check(player.health.health == hp - 1, "and costs a heart (%d -> %d)" % [hp, player.health.health])
	check(not player.phasing and player.get_collision_mask_value(3), "and the body is solid again")
	await create_timer(1.5).timeout
	projection.call("toggle")
	hp = player.health.health
	var body_now: Vector2 = (projection.get("false_player_origin") as Node2D).global_position
	player.global_position = info.cell_position(rock)
	await frames(2)
	player.end_invulnerable()
	projection.call("toggle")
	await frames(2)
	check(player.health.health == hp - 1 and player.global_position.distance_to(body_now) < 4.0, "snapping back from inside rock costs a heart too (%d -> %d)" % [hp, player.health.health])
	await create_timer(1.5).timeout
	projection.call("toggle")
	hp = player.health.health
	player.global_position = body_at + Vector2(0, -10)
	await frames(2)
	projection.call("toggle")
	await frames(2)
	check(player.health.health == hp, "snapping back from open air costs nothing")

	print("drifting into a secret room")
	check(not info.world.secrets.is_empty(), "the level has a secret room")
	projection.call("toggle")
	var room: Array = info.world.secrets[0]["room"]
	player.global_position = info.cell_position(room[0])
	await frames(3)
	check((info.record().secrets as Dictionary).has(0), "a projection drifting into its rock opens it")
	projection.call("toggle")
	await frames(2)

	print("warp")
	Abilities.set_tier(player, &"warp", 1)
	check(Abilities.spell(player) == &"warp" and Abilities.tier(player, &"astral") == 0, "warp takes the spell slot")
	var warp: Warp = player.get_node("Warp") as Warp
	var before: Vector2 = player.global_position
	var landed: Variant = warp.cast()
	# The trip takes a moment (Warp.DEPART and ARRIVE).
	while warp.warping:
		await process_frame
	check(landed != null and player.global_position.distance_to(before) > 1.0 and info.world.ground_below(landed) and not info.solid_at(player.global_position), "it lands on a floor (%s)" % [landed])
	check(warp.cast() == null and warp.readiness() < 0.1, "then it recharges")
	warp.recharge = 0.0
	Abilities.set_tier(player, &"warp", 2)
	check(info.world.empties.any(func(v: Vector2i) -> bool: return info.world.ground_below(v) and not info.is_seen(v)), "(with floors still unseen)")
	landed = warp.cast()
	check(landed != null and not info.is_seen(landed), "tier II lands on a floor not yet seen")
	while warp.warping:
		await process_frame
	info.travel(MapInfo.Exit.RIGHT)
	await settle(6)
	player.set_physics_process(false)
	check(info.world.secrets.size() > 0, "the next level has a secret room too")
	Abilities.set_tier(player, &"warp", 3)
	warp = player.get_node("Warp") as Warp
	warp.recharge = 0.0
	landed = warp.cast()
	while warp.warping:
		await process_frame
	check(landed != null and (info.world.secrets[0]["room"] as Array).has(landed) and (info.record().secrets as Dictionary).has(0), "tier III lands in a secret room not yet opened, and opens it")

	finish()
