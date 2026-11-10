class_name Sites
extends RefCounted
## Where a walled box of a building goes: the one search shared by the cemetery's crypts (Crypts)
## and the institute's halls (Institute). Every position of the box in the level is tried; one that
## comes within `apart` cells of what it must keep away from is passed over; of the rest, the site
## walling over the least open air and needing the shortest passages out wins, ties dealt by a hash
## of the level seed and the position.


## The best site for a box `size` big in `w`: {"box", "doors"}, or {} if none fits.
## - `blocked`: the cells it keeps `apart` cells (or more) away from;
## - `doors(box)`: the doorways a box there would have, each [the doorway, the passage's cells,
##   the step out]; a site needs at least `least` (and at least one);
## - each cell of passage costs `passage_cost`; each doorway past `least` counts `worth` off the
##   score (only where `least` is more than one), and `slack` is the most that can be, so a site
##   whose open air alone already loses is passed over without looking for its doors;
## - `test(box)`: whether a box there may stand at all;
## - `salt`: the deal of the ties.
static func best(w: LevelGen, size: Vector2i, blocked: Dictionary, apart: int, salt: int, doors: Callable, passage_cost: int,
		least: int = 1, worth: int = 0, slack: int = 0, test: Callable = func(_box: Rect2i) -> bool: return true) -> Dictionary:
	var open_sum: CellSums = CellSums.open(w)
	var blocked_sum: CellSums = CellSums.of_set(w, blocked)
	var best_site: Dictionary = {}
	var best_score: int = 1 << 30
	var best_tie: int = 0
	for x: int in range(1, w.size.x - size.x):
		for y: int in range(1, w.size.y - size.y):
			var box: Rect2i = Rect2i(Vector2i(x, y), size)
			if not test.call(box) or blocked_sum.count(box.grow(apart)) > 0:
				continue
			var score: int = open_sum.count(box)
			if score - slack > best_score:
				continue
			var found: Array = doors.call(box)
			if found.size() < maxi(least, 1):
				continue
			if least > 1:
				score -= worth * (found.size() - least)
			for door: Array in found:
				score += (door[1] as Array).size() * passage_cost
			var tie: int = Rules.level_seed(w.seed_for_colors, salt + x * 131 + y)
			if score < best_score or (score == best_score and tie < best_tie):
				best_score = score
				best_tie = tie
				best_site = {"box": box, "doors": found}
	return best_site
