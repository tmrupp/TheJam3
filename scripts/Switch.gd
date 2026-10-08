extends Area2D
class_name Switch
## A switch: interact with it to turn it on or off. On, its gate is lifted (SwitchGate), its lift
## runs (MovingPlatform) and the bell or vane chained to it is free (Bell); off, the gate drops
## again (once the wizard is clear of it), the lift stops where it is and the bell is chained up
## again (a bridge it has already laid stays). Some start on (START_ON_SHARE, dealt by the level
## seed and the switch's cell, with no RNG draw). A hex bolt turns one on but never off, so a gate
## can never be shot shut from its far side with the wizard beyond it. The level record keeps each
## switch as it was last left (LevelRecord.switched: cell -> on).

## The share of switches that start on, and the salt for the level seed when dealing them.
const START_ON_SHARE: float = 0.33
const START_DEAL: int = 9200

@onready var player: Player = Stage.player()

var map_info: MapInfo
## The cell of what it works: the gate it lifts, the lift it runs, or the bell it frees.
var gate_cell: Vector2i = Vector2i(-1, -1)


func setup(info: MapInfo, _v: Vector2i, gate: Vector2i) -> void:
	map_info = info
	gate_cell = gate


## Whether the switch at `cell` of level `w` starts on. A gondola station's never does: all but one
## of the circuit's stations start shut (Gondola).
static func starts_on(w: LevelGen, cell: Vector2i) -> bool:
	var target: Variant = w.get_cell(cell).extra_info if w.is_valid(cell) else null
	if target is Vector2i and (w.circuit.get("gates", []) as Array).has(target):
		return false
	var roll: int = posmod(Rules.level_seed(w.seed_for_colors, START_DEAL + cell.x * 977 + cell.y), 1000)
	return float(roll) / 1000.0 < START_ON_SHARE


## Whether the switch at `cell` of level `w` is on, as its record `rec` leaves it (as last turned,
## else as it started).
static func is_on_in(w: LevelGen, rec: LevelRecord, cell: Vector2i) -> bool:
	if rec.switched.has(cell):
		return bool(rec.switched[cell])
	return starts_on(w, cell)


## The cell of the switch in level `w` that works the thing at `target`, or (-1, -1).
static func of(w: LevelGen, target: Vector2i) -> Vector2i:
	for v: Vector2i in w.objects:
		var cell: LevelGen.Cell = w.get_cell(v)
		if cell.type == LevelGen.Type.SWITCH and cell.extra_info is Vector2i and cell.extra_info == target:
			return v
	return Vector2i(-1, -1)


## Whether it is on.
func is_on() -> bool:
	return map_info != null and has_meta(&"cell") and map_info.switch_on(get_meta(&"cell"))


## Turn it over: on if it was off, off if it was on, and what it works with it.
func flip() -> void:
	if map_info == null or not has_meta(&"cell"):
		return
	var on: bool = not is_on()
	map_info.set_switch(get_meta(&"cell"), on)
	if is_instance_valid(map_info.map_elements):
		for node: Node in map_info.map_elements.get_children():
			if node.get_meta(&"cell", null) != gate_cell:
				continue
			if node is SwitchGate:
				(node as SwitchGate).set_up(on)
			elif node is MovingPlatform:
				if on:
					(node as MovingPlatform).run()
				else:
					(node as MovingPlatform).halt()
			elif node is Bell:
				# A bell or vane chained to this switch (Vane extends Bell): its chain comes off, or
				# back on.
				(node as Bell).switched(on)
	if on:
		RisoFx.burst(&"gain", global_position + Vector2(0, -30), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	else:
		RisoFx.burst(&"hit", global_position + Vector2(0, -30), Vector2.UP, [RisoPrint.BLUE, RisoPrint.NIGHT])


## A hex bolt turns it on, never off (HexBolt strikes everything in the hex_target group).
func hex_hit(_damage: int, _dir: Vector2) -> void:
	if not is_on():
		flip()


func _ready() -> void:
	add_to_group(&"hex_target")
	$Interactable.interacted.connect(flip)
