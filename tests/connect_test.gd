extends TestKit
## Every generated level is one connected cave: all its open cells (and so every exit, the shrine,
## the ink well, keys, lanterns and moons) are joined through open space. Gates (doors, cracked
## walls, locked or unpaid exits) and abilities may still be needed; connectivity is not
## reachability. Checked over many worlds and depths.

func run() -> void:
	var checked: int = 0
	for world_seed: int in [1, 7, 28, 99, 512]:
		for depth: int in [0, 2, 5, 8]:
			var w: LevelGen = build(Vector2i(world_seed, depth))
			# Open = anything that is not rock (cracked walls are gates, so they count as open).
			var open: Callable = func(v: Vector2i) -> bool: return w.is_valid(v) and w.get_cell(v).type != LevelGen.Type.GROUND
			var start: Vector2i = w.exits[MapInfo.Exit.BACK]
			var seen: Dictionary = {start: true}
			var stack: Array[Vector2i] = [start]
			while not stack.is_empty():
				var v: Vector2i = stack.pop_back()
				for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					var n: Vector2i = v + d
					if not seen.has(n) and open.call(n):
						seen[n] = true
						stack.append(n)
			var missing: Array = []
			var total: int = 0
			for x: int in range(w.size.x):
				for y: int in range(w.size.y):
					var v: Vector2i = Vector2i(x, y)
					if open.call(v):
						total += 1
						if not seen.has(v):
							missing.append(v)
			var goals_ok: bool = true
			for v: Vector2i in w.objects:
				if w.get_cell(v).type in [LevelGen.Type.EXIT, LevelGen.Type.SHRINE, LevelGen.Type.INKWELL, LevelGen.Type.KEY, LevelGen.Type.CHECKPOINT, LevelGen.Type.MOON] and not seen.has(v):
					goals_ok = false
			checked += 1
			var shrine_ok: bool = w.shrine.x >= 0
			check(missing.is_empty() and goals_ok and shrine_ok, "world %d depth %d (%s): one cave of %d cells (%d cut off), goals joined %s, shrine at %s" % [world_seed, depth, w.size, total, missing.size(), goals_ok, w.shrine])
	print("  %d levels" % checked)
	finish()
