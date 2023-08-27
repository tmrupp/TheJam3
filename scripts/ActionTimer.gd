# this class is the generalized behavior of a time-based action
# deals with actions that take a certain duration and can be refreshed
class_name ActionTimer

var MAX_TIME = 1.0
var acting = 0.0
var acted = false
var end_callback

func _init(_MAX_TIME, f=func f (_timer): pass):
	MAX_TIME = _MAX_TIME
	end_callback = f

func enable(force=false):
	if force or (acting <= 0.0 and not acted):
		acting = MAX_TIME
		acted = true

func elapse(t):
	if acting > 0:
		acting -= t
		if acting <= 0:
			end_callback.bind(self).call()

func end():
	acting = 0.0

func refresh():
	acted = false

func is_acting():
	return acting > 0
