class_name BrambleHeart
extends BrambleBulb
## The bramble's heart (Bramble): bared in the knot when its last bulb bursts, the knot splitting
## open round it (Bramble.split), hanging from the knot's underside over the head of the shaft. It
## is the bramble's last weak point: always open, wounded as a bulb in bloom is (BrambleWound), by
## any bolt, dash or slash from below, and by a barb parried back into it. While the wizard is in
## the shaft the knot drops a barb down it every BARB_EVERY seconds, at the wizard's column (held to
## the knot's span), its tip poking out of the knot pink for BARB_WARN seconds before it falls: a
## shot (Bullet, its `barb` look) that bursts on the first rock it meets. Burst, the knot tears
## open and the bramble dies (Bramble.burst).

## How often a barb drops (seconds), how long its tip warns first, how fast it falls (px/s), how far
## in from the knot's ends it may drop (px), and how far under the knot's underside it starts.
const BARB_EVERY: float = 1.3
const BARB_WARN: float = 0.6
const BARB_SPEED: float = 430.0
const BARB_EDGE: float = 22.0
const BARB_FROM: float = 14.0

## Seconds into the current barb's round, and the x it will drop at (NAN until its warning).
var barb_t: float = 0.0
var barb_x: float = NAN
## How many barbs it has dropped (for the tests).
var dropped: int = 0


## It is always open, while it lives.
func open() -> bool:
	return alive


func _physics_process(delta: float) -> void:
	if bramble == null:
		return
	opened = bramble.split
	if not alive or bramble.opening or bramble.map_info == null or bramble.split < 1.0:
		return
	var player: Player = bramble.map_info.player
	if player == null or not is_instance_valid(player) or not bramble.in_shaft(player.global_position):
		barb_t = 0.0
		barb_x = NAN
		return
	# A harder preset drops them sooner (Difficulty.haste).
	barb_t += delta * Difficulty.haste()
	if is_nan(barb_x) and barb_t >= BARB_EVERY - BARB_WARN:
		barb_x = clampf(player.global_position.x, bramble.knot_rect.position.x + BARB_EDGE, bramble.knot_rect.end.x - BARB_EDGE)
	if barb_t >= BARB_EVERY:
		drop(barb_x)
		barb_t = 0.0
		barb_x = NAN


## How far through the next barb's warning (0 to 1), or -1 while none is coming.
func warning() -> float:
	if is_nan(barb_x):
		return -1.0
	return clampf((barb_t - (BARB_EVERY - BARB_WARN)) / BARB_WARN, 0.0, 1.0)


## Drop a barb from the knot's underside at `x`.
func drop(x: float) -> void:
	var shot: Bullet = SEED.instantiate() as Bullet
	shot.barb = true
	bramble.map_info.map_elements.add_child(shot)
	shot.global_position = Vector2(x, bramble.knot_rect.end.y + BARB_FROM)
	shot.setup(Vector2.DOWN * BARB_SPEED, [bramble.knot], self)
	dropped += 1
	RisoFx.burst(&"impact", shot.global_position, Vector2.DOWN, [RisoPrint.PINK, RisoPrint.BLUE])
