class_name CellSums
extends RefCounted
## Running sums (a summed-area table) over a level's cells of one kind: how many such cells lie in
## any box, answered at once from four of them (count) rather than by visiting the box. Made once
## for a search over many boxes (a crypt's or hall's site, a temple's), from a mask of the level's
## cells, and made again after the cells change.

## The level's size, and the sums: (size.x + 1) by (size.y + 1), the count of the cells in
## [0, x) by [0, y) at x * (size.y + 1) + y.
var size: Vector2i
var _sums: PackedInt32Array = PackedInt32Array()


## Sums over a mask of `level_size`, 1 for each cell counted (cell (x, y) at x * size.y + y, as
## LevelGen.types).
func _init(level_size: Vector2i, mask: PackedByteArray) -> void:
	size = level_size
	var h: int = size.y + 1
	_sums.resize((size.x + 1) * h)
	_sums.fill(0)
	for x: int in range(size.x):
		var col: int = x * size.y
		var run: int = 0
		for y: int in range(size.y):
			run += mask[col + y]
			_sums[(x + 1) * h + y + 1] = _sums[x * h + y + 1] + run


## The cells of `w` passing `test` (a Callable taking the cell), counted.
static func where(w: LevelGen, test: Callable) -> CellSums:
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(w.size.x * w.size.y)
	mask.fill(0)
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			if test.call(Vector2i(x, y)):
				mask[x * w.size.y + y] = 1
	return CellSums.new(w.size, mask)


## The open cells of `w` (any but rock), counted.
static func open(w: LevelGen) -> CellSums:
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(w.types.size())
	mask.fill(0)
	for i: int in range(w.types.size()):
		if w.types[i] != LevelGen.Type.GROUND:
			mask[i] = 1
	return CellSums.new(w.size, mask)


## The cells of `w` in the set `cells` (cell -> anything), counted; those outside the level left out.
static func of_set(w: LevelGen, cells: Dictionary) -> CellSums:
	return CellSums.new(w.size, mask_of(w, cells))


## A mask over `w` (as _init takes) of the cells in the set `cells` that lie in the level.
static func mask_of(w: LevelGen, cells: Dictionary) -> PackedByteArray:
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(w.size.x * w.size.y)
	mask.fill(0)
	for v: Vector2i in cells:
		if w.is_valid(v):
			mask[v.x * w.size.y + v.y] = 1
	return mask


## How many of the counted cells lie in `box` (clipped to the level).
func count(box: Rect2i) -> int:
	var r: Rect2i = box.intersection(Rect2i(Vector2i.ZERO, size))
	if not r.has_area():
		return 0
	var h: int = size.y + 1
	return _sums[r.end.x * h + r.end.y] - _sums[r.position.x * h + r.end.y] - _sums[r.end.x * h + r.position.y] + _sums[r.position.x * h + r.position.y]
