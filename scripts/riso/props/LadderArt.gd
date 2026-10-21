extends RisoProp
class_name LadderArt
## A library's rolling ladder, its step and its rail.


## Where rung `k` of `ladder` is (world y, its top), counting down from the one under its step: the
## wizard's hands take hold of them as they climb (RisoWizard.climb_limbs).
static func rung_y(ladder: RollingLadder, k: int) -> float:
	return ladder.top_y() + STEP + RUNG_GAP * 0.6 + float(k) * RUNG_GAP


## The RollingLadder it dresses.
var ladder: RollingLadder:
	get:
		return host as RollingLadder

## The ladder's half width at its top and at its foot (px: it splays), a stile's width, the room
## between rungs and a rung's depth (px), and a wheel's radius.
const TOP_HALF: float = 17.0
const FOOT_HALF: float = 25.0
const STILE: float = 7.0
const RUNG_GAP: float = 30.0
const RUNG: float = 6.0
const WHEEL: float = 8.0
## The step's depth (px), and the rail's (px, its top level with the step's).
const STEP: float = 20.0
const RAIL: float = 6.0
## How much wood ink the ladder and step print on their paper (pale, as the ledges are), and the rail.
const WOOD: float = 0.5
const RAIL_WOOD: float = 0.7


## A rolling ladder (RollingLadder): a wooden rail along its whole track that stays put, with a
## dark bracket every cell; on it the step, a wooden board hooked over the rail at each end; and
## under the step's middle the ladder, splaying a little to its foot, its rungs a shade lighter on
## top, with a wheel either side at its foot where it meets the floor. They print in pale wood on
## paper (WOOD), as the ledges do, so they stand out from the dark rooms and bookcases behind.
func _draw_art() -> void:
	var n: int = ladder.length
	var cell: float = half * 2.0
	var x1: float = -half + float(n) * cell
	var top: float = -half
	# The rail, from where the step's left end starts its track to where its right end finishes.
	var holder: Node2D = host.get_parent() as Node2D
	var a: Vector2 = to_local(holder.to_global(ladder.start) if holder != null else ladder.start)
	var rail_a: float = a.x - half
	var rail_b: float = a.x + x1 + ladder.travel
	var rod: PackedVector2Array = RisoShapes.rrect(rail_a, top - RAIL * 0.5, rail_b - rail_a, RAIL, RAIL * 0.5)
	ink.knock(RisoPrint.ALL_PLATES, [rod])
	ink.ink(RisoPrint.BLUE, RAIL_WOOD, [rod])
	var brackets: Array[PackedVector2Array] = []
	var k: int = 0
	while rail_a + float(k) * cell <= rail_b + 1.0:
		var bx: float = rail_a + float(k) * cell
		brackets.append(RisoShapes.rrect(bx - 3.0, top - 16.0, 6.0, 14.0, 2.0))
		k += 1
	ink.ink(RisoPrint.NIGHT, 0.9, brackets)
	# The ladder under the step's middle.
	var mid: float = float(n - 1) * half
	var foot: float = top + float(ladder.rungs) * cell
	var wood: Array[PackedVector2Array] = []
	var lights: Array[PackedVector2Array] = []
	if ladder.rungs > 0:
		for side: float in [-1.0, 1.0]:
			var t0: Vector2 = Vector2(mid + side * TOP_HALF, top + STEP - 2.0)
			var t1: Vector2 = Vector2(mid + side * FOOT_HALF, foot - WHEEL)
			wood.append_array(RisoDecor.strip(PackedVector2Array([t0, t1]), STILE * 0.5, STILE * 0.5))
		var y: float = top + STEP + RUNG_GAP * 0.6
		# (Where rung_y puts them.)
		while y < foot - WHEEL - RUNG:
			var u: float = (y - top) / maxf(1.0, foot - top)
			var w: float = lerpf(TOP_HALF, FOOT_HALF, u)
			wood.append(RisoShapes.rrect(mid - w, y, w * 2.0, RUNG, 2.0))
			lights.append(RisoShapes.rrect(mid - w + 2.0, y, w * 2.0 - 4.0, 2.0, 1.0))
			y += RUNG_GAP
	# The step, hooked over the rail at each end.
	var board: PackedVector2Array = RisoShapes.rrect(-half + 2.0, top, x1 + half - 4.0, STEP, 5.0)
	wood.append(board)
	var hooks: Array[PackedVector2Array] = []
	for hx: float in [-half + 12.0, x1 - 18.0]:
		hooks.append(RisoShapes.rrect(hx, top - RAIL - 4.0, 6.0, RAIL + 10.0, 3.0))
	ink.knock(RisoPrint.ALL_PLATES, wood)
	ink.ink(RisoPrint.BLUE, WOOD, wood)
	ink.ink(RisoPrint.NIGHT, 0.35, [RisoShapes.rrect(-half + 2.0, top + STEP - 6.0, x1 + half - 4.0, 6.0, 3.0)], false)
	ink.lift_ink([RisoPrint.BLUE], 0.6, lights)
	ink.lift_ink([RisoPrint.BLUE], 0.6, [RisoShapes.rrect(-half + 6.0, top + 2.0, x1 + half - 12.0, 3.0, 1.5)])
	ink.ink(RisoPrint.NIGHT, 1.0, hooks)
	# Its wheels, where its foot meets the floor.
	if ladder.rungs > 0 and ladder.rungs < RollingLadder.LADDER_MOST:
		var wheels: Array[PackedVector2Array] = []
		var hubs: Array[PackedVector2Array] = []
		for side: float in [-1.0, 1.0]:
			var c: Vector2 = Vector2(mid + side * FOOT_HALF, foot - WHEEL)
			wheels.append(RisoShapes.circle(c, WHEEL, 14))
			hubs.append(RisoShapes.circle(c, 2.5, 8))
		ink.ink(RisoPrint.NIGHT, 0.95, wheels)
		ink.knock(RisoPrint.ALL_PLATES, hubs)


func view_rect() -> Rect2:
	var cell: float = half * 2.0
	var r: Rect2 = Rect2(-half - ladder.travel - 8.0, -half - 24.0, float(ladder.length) * cell + ladder.travel * 2.0 + 16.0, float(ladder.rungs) * cell + 32.0)
	return Rect2(host.global_position + r.position, r.size)
