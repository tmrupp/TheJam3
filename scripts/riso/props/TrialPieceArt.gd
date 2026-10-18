extends RisoProp
## A piece of a class's trial (TrialPiece), in a soft accent halo (the trial is the way to a tier),
## by kind:
## - a cord: a paper rope with night twists hanging from the ceiling to a weight over the floor; cut,
##   its foot drops and both ends fade;
## - a sigil: a small pale stone floating (blue screened back on paper, as a glyph seal's marble),
##   the trial's spell's mark on it in night; struck, it flashes in accent, and lit for good once the
##   whole ring is caught;
## - a stone: a heavy block of blue stone on the floor, shaded in night, the spell's mark knocked to
##   paper on its face, a night groove along the floor to an accent diamond at the mark it is shoved
##   to;
## - a hoop: an accent hoop hung by two night strings from the ceiling;
## - a mark: a floating paper token in a halo with the spell's mark in night, bobbing; a hidden one
##   (awareness) shows only while the wizard senses, faint otherwise.
## A blow that glances jolts it; done, it fades over TrialPiece.FADE.

## The halo's reach over each piece's own size (px), and how big a spell's mark is on a token, a
## sigil and a stone.
const HALO: float = 12.0
const MARK_TOKEN: float = 0.62
const MARK_SIGIL: float = 0.4
const MARK_STONE: float = 0.7
## A cord: how wide, and how far over the floor its weight hangs (px).
const CORD_W: float = 7.0
const CORD_FOOT: float = 34.0
## A sigil's and a token's radius, a hoop's, and a stone's half width and height (px).
const SIGIL_R: float = 14.0
const TOKEN_R: float = 24.0
const HOOP_R: float = 40.0
const STONE_HALF: Vector2 = Vector2(48.0, 40.0)


## A stone's track reaches across to its mark: in view by all of it.
func view_rect() -> Rect2:
	var p: TrialPiece = host as TrialPiece
	if p == null or p.kind != TrialPiece.STONE:
		return Rect2()
	var lo: float = minf(p.start_x, p.goal_x) - 80.0
	return Rect2(Vector2(lo, host.global_position.y - 100.0), Vector2(absf(p.start_x - p.goal_x) + 160.0, 200.0))


func _draw_art() -> void:
	var p: TrialPiece = host as TrialPiece
	if p == null:
		return
	var g: float = _ground()
	var jolt: float = sin(p.since_glance * 60.0) * 4.0 * exp(-p.since_glance * 8.0) if p.since_glance < 0.6 else 0.0
	var fade: float = 1.0 - clampf(p.since_done / TrialPiece.FADE, 0.0, 1.0) if p.done else 1.0
	match p.kind:
		TrialPiece.CORD:
			_cord(p, g, jolt, fade)
		TrialPiece.SIGIL:
			_sigil(p, jolt, fade)
		TrialPiece.STONE:
			_stone(p, g, jolt, fade)
		TrialPiece.HOOP:
			_hoop(p, jolt, fade)
		_:
			_token(p, jolt, fade)


## A cord from the ceiling to its weight over the floor (see the class description).
func _cord(p: TrialPiece, g: float, jolt: float, fade: float) -> void:
	var top: float = -p.ceiling_up
	var foot: float = g - CORD_FOOT
	var drop: float = 0.0
	var cut: float = (top + foot) * 0.5
	if p.done:
		drop = clampf(p.since_done / TrialPiece.FADE, 0.0, 1.0)
		drop = drop * drop * 60.0
	var upper: PackedVector2Array = PackedVector2Array([Vector2(jolt, top), Vector2(jolt, cut if p.done else foot)])
	var lower: PackedVector2Array = PackedVector2Array([Vector2(jolt, cut + drop), Vector2(jolt, foot + drop)])
	var lines: Array[PackedVector2Array] = RisoDecor.strip(upper, CORD_W, CORD_W)
	if p.done:
		lines.append_array(RisoDecor.strip(lower, CORD_W, CORD_W))
	ink.ink(RisoPrint.ACCENT, 0.18 * fade, RisoDecor.strip(PackedVector2Array([Vector2(jolt, top), Vector2(jolt, foot)]), CORD_W + HALO * 2.0, CORD_W + HALO * 2.0))
	ink.knock(RisoPrint.ALL_PLATES, lines)
	ink.ink(RisoPrint.BLUE, 0.25 * fade, lines, false)
	var weight: PackedVector2Array = RisoShapes.rrect(jolt - 9.0, foot + drop - 4.0, 18.0, 16.0, 6.0)
	ink.ink(RisoPrint.NIGHT, 0.9 * fade, [weight], false)
	var twists: Array[PackedVector2Array] = []
	var y: float = top + 8.0
	while y < foot + drop - 6.0:
		if not p.done or y < cut or y > cut + drop:
			twists.append(PackedVector2Array([Vector2(jolt - CORD_W * 0.5, y), Vector2(jolt + CORD_W * 0.5, y - 4.0), Vector2(jolt + CORD_W * 0.5, y - 2.0), Vector2(jolt - CORD_W * 0.5, y + 2.0)]))
		y += 12.0
	ink.ink(RisoPrint.NIGHT, 0.35 * fade, twists, false)


## A sigil floating in its ring (see the class description).
func _sigil(p: TrialPiece, jolt: float, fade: float) -> void:
	var c: Vector2 = Vector2(jolt, sin(t * 2.2 + phase) * 3.0)
	var flash: bool = p.struck_at >= 0 and Engine.get_physics_frames() - p.struck_at < 12
	ink.ink(RisoPrint.ACCENT, (0.6 if p.done or flash else 0.2) * fade, [RisoShapes.circle(c, SIGIL_R + HALO, 20)])
	var stone: PackedVector2Array = RisoShapes.circle(c, SIGIL_R, 18)
	ink.knock(RisoPrint.ALL_PLATES, [stone])
	ink.ink(RisoPrint.ACCENT if p.done else RisoPrint.BLUE, fade if p.done else 0.5 * fade, [stone])
	_glyph(p.spell, c, MARK_SIGIL, fade)


## The stone, its track and its mark (see the class description).
func _stone(p: TrialPiece, g: float, jolt: float, fade: float) -> void:
	var goal: float = p.goal_x - host.global_position.x
	var start: float = p.start_x - host.global_position.x
	var lo: float = minf(goal, start) - STONE_HALF.x
	var hi: float = maxf(goal, start) + STONE_HALF.x
	ink.ink(RisoPrint.NIGHT, 0.5 * fade, [RisoShapes.rrect(lo, g - 5.0, hi - lo, 5.0, 2.5)], false)
	var d: Vector2 = Vector2(goal, g - 12.0)
	ink.ink(RisoPrint.ACCENT, fade, [PackedVector2Array([d + Vector2(0, -10), d + Vector2(10, 0), d + Vector2(0, 10), d + Vector2(-10, 0)])])
	var block: PackedVector2Array = RisoShapes.rrect(jolt - STONE_HALF.x, g - STONE_HALF.y * 2.0, STONE_HALF.x * 2.0, STONE_HALF.y * 2.0, 6.0)
	ink.ink(RisoPrint.ACCENT, 0.15 * fade, [RisoShapes.rrect(jolt - STONE_HALF.x - HALO, g - STONE_HALF.y * 2.0 - HALO, (STONE_HALF.x + HALO) * 2.0, STONE_HALF.y * 2.0 + HALO, 10.0)])
	ink.knock(RisoPrint.ALL_PLATES, [block])
	ink.ink(RisoPrint.BLUE, 0.85 * fade, [block])
	ink.ink(RisoPrint.NIGHT, 0.35 * fade, [RisoShapes.rrect(jolt - STONE_HALF.x, g - 14.0, STONE_HALF.x * 2.0, 14.0, 4.0)], false)
	var c: Vector2 = Vector2(jolt, g - STONE_HALF.y - 4.0)
	ink.knock(RisoPrint.ALL_PLATES, [RisoShapes.circle(c, 22.0, 20)])
	_glyph(p.spell, c, MARK_STONE * 0.7, fade)


## The hoop on its strings (see the class description).
func _hoop(p: TrialPiece, jolt: float, fade: float) -> void:
	var c: Vector2 = Vector2(jolt, sin(t * 1.6 + phase) * 3.0)
	var top: float = -p.ceiling_up
	for side: float in [-1.0, 1.0]:
		ink.ink(RisoPrint.NIGHT, 0.6 * fade, RisoDecor.strip(PackedVector2Array([Vector2(side * HOOP_R * 0.7, top), c + Vector2(side * HOOP_R * 0.7, -HOOP_R * 0.7)]), 2.0, 2.0), false)
	ink.ink(RisoPrint.ACCENT, 0.15 * fade, RisoShapes.ring(c, HOOP_R - 12.0, HOOP_R + 12.0, 32))
	ink.ink(RisoPrint.ACCENT, fade, RisoShapes.ring(c, HOOP_R - 5.0, HOOP_R + 5.0, 32))


## A mark's token (see the class description).
func _token(p: TrialPiece, jolt: float, fade: float) -> void:
	var c: Vector2 = Vector2(jolt, sin(t * 2.0 + phase) * 5.0)
	if not p.shown():
		ink.ink(RisoPrint.BLUE, 0.12, [RisoShapes.circle(c, TOKEN_R, 20)])
		return
	ink.ink(RisoPrint.ACCENT, (0.3 + 0.12 * sin(t * 3.0 + phase)) * fade, [RisoShapes.circle(c, TOKEN_R + HALO, 24)])
	ink.knock(RisoPrint.ALL_PLATES, [RisoShapes.circle(c, TOKEN_R, 24)])
	_glyph(p.spell, c, MARK_TOKEN, fade)


## Spell `a`'s mark at `c`, `scale` big, in night ink.
func _glyph(a: StringName, c: Vector2, scale: float, fade: float) -> void:
	var mark: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in RisoGlyph.of(a, Vector2.ZERO, t):
		mark.append(Transform2D(0.0, Vector2(scale, scale), 0.0, c) * poly)
	ink.ink(RisoPrint.NIGHT, fade, mark, false)
