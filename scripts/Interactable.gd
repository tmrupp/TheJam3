extends Node
class_name Interactable
## Something the player can use with Discover (E) while touching it. Only one is focused at a
## time: of those the player is touching and that are available, the nearest. Only it shows its
## prompt and answers the key, so neighbours that overlap (the shrine's stations) never both act.

@onready var player: Player = $"/root/Main/Player"
signal interacted
@onready var sprite: Sprite2D = $Sprite2D

var touching: bool = false
var available: bool = true:
	set(value):
		available = value
		if is_instance_valid(sprite):
			sprite.visible = is_focused()
func untouch(other: Node) -> void:
	if (other == player and other.get_parent() != null):
		touching = false

func touch(other: Node) -> void:
	if (other == player and other.get_parent() != null):
		touching = true


## The interactable the player would use now, or null.
static func focused(tree: SceneTree) -> Node:
	var best: Node = null
	var best_d: float = INF
	for node: Node in tree.get_nodes_in_group(&"interactables"):
		var it: Interactable = node as Interactable
		if it == null or not it.touching or not it.available or it.player == null:
			continue
		# Mid-way through a portal (see portal.gd), nothing can be used.
		if it.player.has_meta(&"portal_trip"):
			return null
		var at: Node2D = it.get_parent() as Node2D
		var d: float = at.global_position.distance_squared_to(it.player.global_position) if at != null else INF
		if d < best_d:
			best_d = d
			best = it
	return best


func is_focused() -> bool:
	return touching and available and is_inside_tree() and Interactable.focused(get_tree()) == self


func _process(_delta: float) -> void:
	sprite.visible = is_focused()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Discover") and is_focused():
		# Used up here, so nothing else answers this press (say, at a portal's far end).
		get_viewport().set_input_as_handled()
		interacted.emit()

func _ready() -> void:
	add_to_group(&"interactables")
	get_parent().connect("body_entered", touch)
	get_parent().connect("body_exited", untouch)
	sprite.visible = false
	sprite.global_scale = Vector2.ONE*4
	sprite.position += Vector2.UP*20
