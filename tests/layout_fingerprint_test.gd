extends TestKit
## Fingerprints of a few levels of each archetype and a side world, laid out without the game
## scene. Each place has two: its terrain as collapsed (the WFC sample and the collapse), and how
## it was dressed (every cell's type and what it holds, and the order things were laid in).
##
## Many tests rely on levels being laid out exactly as they were, and a draw from the world RNG
## added, dropped or moved upstream shifts everything after it in every level. This test says so
## directly, rather than leaving it to show as failures in tests about something else. When the
## change is meant, run it with "update" after a lone "--" and it writes the fingerprints now into
## GOLDEN itself (or copy the ones it prints), and say in the report that levels changed (see
## AGENTS.md, "Level generation"). The fingerprints are the default band layout's (Bands.DEFAULT):
## under another, places of bands left out are skipped and the rest are only checked to be dressed
## the same way twice.
## godot --headless --path . --script res://tests/layout_fingerprint_test.gd [-- update]

## The places fingerprinted: [label, archetype (or &"side" for side world kind 0), seed, rows into
## the archetype's band counting away from the start (NextWorldDef.band_row; the garden's go down,
## and a negative count goes up from the start), or, for a side world, the row of the level it is
## entered from].
const PLACES: Array = [
	["garden", &"garden", 28, 0],
	["garden deeper", &"garden", 7, 3],
	["garden above", &"garden", 7, -2],
	["garden way up", &"garden", 28, -3],
	["cemetery", &"cemetery", 28, 0],
	["cemetery deeper", &"cemetery", 99, 4],
	["institute", &"institute", 28, 1],
	["institute deeper", &"institute", 7, 4],
	["crags", &"crags", 28, 0],
	["sky", &"sky", 28, 0],
	["sky deeper", &"sky", 7, 2],
	["hyperspace", &"side", 28, 3],
	["hyperspace above", &"side", 28, -5],
]

## label -> [terrain, dressing], as printed by this test.
const GOLDEN: Dictionary = {
	"garden": ["3141ca88260d303e", "6d800d71aa1b359d"],
	"garden deeper": ["fb83f8a8fba7e562", "e2b497d10d73fa3f"],
	"garden above": ["a22845835c87543e", "7895b825bca8d5ed"],
	"garden way up": ["d67924ee7d49c1fe", "f2ff3dccf0cc6ff8"],
	"cemetery": ["66864e266cbd7058", "742ebb88df1c0c5f"],
	"cemetery deeper": ["f1b78ec97a2b8f94", "b7a35184e676949d"],
	"institute": ["b39d2a5e4c3484c8", "670e957385eb5463"],
	"institute deeper": ["95076f54d35f7650", "5dacd54bae2de6ee"],
	"crags": ["244bfc1eeee7e55f", "1da442d6964815dc"],
	"sky": ["86785972a609d548", "70ff66db545a2244"],
	"sky deeper": ["93cd2873db0561dd", "cd135a45578d5081"],
	"hyperspace": ["e9ba117f74a98ef2", "783bbb3a3067b93e"],
	"hyperspace above": ["a4925ba108552847", "96912b05062f4142"],
}


func run() -> void:
	MapInfo.debug = false
	var update: bool = "update" in OS.get_cmdline_user_args()
	var compare: bool = Bands.current == Bands.DEFAULT
	if not compare:
		print("  the bands in play are %s, not %s: fingerprints are not compared" % [Bands.current, Bands.DEFAULT])
	var printed: Array[String] = []
	var changed: bool = false
	for place: Array in PLACES:
		var label: String = place[0]
		var kind: StringName = place[1]
		if kind != &"side" and not Bands.has(kind):
			print("  skip ", label, ": no ", kind, " in the bands in play")
			continue
		var at: Vector2i = _where(place)
		var cells: Array = collapse(at)
		check(not cells.is_empty(), "%s %s: the terrain collapses" % [label, at])
		if cells.is_empty():
			continue
		var w: LevelGen = LevelGen.new(cells, Rules.def_for(at))
		var again: LevelGen = LevelGen.new(cells, Rules.def_for(at))
		var terrain: String = _terrain(cells)
		var dressing: String = _dressing(w)
		check_eq(_dressing(again), dressing, "%s %s: dressed the same way twice" % [label, at])
		printed.append('\t"%s": ["%s", "%s"],' % [label, terrain, dressing])
		if not compare:
			continue
		if not GOLDEN.has(label):
			changed = true
			check(update, "%s %s: no fingerprint kept yet" % [label, at])
			continue
		var want: Array = GOLDEN[label]
		changed = changed or terrain != want[0] or dressing != want[1]
		if update:
			continue
		if terrain != want[0]:
			check(false, "%s %s: the terrain changed (the WFC sample, the level's size or seed, or the collapse)" % [label, at])
		elif dressing != want[1]:
			check(false, "%s %s: the dressing changed (a placement rule, or an RNG draw added, dropped or moved upstream)" % [label, at])
		else:
			check(true, "%s %s: laid out as before" % [label, at])
	if update and compare and changed:
		_write_golden(printed)
	elif failed:
		print("If the change is meant, these are the fingerprints now (for GOLDEN, or run with -- update):")
		for line: String in printed:
			print(line)
	finish()


## Write `lines` (as printed) into this script's GOLDEN, in place of what it holds.
func _write_golden(lines: Array[String]) -> void:
	var path: String = (get_script() as Script).resource_path
	var text: String = FileAccess.get_file_as_string(path)
	var start: int = text.find("const GOLDEN: Dictionary = {")
	var end: int = text.find("\n}\n", start)
	if start < 0 or end < 0:
		check(false, "GOLDEN found in %s to write" % path)
		return
	text = text.substr(0, start) + "const GOLDEN: Dictionary = {\n" + "\n".join(lines) + text.substr(end)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("GOLDEN updated in %s: say in the report that levels changed" % path)


## The place a row of PLACES names.
static func _where(place: Array) -> Vector2i:
	var kind: StringName = place[1]
	if kind == &"side":
		return Worlds.side_at(0, Vector2i(int(place[2]), int(place[3])))
	return Vector2i(int(place[2]), NextWorldDef.band_row(kind, int(place[3])))


## The collapsed terrain's fingerprint: every cell's colour, column by column (the small insides
## collapsed after it, a crypt's, are left out: they show in the dressing's, as they are built).
static func _terrain(cells: Array) -> String:
	var bytes: PackedInt32Array = PackedInt32Array()
	for column: Variant in cells:
		if not column is Array:
			continue
		for c: Color in column:
			bytes.append(c.to_rgba32())
	return _digest(bytes.to_byte_array())


## The dressing's fingerprint: every cell's type, then each object in the order it was laid, with
## what it holds and how it differs from the usual (Cell.mods).
static func _dressing(w: LevelGen) -> String:
	var types: PackedByteArray = PackedByteArray()
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			types.append(w.get_cell(Vector2i(x, y)).type)
	var laid: PackedStringArray = PackedStringArray()
	for v: Vector2i in w.objects:
		var cell: LevelGen.Cell = w.get_cell(v)
		laid.append("%s %d %s %s" % [v, cell.type, var_to_str(cell.extra_info), var_to_str(cell.mods)])
	return _digest(types + "\n".join(laid).to_utf8_buffer())


## A short, stable digest of `bytes`.
static func _digest(bytes: PackedByteArray) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode().substr(0, 16)
