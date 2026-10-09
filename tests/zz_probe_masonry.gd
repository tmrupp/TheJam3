extends TestKit

func run() -> void:
	for k: int in [0, 1, 2, 3, 5]:
		var at: Vector2i = Vector2i(28, NextWorldDef.band_row(&"crags", k))
		var w: LevelGen = build(at)
		var ground: int = 0
		var open: int = 0
		var exposed: int = 0
		for v: Vector2i in w.masonry:
			if w.is_ground(v):
				ground += 1
				for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					if w.is_valid(v + d) and not w.is_ground(v + d):
						exposed += 1
						break
			else:
				open += 1
		print("row %d size %s masonry %d ground %d open %d exposed-to-air %d" % [at.y, w.size, w.masonry.size(), ground, open, exposed])
	finish()
