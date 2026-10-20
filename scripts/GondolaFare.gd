class_name GondolaFare
extends Area2D
## A gondola's fare box (Gondola), one on each side of the car, so a toll gate shutting a station
## (TollGate) can be paid from inside the car: while the car stands at a station shut by a toll gate
## on this side, the wizard standing in this half of the car pays it here (interact), and the gate
## lifts as if paid from the landing. Standing in the middle of the car or the other half, the
## lever is nearer, and works the car as before. Its prompt shows the price.

## The gondola it belongs to, and the side of the car it is on (-1 left, +1 right).
var gondola: Gondola
var side: int = 1

@onready var _box: Interactable = $Interactable as Interactable
## The station last looked up, and the toll gate found shutting it (null for none).
var _looked: int = -2
var _gate: TollGate = null


## The toll gate it pays now: the one shutting the station the car stands at, if that station is on
## this side; else null.
func toll() -> TollGate:
	if gondola == null or gondola.running or gondola.at_station < 0 or gondola.inner[gondola.at_station] != side:
		return null
	if gondola.at_station != _looked:
		_looked = gondola.at_station
		_gate = null
		var cell: Vector2i = gondola.gates[_looked]
		for node: Node in gondola.map_info.map_elements.get_children():
			var gate: TollGate = node as TollGate
			if gate != null and gate.get_meta(&"cell", Vector2i(-1, -1)) == cell:
				_gate = gate
	if _gate == null or not is_instance_valid(_gate) or _gate.is_queued_for_deletion():
		return null
	return _gate


func interaction_hint() -> Dictionary:
	var gate: TollGate = toll()
	return {"text": str(gate.price)} if gate != null else {}


func _ready() -> void:
	_box.interacted.connect(func() -> void:
		var gate: TollGate = toll()
		if gate != null:
			gate.pay())


func _process(_delta: float) -> void:
	_box.available = gondola != null and gondola.has_rider() and toll() != null
