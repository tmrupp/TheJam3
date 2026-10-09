extends TestKit
## The sky archetype (docs/DEEPER_PLAN.md §4c): its band of depths, terrain sample and realm, the
## open drop under it (a fall costs a heart and puts the wizard back on the last rock), and what is
## up there: jump pads, clouds that give way, updrafts, chasms crossed on the wind a vane sets
## blowing, shielded enemies and watchers whose shots rebound.
## godot --headless --path . --script res://tests/sky_test.gd


func count(w: LevelGen, type: LevelGen.Type) -> int:
	var n: int = 0
	for column: Array in w.cells:
		for cell: LevelGen.Cell in column:
			if cell.type == type:
				n += 1
	return n


func run() -> void:
	bands()
	generation()

	await boot()
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"sky"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	print("in the sky")
	check(info.here.archetype == &"sky", "depth 6 is a sky level")
	if RisoPrint.instance != null:
		check(RisoPrint.instance.realm == &"sky", "printed in the sky's realm")
	var round_it: Array = []
	for x: int in range(-2, info.world.size.x + 2):
		for y: int in [-2, -1, info.world.size.y, info.world.size.y + 1]:
			round_it.append(info.tile_map.get_cell_source_id(0, Vector2i(x, y)))
	for y: int in range(info.world.size.y):
		for x: int in [-2, -1, info.world.size.x, info.world.size.x + 1]:
			round_it.append(info.tile_map.get_cell_source_id(0, Vector2i(x, y)))
	check(round_it.all(func(id: int) -> bool: return id == -1), "no rock round the level: open sky on every side, and a drop below")
	check(info.world.size.x > Rules.level_size(6).x * 3 / 2 and info.world.size.y > Rules.level_size(6).y * 3 / 2, "much bigger than a cave level of its depth (%s to %s)" % [info.world.size, Rules.level_size(6)])

	await falling()
	await pads()
	await puffs()
	await vanes()
	await updrafts()
	await shields()
	await rebounds()
	await birds()

	RunState.delete_save()
	finish()


func bands() -> void:
	print("bands")
	var s0: int = NextWorldDef.first_depth(&"sky")
	check(NextWorldDef.archetype_at(s0) == &"sky" and NextWorldDef.archetype_at(NextWorldDef.band_row(&"sky", NextWorldDef.BAND - 1)) == &"sky" and NextWorldDef.archetype_at(s0 + 1) == &"crags" and NextWorldDef.archetype_at(NextWorldDef.band_row(&"sky", 40)) == &"sky", "the sky is the second band up, past the crags, and goes on above")
	var def: NextWorldDef = Rules.def_for(Vector2i(28, s0))
	check(def.region == SkyArchetype.SAMPLE and def.realm() == &"sky" and def.chasmed(), "a sky level collapses the floating islands, prints in its realm and is gated by chasms")


func generation() -> void:
	print("generation")
	var totals: Dictionary = {"pads": 0, "puffs": 0, "drafts": 0, "shields": 0, "bounces": 0, "birds": 0}
	var s0: int = NextWorldDef.first_depth(&"sky")
	for at: Vector2i in [Vector2i(28, s0), Vector2i(7, NextWorldDef.band_row(&"sky", 1)), Vector2i(99, NextWorldDef.band_row(&"sky", 2))]:
		var def: NextWorldDef = Rules.def_for(at)
		var cells: Array = collapse(def.coord)
		check(not cells.is_empty(), "%s collapses" % at)
		if cells.is_empty():
			continue
		var w: LevelGen = LevelGen.new(cells, def)
		var again: LevelGen = LevelGen.new(collapse(def.coord), def)
		check(w.objects == again.objects, "%s: the same every time" % at)
		check(w.chasms.size() >= Chasms.CHASMS_MIN and count(w, LevelGen.Type.BRIDGE) == 0 and count(w, LevelGen.Type.BELL) == 0, "%s: %d chasms, no bridges or bells" % [at, w.chasms.size()])
		var rock: int = 0
		var outside: int = 0
		for v: Vector2i in w.grounds:
			rock += 1
			if not w.in_isle(v, 4):
				outside += 1
		check(w.isles.size() >= 3 and float(outside) <= float(rock) * 0.1, "%s: %d clusters of islands, the rock all in them (%d of %d cells outside)" % [at, w.isles.size(), outside, rock])
		check(float(rock) / float(w.size.x * w.size.y) >= 0.065, "%s: denser island shelves (%d terrain cells)" % [at, rock])
		check(w.chasms.all(func(gap: Dictionary) -> bool:
			var shore: Vector2i = gap["right"]
			return not w.is_ground(shore) and not w.is_ground(shore + Vector2i.UP) and w.get_cell(shore + Vector2i.DOWN).type in [LevelGen.Type.GROUND, LevelGen.Type.CRACKED]), "%s: wind landing shores are level with clear headroom" % at)
		check(w.links == w.isles.size() - 1, "%s: every cluster linked to the rest by a causeway (%d of %d)" % [at, w.links, w.isles.size() - 1])
		var crosswinds: int = 0
		for column: Array in w.cells:
			for cell: LevelGen.Cell in column:
				if cell.type == LevelGen.Type.WIND and (cell.extra_info as Dictionary).has("chasm"):
					crosswinds += 1
				elif cell.type == LevelGen.Type.WIND:
					totals["drafts"] += 1
				if cell.mods.has("shield"):
					totals["shields"] += 1
				if cell.mods.has("bounces"):
					totals["bounces"] += 1
		var blown: int = w.chasms.size() - w.relic_chasms.size()
		check(crosswinds == blown and count(w, LevelGen.Type.VANE) >= blown, "%s: a crosswind over every chasm but those left to relics (%d of %d), and vanes by them (%d)" % [at, crosswinds, w.chasms.size(), count(w, LevelGen.Type.VANE)])
		check(count(w, LevelGen.Type.SHOOTER) == 0 or w.objects.filter(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.SHOOTER).all(func(v: Vector2i) -> bool: return w.get_cell(v).mods.has("bounces")), "%s: every watcher's shots rebound (%d watchers)" % [at, count(w, LevelGen.Type.SHOOTER)])
		totals["birds"] += count(w, LevelGen.Type.BIRD)
		check(_portals_apart(w), "%s: each pair of teleporters at least %d cells apart" % [at, w.portal_apart()])
		totals["pads"] += count(w, LevelGen.Type.PAD)
		totals["puffs"] += count(w, LevelGen.Type.PUFF)
	var garden_def: NextWorldDef = Rules.def_for(Vector2i(28, 1))
	var garden: LevelGen = LevelGen.new(collapse(garden_def.coord), garden_def)
	check(count(garden, LevelGen.Type.PORTAL) > 0 and _portals_apart(garden), "a garden level's teleporters are as far apart (%d pairs, %d cells)" % [count(garden, LevelGen.Type.PORTAL) / 2, garden.portal_apart()])
	check(totals.values().all(func(n: int) -> bool: return n > 0), "pads, clouds that give way, updrafts, shields, rebounding shots and birds are all dealt: %s" % totals)


## Whether every teleporter in `w` is at least portal_apart() from its partner.
func _portals_apart(w: LevelGen) -> bool:
	for v: Vector2i in w.objects:
		var cell: LevelGen.Cell = w.get_cell(v)
		if cell.type == LevelGen.Type.PORTAL:
			var other: Vector2i = cell.extra_info
			if absi(other.x - v.x) + absi(other.y - v.y) < w.portal_apart():
				return false
	return true


## Stood on rock, then out of the bottom of the level: back on the rock, a heart down.
func falling() -> void:
	print("the drop")
	var rock: Vector2 = Vector2.ZERO
	for v: Vector2i in info.world.empties:
		if info.world.ground_below(v) and info.world.get_cell(v).type == LevelGen.Type.EMPTY:
			rock = info.cell_position(v)
			break
	player.global_position = rock
	player.velocity = Vector2.ZERO
	player.end_invulnerable()
	player.health.health = player.health.max_health
	# Forget any rock stood on before, so the wait below is for this landing: under load a process
	# frame can come before the next physics step, while the floor and footing are still old ones.
	player.footing_at = Vector2i(-99999, -99999)
	player.set_physics_process(true)
	await physics_frame
	await until(func() -> bool: return player.is_on_floor() and player.footing_at == info.coord)
	var stood: Vector2 = player.global_position
	check(player.footing_at == info.coord and player.footing.distance_to(stood) < 4.0, "standing on rock is remembered")
	player.global_position = Vector2(stood.x, info.level_rect().end.y + Player.FALL_MARGIN + 50.0)
	for i: int in range(2):
		await physics_frame
	player.set_physics_process(false)
	check(player.global_position.distance_to(stood) < 40.0 and player.health.health == player.health.max_health - 1, "a fall out of the bottom puts the wizard back there, a heart down")
	player.health.health = player.health.max_health
	player.invulnerable.enable()


func pads() -> void:
	print("jump pads")
	var pad: Node2D = placed("pad.tscn")[0] as Node2D if not placed("pad.tscn").is_empty() else null
	check(pad != null, "a pad in the level")
	if pad == null:
		return
	player.global_position = pad.global_position + Vector2(0, -40)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	var fastest: float = 0.0
	for i: int in range(70):
		await physics_frame
		fastest = minf(fastest, player.velocity.y)
	player.set_physics_process(false)
	# Thrown at the pad's speed: about four cells up where nothing is in the way.
	check(fastest <= -1000.0, "it throws the wizard up at %d px/s" % int(-fastest))


func puffs() -> void:
	print("clouds that give way")
	var puff: Puff = null
	for n: Node in placed("puff.tscn"):
		var above: Vector2i = info.cell_at((n as Node2D).global_position) + Vector2i.UP
		if info.world.is_valid(above) and info.world.get_cell(above).type == LevelGen.Type.EMPTY:
			puff = n as Puff
			break
	check(puff != null, "a cloud in the level")
	if puff == null:
		return
	player.global_position = puff.global_position + Vector2(0, -100)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	await until(func() -> bool: return puff.holds() and player.is_on_floor())
	check(puff.holds() and player.is_on_floor(), "it holds the wizard at first")
	for i: int in range(int(Puff.STAND * 60.0) + 20):
		await physics_frame
	check(not puff.holds(), "stood on for %.1f s, it gives way" % Puff.STAND)
	var through: float = player.global_position.y
	await until(func() -> bool: return player.global_position.y > through + 20.0)
	check(player.global_position.y > through + 20.0, "and the wizard drops through")
	player.global_position = puff.global_position + Vector2(400, -2000)
	player.set_physics_process(false)
	await within(func() -> bool: return puff.holds(), Puff.REFORM + 1.0)
	check(puff.holds(), "it gathers again %.0f s later" % Puff.REFORM)
	# Touched and left at once: it still goes.
	player.global_position = puff.global_position + Vector2(0, -100)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	await until(func() -> bool: return puff.worn() > 0.0)
	player.global_position = puff.global_position + Vector2(400, -2000)
	player.set_physics_process(false)
	for i: int in range(int(Puff.STAND * 60.0) + 10):
		await physics_frame
	check(not puff.holds(), "touched once and left, it gives way all the same")


func vanes() -> void:
	print("vanes and crosswinds")
	var vanes: Array[Node] = placed("vane.tscn")
	check(not vanes.is_empty(), "a vane in the level")
	if vanes.is_empty():
		return
	var vane: Node2D = vanes[0] as Node2D
	var id: int = int(vane.get("chasm"))
	var wind: Wind = null
	for n: Node in placed("wind.tscn"):
		if (n as Wind).chasm == id:
			wind = n as Wind
	check(wind != null and not wind.active(), "its chasm's wind is still")
	var away0: float = signf(wind.rect.get_center().x - vane.global_position.x)
	check(not await _cross(wind, away0, true), "still, a run, a jump and a dash do not get the wizard over it")
	player.keyring.clear()
	vane.call("hex_hit", 1, Vector2.RIGHT)
	check(not wind.active(), "chained, the vane only rattles")
	info.free_bell(vane.get_meta(&"cell"))
	vane.call("hex_hit", 1, Vector2.RIGHT)
	var away: float = signf(wind.rect.get_center().x - vane.global_position.x)
	check(wind.active() and wind.blowing() == away and info.wind_from(id) == vane.get_meta(&"cell"), "freed and turned, the wind blows from its side across")
	# Walk off the vane's shore into the wind: carried over to the far side, on the floor there.
	check(await _cross(wind, away, false), "the wind carries the wizard over the chasm to the floor on the far side")
	var others: Array[Node] = vanes.filter(func(n: Node) -> bool: return n != vane and int(n.get("chasm")) == id)
	if not others.is_empty():
		var other: Node2D = others[0] as Node2D
		info.free_bell(other.get_meta(&"cell"))
		other.call("use")
		check(wind.blowing() == -away, "turning the vane on the far side sends the wind back")


## From the floor a cell back from the chasm's near edge (the side `away` points from), head across:
## walking, or (`leap`) with a jump at the edge and a dash. Whether the wizard ends on the floor of
## the far side.
func _cross(wind: Wind, away: float, leap: bool) -> bool:
	# The floor's row: the third of the wind's rows.
	var row: int = info.cell_at(wind.rect.position + Vector2(64.0, 2.5 * 128.0)).y
	var near_x: float = wind.rect.position.x + 64.0 if away > 0.0 else wind.rect.end.x - 64.0
	var far_x: float = wind.rect.end.x - 64.0 if away > 0.0 else wind.rect.position.x + 64.0
	# Nothing in the way: enemies by the gap are cleared off first.
	for n: Node in info.map_elements.get_children():
		if n.has_node("Wound") and (n as Node2D).global_position.distance_to(wind.rect.get_center()) < wind.rect.size.x:
			n.queue_free()
	await physics_frame
	player.global_position = Vector2(near_x - away * 128.0, info.cell_position(Vector2i(0, row)).y)
	player.velocity = Vector2.ZERO
	player.health.health = player.health.max_health
	player.invulnerable.enable()
	player.dash.refresh()
	player.set_physics_process(true)
	var key: StringName = &"Right" if away > 0.0 else &"Left"
	Input.action_press(key)
	var over: bool = false
	var dashed: int = -1
	for i: int in range(240):
		await physics_frame
		if leap and dashed < 0 and (player.global_position.x - near_x) * away > 0.0:
			var jump: InputEventAction = InputEventAction.new()
			jump.action = &"Jump"
			jump.pressed = true
			Input.parse_input_event(jump)
			dashed = i + 10
		if i == dashed:
			var dash: InputEventAction = InputEventAction.new()
			dash.action = &"Dash"
			dash.pressed = true
			Input.parse_input_event(dash)
		if player.is_on_floor() and (player.global_position.x - far_x) * away > -64.0 and absf(player.global_position.y - info.cell_position(Vector2i(0, row)).y) < 140.0:
			over = true
			break
		if player.global_position.y > info.cell_position(Vector2i(0, row + 4)).y:
			break
	Input.action_release(key)
	Input.action_release(&"Jump")
	Input.action_release(&"Dash")
	player.set_physics_process(false)
	return over


func updrafts() -> void:
	print("updrafts")
	var draft: Wind = null
	for n: Node in placed("wind.tscn"):
		if (n as Wind).up > 0 and (draft == null or (n as Wind).up > draft.up):
			draft = n as Wind
	if draft == null:
		print("  (no updraft in this level)")
		return
	# Looking at the top of a tall shaft, its middle out of view: it still wakes and blows.
	var art: Node = draft.get_node_or_null("RisoArt")
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.global_position = Vector2(draft.rect.get_center().x + 300.0, draft.rect.position.y)
	for i: int in range(20):
		camera.global_position = player.global_position
		camera.reset_smoothing()
		await process_frame
	var t0: float = float(art.get("t")) if art != null else 0.0
	await until(func() -> bool: return draft.visible and draft.can_process() and (art == null or float(art.get("t")) > t0))
	check(draft.visible and draft.can_process() and (art == null or float(art.get("t")) > t0), "looking at the top of a %d-cell shaft, its wind still shows and moves" % draft.up)
	player.global_position = Vector2(draft.rect.get_center().x, draft.rect.end.y - 40.0)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	var start: float = player.global_position.y
	var top: float = start
	for i: int in range(int(draft.rect.size.y / Wind.LIFT_SPEED * 60.0) + 90):
		await physics_frame
		top = minf(top, player.global_position.y)
	player.set_physics_process(false)
	check(start - top > float(draft.up - 1) * 128.0, "the updraft lifts the wizard up its shaft (%d of %d px)" % [int(start - top), int(draft.rect.size.y)])


## A bolt at `at` from `offset` off it (where it is now).
func _bolt(at: Node2D, offset: Vector2, reflected: bool = false) -> void:
	var from: Vector2 = at.global_position + offset
	var bolt: Node2D = Node2D.new()
	bolt.set_script(preload("res://scripts/HexBolt.gd"))
	bolt.set("dir", (at.global_position - from).normalized())
	bolt.set("damage", 1)
	bolt.set("reflected", reflected)
	info.map_elements.add_child(bolt)
	bolt.global_position = from
	await until(gone(bolt), 3000)


func shields() -> void:
	print("shields")
	var foe: Node2D = null
	for n: Node in info.map_elements.get_children():
		if Shield.of(n) != null and not n.is_queued_for_deletion():
			foe = n as Node2D
			break
	check(foe != null, "a shielded enemy in the level")
	if foe == null:
		return
	# Out in the open sky, away from everything else, and held still.
	foe.process_mode = Node.PROCESS_MODE_DISABLED
	for v: Vector2i in info.world.empties:
		if not info.world.in_isle(v, 3) and v.y > 4:
			foe.global_position = info.cell_position(v)
			break
	(foe.get_node("Wound") as Node).process_mode = Node.PROCESS_MODE_ALWAYS
	var shield: Shield = Shield.of(foe)
	var wound: Wound = foe.get_node("Wound") as Wound
	var hp: int = wound.hp
	var from: Vector2 = Vector2(-70, -20)
	await _bolt(foe, from)
	var stunned: bool = bool(foe.get_node("HitBox").get("stunned")) if foe.has_node("HitBox") else false
	check(shield.hp == Shield.HP - 1 and wound.hp == hp and not stunned, "a hex bolt cracks the shield, and neither wounds nor stuns what it guards")
	for i: int in range(Shield.HP - 1):
		await _bolt(foe, from)
	check(not shield.holds() and wound.hp == hp, "after %d hits it breaks" % Shield.HP)
	if wound.hp > 1:
		await _bolt(foe, from)
		check(not is_instance_valid(wound) or wound.hp < hp, "then bolts wound it")
	if not is_instance_valid(foe):
		return
	# A parried shot breaks a whole shield at once.
	var fresh: Shield = Shield.new()
	foe.add_child(fresh)
	shield.name = "Broken"
	fresh.name = "Shield"
	await process_frame
	check(fresh.absorb(true, Vector2.RIGHT) and not fresh.holds(), "a parried shot breaks a whole shield at once")


func rebounds() -> void:
	print("rebounding shots")
	var shooters: Array[Node] = placed("shooter_enemy.tscn").filter(func(n: Node) -> bool: return int(n.get_meta(&"bounces", 0)) > 0)
	print("  (%d watchers here whose shots rebound)" % shooters.size())
	# A shot fired at a wall: it glances off and flies back the other way, then bursts on the next.
	var spot: Vector2i = Vector2i(-1, -1)
	for v: Vector2i in info.world.empties:
		if info.world.is_ground(v + Vector2i.RIGHT) and info.world.get_cell(v).type == LevelGen.Type.EMPTY and info.world.get_cell(v + Vector2i.LEFT).type == LevelGen.Type.EMPTY:
			spot = v
			break
	var shot: Node2D = (load("res://prefabs/bullet.tscn") as PackedScene).instantiate()
	info.map_elements.add_child(shot)
	shot.global_position = info.cell_position(spot + Vector2i.LEFT)
	shot.call("setup", Vector2(300, 0), [], player)
	shot.set("bounces", 2)
	# Up to five seconds: it flies a cell and a half to the wall, slower when frames are short.
	var shot_id: int = shot.get_instance_id()
	await until(func() -> bool:
		var s: Node2D = instance_from_id(shot_id) as Node2D
		return s == null or (s.get("velocity") as Vector2).x < 0.0, 5000)
	check(is_instance_valid(shot) and (shot.get("velocity") as Vector2).x < 0.0 and int(shot.get("bounces")) == 1, "it glances off the wall and comes back")
	if is_instance_valid(shot):
		shot.queue_free()


func birds() -> void:
	print("birds")
	var flock: Array[Node] = placed("bird_enemy.tscn")
	check(not flock.is_empty(), "a bird in the level")
	if flock.is_empty():
		return
	var rb: Node2D = flock[0] as Node2D
	var bird: Node = rb.get_node("Bird")
	# Patrolling: along its height, back and forth within its stretch (the wizard above it, out of
	# its reach but near enough that its part of the level stays awake).
	player.global_position = rb.global_position + Vector2(0, -300)
	var start: Vector2 = rb.global_position
	await until(func() -> bool: return absf(rb.global_position.y - float(bird.get("height"))) < 8.0 and rb.global_position.x != start.x)
	var span: Vector2 = bird.get("span")
	check(absf(rb.global_position.y - float(bird.get("height"))) < 8.0 and rb.global_position.x != start.x and rb.global_position.x >= span.x - 1.0 and rb.global_position.x <= span.y + 1.0, "it patrols along its height")
	# The wizard below: it swoops down at them and back up to its height. A bird only swoops where
	# its arc is clear of rock (the islands' keels can be in the way), so try each until one does.
	var camera: Camera2D = main.get_node("Camera2D")
	player.invulnerable.enable()
	var low: float = 0.0
	var swooped: bool = false
	for candidate: Node in flock:
		rb = candidate as Node2D
		bird = rb.get_node("Bird")
		bird.set("since_swoop", 99.0)
		player.global_position = rb.global_position + Vector2(60, 300)
		# Observe the bird: swoops begin only inside the camera's view.
		player.get_node("CameraControl").set("target_location", player.global_position)
		camera.global_position = player.global_position
		camera.reset_smoothing()
		camera.force_update_scroll()
		low = rb.global_position.y
		for i: int in range(300):
			await physics_frame
			swooped = swooped or bool(bird.call("swooping"))
			low = maxf(low, rb.global_position.y)
			if swooped and not bool(bird.call("swooping")):
				break
			if not swooped and i > 60 + int(Bird.TELL * 60.0):
				break
		if swooped:
			break
	player.global_position = rb.global_position + Vector2(0, -300)
	check(swooped and low > float(bird.get("height")) + 300.0, "with the wizard 300 px below, it swoops down past them (%d px)" % int(low - float(bird.get("height"))))
	await until(func() -> bool: return not bool(bird.call("swooping")) and absf(rb.global_position.y - float(bird.get("height"))) < 8.0)
	check(not bool(bird.call("swooping")) and absf(rb.global_position.y - float(bird.get("height"))) < 8.0, "and climbs back to its height")
