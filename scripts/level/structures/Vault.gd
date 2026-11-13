class_name Vault
extends Structure
## A vault (Vaults): a walled room behind a locked door.

## Its cells.
var room: Array = []
## Its door's cell.
var door: Vector2i = Structure.NONE
## The key colour its door takes.
var color: int = 0


## One laid, holding what it is first laid with.
static func make(room_: Array, door_: Vector2i, color_: int) -> Vault:
	var it: Vault = Vault.new()
	it.room = room_
	it.door = door_
	it.color = color_
	return it
