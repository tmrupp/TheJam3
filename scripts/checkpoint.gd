extends Area2D

class_name Checkpoint
## A lantern. Interact to light it: it becomes where you come back to, and absorbs one death; and,
## lit or already lit, it refills the hex's charges (MapInfo.light_lantern), but not mend's draughts
## nor resurrect's rites.
## At a lantern already lit as where you come back to, interacting also studies: the oldest exam paper
## carried that teaches something is learned into its slot, and the spell it puts out comes back as a
## paper (MapInfo.study). With no paper to study, holding mend with a draught drunk or resurrect with
## a rite spent, interacting burns it into that spell instead (MapInfo.can_burn), filling it. Either way the lantern burns
## out (MapInfo.burn_lantern): it protects no more and is not lit again this run, so the wizard must
## light another to be protected. (In the institute the library's desk teaches free in class time,
## StudyDesk.)

@onready var player: Player = Stage.player()

func enabled (val: bool) -> void:
	var spent: bool = MapInfo.instance != null and MapInfo.instance.is_lantern_spent(self)
	$Sprite2D.self_modulate = Color(0.3, 0.3, 0.35) if spent else (Color.GREEN_YELLOW if val else Color.WHITE)

func refresh () -> void:
	enabled(MapInfo.instance != null and MapInfo.instance.is_respawn_lantern(self))
	($Interactable as Interactable).available = (MapInfo.instance == null or not MapInfo.instance.is_lantern_spent(self))

func interacted () -> void:
	# Spent lanterns cannot be relit during this run.
	if MapInfo.instance != null:
		var lit: bool = MapInfo.instance.is_respawn_lantern(self)
		MapInfo.instance.light_lantern(self)
		if lit and MapInfo.instance.institute.study(global_position + Vector2(0, -40)):
			MapInfo.instance.burn_lantern(self)
		elif lit and MapInfo.instance.can_burn(self):
			MapInfo.instance.burn_lantern(self)
	refresh()

func _ready() -> void:
	$Interactable.connect("interacted", interacted)
	refresh.call_deferred()
