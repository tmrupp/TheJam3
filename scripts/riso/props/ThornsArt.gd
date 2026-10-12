extends RisoProp
## Thorns (Spikes). Always out, they are still: printed once. Thorns that come and go slide out and
## in with them: out, pink (danger); down, low blue stubs on the rock's lip (safe); a timed run's tips
## peek and flicker pink before it rises; the first thorn of a switched run bears the sigil its
## switch shares.

## The thorns' height out (px), and the stubs' left down.
const TALL: float = 40.0
const STUB: float = 9.0


## The Spikes it dresses.
var thorns: Spikes:
	get:
		return host as Spikes


func still() -> bool:
	return thorns == null or thorns.mode == Spikes.Mode.ALWAYS


func _draw_art() -> void:
	var rise: float = thorns.rise if thorns != null else 1.0
	var warn: float = thorns.warning() if thorns != null else 0.0
	var tall: float = lerpf(STUB, TALL, rise)
	if warn > 0.0:
		tall = maxf(tall, STUB + 8.0 * warn)
	var spikes: Array[PackedVector2Array] = []
	for i: int in range(4):
		var x: float = -47.25 + float(i) * 31.5
		spikes.append(RisoShapes.tri(Vector2(x - 13, half + 2.0), Vector2(x, half - tall), Vector2(x + 13, half + 2.0)))
	if rise > 0.5:
		ink.ink(RisoPrint.PINK, 1.0, spikes)
	else:
		ink.ink(RisoPrint.BLUE, 0.85, spikes)
		if warn > 0.0 and fmod(t * 10.0, 1.0) < 0.6:
			ink.ink(RisoPrint.PINK, 0.4 + 0.6 * warn, spikes, false)
	if thorns != null and thorns.mode == Spikes.Mode.SWITCHED:
		var sigil: int = Sigils.of(host)
		if sigil >= 0:
			RisoMarks.sigil_plate(ink, Vector2(0, half - 4.0), 1.0, 1.0, sigil, false)
