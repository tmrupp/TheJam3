extends Node
class_name AstralProjection
## Astral projection, an ability learned at a shrine. Astral (Q, or the pad's left shoulder)
## leaves your body where you stand and sends you out as a glowing projection, untouchable by
## thorns and shots. Press it again, or get hurt, to snap back to your body. Let it run out and
## you stay where the projection is: the body is left behind for good. Tiers make it last longer.

@onready var player: Player = $"../"
@onready var main: Node = $"/root/Main"
@onready var visual: Sprite2D = $"../Sprite2D" # someday, this reference will break

var projection_timer: ActionTimer = ActionTimer.new(5.0, expire)

# holds a reference to the body left behind, if one exists currently
var false_player_origin: Sprite2D

var held_color: Color


## Adds the Astral action if the project does not define it.
static func ensure_input() -> void:
	if InputMap.has_action("Astral"):
		return
	InputMap.add_action("Astral")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_Q
	InputMap.action_add_event("Astral", key)
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_LEFT_SHOULDER
	InputMap.action_add_event("Astral", pad)


## Hurt while projected: snap back to the body instead of taking the hit.
func astral_hurt (_damage: int, _v: Vector2, _attacker: Node) -> void:
	end_projection(projection_timer)

func _ready() -> void:
	AstralProjection.ensure_input()
	player.astral_projection_signal.connect(toggle)
	player.elapse_ability_time_signal.connect(elapse)
	false_player_origin = null

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("Astral") and player.is_physics_processing():
		toggle()

func elapse(delta: float) -> void:
	projection_timer.elapse(delta)

func projecting() -> bool:
	return is_instance_valid(false_player_origin)

## Project, or snap back if already projecting.
func toggle() -> void:
	if projecting():
		end_projection(projection_timer)
	else:
		project()

func project() -> void:
	# Not until astral projection has been learned at a shrine.
	if Abilities.tier(player, &"astral") <= 0:
		return
	# Do not orphan the existing origin or overwrite its return state.
	if projecting():
		return
	player.visual_event.emit(&"projection_start", player.global_position)
	projection_timer.refresh()
	projection_timer.enable()

	# clone the visual: the body left behind
	false_player_origin = visual.duplicate()
	main.add_child(false_player_origin)
	false_player_origin.position = player.position
	false_player_origin.scale = player.scale

	# turn off own collision with bullets and spikes
	player.set_collision_layer_value(6, false)
	player.set_collision_layer_value(8, false)

	# override player's hurt ability with ours
	player.hurt_ability = astral_hurt

	# alter our own visual to look all projection-y
	held_color = visual.modulate
	visual.modulate = Color(0, 1, 1, 0.5)

## Snap back to the body.
func end_projection(_timer: ActionTimer) -> void:
	if not projecting():
		return
	player.visual_event.emit(&"projection_end", false_player_origin.global_position)
	player.position = false_player_origin.position
	player.velocity = Vector2.ZERO
	player.reset_fourier_motion()
	_finish()

## Ran out: stay where the projection is, and the body is gone.
func expire(_timer: ActionTimer) -> void:
	if not projecting():
		return
	player.visual_event.emit(&"projection_end", player.global_position)
	_finish()

func _finish() -> void:
	projection_timer.end()
	projection_timer.refresh()
	visual.modulate = held_color
	player.set_collision_layer_value(6, true)
	player.set_collision_layer_value(8, true)
	player.hurt_ability = player.normal_hurt
	false_player_origin.queue_free()
	false_player_origin = null
