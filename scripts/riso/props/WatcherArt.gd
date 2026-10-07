extends CreatureArt
## A watcher: an eye on a stalk that opens as it charges a shot.


var _last_shot: float = -10.0
## The watcher's lid: eased toward its shooter's charge, so it opens slowly and closes gently.
var watch_open: float = 0.1
var _was_firing: bool = false


func _draw_art() -> void:
	var shooter: Shooter = host.get_node_or_null("Shooter") as Shooter
	var at: Vector2 = Vector2(0, -26.0)
	var charge: float = 0.0
	var recoil: float = 0.0
	var stunned: bool = false
	var fired: bool = false
	if shooter != null:
		var point: Node2D = shooter.get_node_or_null("ShootPoint") as Node2D
		if point != null:
			at = to_local(point.global_position) + Vector2(0, -4)
		var sfx: AudioStreamPlayer = shooter.get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer
		var firing: bool = sfx != null and sfx.playing
		fired = firing and not _was_firing
		if fired:
			_last_shot = t
		_was_firing = firing
		# The eye opens as it charges, which happens only while it can see the wizard; losing
		# sight resets the charge and the lid drifts shut. A ball of ink swells at the muzzle near
		# the end, and it squints on the recoil.
		charge = clampf(shooter.charge, 0.0, 1.0)
		var since: float = t - _last_shot
		recoil = clampf(1.0 - since * 5.0, 0.0, 1.0)
		stunned = shooter.stunned
	var target: float = 0.1 + 0.9 * charge
	watch_open = move_toward(watch_open, target, _dt * (0.9 if target > watch_open else 1.6))
	var open: float = clampf(watch_open - recoil * 0.6, 0.06, 1.0)
	if stunned:
		open = 0.08
		charge = 0.0
	var k: float = 2.8
	var xf: Transform2D = Transform2D(0.0, Vector2(k, k), 0.0, at + Vector2(0, sin(t * 2.0 + phase) * 3.0))
	# A stalk rooted in the floor, swaying under the eye: the watcher grows here.
	var g: float = _ground()
	var eye: Vector2 = xf * Vector2(0, 4)
	if g - eye.y > 12.0:
		var sway: float = sin(t * 1.6 + phase) * 6.0
		var stalk: PackedVector2Array = PackedVector2Array()
		for j: int in range(6):
			var f: float = float(j) / 5.0
			stalk.append(Vector2(sway * sin(f * PI) * 0.8, lerpf(g, eye.y, f)))
		ink.ink(RisoPrint.BLUE, 1.0, RisoDecor.strip(stalk, 9.0, 4.0))
		ink.ink(RisoPrint.NIGHT, 0.3, RisoDecor.strip(stalk, 9.0, 4.0), false)
		ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.ellipse(Vector2(0, g - 2.0), 14.0, 5.0, 14)])
	var drips: Array[PackedVector2Array] = []
	for j: int in range(3):
		var x: float = -4.0 + float(j) * 4.0
		var l: float = 4.0 + sin(t * 2.0 + float(j)) * 1.5
		drips.append(xf * PackedVector2Array([Vector2(x - 1.4, 3), Vector2(x, 6 + l), Vector2(x + 1.4, 3)]))
	var lid: PackedVector2Array = xf * RisoShapes.almond(Vector2.ZERO, 10.0, 5.6, 12)
	# Solid pink over solid blue: the deep purple lid of the prototype.
	ink.ink(RisoPrint.PINK, 1.0, [lid])
	ink.ink(RisoPrint.PINK, 1.0, drips)
	ink.ink(RisoPrint.BLUE, 1.0, [lid])
	var yo: float = lerpf(2.0, 0.0, open)
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], [xf * RisoShapes.almond(Vector2(0, yo), 8.2, maxf(0.3, 4.4 * open), 12)])
	var player: Node2D = Stage.player()
	var look: Vector2 = Vector2.ZERO
	if player != null:
		var d: Vector2 = player.global_position - to_global(at)
		look = Vector2(clampf(d.x / 200.0, -1.0, 1.0) * 2.6, clampf(d.y / 200.0, -1.0, 1.0) * 1.2)
	ink.ink(RisoPrint.PINK, 1.0, [xf * RisoShapes.circle(look + Vector2(0, yo), 3.0 * maxf(0.35, open), 14)])
	ink.ink(RisoPrint.BLUE, 1.0, [xf * RisoShapes.circle(look + Vector2(0, yo), 1.3 * maxf(0.35, open), 10)])
	if fired and player != null:
		var side: float = signf(look.x) if look.x != 0.0 else -1.0
		var from: Vector2 = xf * Vector2(side * 9.6, -0.6)
		RisoFx.burst(&"shot", to_global(from), (player.global_position - to_global(from)).normalized())
	if charge > 0.0:
		# The charge: a solid eye-yellow ball swelling at the corner of the eye nearest the player.
		var aim: float = signf(look.x) if look.x != 0.0 else -1.0
		var ball: float = (0.35 + charge * charge * 2.0) * k
		var corner: Vector2 = xf * Vector2(aim * 9.6, -0.6)
		var core: PackedVector2Array = RisoShapes.circle(corner, ball, 20)
		ink.ink(RisoPrint.EYE, 0.2, [RisoShapes.circle(corner, ball * 1.6, 24)])
		ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT], [core])
		ink.ink(RisoPrint.EYE, 1.0, [core], false)
	if int(host.get_meta(&"bounces", 0)) > 0:
		# Its shots rebound: two pellets of sun circle the eye.
		var pellets: Array[PackedVector2Array] = []
		for j: int in range(2):
			var a: float = t * 2.4 + phase + PI * float(j)
			pellets.append(RisoShapes.circle(xf * Vector2(cos(a) * 15.0, sin(a) * 7.0), 5.0, 12))
		ink.ink(RisoPrint.ACCENT, 1.0, pellets)
	if stunned:
		_stun_mark(xf * Vector2(0, -16))
