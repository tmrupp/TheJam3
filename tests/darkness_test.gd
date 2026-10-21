extends TestKit
## The cemetery's darkness (docs/DEEPER_PLAN.md, "Darkness charges"). Laid out: sun and shade blocks
## stand only inside the crypts or in their doorways, a crypt's stairs turned to blocks take turns, a shade floor lies over
## thorns, ossuary doors shut only a second crypt's doorways and want Rules.ossuary_fill, a level
## dealt no fonts has none, and all of it the same every time. In play: outside the cemetery a dash
## spends darkness as it does in the cemetery; a font gives Snuffer.CHARGES and stays dry through a death and a revisit; a death
## drops the charges into the ghost and taking it back returns them; a dash out of the dark flares; a
## sun block bears a lit wizard and drops a dark one (a shade block the other way about), and turns
## solid round them only once they are clear; an ossuary door keeps what is poured and opens once
## it has its fill.
## godot --headless --path . --script res://tests/darkness_test.gd

## Worlds looked through for a level to play in, and the band's rows (counting from its first).
const WORLDS: Array[int] = [41, 3, 7, 28, 99, 12, 5, 64]
const ROWS: Array[int] = [1, 2, 3, 4]


func run() -> void:
	var at: Variant = generation()
	if at != null:
		await play(at)
	RunState.delete_save()
	finish()


## Look over the cemetery's levels; the first with fonts, a sun block with room under it and an
## ossuary door is played (null if none).
func generation() -> Variant:
	print("generation")
	var chosen: Variant = null
	var blocked: int = 0
	var shade_floors: int = 0
	var stairs_seen: int = 0
	var doors_seen: int = 0
	var looked: int = 0
	for x: int in WORLDS:
		for k: int in ROWS:
			var at: Vector2i = Vector2i(x, NextWorldDef.band_row(&"cemetery", k))
			var w: LevelGen = build(at)
			if w == null:
				continue
			looked += 1
			var blocks: Array[Vector2i] = w.objects_of(LevelGen.Type.PHASE_BLOCK)
			if not blocks.is_empty():
				blocked += 1
			var doorways: Dictionary = {}
			for crypt: Dictionary in w.crypts:
				for d: Vector2i in crypt["doors"]:
					doorways[d] = true
			check(blocks.all(func(v: Vector2i) -> bool: return doorways.has(v) or (w.interiors.has(v) and w.structures.get(v, &"") == &"crypt")), "%s: its %d blocks all stand inside its crypts or in their doorways" % [at, blocks.size()])
			if Rules.fontless_at(at):
				var plain: int = w.objects_of(LevelGen.Type.SNUFFER).filter(func(v: Vector2i) -> bool: return Snuffer.capacity(w, v) == Snuffer.CHARGES).size()
				check_eq(plain, 0, "%s: dealt no fonts, it has none (but a crypt's large one, its prize)" % at)
			# A crypt's stairs, where they were turned to blocks, take turns up the climb.
			for crypt: Dictionary in w.crypts:
				var steps: Array[Vector2i] = []
				for s: Vector2i in crypt["stairs"]:
					if w.get_cell(s).type == LevelGen.Type.PHASE_BLOCK:
						steps.append(s)
				if steps.size() < 2:
					continue
				stairs_seen += 1
				steps.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y or (a.y == b.y and a.x < b.x))
				var turns: bool = true
				for i: int in range(1, steps.size()):
					turns = turns and bool(w.get_cell(steps[i]).extra_info) != bool(w.get_cell(steps[i - 1]).extra_info)
				check(turns, "%s: %d stairs turned to blocks, sun and shade by turns" % [at, steps.size()])
			for v: Vector2i in blocks:
				if not bool(w.get_cell(v).extra_info) and w.get_cell(v + Vector2i.DOWN).type == LevelGen.Type.SPIKES:
					shade_floors += 1
			var doors: Array[Vector2i] = w.objects_of(LevelGen.Type.OSSUARY_DOOR)
			if not doors.is_empty():
				doors_seen += 1
				var second: Array[Vector2i] = []
				if w.crypts.size() >= 2:
					second = w.crypts[1]["doors"]
				check(Rules.ossuary_at(at) and doors.all(func(d: Vector2i) -> bool: return second.has(d) and int((w.get_cell(d).extra_info as Array)[1]) == Rules.ossuary_fill(at.y)), "%s: %d ossuary door(s), on its second crypt's doorways, wanting %d" % [at, doors.size(), Rules.ossuary_fill(at.y)])
			if chosen == null and not doors.is_empty() and count_of(w, LevelGen.Type.SNUFFER) > 0 and _bearing(w) != null:
				chosen = at
				var again: LevelGen = build(at)
				check(w.objects == again.objects and w.grounds == again.grounds, "%s: the same every time" % at)
	check(blocked * 2 >= looked, "%d of %d levels have blocks in their crypts" % [blocked, looked])
	check(stairs_seen >= 1 and shade_floors >= 2 and doors_seen >= 1, "stairs turned to blocks in %d crypt(s), %d shade blocks over thorns, ossuary doors in %d level(s)" % [stairs_seen, shade_floors, doors_seen])
	check(chosen != null, "a level to play in: %s" % [chosen])
	return chosen


## A sun block in `w` with room over it to stand and under it to fall, or null.
func _bearing(w: LevelGen) -> Variant:
	for v: Vector2i in w.objects_of(LevelGen.Type.PHASE_BLOCK):
		var up: LevelGen.Cell = w.get_cell(v + Vector2i.UP)
		var down: LevelGen.Cell = w.get_cell(v + Vector2i.DOWN)
		if bool(w.get_cell(v).extra_info) and up.type in [LevelGen.Type.EMPTY, LevelGen.Type.COIN] and down.type in [LevelGen.Type.EMPTY, LevelGen.Type.COIN] and w.get_cell(v + Vector2i.DOWN * 2).type in [LevelGen.Type.EMPTY, LevelGen.Type.COIN, LevelGen.Type.GROUND]:
			return v
	return null


func play(at: Vector2i) -> void:
	await boot()
	player.set_physics_process(false)
	print("in the garden")
	info.snuff(player.global_position)
	info.run.dark_charges = Snuffer.CHARGES
	await _dash()
	check(info.flame_lit() and info.run.dark_charges == Snuffer.CHARGES - 1, "outside the cemetery too, a dash out of the dark lights the flame and spends a charge")
	await _dash()
	check(not info.flame_lit() and info.run.dark_charges == Snuffer.CHARGES - 1, "and a dash while lit puts it out again")
	info.relight()
	info.run.dark_charges = 0

	print("a font, in %s" % at)
	await _go(at)
	var fonts: Array[Node] = placed("snuffer.tscn")
	var font: Snuffer = fonts[0] as Snuffer
	var cell: Vector2i = font.cell
	_near(font)
	font.use()
	check(info.run.dark_charges == Snuffer.CHARGES and font.dry() and not info.flame_lit(), "a font gives %d charges, puts the flame out and is dry" % Snuffer.CHARGES)
	await _dash()
	check(info.flame_lit() and info.run.dark_charges == Snuffer.CHARGES - 1, "a dash out of the dark spends one")
	check(await within(func() -> bool: return Lamplight.carried_reach(info) > RisoLight.CARRIED_REACH * 1.4, 0.2), "and the spent charge flares: the flame reaches further")
	await within(func() -> bool: return false, Lamplight.FLARE_TIME + 0.1)
	check_eq(Lamplight.carried_reach(info), RisoLight.CARRIED_REACH, "the flare dies down")

	print("a death")
	var carried: int = info.run.dark_charges
	player.health.modify_health(-player.health.health)
	check(info.run.dark_charges == 0 and info.run.ghost_charges == carried, "a death drops the %d charges carried into the ghost" % carried)
	await settle()
	player.set_physics_process(false)
	await _go(at)
	font = _font_at(cell)
	check(font != null and font.dry() and not font.can_snuff(), "after the death, coming back, the font is still dry")
	info.recover_ghost()
	check(info.run.dark_charges == carried and info.run.ghost_charges == 0, "taking the ghost back returns them")

	print("sun and shade blocks")
	var light: Checkpoint = placed("checkpoint.tscn")[0] as Checkpoint
	info.light_lantern(light)
	var v: Vector2i = _bearing(info.world)
	var block: PhaseBlock = _block_at(v)
	player.global_position = info.cell_position(v + Vector2i.UP)
	info.loader.wake_around(player.global_position)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	await within(func() -> bool: return false, 0.5)
	check(block.solid() and info.cell_at(player.global_position) == v + Vector2i.UP, "lit, a sun block bears the wizard")
	info.snuff(player.global_position)
	check(await within(func() -> bool: return player.global_position.y > info.cell_position(v).y, 1.5), "dark, it drops them through")
	player.set_physics_process(false)
	player.global_position = info.cell_position(v)
	await physics_frame
	info.relight()
	await physics_frame
	await physics_frame
	check(block.bears() and not block.solid(), "lit with the wizard inside it, it waits")
	player.global_position = info.cell_position(v + Vector2i.UP * 3)
	await physics_frame
	await physics_frame
	check(block.solid(), "and turns solid once they are clear")
	var shade: Array[Node] = placed("phase_block.tscn").filter(func(n: Node) -> bool: return not (n as PhaseBlock).sun)
	if not shade.is_empty():
		var other: PhaseBlock = shade[0] as PhaseBlock
		check(not other.bears(), "lit, a shade block is a ghost")
		info.snuff(player.global_position)
		check(other.bears(), "dark, it bears them")
		info.relight()

	print("an ossuary door")
	var door: OssuaryDoor = placed("ossuary_door.tscn")[0] as OssuaryDoor
	var doorway: Vector2i = door.cell
	info.run.dark_charges = 0
	check(not door.can_pour() and info.solid_at(info.cell_position(doorway)), "shut, and nothing to pour with no darkness carried")
	info.run.dark_charges = 2
	door.pour()
	check(door.poured() == 2 and info.run.dark_charges == 0 and not door.is_open() and info.solid_at(info.cell_position(doorway)), "it drinks the 2 charges carried, and stays shut")
	await _go(at)
	door = _door_at(doorway)
	check(door != null and door.poured() == 2, "coming back, it keeps what was poured")
	info.run.dark_charges = door.fill + 3
	door.pour()
	check(door.is_open() and info.run.dark_charges == 5 and not info.solid_at(info.cell_position(doorway)), "fed its fill, it opens, and takes no more than it wants")
	var col: CollisionShape2D = door.get_node("CollisionShape2D") as CollisionShape2D
	check(await within(func() -> bool: return col.disabled, 0.5), "and lets the wizard through")
	await _go(at)
	door = _door_at(doorway)
	check(door != null and door.is_open() and door.sunk >= 1.0, "it stays open")


## Play the level at `at`, arriving by its way back.
func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)


## Stand beside `node`, its chunk awake.
func _near(node: Node2D) -> void:
	player.global_position = node.global_position + Vector2(-70, 0)
	info.loader.wake_around(player.global_position)


func _font_at(v: Vector2i) -> Snuffer:
	for node: Node in placed("snuffer.tscn"):
		if (node as Snuffer).cell == v:
			return node as Snuffer
	return null


func _block_at(v: Vector2i) -> PhaseBlock:
	for node: Node in placed("phase_block.tscn"):
		if (node as PhaseBlock).cell == v:
			return node as PhaseBlock
	return null


func _door_at(v: Vector2i) -> OssuaryDoor:
	for node: Node in placed("ossuary_door.tscn"):
		if (node as OssuaryDoor).cell == v:
			return node as OssuaryDoor
	return null


## Dash once (the wizard's physics on only for it).
func _dash() -> void:
	player.dash.acted = false
	player.dash_rest = 0.0
	player.set_physics_process(true)
	Input.action_press("Dash")
	await physics_frame
	await physics_frame
	Input.action_release("Dash")
	player.set_physics_process(false)
