# this class is the generalized behavior of a time-based action
# deals with actions that take a certain duration and can be refreshed
class_name ActionTimer

var MAX_TIME: float = 1.0
var acting: float = 0.0
var acted: bool = false
var end_callback: Callable

# f is fucking unreable as a default param
func _init( _MAX_TIME: float, 
			f: Callable=func f (_timer: ActionTimer) -> void: pass) -> void:
	MAX_TIME = _MAX_TIME
	end_callback = f

func enable(force: bool=false) -> void:
	if force or (acting <= 0.0 and not acted):
		acting = MAX_TIME
		acted = true

func elapse(t: float) -> void:
	if acting > 0:
		acting -= t
		if acting <= 0:
			end_callback.bind(self).call()

func end() -> void:
	acting = 0.0

func refresh() -> void:
	acted = false

func is_acting() -> bool:
	return acting > 0
