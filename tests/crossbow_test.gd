extends TestKit
## The crags' crossbows built into the towers' walls (Crossbow, CragsArchetype.place_crossbows) and
## the keeps' (place_keep_crossbows), and their rock-bug nests (BugNest). Laid out: crossbows turn up
## across the band in towers and keeps, each set into a cell of the building's wall that stays whole
## stone, with open air outside and a free room cell inside (its own cell in the level), facing
## out, no more than the preset's most to a tower, the keeps' apart, and the same every build; no
## nest is in a building. In play: the crossbow sits in the wall, which stays solid; it looses
## arrows dead straight at the wizard outside in front of its slit (not at one well above it, nor
## at the wizard in the room behind it), the first after its draw and the next only once it has
## reloaded; an arrow wounds an enemy in its way; a
## hex bolt or a slash from outside stops at the wall and leaves it whole; from the room, a slash
## and bolts of no damage wound it, and it breaks, the level record keeps it broken, and
## the wall stays whole. A nest is wounded by a slash and bolts of no damage too, and destroyed.
## godot --headless --path . --script res://tests/crossbow_test.gd


func run() -> void:
	if not needs([&"crags"]):
		finish()
		return
	var at: Vector2i = generation()
	check(at != Vector2i.ZERO, "a crag level with a crossbow and a nest to play (%s)" % at)
	if at == Vector2i.ZERO:
		finish()
		return
	await boot(at.x)
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.health.max_health = 99
	player.health.health = 99
	player.set_physics_process(false)
	var cell: float = float(info.tile_map.tile_set.tile_size.y) * info.tile_map.global_scale.y
	await shooting(cell)
	await nest(cell)
	player.set_physics_process(true)
	RunState.delete_save()
	finish()


## Crossbows over the crags of several worlds; returns a place with a crossbow that has open air
## in front of its slit and a nest, to play (ZERO if none).
func generation() -> Vector2i:
	print("generation")
	var found: int = 0
	var in_keeps: int = 0
	var levels: int = 0
	var bad: Array[String] = []
	var play: Vector2i = Vector2i.ZERO
	var most: int = maxi(1, floori(float(CragsArchetype.CROSSBOWS_MOST) * Difficulty.foes()))
	for world: int in [28, 29, 30]:
		for k: int in range(Bands.rows_of(&"crags")):
			var place: Vector2i = Vector2i(world, NextWorldDef.band_row(&"crags", k))
			var w: LevelGen = build(place)
			if w == null:
				continue
			levels += 1
			var bows: Array[Vector2i] = w.objects_of(LevelGen.Type.CROSSBOW)
			found += bows.size()
			var per_tower: Dictionary = {}
			var kept: Array[Vector2i] = []
			for v: Vector2i in bows:
				var how: Dictionary = w.get_cell(v).extra_info
				# The golem's hall's own, shooting into the hall, are lode_hall_test's.
				if bool(how.get("inward", false)):
					found -= 1
					continue
				var facing: int = int(how["facing"])
				var wall: Vector2i = v + Vector2i(facing, 0)
				var out: Vector2i = wall + Vector2i(facing, 0)
				if w.structures.get(wall, &"") == &"keep":
					in_keeps += 1
					if not w.interiors.has(v) or w.interiors.has(out):
						bad.append("%s %s not before a keep's hall" % [place, v])
					if kept.any(func(o: Vector2i) -> bool: return LevelGen.dist(o, v) < CragsArchetype.KEEP_CROSSBOW_APART):
						bad.append("%s %s keep crossbows too close" % [place, v])
					kept.append(v)
					if not w.masonry.has(wall) or not w.is_ground(wall) or w.is_ground(out):
						bad.append("%s %s not set in whole stone with air outside" % [place, v])
					continue
				var tower: int = -1
				for i: int in range(w.towers.size()):
					if (w.towers[i]["box"] as Rect2i).has_point(v):
						tower = i
				if tower < 0:
					bad.append("%s %s not in a tower" % [place, v])
					continue
				per_tower[tower] = int(per_tower.get(tower, 0)) + 1
				if absi(facing) != 1 or not w.interiors.has(v):
					bad.append("%s %s not a room cell" % [place, v])
				if not w.masonry.has(wall) or not w.is_ground(wall) or w.is_ground(out):
					bad.append("%s %s not set in whole stone with air outside" % [place, v])
			for t: int in per_tower:
				if int(per_tower[t]) > most:
					bad.append("%s: %d crossbows in one tower" % [place, per_tower[t]])
			var nests: Array[Vector2i] = w.objects_of(LevelGen.Type.NEST)
			if nests.any(func(v: Vector2i) -> bool: return w.structures.has(v)):
				bad.append("%s: a nest in a building" % place)
			var again: LevelGen = build(place)
			if again.objects_of(LevelGen.Type.CROSSBOW) != bows or bows.any(func(v: Vector2i) -> bool: return str(again.get_cell(v).extra_info) != str(w.get_cell(v).extra_info)):
				bad.append("%s: not the same every build" % place)
			if play == Vector2i.ZERO and not nests.is_empty() and bows.any(func(v: Vector2i) -> bool: return not bool((w.get_cell(v).extra_info as Dictionary).get("inward", false)) and _open_in_front(w, v) and w.structures.get(v + Vector2i(int((w.get_cell(v).extra_info as Dictionary)["facing"]), 0), &"") == &"tower"):
				play = place
	check(found - in_keeps > levels and in_keeps >= levels, "crossbows turn up across the band, in towers and keeps (%d in towers and %d in keeps in %d levels)" % [found - in_keeps, in_keeps, levels])
	check(bad.is_empty(), "each set in a tower's wall of whole stone with air outside and a room cell inside, no more than %d to a tower, no nest in a building, the same every build %s" % [most, bad])
	return play


## Whether crossbow `v` has three cells of open air in front of its slit.
static func _open_in_front(w: LevelGen, v: Vector2i) -> bool:
	var facing: int = int((w.get_cell(v).extra_info as Dictionary)["facing"])
	for k: int in range(2, 5):
		var c: Vector2i = v + Vector2i(facing * k, 0)
		if not w.is_valid(c) or w.is_ground(c):
			return false
	return true


func shooting(cell: float) -> void:
	print("shooting")
	var bow: Crossbow = null
	for n: Node in placed("crossbow.tscn"):
		var b: Crossbow = n as Crossbow
		var clear: bool = true
		for k: int in range(2, 5):
			clear = clear and not info.solid_at(info.cell_position(b.cell) + Vector2(float(b.facing) * cell * float(k), 0.0))
		if clear:
			bow = b
			break
	check(bow != null, "a crossbow with open air before its slit")
	if bow == null:
		return
	var f: float = float(bow.facing)
	var room: Vector2 = info.cell_position(bow.cell)
	var wound: Wound = bow.get_node("Wound") as Wound
	check(bow.is_in_group(&"hex_target") and wound != null and wound.least == 1, "an enemy, wounded by any blow")
	check(info.solid_at(bow.global_position) and not info.solid_at(room), "it sits in the wall, which is solid, before its room cell")
	# Outside, in front of its slit: it draws and looses an arrow at the wizard.
	var outside: Vector2 = room + Vector2(f * cell * 3.0, 0.0)
	player.global_position = outside
	info.loader.wake_around(outside)
	check(await within(func() -> bool: return not _arrows().is_empty(), Crossbow.FIRST_DRAW + 0.5), "it looses an arrow at the wizard outside, almost at once")
	var arrow: Bullet = _arrows()[0] if not _arrows().is_empty() else null
	check(arrow != null and Damager.attacker_of(arrow.get_node("HitBox/Damager")) == bow and signf(arrow.velocity.x) == f and arrow.velocity.y == 0.0, "an arrow of its own, flying straight out")
	# Then it reloads before the next.
	for a: Bullet in _arrows():
		a.queue_free()
	check(not bow.loaded(), "it reloads")
	var early: bool = await within(func() -> bool: return not _arrows().is_empty(), Crossbow.RELOAD * 0.8 / Difficulty.attack())
	check(not early, "and looses no other arrow for a while")
	var again: bool = await within(func() -> bool: return not _arrows().is_empty(), Crossbow.RELOAD + Crossbow.DRAW + 1.0)
	check(again, "then another")
	check(not bow.first, "drawn at the plain speed, the wizard not out of sight meanwhile")
	# An arrow wounds an enemy in its way.
	# (The wizard out of its way, no other arrow about, and the wisp held still in it.)
	player.global_position = Vector2(-9000, -9000)
	for a: Bullet in _arrows():
		a.queue_free()
	var wisp: Node2D = Placeables.scene(LevelGen.Type.ENEMY).instantiate() as Node2D
	LevelLoader.arm(wisp, info.here.depth)
	info.map_elements.add_child(wisp)
	for c: Node in wisp.get_children():
		if c is Stunnable:
			c.set_physics_process(false)
	wisp.global_position = bow.muzzle() + Vector2(f * cell * 0.8, 0.0)
	var wisp_wound: Wound = wisp.get_node("Wound") as Wound
	var wisp_hp: int = wisp_wound.hp
	var shot: Bullet = Crossbow.ARROW.instantiate() as Bullet
	shot.arrow = true
	info.map_elements.add_child(shot)
	shot.global_position = bow.muzzle()
	shot.setup(Vector2(f * Crossbow.ARROW_SPEED, 0.0), [bow], bow)
	var struck: bool = await within(func() -> bool: return not is_instance_valid(wisp) or wisp_wound.hp < wisp_hp, 2.0)
	check(struck and (not is_instance_valid(shot) or shot.is_queued_for_deletion()), "an arrow wounds an enemy in its way, and is spent")
	if is_instance_valid(wisp):
		wisp.queue_free()
	# Not at the wizard well above its slit.
	for a: Bullet in _arrows():
		a.queue_free()
	player.global_position = outside + Vector2(0.0, -cell * 1.5)
	check(await within(func() -> bool: return not bow.sees, 1.0), "nor at one well above its slit")
	player.global_position = outside
	# A bolt or a slash from outside stops at the wall: it stays whole. (The slash, at II, would
	# reach it but for the stone, from just outside the wall's face.)
	var hp: int = wound.hp
	_bolt(outside, Vector2(-f, 0.0), 2)
	await frames(40)
	_slash(bow.muzzle(), Vector2(-f, 0.0), 2)
	check(is_instance_valid(bow) and wound.hp == hp, "a bolt or a slash from outside stops at the wall")
	# In the room behind it: it does not shoot.
	var inside: Vector2 = room - Vector2(f * cell * 0.3, 0.0)
	player.global_position = inside
	for a: Bullet in _arrows():
		a.queue_free()
	await frames(5)
	await within(func() -> bool: return false, Crossbow.DRAW + 1.0)
	check(_arrows().is_empty() and not bow.sees, "nor at the wizard in the room behind it")
	# From the room, a slash and bolts of no damage break it, and it stays broken.
	var at: Vector2i = bow.get_meta(&"cell")
	var wall: Vector2 = room + Vector2(f * cell, 0.0)
	_slash(room, Vector2(f, 0.0), 1)
	check(not is_instance_valid(bow) or wound.hp == hp - 1, "a slash at it from the room wounds it")
	for i: int in range(hp):
		if not is_instance_valid(bow):
			break
		_bolt(inside, Vector2(f, 0.0), 0)
		await frames(20)
	check(not is_instance_valid(bow) or bow.is_queued_for_deletion(), "and bolts of no damage break it (%d)" % hp)
	check(info.record().slain.has(at), "the level record keeps it broken")
	check(info.solid_at(wall), "and the wall stays whole")


func nest(cell: float) -> void:
	print("nest")
	var all: Array[Node] = placed("bug_nest.tscn")
	check(not all.is_empty(), "the level has nests")
	if all.is_empty():
		return
	var host: BugNest = all[0] as BugNest
	var wound: Wound = host.get_node("Wound") as Wound
	check(wound.least == 1, "wounded by any blow")
	var at: Vector2i = host.get_meta(&"cell")
	var hp: int = wound.hp
	# From whichever side is open.
	var side: float = -1.0 if not info.solid_at(host.global_position + Vector2(-cell, 0.0)) else 1.0
	var from: Vector2 = host.global_position + Vector2(side * cell * 0.9, 0.0)
	# The wizard far off, so it hatches nothing, and nothing else about it to take the blows first
	# (its brood, the level's other enemies near it).
	player.global_position = host.global_position + Vector2(0.0, -cell * float(BugNest.WAKE + 4))
	info.loader.wake_around(from)
	_clear_round(host, cell)
	await frames(2)
	_slash(host.global_position + Vector2(side * cell * 0.6, 0.0), Vector2(-side, 0.0), 1)
	check(not is_instance_valid(host) or wound.hp == hp - 1, "a slash at it wounds it")
	for i: int in range(hp):
		if not is_instance_valid(host):
			break
		# Anything that has crawled up beside it since is cleared away first.
		_clear_round(host, cell)
		await frames(1)
		_bolt(from, Vector2(-side, 0.0), 0)
		await frames(20)
	check(not is_instance_valid(host) or host.is_queued_for_deletion(), "and bolts of no damage destroy it (%d)" % hp)
	check(info.record().slain.has(at), "the level record keeps it so")


## Free every enemy within three cells of `host` but it.
func _clear_round(host: Node2D, cell: float) -> void:
	for n: Node in get_nodes_in_group(&"hex_target"):
		if n != host and (n as Node2D).global_position.distance_to(host.global_position) < cell * 3.0:
			n.queue_free()


## The crossbows' arrows in flight.
func _arrows() -> Array[Bullet]:
	var out: Array[Bullet] = []
	for n: Node in info.map_elements.get_children():
		var b: Bullet = n as Bullet
		if b != null and b.arrow and not b.is_queued_for_deletion():
			out.append(b)
	return out


## A hex bolt of `damage` from `from` along `dir`.
func _bolt(from: Vector2, dir: Vector2, damage: int) -> void:
	var bolt: HexBolt = HexBolt.new()
	bolt.damage = damage
	bolt.dir = dir
	info.map_elements.add_child(bolt)
	bolt.global_position = from


## A slash (Slash, at `tier`, ready at once) from `from` heading `dir`, the wizard there just for
## it; then slash back at tier I, and the wizard back where they were.
func _slash(from: Vector2, dir: Vector2, tier: int) -> void:
	var was: Vector2 = player.global_position
	Abilities.set_tier(player, &"slash", tier)
	player.global_position = from - (SpellStrike.origin(player) - player.global_position)
	var slash: Slash = player.get_node("Slash") as Slash
	slash.wait = 0.0
	slash.cast(dir)
	Abilities.set_tier(player, &"slash", 1)
	player.global_position = was
