extends RisoProp
## A crossbow built into a tower's wall (Crossbow), drawn over the wall's stone: on the inner face, a
## dark niche with the crossbow set in it, its stock jutting into the room, its prod pale bare paper,
## its string winding back as it draws and a pink bolt laid on it (danger), which is all that moves;
## and a dark bore through the stone to the outer face, as an empty arrow slit's. The crossbow is
## drawn SIZE times its plain measures, about the wall's inner face, filling the block.

## How long the crossbow kicks back after loosing, and how far (pixels).
const KICK_TIME: float = 0.2
const KICK: float = 10.0
## How far its string winds back when fully drawn (pixels).
const WIND: float = 26.0
## How deep the niche goes into the wall, and how high it is, and how high the bore through to the
## outer face is (pixels): an arrow slit's, as the decor cuts an empty one (RisoDecor.SLIT_NICHE).
const NICHE_DEEP: float = RisoDecor.SLIT_NICHE.x
const NICHE_HIGH: float = RisoDecor.SLIT_NICHE.y
const BORE: float = RisoDecor.SLIT_BORE
## How big the crossbow and its niche are drawn, against the measures here, so it fills its block.
const SIZE: float = RisoDecor.SLIT_SIZE


## The Crossbow it dresses.
var bow: Crossbow:
	get:
		return host as Crossbow


## Drawn as if it faced right, about where it sits in the wall (Crossbow.DEPTH in from the inner
## face); mirrored for one facing left.
func _draw_art() -> void:
	if bow == null:
		return
	var f: float = float(bow.facing)
	var xf: Transform2D = Transform2D(Vector2(f, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
	var inner: float = -Crossbow.DEPTH
	var outer: float = half * 2.0 - Crossbow.DEPTH
	var kick: float = -KICK * clampf(1.0 - bow.since_shot / KICK_TIME, 0.0, 1.0)
	# Reloading, its string hangs slack with no bolt on it.
	var loaded: bool = bow.since_shot > KICK_TIME and bow.loaded()
	# The crossbow itself, drawn SIZE about the wall's inner face.
	var k: float = SIZE
	var xs: Transform2D = xf * Transform2D(0.0, Vector2(k, k), 0.0, Vector2(inner * (1.0 - k), 0.0))
	# The niche in the wall's inner face, and the bore from it through to the outer face.
	ink.ink(RisoPrint.NIGHT, 0.85, [xs * RisoShapes.rrect(inner, -NICHE_HIGH * 0.5, NICHE_DEEP, NICHE_HIGH, 6.0)], false)
	var bore: Array[PackedVector2Array] = [xf * RisoShapes.rrect(inner + (NICHE_DEEP - 4.0) * k, -BORE * 0.5 * k, outer - inner - (NICHE_DEEP - 4.0) * k, BORE * k, 3.0)]
	ink.ink(RisoPrint.NIGHT, 0.9, bore, false)
	# The stock, jutting out of the niche into the room, in dark wood.
	var stock: Array[PackedVector2Array] = [xs * RisoShapes.rrect(inner - 36.0 + kick, -7.0, 70.0, 14.0, 5.0), xs * RisoShapes.rrect(inner - 32.0 + kick, 3.0, 10.0, 16.0, 3.0)]
	ink.knock([RisoPrint.BLUE], stock)
	ink.ink(RisoPrint.NIGHT, 0.95, stock, false)
	# The prod's two limbs in the niche, bent back toward the room, pale against its dark.
	var prod: float = inner + 30.0 + kick
	var tips: Array[Vector2] = [Vector2(prod - 12.0, -32.0), Vector2(prod - 12.0, 32.0)]
	var limbs: Array[PackedVector2Array] = [xs * _bar(Vector2(prod, -3.0), Vector2(prod - 2.0, -17.0), 8.0), xs * _bar(Vector2(prod - 2.0, -17.0), tips[0], 6.0),
		xs * _bar(Vector2(prod, 3.0), Vector2(prod - 2.0, 17.0), 8.0), xs * _bar(Vector2(prod - 2.0, 17.0), tips[1], 6.0)]
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], limbs)
	ink.ink(RisoPrint.BLUE, 0.35, limbs)
	# The string, wound back to the nut as it draws.
	var nut: Vector2 = Vector2(tips[0].x - WIND * bow.drawn, 0.0) if loaded else Vector2(tips[0].x, 0.0)
	var string: Array[PackedVector2Array] = [xs * _bar(tips[0], nut, 2.5), xs * _bar(tips[1], nut, 2.5)]
	ink.knock([RisoPrint.NIGHT], string)
	# The bolt laid on it, from the nut into the bore.
	if loaded:
		var tail: float = nut.x - 4.0
		var bolt: Array[PackedVector2Array] = [xs * RisoShapes.rrect(tail, -3.0, 50.0, 6.0, 2.0), xs * RisoShapes.tri(Vector2(tail + 46.0, -8.0), Vector2(tail + 62.0, 0.0), Vector2(tail + 46.0, 8.0))]
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], bolt)
		ink.ink(RisoPrint.PINK, 1.0, bolt)


## A bar `w` thick from `a` to `b`.
static func _bar(a: Vector2, b: Vector2, w: float) -> PackedVector2Array:
	var n: Vector2 = (b - a).orthogonal().normalized() * w * 0.5
	return PackedVector2Array([a + n, b + n, b - n, a - n])
