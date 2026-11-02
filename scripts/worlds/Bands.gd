class_name Bands
extends RefCounted
## The map of bands a game is played on (docs/REGIONS_PLAN.md §2): which kind of level (Archetype)
## holds which rows, and which boss guards the far end of each band. Every question about bands
## (NextWorldDef.archetype_for and band_row, Bosses.gate_at and row_of, and the rules that count
## rows within a band) reads the layout in use here, so a band is tuned, moved, lengthened or left
## out by changing its line in LAYOUTS, and nothing else.
##
## A layout:
## - "garden": the hub a run starts in, {"arch": its script, "rows": how many rows it spans either
##   side of the start, "down": the boss at its way down, "up": the boss at its way up};
## - "down" and "up": the bands that follow it each way, nearest the start first, each {"arch": its
##   script, "rows": how many rows it spans, "boss": the boss at its far end, &"" for none}.
## Any of them may also have "tune": {an Archetype var: its value in that band}, to dress the band's
## levels thicker or thinner than its archetype does (star_share, wisp_share, watcher_share,
## hoppers_per_k, and the rest of Archetype's vars); bands_test checks every name is one.
## The outermost band each way goes on for ever past its end (the garden, when a way has none).
##
## A game plays the layout named by the "layout=<name>" option after a lone "--" on the command line,
## else DEMO's when the build has the "demo" feature (an export preset's custom feature), else
## DEFAULT. A test may swap in any layout with `use` before it lays anything out.

const GARDEN: Script = preload("res://scripts/worlds/archetypes/GardenArchetype.gd")
const CEMETERY: Script = preload("res://scripts/worlds/archetypes/CemeteryArchetype.gd")
const INSTITUTE: Script = preload("res://scripts/worlds/archetypes/InstituteArchetype.gd")
const CRAGS: Script = preload("res://scripts/worlds/archetypes/CragsArchetype.gd")
const SKY: Script = preload("res://scripts/worlds/archetypes/SkyArchetype.gd")

## The layouts a game can be played on, by name: the whole game, and the garden alone (the demo),
## with its two bosses at its ends and the garden going on past them.
const LAYOUTS: Dictionary = {
	&"full": {
		"garden": {"arch": GARDEN, "rows": 3, "down": &"worm", "up": &"bramble"},
		"down": [
			{"arch": CEMETERY, "rows": 6, "boss": &"necromancer"},
			{"arch": INSTITUTE, "rows": 6, "boss": &"beast"},
		],
		"up": [
			{"arch": CRAGS, "rows": 6, "boss": &"golem"},
			{"arch": SKY, "rows": 6, "boss": &"whale"},
		],
	},
	&"garden": {
		"garden": {"arch": GARDEN, "rows": 3, "down": &"worm", "up": &"bramble"},
		"down": [],
		"up": [],
	},
}
## The layout a game is played on unless told otherwise, and a demo build's.
const DEFAULT: StringName = &"full"
const DEMO: StringName = &"garden"

## The name of the layout in use (&"custom" for one given to `use` as a Dictionary).
static var current: StringName = _first()
## The layout in use.
static var layout: Dictionary = LAYOUTS[current]


## The layout a game starts on (see the class description).
static func _first() -> StringName:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("layout=") and LAYOUTS.has(StringName(arg.trim_prefix("layout="))):
			return StringName(arg.trim_prefix("layout="))
	return DEMO if OS.has_feature("demo") else DEFAULT


## Play on layout `which`: a name in LAYOUTS, or a layout of one's own (a Dictionary shaped as they
## are). Only before any level is laid out: the generator keeps the levels it has made.
static func use(which: Variant) -> void:
	if which is Dictionary:
		layout = which
		current = &"custom"
	else:
		current = StringName(which)
		layout = LAYOUTS[current]


## The rows the garden spans either side of the start.
static func garden_rows() -> int:
	return int((layout["garden"] as Dictionary)["rows"])


## The bands one way of the start (`dir` +1 down, -1 up), nearest first.
static func way(dir: int) -> Array:
	return layout["down"] if dir > 0 else layout["up"]


## The name of the archetype `script` makes.
static func name_of(script: Script) -> StringName:
	return (script.new() as Archetype).name


## Every archetype in the layout, the garden first, then down's, then up's.
static func scripts() -> Array[Script]:
	var out: Array[Script] = [(layout["garden"] as Dictionary)["arch"]]
	for dir: int in [1, -1]:
		for band: Dictionary in way(dir):
			out.append(band["arch"])
	return out


## Whether the layout has a band of the archetype named `kind`.
static func has(kind: StringName) -> bool:
	return scripts().any(func(s: Script) -> bool: return name_of(s) == kind)


## The band holding row `row` (its line in the layout; the garden's for the garden).
static func band_at(row: int) -> Dictionary:
	var d: int = absi(row) - garden_rows()
	var garden: Dictionary = layout["garden"]
	if d <= 0:
		return garden
	var bands: Array = way(row)
	if bands.is_empty():
		return garden
	for band: Dictionary in bands:
		d -= int(band["rows"])
		if d <= 0:
			return band
	return bands.back()


## The script of the archetype of levels on row `row`.
static func script_at(row: int) -> Script:
	return band_at(row)["arch"]


## The archetype of levels on row `row`, as its band tunes it (a new one each time: it is small).
static func archetype_at(row: int) -> Archetype:
	var band: Dictionary = band_at(row)
	var arch: Archetype = (band["arch"] as Script).new()
	var tune: Dictionary = band.get("tune", {})
	for key: String in tune:
		arch.set(key, tune[key])
	return arch


## Row `k` of the band of the archetype named `kind`, counting from its row nearest the start (0)
## away from it (the garden's, down from the start), or -1 for an archetype with no band.
static func band_row(kind: StringName, k: int) -> int:
	if name_of((layout["garden"] as Dictionary)["arch"]) == kind:
		return k
	for dir: int in [1, -1]:
		var before: int = garden_rows() + 1
		for band: Dictionary in way(dir):
			if name_of(band["arch"]) == kind:
				return dir * (before + k)
			before += int(band["rows"])
	return -1


## How many rows band_row counts for the archetype named `kind` before its band ends: its band's
## rows (the garden's, from the start down to its way down), or 0 for one with no band.
static func rows_of(kind: StringName) -> int:
	if name_of((layout["garden"] as Dictionary)["arch"]) == kind:
		return garden_rows() + 1
	for dir: int in [1, -1]:
		for band: Dictionary in way(dir):
			if name_of(band["arch"]) == kind:
				return int(band["rows"])
	return 0


## The boss whose gate is the way on of row `row`'s levels, or &"" for a row with no gate: the
## garden's at either end of it, and each band's at its far end.
static func gate_at(row: int) -> StringName:
	var g: int = garden_rows()
	var garden: Dictionary = layout["garden"]
	if row == g:
		return garden["down"]
	if row == -g:
		return garden["up"]
	var end: int = g
	for band: Dictionary in way(row):
		end += int(band["rows"])
		if absi(row) == end:
			return band["boss"]
	return &""


## The row of the gate boss `name` guards (0 for none).
static func row_of(name: StringName) -> int:
	if name == &"":
		return 0
	var g: int = garden_rows()
	var garden: Dictionary = layout["garden"]
	if name == garden["down"]:
		return g
	if name == garden["up"]:
		return -g
	for dir: int in [1, -1]:
		var end: int = g
		for band: Dictionary in way(dir):
			end += int(band["rows"])
			if band["boss"] == name:
				return dir * end
	return 0


## Every boss in the layout: the garden's way down's and way up's, then each band's, down's first.
static func bosses() -> Array[StringName]:
	var garden: Dictionary = layout["garden"]
	var out: Array[StringName] = [garden["down"], garden["up"]]
	for dir: int in [1, -1]:
		for band: Dictionary in way(dir):
			if band["boss"] != &"":
				out.append(band["boss"])
	return out
