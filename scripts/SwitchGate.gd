extends StaticBody2D
## A gate across a corridor, lifted for good by its switch elsewhere in the level (Switch). It
## has no lock: nothing opens it but the switch. Once open, the level record keeps it open.

var map_info: MapInfo
## The cell of the switch that opens it.
var switch_cell: Vector2i = Vector2i(-1, -1)


func setup(info: MapInfo, _v: Vector2i, lever: Vector2i) -> void:
	map_info = info
	switch_cell = lever


func open() -> void:
	if is_queued_for_deletion():
		return
	RisoPrint.door_opened(self)
	if map_info != null:
		map_info.mark_opened(self)
	queue_free()


func _ready() -> void:
	# The printed portcullis shows a switch emblem where a door shows its lock (RisoProp).
	set_meta(&"key_color", -1)
