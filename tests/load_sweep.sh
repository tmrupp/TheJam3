#!/usr/bin/env bash
# The load-order sweep (docs/CODE_REVIEW.md 2.1, 2.6): every scene of the game (each prefab, the
# main scene, the tools' scenes) is loaded first of all in a process of its own
# (tests/kit/load_first.gd), and any that leaves a scene without a part of itself (a "Parse Error"
# in what Godot prints: a cycle of loads closed badly) or does not load is a FAIL line. The game
# loads in one order today; this says which other orders are fragile before a change brings the
# game to load in one of them. The full run of tests/run.sh makes it (as load_sweep), or:
#   bash tests/load_sweep.sh          the scenes (about a minute)
#   bash tests/load_sweep.sh all      and every script of scripts/ loaded first too (about four)
# Godot is $GODOT, else `godot` on the PATH, else the copy in C:	ools.
set -u
cd "$(dirname "$0")/.."
godot=${GODOT:-$(command -v godot || echo /c/tools/godot-win/Godot_v4.7.2-stable_win64_console.exe)}
export godot
one() {
	local out
	out=$("$godot" --headless --path . --script res://tests/kit/load_first.gd -- "$1" 2>&1)
	if grep -q "Parse Error\|SCRIPT ERROR" <<< "$out" || ! grep -q "^LOADED $1 true" <<< "$out"; then
		echo "FAIL $1 loaded first: $(grep -m1 "Parse Error\|SCRIPT ERROR" <<< "$out" | tr -d '\r' | cut -c1-200)"
	else
		echo "  ok   $1"
	fi
}
export -f one
{ find prefabs tools -name '*.tscn'; [[ ${1:-} == all ]] && find scripts -name '*.gd'; } | sort | sed 's|^|res://|' | xargs -P "${SWEEP_JOBS:-6}" -I{} bash -c 'one "$1"' _ {}
