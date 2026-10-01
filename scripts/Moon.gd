extends Area2D
## A moon: touching it gives your dash back if you have used it, then it wanes for a few seconds
## and returns. Never used up, so a level's moons are always where they were.

const WANE: float = 2.5

@onready var player: Player = $"/root/Main/Player"

## Seconds until it is full again (0 when ready).
var waning: float = 0.0


func is_full() -> bool:
	return waning <= 0.0


func setup(_info: MapInfo, _v: Vector2i) -> void:
	pass


func touch(other: Node) -> void:
	if other != player or not is_full() or not player.dash.acted:
		return
	player.dash.refresh()
	waning = WANE
	RisoFx.burst(&"gain", global_position, Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])


func _physics_process(delta: float) -> void:
	if waning > 0.0:
		waning = maxf(0.0, waning - delta)
		# Back while the wizard is still inside it: offer the reset again.
		if waning == 0.0 and overlaps_body(player):
			touch(player)


func _ready() -> void:
	body_entered.connect(touch)
