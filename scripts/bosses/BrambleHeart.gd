class_name BrambleHeart
extends BrambleBulb
## The bramble's heart (Bramble): a bud hidden in its crown, bared when its last bulb bursts, the
## crown's canes drawing back from round it (Bramble.bare) as it drops down out of them over the head
## of the shaft, printed as a big bud wrapped in sepals of bark (Bramble._draw_bud), struck at its
## middle. It is the bramble's last weak point, wounded as a bulb in bloom is (BrambleWound), by any
## bolt, dash or slash from below; but each time it is wounded its sepals close over it for SHUT_TIME
## seconds, and blows glance off them until they part again. While it is bared the bramble makes
## its last stand (Bramble._bare_heart): every burst bulb opens again and spits seeds, and every vine
## lashes again. Burst, the head of the shaft opens and the bramble dies, its vines drying and
## drawing back into the rock (Bramble.burst).

## How long it stays shut after a wound (seconds), and how fast its sepals close over it and part
## again (their full way a second, times).
const SHUT_TIME: float = 1.6
const SHUT_RATE: float = 6.0

## Seconds left before it opens again after a wound (0 while it is open).
var shut_left: float = 0.0
## How far its sepals are closed over it (0 open, 1 shut), as printed.
var closed: float = 0.0


## It is open while it lives, but for a while after each wound.
func open() -> bool:
	return alive and shut_left <= 0.0


## It has been wounded: it flashes, the bramble quivers from it, and it shuts for a while.
func struck() -> void:
	super()
	shut_left = SHUT_TIME


func _physics_process(delta: float) -> void:
	if bramble == null:
		return
	opened = bramble.bare
	shut_left = maxf(0.0, shut_left - delta)
	closed = move_toward(closed, 0.0 if open() or not alive else 1.0, delta * SHUT_RATE)
