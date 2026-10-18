extends LessonArt
## One of the exam's prizes (ExamPrize), printed as a lesson (LessonArt): a wooden lectern with an
## open book, and over it, in gold, the mark of the spell it teaches with a pip for the tier.


func _held() -> Array:
	var prize: ExamPrize = host as ExamPrize
	return prize.holds() if prize != null else [&"", 0]
