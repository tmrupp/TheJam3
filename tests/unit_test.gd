extends TestKit
## The game's rules that are plain arithmetic, checked without the game scene (a second or so):
## level seeds, prices and the other numbers that grow with depth, key colours by rarity, where
## side worlds sit, the bands of archetypes, where each exit leads, the cemetery's darkness, the
## shrine's offers, the keyring, and figures' colours reading on every realm's ground. A rule that needs a level laid out belongs in a test that builds one.
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
	_wind()
	# The rules of a band, where it is in the bands in play (Bands).
	if Bands.has(&"sky"):
		_whale()
	if Bands.has(&"institute"):
		_beast()
		_institute()
	_stations()
	if Bands.has(&"cemetery"):
		_darkness()
	if Bands.has(&"crags"):
		_lodestones()
		_renamed()
	_legibility()
	var p: Player = Player.new()
	_ability_tables()
	_protocols()
	_offers(p)
	_keyring(p)
	p.free()
	finish()


## Figures read on every realm's ground (RisoPrint.legible): each key colour and each department's
## colour, as printed in each realm, stands off its grounds by RisoPrint.FIGURE_CONTRAST and is
## lighter, or has been screened as far as screening goes; in every realm a place prints in (all but
## the F8 cycle's twilight and aurora) it stands off outright. Moss (sun over the rock's ink) would
## be brown on the institute's brown wall unscreened; sun there needs nothing. Every canvas prints
## its things over the rock's ink of the ground behind them in their own inks unless it is the ground, and holds
## the rock's ink in them to what reads (InkCanvas.figure_rock) unless it is the rock.
func _legibility() -> void:
	var all_read: bool = true
	var places_read: bool = true
	var failing: Array[String] = []
	for r: StringName in RisoPrint.REALMS:
		var overprints: Dictionary = {}
		for color: int in range(Rules.KEY_COLOR_COUNT):
			overprints["key %d" % color] = RisoPrint.key_layers(color, r)
		for dept: StringName in RisoPrint.DEPT_INKS:
			overprints[String(dept)] = RisoPrint.legible(RisoPrint.DEPT_INKS[dept], r)
		for what: String in overprints:
			var layers: Array = overprints[what]
			if RisoPrint.reads_on(RisoPrint.printed(layers, r), RisoPrint.grounds(r)):
				continue
			if r != &"twilight" and r != &"aurora":
				places_read = false
				failing.append("%s %s" % [r, what])
			for layer: Array in layers:
				if RisoPrint.plate_ink(int(layer[0]), r) != Color.WHITE and float(layer[1]) > RisoPrint.SCREEN_FLOOR + 0.001:
					all_read = false
					failing.append("%s %s unscreened" % [r, what])
	check(all_read, "every figure colour reads on its realm's ground or is screened as far as it goes %s" % [failing])
	check(places_read, "every figure colour reads outright in every realm a place prints in %s" % [failing])
	var moss: Array = [[RisoPrint.ACCENT, 1.0], [RisoPrint.BLUE, 1.0]]
	check(not RisoPrint.reads_on(RisoPrint.printed(moss, &"institute"), RisoPrint.grounds(&"institute")), "a moss key unscreened sinks into the institute's wall")
	check(float(RisoPrint.key_layers(2, &"institute")[1][1]) < 1.0, "the institute's moss key has its rock ink screened back")
	check_eq(RisoPrint.key_layers(0, &"institute"), [[RisoPrint.ACCENT, 1.0]], "the institute's sun key prints as it is")
	var canvas: InkCanvas = InkCanvas.new()
	check(canvas.punches_wall, "a canvas prints over the rock's ink of the ground in its own inks unless told it is the ground")
	check(not canvas.of_the_rock, "a canvas's rock ink is a thing's, held to what reads, unless told it is the rock")
	canvas.free()
	# The rock's ink in a thing of the game (InkCanvas.figure_rock): screened in the institute, whose
	# brown is near its night, and as it is in the sky, whose white cloud stands well off its night.
	var rock_reads: bool = true
	for r: StringName in RisoPrint.REALMS:
		if r != &"twilight" and r != &"aurora" and not RisoPrint.reads_on(RisoPrint.printed(RisoPrint.legible([[RisoPrint.BLUE, 1.0]], r), r), RisoPrint.grounds(r)):
			rock_reads = false
	check(rock_reads, "a thing's rock ink, held to what reads, reads on the ground of every realm a place prints in")
	check(float(RisoPrint.legible([[RisoPrint.BLUE, 1.0]], &"institute")[0][1]) < 1.0, "the institute screens a thing's rock ink")
	check_eq(RisoPrint.legible([[RisoPrint.BLUE, 1.0]], &"sky"), [[RisoPrint.BLUE, 1.0]], "the sky prints a thing's rock ink as it is")


## The crags' lodestones (Rules.lodestone_at): along each crags row, every stretch of
## Rules.LODESTONE_STRETCH worlds holds each damage spell's stone once (one level in four), so none
## is ever further than a stretch less one along a row; none outside the crags or in a side world.
## How soon an empowered cast comes back (Rules.empower_recharge), and how long a press is held for
## one (Empower.long_enough). Every damage spell's node casts with an empowered flag.
func _lodestones() -> void:
	var spells: Array[StringName] = Abilities.in_slot(&"damage")
	var stretch: int = Rules.LODESTONE_STRETCH
	var each_once: bool = true
	var quarter: bool = true
	for k: int in range(Bands.rows_of(&"crags")):
		var row: int = NextWorldDef.band_row(&"crags", k)
		for s: int in [-3, -1, 0, 1, 5]:
			var found: Dictionary = {}
			var held: int = 0
			for i: int in range(stretch):
				var spell: StringName = Rules.lodestone_at(Vector2i(s * stretch + i, row))
				if spell != &"":
					held += 1
					found[spell] = int(found.get(spell, 0)) + 1
			each_once = each_once and found.size() == spells.size() and found.values().all(func(n: int) -> bool: return n == 1)
			quarter = quarter and held * 4 == stretch
	check(spells.size() == 6 and each_once, "every stretch of %d worlds along every crags row holds each damage spell's lodestone once" % stretch)
	check(quarter, "so one crags level in four holds a lodestone")
	var furthest: int = 0
	var row0: int = NextWorldDef.band_row(&"crags", 0)
	for spell: StringName in spells:
		var last: int = -9999
		for x: int in range(-60, 120):
			if Rules.lodestone_at(Vector2i(x, row0)) == spell:
				if last > -9999:
					furthest = maxi(furthest, x - last)
				last = x
	check(furthest > 0 and furthest <= 2 * stretch - 1, "a spell's stones are never more than %d worlds apart along a row (%d at most)" % [2 * stretch - 1, furthest])
	var outside: bool = true
	for row: int in [0, 2, -2, NextWorldDef.band_row(&"cemetery", 0), NextWorldDef.band_row(&"sky", 0)]:
		for x: int in range(0, 48):
			outside = outside and Rules.lodestone_at(Vector2i(x, row)) == &""
	for x: int in range(0, 48):
		outside = outside and Rules.lodestone_at(Worlds.side_at(0, Vector2i(x, row0))) == &""
	check(outside, "no lodestone outside the crags, nor in a side world")
	check(Rules.lodestone_at(Vector2i(31, row0)) == Rules.lodestone_at(Vector2i(31, row0)), "the same every time")
	check(not is_finite(Rules.empower_recharge(0)), "before any lodestone, no empowered cast")
	var steps: Array[float] = []
	for n: int in range(1, 10):
		steps.append(Rules.empower_recharge(n))
	check(steps.slice(0, 7) == [60.0, 45.0, 34.0, 25.0, 19.0, 14.0, 10.0] and steps[7] == 10.0 and steps[8] == 10.0, "it comes back in 60 s after the first stone, a quarter sooner for each more, 10 s from the seventh on")
	check(not Empower.long_enough(Empower.HOLD - 0.05) and Empower.long_enough(Empower.HOLD) and is_equal_approx(Empower.HOLD, 0.4), "a press held 0.4 s casts empowered, a shorter one as ever")
	var takes: bool = true
	for spell: StringName in spells:
		var made: Resource = load(String(Abilities.ABILITIES[spell]["make"]))
		var script: Script = made as Script
		if made is PackedScene:
			var node: Node = (made as PackedScene).instantiate()
			script = node.get_script()
			node.free()
		takes = takes and _takes(_method(script, &"cast_spell"), 1)
	check(takes, "every damage spell's node casts with an empowered flag (cast_spell(empowered))")


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
	var g: int = Bands.garden_rows()
	# The garden is the hub, both ways from the start; then the bands of each way, in turn, each
	# its rows long, the outermost going on (the garden, a way with none). Asked of the bands in
	# play, so it holds however they are tuned (bands_test tries other layouts).
	var spans: bool = true
	for row: int in range(-g, g + 1):
		spans = spans and NextWorldDef.archetype_at(row) == &"garden"
	for dir: int in [1, -1]:
		var row: int = g + 1
		var last: StringName = &"garden"
		for band: Dictionary in Bands.way(dir):
			last = Bands.name_of(band["arch"])
			for k: int in range(int(band["rows"])):
				spans = spans and NextWorldDef.archetype_at(dir * row) == last and NextWorldDef.band_row(last, k) == dir * row
				row += 1
		spans = spans and NextWorldDef.archetype_at(dir * (row + 40)) == last
	check(spans, "the garden spans rows -%d to %d, then each way's bands follow, their rows each, the outermost going on (%s)" % [g, g, Bands.current])
	check_eq(NextWorldDef.archetype_at(0), &"garden", "the run starts in the garden")
	check_eq(NextWorldDef.first_depth(&"nowhere"), -1, "no band for an archetype that does not exist")
	for kind: StringName in NextWorldDef.archetype_names():
		var def: NextWorldDef = Rules.def_for(Vector2i(28, NextWorldDef.first_depth(kind)))
		check(def.archetype == kind and def.realm() == kind and RisoPrint.REALMS.has(kind), "a %s level is printed in its own realm" % kind)
	var up: int = -(g + 1)
	var above: NextWorldDef = Rules.def_for(Vector2i(28, up))
	check_eq(above.depth, absi(up), "a level's depth is its distance from the start, whichever way")
	check(Rules.where(Vector2i(28, -5)) == "world 28 · height 5" and Rules.where(Vector2i(28, 5)) == "world 28 · depth 5", "a level above the start is named by its height")
	check(not Rules.def_for(Vector2i(28, 0)).chasmed(), "the garden has no chasms")
	if Bands.has(&"sky"):
		var sky: NextWorldDef = Rules.def_for(Vector2i(28, NextWorldDef.first_depth(&"sky")))
		check_eq(sky.size, Vector2i((Vector2(Rules.level_size(sky.depth)) * SkyArchetype.SCALE).round()), "a sky level is SkyArchetype.SCALE times a cave level of its distance")
		check(sky.chasmed(), "the sky has chasms (its gaps)")
	if Bands.has(&"cemetery"):
		check(Rules.def_for(Vector2i(28, NextWorldDef.first_depth(&"cemetery"))).chasmed(), "and the cemetery")


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


## A saved run names its bosses as they are now (RunState.gone_kinds, Bosses.RENAMED): the spider
## slain and its relic waiting read as the golem's, the others as they were; and the golem guards
## the crags' gate, where the spider did.
func _renamed() -> void:
	var old: Dictionary = {"bosses": {&"spider": true, &"worm": true}, "boss_relics": {&"spider": [Vector2i(3, -9), Vector2(10, 20), &"blink"]}}
	var now: Dictionary = RunState.gone_kinds(old)
	check(now["bosses"] == {&"golem": true, &"worm": true} and (now["boss_relics"] as Dictionary).keys() == [&"golem"], "a save's slain spider and its relic are the golem's")
	check(Bosses.row_of(&"golem") == NextWorldDef.band_row(&"crags", Bands.rows_of(&"crags") - 1) and Bosses.row_of(&"spider") == 0, "the golem guards the crags' gate, and the spider nothing")


## A sky level's wind (Rules.wind_of): still with no vane on; the way of the vane last switched
## on, as strong as the vanes on that point that way, the others' doing nothing; still again once
## none of its way is on.
func _wind() -> void:
	var rec: LevelRecord = LevelRecord.new()
	check_eq(Rules.wind_of(rec), 0, "a sky level's wind is still with no vane on")
	rec.vanes_on = {Vector2i(1, 1): 1, Vector2i(2, 1): 1, Vector2i(3, 1): -1}
	rec.wind_way = 1
	check_eq(Rules.wind_of(rec), 2, "two vanes on pointing right: the wind blows right, strength 2")
	rec.wind_way = -1
	check_eq(Rules.wind_of(rec), -1, "turned left by its one left vane: strength 1, the right ones doing nothing")
	rec.vanes_on.erase(Vector2i(3, 1))
	check_eq(Rules.wind_of(rec), 0, "and with none of its way left on, still")
	# More vanes make a gust blow longer, not harder.
	check(Wind.carry_for(1) == Wind.carry_for(3) and Wind.carry_for(0) == 0.0, "a gust carries the wizard as fast whatever its strength")
	check(Wind.gust_for(1) == Wind.GUST and Wind.gust_for(2) > Wind.gust_for(1) and Wind.gust_for(99) == Wind.GUST_MAX, "each vane past the first makes a gust last longer, up to %.0f s" % Wind.GUST_MAX)


## The whale's hunt (WhaleHunt): met a few worlds off the wizard the first time they come into the
## sky; moving a world the way its own level's wind is set, held when the levels either side blow
## into its level, and never far from the wizard; on the sky's top row; never once slain.
func _whale() -> void:
	var run: RunState = RunState.new()
	run.start(28)
	var row: int = WhaleHunt.row()
	check_eq(row, Bosses.row_of(&"whale"), "the whale swims the sky's top row, its gate row")
	check(not WhaleHunt.move(run, Vector2i(28, 0)) and run.whale_x == WhaleHunt.NONE, "nor is it met below the sky")
	var sky: Vector2i = Vector2i(28, NextWorldDef.band_row(&"sky", 2))
	WhaleHunt.move(run, sky)
	var off: int = run.whale_x - sky.x
	check(off != 0 and absi(off) <= WhaleHunt.REACH, "met %d worlds off the wizard's first sky level" % off)
	var x: int = run.whale_x
	var rec: LevelRecord = run.record(Vector2i(x, row))
	rec.vanes_on = {Vector2i.ZERO: 1}
	rec.wind_way = 1
	WhaleHunt.move(run, Vector2i(x, row))
	check_eq(run.whale_x, x + 1, "its own level set to blow right: it moves a world right")
	run.record(Vector2i(x, row)).vanes_on = {Vector2i.ZERO: 1}
	run.record(Vector2i(x, row)).wind_way = 1
	var right: LevelRecord = run.record(Vector2i(x + 2, row))
	right.vanes_on = {Vector2i.ZERO: -1}
	right.wind_way = -1
	check(WhaleHunt.trapped(run, x + 1), "the levels either side blowing into its level: trapped")
	WhaleHunt.move(run, Vector2i(x + 1, row))
	check_eq(run.whale_x, x + 1, "and so held where it is")
	right.vanes_on.clear()
	for i: int in range(6):
		WhaleHunt.move(run, Vector2i(x + 20, row))
	check(absi(run.whale_x - (x + 20)) <= WhaleHunt.REACH, "it never strays more than %d worlds from the wizard" % WhaleHunt.REACH)
	check(WhaleHunt.here(run, Vector2i(run.whale_x, row)) and not WhaleHunt.here(run, Vector2i(run.whale_x, row + 1)), "it is only in its world, on its row")
	run.bosses[&"whale"] = true
	var was: int = run.whale_x
	check(not WhaleHunt.move(run, Vector2i(x, row)) and run.whale_x == was and not WhaleHunt.here(run, Vector2i(was, row)), "slain, it is never met again")



## The beast's souls (BeastSouls): as many go out however much was visited; one stays in a level
## visited for every few visited, so a wizard who explored finds them in places they know and one who
## dived straight down has them flung far, into levels not yet visited, worlds off and across the
## bands; never into a side world, a gate level or the beast's own level; the same every time, sent
## once, and gone with the beast.
func _beast() -> void:
	var gate: Vector2i = Vector2i(28, Bosses.row_of(&"beast"))
	var most: int = BeastSouls.SOULS + BeastSouls.FED_SOULS_MOST
	check_eq([BeastSouls.kept_near(0, most), BeastSouls.kept_near(BeastSouls.VISITS_PER_SOUL, most), BeastSouls.kept_near(BeastSouls.VISITS_PER_SOUL * 3, most), BeastSouls.kept_near(999, most)], [0, 1, 3, most], "one soul stays in a level visited for every %d visited, up to all %d" % [BeastSouls.VISITS_PER_SOUL, most])
	# A run that dived straight down, and one that wandered far along the rows too, both well fed.
	var straight: RunState = RunState.new()
	straight.start(28)
	straight.fed = BeastSouls.FED_PER_SOUL * BeastSouls.FED_SOULS_MOST
	for y: int in range(0, Bosses.row_of(&"beast")):
		straight.record(Vector2i(28, y))
	var wide: RunState = RunState.new()
	wide.start(28)
	wide.fed = straight.fed
	for c: Vector2i in straight.records:
		wide.record(c)
	for x: int in range(10, 46):
		for y: int in [0, 1, 2, 5, -1, -4, 8, 11]:
			wide.record(Vector2i(x, y))
	wide.record(gate)
	wide.record(Worlds.side_at(0, Vector2i(28, 1)))
	BeastSouls.send(straight, gate)
	BeastSouls.send(wide, gate)
	check(straight.souls_sent == most and wide.souls_sent == most, "%d souls go out, however much of the world was visited" % most)
	var kept: int = 0
	var far: int = 0
	var bands: Dictionary = {}
	for c: Vector2i in straight.souls:
		if straight.records.has(c):
			kept += 1
		elif absi(c.x - gate.x) >= BeastSouls.FAR_COLUMNS.x and absi(c.x - gate.x) <= BeastSouls.FAR_COLUMNS.y:
			far += 1
			bands[NextWorldDef.archetype_at(c.y)] = true
	check(kept == BeastSouls.kept_near(BeastSouls.visited(straight, gate).size(), most) and far == most - kept, "dived straight down: %d stay in levels visited, %d flung %d to %d worlds off into levels not yet visited" % [kept, far, BeastSouls.FAR_COLUMNS.x, BeastSouls.FAR_COLUMNS.y])
	check(bands.size() >= 3, "across the bands (%d of them)" % bands.size())
	var known: bool = true
	var allowed: bool = true
	for c: Vector2i in wide.souls:
		known = known and wide.records.has(c)
		if Worlds.is_side(c) or Bosses.gate_at(c.y) != &"" or c == gate:
			allowed = false
	for c: Vector2i in straight.souls:
		if Worlds.is_side(c) or Bosses.gate_at(c.y) != &"" or c == gate:
			allowed = false
	check(known, "explored widely: every one in a level visited")
	check(allowed, "never into a side world, a gate level or its own")
	var again: RunState = RunState.new()
	again.start(28)
	again.fed = straight.fed
	for c: Vector2i in straight.records:
		again.record(c)
	BeastSouls.send(again, gate)
	check(again.souls == straight.souls, "the same places for the same run")
	var sent: Dictionary = straight.souls.duplicate()
	BeastSouls.send(straight, gate)
	check(straight.souls == sent, "sent once only")
	var fresh: RunState = RunState.new()
	fresh.start(28)
	fresh.record(gate)
	BeastSouls.send(fresh, gate)
	check(fresh.souls_sent == BeastSouls.SOULS and fresh.souls.keys().all(func(c: Vector2i) -> bool: return not fresh.records.has(c)), "with nothing else visited, every one is flung far")
	BeastSouls.end(wide)
	check(wide.souls.is_empty(), "slain, its souls go with it")


## The institute's rules (Institute): every master has mastered one of the wizard's damage spells;
## every department studies a band there is, and its portal leads to a row of that band, in the same
## world, dealt by the level and the same every time.
func _institute() -> void:
	check(Institute.MASTERIES.all(func(a: StringName) -> bool: return Abilities.slot_of(a) == &"damage"), "a master masters a damage spell")
	var bands: Array[StringName] = NextWorldDef.archetype_names()
	check(Institute.DEPARTMENTS.values().all(func(b: StringName) -> bool: return bands.has(b) and b != &"institute"), "each department studies another band")
	var def: NextWorldDef = Rules.def_for(Vector2i(28, NextWorldDef.band_row(&"institute", 1)))
	check_eq(def.archetype, &"institute", "the band below the cemetery is the institute")
	for dept: StringName in Institute.DEPARTMENTS:
		var ok: bool = true
		for i: int in range(4):
			var row: int = Institute.department_row(def, dept, i)
			ok = ok and NextWorldDef.archetype_at(row) == Institute.DEPARTMENTS[dept] and row == Institute.department_row(def, dept, i)
		check(ok, "a %s portal leads to a level of %s, the same every time" % [dept, Institute.DEPARTMENTS[dept]])
	var defaults_ok: bool = true
	for dept: StringName in Timetable.LADDERS:
		for a: StringName in Timetable.LADDERS[dept]:
			defaults_ok = defaults_ok and Timetable.default_spell(a) == Timetable.LADDERS[dept][0] and Timetable.default_spell(a) in Institute.MASTERIES
	check(defaults_ok, "an instructor teaching a move casts its department's damage spell, the first rung of its ladder")
	# The departments' climb (Timetable.climb): every rule reads the tiers as they stood.
	var all_met: Dictionary = {&"botany": true, &"astronomy": true, &"geology": true, &"necrology": true}
	var dusk_less: Dictionary = {&"botany": true, &"astronomy": true, &"geology": true, &"necrology": false}
	var t: Callable = func(b: int, a: int, g: int, n: int) -> Dictionary: return {&"botany": b, &"astronomy": a, &"geology": g, &"necrology": n}
	check_eq(Timetable.climb(t.call(1, 1, 1, 1), &"botany", all_met), t.call(2, 2, 2, 1), "botany attended: botany and astronomy rise; geology, botany on its stratum, rises; necrology, with nothing crashed, stays at I")
	check_eq(Timetable.climb(t.call(2, 3, 1, 1), &"geology", all_met), t.call(1, 4, 1, 2), "geology attended: botany crashes, astronomy rises; geology, its own class, falls; necrology rises on the crash")
	check_eq(Timetable.climb(t.call(2, 3, 1, 3), &"", dusk_less), t.call(1, 1, 1, 3), "nothing attended: botany and astronomy crash; geology, nothing laid on it, stays at I; necrology, not meeting, holds")
	check_eq(Timetable.climb(t.call(2, 2, 2, 1), &"astronomy", all_met), t.call(1, 1, 3, 2), "astronomy attended: it crashes (its paper taken), botany too; geology, astronomy on its stratum, rises; necrology rises")
	check_eq(Timetable.climb(t.call(1, 1, 3, 1), &"botany", all_met), t.call(2, 2, 1, 2), "botany attended below geology: geology, not on its stratum, crashes from III; necrology rises on it")
	check_eq(Timetable.climb(t.call(4, 1, 1, 1), &"botany", all_met), t.call(4, 2, 1, 1), "at the top botany holds, neither rising nor crashing")
	check_eq(Timetable.climb(t.call(1, 1, 1, 1), &"", all_met), t.call(1, 1, 1, 1), "falling from I is no crash: nothing rises")
	var seeker: int = KeyRing.paper(&"seeker", 3)
	var lifted: int = KeyRing.stolen(seeker)
	check(lifted != seeker and KeyRing.is_stolen(lifted) and not KeyRing.is_stolen(seeker), "a stolen paper is told from its paper")
	check_eq([KeyRing.paper_spell(lifted), KeyRing.paper_tier(lifted), KeyRing.stolen(lifted)], [&"seeker", 3, lifted], "and holds the same spell and tier (stealing it twice changes nothing)")
	# Every wall style the F7 panel offers has its inks and a name.
	check(RisoPrint.WALL_STYLES.all(func(w: StringName) -> bool: return RisoTerrain.WALL_LOOKS.has(w)) and RisoPrint.WALL_STYLE_NAMES.size() == RisoPrint.WALL_STYLES.size(),
		"each institute wall style has its inks and a name")

## The crags' tower puzzle (Stations): riding needs both ends on and no two off in a row between;
## a dealt level has a way up and a different way down, and can leave the whole line on, quickly even
## with the most stations a line has; a tower is never flipped twice running.
func _stations() -> void:
	check(Stations.rides(0b101, 0, 2) and not Stations.rides(0b1001, 0, 3) and not Stations.rides(0b110, 0, 2), "the car rides past one off station, never two in a row, and only from and to on ones")
	var tiers: Array[int] = [0, 1, 2, 3, 4]
	var t0: int = Time.get_ticks_msec()
	var masks: Array[int] = Stations.deal(5, tiers, 4242)
	var took: int = Time.get_ticks_msec() - t0
	var up: Variant = Stations.way(5, tiers, masks, 1, 0, 4)
	var down: Variant = Stations.way(5, tiers, masks, 1 << 4, 4, 0)
	check(up != null and down != null and up != down, "a dealt level has a way up %s and a different way down %s" % [up, down])
	check(Stations.all_on_reached(5, tiers, masks), "and some flips leave the whole line on")
	check(Stations.deal(5, tiers, 4242) == masks, "the same level deals the same sets every time (%d ms)" % took)
	var seq: Array = up if up != null else []
	var twice: bool = false
	for i: int in range(1, seq.size()):
		twice = twice or seq[i] == seq[i - 1]
	check(not twice, "no tower is flipped twice running")
	# The most stations a line has (CragsArchetype.STOPS.y), six towers: dealt quickly, and passing.
	var many: Array[int] = [0, 2, 4, 5, 7, 8]
	var n: int = CragsArchetype.STOPS.y
	var t1: int = Time.get_ticks_msec()
	var passed: int = 0
	for sd: int in range(5):
		var m: Array[int] = Stations.deal(n, many, 900 + sd)
		var ok: bool = Stations.way(n, many, m, 1, 0, n - 1) != null and Stations.way(n, many, m, 1 << (n - 1), n - 1, 0) != null and Stations.all_on_reached(n, many, m)
		passed += 1 if ok else 0
	check(passed >= 4, "with %d stations, %d of 5 levels deal a way up, a way down and the whole line on (%d ms a deal)" % [n, passed, (Time.get_ticks_msec() - t1) / 5])


## The cemetery's darkness (docs/DEEPER_PLAN.md): a dash out of the dark lights the flame and spends
## a charge, a dash while lit puts it out again while one is left (the table in the plan, from a
## font's three on top of four); about FONTLESS_SHARE of the cemetery's levels have no fonts, but
## never its first row, its gate level, a side world or another band; ossuary doors want more
## darkness deeper, and never stand in the gate level.
func _darkness() -> void:
	print("darkness")
	var charges: int = 4 + Snuffer.CHARGES
	var dark: bool = true
	var seen: Array[Vector2i] = []
	for i: int in range(16):
		var after: Vector2i = Rules.dash_dark(dark, charges)
		dark = after.x == 1
		charges = after.y
		seen.append(after)
	check(seen.slice(0, 4) == [Vector2i(0, 6), Vector2i(1, 6), Vector2i(0, 5), Vector2i(1, 5)], "from the dark with 7: lit 6, dark 6, lit 5, dark 5")
	check(seen[11] == Vector2i(1, 1) and seen.slice(12) == [Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)], "down to the last charge, then a dash leaves the flame lit and spends nothing")
	check_eq(Rules.dash_dark(true, 0), Vector2i(0, 0), "a dash out of the dark with nothing to spend lights the flame")
	var first: int = NextWorldDef.first_depth(&"cemetery")
	var gate: int = NextWorldDef.band_row(&"cemetery", Bands.rows_of(&"cemetery") - 1)
	var fontless: int = 0
	var dealt: int = 0
	var never: bool = true
	for x: int in range(-60, 60):
		never = never and not Rules.fontless_at(Vector2i(x, first)) and not Rules.fontless_at(Vector2i(x, gate)) and not Rules.ossuary_at(Vector2i(x, gate))
		never = never and not Rules.fontless_at(Vector2i(x, 1)) and not Rules.fontless_at(Vector2i(x, NextWorldDef.first_depth(&"institute")))
		for row: int in range(first + 1, gate):
			dealt += 1
			if Rules.fontless_at(Vector2i(x, row)):
				fontless += 1
	check(never, "never fontless in the band's first row, its gate level or another band, and no ossuary in the gate level")
	var share: float = float(fontless) / float(dealt)
	check(absf(share * 100.0 - float(Rules.FONTLESS_SHARE)) < 8.0, "%d of %d of the cemetery's other levels without fonts (%.0f %%)" % [fontless, dealt, share * 100.0])
	check(Rules.ossuary_fill(first) == Rules.OSSUARY_FILL.x and Rules.ossuary_fill(gate - 1) == Rules.OSSUARY_FILL.y and Rules.ossuary_fill(first + 2) > Rules.ossuary_fill(first + 1), "an ossuary door drinks %d charges in the first row, more each row, %d in the last before the gate level" % [Rules.OSSUARY_FILL.x, Rules.OSSUARY_FILL.y])


func _ability_tables() -> void:
	var order: Array[StringName] = Abilities.ids()
	check(order.size() == Abilities.ABILITIES.size() and order.all(func(a: StringName) -> bool: return Abilities.max_tier(a) >= 1 and Abilities.label(a) != ""), "every ability has a name and a top tier")
	check(order.all(func(a: StringName) -> bool: return not Abilities.ABILITIES[a].has("cost") or Abilities.is_spell(a)), "only spells have a cast price")
	# The hat's glow names that are not abilities (climb) ask too (RisoPrint.flare).
	check(not Abilities.is_spell(&"climb") and Abilities.is_spell(&"hex") and not Abilities.is_spell(&"wall_climb"), "a name that is not an ability is not a spell (no error)")
	check(Relics.MOVES.all(func(a: StringName) -> bool: return a in order), "every relic move is an ability")
	check(order.all(func(a: StringName) -> bool: return int(Abilities.ABILITIES[a].get("base", 0)) <= Abilities.max_tier(a)), "nothing starts past its top tier")
	var start: Dictionary = Abilities.start_tiers()
	check(order.all(func(a: StringName) -> bool: return int(start[a]) == (1 if a in [&"dash", &"slash", &"mend"] else 0)), "a run starts with the dash, slash and mend")
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
	# Exam papers ride on the ring as keys do, a slot each.
	var codes_ok: bool = true
	for a: StringName in KeyRing.subjects():
		codes_ok = codes_ok and Abilities.max_tier(a) < KeyRing.PAPER_SPELL
		for t: int in range(1, Abilities.max_tier(a) + 1):
			var code: int = KeyRing.paper(a, t)
			codes_ok = codes_ok and KeyRing.is_paper(code) and KeyRing.paper_spell(code) == a and KeyRing.paper_tier(code) == t
	check(codes_ok, "an exam paper's code holds its subject and tier, for every ability that takes a slot")
	check(KeyRing.subjects().has(&"dash") and KeyRing.subjects().has(&"mend") and KeyRing.subjects().has(&"hex") and not KeyRing.subjects().has(&"vigor"), "the dash and mend have papers too; perks do not")
	check(not KeyRing.is_paper(KeyRing.SKELETON) and not KeyRing.is_paper(0), "and is no key's colour")
	p.tiers[&"keyring"] = 1
	var hex: int = KeyRing.paper(&"hex", 2)
	p.keyring.take(1)
	p.keyring.take(hex)
	var just_hex: Array[int] = [hex]
	check(p.keyring.papers() == just_hex and p.keyring.has(1), "a paper takes a key's slot, beside a key")
	check_eq(p.keyring.take(KeyRing.paper(&"warp", 1)), 1, "and a full ring leaves the oldest behind, key or paper")
	p.keyring.spend(hex)
	var just_warp: Array[int] = [KeyRing.paper(&"warp", 1)]
	check(p.keyring.papers() == just_warp, "spent, it is gone")
	p.tiers[&"keyring"] = 0
	p.keyring.clear()
