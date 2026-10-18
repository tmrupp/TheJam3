class_name InstituteArchetype
extends Archetype
## The institute: the last band down (docs/REGIONS_PLAN.md §7), a sunken institute of magic dug into
## the earth, in place of the catacombs. Its terrain is collapsed unturned from a sample of rooms and
## corridors (wfc_images/institute.png, drawn by tests/make_institute_sample.gd); then a structure
## pass (Institute) builds its halls of pale marble into it: classrooms, each a floor and a gallery
## with doorways at both ends, and the library's stacks, galleries one over another.
## It prints in a realm of its own, deep brown earth and wood with pale marble, gold kept for rewards.
##
## Its people (Institute.furnish, populate): students in numbers and their masters, each master
## having mastered one of the wizard's spells and teaching a tier of it once beaten (Lesson);
## proctors who shield the students near them, and in the library librarians whose hush silences
## the wizard's spells. Abominations of the beast rise into its halls from breaches in the floor,
## and they, the students and the masters fight one another as well as the wizard. Its puzzle is
## the timetable (Timetable): classrooms open only to a wizard carrying the right exam paper, and the
## way through runs through them. Its departments' portals lead to real levels of the other bands in the
## same world column (Department).

const SAMPLE: String = "res://wfc_images/institute.png"


func _init() -> void:
	name = &"institute"
	title = "The Institute"
	decor = &"institute"
	sample = SAMPLE
	symmetry = 1


## Its halls, built into the collapsed rooms once the caves are joined (Institute.build).
func cut_gates(w: LevelGen) -> void:
	Institute.build(w)


## Its people out in the level and its breaches (Institute.populate).
func populate(w: LevelGen, def: NextWorldDef) -> void:
	Institute.populate(w, def)


## Last of all: what the halls hold (Institute.furnish).
func finish(w: LevelGen, def: NextWorldDef) -> void:
	Institute.furnish(w, def)
