extends TestKit
## Climbing levels (docs/REGIONS_PLAN.md, phase 2): above the start the way on lies above the way
## back, in the top band of the level, and below the start the way round; the climb helper (Climb)
## lays a few ledges in up levels only, never in a chasm's or gap's kept air or a door's corridor,
## the same on every build; and they help (more ways on are reached with them than without), though
## nothing is promised.
## godot --headless --path . --script res://tests/climb_test.gd

const WORLDS: Array[int] = [1, 7, 28, 99, 123]


func run() -> void:
	MapInfo.debug = false
	var rows: Array[int] = [-1, -3, NextWorldDef.band_row(&"crags", 1), NextWorldDef.band_row(&"sky", 0), 2, NextWorldDef.band_row(&"cemetery", 1)]
	var placed_ok: bool = true
	var bands_ok: bool = true
	var ledges_ok: bool = true
	var down_bare: bool = true
	var same: bool = true
	var helped: int = 0
	var reached_with: int = 0
	var reached_without: int = 0
	var levels_up: int = 0
	for x: int in WORLDS:
		for row: int in rows:
			var at: Vector2i = Vector2i(x, row)
			var def: NextWorldDef = Rules.def_for(at)
			var cells: Array = collapse(at)
			var w: LevelGen = LevelGen.new(cells, def)
			var back: Vector2i = w.exits[MapInfo.Exit.BACK]
			var on: Vector2i = w.exits[MapInfo.Exit.DEEPER]
			placed_ok = placed_ok and ((on.y < back.y) if row < 0 else (on.y > back.y))
			var top: int = 1 << 30
			for v: Vector2i in w.empties_where(w.ground_below):
				top = mini(top, v.y)
			@warning_ignore("integer_division")
			var band: int = maxi(2, w.size.y / 4)
			if row < 0:
				bands_ok = bands_ok and on.y <= top + band
			if row >= 0:
				down_bare = down_bare and w.climb_ledges.is_empty()
				continue
			levels_up += 1
			ledges_ok = ledges_ok and w.climb_ledges.size() <= Climb.MAX_LEDGES
			for q: Vector2i in w.climb_ledges:
				ledges_ok = ledges_ok and w.get_cell(q).type == LevelGen.Type.PLATFORM and not Chasms.near(w, q) and not w.keep_clear.has(q)
			var again: LevelGen = LevelGen.new(cells, def)
			same = same and again.climb_ledges == w.climb_ledges and again.objects == w.objects
			# Reached with the ledges, and without them (their footholds taken away again).
			var up: int = Climb.hop_up(def)
			var nodes: Dictionary = Climb.footholds(w)
			var with: Dictionary = {back: true}
			Reach.grow(w, nodes, with, [back], {}, {}, Reach.ACROSS, up)
			# Every ledge's foothold was new (Climb lays one only where nothing stood before).
			var bare: Dictionary = nodes.duplicate()
			for q: Vector2i in w.climb_ledges:
				bare.erase(q + Vector2i.UP)
			var without: Dictionary = {back: true}
			for q: Vector2i in w.climb_ledges:
				w.set_kind(q, LevelGen.Type.EMPTY)
			Reach.grow(w, bare, without, [back], {}, {}, Reach.ACROSS, up)
			if with.has(on):
				reached_with += 1
			if without.has(on):
				reached_without += 1
			if with.has(on) and not without.has(on):
				helped += 1
	check(placed_ok, "above the start the way on lies above the way back, below it the way round")
	check(bands_ok, "an up level's way on is in its top part")
	check(down_bare, "levels below the start get no climbing ledges")
	check(ledges_ok, "an up level's climbing ledges are at most %d, ledges, and clear of chasms, gaps and corridors" % Climb.MAX_LEDGES)
	check(same, "they are laid the same on every build")
	check(helped > 0 and reached_with > reached_without, "they help: the way on reached in %d of %d up levels with them, %d without" % [reached_with, levels_up, reached_without])
	finish()

