extends PortalArt
## A department's portal (Department), or the way back one opened (WayBack): a round-headed arch of
## pale marble on two columns, standing on a step and hugging its opening, which is a portal's
## (PortalArt's outline) filled as every portal is (the F7 panel's style: TV static by default),
## and on its keystone the department's emblem on a paper disc: a leaf for botany, a skull for necrology, a crystal for geology, a star for
## astronomy (a way back bears the institute's columned front). Standing by it pops up a plaque with
## where it leads, as marks and numbers (RisoMarks.place_marks). It shines a little (RisoLight).

## The arch's half width and height over the floor (px), its columns' width, and the emblem's disc.
## The arch's head sits close round the opening's top, so the whole stands lower than a gate with
## its sigil.
const ARCH_X: float = 56.0
const ARCH_H: float = 160.0
const COLUMN: float = 13.0
const DISC_R: float = 15.0
## The plaque's measures (as a signpost's, SignArt).
const PLACE_R: float = 9.0
const NUMBER_PX: int = 22


func shines() -> bool:
	return true


func light() -> Array:
	return _light(Vector2(0, _ground() - PortalArt.PORTAL_RY - PortalArt.PORTAL_LIFT), RisoLight.GLEAM, RisoPrint.ACCENT)


func _draw_art() -> void:
	var g: float = _ground()
	var center: Vector2 = Vector2(0, g - PortalArt.PORTAL_RY - PortalArt.PORTAL_LIFT)
	# The step, the columns and the arch over them: pale marble (paper, lightly screened).
	var step: PackedVector2Array = RisoShapes.rrect(-ARCH_X - 12.0, g - 9.0, (ARCH_X + 12.0) * 2.0, 10.0, 2.0)
	var stone: Array[PackedVector2Array] = [step]
	for side: float in [-1.0, 1.0]:
		var x: float = side * (ARCH_X - COLUMN * 0.5)
		stone.append(RisoShapes.rrect(x - COLUMN * 0.5, g - ARCH_H + 34.0, COLUMN, ARCH_H - 42.0, 2.0))
		stone.append(RisoShapes.rrect(x - COLUMN * 0.8, g - 16.0, COLUMN * 1.6, 8.0, 1.5))
		stone.append(RisoShapes.rrect(x - COLUMN * 0.8, g - ARCH_H + 30.0, COLUMN * 1.6, 7.0, 1.5))
	stone.append(_arch(Vector2(0, g - ARCH_H + 40.0), Vector2(ARCH_X + 4.0, 44.0), Vector2(ARCH_X - COLUMN, 32.0)))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], stone)
	ink.ink(RisoPrint.BLUE, 0.22, stone, false)
	ink.ink(RisoPrint.NIGHT, 0.12, [RisoShapes.rrect(-ARCH_X - 12.0, g - 4.0, (ARCH_X + 12.0) * 2.0, 5.0, 2.0)], false)
	# The opening, filled as a gate's is (PortalArt): it stirs with the wizard right at it.
	if center != _shape_center:
		_shape_center = center
		_mouth = PortalArt.portal_oval(center, 1.0)
	var near: float = 0.0
	var player: Node2D = Stage.player()
	if player != null:
		var d: Vector2 = (player.global_position - to_global(center)).abs()
		near = clampf(1.0 - (maxf(d.x - 18.0, 0.0) / 36.0 + maxf(d.y - 60.0, 0.0) / 50.0), 0.0, 1.0)
	var flare: float = clampf(1.0 - (Time.get_ticks_msec() / 1000.0 - float(host.get_meta(&"flare_at", -100.0))) / 0.6, 0.0, 1.0)
	ink.knock([RisoPrint.NIGHT], [_mouth])
	_portal_clock += _dt * lerpf(1.0, PortalArt.PORTAL_SLOW, near)
	if RisoPrint.instance != null and RisoPrint.instance.portal_style == &"static":
		_portal_static(center, near, flare, RisoPrint.ACCENT, _portal_clock)
	else:
		_portal_ripples(center, near, flare, RisoPrint.ACCENT, _portal_clock)
	# The keystone's disc and its emblem.
	var key: Vector2 = Vector2(0, g - ARCH_H - 2.0)
	var disc: PackedVector2Array = RisoShapes.circle(key, DISC_R, 24)
	ink.knock(RisoPrint.ALL_PLATES, [disc])
	ink.ink(RisoPrint.NIGHT, 1.0, _emblem(key), false)
	var to: Variant = _leads_to()
	if to != null:
		var s: float = _pop(0, Vector2(0, g - 60.0))
		if s > 0.0:
			_place(to as Vector2i, Vector2(0, g - POP_Y), s)


## The top half of an elliptical ring round `c`, from radii `outer` to `inner`: the arch's head.
static func _arch(c: Vector2, outer: Vector2, inner: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(17):
		var a: float = PI + PI * float(i) / 16.0
		out.append(c + Vector2(cos(a) * outer.x, sin(a) * outer.y))
	for i: int in range(16, -1, -1):
		var a: float = PI + PI * float(i) / 16.0
		out.append(c + Vector2(cos(a) * inner.x, sin(a) * inner.y))
	return out


## Where it leads: a department's destination, or the institute level a way back returns to; null
## before it is set up.
func _leads_to() -> Variant:
	var dept: Department = host as Department
	if dept != null and dept.map_info != null:
		return dept.destination()
	var back: WayBack = host as WayBack
	if back != null and back.map_info != null:
		return back.destination()
	return null


## The emblem on its keystone (see the class description), round `c`.
func _emblem(c: Vector2) -> Array[PackedVector2Array]:
	var dept: Department = host as Department
	var band: StringName = dept.band() if dept != null else &"institute"
	match band:
		&"garden":
			return [Transform2D(0.4, c) * RisoShapes.almond(Vector2.ZERO, 6.0, 12.0, 12), RisoShapes.rrect(c.x - 0.8, c.y + 2.0, 1.6, 9.0, 0.8)]
		&"cemetery":
			return [RisoShapes.circle(c + Vector2(0, -2.0), 8.0, 16), RisoShapes.rrect(c.x - 4.5, c.y + 3.0, 9.0, 6.0, 2.0)]
		&"crags":
			return [PackedVector2Array([c + Vector2(0, -12), c + Vector2(7, -2), c + Vector2(4, 11), c + Vector2(-4, 11), c + Vector2(-7, -2)])]
		&"sky":
			return [RisoShapes.sparkle(c, 12.0)]
	# The institute: a pediment over three columns.
	var out: Array[PackedVector2Array] = [PackedVector2Array([c + Vector2(-11, -4), c + Vector2(0, -11), c + Vector2(11, -4)])]
	for x: float in [-7.0, 0.0, 7.0]:
		out.append(RisoShapes.rrect(c.x + x - 1.6, c.y - 3.0, 3.2, 12.0, 0.8))
	return out


## Place `at` on a plaque centred on `centre`, scaled `s`: its marks and its two numbers (as a
## signpost prints one, SignArt._place).
func _place(at: Vector2i, centre: Vector2, s: float) -> void:
	var n: Vector3i = Rules.place_numbers(at)
	var texts: PackedStringArray = PackedStringArray([str(n.x), str(absi(n.y))])
	var font: Font = RisoTheme.serif()
	var widths: Vector2 = Vector2(font.get_string_size(texts[0], HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_PX).x,
			font.get_string_size(texts[1], HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_PX).x) * s
	var r: float = PLACE_R * s
	var w: float = RisoMarks.place_width(r, widths, false)
	var h: float = 40.0 * s
	var plate: PackedVector2Array = RisoShapes.rrect(centre.x - w * 0.5 - 11.0 * s, centre.y - h * 0.5, w + 22.0 * s, h, h * 0.35)
	var u: InkCanvas = _ui()
	u.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], [plate])
	u.ink(RisoPrint.BLUE, 0.2, [plate], false)
	var xs: Vector2 = RisoMarks.place_marks(u, Vector2(centre.x - w * 0.5, centre.y), r, widths, false, n.y < 0)
	_text(texts[0], Vector2(xs.x + widths.x * 0.5, centre.y), NUMBER_PX, s)
	_text(texts[1], Vector2(xs.y + widths.y * 0.5, centre.y), NUMBER_PX, s)
