extends LessonArt
## The library's reading desk (StudyDesk), printed as a lesson's lectern (LessonArt): a wooden lectern
## with an open book, and over it, while studying here now would teach (StudyDesk.paper), the mark of
## the spell it would teach in gold with a pip for each tier. Nothing floats over it otherwise.


func _held() -> Array:
	var desk: StudyDesk = host as StudyDesk
	return desk.holds() if desk != null and desk.map_info != null else [&"", 0]
