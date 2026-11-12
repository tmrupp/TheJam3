class_name SampleSheet
extends RefCounted
## A WFC sample kept as text in the script that draws it (tests/make_crags_sample.gd,
## make_institute_sample.gd, make_sky_sample.gd): the samples that are painted by hand in the
## generation lab. A row of the sheet is a line of the script's SHEET and a cell a letter (INKS), so
## a change to a sample reads in a diff as the picture does, and the script and the picture in
## wfc_images cannot drift apart unseen. Such a script does one of three things, by what follows a
## lone "--" on its command line (asked):
## - nothing: it draws the picture from its SHEET (draw);
## - "fold": it reads the picture as it is in wfc_images, as the lab saved it, and writes it into
##   its own SHEET (fold). Run this after painting a sample in the lab;
## - "redraw": it draws the picture afresh by the script's own rules (its _redraw), as the sheet was
##   first drawn, over whatever was painted. Fold it after to keep it.

## The letter for each of a sample's colours (LevelGen.color_to_type): open air, rock, thorns, and
## the open sky between the sky's clusters.
const INKS: Dictionary = {".": Color.WHITE, "#": Color.BLACK, "^": Color.RED, "~": LevelGen.SKY}
## How many times a picture is tried again when it cannot be written (a file another program holds
## for a moment), and how long between tries, in milliseconds.
const SAVE_TRIES: int = 8
const SAVE_WAIT: int = 500


## What the script was asked to do: &"fold", &"redraw", or &"" to draw from its SHEET.
static func asked() -> StringName:
	for arg: String in OS.get_cmdline_user_args():
		if arg in ["fold", "redraw"]:
			return StringName(arg)
	return &""


## The picture `sheet` spells, a pixel a cell.
static func image(sheet: PackedStringArray) -> Image:
	var wide: int = 0
	for line: String in sheet:
		wide = maxi(wide, line.length())
	var img: Image = Image.create(maxi(wide, 1), maxi(sheet.size(), 1), false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	for y: int in range(sheet.size()):
		for x: int in range(sheet[y].length()):
			img.set_pixel(x, y, INKS.get(sheet[y][x], Color.WHITE))
	return img


## `img` as a sheet's lines: a letter a pixel (one that is none of INKS' colours reads as open air).
static func text(img: Image) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for y: int in range(img.get_height()):
		var line: String = ""
		for x: int in range(img.get_width()):
			var letter: String = "."
			for key: String in INKS:
				if img.get_pixel(x, y).is_equal_approx(INKS[key]):
					letter = key
			line += letter
		out.append(line)
	return out


## Write `img` to `path` (a res:// path), trying again for a while if it cannot be written. Whether
## it was.
static func save(img: Image, path: String) -> bool:
	for attempt: int in range(SAVE_TRIES):
		if img.save_png(ProjectSettings.globalize_path(path)) == OK:
			print("drawn: ", path, ", ", img.get_width(), " x ", img.get_height())
			return true
		OS.delay_msec(SAVE_WAIT)
	push_error("could not write %s" % path)
	return false


## Draw `sheet` to `path`, printing it.
static func draw(sheet: PackedStringArray, path: String) -> void:
	for line: String in sheet:
		print(line)
	save(image(sheet), path)


## Read the picture at `path` and write it into `script`'s own file as its SHEET, in place of what
## the SHEET holds.
static func fold(path: String, script: Script) -> void:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		push_error("no picture at %s to fold" % path)
		return
	img.convert(Image.FORMAT_RGBA8)
	var lines: PackedStringArray = PackedStringArray()
	for line: String in text(img):
		lines.append('\t"%s",' % line)
	var file_path: String = script.resource_path
	var source: String = FileAccess.get_file_as_string(file_path)
	var head: String = "const SHEET: PackedStringArray = [\n"
	var start: int = source.find(head)
	var end: int = source.find("]\n", start)
	if start < 0 or end < 0:
		push_error("no SHEET in %s to write" % file_path)
		return
	source = source.substr(0, start) + head + "\n".join(lines) + ("\n" if not lines.is_empty() else "") + source.substr(end)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	print("folded: ", path, ", ", img.get_width(), " x ", img.get_height(), ", into ", file_path)
