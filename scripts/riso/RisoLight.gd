extends Node2D
class_name RisoLight
## Lantern light. Your respawn lantern throws a warm pool that lifts the night ink off the rock
## and the sky around it, flickering softly, so the place you return to reads as a destination.
## Every other lantern gives a faint glow. Printed above the terrain and decor, under the props.

var lanterns: Array[Node2D] = []
var ink: InkCanvas
var half: float = 64.0
var t: float = 0.0


func _ready() -> void:
	z_index = -12
	z_as_relative = false
	add_to_group(&"riso_art")
	visible = RisoPrint.is_on()
	ink = InkCanvas.new()
	add_child(ink)


func rebuild(info: MapInfo) -> void:
	lanterns.clear()
	half = float(info.tile_map.tile_set.tile_size.y) * info.tile_map.global_scale.y * 0.5
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == "checkpoint.tscn" and not node.is_queued_for_deletion():
			lanterns.append(node as Node2D)


## Where a lantern's glass hangs (its prop draws the glass there).
func glass(lantern: Node2D, info: MapInfo) -> Vector2:
	var floor_y: float = info.cell_position(info.cell_at(lantern.global_position)).y + half
	return Vector2(lantern.global_position.x + 30.0, floor_y - 72.0)


func _process(delta: float) -> void:
	t += delta
	var info: MapInfo = MapInfo.instance
	var cam: Camera2D = get_viewport().get_camera_2d()
	ink.begin()
	if info == null or info.world == null or cam == null:
		ink.finish()
		return
	var view: Rect2 = RisoLight.view_rect(self, cam).grow(420.0)
	var faint: Array[PackedVector2Array] = []
	for lantern: Node2D in lanterns:
		if not is_instance_valid(lantern) or lantern.is_queued_for_deletion():
			continue
		var at: Vector2 = glass(lantern, info)
		if not view.has_point(at):
			continue
		if info.is_respawn_lantern(lantern):
			var f: float = 1.0 + 0.035 * sin(t * 3.1) * sin(t * 1.7 + 0.6)
			for ring: Array in [[380.0, 0.16], [250.0, 0.18], [140.0, 0.22]]:
				ink.lift_ink([RisoPrint.NIGHT], float(ring[1]), [RisoShapes.circle(at, float(ring[0]) * f, 40)])
		else:
			faint.append(RisoShapes.circle(at, 110.0, 28))
	ink.lift_ink([RisoPrint.NIGHT], 0.09, faint)
	ink.finish()


## The camera's view in world space.
static func view_rect(node: CanvasItem, cam: Camera2D) -> Rect2:
	var base: Vector2 = Vector2(node.get_window().content_scale_size)
	if base.x < 1.0:
		base = Vector2(320, 180)
	var size: Vector2 = base / cam.zoom
	return Rect2(cam.get_screen_center_position() - size * 0.5, size)
