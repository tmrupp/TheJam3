#!/usr/bin/env bash
# Regression runner: every tests/*_test.gd, in parallel.
#
#   bash tests/run.sh               quick check-in run: the headless tests (about half a minute)
#   bash tests/run.sh full          everything: also tests tagged "## suite: full", then the ones
#                                   tagged "## suite: window" one at a time in a real window
#   bash tests/run.sh keys_test hex_test    just these (headless)
#   options: -j N (parallel jobs), -t SECONDS (timeout per test)
#
# A test's tier is a line near its top: "## suite: full" (slow or known broken) or
# "## suite: window" (needs a rendered window); untagged tests are in the quick run.
# A test passes when Godot exits 0 and its log has no FAIL, SCRIPT ERROR or Parse Error. A script
# error usually leaves the test waiting forever, so it is stopped a moment after one appears.
# Some tests count frames and can miss under the load of running side by side: a headless test
# that fails is run once more on its own, and if it passes then it is reported as flaky (its
# first log is kept as <name>.flaky.log) rather than failed.
# Each test keeps its own save file (MapInfo.save_path = "user://<name>.save"), so tests can run
# side by side. Godot comes from $GODOT, else `godot` on the PATH, else the copy in C:\tools.
# The project is re-imported first when a script is newer than Godot's class cache (new
# class_names are not seen until then).

set -u
cd "$(dirname "$0")/.."

mode=quick
jobs=$(( $(nproc 2>/dev/null || echo 4) / 2 ))
(( jobs > 8 )) && jobs=8
(( jobs < 1 )) && jobs=1
limit=120
names=()
while (( $# )); do
	case "$1" in
		quick|full) mode=$1 ;;
		-j) jobs=$2; shift ;;
		-t) limit=$2; shift ;;
		*) names+=("${1%.gd}") ;;
	esac
	shift
done

godot=${GODOT:-$(command -v godot || true)}
[[ -z "$godot" ]] && godot=/c/tools/godot-win/Godot_v4.7.2-stable_win64_console.exe
if [[ ! -x "$godot" ]]; then
	echo "Godot not found: set GODOT to the console executable" >&2
	exit 2
fi

logs="${TMPDIR:-/tmp}/thejam3-tests/$mode"
rm -rf "$logs"
mkdir -p "$logs"

cache=.godot/global_script_class_cache.cfg
if [[ ! -f "$cache" ]] || [[ -n "$(find scripts tests -name '*.gd' -newer "$cache" -print -quit)" ]]; then
	echo "re-importing (scripts changed since the class cache was built)"
	"$godot" --headless --path . --import > "$logs/_import.log" 2>&1
fi

tier() { grep -m1 -o '^## suite: [a-z]*' "tests/$1.gd" | awk '{print $3}'; }

headless=()
windowed=()
if (( ${#names[@]} )); then
	headless=("${names[@]}")
else
	for f in tests/*_test.gd; do
		t=$(basename "$f" .gd)
		case "$(tier "$t")" in
			"") headless+=("$t") ;;
			full) [[ $mode == full ]] && headless+=("$t") ;;
			window) [[ $mode == full ]] && windowed+=("$t") ;;
		esac
	done
fi

# Run one test; writes "<PASS|FAIL> <seconds>s <name> <why>" to its .result file.
run_one() {
	local t=$1 window=$2 log="$logs/$1.log" start=$SECONDS why="" code
	local args=(--headless)
	[[ $window == 1 ]] && args=(--windowed --resolution 1280x720)
	"$godot" "${args[@]}" --path . --script "res://tests/$t.gd" > "$log" 2>&1 &
	local pid=$! errored=-1
	while kill -0 "$pid" 2>/dev/null; do
		if (( SECONDS - start >= limit )); then
			why="timed out after ${limit}s"
			kill "$pid" 2>/dev/null
			break
		fi
		if (( errored < 0 )) && grep -q "SCRIPT ERROR\|Parse Error" "$log"; then
			errored=$SECONDS
		fi
		if (( errored >= 0 && SECONDS - errored >= 3 )); then
			why="stopped after a script error"
			kill "$pid" 2>/dev/null
			break
		fi
		sleep 0.3
	done
	wait "$pid" 2>/dev/null
	code=$?
	if [[ -z "$why" ]]; then
		if (( code != 0 )); then why="exit $code"; fi
		if grep -q "FAIL\|SCRIPT ERROR\|Parse Error" "$log"; then why="${why:+$why, }errors in log"; fi
	fi
	local secs=$(( SECONDS - start ))
	if [[ -z "$why" ]]; then
		echo "PASS ${secs}s $t" > "$logs/$t.result"
	else
		echo "FAIL ${secs}s $t ($why)" > "$logs/$t.result"
	fi
	cat "$logs/$t.result"
}

began=$SECONDS
echo "$mode run: ${#headless[@]} headless (${jobs} at a time)${windowed:+, ${#windowed[@]} windowed}; logs in $logs"
for t in "${headless[@]}"; do
	while (( $(jobs -rp | wc -l) >= jobs )); do
		wait -n
	done
	run_one "$t" 0 &
done
wait
for r in $(grep -l '^FAIL' "$logs"/*.result 2>/dev/null); do
	t=$(basename "$r" .result)
	mv "$logs/$t.log" "$logs/$t.flaky.log"
	echo "retrying $t on its own"
	if run_one "$t" 0 | grep -q '^PASS'; then
		echo "FLAKY $t (failed beside others, passed alone; see $logs/$t.flaky.log)" > "$logs/$t.flaky"
	fi
done
for t in "${windowed[@]}"; do
	run_one "$t" 1
done

failed=$(cat "$logs"/*.result 2>/dev/null | grep -c '^FAIL')
total=$(ls "$logs"/*.result 2>/dev/null | wc -l)
echo
echo "$(( total - failed )) of $total passed in $(( SECONDS - began ))s"
cat "$logs"/*.flaky 2>/dev/null
if (( failed )); then
	grep -h '^FAIL' "$logs"/*.result
	for r in $(grep -l '^FAIL' "$logs"/*.result); do
		t=$(basename "$r" .result)
		echo "--- $t:"
		grep -m5 "FAIL\|SCRIPT ERROR\|Parse Error" "$logs/$t.log" | sed 's/^/    /'
	done
	exit 1
fi
