extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$"..".climable = true
	
func _exit_tree() -> void:
	$"..".climable = false
