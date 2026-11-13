class_name CryptTrial
extends Structure
## A trial in a crypt (Crypts): a pit, a crawl or a well.

## Which: &"pit", &"crawl" or &"well".
var kind: StringName = &""
## Its cells.
var rect: Rect2i = Rect2i()


## One laid, holding what it is first laid with.
static func make(kind_: StringName, rect_: Rect2i) -> CryptTrial:
	var it: CryptTrial = CryptTrial.new()
	it.kind = kind_
	it.rect = rect_
	return it
