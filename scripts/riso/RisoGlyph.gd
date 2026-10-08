class_name RisoGlyph
extends RefCounted
## The mark of each ability (Abilities): printed in a shrine's niche, on a relic, in the HUD's
## spell slot and on the map. A new ability gets its mark here (anything else shows a spark).


## An ability's mark, centred on `c`: what a shrine teaches.
static func of(a: StringName, c: Vector2, t: float) -> Array[PackedVector2Array]:
	match a:
		&"dash":
			return [RisoMarks.chevron(c + Vector2(-8, 0), Vector2.RIGHT, 0.8), RisoMarks.chevron(c + Vector2(12, 0), Vector2.RIGHT, 0.8)]
		&"double_jump":
			return [RisoMarks.chevron(c + Vector2(0, -10), Vector2.UP, 0.8), RisoMarks.chevron(c + Vector2(0, 12), Vector2.UP, 0.8)]
		&"wall_climb":
			return [RisoShapes.rrect(c.x - 22, c.y - 26, 9, 52, 4), RisoShapes.crescent(c + Vector2(6, -4), 14.0, Vector2(-6, 0)), RisoShapes.circle(c + Vector2(4, 18), 5.0, 12)]
		&"blink":
			return [RisoShapes.circle(c + Vector2(-18, 0), 7.0, 14), RisoShapes.circle(c + Vector2(-4, 0), 2.5, 8), RisoShapes.circle(c + Vector2(5, 0), 2.5, 8), RisoShapes.circle(c + Vector2(18, 0), 10.0, 18)]
		&"parry":
			return [RisoShapes.crescent(c, 22.0, Vector2(9, 0))]
		&"astral":
			return RisoMarks.ghost_shape(Transform2D(0.0, Vector2(1.5, 1.5), 0.0, c + Vector2(0, 28)))
		&"vigor":
			var bead: PackedVector2Array = RisoShapes.circle(c, 14.0, 24)
			return [bead]
		&"levitate":
			# A feather of three rising arcs over a ring.
			return [RisoShapes.ellipse(c + Vector2(0, 14), 18.0, 5.0, 18), RisoShapes.almond(c + Vector2(0, -6), 7.0, 18.0, 12),
				RisoShapes.rrect(c.x - 1.6, c.y - 4, 3.2, 16, 1.6)]
		&"rift":
			# Two linked rings.
			return [RisoShapes.circle(c + Vector2(-11, 0), 9.0, 18), RisoShapes.circle(c + Vector2(11, 0), 9.0, 18), RisoShapes.rrect(c.x - 6, c.y - 1.6, 12, 3.2, 1.6)]
		&"awareness":
			# An open eye with a lit pupil.
			return [RisoShapes.almond(c, 22.0, 11.0, 14), RisoShapes.circle(c, 5.0, 12)]
		&"speed":
			# Three staggered speed lines streaming back from a running bead.
			return [RisoShapes.circle(c + Vector2(14, 0), 7.0, 14), RisoShapes.rrect(c.x - 20, c.y - 12, 26, 5, 2.5),
				RisoShapes.rrect(c.x - 26, c.y - 2.5, 32, 5, 2.5), RisoShapes.rrect(c.x - 16, c.y + 7, 22, 5, 2.5)]
		&"warp":
			# A ring it leaves by, a dotted way across, and the ring it comes out of.
			return [RisoShapes.circle(c + Vector2(-17, 8), 8.0, 16), RisoShapes.circle(c + Vector2(-5, -1), 2.6, 8), RisoShapes.circle(c + Vector2(4, -6), 2.6, 8),
				RisoShapes.circle(c + Vector2(16, -6), 11.0, 20)]
		&"strike":
			# The dash's chevron driving into a burst.
			return [RisoMarks.chevron(c + Vector2(-10, 0), Vector2.RIGHT, 0.8), RisoShapes.sparkle(c + Vector2(14, 0), 15.0)]
		&"hex":
			# A comet: a bold spark with a tapering tail behind it.
			return [RisoShapes.sparkle(c + Vector2(7, -5), 17.0), PackedVector2Array([c + Vector2(4, -12), c + Vector2(-22, 14), c + Vector2(-2, 0)])]
		&"mend":
			# A drop of light over a bead: a draught that heals.
			return [RisoShapes.circle(c + Vector2(0, 9), 12.0, 22), RisoShapes.almond(c + Vector2(0, -14), 6.0, 11.0, 12),
				RisoShapes.rrect(c.x - 1.8, c.y - 26, 3.6, 8, 1.8)]
		&"ferry":
			# A raft on two ripples, a chevron over it the way it glides.
			return [RisoShapes.rrect(c.x - 20, c.y - 4, 40, 9, 4.5), RisoShapes.ellipse(c + Vector2(-8, 13), 10.0, 2.6, 12),
				RisoShapes.ellipse(c + Vector2(10, 17), 8.0, 2.2, 12), RisoMarks.chevron(c + Vector2(0, -16), Vector2.RIGHT, 0.6)]
		&"ward":
			# Three curved plates in a ring round a bead.
			var guard: Array[PackedVector2Array] = [RisoShapes.circle(c, 6.0, 14)]
			for i: int in range(3):
				var mid: float = -PI * 0.5 + TAU * (float(i) + 0.5) / 3.0
				guard.append(RisoWard.arc(14.0, 22.0, mid - 0.8, mid + 0.8, c))
			return guard
		&"keyring":
			# A ring with two keys hanging from it.
			var ring: Array[PackedVector2Array] = [RisoShapes.crescent(c + Vector2(0, -12), 11.0, Vector2(0, 4))]
			for side: float in [-1.0, 1.0]:
				var xf: Transform2D = Transform2D(PI * 0.5 + side * 0.35, c + Vector2(side * 9.0, 2.0))
				for poly: PackedVector2Array in RisoMarks.key_shape(Vector2.ZERO, 0.55, 0 if side < 0 else 1):
					ring.append(xf * poly)
			return ring
	return [RisoShapes.sparkle(c, 18.0)]
