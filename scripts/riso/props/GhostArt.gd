extends RisoProp
## The wizard's ghost where they died, with the stars it holds circling.


## The Ghost it dresses.
var ghost: Ghost:
	get:
		return host as Ghost


func _draw_art() -> void:
	var s: float = 3.2
	var drift: float = sin(t * 1.7 + phase) * 5.0
	var at: Transform2D = Transform2D(sin(t * 1.1 + phase) * 0.04, Vector2(s, s), 0.0, Vector2(0, 34 + drift))
	var style: StringName = RisoPrint.instance.character_style if RisoPrint.instance != null else RisoPrint.DEFAULT_CHARACTER
	var player: Player = Stage.player()
	var spell: StringName = Abilities.spell(player) if player != null else &""
	var body: Array[PackedVector2Array] = RisoMarks.ghost_shape(at) if style == &"wizard" else RisoCostume.silhouette(style, at, 1.0, spell)
	ink.ink(RisoPrint.GLOW, 0.12, [RisoShapes.circle(Vector2(0, -30 + drift), 70.0 * (1.0 + 0.05 * sin(t * 2.3)), 32)])
	ink.ink(RisoPrint.GLOW, 0.45, body)
	# The faceless hood between robe and hat, dark, with the eyes still lit inside it.
	var face: Vector2 = Vector2(0, -18.5)
	if style == &"cosmonaut":
		face = Vector2(0.8, -24)
	elif style == &"fool":
		face = Vector2(0.5, -23.5)
	elif style == &"shaman":
		face = Vector2(0, -25)
	var hood: PackedVector2Array = at * (RisoShapes.smooth(PackedVector2Array([Vector2(-3.8, -14.4), Vector2(-5.0, -18.0), Vector2(-5.4, -22.0), Vector2(5.4, -22.0), Vector2(5.0, -18.0), Vector2(3.8, -14.4)])) if style == &"wizard" else RisoShapes.ellipse(face, 4.5, 4.0))
	ink.ink(RisoPrint.NIGHT, 0.7, [hood])
	ink.ink(RisoPrint.GLOW, 0.2, [hood], false)
	var eyes: Array[PackedVector2Array] = [RisoShapes.circle(at * (face + Vector2(-1.4, 0)), 3.0, 10), RisoShapes.circle(at * (face + Vector2(1.4, 0)), 3.0, 10)]
	ink.knock(RisoPrint.ALL_PLATES, eyes)
	ink.ink(RisoPrint.EYE, 1.0, eyes, false)
	var count: int = mini(ghost.stars, 8)
	var motes: Array[PackedVector2Array] = []
	for i: int in range(count):
		var a: float = t * 1.3 + TAU * float(i) / float(count)
		var c: Vector2 = Vector2(0, -30 + drift) + Vector2(cos(a) * 52.0, sin(a) * 22.0)
		motes.append(RisoShapes.sparkle(c, 8.0))
	if not motes.is_empty():
		ink.ink(RisoPrint.ACCENT, 1.0, motes)
