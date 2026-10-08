class_name RisoWard
extends RefCounted
## The look shared by an enemy's shield (Shield) and the wizard's ward (Ward): a ring of curved
## plates round what it guards, one for each hit it can still take, turning slowly. Each plate is a
## solid band of ink with a bare-paper glint along it, so a guarded thing reads at a glance and how
## many hits are left can be counted. Struck, it flashes; a plate that breaks flies apart in shards.

## How thick a plate is, unless told otherwise.
const THICK: float = 9.0
## How much of its share of the ring a plate covers: the rest is gap, wide enough that the plates
## left can be counted at a glance.
const PLATE_SHARE: float = 0.55
## How long a broken plate's shards fly, in seconds.
const SHARD_TIME: float = 0.45


## The plates, round `at`: `segments` round the ring at radius `r`, turned by `spin`; the first
## `intact` are whole, the rest gone. `regrow` (0 to 1) prints the next `regrowing` missing ones
## faintly as they come back (the ward recharging). `flash` (0 to 1) brightens the ring just after a
## hit. In ink `plate`, `thick` thick; `cover` (0 to 1) scales the whole print, so a guard can sit
## quietly round the wizard yet print solid round an enemy.
static func plates(ink: InkCanvas, at: Vector2, r: float, segments: int, intact: int, spin: float, flash: float, plate: int,
		regrow: float = 0.0, regrowing: int = 0, cover: float = 1.0, thick: float = THICK) -> void:
	if segments <= 0:
		return
	var whole: Array[PackedVector2Array] = []
	var growing: Array[PackedVector2Array] = []
	var glints: Array[PackedVector2Array] = []
	var half: float = TAU / float(segments) * PLATE_SHARE * 0.5
	for i: int in range(segments):
		var mid: float = plate_angle(i, segments, spin)
		if i < intact:
			whole.append(arc(r - thick, r, mid - half, mid + half, at))
			glints.append(arc(r - thick * 0.62, r - thick * 0.38, mid - half * 0.55, mid + half * 0.2, at))
		elif regrow > 0.0 and i < intact + regrowing:
			growing.append(arc(r - thick, r, mid - half * regrow, mid + half * regrow, at))
	var shown: float = minf(1.0, cover + (1.0 - cover) * flash)
	if not whole.is_empty():
		# A faint veil inside, so the ring reads as one bubble.
		ink.ink(plate, (0.07 + 0.25 * flash) * shown, [RisoShapes.circle(at, r - thick, 40)], false)
		# The night and rock lifted under them first, so the plates print bright over both.
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], shown, whole)
		ink.ink(plate, minf(1.0, 0.85 + 0.15 * flash) * shown, whole, false)
		ink.lift_ink(RisoPrint.ALL_PLATES, shown, glints)
	if not growing.is_empty():
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.5 * shown, growing)
		ink.ink(plate, 0.5 * shown, growing, false)


## Where plate `i` of `segments` sits round the ring, turned by `spin` (radians).
static func plate_angle(i: int, segments: int, spin: float) -> float:
	return spin - PI * 0.5 + TAU * (float(i) + 0.5) / float(segments)


## The shards of a plate round `at` that broke at `angle`, `u` (0 to 1) of the way through their flight:
## thrown outward and falling, shrinking as they go.
static func shards(ink: InkCanvas, at: Vector2, r: float, angle: float, u: float, plate: int) -> void:
	if u >= 1.0:
		return
	var pieces: Array[PackedVector2Array] = []
	for k: int in range(4):
		var a: float = angle + (float(k) - 1.5) * 0.28
		var d: Vector2 = Vector2.from_angle(a)
		var p: Vector2 = at + d * (r - THICK * 0.5 + (40.0 + 14.0 * float(k % 2)) * u) + Vector2(0, 80.0 * u * u)
		var s: float = 7.0 * (1.0 - u)
		pieces.append(PackedVector2Array([p + d * s, p + d.orthogonal() * s * 0.7, p - d * s * 0.6, p - d.orthogonal() * s * 0.5]))
	ink.ink(plate, 0.9 * (1.0 - u), pieces, false)


## A band of a ring round `c` from radius `r0` to `r1`, between angles `a0` and `a1`.
static func arc(r0: float, r1: float, a0: float, a1: float, c: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = maxi(3, int(absf(a1 - a0) / 0.12))
	for k: int in range(n + 1):
		out.append(c + Vector2.from_angle(lerpf(a0, a1, float(k) / float(n))) * r1)
	for k: int in range(n, -1, -1):
		out.append(c + Vector2.from_angle(lerpf(a0, a1, float(k) / float(n))) * r0)
	return out
