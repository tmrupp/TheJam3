extends LessonArt
## A lecture hall's lectern (Lectern), printed as a lesson's (LessonArt): a wooden lectern with an
## open book, and over it, in gold, the mark of the spell it would give back to the wizard now (one
## the institute has taught them, RunState.taught) with a pip for its tier; nothing floats over it
## while there is none, or while its hall's trial is under way.


func _held() -> Array:
	var lectern: Lectern = host as Lectern
	return lectern.holds() if lectern != null and lectern.map_info != null else [&"", 0]
