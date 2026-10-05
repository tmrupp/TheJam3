extends Node
class_name AstralProjection
## Astral projection, a spell learned at a shrine. Spell (Q, or the pad's X) leaves your body
## where you stand and sends you out as a glowing projection, untouchable by thorns and shots. It
## floats wherever the stick points, through rock and anything else solid (see Player.phasing),
## and drifting into a secret room's rock opens the room. Hits cannot hurt or interrupt it.
## Press Spell again to snap
## back to your body. Let it run out and you stay where the projection is: the body is left
## behind for good. Ending it inside rock, either way, costs a heart and puts you back in your
## body. Tiers make it last longer.

@onready var player: Player = $"../"
@onready var main: Node = $"/root/Main"
@onready var visual: Sprite2D = $"../Sprite2D" # someday, this reference will break

## A brief projection, growing from 1.5 to 3 seconds with its four tiers.
const PROJECTION_TIME: float = 1.5
const TIER_TIME: float = 0.5
## The projection prints with less than half its usual ink, letting the scene show through.
const PROJECTION_COVER: float = 0.4
var projection_timer: ActionTimer = ActionTimer.new(PROJECTION_TIME, expire)

# holds a reference to the body left behind, if one exists currently
var false_player_origin: Sprite2D

var held_color: Color


## Hits pass through the projection without ending it.
func astral_hurt (_damage: int, _v: Vector2, _attacker: Node) -> void:
	pass

func _ready() -> void:
	player.astral_projection_signal.connect(toggle)
	player.elapse_ability_time_signal.connect(elapse)
	false_player_origin = null

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

	# drift through anything solid (see Player.phasing)
	player.phasing = true
	player.velocity = Vector2.ZERO
	player.set_collision_mask_value(3, false)

	# override player's hurt ability with ours
	player.hurt_ability = astral_hurt

	# alter our own visual to look all projection-y
	held_color = visual.modulate
	visual.modulate = Color(0, 1, 1, PROJECTION_COVER)

## Snap back to the body (a heart lost if the projection was inside rock).
func end_projection(_timer: ActionTimer) -> void:
	if not projecting():
		return
	var stuck: bool = _in_rock()
	player.visual_event.emit(&"projection_end", false_player_origin.global_position)
	player.position = false_player_origin.position
	player.velocity = Vector2.ZERO
	player.reset_fourier_motion()
	_finish()
	if stuck:
		_rock_hurts()

## Ran out: stay where the projection is, and the body is gone; unless it ran out inside rock,
## when it costs a heart and you are back in your body.
func expire(_timer: ActionTimer) -> void:
	if not projecting():
		return
	if _in_rock():
		end_projection(projection_timer)
		return
	player.visual_event.emit(&"projection_end", player.global_position)
	_finish()

## Whether the projection is inside rock (or anything else solid).
func _in_rock() -> bool:
	return MapInfo.instance != null and MapInfo.instance.solid_at(player.global_position)

func _rock_hurts() -> void:
	player.end_invulnerable()
	player.hurt(-1, Vector2.ZERO, null)

func _finish() -> void:
	projection_timer.end()
	projection_timer.refresh()
	visual.modulate = held_color
	player.set_collision_layer_value(6, true)
	player.set_collision_layer_value(8, true)
	player.phasing = false
	player.set_collision_mask_value(3, true)
	player.hurt_ability = player.normal_hurt
	false_player_origin.queue_free()
	false_player_origin = null
