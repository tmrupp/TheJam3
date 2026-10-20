extends TestKit
## Prints the crypts of a few cemetery levels as JSON, cell by cell, for drawing them elsewhere
## (the darkness write-up): # rock, . air, S sun block, H shade block, ^ thorns, F font, f dry font
## (none: fonts are only dry in play), O ossuary door, * star or cluster, K skeleton, G light gate.
## godot --headless --path . --script res://tests/dump_crypts.gd -- 5,8 3,6
## suite: full


func run() -> void:
	var places: Array[Vector2i] = []
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split(",")
		if parts.size() == 2:
			places.append(Vector2i(int(parts[0]), int(parts[1])))
	var out: Array = []
	for at: Vector2i in places:
		var w: LevelGen = build(at)
		if w == null:
			continue
		for crypt: Dictionary in w.crypts:
			var box: Rect2i = crypt["box"]
			var rows: Array[String] = []
			for y: int in range(box.position.y - 1, box.end.y + 1):
				var row: String = ""
				for x: int in range(box.position.x - 3, box.end.x + 3):
					row += _char(w, Vector2i(x, y))
				rows.append(row)
			out.append({"place": [at.x, at.y], "fontless": Rules.fontless_at(at), "rows": rows})
	print("JSON ", JSON.stringify(out))
	finish()


func _char(w: LevelGen, v: Vector2i) -> String:
	if not w.is_valid(v):
		return "#"
	var cell: LevelGen.Cell = w.get_cell(v)
	match cell.type:
		LevelGen.Type.GROUND:
			return "#"
		LevelGen.Type.PHASE_BLOCK:
			return "S" if bool(cell.extra_info) else "H"
		LevelGen.Type.SPIKES:
			return "^"
		LevelGen.Type.SNUFFER:
			return "F"
		LevelGen.Type.OSSUARY_DOOR:
			return "O"
		LevelGen.Type.COIN, LevelGen.Type.CLUSTER:
			return "*"
		LevelGen.Type.SKELETON:
			return "K"
		LevelGen.Type.LIGHT_GATE:
			return "G"
	return "."
