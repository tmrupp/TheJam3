extends CreatureArt
## A rock-bug (RockBug): a domed shell of stone, three pink legs a side and two pink eyes, its back
## turned away from whatever it clings to.

## Its size, in the drawing's units (scaled up by SCALE): the shell's half-width and height, and
## how far its legs reach.
const SCALE: float = 3.4
const SHELL_W: float = 15.0
const SHELL_H: float = 10.0
const LEG: float = 9.0


## A rock-bug: a dome of dark stone (blue under night, its front plate darker than its back, a pale
## gleam on its crown, a few night speckles), under it three pink legs a side scuttling while it
## walks (still when it falls or is stunned), and two pink eyes at its front, all turned so its back
## faces `up`.
func _draw_art() -> void:
	var bug: RockBug = host.get_node_or_null("RockBug") as RockBug
	var up: Vector2 = bug.up if bug != null else Vector2.UP
	var walking: bool = bug != null and bug.walking and not bug.stunned
	var facing: float = float(bug.way) if bug != null else 1.0
	var xf: Transform2D = Transform2D(up.angle() + PI * 0.5, Vector2(facing, 1.0) * SCALE, 0.0, Vector2.ZERO)
	var legs: Array[PackedVector2Array] = []
	for k: int in range(3):
		for side: float in [-1.0, 1.0]:
			var root: Vector2 = Vector2((float(k) - 1.0) * 7.0, 2.0)
			var swing: float = sin(t * 18.0 + float(k) * 2.1 + (0.0 if side > 0.0 else PI)) * 3.0 if walking else 0.0
			var foot: Vector2 = root + Vector2((float(k) - 1.0) * 4.0 + swing, LEG)
			var knee: Vector2 = root.lerp(foot, 0.5) + Vector2(side * 2.5, -2.0)
			legs.append_array(RisoDecor.strip(xf * PackedVector2Array([root, knee, foot]), 2.6, 1.6))
	ink.ink(RisoPrint.PINK, 1.0, legs)
	# The shell: a dome over a flat belly, its front plate a shade darker, a gleam on its crown.
	var dome: PackedVector2Array = PackedVector2Array()
	for n: int in range(13):
		var a: float = PI + PI * float(n) / 12.0
		dome.append(Vector2(cos(a) * SHELL_W, 3.0 + sin(a) * SHELL_H))
	var shell: PackedVector2Array = xf * dome
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], [shell])
	ink.ink(RisoPrint.BLUE, 1.0, [shell])
	ink.ink(RisoPrint.NIGHT, 0.6, [shell], false)
	var front: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in dome:
		if p.x >= 2.0:
			front.append(p)
	front.append(Vector2(2.0, 3.0))
	ink.ink(RisoPrint.NIGHT, 0.3, [xf * front], false)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.55, [xf * RisoShapes.almond(Vector2(-3.0, -SHELL_H + 4.5), 6.0, 1.6, 10)])
	var specks: Array[PackedVector2Array] = []
	for k: int in range(4):
		specks.append(xf * RisoShapes.circle(Vector2(-9.0 + float(k) * 6.0, -2.0 - float(k % 2) * 3.0), 1.4, 8))
	ink.ink(RisoPrint.NIGHT, 0.5, specks, false)
	# Its eyes, at the front, low on the shell.
	var eyes: Array[PackedVector2Array] = []
	for e: Vector2 in [Vector2(SHELL_W - 3.0, 0.0), Vector2(SHELL_W - 7.5, 0.5)]:
		eyes.append(xf * RisoShapes.circle(e, 2.2, 10))
	ink.ink(RisoPrint.PINK, 1.0, eyes)
	if bug != null and bug.stunned:
		_stun_mark(xf * Vector2(0.0, -SHELL_H - 8.0))
