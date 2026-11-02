extends TestKit
## The band layout can be tuned freely (Bands): under each of its layouts and a few made up here
## (bands short and long, one way with none, the bands in another order, the garden wider or
## narrower), the rules that follow from it still hold. The garden spans its rows either side of the
## start and each band follows its way's last, its rows long, the outermost going on; band_row
## and first_depth land in their band; each band's far end, and the garden's two ends, are gates
## held by their boss and nothing else; a way out crosses the gates past it nearest first; a gate
## level holds no relic of its own; a level in each band and at each gate lays out, the boss (all
## but the whale, which roams) in its gate level; and a band's "tune" names only Archetype's vars,
## and dresses its levels as it says.
## godot --headless --path . --script res://tests/bands_test.gd

## Layouts of its own, besides Bands.LAYOUTS.
var made_up: Dictionary = {
	&"short": {
		"garden": {"arch": Bands.GARDEN, "rows": 1, "down": &"worm", "up": &"bramble"},
		"down": [{"arch": Bands.CEMETERY, "rows": 2, "boss": &"necromancer"}],
		"up": [{"arch": Bands.CRAGS, "rows": 9, "boss": &"golem"}],
	},
	&"lopsided": {
		"garden": {"arch": Bands.GARDEN, "rows": 2, "down": &"worm", "up": &"bramble"},
		"down": [
			{"arch": Bands.INSTITUTE, "rows": 3, "boss": &"beast"},
			{"arch": Bands.CEMETERY, "rows": 4, "boss": &"necromancer"},
		],
		"up": [],
	},
	&"wide": {
		"garden": {"arch": Bands.GARDEN, "rows": 5, "down": &"worm", "up": &"bramble", "tune": {"star_share": 0.05, "wisp_share": 0.0}},
		"down": [{"arch": Bands.CEMETERY, "rows": 6, "boss": &""}],
		"up": [
			{"arch": Bands.SKY, "rows": 2, "boss": &"whale"},
			{"arch": Bands.CRAGS, "rows": 3, "boss": &"golem"},
		],
	},
}


func run() -> void:
	MapInfo.debug = false
	var was: Dictionary = Bands.layout
	var was_name: StringName = Bands.current
	var layouts: Dictionary = Bands.LAYOUTS.duplicate()
	layouts.merge(made_up)
	for name: StringName in layouts:
		Bands.use(layouts[name])
		print("the %s bands" % name)
		_rows(name)
		_gates(name)
		_levels(name)
		_tuning(name)
	# Put back as it was: by name, or (a layout of the tests' own) as itself.
	Bands.use(was_name if Bands.LAYOUTS.has(was_name) else was)
	check_eq(Bands.layout, was, "the bands in play are put back")
	finish()


## Which archetype holds which row, and where band_row lands.
func _rows(name: StringName) -> void:
	var g: int = Bands.garden_rows()
	var ok: bool = true
	for row: int in range(-g, g + 1):
		ok = ok and NextWorldDef.archetype_at(row) == &"garden"
	var counted: bool = true
	for dir: int in [1, -1]:
		var row: int = g + 1
		var last: StringName = &"garden"
		for band: Dictionary in Bands.way(dir):
			last = Bands.name_of(band["arch"])
			counted = counted and Bands.rows_of(last) == int(band["rows"]) and NextWorldDef.first_depth(last) == dir * row
			for k: int in range(int(band["rows"])):
				ok = ok and NextWorldDef.archetype_at(dir * row) == last and NextWorldDef.band_row(last, k) == dir * row
				row += 1
		for past: int in [0, 1, 40]:
			ok = ok and NextWorldDef.archetype_at(dir * (row + past)) == last
	check(ok, "%s: the garden spans rows -%d to %d, then each way's bands, their rows each, the outermost going on" % [name, g, g])
	check(counted and Bands.rows_of(&"garden") == g + 1 and NextWorldDef.band_row(&"garden", 2) == 2, "%s: each band counts its own rows from its row nearest the start" % name)
	var listed: bool = NextWorldDef.archetype_names()[0] == &"garden"
	for kind: StringName in [&"cemetery", &"institute", &"crags", &"sky"]:
		listed = listed and Bands.has(kind) == NextWorldDef.archetype_names().has(kind)
		if not Bands.has(kind):
			listed = listed and NextWorldDef.first_depth(kind) == -1 and Bands.rows_of(kind) == 0
	check(listed, "%s: only the bands in it are listed, and a band left out has no rows" % name)


## Who guards which gate, and which gates a way out crosses.
func _gates(name: StringName) -> void:
	var g: int = Bands.garden_rows()
	var want: Dictionary = {g: &"worm", -g: &"bramble"}
	var far: int = g
	for dir: int in [1, -1]:
		var end: int = g
		for band: Dictionary in Bands.way(dir):
			end += int(band["rows"])
			if band["boss"] != &"":
				want[dir * end] = band["boss"]
		far = maxi(far, end)
	var ok: bool = true
	for row: int in range(-(far + 8), far + 9):
		ok = ok and Bosses.gate_at(row) == StringName(want.get(row, &""))
	for row: int in want:
		ok = ok and Bosses.row_of(want[row]) == row and Relics.at(Vector2i(28, row)) == &""
	check(ok and Bands.bosses().size() == want.size(), "%s: a gate at each of the garden's ends and each band's far end, with its boss, and no relic of its own" % name)
	for dir: int in [1, -1]:
		var gates: Array[StringName] = []
		for d: int in range(1, far + 2):
			if want.has(dir * d):
				gates.append(want[dir * d])
		check_eq(Bosses.crossed(0, dir * (far + 2)), gates, "%s: a way out %s past every band crosses every gate on it, nearest first" % [name, "down" if dir > 0 else "up"])
		check(Bosses.crossed(dir * (far + 2), 0).is_empty(), "%s: and a way back none" % name)


## A level in each band's first row and at each gate lays out, the boss in its gate level.
func _levels(name: StringName) -> void:
	var rows: Array[int] = [0]
	for kind: StringName in NextWorldDef.archetype_names():
		if kind != &"garden":
			rows.append(NextWorldDef.first_depth(kind))
	var bosses: Dictionary = {}
	for boss: StringName in Bands.bosses():
		bosses[Bosses.row_of(boss)] = boss
		rows.append(Bosses.row_of(boss))
	var ok: bool = true
	var held: bool = true
	for row: int in rows:
		var w: LevelGen = build(Vector2i(28, row))
		ok = ok and w != null and w.exits.has(MapInfo.Exit.DEEPER)
		if w == null or not bosses.has(row):
			continue
		var found: Array[Vector2i] = w.objects_of(LevelGen.Type.BOSS)
		if bosses[row] == &"whale":
			held = held and found.is_empty()
		else:
			held = held and found.size() == 1 and StringName(w.get_cell(found[0]).extra_info) == bosses[row]
	check(ok, "%s: a level lays out in every band and at every gate (rows %s)" % [name, rows])
	check(held, "%s: each boss in its gate level, but the whale, which roams" % name)


## Every "tune" in the layout names a var of its band's archetype, and the archetype made for a row
## of the band carries it.
func _tuning(name: StringName) -> void:
	var bands: Array = [Bands.layout["garden"]]
	bands.append_array(Bands.way(1))
	bands.append_array(Bands.way(-1))
	var named: bool = true
	var carried: bool = true
	for band: Dictionary in bands:
		var tune: Dictionary = band.get("tune", {})
		var plain: Archetype = (band["arch"] as Script).new()
		var row: int = 0 if band == Bands.layout["garden"] else NextWorldDef.first_depth(Bands.name_of(band["arch"]))
		var made: Archetype = NextWorldDef.archetype_for(row)
		for key: String in tune:
			named = named and key in plain
			carried = carried and made.get(key) == tune[key]
	check(named and carried, "%s: each band's tuning names its archetype's own settings, and its levels carry them" % name)
	var garden: Dictionary = (Bands.layout["garden"] as Dictionary).get("tune", {})
	if garden.has("wisp_share") and float(garden["wisp_share"]) == 0.0:
		var w: LevelGen = build(Vector2i(28, 0))
		check(count_of(w, LevelGen.Type.ENEMY) == 0 and count_of(w, LevelGen.Type.COIN) < 40, "%s: a garden tuned to no wisps and few stars has none, and few" % name)
