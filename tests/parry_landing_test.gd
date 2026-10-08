extends TestKit
## Jumping down onto an enemy and parrying as you land: the wizard bounces up off it (a pogo), in
## real physics, rather than settling on top. The enemy's body is solid to the wizard but is no
## moving platform (Player.ENEMY_LAYER): its own drift, and the push of the wizard's weight on it,
## must not be carried into the wizard and cancel the bounce.
## godot --headless --path . --script res://tests/parry_landing_test.gd


func run() -> void:
	await boot(28)
	var wisp: Node2D = placed("mover_enemy.tscn")[0] as Node2D
	var guard: Parry = player.get_node("Parry") as Parry
	await until(func() -> bool: return not player.is_invulnerable(), 5000)
	player.global_position = wisp.global_position + Vector2(0, -260)
	player.velocity = Vector2.ZERO
	var caught_y: float = INF
	var highest: float = INF
	for i: int in range(90):
		await physics_frame
		# Raise the guard just before landing, as a player timing it would.
		if guard.raised_at < 0.0 and player.global_position.y > wisp.global_position.y - 70.0:
			player.parry.emit()
		if caught_y == INF and guard.parried_at > guard.raised_at:
			caught_y = player.global_position.y
		if caught_y != INF:
			highest = minf(highest, player.global_position.y)
	Engine.time_scale = 1.0
	check(caught_y != INF, "landing on the wisp with the guard up catches its touch")
	check(caught_y - highest > 60.0, "and the wizard bounces up off it (%d px), not settling on top" % int(caught_y - highest))
	check(player.platform_floor_layers & Player.ENEMY_LAYER == 0, "an enemy is no moving platform to the wizard")
	finish()
