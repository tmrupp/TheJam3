extends TestKit
## Sigils (Sigils.gd): each pair of teleporters shares a sigil, and each switch shares one with
## what it works (a gate, a bell or vane, a lift); no two links in a level (pairs or switches)
## share one while there are sigils to go round, and past that a sigil is reused only once every
## one is in use, by the link furthest from its others. Dealt the same on every build, and read by
## the placed things in play.
## godot --headless --path . --script res://tests/sigils_test.gd


func run() -> void:
	print("shapes")
	var shapes_ok: bool = true
	for k: int in range(RisoMarks.SIGILS):
		var polys: Array[PackedVector2Array] = RisoMarks.sigil(k, Vector2.ZERO, 10.0)
		for poly: PackedVector2Array in polys:
			for p: Vector2 in poly:
				shapes_ok = shapes_ok and absf(p.x) <= 10.5 and absf(p.y) <= 10.5
			shapes_ok = shapes_ok and poly.size() >= 3
		shapes_ok = shapes_ok and not polys.is_empty()
	check(shapes_ok, "each of the %d sigils is drawn within its size" % RisoMarks.SIGILS)

	print("dealing")
	var pairs_ok: bool = true
	var switches_ok: bool = true
	var apart_ok: bool = true
	var again_ok: bool = true
	var portals_seen: int = 0
	var switches_seen: int = 0
	var bells: int = 0
	var lifts: int = 0
	var crowded: int = 0
	for world_seed: int in [1, 7, 28, 99]:
		for depth: int in [0, NextWorldDef.first_depth(&"cemetery"), NextWorldDef.first_depth(&"sky"), NextWorldDef.band_row(&"sky", 3)]:
			var at: Vector2i = Vector2i(world_seed, depth)
			var w: LevelGen = build(at)
			var portal_kinds: Array[int] = []
			var switch_kinds: Array[int] = []
			for v: Vector2i in w.objects:
				var cell: LevelGen.Cell = w.get_cell(v)
				if cell.type == LevelGen.Type.PORTAL:
					var other: Vector2i = cell.extra_info
					pairs_ok = pairs_ok and w.sigil_at(v) >= 0 and w.sigil_at(v) == w.sigil_at(other)
					if v < other:
						portal_kinds.append(w.sigil_at(v))
				elif cell.type == LevelGen.Type.SWITCH:
					var target: Vector2i = cell.extra_info
					switches_ok = switches_ok and w.sigil_at(v) >= 0 and w.sigil_at(v) == w.sigil_at(target)
					switch_kinds.append(w.sigil_at(v))
					var kind: LevelGen.Type = w.get_cell(target).type
					if kind in [LevelGen.Type.BELL, LevelGen.Type.VANE]:
						bells += 1
					elif kind == LevelGen.Type.MOVING_PLATFORM:
						lifts += 1
			var distinct: Dictionary = {}
			for k: int in portal_kinds + switch_kinds:
				distinct[k] = true
			var links: int = portal_kinds.size() + switch_kinds.size()
			apart_ok = apart_ok and distinct.size() == mini(links, RisoMarks.SIGILS)
			crowded = maxi(crowded, links)
			portals_seen += portal_kinds.size()
			switches_seen += switch_kinds.size()
			var rebuilt: LevelGen = build(at)
			for v: Vector2i in w.objects:
				again_ok = again_ok and rebuilt.sigil_at(v) == w.sigil_at(v)
	check(pairs_ok, "both ends of each of %d teleporter pairs share a sigil" % portals_seen)
	check(switches_ok, "each of %d switches shares its sigil with what it works (%d bells or vanes, %d lifts among them)" % [switches_seen, bells, lifts])
	check(bells > 0, "bells and vanes chained to switches are among them")
	check(apart_ok, "no two links in a level share a sigil while there are sigils to go round (up to %d links in a level)" % crowded)
	check(again_ok, "the sigils are dealt the same on every build")

	print("more links than sigils")
	var w0: LevelGen = build(Vector2i(28, 0))
	var links: Array = []
	for i: int in range(RisoMarks.SIGILS + 4):
		links.append([Vector2i(i * 10, 0), Vector2i(i * 10 + 1, 0)])
	var dealt: Dictionary = {}
	Sigils._deal_links(w0, links, 1, dealt)
	var first: Dictionary = {}
	for i: int in range(RisoMarks.SIGILS):
		first[dealt[links[i][0]]] = true
	check_eq(first.size(), RisoMarks.SIGILS, "the first %d links get every sigil once" % RisoMarks.SIGILS)
	# Links along a line: the 13th reuses the sigil of a link at the far end of it.
	var reused: int = dealt[links[RisoMarks.SIGILS][0]]
	var twin: int = -1
	for i: int in range(RisoMarks.SIGILS):
		if dealt[links[i][0]] == reused:
			twin = i
	check(twin == 0, "the next reuses the sigil of the furthest link (link %d)" % twin)

	print("in play")
	await boot(28)
	player.set_physics_process(false)
	var switch_nodes: Array[Node] = placed("switch.tscn")
	var gate_nodes: Array[Node] = placed("switch_gate.tscn")
	var play_ok: bool = not switch_nodes.is_empty()
	for lever: Node in switch_nodes:
		var to: Vector2i = (lever as Switch).gate_cell
		play_ok = play_ok and Sigils.of(lever) >= 0 and Sigils.of(lever) == info.world.sigil_at(to)
	for g: Node in gate_nodes:
		play_ok = play_ok and Sigils.of(g) == info.world.sigil_at((g as SwitchGate).switch_cell)
	check(play_ok, "placed switches and gates read their shared sigil (%d switches)" % switch_nodes.size())
	var portal_nodes: Array[Node] = placed("portal.tscn")
	var portals_ok: bool = not portal_nodes.is_empty()
	for p: Node in portal_nodes:
		portals_ok = portals_ok and Sigils.of(p) == info.world.sigil_at(info.cell_at((p as Portal).go_to_pos))
	check(portals_ok, "placed teleporters read the sigil their partner shows (%d)" % portal_nodes.size())
	finish()
