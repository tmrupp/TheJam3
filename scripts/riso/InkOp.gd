extends Node2D
## One ordered print operation on one or more ink plates: either lay ink (coverage in alpha)
## or lift ink (multiply blend, so the plate keeps 1 - coverage of what was there).

var polys: Array[PackedVector2Array] = []
var alphas: Array[PackedFloat32Array] = []
var cover: float = 1.0
var lift: bool = false


func _draw() -> void:
	for i: int in range(polys.size()):
		var poly: PackedVector2Array = polys[i]
		if poly.size() < 3 or absf(_area(poly)) < 1.0:
			continue
		if i < alphas.size() and alphas[i].size() == poly.size():
			var colors: PackedColorArray = PackedColorArray()
			for a: float in alphas[i]:
				colors.append(Color(1, 1, 1, 1.0 - a if lift else a))
			draw_polygon(poly, colors)
		else:
			draw_colored_polygon(poly, Color(1, 1, 1, 1.0 - cover if lift else cover))


## Signed shoelace area; shapes under a pixel are skipped (they cannot triangulate and print nothing).
func _area(poly: PackedVector2Array) -> float:
	var a: float = 0.0
	var n: int = poly.size()
	for i: int in range(n):
		a += poly[i].x * poly[(i + 1) % n].y - poly[(i + 1) % n].x * poly[i].y
	return a * 0.5
