"""A model of the institute's timetable, to see how its rules play before and after changing them.

It reads the rules as the game has them (written by tests/dump_timetable.gd), checks its own copy of
the departments' climb against every outcome the game gave, then plays the timetable out:

- shortest plans: the fewest rings to earn a paper of each department at each tier, and how many
  different shortest plans there are (one is a puzzle with one answer; thousands, a loose one);
- on the classrooms of real institute levels, and on every way a level's four rooms can start;
- with a key ring of 1, 2 or 3 papers; with and without the departments' rhythms;
- in random play: how often each department stands at II or III by chance;
- and with other rules for geology, for comparison.

The wizard is modelled as the game has them: they start holding slash I (a geology spell); a class of
tier II or more asks for a paper of the department before it round the ring (Timetable.NEEDS), a
tier lower; a class of a relic's move (levitate, astral) cannot be attended without the relic;
ringing from the corridors needs a class they could go into first (passing time). Field trips cost
no rings, and the key ring keeps the best paper of each department, the wizard choosing which to
drop when it is full (lecterns make that a real choice). Instructors' papers are left out.

    godot --headless --path . --script res://tests/dump_timetable.gd -- out=../timetable_rules.json
    python tools/timetable_model.py ../timetable_rules.json [--json results.json]
"""
import argparse
import itertools
import json
import random
import statistics
import sys
from collections import defaultdict

ORDER = ["botany", "astronomy", "geology", "necrology"]


class Rules:
    def __init__(self, data):
        self.depts = list(data["depts"])
        self.ladders = data["ladders"]
        self.meets = {d: set(data["meets"][d]) for d in self.depts}
        self.holds = data["holds"]
        self.needs = data["needs"]
        self.top = data["top"]
        self.periods = data["periods"]
        self.max_tier = data["max_tier"]
        self.relic_moves = set(data["relic_moves"])
        self.dept_of = {a: d for d in self.depts for a in self.ladders[d]}


def climb(rules, tiers, attended, meeting, geology="strict_lowest", last_rose=None, untaught=False, botany_stands=True):
    """The departments' tiers after a period (Timetable.climb), `geology` naming the rule geology
    climbs by (the game's is strict_lowest; the rest are for comparison). `untaught`: botany's class was
    one the wizard cannot be taught, which leaves botany standing (`botany_stands` False models the
    rules before that was so)."""
    out = dict(tiers)
    crashed = False
    rose = {d: False for d in rules.depts}
    for d in ["botany", "astronomy", "geology"]:
        if not meeting[d]:
            continue
        hold = False
        if d == "botany":
            if untaught and botany_stands and attended != "botany":
                continue
            up = attended == "botany"
        elif d == "astronomy":
            up = attended not in ("", "astronomy")
        else:
            others = [o for o in rules.depts if o != "geology" and meeting[o]]
            if geology == "strict_lowest":
                up = bool(others) and all(tiers[o] > tiers["geology"] for o in others)
            elif geology == "lowest_or_tied":
                up = bool(others) and all(tiers[o] >= tiers["geology"] for o in others)
            elif geology == "strict_lowest_holds":
                up = bool(others) and all(tiers[o] > tiers["geology"] for o in others)
                hold = not up
            elif geology == "echo":
                up = any((last_rose or {}).get(o, False) for o in rules.depts if o != "geology")
            else:
                raise ValueError(geology)
        if up:
            out[d] = min(tiers[d] + 1, rules.top)
            rose[d] = out[d] > tiers[d]
        elif not hold:
            crashed = crashed or tiers[d] >= 2
            out[d] = 1
    if meeting["necrology"]:
        out["necrology"] = min(tiers["necrology"] + 1, rules.top) if crashed else 1
        rose["necrology"] = out["necrology"] > tiers["necrology"]
    return out, rose


def check(rules, data):
    """The model's climb against every outcome the game gave; the model's schedule formula against
    every real classroom. Returns a list of mismatches (empty when the model is true to the game)."""
    bad = []
    for before, attended, m, untaught, after in data["climb"]:
        tiers = dict(zip(rules.depts, before))
        meeting = {rules.depts[k]: bool((m >> k) & 1) for k in range(len(rules.depts))}
        got, _ = climb(rules, tiers, attended, meeting, untaught=untaught)
        if [got[d] for d in rules.depts] != after:
            bad.append(("climb", before, attended, m, after, [got[d] for d in rules.depts]))
    rings = len(data["levels"][0]["rooms"][0]["subjects"]) if data["levels"] else 0
    for level in data["levels"]:
        for room in level["rooms"]:
            fits = [s for s in range(3) if schedule(rules, room["dept"], s, rings) == room["subjects"]]
            if not fits:
                bad.append(("schedule", level["at"], room["dept"], room["subjects"][:12]))
    return bad


def sessions_before(rules, dept, r):
    days = sorted(rules.meets[dept])
    return (r // rules.periods) * len(days) + len([p for p in days if p < r % rules.periods])


def schedule(rules, dept, start, rings, all_meet=False):
    """What a classroom of `dept` starting at `start` teaches each ring (Timetable.subject)."""
    out = []
    ladder = rules.ladders[dept]
    for r in range(rings):
        meets = all_meet or (r % rules.periods) in rules.meets[dept]
        if not meets:
            out.append("")
            continue
        n = r if all_meet else sessions_before(rules, dept, r)
        out.append(ladder[(start + n // rules.holds[dept]) % len(ladder)])
    return out


class Level:
    """A level's classrooms: (department, its subject each ring)."""
    def __init__(self, rooms, all_meet=False):
        self.rooms = rooms
        self.all_meet = all_meet

    def meeting(self, rules, r):
        return {d: any(room[1][r] != "" for room in self.rooms if room[0] == d) for d in rules.depts}


def taught(rules, a, tier):
    return min(tier, rules.max_tier[a])


class Wizard:
    """The wizard and the rules they play under: `bell_when_none_open` (the bell rings in passing time
    when no class is open to them) and `botany_stands` (an untaught botany class leaves botany
    standing) are the game's now; turning them off models the rules before 2026-10-18's fixes."""
    def __init__(self, cap=2, relics=False, geology="strict_lowest", bell_when_none_open=True, botany_stands=True):
        self.cap = cap
        self.relics = relics
        self.geology = geology
        self.bell_when_none_open = bell_when_none_open
        self.botany_stands = botany_stands


def enrolled(rules, tiers, papers, dept, a):
    t = taught(rules, a, tiers[dept])
    if t < 2:
        return True
    need, nt = rules.needs[dept], t - 1
    held = 1 if need == "geology" else 0  # slash I
    return max(held, papers.get(need, 0)) >= nt


def choices(rules, level, wiz, r, tiers, papers):
    """What the wizard can do in the period after `r` rings: attend a room (its index), or ring from
    the corridors (None, when some class could be gone into first, or none is in session)."""
    rooms = []
    any_class = False
    any_open = False
    for k, (dept, subjects) in enumerate(level.rooms):
        a = subjects[r]
        if a == "":
            continue
        any_class = True
        if not enrolled(rules, tiers, papers, dept, a):
            continue
        any_open = True
        if a in rules.relic_moves and not wiz.relics:
            continue
        rooms.append(k)
    out = list(rooms)
    # Ringing from the corridors: at the start (not passing time), after going into a class open to
    # them and back out, or, with the fix, when no class is open to them at all.
    if r == 0 or any_open or not any_class or wiz.bell_when_none_open:
        out.append(None)
    return out


def untaught(rules, level, wiz, r):
    """Whether every botany class in session in the period after `r` rings is one the wizard cannot
    be taught (a relic's move they lack)."""
    classes = [subjects[r] for dept, subjects in level.rooms if dept == "botany" and subjects[r] != ""]
    return bool(classes) and all(a in rules.relic_moves and not wiz.relics for a in classes)


def keep(papers, dept, tier, cap):
    """Every key ring the wizard can come away with after earning (dept, tier)."""
    if papers.get(dept, 0) >= tier:
        return [papers]
    p = dict(papers)
    p[dept] = tier
    if len(p) <= cap:
        return [p]
    return [{k: v for k, v in p.items() if k != drop} for drop in p if drop != dept]


def frozen(p):
    return tuple(sorted(p.items()))


def shortest(rules, level, wiz, rings=36, targets=None):
    """Breadth-first over the wizard's choices: for each (department, tier), the fewest rings to earn
    a paper of it at that tier or higher, and how many different plans do it in that many."""
    start = (tuple(1 for _ in rules.depts), (), tuple(False for _ in rules.depts))
    frontier = {start: 1}
    best, ways = {}, {}
    for r in range(rings):
        meeting = level.meeting(rules, r)
        nxt = defaultdict(int)
        for (tk, pk, lr), count in frontier.items():
            tiers = dict(zip(rules.depts, tk))
            papers = dict(pk)
            for c in choices(rules, level, wiz, r, tiers, papers):
                attended, gained = "", None
                if c is not None:
                    dept, subjects = level.rooms[c]
                    attended = dept
                    gained = (dept, taught(rules, subjects[r], tiers[dept]))
                after, rose = climb(rules, tiers, attended, meeting, wiz.geology, dict(zip(rules.depts, lr)), untaught(rules, level, wiz, r), wiz.botany_stands)
                plist = [papers]
                if gained:
                    for t in range(1, gained[1] + 1):
                        key = (gained[0], t)
                        if key not in best:
                            best[key] = r + 1
                        if best[key] == r + 1:
                            ways[key] = ways.get(key, 0) + count
                    plist = keep(papers, gained[0], gained[1], wiz.cap)
                for p2 in plist:
                    nxt[(tuple(after[d] for d in rules.depts), frozen(p2), tuple(rose[d] for d in rules.depts))] += count
        frontier = nxt
        if targets and all(t in best for t in targets):
            break
    return best, ways


def random_play(rules, level, wiz, rings=60, runs=400, seed=1):
    rng = random.Random(seed)
    at2 = defaultdict(int)
    at3 = defaultdict(int)
    first3 = []
    stuck = []
    total = 0
    for _ in range(runs):
        tiers = {d: 1 for d in rules.depts}
        papers, lr, got3 = {}, {d: False for d in rules.depts}, None
        for r in range(rings):
            options = choices(rules, level, wiz, r, tiers, papers)
            if not options:
                # Stuck in passing time: every class in session asks for a paper the wizard lacks, so
                # there is no class to go into, and the bell will not ring until they do.
                stuck.append(r)
                break
            c = rng.choice(options)
            attended = ""
            if c is not None:
                dept, subjects = level.rooms[c]
                attended = dept
                t = taught(rules, subjects[r], tiers[dept])
                if t >= 3 and got3 is None:
                    got3 = r + 1
                papers = rng.choice(keep(papers, dept, t, wiz.cap))
            tiers, lr = climb(rules, tiers, attended, level.meeting(rules, r), wiz.geology, lr, untaught(rules, level, wiz, r), wiz.botany_stands)
            total += 1
            for d in rules.depts:
                at2[d] += tiers[d] >= 2
                at3[d] += tiers[d] >= 3
        first3.append(got3 if got3 is not None else rings + 1)
    return {d: (at2[d] / max(total, 1), at3[d] / max(total, 1)) for d in rules.depts}, statistics.median(first3), stuck


def synthetic(rules, starts, rings=36, all_meet=False):
    return Level([(d, schedule(rules, d, starts[d], rings, all_meet)) for d in ORDER], all_meet)


TARGETS = [(d, t) for d in ORDER for t in (2, 3, 4)]


def summarise(results):
    """min / median / max over many levels of each target's fewest rings (None = not within reach)."""
    out = {}
    for t in TARGETS:
        vals = [r[0].get(t) for r in results]
        reach = [v for v in vals if v is not None]
        plans = [r[1][t] for r in results if t in r[1]]
        out[t] = {"min": min(reach) if reach else None, "median": statistics.median(reach) if reach else None,
                  "max": max(reach) if reach else None, "unreached": len(vals) - len(reach),
                  "plans": statistics.median(plans) if plans else None}
    return out


def table(title, summary):
    print(f"\n{title}")
    print("  " + " ".join(f"{d[:4]:>18}" for d in ORDER))
    for tier in (2, 3, 4):
        cells = []
        for d in ORDER:
            s = summary[(d, tier)]
            if s["min"] is None:
                cells.append(f"{'never':>18}")
            else:
                miss = f" ({s['unreached']}x)" if s["unreached"] else ""
                cells.append(f"{s['min']:>3}/{s['median']:>4}/{s['max']:>3}{miss:>6}")
        print(f"  {['', '', 'II', 'III', 'IV'][tier]:>3} " + " ".join(cells))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("rules", help="the JSON tests/dump_timetable.gd wrote")
    ap.add_argument("--json", help="write every result here too")
    ap.add_argument("--rings", type=int, default=36)
    args = ap.parse_args()
    data = json.load(open(args.rules, encoding="utf-8"))
    rules = Rules(data)
    bad = check(rules, data)
    print(f"model against the game: {len(data['climb'])} climbs and {sum(len(l['rooms']) for l in data['levels'])} classrooms, {len(bad)} mismatches")
    for b in bad[:10]:
        print("  ", b)
    if bad:
        sys.exit(1)
    report = {}
    starts = [dict(zip(ORDER, s)) for s in itertools.product(range(3), repeat=4)]

    # 1. Real levels.
    real = []
    for level in data["levels"]:
        lv = Level([(room["dept"], room["subjects"]) for room in level["rooms"]])
        real.append(shortest(rules, lv, Wizard(), min(args.rings, len(level["rooms"][0]["subjects"])), TARGETS))
    report["real"] = summarise(real)
    table("real levels (fewest rings: min/median/max over levels; key ring 2)", report["real"])

    # 2. Every way four rooms can start, by key ring size and with or without the rhythms.
    for cap in (1, 2, 3):
        res = [shortest(rules, synthetic(rules, s, args.rings), Wizard(cap=cap), args.rings, TARGETS) for s in starts]
        report[f"starts_cap{cap}"] = summarise(res)
        table(f"all 81 starts, key ring {cap}", report[f"starts_cap{cap}"])
    res = [shortest(rules, synthetic(rules, s, args.rings, all_meet=True), Wizard(), args.rings, TARGETS) for s in starts]
    report["no_rhythms"] = summarise(res)
    table("all 81 starts, every department meeting every period", report["no_rhythms"])
    res = [shortest(rules, synthetic(rules, s, args.rings), Wizard(relics=True), args.rings, TARGETS) for s in starts]
    report["relics"] = summarise(res)
    table("all 81 starts, the wizard holding levitate and astral", report["relics"])

    # 2b. The rules before the fixes (bell silent with no class open; untaught botany crashing).
    res = [shortest(rules, synthetic(rules, s, args.rings), Wizard(bell_when_none_open=False, botany_stands=False), args.rings, TARGETS) for s in starts]
    report["before_fixes"] = summarise(res)
    table("all 81 starts, before the fixes", report["before_fixes"])

    # 3. Random play.
    rp = defaultdict(lambda: [0.0, 0.0])
    firsts = []
    stuck_runs, stuck_at = 0, []
    sample = starts[::9]
    runs = 150
    for s in sample:
        shares, first3, stuck = random_play(rules, synthetic(rules, s, 60), Wizard(), rings=60, runs=runs)
        firsts.append(first3)
        stuck_runs += len(stuck)
        stuck_at += stuck
        for d in ORDER:
            rp[d][0] += shares[d][0] / len(sample)
            rp[d][1] += shares[d][1] / len(sample)
    report["random"] = {"shares": {d: rp[d] for d in ORDER}, "median_rings_to_any_III": statistics.median(firsts),
                        "stuck_share": stuck_runs / (runs * len(sample)), "stuck_median_ring": statistics.median(stuck_at) if stuck_at else None}
    old_stuck, old_runs = 0, 0
    for s in sample:
        _, _, stuck = random_play(rules, synthetic(rules, s, 60), Wizard(bell_when_none_open=False, botany_stands=False), rings=60, runs=runs)
        old_stuck += len(stuck)
        old_runs += runs
    report["random"]["stuck_share_before_fixes"] = old_stuck / old_runs
    print("\nrandom play (60 rings): share of rings at II+ / III+")
    print("  " + "  ".join(f"{d}: {rp[d][0]:.2f}/{rp[d][1]:.2f}" for d in ORDER))
    print(f"  median rings to a first paper of tier III, any department: {statistics.median(firsts)}")
    print(f"  runs stuck in passing time (no class open to them, the bell silent): {report['random']['stuck_share']:.0%} (before the fixes {report['random']['stuck_share_before_fixes']:.0%})")

    # 4. Other rules for geology.
    report["geology"] = {}
    for g in ["strict_lowest", "lowest_or_tied", "strict_lowest_holds", "echo"]:
        res = [shortest(rules, synthetic(rules, s, args.rings), Wizard(geology=g), args.rings, TARGETS) for s in starts[::3]]
        summ = summarise(res)
        shares = defaultdict(float)
        for s in starts[::27]:
            sh, _, _ = random_play(rules, synthetic(rules, s, 60), Wizard(geology=g), rings=60, runs=150)
            for d in ORDER:
                shares[d] += sh[d][0] / 3
        report["geology"][g] = {"summary": summ, "random_II": dict(shares)}
        table(f"geology rule: {g} (27 starts); random play geology at II+: {shares['geology']:.2f}", summ)

    if args.json:
        def keyed(v):
            if isinstance(v, dict):
                return {(f"{k[0]} {k[1]}" if isinstance(k, tuple) else k): keyed(x) for k, x in v.items()}
            return v
        json.dump(keyed(report), open(args.json, "w", encoding="utf-8"), indent=1)
        print(f"\nwrote {args.json}")


if __name__ == "__main__":
    main()
