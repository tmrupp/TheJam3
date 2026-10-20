extends RisoProp
## Thorns (Spikes). Always out, they are still: printed once. Thorns that come and go slide out and
## in with them: out, pink (danger); down, low blue stubs on the rock's lip (safe); a timed run's tips
## peek and flicker pink before it rises; the first thorn of a switched run bears the sigil its
## switch shares. They print on top of the decor round them (grass, plants, moss): everything under
## them is knocked to paper first, so their pink stays true rather than darkened where decor crosses.

## The thorns' height out (px), and the stubs' left down.
const TALL: float = 40.0
const STUB: float = 9.0


## The Spikes it dresses.
var thorns: Spikes:
	get:
		return host as Spikes


## The mist in a chasm's pit (Spikes.pit): how high its top bank rises over the thorns (px, just
## under the bridge's deck), how many banks it has, how thick the lowest and the highest are (px),
## how much each lifts the night toward the paper, and the thick haze at the bottom (how high, how
## much).
const MIST_RISE: float = 270.0
const MIST_BANKS: int = 8
const MIST_THICK: Vector2 = Vector2(44.0, 18.0)
const MIST_LIFT: float = 0.14
const MIST_FLOOR: float = 150.0
const MIST_FLOOR_LIFT: float = 0.34


func still() -> bool:
	return thorns == null or (thorns.mode == Spikes.Mode.ALWAYS and thorns.pit < 0)


func view_rect() -> Rect2:
	if thorns == null or thorns.pit < 0:
		return Rect2()
	return Rect2(host.global_position + Vector2(-half, -MIST_RISE - MIST_THICK.x), Vector2(half * 2.0, MIST_RISE + MIST_THICK.x + half))


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
	ink.knock(RisoPrint.ALL_PLATES, spikes)
	if rise > 0.5:
		ink.ink(RisoPrint.PINK, 1.0, spikes)
	else:
		ink.ink(RisoPrint.BLUE, 0.85, spikes)
		if warn > 0.0 and fmod(t * 10.0, 1.0) < 0.6:
			ink.ink(RisoPrint.PINK, 0.4 + 0.6 * warn, spikes, false)
	if thorns != null and thorns.pit >= 0:
		_mist()
	if thorns != null and thorns.mode == Spikes.Mode.SWITCHED:
		var sigil: int = Sigils.of(host)
		if sigil >= 0:
			RisoMarks.sigil_plate(ink, Vector2(0, half - 4.0), 1.0, 1.0, sigil, false)


## The mist filling a chasm's pit over its thorns: a thick haze at the bottom with a rolling top,
## and banks of mist over it up to just under the bridge, thinning as they rise, each swelling and
## rolling at its own pace. Each is a strip across the thorns' cell whose edges follow the level, not
## the cell, so the pit's columns join into one mist. It lifts the night and blue toward the paper
## and leaves the thorns' pink alone, so the danger still shows through.
func _mist() -> void:
	var gx: float = host.global_position.x
	var steps: int = 8
	var floor_top: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps + 1):
		var x: float = -half + half * 2.0 * float(i) / float(steps)
		floor_top.append(Vector2(x, -MIST_FLOOR + 16.0 * sin((gx + x) * 0.019 + t * 0.6) + 8.0 * sin((gx + x) * 0.047 - t * 0.9)))
	floor_top.append(Vector2(half, half))
	floor_top.append(Vector2(-half, half))
	var banks: Array[PackedVector2Array] = []
	for b: int in range(MIST_BANKS):
		var k: float = float(b) / float(MIST_BANKS - 1)
		var cy: float = lerpf(-MIST_FLOOR * 0.7, -MIST_RISE, k)
		var thick: float = lerpf(MIST_THICK.x, MIST_THICK.y, k)
		var top: PackedVector2Array = PackedVector2Array()
		var under: PackedVector2Array = PackedVector2Array()
		for i: int in range(steps + 1):
			var x: float = -half + half * 2.0 * float(i) / float(steps)
			var wx: float = gx + x
			# A swell that rolls along the pit, and the bank's middle rising and falling with it.
			var swell: float = 0.55 + 0.45 * sin(wx * (0.011 + 0.003 * float(b)) + t * (0.35 + 0.08 * float(b)) + float(b) * 2.3)
			var lift: float = 10.0 * sin(wx * 0.017 - t * (0.25 + 0.05 * float(b)) + float(b))
			top.append(Vector2(x, cy + lift - thick * swell))
			under.append(Vector2(x, cy + lift + thick * 0.6 * swell))
		under.reverse()
		top.append_array(under)
		banks.append(top)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], MIST_FLOOR_LIFT, [floor_top])
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], MIST_LIFT, banks)
	@warning_ignore("integer_division")
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], MIST_LIFT, banks.slice(0, MIST_BANKS / 2))
