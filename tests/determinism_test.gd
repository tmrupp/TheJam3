extends TestKit
## suite: full (half a minute or more of laying out; layout_fingerprint_test checks a few levels twice in the quick run)
## A level is laid out the same every time (AGENTS.md, "Level generation: determinism matters"):
## a broad sample of places (every band's first, middle and gate rows in two worlds, the garden up
## and down, every kind of side world, and every difficulty preset), each laid out twice, the two
## compared in every property the layout has (each script variable of LevelGen, walked by its
## property list, so one added later is covered too; the world RNG's state after the last draw among
## them). The one test of it: other tests build a level once and check what it holds. That a level
## loaded twice in the game is the same is revisit_test's.
## godot --headless --path . --script res://tests/determinism_test.gd

## The worlds sampled.
const WORLDS: Array[int] = [28, 7]
## The rows of each band sampled (TestKit.band_rows: the first, one in, the middle, the gate's).
const KS: Array[int] = [0, 1, 6, -1]
## How deep into the Variant a property is compared (a level's cells are three deep).
const DEPTH: int = 8


func run() -> void:
	MapInfo.debug = false
	var places: Array = []
	for world: int in WORLDS:
		var garden: Array[int] = [0, 1, -1, Bands.garden_rows(), -Bands.garden_rows()]
		for row: int in garden:
			places.append([Difficulty.DEFAULT, Vector2i(world, row)])
		for band: StringName in [&"cemetery", &"institute", &"crags", &"sky"]:
			if Bands.has(band):
				for row: int in band_rows(band, KS):
					places.append([Difficulty.DEFAULT, Vector2i(world, row)])
		for row: int in [3, -5]:
			places.append([Difficulty.DEFAULT, Worlds.side_at(0, Vector2i(world, row))])
	for kind: int in range(1, Worlds.KINDS.size()):
		places.append([Difficulty.DEFAULT, Worlds.side_at(kind, Vector2i(28, 1))])
	places.append([Difficulty.DEFAULT, Tutorial.of(28)])
	# Every preset, in one level of each band.
	for p: int in range(Difficulty.Preset.size()):
		if p == Difficulty.DEFAULT:
			continue
		for band: StringName in [&"garden", &"cemetery", &"institute", &"crags", &"sky"]:
			if band == &"garden" or Bands.has(band):
				places.append([p, Vector2i(28, 2 if band == &"garden" else NextWorldDef.band_row(band, 1))])
	var differ: Array[String] = []
	var compared: int = 0
	for place: Array in places:
		Difficulty.preset = place[0] as Difficulty.Preset
		var at: Vector2i = place[1]
		if not Worlds.valid(at):
			continue
		var cells: Array = collapse(at)
		if cells.is_empty():
			continue
		var a: Dictionary = _properties(LevelGen.new(cells, Rules.def_for(at)))
		var b: Dictionary = _properties(LevelGen.new(collapse(at), Rules.def_for(at)))
		compared += 1
		var unlike: Array[String] = []
		for name: String in a:
			if a[name] != b.get(name):
				unlike.append(name)
		if not unlike.is_empty():
			differ.append("%s %s: %s" % [Difficulty.NAMES[place[0]], at, ", ".join(unlike)])
	Difficulty.preset = Difficulty.DEFAULT
	check(compared >= 40, "%d places laid out twice" % compared)
	check(differ.is_empty(), "each the same both times, in every property%s" % ("" if differ.is_empty() else " (unlike: %s)" % "; ".join(differ.slice(0, 6))))
	finish()


## Every script variable of `w` (but the private ones, which hold what a pass keeps for itself
## while it works), each written out in full, and the sigils it deals.
func _properties(w: LevelGen) -> Dictionary:
	var out: Dictionary = {}
	for prop: Dictionary in w.get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var name: String = prop["name"]
		if not name.begins_with("_"):
			out[name] = _written(w.get(name), 0)
	# The sigils, dealt the first time one is asked for (LevelGen.sigil_at).
	out["sigils"] = _written(Sigils.deal(w), 0)
	return out


## `v` written out: a cell by its type, what it holds and how it differs, the RNG by its seed and
## state, other objects by their class, containers in their order.
func _written(v: Variant, depth: int) -> String:
	if depth > DEPTH:
		return "..."
	if v is LevelGen.Cell:
		var c: LevelGen.Cell = v
		return "C(%d,%s,%s)" % [c.type, _written(c.extra_info, depth + 1), _written(c.mods, depth + 1)]
	if v is RandomNumberGenerator:
		var r: RandomNumberGenerator = v
		return "R(%d,%d)" % [r.seed, r.state]
	if v is Object:
		return "O(%s)" % (v as Object).get_class()
	if v is Callable:
		return "F"
	if v is Dictionary:
		var parts: PackedStringArray = PackedStringArray()
		for k: Variant in v:
			parts.append(_written(k, depth + 1) + ":" + _written(v[k], depth + 1))
		return "{" + ",".join(parts) + "}"
	if v is Array:
		var parts: PackedStringArray = PackedStringArray()
		for e: Variant in v:
			parts.append(_written(e, depth + 1))
		return "[" + ",".join(parts) + "]"
	return var_to_str(v)
