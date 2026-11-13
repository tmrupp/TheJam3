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
	"garden": ["5182cded83b7fa01", "2d35cc2d677677fb"],
	"garden deeper": ["ec1c4331d343b556", "6394041ce32713b7"],
	"garden above": ["6dbeea8cacac54b4", "fb6bd8eb2e608dfe"],
	"garden way up": ["79162f58f0e941b4", "52c01e858ff0c4c3"],
	"cemetery": ["3698d9d40674149e", "612f1483d1fd8629"],
	"cemetery deeper": ["8c8d9814f7ba0ca9", "1bc776f537694893"],
	"institute": ["a01b45b95ee65bf1", "5a7e609b84cec7dc"],
	"institute deeper": ["4f2078ca6c86a9cc", "4b3e748884c2d855"],
	"crags": ["ef0e44a5b82debef", "869b7326feed264a"],
	"sky": ["044fc57a1630e032", "85a1a7aa2f2fca75"],
	"sky deeper": ["2af2d2ed89d54954", "4a267f1a4718ad04"],
	"hyperspace": ["cd4d98d58e9b4b93", "2903529a86e37396"],
	"hyperspace above": ["43f11c6b31fca101", "c7daee57fdce97e9"],
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
