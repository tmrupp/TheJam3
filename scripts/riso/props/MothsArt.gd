extends RisoProp
## A swarm of moths fluttering where the swarm puts them.


## The MothSwarm it dresses.
var swarm: MothSwarm:
	get:
		return host as MothSwarm


## A swarm of moths: each a pair of pale wings beating round a dark body, dusted with accent; they
## flutter where the swarm (MothSwarm) puts them, round a lit lantern's glass when it draws them.
## Scattered they are faint, with a pink point pulsing where they will gather again.
func _draw_art() -> void:
	var spots: Array = swarm.spots
	var moths: Array = swarm.moths
	var wings: Array[PackedVector2Array] = []
	var bodies: Array[PackedVector2Array] = []
	for i: int in range(mini(spots.size(), moths.size())):
		var p: Vector2 = spots[i]
		# Wings beat on a hinge at the body: each turns up and down about its root, never changing shape.
		var flap: float = sin(t * 22.0 + float((moths[i] as Array)[4]) * 3.0) * 0.75
		var heading: float = float((moths[i] as Array)[0]) + PI * 0.5 * signf(float((moths[i] as Array)[2]))
		var turn: Transform2D = Transform2D(sin(heading) * 0.4, p)
		for side: float in [-1.0, 1.0]:
			wings.append(turn * Transform2D(-side * flap, Vector2(side * 1.5, -3.0)) * RisoShapes.ellipse(Vector2(side * 9.0, 0.0), 9.5, 6.0, 12))
		bodies.append(turn * RisoShapes.rrect(-2.2, -6.0, 4.4, 12.0, 2.2))
	# Scattered (MothSwarm.scattered), the moths are faint and a pink point pulses where they will
	# come back together; whole again, they print solid.
	var scattered: float = swarm.scattered
	var apart: float = clampf(scattered / MothSwarm.SCATTER_TIME * 1.6, 0.0, 1.0)
	var cover: float = 1.0 - 0.7 * apart
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.85 * cover, wings)
	ink.ink(RisoPrint.ACCENT, 0.45 * cover, wings, false)
	ink.ink(RisoPrint.NIGHT, cover, bodies, false)
	if scattered > 0.0:
		var pulse: float = 0.5 + 0.5 * sin(t * 7.0)
		ink.ink(RisoPrint.PINK, 1.0, [RisoShapes.circle(Vector2.ZERO, 7.0 + pulse * 2.0, 14)])
		ink.ink(RisoPrint.PINK, 0.4 * (1.0 - pulse), [RisoShapes.circle(Vector2.ZERO, 16.0 + pulse * 20.0, 24)])
