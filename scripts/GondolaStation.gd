class_name GondolaStation
extends Area2D
## One of a gondola's stations (Gondola), made by the gondola: it sits in the station's doorway, and
## the wizard standing in the doorway calls the car there with its call switch (interact), once the
## station is open and while the car is somewhere else. Its art (StationArt) frames the doorway as a
## station: a board over it with the station's number, a boarding step across it and the call
## switch on its frame by the car.

## The gondola it belongs to, which of its stations it is, and the way its landing faces from the
## doorway (+1 right, -1 left).
var gondola: Gondola
var index: int = 0
var inner: int = 1

@onready var _post: Interactable = $Interactable as Interactable


func interaction_hint() -> Dictionary:
	return {"text": "call"}


func _ready() -> void:
	_post.interacted.connect(func() -> void: gondola.call_to(index))


func _process(_delta: float) -> void:
	# Its gondola gone (its level unloaded) or left behind: nothing to call.
	if gondola == null or not is_instance_valid(gondola):
		queue_free()
		return
	_post.available = gondola.may_call(index)


## Whether the car is on its way here, called.
func called() -> bool:
	return gondola != null and is_instance_valid(gondola) and gondola.running and not gondola.ridden and gondola.bound_for == index
