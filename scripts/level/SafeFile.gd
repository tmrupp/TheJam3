class_name SafeFile
extends RefCounted
## A file of one value (a save: the run's, RunState; the kept map, Known) written so that a crash
## or a power cut in the middle of a write never costs what was there before. The new value is
## written whole to a file beside it (`path` + NEW); only then is the last good file moved aside
## (`path` + LAST, kept until the next write) and the new one given its name. Reading takes the
## file itself where it holds a value, else the last good one: at every moment of a write one of
## the two is whole.

## What is added to a file's path for the one being written, and for the last good one kept.
const NEW: String = ".new"
const LAST: String = ".last"


## Write `value` to `path` (see the class description). False if it could not be written, the
## file there before left as it was.
static func write(path: String, value: Variant) -> bool:
	var file: FileAccess = FileAccess.open(path + NEW, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(value)
	var whole: bool = file.get_error() == OK
	file.close()
	if not whole:
		_remove(path + NEW)
		return false
	if FileAccess.file_exists(path):
		_remove(path + LAST)
		if DirAccess.rename_absolute(_abs(path), _abs(path + LAST)) != OK:
			_remove(path + NEW)
			return false
	return DirAccess.rename_absolute(_abs(path + NEW), _abs(path)) == OK


## The value kept at `path`: the file's own, else the last good one's (a write was cut short
## between the two moves, or the file was), else null.
static func read(path: String) -> Variant:
	for p: String in [path, path + LAST]:
		if not FileAccess.file_exists(p):
			continue
		var file: FileAccess = FileAccess.open(p, FileAccess.READ)
		# A value is stored as its length, then that many bytes: one cut short is told by that,
		# without asking the engine to read it (which it reports as an error).
		if file == null or file.get_length() < 4 or file.get_32() != file.get_length() - 4:
			continue
		file.seek(0)
		var value: Variant = file.get_var()
		if value != null:
			return value
	return null


## Whether anything is kept at `path` (the file or the last good one).
static func exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + LAST)


## Take away everything kept at `path`: the file, the last good one and one left half written.
static func remove(path: String) -> void:
	for p: String in [path, path + LAST, path + NEW]:
		_remove(p)


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_abs(path))


static func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)
