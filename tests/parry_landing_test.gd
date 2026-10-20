extends TestKit
## Dropping onto an enemy and slashing down at it as you land: the blow bounces the wizard up off it
## (a pogo, SpellStrike.recoil), in real physics, rather than settling on top; a parry alone, with no
## blow, does not. The enemy's body is solid to the wizard but is no moving platform
## (Player.ENEMY_LAYER): its own drift, and the push of the wizard's weight on it, must not be
## carried into the wizard and cancel the bounce.
## godot --headless --path . --script res://tests/parry_landing_test.gd


func run() -> void:
	await boot(28)
	# A wisp with open air over it, so the wizard drops straight onto it.
	var w: LevelGen = info.world
	var clear: Callable = func(v: Vector2i) -> bool: return w.is_valid(v) and w.get_cell(v).type in [LevelGen.Type.EMPTY, LevelGen.Type.COIN]
	var wisp: Node2D = null
	for e: Node in placed("mover_enemy.tscn"):
		var at: Vector2i = info.cell_at((e as Node2D).global_position)
		if wisp == null and clear.call(at + Vector2i.UP) and clear.call(at + Vector2i.UP * 2) and clear.call(at + Vector2i.UP * 3):
			wisp = e as Node2D
	check(wisp != null, "a wisp with open air over it")
	(wisp.get_node("Wound") as Wound).hp = 99
	var guard: Parry = player.get_node("Parry") as Parry
	var slash: Slash = player.get_node("Slash") as Slash
	await until(func() -> bool: return not player.is_invulnerable(), 5000)
	player.global_position = wisp.global_position + Vector2(0, -260)
	player.velocity = Vector2.ZERO
	var struck_y: float = INF
	var highest: float = INF
	for i: int in range(90):
		await physics_frame
		# Slash down just before landing, as a player timing it would (the guard goes up with it).
		if struck_y == INF and player.global_position.y > wisp.global_position.y - 90.0:
			player.parry.emit()
			if slash.cast(Vector2.DOWN):
				struck_y = player.global_position.y
		if struck_y != INF:
			highest = minf(highest, player.global_position.y)
	Engine.time_scale = 1.0
	check(struck_y != INF and (wisp.get_node("Wound") as Wound).hp < 99, "slashing down at the wisp as the wizard lands strikes it")
	check(struck_y - highest > 60.0, "and the wizard bounces up off it (%d px), not settling on top" % int(struck_y - highest))
	check(player.platform_floor_layers & Player.ENEMY_LAYER == 0, "an enemy is no moving platform to the wizard")
	# A parry alone pushes nothing: landing on an enemy with the guard up stuns it, no bounce.
	# Held clear of the wisp, so it cannot hurt them meanwhile (no guard goes up while hurt), and
	# the guard's cooldown (run by the wizard's physics, held here) made ready.
	player.set_physics_process(false)
	player.global_position = wisp.global_position + Vector2(0, -400)
	guard.stop_parry()
	guard.cooldown.refresh()
	player.end_invulnerable()
	player.parry.emit()
	player.knock = Vector2.ZERO
	player.knock_back.end()
	player.velocity = Vector2(250.0, 650.0)
	player.hurt(-1, Vector2.UP * 400.0, wisp.get_node("HitBox/Damager"))
	Engine.time_scale = 1.0
	check(guard.parried_at >= guard.raised_at and is_equal_approx(player.velocity.y, 650.0) and player.knock == Vector2.ZERO, "a parry alone, landing on an enemy, catches it without bouncing the wizard")
	finish()
