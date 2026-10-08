extends TestKit
## The game's rules that are plain arithmetic, checked without the game scene (a second or so):
## level seeds, prices and the other numbers that grow with depth, key colours by rarity, where
## side worlds sit, the bands of archetypes, where each exit leads, the shrine's offers, and the
## keyring. A rule that needs a level laid out belongs in a test that builds one.
## godot --headless --path . --script res://tests/unit_test.gd

## level_seed of these places, as it has always been: every level of every run comes from it, so a
## change here changes every level there is.
const SEEDS: Dictionary = {
	Vector2i(0, 0): 60412924,
	Vector2i(28, 0): 1346542692,
	Vector2i(28, 5): 227949928,
	Vector2i(-3, 7): 1837187598,
	Vector2i(123456, 40): 782696996,
}
## Depths swept by the checks of numbers that grow with depth.
const DEPTHS: int = 40
## Places the checks of exits and side worlds look at.
const PLACES: Array[Vector2i] = [Vector2i(28, 0), Vector2i(28, 3), Vector2i(7, 6), Vector2i(99, 13), Vector2i(0, 25),
	Vector2i(28, -1), Vector2i(7, -5), Vector2i(99, -12)]


func run() -> void:
	MapInfo.debug = false
	_seeds()
	_by_depth()
	_rarity()
	_archetypes()
	_side_worlds()
	_exits()
	_branches()
	_relics()
	var p: Player = Player.new()
	_ability_tables()
	_protocols()
	_offers(p)
	_keyring(p)
	p.free()
	finish()


func _seeds() -> void:
	for at: Vector2i in SEEDS:
		check_eq(Rules.level_seed(at.x, at.y), int(SEEDS[at]), "level_seed%s is unchanged" % at)
	var seen: Dictionary = {}
	var negative: int = 0
	for x: int in range(-20, 20):
		for y: int in range(0, 20):
			var s: int = Rules.level_seed(x, y)
			seen[s] = true
			if s < 0:
				negative += 1
	check(negative == 0, "level seeds are never negative")
	check(seen.size() == 40 * 20, "no two of 800 nearby places share a level seed")


func _by_depth() -> void:
	var rising: Callable = func(f: Callable, strict: bool) -> bool:
		for d: int in range(DEPTHS):
			var a: int = int(f.call(d))
			var b: int = int(f.call(d + 1))
			if b < a or (strict and b == a):
				return false
		return true
	check(rising.call(Rules.deeper_price, true), "the deeper exit costs more at every depth")
	check(rising.call(Rules.map_price, false), "inking the map never gets cheaper deeper")
	check(rising.call(Rules.cluster_value, false), "a star cluster is never worth less deeper")
	check(rising.call(Wound.hp_for, false), "enemies never get weaker deeper")
	check_eq(Rules.cluster_value(-3), Rules.cluster_value(0), "a side world's depth below 0 prices clusters as the surface")
	var hp: Array[int] = []
	var distance_ok: bool = true
	var size_ok: bool = true
	for d: int in range(DEPTHS):
		hp.append(Wound.hp_for(d))
		var e: int = Rules.exit_distance(d)
		distance_ok = distance_ok and e >= 24 and e <= 96
		var s: Vector2i = Rules.level_size(d)
		var below: Vector2i = Rules.level_size(d + 1)
		size_ok = size_ok and s.x >= 36 and s.x <= 60 and s.y >= 30 and s.y <= 48 and below.x >= s.x and below.y >= s.y
	check(hp.min() == 2 and hp.max() == 3, "enemy health runs from 2 to 3")
	check(distance_ok, "the way back and the deeper exit are 24 to 96 cells apart")
	check(size_ok, "levels grow with depth, from 36 x 30 to at most 60 x 48 cells")
	check_eq(Rules.relic_need(Rules.RELIC_NEED_FROM - 1), 0, "no crossing is left to relics before RELIC_NEED_FROM")
	check_eq(Rules.relic_need(Rules.RELIC_NEED_FROM), Rules.RELIC_NEED_STEP, "then RELIC_NEED_STEP %")
	check_eq(Rules.relic_need(500), Rules.RELIC_NEED_MAX, "and never more than RELIC_NEED_MAX %")
	for a: StringName in Abilities.ids():
		var free: bool = not Abilities.ABILITIES[a].has("cost")
		var ok: bool = true
		for d: int in range(DEPTHS):
			var c: int = Abilities.cast_price(a, d)
			ok = ok and (c == 0 if free else c >= 1 and Abilities.cast_price(a, d + 1) >= c)
		check(ok, "%s: %s" % [a, "costs nothing to cast" if free else "costs at least a star a cast, more deeper"])
	var learn_ok: bool = true
	for d: int in range(DEPTHS):
		for t: int in range(1, 5):
			var p: int = Abilities.price(d, t)
			learn_ok = learn_ok and p >= 3 and Abilities.price(d, t + 1) >= p and Abilities.price(d + 1, t) <= p
	check(learn_ok, "learning costs at least 3 stars, more per tier, less deeper")


func _rarity() -> void:
	var total: int = 0
	for w: int in Rules.KEY_RARITY:
		total += w
	var counts: Array[int] = []
	counts.resize(Rules.KEY_RARITY.size())
	for r: int in range(total):
		counts[Rules.rarity_color(r)] += 1
	check_eq(counts, Rules.KEY_RARITY, "over one turn of draws, each key colour comes up KEY_RARITY times")
	check_eq(Rules.rarity_color(-1), Rules.rarity_color(total - 1), "a negative draw deals a colour as well")
	check_eq(Rules.KEY_RARITY.size(), Rules.KEY_COLOR_COUNT, "a rarity for every key colour")


func _archetypes() -> void:
	var band: int = NextWorldDef.BAND
	var g: int = NextWorldDef.GARDEN_ROWS
	# The garden is the hub, both ways from the start; then the bands of each way, in turn.
	var bands: Array = []
	for row: int in range(-3 * band - g, 3 * band + g + 1):
		bands.append(NextWorldDef.archetype_at(row))
	var want: Array = []
	for row: int in range(-3 * band - g, 3 * band + g + 1):
		var d: int = absi(row)
		if d <= g:
			want.append(&"garden")
		elif row > 0:
			want.append(&"cemetery" if d <= g + band else &"catacombs")
		else:
			want.append(&"crags" if d <= g + band else &"sky")
	check_eq(bands, want, "the garden spans rows -%d to %d; down the cemetery then the catacombs, up the crags then the sky, %d rows each, the outermost going on" % [g, g, band])
	check_eq(NextWorldDef.archetype_at(0), &"garden", "the run starts in the garden")
	check_eq(NextWorldDef.first_depth(&"nowhere"), -1, "no band for an archetype that does not exist")
	var firsts: Dictionary = {&"garden": 0, &"cemetery": g + 1, &"catacombs": g + 1 + band, &"crags": -(g + 1), &"sky": -(g + 1 + band)}
	for kind: StringName in firsts:
		check_eq(NextWorldDef.first_depth(kind), int(firsts[kind]), "the %s's row nearest the start" % kind)
	check(NextWorldDef.band_row(&"sky", 2) == -(g + 3 + band) and NextWorldDef.band_row(&"cemetery", 2) == g + 3, "band rows count away from the start, up or down")
	for kind: StringName in [&"garden", &"cemetery", &"sky", &"crags"]:
		var def: NextWorldDef = Rules.def_for(Vector2i(28, NextWorldDef.first_depth(kind)))
		check(def.archetype == kind and def.realm() == kind and RisoPrint.REALMS.has(kind), "a %s level is printed in its own realm" % kind)
	# A stand-in until its own art (docs/REGIONS_PLAN.md): the catacombs in the cemetery's realm.
	check(Rules.def_for(Vector2i(28, NextWorldDef.first_depth(&"catacombs"))).realm() == &"cemetery", "the catacombs stand in with a borrowed realm")
	var sky_depth: int = NextWorldDef.first_depth(&"sky")
	var sky: NextWorldDef = Rules.def_for(Vector2i(28, sky_depth))
	check_eq(sky.depth, absi(sky_depth), "a level's depth is its distance from the start, whichever way")
	check_eq(sky.size, Vector2i((Vector2(Rules.level_size(sky.depth)) * SkyArchetype.SCALE).round()), "a sky level is SkyArchetype.SCALE times a cave level of its distance")
	check(Rules.where(Vector2i(28, -5)) == "world 28 · height 5" and Rules.where(Vector2i(28, 5)) == "world 28 · depth 5", "a level above the start is named by its height")
	check(sky.chasmed() and Rules.def_for(Vector2i(28, NextWorldDef.first_depth(&"cemetery"))).chasmed() and not Rules.def_for(Vector2i(28, 0)).chasmed(), "the cemetery and the sky have chasms, the garden none")


func _side_worlds() -> void:
	for k: int in range(Worlds.KINDS.size()):
		var ok: bool = true
		for from: Vector2i in PLACES:
			var at: Vector2i = Worlds.side_at(k, from)
			ok = ok and Worlds.is_side(at) and Worlds.kind_at(at) == k and Worlds.origin_of(at) == from and Worlds.valid(at)
			ok = ok and Rules.def_for(at).get_script() == Worlds.KINDS[k]
		check(ok, "side world kind %d: entered from a level, it knows its kind and that level" % k)
		check_eq(Worlds.door_kind(Worlds.door(k)), k, "a door into kind %d leads into it" % k)
	check_eq(Worlds.kind_at(Vector2i(28, 3)), -1, "a level is no side world")
	check(not Worlds.is_side(Vector2i(28, -12)) and Worlds.valid(Vector2i(28, -12)), "nor is a level above the start")
	var signed_ok: bool = true
	for row: int in [-40, -1, 0, 1, 40]:
		for k: int in range(Worlds.KINDS.size()):
			var at: Vector2i = Worlds.side_at(k, Vector2i(5, row))
			signed_ok = signed_ok and Worlds.is_side(at) and Worlds.origin_of(at) == Vector2i(5, row) and Worlds.kind_at(at) == k
	check(signed_ok, "a side world entered from a level above or below the start knows its kind and that level")
	# Version-2 saves kept kind k from (seed, depth) at (seed, -(k * STRIDE + depth) - 1).
	check(Worlds.from_v2(Vector2i(9, -(0 * Worlds.STRIDE + 3) - 1)) == Worlds.side_at(0, Vector2i(9, 3)) and Worlds.from_v2(Vector2i(9, 4)) == Vector2i(9, 4), "a version-2 save's side worlds move to their new place, its levels stay")
	var old_side: Vector2i = Vector2i(9, -(0 * Worlds.STRIDE + 3) - 1)
	var v2: Dictionary = {"version": 2, "deepest": 5, "coord": old_side, "respawn_coord": Vector2i(9, 2), "ghost_coord": old_side,
		"records": {old_side: {}, Vector2i(9, 2): {}}, "rift_link": [[old_side, Vector2(1, 2)]]}
	var v3: Dictionary = RunState.from_v2(v2)
	var moved: Vector2i = Worlds.side_at(0, Vector2i(9, 3))
	check(int(v3["version"]) == RunState.SAVE_VERSION and v3["coord"] == moved and v3["ghost_coord"] == moved and v3["respawn_coord"] == Vector2i(9, 2), "a version-2 save is read with its places moved")
	check((v3["records"] as Dictionary).has(moved) and (v3["records"] as Dictionary).has(Vector2i(9, 2)) and (v3["rift_link"] as Array)[0][0] == moved and int(v3["furthest_row"]) == 5, "its records, rift and furthest row too")
	check(not Worlds.valid(Worlds.side_at(Worlds.KINDS.size(), Vector2i(28, 3))), "nor is there a side world of a kind not listed")
	for e: int in [MapInfo.Exit.DEEPER, MapInfo.Exit.BACK, MapInfo.Exit.LEFT, MapInfo.Exit.RIGHT, MapInfo.Exit.RETURN]:
		check_eq(Worlds.door_kind(e), -1, "exit %d is no side door" % e)
	check(MapInfo.Exit.size() <= Worlds.DOOR_BASE, "side doors are numbered past the ordinary exits")


func _exits() -> void:
	for at: Vector2i in PLACES:
		var def: NextWorldDef = Rules.def_for(at)
		var left: Dictionary = def.lead(MapInfo.Exit.LEFT)
		var right: Dictionary = def.lead(MapInfo.Exit.RIGHT)
		var deeper: Dictionary = def.lead(MapInfo.Exit.DEEPER)
		check(left["to"] == at + Vector2i.LEFT and int(left["arrive"]) == MapInfo.Exit.RIGHT, "%s: left leads to the next world's right-hand door" % at)
		check(Rules.def_for(right["to"]).lead(MapInfo.Exit.LEFT)["to"] == at, "%s: right, then left, comes back" % at)
		var on: Vector2i = Vector2i.DOWN if at.y >= 0 else Vector2i.UP
		check(deeper["to"] == at + on and int(deeper["arrive"]) == MapInfo.Exit.BACK and deeper["way"] == Vector2(on), "%s: the way on leads away from the start, arriving at the way back" % at)
		var below: NextWorldDef = Rules.def_for(deeper["to"])
		if below.arrival_from == null:
			check(below.lead(MapInfo.Exit.BACK)["to"] == at, "%s: on, then back, comes back" % at)
		var near: Array[Vector2i] = def.neighbours()
		check(not near.has(at) and near.all(func(v: Vector2i) -> bool: return Worlds.valid(v) and near.count(v) == 1), "%s: its neighbours are other places, each once" % at)
		var rec: LevelRecord = LevelRecord.new()
		check_eq(def.price(MapInfo.Exit.DEEPER, rec), Rules.deeper_price(absi(at.y)), "%s: the way on costs deeper_price of its distance" % at)
		def.pay(MapInfo.Exit.DEEPER, rec)
		check_eq(def.price(MapInfo.Exit.DEEPER, rec), 0, "%s: once, and is then free" % at)
		check_eq(def.price(MapInfo.Exit.LEFT, rec), 0, "%s: side exits cost no stars" % at)
		for k: int in range(Worlds.KINDS.size()):
			var door: int = Worlds.door(k)
			check(def.price(door, rec) == Worlds.proto(k).entry_price(absi(at.y)), "%s: a side door costs its world's entry price" % at)
			def.pay(door, rec)
			check_eq(def.price(door, rec), 0, "%s: once" % at)


## The start's way back leads up; the first level up leads back down into it; hyperspace may cross
## the start into the other branch.
func _branches() -> void:
	var start: NextWorldDef = Rules.def_for(Vector2i(28, 0))
	var up: Dictionary = start.lead(MapInfo.Exit.BACK)
	check(up["to"] == Vector2i(28, -1) and int(up["arrive"]) == MapInfo.Exit.BACK and up["way"] == Vector2.UP, "the start's way back leads up, arriving at the way back of the first level up")
	var first_up: NextWorldDef = Rules.def_for(Vector2i(28, -1))
	var home: Dictionary = first_up.lead(MapInfo.Exit.BACK)
	check(home["to"] == Vector2i(28, 0) and int(home["arrive"]) == MapInfo.Exit.BACK and home["way"] == Vector2.DOWN, "and its way back leads down into the start, at the start's way up")
	check(Rules.def_for(Vector2i(28, 1)).lead(MapInfo.Exit.BACK)["arrive"] == MapInfo.Exit.DEEPER, "while the first level down leads back up to the start's way down")
	check(first_up.exit_dir(MapInfo.Exit.DEEPER) == Vector2.UP and first_up.exit_dir(MapInfo.Exit.BACK) == Vector2.DOWN and start.exit_dir(MapInfo.Exit.BACK) == Vector2.UP, "chevrons point the way each exit leads")
	check(start.leads_on(MapInfo.Exit.BACK) and start.leads_on(MapInfo.Exit.DEEPER) and not first_up.leads_on(MapInfo.Exit.BACK) and first_up.leads_on(MapInfo.Exit.DEEPER) and not Rules.def_for(Vector2i(28, 1)).leads_on(MapInfo.Exit.BACK), "the start's way up is a way on (printed pink), as its way down is; ways back are not")
	var rec: LevelRecord = LevelRecord.new()
	check(start.price(MapInfo.Exit.BACK, rec) == Rules.deeper_price(0) and start.price(MapInfo.Exit.DEEPER, rec) == Rules.deeper_price(0), "the start's ways up and down cost the same")
	start.pay(MapInfo.Exit.BACK, rec)
	check(start.price(MapInfo.Exit.BACK, rec) == 0 and start.price(MapInfo.Exit.DEEPER, rec) > 0, "paying the way up leaves the way down to pay")
	check_eq(first_up.price(MapInfo.Exit.BACK, LevelRecord.new()), 0, "a way back toward the start is free")
	var hyper: Hyperspace = Worlds.proto(Worlds.kind_of(Hyperspace)) as Hyperspace
	var crossed: int = 0
	var stayed: int = 0
	var inverse_ok: bool = true
	for x: int in range(1, 200):
		for row: int in [2, -2, 7, -9]:
			var from: Vector2i = Vector2i(x, row)
			if not hyper.deals(from):
				continue
			var to: Vector2i = hyper.destination_for(from)
			inverse_ok = inverse_ok and absi(to.y) == absi(row) + Hyperspace.DROP and absi(to.x - x) <= 1
			if signi(to.y) == signi(row):
				stayed += 1
			else:
				crossed += 1
			var back: Variant = hyper.arriving(to)
			inverse_ok = inverse_ok and back != null and hyper.destination_for(back) == to
	check(inverse_ok, "hyperspace leads %d rows further from the start, and the level it leads to knows a hyperspace that leads there" % Hyperspace.DROP)
	check(crossed > 0 and stayed > crossed, "most stay in their branch, some cross the start into the other (%d stayed, %d crossed)" % [stayed, crossed])
	check(not hyper.deals(Vector2i(28, 0)), "there is no hyperspace door at the start")


func _relics() -> void:
	var ok: bool = true
	var found: Dictionary = {}
	for x: int in range(200):
		for y: int in range(0, 30):
			var move: StringName = Relics.at(Vector2i(x, y))
			ok = ok and (move == &"" or move in Relics.MOVES) and Relics.at(Vector2i(x, y)) == move
			if move != &"":
				found[move] = true
	check(ok, "a level holds one of the relic moves or none, the same every time")
	check_eq(found.size(), Relics.MOVES.size(), "every relic move is found somewhere")
	check_eq(Relics.at(Worlds.side_at(0, Vector2i(28, 5))), &"", "no relic in a side world")


func _ability_tables() -> void:
	var order: Array[StringName] = Abilities.ids()
	check(order.size() == Abilities.ABILITIES.size() and order.all(func(a: StringName) -> bool: return Abilities.max_tier(a) >= 1 and Abilities.label(a) != ""), "every ability has a name and a top tier")
	check(order.all(func(a: StringName) -> bool: return not Abilities.ABILITIES[a].has("cost") or Abilities.is_spell(a)), "only spells have a cast price")
	# The hat's glow names that are not abilities (climb) ask too (RisoPrint.flare).
	check(not Abilities.is_spell(&"climb") and Abilities.is_spell(&"hex") and not Abilities.is_spell(&"wall_climb"), "a name that is not an ability is not a spell (no error)")
	check(Relics.MOVES.all(func(a: StringName) -> bool: return a in order), "every relic move is an ability")
	check(order.all(func(a: StringName) -> bool: return int(Abilities.ABILITIES[a].get("base", 0)) <= Abilities.max_tier(a)), "nothing starts past its top tier")
	var start: Dictionary = Abilities.start_tiers()
	check(order.all(func(a: StringName) -> bool: return int(start[a]) == (1 if a in [&"dash", &"parry"] else 0)), "a run starts with the dash and parry")
	# An ability done by a node: the node says how a tier tunes it (set_tier), and a spell casts
	# (cast_spell) and tells the spell orb how ready it is (readiness) and how long it has left
	# (running). A misspelled or missing one would only fail when that ability is used.
	var wizard: PackedScene = load("res://prefabs/player.tscn")
	var scene_nodes: Node = wizard.instantiate()
	var nodes_ok: bool = true
	for a: StringName in order:
		var entry: Dictionary = Abilities.ABILITIES[a]
		if not entry.has("node"):
			nodes_ok = nodes_ok and not Abilities.is_spell(a)
			continue
		var script: Script = null
		var made: Resource = load(String(entry["make"])) if entry.has("make") else null
		if made is PackedScene:
			var node: Node = (made as PackedScene).instantiate()
			script = node.get_script()
			node.free()
		elif made is Script:
			script = made
		elif scene_nodes.has_node(String(entry["node"])):
			script = scene_nodes.get_node(String(entry["node"])).get_script()
		var spell_ok: bool = [&"cast_spell", &"readiness", &"running"].all(func(m: StringName) -> bool: return _defines(script, m)) if script != null else false
		var ok: bool = script != null and _defines(script, &"set_tier") and (not Abilities.is_spell(a) or spell_ok)
		if not ok:
			print("  %s: its node lacks set_tier, or (a spell) cast_spell, readiness or running" % a)
		nodes_ok = nodes_ok and ok
	scene_nodes.free()
	check(nodes_ok, "every ability's node takes its tier, and every spell's casts and says how ready it is and how long it runs (spells all have a node)")


## Whether `script` (or a script it extends) defines `method`.
func _defines(script: Script, method: StringName) -> bool:
	return not _method(script, method).is_empty()


## `method` as `script` (or a script it extends) defines it (see Object.get_method_list), or {}.
func _method(script: Script, method: StringName) -> Dictionary:
	for m: Dictionary in script.get_script_method_list():
		if StringName(m["name"]) == method:
			return m
	return {}


## Whether method `m` can be called with `n` arguments (counting those with defaults).
func _takes(m: Dictionary, n: int) -> bool:
	var args: int = (m["args"] as Array).size()
	return args - (m["default_args"] as Array).size() <= n and n <= args


## The two things called by name on scripts that share no base class. A prefab's `setup` is
## called as its Placeables entry says ("setup": how many it takes), so each entry must match its
## prefab's script (a boss's own prefab, Bosses.SCENES, as the boss cell's). A hex bolt calls
## `hex_hit(damage, dir)` on the things listed in HexBolt.ANSWERS, so every script with a hex_hit
## must be one of them and take those two.
func _protocols() -> void:
	var setups_ok: bool = true
	for t: int in Placeables.TABLE:
		var node: Node = Placeables.scene(t).instantiate()
		var script: Script = node.get_script() as Script
		node.free()
		var want: int = Placeables.setup_args(t)
		var m: Dictionary = _method(script, &"setup") if script != null else {}
		if (want == 0) != m.is_empty() or (want > 0 and not _takes(m, want)):
			print("  %s: its prefab's setup does not take %d" % [LevelGen.Type.find_key(t), want])
			setups_ok = false
	# A boss built for itself is placed as the boss cell is, so its setup takes the same.
	for boss: StringName in Bosses.SCENES:
		var node: Node = Bosses.scene(boss).instantiate()
		var script: Script = node.get_script() as Script
		node.free()
		if script == null or not _takes(_method(script, &"setup"), Placeables.setup_args(LevelGen.Type.BOSS)):
			print("  %s: its prefab's setup does not take what the boss cell's does" % boss)
			setups_ok = false
	check(setups_ok, "every placed thing's prefab (and each boss's own) has a setup taking what its Placeables entry says, or none")
	var answering: Array[Script] = []
	for path: String in _scripts_in("res://scripts"):
		if FileAccess.get_file_as_string(path).contains("\nfunc hex_hit("):
			answering.append(load(path) as Script)
	var hex_ok: bool = not answering.is_empty()
	for script: Script in answering:
		var listed: bool = false
		var s: Script = script
		while s != null and not listed:
			listed = s in HexBolt.ANSWERS
			s = s.get_base_script()
		if not listed or not _takes(_method(script, &"hex_hit"), 2):
			print("  %s: its hex_hit is not in HexBolt.ANSWERS, or does not take (damage, dir)" % script.resource_path)
			hex_ok = false
	check(hex_ok and HexBolt.ANSWERS.all(func(s: Script) -> bool: return s in answering), "every script a hex bolt answers is in HexBolt.ANSWERS, and each takes (damage, dir) (%d)" % answering.size())


## Every GDScript file under `dir`, at any depth.
func _scripts_in(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_in(dir.path_join(d)))
	return out


## The shrine's offers (Abilities.offers), over many level seeds and the wizard part of the way
## through a run: different abilities, none at its top tier, no relic move before its relic, no
## dash once blink replaces it, and at least one a gain with nothing given up whenever there is one.
func _offers(p: Player) -> void:
	var states: Array[Dictionary] = [{}, {&"hex": 1}, {&"blink": 1, &"double_jump": 2, &"warp": 1}, {}]
	for a: StringName in Abilities.ids():
		if a != &"speed":
			(states[3] as Dictionary)[a] = Abilities.max_tier(a)
	(states[3] as Dictionary)[&"hex"] = 0
	(states[3] as Dictionary)[&"rift"] = 1
	for i: int in range(states.size()):
		p.tiers = Abilities.start_tiers()
		var state: Dictionary = states[i]
		for a: StringName in state:
			p.tiers[a] = int(state[a])
		var problems: Array[String] = []
		for level_seed: int in range(300):
			var picks: Array[StringName] = Abilities.offers(level_seed, p, 3)
			for a: StringName in picks:
				if picks.count(a) > 1:
					problems.append("%s twice" % a)
				if Abilities.tier(p, a) >= Abilities.max_tier(a):
					problems.append("%s past its top tier" % a)
				if a in Relics.MOVES and Abilities.tier(p, a) == 0:
					problems.append("%s before its relic" % a)
				if a == &"dash" and Abilities.tier(p, &"blink") > 0:
					problems.append("the dash with blink")
			var gain_left: bool = Abilities.ids().any(func(a: StringName) -> bool: return _offerable(p, a) and not Abilities.is_swap(p, a))
			if gain_left and picks.all(func(a: StringName) -> bool: return Abilities.is_swap(p, a)):
				problems.append("only swaps at seed %d" % level_seed)
		check(problems.is_empty(), "shrine offers, wizard state %d: %s" % [i, "fine over 300 seeds" if problems.is_empty() else ", ".join(problems.slice(0, 3))])


## Whether a shrine may offer `a` at all, by the rules in Abilities.offers.
func _offerable(p: Player, a: StringName) -> bool:
	if a in Relics.MOVES and Abilities.tier(p, a) == 0:
		return false
	if a == &"dash" and Abilities.tier(p, &"blink") > 0:
		return false
	return Abilities.tier(p, a) < Abilities.max_tier(a)


func _keyring(p: Player) -> void:
	p.tiers = Abilities.start_tiers()
	p.keyring.clear()
	check_eq(p.keyring.capacity(), 1, "without the keyring the wizard carries one key")
	check_eq(p.keyring.take(1), -1, "the first key is simply carried")
	check_eq(p.keyring.take(2), 1, "a second leaves the first behind")
	check_eq(p.keyring.all(), [2] as Array[int], "and is the one carried")
	p.tiers[&"keyring"] = 2
	check_eq(p.keyring.capacity(), 3, "each tier of the keyring carries one more")
	p.keyring.take(0)
	p.keyring.take(3)
	check_eq(p.keyring.take(1), 2, "with the ring full, the oldest is left behind")
	check_eq(p.keyring.all(), [0, 3, 1] as Array[int], "the rest are kept, oldest first")
	check(p.keyring.has(3) and not p.keyring.has(2), "has() knows what is carried")
	p.tiers[&"keyring"] = 0
	p.keyring.set_all([0, 3, 1])
	check_eq(p.keyring.all(), [1] as Array[int], "set_all trims to the ring, oldest dropped")
	p.keyring.set_skeletons(2)
	check(p.keyring.spend_skeleton() and p.keyring.spend_skeleton() and not p.keyring.spend_skeleton(), "a skeleton key is spent once each")
	p.keyring.clear()
	check(p.keyring.all().is_empty() and p.keyring.skeletons() == 0, "a new run starts empty-handed")
