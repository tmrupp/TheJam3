extends TestKit
## Whole levels, many at once, to look over what the generator makes: for each band asked for and
## each of a few worlds, a level of that band (its row in the band dealt by the world, so the
## band's sizes and gates turn up), photographed whole (TestKit.overview_still) and its map's level
## page with the whole level inked. Written to ../art-captures/riso-frames/overview/ as
## <band>_<world>_<row>.png and <band>_<world>_<row>_map.png, with a line per level printed (its
## size, and how many enemies, keys and shrines it holds).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_overview.gd
## Options after a lone "--" (all optional): bands=garden,crags (every band by default),
## worlds=4 (how many worlds a band, WORLDS by default), first=100 (the first world: worlds are
## first, first + 1, ...; picked by PICK_SEED by default), row=2 (that row of each band rather than
## a dealt one), maps=false (no map pages), tiles=4 (tiles across a level).

## Worlds a band by default, and the seed that picks them.
const WORLDS: int = 3
const PICK_SEED: int = 20261015
## Tiles across a level by default.
const TILES: int = 3
## Where the stills go, in the stills folder.
const FOLDER: String = "overview"


func run() -> void:
	window()
	var opts: Dictionary = _options()
	var bands: Array[StringName] = NextWorldDef.archetype_names()
	if opts.has("bands"):
		bands.clear()
		for b: String in String(opts["bands"]).split(",", false):
			bands.append(StringName(b.strip_edges()))
	var count: int = int(opts.get("worlds", WORLDS))
	var tiles: int = int(opts.get("tiles", TILES))
	var maps: bool = String(opts.get("maps", "true")) != "false"
	var pick: RandomNumberGenerator = RandomNumberGenerator.new()
	pick.seed = PICK_SEED
	var first: int = int(opts.get("first", pick.randi_range(1, 900)))
	await boot(first)
	player.get_node("CameraControl").set_process(false)
	var shot: int = 0
	for band: StringName in bands:
		if band not in NextWorldDef.archetype_names():
			print("  no band named ", band)
			continue
		var rows: int = NextWorldDef.GARDEN_ROWS + 1 if NextWorldDef.band_row(band, 0) == 0 else NextWorldDef.BAND
		for i: int in range(count):
			var world: int = first + i
			var k: int = int(opts["row"]) if opts.has("row") else (hash([world, band]) % rows + rows) % rows
			var at: Vector2i = Vector2i(world, NextWorldDef.band_row(band, k))
			await _go(at)
			var name: String = "%s/%s_%d_%d" % [FOLDER, band, at.x, at.y]
			await overview_still(name + ".png", tiles)
			if maps:
				info.ink_whole_map()
				var map: Node = main.get_node("RisoMap")
				map.call("toggle")
				await frames(30)
				save_still(name + "_map.png")
				map.call("toggle")
				await frames(10)
			var w: LevelGen = info.world
			print("  %s %s: %d x %d cells, %d enemies, %d keys, %d shrines" % [band, Rules.where(at), w.size.x, w.size.y, _enemies(w), count_of(w, LevelGen.Type.KEY), count_of(w, LevelGen.Type.SHRINE)])
			shot += 1
	print("CAPTURED ", shot, " levels to ", ProjectSettings.globalize_path(STILLS).path_join(FOLDER))
	RunState.delete_save()
	finish()


## Go straight to place `at`, with no title card to wait out, and hold the wizard still there.
func _go(at: Vector2i) -> void:
	var def: NextWorldDef = Rules.def_for(at)
	if def != null and def.arch != null:
		info.region = def.arch.name
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	await until(func() -> bool: return RisoTransition.instance == null or not RisoTransition.instance.titling(), 10000)
	await frames(60)


## How many enemies level `w` holds (every placed thing the table calls an enemy).
func _enemies(w: LevelGen) -> int:
	var n: int = 0
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			if Placeables.has_flag(w.get_cell(Vector2i(x, y)).type, &"enemy"):
				n += 1
	return n


## The options given after "--", as name -> value.
func _options() -> Dictionary:
	var out: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			out[parts[0]] = parts[1]
	return out
