class_name SecretRoom
extends Structure
## A secret room (Secrets): sealed in the rock behind a false wall.

## Its cells.
var room: Array = []
## The cells of its way in, the false wall's.
var entrance: Array = []
## What it holds: each [cell, type, extra].
var rewards: Array = []


## One laid, holding what it is first laid with.
static func make(room_: Array, entrance_: Array, rewards_: Array) -> SecretRoom:
	var it: SecretRoom = SecretRoom.new()
	it.room = room_
	it.entrance = entrance_
	it.rewards = rewards_
	return it
