extends TestKit
## The dash is the attack (DashStrike): dashing through an enemy stuns it without hurting the
## wizard, the strike perk makes it wound, a shield takes the dash and throws the wizard back,
## dashing into a cracked wall breaks it, and on the ground the dash only comes back after
## Player.DASH_GROUND_COOLDOWN. A blink strikes along its way and spends the moons it passes.
## godot --headless --path . --script res://tests/dash_strike_test.gd

## Frames the directions are held through a dash (it is over by then).
const DASH_HOLD: int = 20


func open_cell(v: Vector2i) -> bool:
	return info.world.is_valid(v) and info.world.get_cell(v).type == LevelGen.Type.EMPTY


## A wisp with two open cells beside it on one side, and that side.
func target(skip: Array[Node] = []) -> Array:
	for e: Node in placed("mover_enemy.tscn"):
		if e in skip:
			continue
		var c: Vector2i = e.get_meta(&"cell")
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			if open_cell(c + side) and open_cell(c + side * 2):
				return [e, Vector2(side)]
	return []


## Dash for real (the Dash action), holding `dir` if given.
func press_dash(dir: Vector2 = Vector2.ZERO) -> void:
	var held: Array[StringName] = []
	if dir.x != 0.0:
		held.append(&"Right" if dir.x > 0.0 else &"Left")
	if dir.y != 0.0:
		held.append(&"Down" if dir.y > 0.0 else &"Up")
	for a: StringName in held:
		Input.action_press(a)
	Input.action_press(&"Dash")
	await physics_frame
	Input.action_release(&"Dash")
	# Hold the directions through the dash.
	await frames(DASH_HOLD)
	for a: StringName in held:
		Input.action_release(a)


func stunned(e: Node) -> bool:
	return is_instance_valid(e) and bool(e.get_node("HitBox").get("stunned"))


func run() -> void:
	await boot()
	player.end_invulnerable()
	var strike: DashStrike = player.get_node_or_null("DashStrike") as DashStrike
	check(strike != null and strike.damage == 0 and Abilities.spell(player) == &"parry", "every wizard's dash strikes; parry is the spell to start with")

	print("on the ground")
	player.global_position = info.respawn_marker.global_position
	await until(func() -> bool: return player.is_on_floor() and not player.dash.acted)
	check(player.is_on_floor() and not player.dash.acted, "standing, the dash is ready")
	await press_dash()
	check(player.is_on_floor() and player.dash.acted, "dashed on the ground: not back at once")
	await until(func() -> bool: return not player.dash.acted, roundi((Player.DASH_GROUND_COOLDOWN + 0.1) * 1000.0))
	check(not player.dash.acted, "back after %.2f s" % Player.DASH_GROUND_COOLDOWN)

	print("dashing through a wisp")
	var pick: Array = target()
	check(not pick.is_empty(), "a wisp with room beside it")
	var e: Node2D = pick[0]
	var side: Vector2 = pick[1]
	e.get_node("Mover").set_physics_process(false)
	var hp: int = int(e.get_node("Wound").get("hp"))
	var health: int = player.health.health
	player.global_position = e.global_position + side * 120.0 + Vector2(0, 16 - 31)
	player.velocity = Vector2.ZERO
	player.dash.refresh()
	player.dash_rest = 0.0
	await press_dash(-side)
	check(stunned(e), "it is stunned")
	check(int(e.get_node("Wound").get("hp")) == hp, "but not wounded without the strike perk")
	check(player.health.health == health, "and the wizard is unhurt")
	check((player.global_position - e.global_position).dot(-side) > 0.0, "having passed right through it")
	check(player.get_collision_mask_value(DashStrike.ENEMY_LAYER), "enemies block again once the dash is over")

	print("a dash ending inside an enemy")
	player.set_collision_mask_value(DashStrike.ENEMY_LAYER, false)
	player.global_position = e.global_position + Vector2(20, -20)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	await frames(6)
	check(not player.get_collision_mask_value(DashStrike.ENEMY_LAYER), "enemies stay passable while the wizard is inside one")
	check(player.global_position.distance_to(e.global_position) < 200.0, "so the wizard is not flung out of it (%.0f px off)" % player.global_position.distance_to(e.global_position))
	player.global_position = e.global_position + side * 220.0 + Vector2(0, 16 - 31)
	await until(func() -> bool: return player.get_collision_mask_value(DashStrike.ENEMY_LAYER))
	check(player.get_collision_mask_value(DashStrike.ENEMY_LAYER), "and block again once the wizard is clear")

	print("guarded while dashing")
	var damager: Node = e.get_node("HitBox/Damager")
	player.dash.enable(true)
	check(strike.guards(damager), "touching an enemy mid-dash does not hurt")
	check(not strike.guards(null), "anything else still does")
	player.dash.end()
	strike.guard_left = 0.0
	check(not strike.guards(damager), "and once the dash is over, it hurts again")

	print("the strike perk")
	Abilities.grant(player, &"strike")
	check(strike.damage == 1 and Abilities.max_tier(&"strike") == 3, "strike I wounds 1 (up to III)")
	var cell: Vector2i = e.get_meta(&"cell")
	strike.struck.clear()
	strike.sweep(e.global_position - side * 100.0, e.global_position + side * 100.0)
	check(not is_instance_valid(e) or e.is_queued_for_deletion(), "a struck wisp is slain")
	check((info.record().slain as Dictionary).has(cell), "and the level records it")

	print("shields")
	var pick2: Array = target()
	var guard: Node2D = pick2[0]
	var shield: Shield = Shield.new()
	shield.name = "Shield"
	shield.hp = 2
	guard.add_child(shield)
	player.dash.enable(true)
	strike.struck.clear()
	strike.sweep(guard.global_position - Vector2(100, 0), guard.global_position + Vector2(100, 0))
	check(shield.hp == 1 and not stunned(guard) and is_instance_valid(guard) and not guard.is_queued_for_deletion(), "a shield takes the dash whole")
	check(not player.dash.is_acting() and player.velocity.x < 0.0, "and throws the wizard back")

	print("cracked walls")
	var wall: Node2D = null
	var from: Vector2i = Vector2i.ZERO
	for n: Node in placed("cracked_wall.tscn"):
		if n.has_meta(&"secret"):
			continue
		var c: Vector2i = n.get_meta(&"cell")
		for s: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if wall == null and open_cell(c + s) and open_cell(c + s * 2):
				wall = n as Node2D
				from = c + s
	check(wall != null, "a cracked wall with room beside it")
	if wall != null:
		var wcell: Vector2i = wall.get_meta(&"cell")
		player.global_position = info.cell_position(from)
		player.velocity = Vector2.ZERO
		player.dash.refresh()
		player.dash_rest = 0.0
		await press_dash(Vector2(wcell - from))
		check(not is_instance_valid(wall) or wall.is_queued_for_deletion(), "dashing into it breaks it")
		check((info.record().broken as Dictionary).has(wcell), "for good")

	print("blink")
	Abilities.set_tier(player, &"blink", 1)
	var blink: Node = player.get_node("Blink")
	var moon: Node2D = placed("moon.tscn")[0] as Node2D
	player.dash.enable(true)
	check(player.dash.acted, "the dash is spent")
	blink.call("_moons", moon.global_position - Vector2(150, 0), moon.global_position + Vector2(150, 0))
	check(not player.dash.acted and float(moon.get("waning")) > 0.0, "a moon on the blink's way is spent and gives the dash back")
	var pick3: Array = target([guard])
	var far: Node2D = pick3[0]
	strike.struck.clear()
	strike.damage = 0
	strike.sweep(far.global_position - Vector2(250, 0), far.global_position + Vector2(250, 0))
	check(stunned(far), "and what lies on its way is struck")

	finish()
