extends RisoProp
## A thorn vine on its own in a garden wall (GardenVine), printed as the bramble prints its vines
## (Bramble.ink_vine): resting, a dark bud at its root; warning, pink shoots poking out of the rock;
## out, a pink stem with thorns along it and a hooked tip, writhing.


## The vine it dresses.
var vine: GardenVine:
	get:
		return host as GardenVine


func _draw_art() -> void:
	var v: GardenVine = vine
	if v == null:
		return
	Bramble.ink_vine(ink, Transform2D(v.way.angle(), to_local(v.global_position)), v, t)


## It writhes and lashes: printed every frame.
func every_frame() -> bool:
	return true
