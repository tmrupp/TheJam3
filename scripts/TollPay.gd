extends Area2D
## Where the wizard pays a toll gate (TollGate), its parent: a little wider than the gate, so it can
## be paid from the landing or from the car beside it. Its prompt shows the price.

@onready var gate: TollGate = get_parent() as TollGate


func interaction_hint() -> Dictionary:
	return {"text": str(gate.price)} if gate != null else {}


func _ready() -> void:
	($Interactable as Interactable).interacted.connect(func() -> void: gate.pay())
