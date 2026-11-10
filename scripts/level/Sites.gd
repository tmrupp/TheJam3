class_name Sites
extends RefCounted
## Where a walled box of a building goes: the one search shared by the cemetery's crypts (Crypts)
## and the institute's halls (Institute). Made over a level as it stands, with the cells a box
## must keep away from (best may then be asked many times, for boxes of other sizes, while the
## level is unchanged). Every position of the box in the level is tried; one that comes within
## `apart` cells of what it keeps away from is passed over; of the rest, the site walling over the
## least open air and needing the shortest passages out wins, ties dealt by a hash of the level
## seed and the position.

var w: LevelGen
## The cells a box keeps away from (cell -> true).
var blocked: Dictionary
## The open cells (any but rock) and the blocked ones, counted in any box at once.
var _open_sum: CellSums
var _blocked_sum: CellSums


func _init(level: LevelGen, keep_from: Dictionary) -> void:
	w = level
	blocked = keep_from
	_open_sum = CellSums.open(w)
	_blocked_sum = CellSums.of_set(w, blocked)


## The best site for a box `size` big: {"box", "doors"}, or {} if none fits.
## - `doors(box)`: the doorways a box there would have, each [the doorway, the passage's cells,
##   the step out]; a site needs at least `least` (and at least one);
## - each cell of passage costs `passage_cost`; each doorway past `least` counts `worth` off the
##   score (only where `least` is more than one), and `slack` is the most that can be, so a site
##   whose open air alone already loses is passed over without looking for its doors;
## - `test(box)`: whether a box there may stand at all;
## - `salt`: the deal of the ties.
func best(size: Vector2i, apart: int, salt: int, doors: Callable, passage_cost: int,
		least: int = 1, worth: int = 0, slack: int = 0, test: Callable = func(_box: Rect2i) -> bool: return true) -> Dictionary:
	var best_site: Dictionary = {}
	var best_score: int = 1 << 30
	var best_tie: int = 0
	for x: int in range(1, w.size.x - size.x):
		for y: int in range(1, w.size.y - size.y):
			var box: Rect2i = Rect2i(Vector2i(x, y), size)
			if not test.call(box) or _blocked_sum.count(box.grow(apart)) > 0:
				continue
			var score: int = _open_sum.count(box)
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
