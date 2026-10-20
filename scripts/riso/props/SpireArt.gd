extends RisoProp
## A watchtower's iron spire (Spire): a tapering rod a little taller than a cell standing on the roof,
## in blue (pale iron against the night) with a night shade down one side and a paper glint down the
## other, two cross-arms and a ball at its head. A warm tower's ball is knocked to paper with an accent
## spark in it (it answers a strike); a cold tower's (MapInfo.tower_cold) is screened in night, its
## ball dull blue, with flecks of paper frost down the rod. Struck empowered, accent forks crackle
## down it for a moment; a plain hit only shivers it.

## The rod: how tall (px over the roof), how wide at its foot and head, the arms (how high, how
## wide), the ball (radius) and the spark in it.
const TALL: float = 150.0
const FOOT: float = 18.0
const HEAD: float = 6.0
const ARMS_UP: Vector2 = Vector2(62.0, 100.0)
const ARMS_WIDE: float = 40.0
const BALL: float = 12.0
const SPARK: float = 6.0
## How long a strike's crackle lasts, and a plain hit's shiver (seconds).
const CRACKLE: float = 0.6
const SHIVER: float = 0.3
## How much night screens a cold spire.
const COLD_SCREEN: float = 0.4


## The Spire it dresses.
var spire: Spire:
	get:
		return host as Spire


func shines() -> bool:
	return true


## Its spark glints while the tower is warm.
func light() -> Array:
	if spire == null or spire.cold():
		return []
	return _light(Vector2(0, _ground() - TALL), RisoLight.SPARK, RisoPrint.ACCENT)


func _draw_art() -> void:
	var s: Spire = spire
	if s == null:
		return
	var g: float = _ground()
	var cold: bool = s.cold()
	var shiver: float = sin((s.t - s.rung_at) * 70.0) * 3.0 * clampf(1.0 - (s.t - s.rung_at) / SHIVER, 0.0, 1.0)
	var top: Vector2 = Vector2(shiver, g - TALL)
	var rod: PackedVector2Array = PackedVector2Array([Vector2(-FOOT * 0.5, g), Vector2(FOOT * 0.5, g), top + Vector2(HEAD * 0.5, 0), top - Vector2(HEAD * 0.5, 0)])
	var body: Array[PackedVector2Array] = [rod, RisoShapes.rrect(-FOOT * 1.2, g - 12.0, FOOT * 2.4, 12.0, 4.0)]
	for k: int in range(2):
		var y: float = g - (ARMS_UP.x if k == 0 else ARMS_UP.y)
		var w: float = ARMS_WIDE * (1.0 if k == 0 else 0.65)
		var x: float = shiver * (g - y) / TALL
		body.append(RisoShapes.rrect(x - w * 0.5, y - 3.5, w, 7.0, 3.5))
		body.append(RisoShapes.circle(Vector2(x - w * 0.5, y), 5.0, 10))
		body.append(RisoShapes.circle(Vector2(x + w * 0.5, y), 5.0, 10))
	var ball: PackedVector2Array = RisoShapes.circle(top, BALL, 18)
	body.append(ball)
	ink.ink(RisoPrint.BLUE, 1.0, body)
	# A night shade down its right side; a paper glint down its left.
	ink.ink(RisoPrint.NIGHT, 0.5, [PackedVector2Array([Vector2(1.0, g), Vector2(FOOT * 0.5, g), top + Vector2(HEAD * 0.5, 0), top + Vector2(0.5, 0)])], false)
	ink.knock([RisoPrint.BLUE], [PackedVector2Array([Vector2(-FOOT * 0.32, g - 14.0), Vector2(-FOOT * 0.12, g - 14.0), top + Vector2(-0.6, BALL + 4.0), top + Vector2(-1.6, BALL + 4.0)])])
	if cold:
		ink.ink(RisoPrint.NIGHT, COLD_SCREEN, body, false)
		var frost: Array[PackedVector2Array] = []
		for k: int in range(5):
			frost.append(RisoShapes.sparkle(Vector2(shiver * 0.5 + (RisoShapes.hash1(phase + float(k)) - 0.5) * 10.0, g - 22.0 - float(k) * 26.0), 4.0, 1.0))
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], frost)
	else:
		var spark: PackedVector2Array = RisoShapes.sparkle(top, SPARK * (1.0 + 0.2 * sin(t * 3.0 + phase)), 1.0)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [RisoShapes.circle(top, BALL - 3.0, 16)])
		ink.ink(RisoPrint.ACCENT, 1.0, [spark], false)
	# Struck empowered: forks of spell light crackle down the rod.
	var crackle: float = clampf(1.0 - (s.t - s.struck_at) / CRACKLE, 0.0, 1.0)
	if crackle > 0.0:
		var forks: Array[PackedVector2Array] = []
		var p: Vector2 = top
		for k: int in range(6):
			var q: Vector2 = Vector2((RisoShapes.hash1(s.t * 30.0 + float(k)) - 0.5) * 34.0, top.y + TALL * float(k + 1) / 6.0)
			var n: Vector2 = (q - p).normalized().orthogonal() * 3.5
			forks.append(PackedVector2Array([p - n, q - n, q + n, p + n]))
			p = q
		forks.append(RisoShapes.circle(top, BALL + 14.0 * crackle, 20))
		ink.ink(RisoPrint.ACCENT, crackle, forks, false)
