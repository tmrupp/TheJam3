extends TestKit
## suite: full (over 15 s: the quick run leaves it to the full one, docs/PERF_PLAN.md 1.2)
## The tutorial (Tutorial): laid out by hand, the same in every world, with its
## start and lantern, its control cards (ControlHint), its key and door of one colour, and stars
## enough for the shrine. A run begun with the tutorial starts in it by its lit lantern; its way out
## comes out by the start level's door into it, which every start level has, laid last (nearest the
## way in), and leads back in at the way out. Coming out marks it done, so the start menu's toggle
## starts off from then on. A card rises as the wizard comes near and goes once its control is used.
## The stretches that need the wizard's reach (the steps, the bed of thorns a jump clears, the one
## only a jump and a dash clear, and the wider one a jump and a dash fall short of, crossed by dashing
## again once the moon over it has given the dash back) are crossed with the game's own controls. The utility spell's card
## costs a wizard at full health a heart as it rises, which pressing Utility (mend) heals. The
## watcher hovers out of reach: a jump, a dash up and a slash at the top fall short of it, while a
## shot of its own turned back by the guard flies home and wounds it. Its card is the parry's,
## standing where the watcher first sees the wizard, gone by a catch and not by a press; past it a
## bed of thorns too
## wide for a jump and a dash is crossed by bouncing off its thorns with the guard (a pogo), which
## puts the pogo's card away. Past the utility card, a lantern lit does not fill the draught mend
## just drank; interacting with it again burns it into mend, filling it and leaving the wizard
## unprotected, which puts the burn card away (it is not put away by a press); a lantern past it
## protects them again. Its shrine
## offers a strict upgrade against a swap (Tutorial.BOONS), then the usual boons once one is known.
## godot --headless --path . --script res://tests/tutorial_test.gd

## The cells the reach checks start from and must get past (Tutorial.MAP): standing before the
## first step; and running at each bed of thorns from three cells before its edge, the first a jump
## clears, the second only a jump and a dash.
const STEPS_FROM: Vector2i = Vector2i(10, 10)
const STEPS_PAST: int = 18
const THORNS_FROM: Vector2i = Vector2i(21, 10)
const THORNS_PAST: int = 26
const GAP_FROM: Vector2i = Vector2i(33, 10)
const GAP_PAST: int = 39
const MOON_FROM: Vector2i = Vector2i(42, 10)
const MOON_PAST: int = 49
## How far past the middle of the last cell before a bed (px) the wizard jumps.
const JUMP_AT: float = 30.0
## The pogo's bed of thorns, found in the map's floor row by its width; and how far under standing
## height (px), falling into the bed (its thorns are a row down), the wizard raises the guard to
## catch them.
const POGO_BED: String = "^^^^^^^^^^"
const GUARD_AT: float = 40.0


func run() -> void:
	var at: Vector2i = Tutorial.of(28)
	_layout(at)
	_start_levels()
	await boot(28, true)
	DirAccess.remove_absolute(Tutorial.settings_path)
	await _arrival(at)
	await _hint()
	await _reach()
	await _parry()
	await _pogo()
	await _utility()
	await _burn()
	await _shrine()
	await _out_and_in(at)
	RunState.delete_save()
	DirAccess.remove_absolute(Tutorial.settings_path)
	finish()


func _layout(at: Vector2i) -> void:
	print("layout")
	var w: LevelGen = build(at)
	var elsewhere: LevelGen = build(Tutorial.of(-4013))
	check(w != null, "the tutorial is laid out")
	if w == null:
		return
	check(elsewhere != null and elsewhere.objects == w.objects, "and in every world")
	check(w.exits.keys() == [MapInfo.Exit.BACK], "its way out is its one exit")
	check(w.is_valid(w.start) and w.is_valid(w.start_lantern) and w.get_cell(w.start_lantern).type == LevelGen.Type.CHECKPOINT, "a run starts by its lantern")
	check_eq(count_of(w, LevelGen.Type.HINT), Tutorial.MAP.reduce(func(n: int, row: String) -> int:
			return n + Array(row.split("")).filter(func(c: String) -> bool: return Tutorial.HINTS.has(c)).size(), 0), "a control card for every digit of the map")
	var keys: Array[Vector2i] = w.objects.filter(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.KEY)
	var doors: Array[Vector2i] = w.objects.filter(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.DOOR)
	check(keys.size() == 1 and doors.size() == 1 and w.get_cell(keys[0]).extra_info == w.get_cell(doors[0]).extra_info, "one key and one door, of the same colour")
	var stars: int = count_of(w, LevelGen.Type.COIN) + count_of(w, LevelGen.Type.CLUSTER) * Rules.cluster_value(0)
	check(stars >= Abilities.price(0, 1), "stars enough on the way for the shrine (%d, a first tier costs %d)" % [stars, Abilities.price(0, 1)])
	check_eq(count_of(w, LevelGen.Type.SHRINE), 1, "a shrine")


func _start_levels() -> void:
	print("the start levels' door")
	var kind: int = Tutorial.kind_number()
	var door: int = Worlds.door(kind)
	var all_have: bool = true
	for x: int in [28, 29, -7, 1003]:
		var w: LevelGen = build(Vector2i(x, 0))
		all_have = all_have and w != null and w.exits.has(door) and w.get_cell(w.exits[door]).type == LevelGen.Type.EXIT
	check(all_have, "every start level has a door into its tutorial")
	var lead: Dictionary = Rules.def_for(Vector2i(28, 0)).lead(door)
	check(lead.get("to") == Tutorial.of(28) and lead.get("arrive") == MapInfo.Exit.BACK, "which leads in at its way out")
	var out: Dictionary = Rules.def_for(Tutorial.of(28)).lead(MapInfo.Exit.BACK)
	check(out.get("to") == Vector2i(28, 0) and out.get("arrive") == door, "and the way out comes out by that door")
	check(not build(Vector2i(28, 1)).exits.has(door) and not Rules.def_for(Vector2i(28, -1)).doors.has(kind), "no other row has one")
	check_eq(Rules.def_for(Vector2i(28, 0)).price(door, LevelRecord.new()), 0, "it costs nothing")


func _arrival(at: Vector2i) -> void:
	print("starting in it")
	check_eq(info.coord, at, "a run begun with the tutorial starts in it")
	check(player.global_position.distance_to(info.cell_position(info.world.start)) < 80.0, "by its start")
	check(info.run.respawn_coord == at and info.run.respawn_cell == info.world.start_lantern, "its lantern lit")
	check(not Tutorial.done(), "not yet done")


func _hint() -> void:
	print("a card")
	var cards: Array[Node] = placed("control_hint.tscn")
	var jump: ControlHint = null
	for n: Node in cards:
		if (n as ControlHint).action == &"Jump":
			jump = n as ControlHint
	check(jump != null, "the jump's card is there")
	if jump == null:
		return
	check(not jump.showing(), "down while the wizard is far")
	player.global_position = jump.global_position
	still()
	check(await until(func() -> bool: return jump.showing() and jump.up_for >= ControlHint.SEEN), "up as they come near")
	press(&"Jump", true)
	await physics_frame
	press(&"Jump", false)
	await settle(30)
	check(ControlHint.learned.has(&"Jump") and not jump.showing(), "and gone once they jump")


## The card of control `action`, or null.
func _card(action: StringName) -> ControlHint:
	for n: Node in placed("control_hint.tscn"):
		if (n as ControlHint).action == action:
			return n as ControlHint
	return null


## How near (px) a watcher's shot comes before the guard goes up to meet it (the guard is up for
## Parry.WINDOW; the shot strikes the wizard a little nearer than this), and how many game seconds
## the watcher has to see the wizard, fire and its shot arrive.
const MEET_AT: float = 80.0
const SHOT_WAIT: float = 15.0


## The watcher and its card, the parry's, on the Spell button: the watcher hovers in view, and a
## slash or a hex bolt that strikes it glances off; its card stands where its first shot comes at
## the wizard and is put away by a catch, not by a press; and a shot of its own, turned back, flies
## home and wounds it.
func _parry() -> void:
	print("the watcher and the parry card")
	var card: ControlHint = _card(ControlHint.PARRY)
	check(card != null and ControlHint.actions(ControlHint.PARRY) == [&"Spell"], "the watcher's card is the parry's, on the Spell button")
	# The spell is on a face button and the left trigger alike; a pad card lights both.
	var parts: Array[RisoPad.Part] = RisoPad.parts_of(&"Spell")
	check(parts.size() == 2 and parts[0] == RisoPad.Part.FACE_LEFT and parts.has(RisoPad.Part.LEFT_TRIGGER), "the spell's pad card lights its face button and the left trigger")
	var watchers: Array[Node] = placed("shooter_enemy.tscn")
	check_eq(watchers.size(), 1, "one watcher")
	if card == null or watchers.size() != 1:
		return
	# The wisp left behind, so nothing else comes at the wizard here.
	for n: Node in placed("mover_enemy.tscn"):
		n.queue_free()
	var watcher: RigidBody2D = watchers[0] as RigidBody2D
	var eye: Shooter = watcher.get_node("Shooter") as Shooter
	var wound: Wound = watcher.get_node("Wound") as Wound
	var hurts: Array[int] = []
	var glanced: Array[Vector2] = []
	wound.hurt.connect(func(d: int) -> void: hurts.append(d))
	wound.warded.connect(func(dir: Vector2) -> void: glanced.append(dir))
	await _go(Vector2i(info.cell_at(watcher.global_position).x, 10))
	check(await until(func() -> bool: return eye.home.is_finite()), "it hovers")
	check(eye.hovering and not int(watcher.get_meta(&"bounces", 0)) > 0, "its shots flying straight")
	check(wound.parried_only, "and only a parried shot wounds it")
	# Held still, its shots put away: a slash that reaches it, and a hex bolt, glance off.
	eye.set_physics_process(false)
	freeze()
	player.global_position = watcher.global_position + Vector2(-90, 10)
	still()
	Input.action_press("Right")
	player.get_node("Slash").call(&"cast_spell", false)
	Input.action_release("Right")
	await settle(10)
	check(glanced.size() == 1 and hurts.is_empty(), "a slash glances off it, unhurt")
	var bolt: HexBolt = HexBolt.new()
	bolt.dir = Vector2.RIGHT
	info.map_elements.add_child(bolt)
	bolt.global_position = watcher.global_position + Vector2(-240, 0)
	await until(gone(bolt))
	check(glanced.size() == 2 and hurts.is_empty(), "and so does a hex bolt")
	for n: Node in Stage.main().get_children():
		if n is Bullet:
			n.queue_free()
	player.set_physics_process(true)
	eye.charge = 0.0
	eye.set_physics_process(true)
	# The card stands where the watcher's first shot comes at the wizard: it rises as they come to it.
	await _go(info.cell_at(card.global_position))
	check(await until(func() -> bool: return card.showing() and card.up_for >= ControlHint.SEEN), "the card is up as they come near")
	check(await until(func() -> bool: return eye.sees), "where the watcher sees them")
	var guard: Parry = player.get_node("Parry") as Parry
	player.health.health = player.health.max_health
	await frames(2)
	# A press with nothing coming: the card stays.
	var spell: Node = player.get_node("Slash")
	spell.call(&"refill")
	press(&"Spell", true)
	await physics_frame
	press(&"Spell", false)
	await settle(10)
	check(card.showing() and not ControlHint.learned.has(ControlHint.PARRY), "a press alone does not put it away")
	# Its shot, met with the guard as it comes.
	spell.call(&"refill")
	var meet: Callable = func() -> bool:
		for n: Node in Stage.main().get_children():
			var b: Bullet = n as Bullet
			if b != null and not b.is_queued_for_deletion() and b.global_position.distance_to(player.global_position) < MEET_AT:
				return true
		return false
	check(await within(meet, SHOT_WAIT), "the watcher fires at them")
	press(&"Spell", true)
	await physics_frame
	press(&"Spell", false)
	check(await within(func() -> bool: return guard.glory(), 1.0), "the guard catches its shot")
	check(await within(func() -> bool: return not hurts.is_empty() or not is_instance_valid(watcher), 3.0), "which flies home and wounds it")
	check_eq(player.health.health, player.health.max_health, "the wizard unhurt")
	check(ControlHint.learned.has(ControlHint.PARRY) and not card.showing(), "and the catch puts the card away")
	# Gone, so it leaves the stretches past it alone.
	if is_instance_valid(watcher):
		watcher.queue_free()
	await settle(4)


## The bed of thorns past the watcher: too wide for a jump and a dash, crossed by bouncing off its
## thorns, catching them underfoot with the guard; the pogo's card goes once they have.
func _pogo() -> void:
	print("the pogo")
	var start: int = Tutorial.MAP[11].find(POGO_BED)
	check(start > 0, "a bed of %d thorns" % POGO_BED.length())
	if start <= 0:
		return
	var from: Vector2i = Vector2i(start - 3, 10)
	var past: int = start + POGO_BED.length()
	var card: ControlHint = _card(ControlHint.POGO)
	check(card != null and info.cell_at(card.global_position).x < start, "the pogo's card stands at its edge")
	Health.invincible = true
	check(not await _leap(from, past, 1), "a jump and a dash fall short of it")
	Health.invincible = false
	player.health.health = player.health.max_health
	await _go(from)
	player.global_position = card.global_position
	check(await until(func() -> bool: return card.showing() and card.up_for >= ControlHint.SEEN), "its card is up at its edge")
	await settle(4)
	await _go(from)
	var guard: Parry = player.get_node("Parry") as Parry
	var bounced_from: float = guard.pogo_at
	var stand: float = player.global_position.y
	var edge: float = info.cell_position(from + Vector2i(2, 0)).x + JUMP_AT
	var jumped: bool = false
	var left: bool = false
	var dashed: bool = false
	var guarding: int = 0
	var over: bool = false
	Input.action_press("Right")
	for i: int in range(600):
		if not jumped and player.global_position.x >= edge:
			press(&"Jump", true)
			jumped = true
		elif jumped and not player.is_on_floor():
			# A dash at the top of each arc (a catch gives it back), the guard up just over the thorns.
			if not dashed and player.velocity.y > -150.0 and player.velocity.y < 0.0:
				press(&"Dash", true)
				dashed = true
			if guarding == 0 and player.velocity.y > 0.0 and player.global_position.y > stand + GUARD_AT:
				press(&"Spell", true)
				guarding = 1
		await physics_frame
		if guarding > 0:
			guarding += 1
			if guarding == 4:
				press(&"Spell", false)
			if player.velocity.y < 0.0 and guarding > 4:
				# Bounced: the next arc gets its own dash and guard.
				guarding = 0
				dashed = false
				press(&"Dash", false)
		left = left or (jumped and not player.is_on_floor())
		if left and player.is_on_floor() and player.velocity.y >= 0.0:
			var cell: Vector2i = info.cell_at(player.global_position)
			over = cell.x >= past and cell.y == from.y
			break
	_release()
	press(&"Spell", false)
	await frames(10)
	check(guard.pogo_at > bounced_from, "the guard catches the thorns underfoot and bounces them up")
	check(over, "bouncing off its thorns, they cross it")
	check(ControlHint.learned.has(ControlHint.POGO), "and the pogo's card goes")


func _utility() -> void:
	print("the utility card")
	var card: ControlHint = null
	for n: Node in placed("control_hint.tscn"):
		if (n as ControlHint).action == ControlHint.STRIKES:
			card = n as ControlHint
	check(card != null, "the utility spell's card is there")
	if card == null:
		return
	check_eq(Abilities.spell(player, &"utility"), ControlHint.HEALS, "and the run holds mend")
	var full: int = player.health.max_health
	player.health.health = full
	player.global_position = card.global_position
	still()
	check(await until(func() -> bool: return card.struck), "it strikes as it rises")
	check(player.health.health < full, "costing the wizard a heart")
	check(await until(func() -> bool: return card.up_for >= ControlHint.SEEN), "up long enough to be seen")
	press(Abilities.UTILITY_ACTION, true)
	await physics_frame
	press(Abilities.UTILITY_ACTION, false)
	await settle(10)
	check_eq(player.health.health, full, "Utility heals them, with mend")
	check(ControlHint.learned.has(ControlHint.STRIKES) and not card.showing(), "and the card goes")
	await _go(info.cell_at(card.global_position))
	check_eq(player.health.health, full, "it strikes once")


## The burn card and its lantern, then the lantern past it.
func _burn() -> void:
	print("burning a lantern into mend")
	var card: ControlHint = _card(ControlHint.BURN)
	check(card != null, "the burn card is there")
	if card == null:
		return
	var mend: Mend = player.get_node("Mend") as Mend
	check_eq(mend.draughts(), 0, "mend's draught is drunk (the utility card)")
	var lanterns: Array[Node] = placed("checkpoint.tscn").filter(func(n: Node) -> bool: return (n as Node2D).global_position.x > card.global_position.x)
	lanterns.sort_custom(func(a: Node, b: Node) -> bool: return (a as Node2D).global_position.x < (b as Node2D).global_position.x)
	check_eq(lanterns.size(), 2, "a lantern by the card, and one past it")
	if lanterns.size() < 2:
		return
	var first: Node2D = lanterns[0] as Node2D
	await _go(info.cell_at(first.global_position))
	check(await until(func() -> bool: return card.showing() and card.up_for >= ControlHint.SEEN), "the card is up by its lantern")
	await _interact()
	check(info.is_respawn_lantern(first), "a press lights the lantern")
	check_eq(mend.draughts(), 0, "lighting it does not fill the draught")
	check(info.can_burn(first), "it can be burned now")
	check(not ControlHint.learned.has(ControlHint.BURN) and card.showing(), "the card stays up for a press")
	await _interact()
	check(info.is_lantern_spent(first) and info.run.vulnerable, "a second press burns it out: the wizard is unprotected")
	check_eq(mend.draughts(), mend.draughts_max(), "and mend's draught is filled")
	check(ControlHint.learned.has(ControlHint.BURN), "which puts the card away")
	await settle(10)
	check(not card.showing(), "and it is down")
	var second: Node2D = lanterns[1] as Node2D
	await _go(info.cell_at(second.global_position))
	await _interact()
	check(info.is_respawn_lantern(second) and not info.run.vulnerable, "the lantern past it protects them again")
	check(not info.can_burn(second), "and, mend full, cannot be burned")


## Press and let go of the interact button.
func _interact() -> void:
	press(&"Discover", true)
	await frames(2)
	press(&"Discover", false)
	await frames(2)


func _shrine() -> void:
	print("the shrine")
	var shrines: Array[Node] = placed("shrine.tscn")
	check_eq(shrines.size(), 1, "one shrine")
	if shrines.is_empty():
		return
	var shrine: Shrine = shrines[0] as Shrine
	check_eq(shrine.offers(), Tutorial.BOONS, "it offers the tutorial's own boons")
	check(not shrine.swap(0) and shrine.swap(1), "a strict upgrade, and a swap")
	check_eq(Abilities.spell(player), &"slash", "the swap's slot holds the slash")
	player.collect(shrine.offer_price(1) - player.coins.coins)
	shrine.buy_boon(1)
	check_eq(Abilities.spell(player), &"hex", "taking the swap puts hex in the damage slot")
	check(shrine.used(), "and spends the shrine")
	check(info.here.boons(player).is_empty(), "with one known, the usual boons come back")


## The two stretches that need the wizard's reach, crossed with the game's controls.
func _reach() -> void:
	print("reach")
	Health.invincible = true
	# Up the steps: walk right, jumping at each.
	await _go(STEPS_FROM)
	var steps: bool = false
	for i: int in range(240):
		Input.action_press("Right")
		if i % 30 == 0:
			press(&"Jump", true)
		elif i % 30 == 18:
			press(&"Jump", false)
		await physics_frame
		if info.cell_at(player.global_position).x >= STEPS_PAST:
			steps = true
			break
	_release()
	check(steps, "the steps are climbed by jumping")
	# Over the beds of thorns: the first by a running jump; the second only with a dash at the top.
	check(await _leap(THORNS_FROM, THORNS_PAST, 0), "the first bed of thorns is cleared by a jump")
	check(not await _leap(GAP_FROM, GAP_PAST, 0), "a jump alone falls short of the second")
	check(await _leap(GAP_FROM, GAP_PAST, 1), "which is cleared by a jump and a dash")
	# The moon's bed: a jump and a dash fall short; the moon over it gives the dash back for another.
	check_eq(placed("moon.tscn").size(), 1, "a moon over the third bed")
	check(not await _leap(MOON_FROM, MOON_PAST, 1), "a jump and a dash fall short of the third bed")
	check(await _leap(MOON_FROM, MOON_PAST, 2), "which is cleared by dashing again once the moon gives the dash back")
	Health.invincible = false


## Run right from `from` and jump from the edge two cells on, dashing at the top of the jump when
## `dashes` is 1 or more, and again as soon as the dash is back (a moon's) when it is 2: whether the
## wizard lands at its height at or past column `past`.
func _leap(from: Vector2i, past: int, dashes: int) -> bool:
	await _go(from)
	var rose: bool = false
	var over: bool = false
	var dashed: int = 0
	var edge: float = info.cell_position(from + Vector2i(2, 0)).x + JUMP_AT
	Input.action_press("Right")
	for i: int in range(180):
		if player.global_position.x >= edge and not rose and not Input.is_action_pressed("Jump"):
			press(&"Jump", true)
		rose = rose or player.velocity.y < -300.0
		if dashed == 0 and dashes >= 1 and rose and player.velocity.y > -150.0:
			press(&"Dash", true)
			dashed = 1
		elif dashed == 1 and player.velocity.x >= Player.DASH_SPEED * 0.9:
			dashed = 4
		elif dashed == 4 and dashes >= 2 and player.velocity.x < Player.DASH_SPEED * 0.9:
			# The first dash under way (4) is over: let go, then dash again once it is back.
			press(&"Dash", false)
			dashed = 2
		elif dashed == 2 and not player.dash.acted:
			press(&"Dash", true)
			dashed = 3
		await physics_frame
		if rose and player.is_on_floor():
			var cell: Vector2i = info.cell_at(player.global_position)
			over = cell.x >= past and cell.y == from.y
			break
	_release()
	await frames(10)
	return over


## Put the wizard on cell `v`, at rest.
func _go(v: Vector2i) -> void:
	freeze()
	player.global_position = info.cell_position(v)
	still()
	player.set_physics_process(true)
	await settle(20)


func _release() -> void:
	for a: StringName in [&"Left", &"Right", &"Jump", &"Dash"]:
		Input.action_release(a)
		press(a, false)


func _out_and_in(at: Vector2i) -> void:
	print("out and back")
	var door: int = Worlds.door(Tutorial.kind_number())
	info.travel(MapInfo.Exit.BACK)
	await settle()
	check(info.coord == Vector2i(28, 0), "the way out leads to the start level")
	check(player.global_position.distance_to(info.cell_position(info.world.exits.get(door, Vector2i(-1, -1)))) < 80.0, "coming out by its door")
	check(Tutorial.done(), "and marks the tutorial done")
	info.travel(door)
	await settle()
	check(info.coord == at and player.global_position.distance_to(info.cell_position(info.world.exits[MapInfo.Exit.BACK])) < 80.0, "the door leads back in, at the way out")
