extends RisoProp
## A watcher's shot: a pink shard, or a rebounding pellet of sun.


## The Bullet it dresses.
var shot: Bullet:
	get:
		return host as Bullet


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
	ink.ink(RisoPrint.PINK, 0.5, [xf * RisoShapes.rrect(-34, -3, 30, 6, 3)])
	ink.ink(RisoPrint.PINK, 1.0, [xf * RisoShapes.sparkle(Vector2.ZERO, 10.0, 1.7)])
	ink.ink(RisoPrint.ACCENT, 1.0, [xf * RisoShapes.circle(Vector2(2, 0), 4.0, 10)])
