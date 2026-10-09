extends TestKit
## The crags' towers (CragsArchetype.build_towers): every crag level has at least one, each tall and
## narrow, of built stone, standing on rock, a room of air on each storey (kept as interiors), the
## ground floor open through a doorway in either wall. Each floor over a room has a stair hole at
## one end, the ends taking turns, with a one-way ledge under it, so the wizard climbs it on their
## own hops (Reach) from the doorway to the top room, and on through the roof's hatch onto the roof
## for a watchtower. A hoard tower is roofed over and holds stars in its top room. The keeps' halls
## are interiors too. Two builds of a level are the same.
## godot --headless --path . --script res://tests/towers_test.gd


func run() -> void:
	var hoards: int = 0
	var watch: int = 0
	for k: int in [0, 1, 2, 3, 5]:
		var at: Vector2i = Vector2i(28, NextWorldDef.band_row(&"crags", k))
		var w: LevelGen = build(at)
		print("row %d: %d towers" % [at.y, w.towers.size()])
		check(not w.towers.is_empty(), "row %d has towers" % at.y)
		for tower: Dictionary in w.towers:
			if tower["hoard"]:
				hoards += 1
			else:
				watch += 1
			_tower(w, tower)
		check(w.interiors.size() > 0 and w.interiors.keys().all(func(v: Vector2i) -> bool: return not w.masonry.has(v)), "its buildings' air is kept as interiors, none of it masonry")
		var again: LevelGen = build(at)
		check(again.towers == w.towers and again.interiors == w.interiors, "the same every build")
	check(hoards > 0 and watch > 0, "watchtowers and hoard towers both turn up (%d and %d)" % [watch, hoards])
	check(build(Vector2i(28, 0)).towers.is_empty(), "the garden has none")
	finish()


## One tower's build and climb.
func _tower(w: LevelGen, tower: Dictionary) -> void:
	var box: Rect2i = tower["box"]
	var x0: int = box.position.x
	var x1: int = box.end.x - 1
	var roof: int = box.position.y
	var ground: int = box.end.y - 1
	var name_of: String = "tower at %s (%s)" % [box.position, "hoard" if tower["hoard"] else "watch"]
	var storeys: int = (box.size.y - 1) / CragsArchetype.STOREY
	check(box.size.x >= CragsArchetype.TOWER_WIDE.x and storeys >= CragsArchetype.TOWER_STOREYS.x, "%s: %d wide, %d storeys" % [name_of, box.size.x, storeys])
	# Standing on rock: under its footing, down from each column, rock within TOWER_FOOTING rows.
	var grounded: bool = true
	for x: int in range(x0, x1 + 1):
		var y: int = ground + 1
		while w.is_valid(Vector2i(x, y)) and w.masonry.has(Vector2i(x, y)):
			y += 1
		grounded = grounded and (not w.is_valid(Vector2i(x, y)) or w.is_ground(Vector2i(x, y)) or w.is_ground(Vector2i(x, y - 1)))
	check(grounded, "%s: stands on rock" % name_of)
	# Its ledges: one-way platforms under its stair holes.
	var holes: Array = tower["holes"]
	var ledges: Array = tower["ledges"]
	var ok_stair: bool = holes.size() == ledges.size() and holes.size() >= CragsArchetype.STAIR * (storeys - 1)
	for i: int in range(holes.size()):
		var hole: Vector2i = holes[i]
		ok_stair = ok_stair and not w.is_ground(hole) and w.get_cell(ledges[i]).type == LevelGen.Type.PLATFORM and ledges[i] == hole + Vector2i.DOWN
	check(ok_stair, "%s: a stair hole in each floor over a room, a ledge under each (%d)" % [name_of, holes.size()])
	# Climbed on the wizard's own hops from outside its doorway to its top room (and its roof).
	var nodes: Dictionary = Reach.footholds(w)
	var door: Vector2i = Vector2i(x0 - 1, ground - 1) if nodes.has(Vector2i(x0 - 1, ground - 1)) else Vector2i(x1 + 1, ground - 1)
	check(nodes.has(door), "%s: something to stand on outside its doorway" % name_of)
	# Only the tower and its doorsteps: so it is the stair inside that is climbed.
	var inside: Dictionary = {}
	for v: Vector2i in nodes:
		if v.x >= x0 - 1 and v.x <= x1 + 1 and v.y >= roof - 1 and v.y <= ground:
			inside[v] = nodes[v]
	var reach: Dictionary = {door: true}
	Reach.grow(w, inside, reach, [door], {}, {}, Reach.ACROSS, Reach.UP)
	var top: Array = tower["top"]
	check(top.any(func(v: Vector2i) -> bool: return reach.has(v)), "%s: its top room reached on the wizard's own hops" % name_of)
	if tower["hoard"]:
		check(w.is_ground(Vector2i(x0 + 1, roof)) and range(x0 + 1, x1).all(func(x: int) -> bool: return w.is_ground(Vector2i(x, roof))), "%s: roofed over" % name_of)
		var stars: int = top.filter(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.COIN).size()
		check(stars > 0, "%s: stars in its top room (%d)" % [name_of, stars])
	else:
		var on_roof: bool = range(x0, x1 + 1).any(func(x: int) -> bool: return reach.has(Vector2i(x, roof - 1)))
		check(on_roof, "%s: out through the hatch onto its roof" % name_of)
