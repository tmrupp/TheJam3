extends RisoProp
## A ferry raft: a rounded slab of the spell's ink with a paper sheen along its top, a soft wake
## trailing behind it as it glides, and a glow under it; it thins away as it fades.


## The FerryRaft it dresses.
var raft: FerryRaft:
	get:
		return host as FerryRaft


func _draw_art() -> void:
	var w: float = FerryRaft.HALF_WIDTH
	var h: float = FerryRaft.HALF_THICK
	var keep: float = 1.0 - clampf(raft.fade, 0.0, 1.0)
	if keep <= 0.0:
		return
	# The last half second of its life, it flickers to say it will go.
	var flicker: float = 1.0 if raft.left > 0.5 or raft.left <= 0.0 else (0.55 + 0.45 * absf(sin(t * 18.0)))
	var cover: float = keep * flicker
	var bob: float = sin(t * 4.0 + phase) * 2.0
	var slab: PackedVector2Array = RisoShapes.rrect(-w, -h + bob, w * 2.0, h * 2.0, h)
	ink.ink(RisoPrint.ROBE, 0.2 * cover, [RisoShapes.ellipse(Vector2(0, h + 10.0 + bob), w * 0.9, 12.0, 24)])
	if raft.velocity != Vector2.ZERO and not raft.stopped and raft.left > 0.0:
		var back: Vector2 = -raft.velocity.normalized()
		var wake: Array[PackedVector2Array] = []
		for k: int in range(3):
			var at: Vector2 = back * (w * 0.6 + 26.0 * float(k + 1)) + Vector2(0, bob)
			wake.append(RisoShapes.circle(at, 9.0 - 2.5 * float(k), 12))
		ink.ink(RisoPrint.ROBE, 0.35 * cover, wake)
	ink.ink(RisoPrint.ROBE, cover, [slab])
	ink.knock([RisoPrint.ROBE, RisoPrint.NIGHT], [RisoShapes.rrect(-w + 12.0, -h + 3.0 + bob, w * 2.0 - 24.0, 4.0, 2.0)])
