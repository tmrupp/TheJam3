extends TestKit
## The practice range (PracticeRange, PracticeTally), for debug runs: laid out by hand, the same on
## every visit, behind no door, with its way back, a lantern and its tally at its left end and every
## kind of foe in its bays, some with shields. In the game its foes drop no stars and come back
## PracticeTally.RESPAWN seconds after they fall; they patrol as anywhere, or, held still from the
## F7 panel, stand where they are; made sturdy, they have PracticeTally.STURDY_HP. The tally counts
## what the spell in the damage slot deals, its casts, the foes slain and how long they took, and
## starts afresh for another spell, keeping the last one's result.
## godot --headless --path . --script res://tests/practice_test.gd

## The first wisp's cell (PracticeRange.MAP), and the cell the wizard stands in near it.
const WISP: Vector2i = Vector2i(13, 12)
const STRIKE_FROM: Vector2i = Vector2i(12, 12)
## How far (px) to the left of the wisp the wizard strikes it from.
const STRIKE_OFF: float = 60.0


func run() -> void:
	var kind: int = Worlds.kind_of(PracticeRange)
	var at: Vector2i = Worlds.side_at(kind, Vector2i(28, 1))
	_layout(kind, at)
	await boot(28)
	MapInfo.debug = true
	Health.invincible = true
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var tally: PracticeTally = PracticeTally.instance
	check(tally != null and is_instance_valid(tally), "the tally is in the range")
	if tally == null:
		_done()
		return
	await _foes(tally)
	await _still(tally)
	await _strike(tally)
	await _swap(tally)
	await _sturdy(tally)
	_done()


func _done() -> void:
	PracticeTally.still = false
	PracticeTally.sturdy = false
	Health.invincible = false
	MapInfo.debug = false
	RunState.delete_save()
	finish()


func _layout(kind: int, at: Vector2i) -> void:
	print("layout")
	var w: LevelGen = build(at)
	var again: LevelGen = build(at)
	check(w != null and again != null and w.objects == again.objects, "the range is laid out the same on every visit")
	if w == null:
		return
	check(w.exits.keys() == [MapInfo.Exit.BACK] and w.exit_lanterns.has(MapInfo.Exit.BACK) and count_of(w, LevelGen.Type.TALLY) == 1, "its way back alone, with a lantern and the tally")
	var kinds: Array[LevelGen.Type] = [LevelGen.Type.ENEMY, LevelGen.Type.HOPPER, LevelGen.Type.SHOOTER, LevelGen.Type.ABOMINATION,
		LevelGen.Type.CROSSBOW, LevelGen.Type.BUG, LevelGen.Type.NEST, LevelGen.Type.BIRD]
	var missing: Array[String] = []
	for t: LevelGen.Type in kinds:
		if count_of(w, t) == 0:
			missing.append(str(LevelGen.Type.find_key(t)))
	check(missing.is_empty(), "a bay of every kind of foe (missing: %s)" % [missing])
	var shielded: int = w.objects.filter(func(v: Vector2i) -> bool: return w.get_cell(v).mods.has("shield")).size()
	check_eq(shielded, 3, "three foes with shields")
	var doors: bool = false
	for debug: bool in [false, true]:
		MapInfo.debug = debug
		for row: int in [-8, -1, 0, 1, 5, 12]:
			for x: int in range(20, 40):
				doors = doors or kind in Rules.def_for(Vector2i(x, row)).doors
	MapInfo.debug = false
	check(not doors, "no level has a door into it, debug run or not")
	check((Rules.def_for(at) as SideWorld).dead_end(), "its way back leads out to the level it was entered from")


func _foes(tally: PracticeTally) -> void:
	print("foes")
	await frames(2)
	var laid: int = info.world.objects.filter(func(v: Vector2i) -> bool: return Placeables.has_flag(info.world.get_cell(v).type, &"enemy")).size()
	check_eq(tally.foes.size(), laid, "every foe laid with the range is taken in")
	var starless: bool = tally.foes.values().all(func(n: Node) -> bool: return not (n.get_node("Wound") as Wound).stars)
	check(starless, "none drops stars")
	player.set_physics_process(false)
	player.global_position = info.cell_position(STRIKE_FROM) + Vector2(0, 16 - 31)
	var wisp: Node2D = tally.foes[WISP] as Node2D
	var from: Vector2 = wisp.global_position
	var moved: bool = await within(func() -> bool: return is_instance_valid(wisp) and wisp.global_position.distance_to(from) > 8.0, 3.0)
	check(moved, "live, the wisps patrol")


func _still(tally: PracticeTally) -> void:
	print("still")
	var riso: RisoPrint = RisoPrint.instance
	(riso._options[&"practice_still"] as OptionButton).item_selected.emit(1)
	check(PracticeTally.still, "the F7 panel holds the foes still")
	await frames(3)
	var wisp: Node2D = tally.foes.get(WISP) as Node2D
	check(wisp != null and is_instance_valid(wisp), "the foes are laid again")
	if wisp == null:
		return
	var held: bool = await within(func() -> bool: return is_instance_valid(wisp) and not wisp.get_node("Mover").is_physics_processing(), PracticeTally.SETTLE + 0.5)
	check(held and wisp.global_position.y > info.cell_position(WISP).y, "held still once it has fallen from where it was laid onto the floor")
	var from: Vector2 = wisp.global_position
	await frames(60)
	check(is_instance_valid(wisp) and wisp.global_position.distance_to(from) < 2.0, "and it stays put")


func _strike(tally: PracticeTally) -> void:
	print("strike")
	tally.reset()
	await frames(1)
	var wisp: Node2D = tally.foes.get(WISP) as Node2D
	if wisp == null:
		check(false, "a wisp to strike")
		return
	var wound: Wound = wisp.get_node("Wound") as Wound
	var hp: int = wound.hp
	var slash: Slash = player.get_node("Slash") as Slash
	player.global_position = Vector2(wisp.global_position.x - STRIKE_OFF, info.cell_position(STRIKE_FROM).y + 16 - 31)
	player.sprite.scale.x = absf(player.sprite.scale.x)
	slash.wait = 0.0
	check(Abilities.cast(player), "the wizard slashes at a wisp")
	check(wound.hp == hp - 1 and tally.dealt == 1 and tally.casts == 1 and tally.recent() == 1, "the tally counts the cast and the wound")
	var home: Vector2 = wisp.get_meta(&"practice_home") as Vector2
	var back: bool = await within(func() -> bool: return is_instance_valid(wisp) and wisp.global_position.distance_to(home) < 1.0, 1.0)
	check(back, "knocked aside, the still wisp drifts back to its spot")
	var struck: float = tally.clock
	for i: int in range(hp - 1):
		await frames(10)
		slash.wait = 0.0
		Abilities.cast(player)
	await frames(1)
	check(tally.slain == 1 and not tally.foes.has(WISP), "struck down, it is counted slain")
	check(absf(tally.mean_kill() - (tally.clock - struck)) < 0.2, "with how long it took from its first wound (%.2f s)" % tally.mean_kill())
	check(placed("coin.tscn").is_empty(), "and it drops no stars")
	var returned: bool = await within(func() -> bool: return tally.foes.has(WISP), PracticeTally.RESPAWN + 1.0)
	check(returned, "it comes back after %.0f s" % PracticeTally.RESPAWN)
	if returned:
		var again: Node2D = tally.foes[WISP] as Node2D
		var held: bool = await within(func() -> bool: return is_instance_valid(again) and not again.get_node("Mover").is_physics_processing(), PracticeTally.SETTLE + 0.5)
		check((again.get_node("Wound") as Wound).hp == Wound.hp_for(info.here.depth) and held, "whole, and held still again once it lands")


func _swap(tally: PracticeTally) -> void:
	print("another spell")
	var had: String = tally.spell
	Abilities.grant(player, &"nova")
	await frames(2)
	check(tally.spell.begins_with("nova I") and tally.dealt == 0 and tally.casts == 0, "taking up nova starts the count afresh")
	check(tally.history.size() == 1 and tally.history[0].begins_with(had), "keeping the slash's result: %s" % [tally.history])


func _sturdy(tally: PracticeTally) -> void:
	print("sturdy")
	var riso: RisoPrint = RisoPrint.instance
	(riso._options[&"practice_sturdy"] as OptionButton).item_selected.emit(1)
	await frames(3)
	var all_sturdy: bool = not tally.foes.is_empty() and tally.foes.values().all(func(n: Node) -> bool: return is_instance_valid(n) and (n.get_node("Wound") as Wound).hp == PracticeTally.STURDY_HP)
	check(PracticeTally.sturdy and all_sturdy, "made sturdy, every foe has %d health" % PracticeTally.STURDY_HP)
	(riso._options[&"practice_sturdy"] as OptionButton).item_selected.emit(0)
	(riso._options[&"practice_still"] as OptionButton).item_selected.emit(0)
	await frames(3)
	check(not PracticeTally.still and not PracticeTally.sturdy and (tally.foes.get(WISP) as Node).get_node("Mover").is_physics_processing(), "and back to live foes of their depth's health")
