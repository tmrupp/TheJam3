extends TestKit
## The lodestone golem (Golem, docs/REGIONS_PLAN.md §6), fought in its hall (LodeHall) at the top of
## the crags' gate level: placed in its lair whole, its heart covered; every damage spell tempered in
## its hall, lodestone or none, and not outside it; plain blows glancing off its chunks; an empowered
## slash and an empowered hex bolt each shattering the first chunk in their way to its heart (its far
## forearm, then the next in the way); its heart covered while a plate of its ward is whole, and
## empowered blows breaking their way through to it; bare, wounded by a plain blow, an arrow and a
## parry; lode shards shed, landing on the floor, one taken making the
## wizard's spent empowered cast ready at once, the other left lying while it is ready (all of this
## with the golem held still); a lantern death bringing it back whole; then its moves: asleep until
## the wizard comes into its hall, walking after them along its floor, the slam (its fists raised,
## then down with a shockwave each way along the floor, hurting the wizard), a parried slam stunning
## it and shedding its shards, the shards called home a while later through where the wizard stood
## and regrowing a chunk over its heart, the hurl (a shoulder cap torn off and lobbed at the wizard far
## off, lying where it lands until called home whole), and the leap (the wizard on the top gallery,
## it goes to the gap over it, the landing marked, and leaps up storey by storey); and its last
## wound: it falls apart, its shards go with it, its relic waits where it stood, its gate opens, and
## it is never met again.
## godot --headless --path . --script res://tests/golem_test.gd


func run() -> void:
	MapInfo.debug = false
	var gate: Vector2i = Vector2i(28, Bosses.row_of(&"golem"))
	await boot(28)
	player.set_physics_process(false)
	player.health.max_health = 99
	player.health.health = 99
	await _go(gate)
	print("in its hall")
	var golem: Golem = placed("golem.tscn")[0] as Golem
	check(golem.state == Golem.State.SLEEP, "asleep in its lair")
	_hold(golem)
	var keep: Dictionary = info.world.keep
	var lair: Vector2 = info.cell_position(keep["lair"])
	check(golem.boss == &"golem" and is_equal_approx(golem.global_position.x, lair.x) and info.world.is_ground(info.cell_at(golem.global_position + Vector2(0.0, 8.0))), "in its lair, standing on the ground floor")
	check(golem.chunks_left() == Golem.PART_SIZE.size() and golem.covered() and golem.wound.hp == Golem.HEART and golem.is_in_group(&"hex_target"), "whole: %d chunks, its heart covered, %d wounds to go" % [Golem.PART_SIZE.size(), Golem.HEART])
	for bow: Node in placed("crossbow.tscn"):
		bow.set_physics_process(false)

	print("the hall tempers")
	var empower: Empower = Empower.of(player)
	check(info.run.tempered.is_empty(), "no lodestone touched this run")
	player.global_position = golem.global_position + Vector2(-400.0, -20.0)
	check(empower.tempers_now(), "in its hall the spell in the slot may be cast empowered all the same")
	var outside: Vector2 = info.cell_position(Vector2i((keep["box"] as Rect2i).end.x + 2, (keep["box"] as Rect2i).end.y + 2))
	player.global_position = outside
	check(not empower.tempers_now(), "and not outside it")

	print("chunks")
	var left: Vector2 = golem.heart_center() + Vector2(-260.0, 0.0)
	SpellStrike.strike(golem, Vector2.RIGHT, 3, &"slash", false, left)
	check(golem.chunks_left() == Golem.PART_SIZE.size() and golem.wound.hp == Golem.HEART, "a plain blow glances off its chunks")
	var arm: int = Golem.BACK_FORE
	_slash_from(golem.part_center(arm) + Vector2(-Golem.PART_SIZE[arm].y - Slash.REACH * 0.6, 0.0), Vector2.RIGHT)
	check(not golem.whole[arm] and golem.chunks_left() == Golem.PART_SIZE.size() - 1, "an empowered slash from the side shatters the first chunk in its way: its far forearm")
	var bolt: HexBolt = HexBolt.new()
	bolt.damage = 1
	bolt.dir = Vector2.RIGHT
	bolt.empowered = true
	info.map_elements.add_child(bolt)
	bolt.global_position = left + Vector2(-200.0, 0.0)
	var bored: bool = await within(func() -> bool: return golem.chunks_left() == Golem.PART_SIZE.size() - 2, 2.0)
	check(bored, "an empowered hex bolt shatters the next chunk in its way")
	check(golem.covered(), "a plate of its ward is still whole")
	SpellStrike.strike(golem, Vector2.RIGHT, 3, &"slash", false, left)
	check(golem.covered() and golem.wound.hp == Golem.HEART, "its heart is covered while a plate of its ward is whole: a plain blow glances off")
	var blows: int = 0
	while golem.covered() and blows < 6:
		SpellStrike.strike(golem, Vector2.RIGHT, 1, &"slash", true, left)
		blows += 1
	check(not golem.covered() and Golem.COVERS.all(func(i: int) -> bool: return not golem.whole[i]) and blows <= 3, "empowered blows from the side break through to its heart, its ward all gone (%d more)" % blows)

	print("its heart")
	SpellStrike.strike(golem, Vector2.RIGHT, 0, &"push", false, golem.heart_center() + Vector2(-50.0, 0.0))
	check(golem.wound.hp == Golem.HEART - 1, "bare, a plain blow wounds it, even one of no damage")

	print("lode shards")
	empower.wait = 30.0
	golem.shed_shards()
	check(golem.shards.size() == Golem.SHARDS, "a parried strong attack sheds %d lode shards" % Golem.SHARDS)
	var landed: bool = await within(func() -> bool: return golem.shards.all(func(s: LodeShard) -> bool: return s.landed), 3.0)
	var on_floor: bool = golem.shards.all(func(s: LodeShard) -> bool: return info.world.is_ground(info.cell_at(s.global_position + Vector2(0.0, LodeShard.SIZE + 8.0))))
	check(landed and on_floor, "they fly out, fall, and lie on the floor")
	var first: LodeShard = golem.shards[0]
	var second: LodeShard = golem.shards[1]
	player.global_position = first.global_position
	var taken: bool = await within(gone(first), 1.0)
	check(taken and empower.wait == 0.0 and empower.ready_now(), "one taken makes the spent empowered cast ready at once")
	player.global_position = second.global_position
	await frames(10)
	check(is_instance_valid(second) and not second.is_queued_for_deletion(), "while it is ready, the other is left lying")
	player.global_position = outside

	print("a death heals it")
	info.run.vulnerable = false
	player.die()
	await settle()
	await _go(gate)
	golem = placed("golem.tscn")[0] as Golem
	check(golem.chunks_left() == Golem.PART_SIZE.size() and golem.wound.hp == Golem.HEART and golem.shards.is_empty(), "after a lantern death it is whole again")
	for bow: Node in placed("crossbow.tscn"):
		bow.set_physics_process(false)
	await _moves(golem)
	golem.called.clear()
	_hold(golem)

	print("slain")
	# Its heart bared, and its arms gone so a line from either side reaches it.
	for i: int in Golem.COVERS + Golem.ARMS:
		golem.shatter(i, Vector2.RIGHT)
	golem.shed_shards()
	var shed: Array[int] = []
	for s: LodeShard in golem.shards:
		shed.append(s.get_instance_id())
	var arrow: Bullet = Crossbow.ARROW.instantiate() as Bullet
	arrow.arrow = true
	info.map_elements.add_child(arrow)
	arrow.global_position = golem.heart_center() + Vector2(-400.0, 0.0)
	arrow.setup(Vector2(Crossbow.ARROW_SPEED, 0.0), [], null)
	var pierced: bool = await within(func() -> bool: return golem.wound.hp == Golem.HEART - 1, 2.0)
	check(pierced, "an arrow wounds its bare heart")
	golem.wound.hit(1, Vector2.LEFT)
	check(golem.wound.hp == Golem.HEART - 2, "and so does a parry")
	SpellStrike.strike(golem, Vector2.RIGHT, 1, &"slash", false, golem.heart_center() + Vector2(-260.0, 0.0))
	check(golem.dying and not golem.is_in_group(&"hex_target"), "its last wound, and it falls apart")
	var dead: bool = await within(gone(golem), Golem.DIE_TIME + 3.0)
	await settle()
	check(dead and info.run.bosses.has(&"golem") and placed("golem.tscn").is_empty(), "it is slain for the run")
	check(shed.size() == Golem.SHARDS and shed.all(func(id: int) -> bool: return instance_from_id(id) == null), "its shards go with it")
	var relics: Array[Node] = placed("relic.tscn").filter(func(n: Node) -> bool: return n.get_meta(&"boss", &"") == &"golem")
	check(relics.size() == 1 and info.world.is_ground(info.cell_at((relics[0] as Node2D).global_position) + Vector2i.DOWN) and (relics[0] as Relic).price() == 0, "its relic waits on the floor where it stood, free")
	check(_exit(MapInfo.Exit.DEEPER).sealed() == &"", "and the way up out of the crags is open")
	await _go(gate)
	check(placed("golem.tscn").is_empty(), "it is never met again")
	RunState.delete_save()
	finish()


## Its moves, from asleep in its lair with the wizard out of its hall.
func _moves(golem: Golem) -> void:
	var keep: Dictionary = info.world.keep
	var inside: Rect2i = keep["inside"]
	var floors: Array[int] = keep["floors"]
	var ground: int = inside.end.y - 1
	print("waking")
	player.global_position = info.cell_position(Vector2i((keep["box"] as Rect2i).end.x + 2, (keep["box"] as Rect2i).end.y + 2))
	await within(func() -> bool: return false, 0.5)
	check(golem.state == Golem.State.SLEEP, "asleep while the wizard is out of its hall")
	var lair: Vector2i = keep["lair"]
	var far_x: int = inside.position.x + 1 if lair.x - inside.position.x > inside.end.x - lair.x else inside.end.x - 2
	golem.hurl_wait = INF
	player.global_position = info.cell_position(Vector2i(far_x, ground))
	var woke: bool = await within(func() -> bool: return golem.state != Golem.State.SLEEP, 0.5)
	check(woke, "it wakes as they come into its hall")

	print("walking")
	var was: float = golem.global_position.x
	var toward: float = signf(player.global_position.x - was)
	await within(func() -> bool: return false, 1.0)
	var walked: float = (golem.global_position.x - was) * toward
	check(walked > Golem.WALK * 0.5 and golem.face == int(toward), "it walks after them along its floor, facing them (%d px in a second)" % roundi(walked))
	check(golem.global_position.x >= golem.hall_left + Golem.EDGE - 1.0 and golem.global_position.x <= golem.hall_right - Golem.EDGE + 1.0, "within its hall's walls")

	print("the slam")
	player.global_position = Vector2(golem.global_position.x + toward * 240.0, info.cell_position(Vector2i(0, ground)).y)
	var raised: bool = await within(func() -> bool: return golem.state == Golem.State.SLAM_WARN, 2.0)
	var arm_up: bool = await within(func() -> bool: return golem.fist_at(1).y < golem.global_position.y - 250.0, Golem.SLAM_WARN)
	check(raised and arm_up, "the wizard near on its floor, it raises its fists (the warning)")
	player.end_invulnerable()
	var health: int = player.health.health
	var down: bool = await within(func() -> bool: return golem.state == Golem.State.SLAM, Golem.SLAM_WARN + 0.5)
	await physics_frame
	await physics_frame
	var shocks: Array[Node] = info.map_elements.get_children().filter(func(n: Node) -> bool: return n is GolemShock)
	check(down and not golem.fists.collision.disabled and shocks.size() == 2, "then brings them down, its fists hurting, and a shockwave runs each way along the floor")
	var hurt: bool = await within(func() -> bool: return player.health.health < health, 1.0)
	check(hurt, "the wizard there is hurt")
	await within(func() -> bool: return golem.state == Golem.State.HUNT, 3.0)

	print("a parried slam")
	golem.shatter(Golem.COVERS[0], Vector2.RIGHT)
	player.global_position = Vector2(golem.global_position.x + float(golem.face) * 240.0, player.global_position.y)
	var slamming: bool = await within(func() -> bool: return golem.state == Golem.State.SLAM, 4.0)
	(player.get_node("Parry") as Parry).parry(1, Vector2.ZERO, golem.fists.get_node("Damager"))
	await physics_frame
	await physics_frame
	check(slamming and golem.stunned() and golem.shards.size() == Golem.SHARDS and golem.fists.collision.disabled, "a guard up as its fists come down stuns it, and %d lode shards fly out of it" % Golem.SHARDS)

	print("the recall")
	player.global_position = info.cell_position(Vector2i(far_x, ground))
	var warned: bool = await within(func() -> bool: return golem.state == Golem.State.RECALL_WARN, Parry.STUN + Golem.RECALL_DELAY + 2.0)
	check(warned and golem.called.size() == Golem.SHARDS, "lying a while, they are called back, a warning first")
	var home: bool = await within(func() -> bool: return golem.shards.is_empty() and golem.called.is_empty(), Golem.RECALL_WARN + 4.0)
	check(home and golem.whole[Golem.COVERS[0]], "they fly home, and one regrows the chunk over its heart that was shattered")

	print("the hurl")
	player.global_position = info.cell_position(Vector2i(far_x, ground))
	golem.hurl_wait = 0.0
	var holding: bool = await within(func() -> bool: return golem.state == Golem.State.HURL_WARN, 3.0)
	var held: int = golem.hurling
	check(holding and held == Golem.HURLED[0], "the wizard far off, it tears off a shoulder cap and holds it up (the warning)")
	var thrown: bool = await within(func() -> bool: return not golem.stones.is_empty(), Golem.HURL_WARN + 0.5)
	check(thrown and golem.thrown[held] and not golem.whole[held], "and hurls it, gone from it while it is away")
	golem.hurl_wait = INF
	var lies: bool = await within(func() -> bool: return golem.stones.is_empty() or golem.stones[0].landed, Golem.HURL_FLIGHT + 2.0)
	check(lies and not golem.stones.is_empty(), "it lands and lies")
	var back: bool = await within(func() -> bool: return golem.whole[held] and golem.stones.is_empty(), Golem.RECALL_DELAY + Golem.RECALL_WARN + 6.0)
	check(back and not golem.thrown[held], "until it is called home, whole again")

	print("the leap")
	var stair_x: int = (keep["stairs"] as Array[Rect2i])[0].position.x
	player.global_position = info.cell_position(Vector2i(stair_x + 4 if stair_x + 4 < inside.end.x - 1 else stair_x - 3, floors[0] - 1))
	var crouched: bool = await within(func() -> bool: return golem.state == Golem.State.LEAP_WARN, 15.0)
	check(crouched and golem.storey() == 2 and absf(golem.leap_to.y - golem.floor_y(1)) < 1.0, "the wizard on the top gallery, it goes to the gap over it, the spot it will land on marked")
	var up: bool = await within(func() -> bool: return golem.storey() == 1 and golem.state != Golem.State.LEAP, Golem.LEAP_WARN + Golem.LEAP_TIME + 1.0)
	check(up and info.world.is_ground(info.cell_at(golem.global_position + Vector2(0.0, 8.0))), "and leaps up through it, landing on the gallery")
	var top: bool = await within(func() -> bool: return golem.storey() == 0, 15.0)
	check(top, "and on up to the top gallery after them")


## Hold `golem` still where it is (resting for ever), so only what a check does to it happens.
func _hold(golem: Golem) -> void:
	golem.state = Golem.State.REST
	golem.timer = INF


## An empowered slash (tier I, ready at once) from `at` (the spell's own origin) heading `dir`, the
## wizard there just for it; then the wizard back where they were.
func _slash_from(at: Vector2, dir: Vector2) -> void:
	var was: Vector2 = player.global_position
	Abilities.set_tier(player, &"slash", 1)
	player.global_position = at - (SpellStrike.origin(player) - player.global_position)
	var slash: Slash = player.get_node("Slash") as Slash
	slash.wait = 0.0
	slash.cast(dir, true)
	player.global_position = was


## Load place `at` (arriving at its way back) and wait for it.
func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)


## The place's exit `which`.
func _exit(which: int) -> LevelExit:
	for n: Node in placed("level_exit.tscn"):
		if (n as LevelExit).exit == which:
			return n as LevelExit
	return null
