extends TestKit
## Fingerprints of a few levels of each archetype and a side world, laid out without the game
## scene. Each place has two: its terrain as collapsed (the WFC sample and the collapse), and how
## it was dressed (every cell's type and what it holds, and the order things were laid in).
##
## Many tests rely on levels being laid out exactly as they were, and a draw from the world RNG
## added, dropped or moved upstream shifts everything after it in every level. This test says so
## directly, rather than leaving it to show as failures in tests about something else. When the
## change is meant, copy the fingerprints it prints into GOLDEN, and say in the report that levels
## changed (see AGENTS.md, "Level generation").
## godot --headless --path . --script res://tests/layout_fingerprint_test.gd

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
	["catacombs", &"catacombs", 28, 1],
	["crags", &"crags", 28, 0],
	["sky", &"sky", 28, 0],
	["sky deeper", &"sky", 7, 2],
	["hyperspace", &"side", 28, 3],
	["hyperspace above", &"side", 28, -5],
]

## label -> [terrain, dressing], as printed by this test.
const GOLDEN: Dictionary = {
	"garden": ["3141ca88260d303e", "ae247db8f4c1e194"],
	"garden deeper": ["fb83f8a8fba7e562", "d0a3e80972bfeff6"],
	"garden above": ["a22845835c87543e", "347552e9660f5534"],
	"garden way up": ["d67924ee7d49c1fe", "192c913bfe92a7c1"],
	"cemetery": ["7650e6c907d3323b", "a8b60caaa25cfaec"],
	"cemetery deeper": ["15d89edbee4a610f", "577f408ecf786a90"],
	"catacombs": ["ea38d7ba74ac6456", "18f947fd26b671ba"],
	"crags": ["1f936f59ae152a07", "c32f256b931d28bb"],
	"sky": ["86785972a609d548", "ce64b130991fee91"],
	"sky deeper": ["93cd2873db0561dd", "317716bbc18b0e7f"],
	"hyperspace": ["e9ba117f74a98ef2", "783bbb3a3067b93e"],
	"hyperspace above": ["a4925ba108552847", "96912b05062f4142"],
}


func run() -> void:
	MapInfo.debug = false
	var printed: Array[String] = []
	for place: Array in PLACES:
		var label: String = place[0]
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
		if not GOLDEN.has(label):
			check(false, "%s %s: no fingerprint kept yet" % [label, at])
			continue
		var want: Array = GOLDEN[label]
		if terrain != want[0]:
			check(false, "%s %s: the terrain changed (the WFC sample, the level's size or seed, or the collapse)" % [label, at])
		elif dressing != want[1]:
			check(false, "%s %s: the dressing changed (a placement rule, or an RNG draw added, dropped or moved upstream)" % [label, at])
		else:
			check(true, "%s %s: laid out as before" % [label, at])
	if failed:
		print("If the change is meant, these are the fingerprints now (for GOLDEN):")
		for line: String in printed:
			print(line)
	finish()


## The place a row of PLACES names.
static func _where(place: Array) -> Vector2i:
	var kind: StringName = place[1]
	if kind == &"side":
		return Worlds.side_at(0, Vector2i(int(place[2]), int(place[3])))
	return Vector2i(int(place[2]), NextWorldDef.band_row(kind, int(place[3])))


## The collapsed terrain's fingerprint: every cell's colour, column by column.
static func _terrain(cells: Array) -> String:
	var bytes: PackedInt32Array = PackedInt32Array()
	for column: Array in cells:
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
