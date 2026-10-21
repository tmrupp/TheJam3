extends TestKit
## The damage spells (Slash, Nova, Push and Lunge strike round the wizard, SpellStrike; Seeker), in the damage
## slot on the Spell button, none of them stunning (only a parry stuns): a slash wounds what is in its arc in front and not what is
## behind, comes back quickly, and at IV cuts shots out of the air; a shield takes it whole; a nova
## strikes everything round the wizard within its reach and nothing past it, and is slow to come
## back; a push shoves what is in its cone away without wounding it at I, wounds what
## it slams into a wall and, at once, what cannot be moved, wounds at II, and blows shots away; a
## seeker turns onto an enemy a straight bolt would miss; a lunge throws the wizard forward and
## stabs what it reaches. A slash that lands throws the wizard back off what it struck, and its mark
## moves with them.
## godot --headless --path . --script res://tests/damage_spells_test.gd


## Open air: nothing solid (cracked rock only once broken), and no thorns.
func open_cell(v: Vector2i) -> bool:
	if not info.world.is_valid(v):
		return false
	if info.world.get_cell(v).type == LevelGen.Type.CRACKED:
		return (info.record().broken as Dictionary).has(v)
	return info.world.get_cell(v).type not in [LevelGen.Type.GROUND, LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.SPIKES, LevelGen.Type.LASER]


## Open air, or cracked rock (not a secret room's) that `clear_round` breaks out of the way.
func clearable(v: Vector2i) -> bool:
	return open_cell(v) or (info.world.is_valid(v) and info.world.get_cell(v).type == LevelGen.Type.CRACKED and info.world.get_cell(v).extra_info == null)


## A free floor cell with three open (or clearable) cells either side of it, over ground (cracked
## rock in the floor holds the wizard up as well as rock until it is broken).
func spot() -> Vector2i:
	var w: LevelGen = info.world
	for v: Vector2i in w.free_floors():
		var ok: bool = true
		for dx: int in range(-3, 4):
			var under: Vector2i = v + Vector2i(dx, 1)
			ok = ok and clearable(v + Vector2i(dx, 0)) and (w.is_ground(under) or (w.is_valid(under) and w.get_cell(under).type == LevelGen.Type.CRACKED))
		if ok:
			return v
	return Vector2i(-1, -1)


## Break the cracked rock in the three cells either side of `at` (as an empowered spell would), so
## the stretch is open whatever cracks the level laid there.
func clear_round(at: Vector2i) -> void:
	var cells: Array[Vector2i] = []
	for dx: int in range(-3, 4):
		cells.append(at + Vector2i(dx, 0))
	CrackedWall.crumble_cells(self, cells, Vector2.RIGHT)


## A wisp, held still, its middle `off` px from cell `at`'s middle, at the wizard's height.
func wisp(at: Vector2i, off: float) -> Node2D:
	var e: Node2D = Placeables.scene(LevelGen.Type.ENEMY).instantiate() as Node2D
	LevelLoader.arm(e, info.here.depth)
	info.map_elements.add_child(e)
	e.get_node("Mover").set_physics_process(false)
	e.global_position = info.cell_position(at) + Vector2(off, 16.0)
	return e


func hp(e: Node) -> int:
	return int((e.get_node("Wound") as Wound).hp) if is_instance_valid(e) and not e.is_queued_for_deletion() else 0


func stunned(e: Node) -> bool:
	return is_instance_valid(e) and bool(e.get_node("HitBox").get("stunned"))


## A watcher's shot, still, `off` px from cell `at`'s middle.
func shot(at: Vector2i, off: float) -> Bullet:
	var b: Bullet = (load("res://prefabs/bullet.tscn") as PackedScene).instantiate() as Bullet
	info.map_elements.add_child(b)
	b.global_position = info.cell_position(at) + Vector2(off, -8.0)
	b.setup(Vector2.ZERO, [], null)
	return b


func run() -> void:
	await boot()
	player.end_invulnerable()
	player.health.max_health = 99
	player.health.health = 99
	var at: Vector2i = spot()
	check(at != Vector2i(-1, -1), "open floor to cast on")
	player.set_physics_process(false)
	player.global_position = info.cell_position(at) + Vector2(0, 16 - 31)
	await frames(2)
	clear_round(at)
	await frames(2)

	print("slash")
	var slash: Slash = player.get_node("Slash") as Slash
	check(Abilities.spell(player) == &"slash" and Abilities.tier(player, &"slash") == 1, "slash I is the spell a run starts with")
	var ahead: Node2D = wisp(at, 80.0)
	var behind: Node2D = wisp(at, -110.0)
	var hp_ahead: int = hp(ahead)
	var hp_behind: int = hp(behind)
	check(slash.cast(Vector2.RIGHT), "it slashes")
	check(hp(ahead) == hp_ahead - 1 and not stunned(ahead), "what is in front is wounded, not stunned")
	check(hp(behind) == hp_behind and not stunned(behind), "what is behind is not")
	check(player.knock.x < 0.0 and player.knock_back.is_acting(), "landing it throws the wizard back off what it struck (recoil_test has the measures)")
	player.knock = Vector2.ZERO
	player.knock_back.end()
	var mark: SpellMark = null
	for n: Node in info.map_elements.get_children():
		if n is SpellMark and not n.is_queued_for_deletion():
			mark = n as SpellMark
	check(mark != null and mark.caster == player, "its mark goes with the wizard")
	if mark != null:
		player.global_position += Vector2(30.0, 0.0)
		await frames(1)
		check(is_instance_valid(mark) and mark.from.is_equal_approx(SpellStrike.origin(player)), "so they never walk out of their own slash")
		player.global_position -= Vector2(30.0, 0.0)
	check(not slash.cast(Vector2.RIGHT) and Abilities.readiness(player) < 1.0, "it is not ready again at once")
	var back: bool = await within(func() -> bool: return Abilities.readiness(player) >= 1.0, Slash.COOLDOWN + 0.2)
	check(back, "but quickly")
	var guard: Node2D = wisp(at, 60.0)
	var shield: Shield = Shield.new()
	shield.name = "Shield"
	shield.hp = 2
	guard.add_child(shield)
	var hp_guard: int = hp(guard)
	ahead.queue_free()
	await frames(1)
	slash.cast(Vector2.RIGHT)
	check(shield.hp == 1 and hp(guard) == hp_guard and not stunned(guard), "a shield takes it whole")
	guard.queue_free()
	behind.queue_free()
	Abilities.set_tier(player, &"slash", 4)
	slash.wait = 0.0
	var bolt: Bullet = shot(at, 70.0)
	slash.cast(Vector2.RIGHT)
	await frames(1)
	check(not is_instance_valid(bolt) or bolt.is_queued_for_deletion(), "slash IV cuts a shot out of the air")
	# From the Spell button: the spell, and the parry guard with it (Parry).
	var parry: Parry = player.get_node("Parry") as Parry
	slash.wait = 0.0
	Input.action_press(Abilities.SPELL_ACTION)
	player.set_physics_process(true)
	await frames(2)
	Input.action_release(Abilities.SPELL_ACTION)
	player.set_physics_process(false)
	player.global_position = info.cell_position(at) + Vector2(0, 16 - 31)
	check(slash.wait > 0.0, "the Spell button slashes")
	check(parry.guard_left() >= 0.0, "and raises the parry guard with it")
	# The guard closed and back (its cooldown runs with the wizard's physics, held here), the slash
	# still recharging.
	parry.stop_parry()
	parry.cooldown.refresh()
	slash.wait = Slash.COOLDOWN
	Input.action_press(Abilities.SPELL_ACTION)
	player.set_physics_process(true)
	await frames(2)
	Input.action_release(Abilities.SPELL_ACTION)
	player.set_physics_process(false)
	player.global_position = info.cell_position(at) + Vector2(0, 16 - 31)
	check(parry.guard_left() >= 0.0, "the guard rises even while the spell is not ready (its own cooldown)")

	print("nova")
	Abilities.grant(player, &"nova")
	var nova: Nova = player.get_node("Nova") as Nova
	check(Abilities.spell(player) == &"nova" and not player.has_node("Slash"), "nova takes the damage slot")
	var left: Node2D = wisp(at, -120.0)
	var right: Node2D = wisp(at, 120.0)
	var far: Node2D = wisp(at, 3.0 * 128.0)
	var hp_far: int = hp(far)
	var hp_left: int = hp(left)
	check(nova.cast(), "it bursts")
	check(hp(left) == hp_left - 1 and hp(right) == hp_left - 1 and not stunned(left) and not stunned(right), "everything round the wizard within its reach is wounded, not stunned")
	check(hp(far) == hp_far and not stunned(far), "nothing past its reach")
	check(not nova.cast() and Nova.COOLDOWN > Slash.COOLDOWN * 4.0, "it is slow to come back")
	for e: Node2D in [left, right, far]:
		if is_instance_valid(e):
			e.queue_free()

	print("push")
	Abilities.grant(player, &"push")
	var push: Push = player.get_node("Push") as Push
	check(Abilities.spell(player) == &"push", "push takes the damage slot")
	var target: Node2D = wisp(at, 70.0)
	# Tough, so a slam into rock past the shove's end does not finish it before the checks below.
	(target.get_node("Wound") as Wound).hp = 99
	var hp_target: int = hp(target)
	var from_x: float = target.global_position.x
	var blown: Bullet = shot(at, 100.0)
	check(push.cast(Vector2.RIGHT), "it blows")
	await frames(1)
	check(not stunned(target) and hp(target) == hp_target, "what is in its cone is neither stunned nor wounded at I")
	check(not is_instance_valid(blown) or blown.is_queued_for_deletion(), "and shots in it are blown away")
	var shoved: bool = await within(func() -> bool: return target.global_position.x > from_x + Push.SHOVE * 0.5, Push.SHOVE_TIME + 0.3)
	check(shoved, "and it is shoved away (%.0f px)" % (target.global_position.x - from_x))
	# Into the first rock along the row: the wizard two cells short of it, a wisp in the cell before.
	var wall: Vector2i = at
	while open_cell(wall):
		wall += Vector2i(1, 0)
	player.global_position = info.cell_position(wall - Vector2i(2, 0)) + Vector2(0, 16 - 31)
	var pinned: Node2D = wisp(wall - Vector2i(1, 0), 0.0)
	var hp_pinned: int = hp(pinned)
	push.wait = 0.0
	check(push.cast(Vector2.RIGHT), "a push at a wisp before a wall")
	var slammed: bool = await within(func() -> bool: return hp(pinned) < hp_pinned, Push.SHOVE_TIME + 0.3)
	check(slammed, "slammed into the wall, it is wounded, though push I does not wound")
	if is_instance_valid(pinned):
		pinned.queue_free()
	player.global_position = info.cell_position(at) + Vector2(0, 16 - 31)
	# What cannot be moved (as a boss: only a parry stuns it) takes the slam at once, unmoved.
	var fixed: Node2D = wisp(at, 70.0)
	Stunner.of(fixed).parry_only = true
	var hp_fixed: int = hp(fixed)
	push.wait = 0.0
	push.cast(Vector2.RIGHT)
	check_eq(hp(fixed), hp_fixed - Push.SLAM, "what cannot be moved takes the slam at once")
	check(not fixed.get_children().any(func(n: Node) -> bool: return n is Push.Shove), "and is not shoved")
	fixed.queue_free()
	Abilities.grant(player, &"push")
	push.wait = 0.0
	target.global_position = info.cell_position(at) + Vector2(70.0, 16.0)
	push.cast(Vector2.RIGHT)
	check(hp(target) < hp_target, "push II also wounds")
	if is_instance_valid(target):
		target.queue_free()

	print("seeker")
	# In the open air over the level, where there is room for its quarry up off the line a straight
	# bolt flies along (the level's own air is too low here).
	var cell: float = info.cell_position(at + Vector2i(1, 0)).x - info.cell_position(at).x
	var high: Vector2 = info.cell_position(Vector2i(at.x, 0)) + Vector2(0.0, -cell * 6.0)
	player.global_position = high
	await frames(2)
	Abilities.grant(player, &"seeker")
	var seeker: Seeker = player.get_node("Seeker") as Seeker
	check(Abilities.spell(player) == &"seeker", "the seeker takes the damage slot")
	# Up and ahead, well off the line a straight bolt flies along.
	var quarry: Node2D = wisp(at, 0.0)
	quarry.global_position = high + Vector2(cell * 3.0, -cell * 2.6)
	var hp_quarry: int = hp(quarry)
	var loosed: Array[HexBolt] = seeker.cast(Vector2.RIGHT)
	check(loosed.size() == 1 and seeker.cast(Vector2.RIGHT).is_empty(), "it looses one, then is not ready")
	await frames(4)
	check(not is_instance_valid(loosed[0]) or loosed[0].dir.y < -0.05, "it turns toward the enemy")
	var found: bool = await within(func() -> bool: return hp(quarry) < hp_quarry, 1.5)
	check(found, "and strikes it, though it was not aimed at it")
	if is_instance_valid(quarry):
		quarry.queue_free()
	Abilities.set_tier(player, &"seeker", 3)
	seeker.wait = 0.0
	var pair: Array[HexBolt] = seeker.cast(Vector2.RIGHT)
	check(pair.size() == 2, "seeker III looses two")
	for bolt_: HexBolt in pair:
		bolt_.queue_free()

	print("lunge")
	Abilities.grant(player, &"lunge")
	var lunge: Lunge = player.get_node("Lunge") as Lunge
	check(Abilities.spell(player) == &"lunge", "the lunge takes the damage slot")
	# The level's own enemies off the stretch it lunges along (their bodies would stop it).
	for e: Node in get_nodes_in_group(&"hex_target"):
		if e.has_node("Wound") and (e as Node2D).global_position.distance_to(info.cell_position(at)) < cell * 5.0:
			e.queue_free()
	player.global_position = info.cell_position(at) + Vector2(-cell * 2.5, 16 - 31)
	player.set_physics_process(true)
	await frames(20)
	var start_x: float = player.global_position.x
	check(lunge.cast(1.0), "it lunges")
	await within(func() -> bool: return not lunge.lunging(), 0.6)
	await frames(3)
	var went: float = player.global_position.x - start_x
	check(went > cell * 1.6, "it throws the wizard forward (%.0f px)" % went)
	player.global_position = info.cell_position(at) + Vector2(-cell * 2.5, 16 - 31)
	await frames(20)
	var stuck: Node2D = wisp(at, -cell * 0.5)
	var hp_stuck: int = hp(stuck)
	lunge.wait = 0.0
	lunge.cast(1.0)
	var stabbed: bool = await within(func() -> bool: return hp(stuck) < hp_stuck, 0.6)
	check(stabbed and not stunned(stuck), "and stabs what it reaches on the way, wounding, not stunning")
	player.set_physics_process(false)
	if is_instance_valid(stuck):
		stuck.queue_free()

	print("struck where it is drawn")
	player.global_position = info.cell_position(at) + Vector2(0, 16 - 31)
	var w: Node2D = wisp(at, cell)
	await frames(2)
	var body: Rect2 = SpellStrike.body_of(w)
	check(body.has_area() and body.get_center().y < w.global_position.y - 15.0, "a wisp's body as drawn floats over its feet, and it is struck there")
	# A blow reaching only its tail end, well off the line through its middle, lands; one beside it
	# does not.
	var tail: Vector2 = Vector2(body.position.x + 2.0, body.get_center().y)
	var none: Callable = func(_s: Shaped) -> bool: return false
	check(absf(tail.x - w.global_position.x) > 16.0 and SpellStrike.caught(self, player.global_position, func(p: Vector2) -> bool: return p.distance_to(tail) <= 8.0, none).has(w), "a blow reaching only its tail lands")
	var beside: Vector2 = body.position + Vector2(-30.0, -30.0)
	check(not SpellStrike.caught(self, player.global_position, func(p: Vector2) -> bool: return p.distance_to(beside) <= 8.0, none).has(w), "one beside it does not")
	var mid_y: float = body.get_center().y
	check(HexBolt.crosses(Vector2(body.position.x - 40.0, mid_y), Vector2(body.position.x + 4.0, mid_y), body) and not HexBolt.crosses(Vector2(body.position.x - 40.0, body.position.y - 20.0), Vector2(body.end.x + 40.0, body.position.y - 20.0), body), "a bolt's step through its body crosses it, one over it does not")
	w.queue_free()
	RunState.delete_save()
	finish()
