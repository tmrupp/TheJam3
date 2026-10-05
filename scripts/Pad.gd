extends Area2D
## A jump pad, in sky levels (MapInfo.World.populate_sky): a springy cushion of cloud on a floor,
## placed below a ledge or shelf. Land on it, or walk onto it, and it throws the wizard about
## MapInfo.World.PAD_REACH cells up (letting go of Jump does not cut it short) and gives the dash
## back.

const LAUNCH: float = -1080.0
## Seconds before it throws again (so one landing throws once).
const REST: float = 0.25

## Seconds since it last threw (the art squashes and springs back).
var since_launch: float = 99.0


func _physics_process(delta: float) -> void:
	since_launch += delta
	if since_launch < REST:
		return
	for body: Node2D in get_overlapping_bodies():
		var p: Player = body as Player
		if p != null and not p.phasing and p.velocity.y >= -60.0:
			launch(p)
			return


func launch(p: Player) -> void:
	since_launch = 0.0
	p.velocity.y = LAUNCH
	# Not a jump: letting go of Jump does not cut the throw short.
	p.jumping = false
	p.coyote.end()
	p.dash.refresh()
	p.jumps = p.MAX_JUMPS
	p.visual_event.emit(&"jump", p.global_position)
	RisoFx.burst(&"gain", global_position + Vector2(0, 40), Vector2.UP, [RisoPrint.BLUE, RisoPrint.ACCENT])
