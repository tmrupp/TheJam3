extends SceneTree
## The sky archetype (docs/DEEPER_PLAN.md §4c): its band of depths, terrain sample and realm, the
## open drop under it (a fall costs a heart and puts the wizard back on the last rock), and what is
## up there: jump pads, clouds that give way, updrafts, chasms crossed on the wind a vane sets
## blowing, shielded enemies and watchers whose shots rebound.
## godot --headless --path . --script res://tests/sky_test.gd

var main: Node
var info: MapInfo
var player: Player
var failed: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func settle(frames: int = 4) -> void:
	await process_frame
	var deadline: int = Time.get_ticks_msec() + 30000
	while (info.world == null or info.travelling or info.run_ending > 0.0) and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in range(frames):
		await physics_frame
		await process_frame


func placed(file: String) -> Array[Node]:
	var found: Array[Node] = []
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == file and not n.is_queued_for_deletion():
			found.append(n)
	return found


func count(w: MapInfo.World, type: MapInfo.Type) -> int:
	var n: int = 0
	for column: Array in w.cells:
		for cell: MapInfo.Cell in column:
			if cell.type == type:
				n += 1
	return n


func run() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://sky_test.save"
	await process_frame
	bands()
	generation(main.get_node("WaveFunctionCollapse"))

	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	await process_frame
	await process_frame
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player
	await settle()
	info.coord = Vector2i(28, 6)
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	print("in the sky")
	check(info.here.sky(), "depth 6 is a sky level")
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
	check(info.world.size.x > MapInfo.level_size(6).x * 3 / 2 and info.world.size.y > MapInfo.level_size(6).y * 3 / 2, "much bigger than a cave level of its depth (%s to %s)" % [info.world.size, MapInfo.level_size(6)])

	await falling()
	await pads()
	await puffs()
	await vanes()
	await updrafts()
	await shields()
	await rebounds()
	await birds()

	MapInfo.delete_save()
	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: the sky")
		quit()


func bands() -> void:
	print("bands")
	check(NextWorldDef.archetype_at(6) == &"sky" and NextWorldDef.archetype_at(8) == &"sky" and NextWorldDef.archetype_at(9) == &"garden", "the sky takes the third band, then the garden comes round again")
	var def: NextWorldDef = MapInfo.def_for(Vector2i(28, 6))
	check(def.region == NextWorldDef.ISLANDS and def.realm() == &"sky" and def.chasmed(), "a sky level collapses the floating islands, prints in its realm and is gated by chasms")


func generation(wfc: Node) -> void:
	print("generation")
	var totals: Dictionary = {"pads": 0, "puffs": 0, "drafts": 0, "shields": 0, "bounces": 0, "birds": 0}
	for at: Vector2i in [Vector2i(28, 6), Vector2i(7, 7), Vector2i(99, 8)]:
		var def: NextWorldDef = MapInfo.def_for(at)
		var cells: Array = wfc.call("generate_level", def)
		check(not cells.is_empty(), "%s collapses" % at)
		if cells.is_empty():
			continue
		var w: MapInfo.World = MapInfo.World.new(cells, def)
		var again: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", def), def)
		check(w.objects == again.objects, "%s: the same every time" % at)
		check(w.chasms.size() >= MapInfo.CHASMS_MIN and count(w, MapInfo.Type.BRIDGE) == 0 and count(w, MapInfo.Type.BELL) == 0, "%s: %d chasms, no bridges or bells" % [at, w.chasms.size()])
		var rock: int = 0
		var outside: int = 0
		for v: Vector2i in w.grounds:
			rock += 1
			if not w.in_isle(v, 4):
				outside += 1
		check(w.isles.size() >= 3 and float(outside) <= float(rock) * 0.1, "%s: %d clusters of islands, the rock all in them (%d of %d cells outside)" % [at, w.isles.size(), outside, rock])
		check(w.links == w.isles.size() - 1, "%s: every cluster linked to the rest by a causeway (%d of %d)" % [at, w.links, w.isles.size() - 1])
		var crosswinds: int = 0
		for column: Array in w.cells:
			for cell: MapInfo.Cell in column:
				if cell.type == MapInfo.Type.WIND and (cell.extra_info as Dictionary).has("chasm"):
					crosswinds += 1
				elif cell.type == MapInfo.Type.WIND:
					totals["drafts"] += 1
				if cell.mods.has("shield"):
					totals["shields"] += 1
				if cell.mods.has("bounces"):
					totals["bounces"] += 1
		check(crosswinds == w.chasms.size() and count(w, MapInfo.Type.VANE) >= w.chasms.size(), "%s: a crosswind over every chasm (%d), and vanes by them (%d)" % [at, crosswinds, count(w, MapInfo.Type.VANE)])
		check(count(w, MapInfo.Type.SHOOTER) == 0 or w.objects.filter(func(v: Vector2i) -> bool: return w.get_cell(v).type == MapInfo.Type.SHOOTER).all(func(v: Vector2i) -> bool: return w.get_cell(v).mods.has("bounces")), "%s: every watcher's shots rebound (%d watchers)" % [at, count(w, MapInfo.Type.SHOOTER)])
		totals["birds"] += count(w, MapInfo.Type.BIRD)
		totals["pads"] += count(w, MapInfo.Type.PAD)
		totals["puffs"] += count(w, MapInfo.Type.PUFF)
	check(totals.values().all(func(n: int) -> bool: return n > 0), "pads, clouds that give way, updrafts, shields, rebounding shots and birds are all dealt: %s" % totals)


## Stood on rock, then out of the bottom of the level: back on the rock, a heart down.
func falling() -> void:
	print("the drop")
	var rock: Vector2 = Vector2.ZERO
	for v: Vector2i in info.world.empties:
		if info.world.ground_below(v) and info.world.get_cell(v).type == MapInfo.Type.EMPTY:
			rock = info.cell_position(v)
			break
	player.global_position = rock
	player.velocity = Vector2.ZERO
	player.invulnerable.end()
	player.health.health = player.health.max_health
	player.set_physics_process(true)
	for i: int in range(20):
		await physics_frame
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
		if info.world.is_valid(above) and info.world.get_cell(above).type == MapInfo.Type.EMPTY:
			puff = n as Puff
			break
	check(puff != null, "a cloud in the level")
	if puff == null:
		return
	player.global_position = puff.global_position + Vector2(0, -100)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	for i: int in range(20):
		await physics_frame
	check(puff.holds() and player.is_on_floor(), "it holds the wizard at first")
	for i: int in range(int(Puff.STAND * 60.0) + 20):
		await physics_frame
	check(not puff.holds(), "stood on for %.1f s, it gives way" % Puff.STAND)
	var through: float = player.global_position.y
	for i: int in range(20):
		await physics_frame
	check(player.global_position.y > through + 20.0, "and the wizard drops through")
	player.global_position = puff.global_position + Vector2(400, -2000)
	player.set_physics_process(false)
	await create_timer(Puff.REFORM + 0.3).timeout
	check(puff.holds(), "it gathers again %.0f s later" % Puff.REFORM)


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
	KeyRing.clear(player)
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
	for i: int in range(10):
		await process_frame
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
	for i: int in range(20):
		await physics_frame


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
	check(shield.hp == MapInfo.SHIELD_HP - 1 and wound.hp == hp and not stunned, "a hex bolt cracks the shield, and neither wounds nor stuns what it guards")
	for i: int in range(MapInfo.SHIELD_HP - 1):
		await _bolt(foe, from)
	check(not shield.holds() and wound.hp == hp, "after %d hits it breaks" % MapInfo.SHIELD_HP)
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
		if info.world.is_ground(v + Vector2i.RIGHT) and info.world.get_cell(v).type == MapInfo.Type.EMPTY and info.world.get_cell(v + Vector2i.LEFT).type == MapInfo.Type.EMPTY:
			spot = v
			break
	var shot: Node2D = (load("res://prefabs/bullet.tscn") as PackedScene).instantiate()
	info.map_elements.add_child(shot)
	shot.global_position = info.cell_position(spot + Vector2i.LEFT)
	shot.call("setup", Vector2(300, 0), [], player)
	shot.set("bounces", 2)
	for i: int in range(90):
		await process_frame
		if not is_instance_valid(shot) or (shot.get("velocity") as Vector2).x < 0.0:
			break
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
	for i: int in range(60):
		await physics_frame
	var span: Vector2 = bird.get("span")
	check(absf(rb.global_position.y - float(bird.get("height"))) < 8.0 and rb.global_position.x != start.x and rb.global_position.x >= span.x - 1.0 and rb.global_position.x <= span.y + 1.0, "it patrols along its height")
	# The wizard below: it swoops down at them and back up to its height.
	bird.set("since_swoop", 99.0)
	player.global_position = rb.global_position + Vector2(60, 300)
	player.invulnerable.enable()
	var low: float = rb.global_position.y
	var swooped: bool = false
	for i: int in range(int(Bird.SWOOP_TIME * 60.0) + 30):
		await physics_frame
		swooped = swooped or bool(bird.call("swooping"))
		low = maxf(low, rb.global_position.y)
	player.global_position = rb.global_position + Vector2(0, -300)
	check(swooped and low > float(bird.get("height")) + 150.0, "with the wizard below, it swoops down (%d px)" % int(low - float(bird.get("height"))))
	for i: int in range(60):
		await physics_frame
	check(not bool(bird.call("swooping")) and absf(rb.global_position.y - float(bird.get("height"))) < 8.0, "and climbs back to its height")
