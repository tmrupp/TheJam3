extends LessonArt
## A classroom's lectern (Lectern), printed as a lesson's (LessonArt): a wooden lectern with an open
## book, and over it the exam paper it holds (Lectern.paper), a paper sheet behind its subject's mark
## in gold with a pip for each tier. Nothing floats over it while it holds nothing.

## How big the paper sheet is behind the mark.
const SHEET: float = 2.6


func _held() -> Array:
	var lectern: Lectern = host as Lectern
	return lectern.holds() if lectern != null and lectern.map_info != null else [&"", 0]


func _under(c: Vector2) -> void:
	var lectern: Lectern = host as Lectern
	var code: int = lectern.paper() if lectern != null else 0
	if code != 0:
		RisoPrint.ink_key(ink, code, 1.0, RisoMarks.paper_shape(c + Vector2(0, 6), SHEET))
