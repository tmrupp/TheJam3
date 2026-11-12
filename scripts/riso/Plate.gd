class_name Plate
extends RefCounted
## The print's plates by number, apart from the print itself (RisoPrint.NIGHT and the rest are
## these under their old names): gameplay that only names an ink (a burst's colours, a prop's
## plate) asks here, and need not load the whole print to do so (docs/CODE_REVIEW.md 2.1).

const NIGHT: int = 0
const BLUE: int = 1
const PINK: int = 2
const ACCENT: int = 3
const EYE: int = 4
const GLOW: int = 5
## The wizard's robe and hat, in the ink of the spell they carry (RisoPrint.ROBES).
const ROBE: int = 6
## The travelers' clothes and glass stay federal blue even in a realm whose terrain ink is green.
const CLOTH: int = 7
## How many plates there are.
const COUNT: int = 8
