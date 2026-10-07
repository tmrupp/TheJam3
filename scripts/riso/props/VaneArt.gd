extends BellArt
## A wind vane on its post, chained like a bell, its arrow pointing across while its wind blows.


## A wind vane on its post by a chasm (Vane): a blue post and, on top, an arrow in sun ink with a
## tail fin, and a little cross of cups under it. While its chasm's wind blows from it, the arrow
## points across the chasm and the cups spin; otherwise it idles on the breeze. Chained like a
## grave bell (padlock or switch plate); freed and still, a soft halo shows it waits to be turned.
func _draw_art() -> void:
	var g: float = _ground()
	var blowing: bool = bell.rung()
	var chained: bool = not bell.unchained()
	var since: float = bell.since_rung
	var rattle: float = bell.since_rattle
	var freed: float = bell.since_freed
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-5.0, g - 160.0, 10.0, 160.0, 4.0)])
	var head: Vector2 = Vector2(0, g - 168.0)
	# Which way it points: across its chasm while the wind blows from it.
	var across: float = 1.0
	var wind: Wind = _chasm_wind(bell.chasm)
	if wind != null:
		across = 1.0 if wind.rect.get_center().x > host.global_position.x else -1.0
	var swing: float = sin(t * 0.9 + phase) * 0.5 if not blowing else 0.0
	if rattle < 0.8:
		swing += sin(rattle * 38.0) * 0.2 * exp(-rattle * 5.0)
	var face: float = across if blowing else signf(cos(swing * 2.0 + phase)) * (0.4 + 0.6 * absf(cos(swing * 2.0 + phase)))
	if since >= 0.0 and since < 0.6:
		face = across * (1.0 - 2.0 * exp(-since * 9.0) * cos(since * 20.0)) * 0.5 + across * 0.5
	if not blowing and not chained:
		ink.ink(RisoPrint.ACCENT, 0.18 + 0.06 * sin(t * 2.5 + phase), [RisoShapes.circle(head + Vector2(0, 30), 50.0, 28)])
	var xf: Transform2D = Transform2D(0.0, Vector2(face, 1.0), 0.0, head)
	var arrow: PackedVector2Array = PackedVector2Array([Vector2(-34, -3), Vector2(22, -3), Vector2(22, -10), Vector2(40, 0), Vector2(22, 10), Vector2(22, 3), Vector2(-34, 3)])
	var fin: PackedVector2Array = PackedVector2Array([Vector2(-34, -3), Vector2(-46, -16), Vector2(-26, -16), Vector2(-20, -3)])
	var fin2: PackedVector2Array = PackedVector2Array([Vector2(-34, 3), Vector2(-46, 16), Vector2(-26, 16), Vector2(-20, 3)])
	ink.ink(RisoPrint.ACCENT, 1.0, [xf * arrow, xf * fin, xf * fin2])
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.circle(head, 6.0, 14)])
	# The cups: a cross that spins while the wind blows from it.
	var spin: float = t * (9.0 if blowing else 0.6) + phase
	var cups: Array[PackedVector2Array] = []
	for k: int in range(4):
		var a: float = spin + PI * 0.5 * float(k)
		var d: Vector2 = Vector2(cos(a) * 22.0, sin(a) * 6.0)
		cups.append_array(RisoDecor.strip(PackedVector2Array([head + Vector2(0, 26), head + Vector2(0, 26) + d]), 2.5, 2.5))
		cups.append(RisoShapes.circle(head + Vector2(0, 26) + d, 5.0, 10))
	ink.ink(RisoPrint.BLUE, 1.0, cups)
	if chained or freed < 0.7:
		_bell_chain(Transform2D(0.0, Vector2(2.0, 2.0), 0.0, Vector2(0.0, g - 120.0)), g, chained, freed)
	if blowing:
		var gusts: Array[PackedVector2Array] = []
		for k: int in range(3):
			var u: float = fmod(t * 1.2 + float(k) / 3.0, 1.0)
			var y: float = head.y - 12.0 + 12.0 * float(k)
			var x: float = across * (50.0 + u * 70.0)
			gusts.append(RisoShapes.almond(Vector2(x, y), 16.0 * (1.0 - u) + 4.0, 2.4, 10))
		ink.ink(RisoPrint.ACCENT, 0.6, gusts, false)


## The crosswind over chasm `id`, if this level has one.
func _chasm_wind(id: int) -> Wind:
	for node: Node in get_tree().get_nodes_in_group(&"wind"):
		if node is Wind and (node as Wind).chasm == id:
			return node as Wind
	return null
