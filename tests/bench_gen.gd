extends TestKit
## What laying a level out costs, by place: the terrain collapse (WFC) and the layout (LevelGen),
## timed apart, for rows down and up from the start. No game scene.
## With "passes" after a lone "--", what each pass of the layout costs instead (LevelGen.on_pass),
## on average over a few rows of each band in a few worlds (docs/PERF_PLAN.md keeps the figures).
## godot --headless --path . --script res://tests/bench_gen.gd [-- passes]

## The rows timed (down then up).
const ROWS: Array[int] = [0, 2, 4, 6, 8, 10, 12, 14, 16, -2, -4, -6, -8, -10, -12]
## For "passes": the worlds, and the rows of each band counted into it (TestKit.band_rows).
const PASS_WORLDS: Array[int] = [28, 7, 99]
const PASS_ROWS: Array[int] = [0, 2, 5, -1]
## The bands timed pass by pass.
const PASS_BANDS: Array[StringName] = [&"garden", &"cemetery", &"institute", &"crags", &"sky"]


func run() -> void:
	if "passes" in OS.get_cmdline_user_args():
		_passes()
		finish()
		return
	var total_c: float = 0.0
	var total_l: float = 0.0
	for row: int in ROWS:
		var at: Vector2i = Vector2i(28, row)
		var def: NextWorldDef = Rules.def_for(at)
		var t0: int = Time.get_ticks_usec()
		var cells: Array = collapse(at)
		var t1: int = Time.get_ticks_usec()
		if cells.is_empty():
			print("BENCH row %3d  never settled" % row)
			continue
		var w: LevelGen = LevelGen.new(cells, def)
		var t2: int = Time.get_ticks_usec()
		var c_ms: float = (t1 - t0) / 1000.0
		var l_ms: float = (t2 - t1) / 1000.0
		total_c += c_ms
		total_l += l_ms
		print("BENCH row %3d %-10s %-9s collapse %8.1f ms  layout %8.1f ms  objects %d" % [row, def.realm(), def.size, c_ms, l_ms, w.objects.size()])
	print("BENCH total collapse %.0f ms, layout %.0f ms" % [total_c, total_l])
	finish()


## Each band's passes, the slowest first, as milliseconds a level on average.
func _passes() -> void:
	for band: StringName in PASS_BANDS:
		if not Bands.has(band):
			continue
		var spent: Dictionary = {}
		var levels: int = 0
		var total: float = 0.0
		var last: Array[int] = [0]
		LevelGen.on_pass = func(pass_name: StringName) -> void:
			var now: int = Time.get_ticks_usec()
			spent[pass_name] = float(spent.get(pass_name, 0.0)) + float(now - last[0]) / 1000.0
			last[0] = now
		var rows: Array[int] = [0, 2, 5, -3]
		if band != &"garden":
			rows = band_rows(band, PASS_ROWS)
		for world: int in PASS_WORLDS:
			for row: int in rows:
				var at: Vector2i = Vector2i(world, row)
				var cells: Array = collapse(at)
				if cells.is_empty():
					continue
				last[0] = Time.get_ticks_usec()
				var t0: int = last[0]
				LevelGen.new(cells, Rules.def_for(at))
				total += float(Time.get_ticks_usec() - t0) / 1000.0
				levels += 1
		LevelGen.on_pass = Callable()
		var names: Array = spent.keys()
		names.sort_custom(func(a: StringName, b: StringName) -> bool: return float(spent[a]) > float(spent[b]))
		var parts: PackedStringArray = PackedStringArray()
		for pass_name: StringName in names:
			if float(spent[pass_name]) / levels >= 1.0:
				parts.append("%s %.0f" % [pass_name, float(spent[pass_name]) / levels])
		print("BENCH PASSES %-9s %4.0f ms a level (%d levels): %s" % [band, total / levels, levels, ", ".join(parts)])
