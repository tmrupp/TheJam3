extends RisoProp
## A watcher's shot: a pink shard on paper, or a rebounding pellet of sun; or a bramble's seed; or
## a crossbow's arrow.


## A watcher's shard (px): how big its four-pointed spark is, and how long and how wide its trail.
const SHARD_SIZE: float = 13.0
const SHARD_TAIL: float = 40.0
const SHARD_WIDE: float = 3.5

## The Bullet it dresses.
var shot: Bullet:
	get:
		return host as Bullet


func _ready() -> void:
	super()
	# Over the props (doors, z 2), as the wizard's hex bolts are.
	z_index = 3


func _draw_art() -> void:
	var ang: float = shot.velocity.angle()
	var xf: Transform2D = Transform2D(ang, Vector2.ZERO)
	if shot.bounces > 0 or shot.since_bounce < 99.0:
		# A rebounding shot: a round pellet of sun with a pink core and a short tail, flashing
		# as it glances off a wall.
		var flash: float = clampf(1.0 - shot.since_bounce / 0.15, 0.0, 1.0)
		ink.ink(RisoPrint.ACCENT, 0.4, [xf * RisoShapes.almond(Vector2(-16, 0), 16.0, 5.0, 12)])
		ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(Vector2.ZERO, 9.0 + 6.0 * flash, 16)])
		ink.ink(RisoPrint.PINK, 1.0, [RisoShapes.circle(Vector2.ZERO, 4.0, 10)])
		return
	if shot.seed:
		# A bramble's seed: a pink seed spinning as it flies, with a dark eye and a thorny tip.
		var spin: Transform2D = Transform2D(t * 10.0, Vector2.ZERO)
		ink.ink(RisoPrint.PINK, 0.4, [xf * RisoShapes.almond(Vector2(-30, 0), 22.0, 5.0, 10)])
		ink.ink(RisoPrint.PINK, 1.0, [spin * RisoShapes.almond(Vector2.ZERO, 21.0, 12.0, 12)])
		ink.ink(RisoPrint.PINK, 1.0, [spin * RisoShapes.tri(Vector2(17, -6), Vector2(32, 0), Vector2(17, 6))])
		ink.ink(RisoPrint.NIGHT, 0.7, [spin * RisoShapes.ellipse(Vector2(-1, 0), 7.0, 4.0, 10)], false)
		return
	if shot.arrow:
		# A crossbow's arrow: a pink shaft with a faint trail, pink fletching and a pink head.
		ink.ink(RisoPrint.PINK, 0.3, [xf * RisoShapes.rrect(-70, -1.5, 30, 3, 1.5)])
		ink.ink(RisoPrint.PINK, 0.75, [xf * RisoShapes.rrect(-40, -2.5, 44, 5, 2)])
		ink.ink(RisoPrint.PINK, 1.0, [xf * RisoShapes.tri(Vector2(2, -7), Vector2(18, 0), Vector2(2, 7))])
		ink.ink(RisoPrint.PINK, 0.8, [xf * RisoShapes.tri(Vector2(-44, -8), Vector2(-30, -2), Vector2(-40, -2)), xf * RisoShapes.tri(Vector2(-44, 8), Vector2(-30, 2), Vector2(-40, 2))])
		return
	# A watcher's shard, printed on paper (the night and the rock's ink knocked out under it) so its
	# pink stays bright on a dark wall or in the dark, rather than sinking into it.
	var tail: PackedVector2Array = xf * RisoShapes.rrect(-SHARD_TAIL, -SHARD_WIDE, SHARD_TAIL - 4.0, SHARD_WIDE * 2.0, SHARD_WIDE)
	var shard: PackedVector2Array = xf * RisoShapes.sparkle(Vector2.ZERO, SHARD_SIZE, 1.7)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [tail, shard])
	ink.ink(RisoPrint.PINK, 0.55, [tail])
	ink.ink(RisoPrint.PINK, 1.0, [shard])
	ink.ink(RisoPrint.ACCENT, 1.0, [xf * RisoShapes.circle(Vector2(2, 0), 4.5, 10)])
