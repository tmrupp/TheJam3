extends WaveFunctionCollapse

## Collapses the terrain for one level. A failed collapse retries on a seed derived from the
## level seed and the attempt, so the same (seed, depth) always gives the same level. A place whose
## archetype builds round small insides of their own (Archetype.patches: the cemetery's crypts)
## has each collapsed too, after the terrain, on seeds of their own, and handed over after the
## terrain's columns as {"patches": [each inside, or [] if it never settled]} (LevelGen reads it).
## An inside may be collapsed by slices ("slices": &"columns" or &"rows", the crypts' trials): each
## column (or row) of its sample is one colour of a strip three cells thick, the strip is collapsed,
## and each colour of what settles is that column (or row) again. So a sample whose rows (or columns)
## must stay in their order keeps them, and only the order of its columns (or rows) is collapsed,
## three at a time, which settles where the whole picture seldom would.

## Salt for the level seed when collapsing each inside (and each retry).
const PATCH_DEAL: int = 6200
const PATCH_TRIES: int = 16
func generate_level(def: NextWorldDef) -> Array:
	texture = load(def.region)
	output_size = def.size
	symmetry = def.symmetry
	var map: Array = []
	for attempt: int in range(32):
		set_seed(def.gen_seed if attempt == 0 else Rules.level_seed(def.gen_seed, 1000 + attempt))
		map = collapse()
		if len(map) > 0:
			break
	if map.is_empty():
		# The collapse never settled: whatever the place falls back to ([] for a level).
		return def.fallback()
	var specs: Array[Dictionary] = def.patches()
	if specs.is_empty():
		return map
	var patches: Array = []
	for i: int in range(specs.size()):
		var sample: Texture2D = load(String(specs[i]["sample"]))
		var size: Vector2i = specs[i]["size"]
		var slices: StringName = StringName(specs[i].get("slices", &""))
		var kinds: Array = []
		texture = sample
		output_size = size
		if slices != &"":
			var strip: Array = _strip(sample.get_image(), slices == &"columns")
			texture = ImageTexture.create_from_image(strip[0])
			kinds = strip[1]
			output_size = Vector2i(size.x, STRIP) if slices == &"columns" else Vector2i(STRIP, size.y)
		symmetry = 1
		var inside: Array = []
		for attempt: int in range(PATCH_TRIES):
			set_seed(Rules.level_seed(def.gen_seed, PATCH_DEAL + i * 100 + attempt))
			inside = collapse()
			if len(inside) > 0:
				break
		if slices != &"" and not inside.is_empty():
			inside = _unstrip(inside, kinds, size, slices == &"columns")
		patches.append(inside)
	map.append({"patches": patches})
	return map


## How thick the strip an inside is collapsed by slices from is (cells): the pattern's size.
const STRIP: int = 3


## The strip for collapsing `img` by its columns (`columns`) or rows: [the strip, each slice's
## colours in order of the colour that stands for it]. Each different slice gets a colour of its
## own, the n-th Color8(n + 1, 7, 200).
static func _strip(img: Image, columns: bool) -> Array:
	var count: int = img.get_width() if columns else img.get_height()
	var along: int = img.get_height() if columns else img.get_width()
	var ids: Dictionary = {}
	var kinds: Array = []
	var order: Array[int] = []
	for i: int in range(count):
		var slice: Array[Color] = []
		for j: int in range(along):
			slice.append(img.get_pixel(i, j) if columns else img.get_pixel(j, i))
		var key: String = str(slice)
		if not ids.has(key):
			ids[key] = kinds.size()
			kinds.append(slice)
		order.append(int(ids[key]))
	var strip: Image = Image.create(count if columns else STRIP, STRIP if columns else count, false, Image.FORMAT_RGBA8)
	for i: int in range(count):
		for k: int in range(STRIP):
			strip.set_pixel(i if columns else k, k if columns else i, Color8(order[i] + 1, 7, 200))
	return [strip, kinds]


## The inside of `size` a strip collapsed by slices stands for (see _strip): each colour along its
## first row (or column) the slice it stands for.
static func _unstrip(strip: Array, kinds: Array, size: Vector2i, columns: bool) -> Array:
	var out: Array = []
	for x: int in range(size.x):
		var column: Array = []
		for y: int in range(size.y):
			var code: Color = Color(strip[x][0]) if columns else Color(strip[0][y])
			var slice: Array = kinds[clampi(code.r8 - 1, 0, kinds.size() - 1)]
			column.append(slice[y] if columns else slice[x])
		out.append(column)
	return out
