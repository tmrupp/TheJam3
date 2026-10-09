extends TestKit
## What laying a level out costs, by place: the terrain collapse (WFC) and the layout (LevelGen),
## timed apart, for rows down and up from the start. No game scene.
## godot --headless --path . --script res://tests/bench_gen.gd

## The rows timed (down then up).
const ROWS: Array[int] = [0, 2, 4, 6, 8, 10, 12, 14, 16, -2, -4, -6, -8, -10, -12]


func run() -> void:
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
