"""A model of the institute's timetable, to see how its rules play before and after changing them.

It reads the rules as the game has them (written by tests/dump_timetable.gd), checks its own copy of
the departments' climb against every outcome the game gave, then plays the timetable out:

- shortest plans: the fewest rings to earn a paper of each department at each tier, and how many
  different shortest plans there are (one is a puzzle with one answer; thousands, a loose one);
- on the classrooms of real institute levels, and on every way a level's four rooms can start;
- with a key ring of 1, 2 or 3 papers; with and without the departments' rhythms;
- in random play: how often each department stands at II or III by chance;
- and with other rules for geology, for comparison;
- and (--route) the way through real levels: the fewest rings from the way in to the way on, which
  stands in a classroom asking besides for a paper of another department (way_through).

The wizard is modelled as the game has them: they start holding slash I (a geology spell); a class of
tier II or more asks for a paper of the department before it round the ring (Timetable.NEEDS), a
tier lower; each classroom is in session two periods of three, from a place in that cycle dealt by
the seed; a class starts when its cord is rung inside it and ends when a bell out of the classrooms
rings it out (one ring, a period); a corridor bell rung with no class started moves the day on all
the same; a class of a relic's move (levitate, astral) the wizard lacks counts as attended, with no
paper. Field trips cost
no rings, and the key ring keeps the best paper of each department, the wizard choosing which to
drop when it is full (lecterns make that a real choice). Instructors' and lecterns' papers (stolen)
are left out.

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
        self.in_session = data["in_session"]
        self.holds = data["holds"]
        self.needs = data["needs"]
        self.top = data["top"]
        self.periods = data["periods"]
        self.max_tier = data["max_tier"]
        self.relic_moves = set(data["relic_moves"])
        self.dept_of = {a: d for d in self.depts for a in self.ladders[d]}


def climb(rules, tiers, attended, meeting, geology="strata", last_rose=None):
    """The departments' tiers after a period (Timetable.climb), `geology` naming the rule geology
    climbs by (the game's is strata; the rest are for comparison)."""
    out = dict(tiers)
    crashed = False
    rose = {d: False for d in rules.depts}
    for d in ["botany", "astronomy", "geology"]:
        if not meeting[d]:
            continue
        hold = False
        if d == "botany":
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
            elif geology == "pressure":
                # Pressed by a higher stratum: the class attended was another department's, standing
                # above geology.
                up = attended not in ("", "geology") and tiers[attended] > tiers["geology"]
            elif geology == "sediment":
                # Settles while left alone: no class attended at all.
                up = attended == ""
            elif geology == "below_average":
                up = bool(others) and tiers["geology"] * len(others) < sum(tiers[o] for o in others)
            elif geology == "below_most":
                below = sum(1 for o in others if tiers[o] > tiers["geology"])
                up = bool(others) and below >= min(2, len(others))
            elif geology == "strata":
                # Laid down on its own stratum: the class attended was another department's,
                # standing at geology's own tier.
                up = attended not in ("", "geology") and tiers[attended] == tiers["geology"]
            elif geology == "outcrop":
                # Laid bare: a department standing above it is closed this period.
                up = any(not meeting[o] and tiers[o] > tiers["geology"] for o in rules.depts if o != "geology")
            elif geology == "weathering":
                # Roots split the rock: botany's class (the department geology asks for) was attended.
                up = attended == rules.needs["geology"]
            elif geology == "landslide":
                # A department standing above it fell back to I this period (botany or astronomy,
                # whose rules are settled before geology's).
                up = any(meeting[o] and tiers[o] >= 2 and tiers[o] > tiers["geology"] and out[o] == 1 for o in ("botany", "astronomy"))
            elif geology == "core_sample":
                # Its own class attended while some other department meeting stands above it.
                up = attended == "geology" and any(tiers[o] > tiers["geology"] for o in others)
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
    for before, attended, m, after in data["climb"]:
        tiers = dict(zip(rules.depts, before))
        meeting = {rules.depts[k]: bool((m >> k) & 1) for k in range(len(rules.depts))}
        got, _ = climb(rules, tiers, attended, meeting)
        if [got[d] for d in rules.depts] != after:
            bad.append(("climb", before, attended, m, after, [got[d] for d in rules.depts]))
    rings = len(data["levels"][0]["rooms"][0]["subjects"]) if data["levels"] else 0
    for level in data["levels"]:
        for room in level["rooms"]:
            fits = [s for s in range(3) if schedule(rules, room["dept"], s, rings, phase=room.get("phase", 0)) == room["subjects"]]
            if not fits:
                bad.append(("schedule", level["at"], room["dept"], room["subjects"][:12]))
    return bad


def in_cycle(rules, phase, r):
    """Whether a classroom `phase` into its cycle is in session after `r` rings (Timetable.in_cycle)."""
    return (r + phase) % rules.periods < rules.in_session


def sessions_before(rules, phase, r):
    return sum(1 for k in range(r) if in_cycle(rules, phase, k))


def schedule(rules, dept, start, rings, all_meet=False, phase=0):
    """What a classroom of `dept` starting at subject `start` and `phase` into its cycle teaches each
    ring (Timetable.subject); `all_meet`: in session every period."""
    out = []
    ladder = rules.ladders[dept]
    for r in range(rings):
        meets = all_meet or in_cycle(rules, phase, r)
        if not meets:
            out.append("")
            continue
        n = r if all_meet else sessions_before(rules, phase, r)
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
    """The wizard: how many papers their ring holds, whether they hold the relics (so relic classes
    teach them), and the rule geology climbs by."""
    def __init__(self, cap=2, relics=False, geology="strata"):
        self.cap = cap
        self.relics = relics
        self.geology = geology


def teaches(rules, wiz, a):
    """Whether a class of `a` teaches the wizard (gives a paper): not a relic's move they lack."""
    return wiz.relics or a not in rules.relic_moves


def enrolled(rules, tiers, papers, dept, a):
    t = taught(rules, a, tiers[dept])
    if t < 2:
        return True
    need, nt = rules.needs[dept], t - 1
    held = 1 if need == "geology" else 0  # slash I
    return max(held, papers.get(need, 0)) >= nt


def choices(rules, level, wiz, r, tiers, papers):
    """What the wizard can do in the period after `r` rings: start a room's class and ring it out (its
    index), or ring a corridor bell with no class started (None)."""
    rooms = []
    for k, (dept, subjects) in enumerate(level.rooms):
        a = subjects[r]
        if a != "" and enrolled(rules, tiers, papers, dept, a):
            rooms.append(k)
    return rooms + [None]


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
                    if teaches(rules, wiz, subjects[r]):
                        gained = (dept, taught(rules, subjects[r], tiers[dept]))
                after, rose = climb(rules, tiers, attended, meeting, wiz.geology, dict(zip(rules.depts, lr)))
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
                if teaches(rules, wiz, subjects[r]):
                    t = taught(rules, subjects[r], tiers[dept])
                    if t >= 3 and got3 is None:
                        got3 = r + 1
                    papers = rng.choice(keep(papers, dept, t, wiz.cap))
            tiers, lr = climb(rules, tiers, attended, level.meeting(rules, r), wiz.geology, lr)
            total += 1
            for d in rules.depts:
                at2[d] += tiers[d] >= 2
                at3[d] += tiers[d] >= 3
        first3.append(got3 if got3 is not None else rings + 1)
    return {d: (at2[d] / max(total, 1), at3[d] / max(total, 1)) for d in rules.depts}, statistics.median(first3), stuck


def synthetic(rules, starts, rings=36, all_meet=False):
    """A level of four rooms, one per department, starting at subjects `starts`, each at a place in its
    cycle dealt from them (the same every time)."""
    roll = random.Random(sum(starts[d] * 3 ** i for i, d in enumerate(ORDER)) + 17)
    return Level([(d, schedule(rules, d, starts[d], rings, all_meet, roll.randrange(rules.periods))) for d in ORDER], all_meet)


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


# ------------------------------------------------------------------ getting through a level

class Route:
    """A real level as a graph for walking it (tests/dump_timetable.gd): regions of open air joined only
    by classrooms (and, with `keys`, by locked doors and gates); where the wizard comes in; where a bell cord hangs out of the
    classrooms; and which classroom holds the way on (the game's, Institute.way_on, unless
    `exit_room` names one; for a level written without it, the one most classrooms away from the way
    in, ties by distance)."""
    def __init__(self, level, keys=True, exit_room=None):
        if exit_room is None and level.get("exit", -1) >= 0:
            exit_room = level["exit"]
        parent = {}

        def find(a):
            parent.setdefault(a, a)
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a

        if keys:
            for lock in level.get("locks", []):
                if lock["kind"] in ("door", "switch_gate", "light_gate"):
                    for other in lock["regions"][1:]:
                        parent[find(other)] = find(lock["regions"][0])
        self.rooms = [(room["dept"], room["subjects"], frozenset(find(g) for g in room["regions"])) for room in level["rooms"]]
        self.start = find(level["start_region"])
        self.cords = {find(g) for g in level["cord_regions"]}
        self.at = level["at"]
        # Rooms crossed to reach each room's door, from the way in.
        dist = {self.start: 0}
        frontier = [self.start]
        room_dist = {}
        while frontier:
            nxt = []
            for g in frontier:
                for k, (_, _, gs) in enumerate(self.rooms):
                    if g in gs and k not in room_dist:
                        room_dist[k] = dist[g]
                        for h in gs:
                            if h not in dist:
                                dist[h] = dist[g] + 1
                                nxt.append(h)
            frontier = nxt
        self.room_dist = room_dist
        if exit_room is None and room_dist:
            sx, sy = level["start"]
            exit_room = max(room_dist, key=lambda k: (room_dist[k], (level["rooms"][k]["at"][0] - sx) ** 2 + (level["rooms"][k]["at"][1] - sy) ** 2))
        self.exit = exit_room


def way_through(rules, route, gate="any", gate_tier=2, cap=2, rings=30, geology="strata"):
    """The fewest rings from the way in to the way on, or None (not within `rings`), for a wizard
    who comes in with nothing on their ring, under the game's rules: in passing time the wizard walks
    the corridors and through every classroom open to them (in session, enrolled); they may ring the
    cord in any of those (not the one rung last) to begin class time attending it, and walk out of it
    to end the period (a relic class they lack counts too, with no paper), coming out on any side of
    it; or ring a corridor bell they can reach and then another, truant, ending the period at a bell. gate "any" (the game, Timetable.WAY_ON_PAPER): the way
    on (its classroom opening as any other) takes a paper of any department but its classroom's at
    `gate_tier` or higher; gate "always": one of the department before its own round the ring; gate
    None: no paper. `geology`
    names the rule geology climbs by (climb)."""
    if route.exit is None:
        return None
    papers0 = ()

    def taught_tier(tiers, k, r):
        dept, subjects, _ = route.rooms[k]
        a = subjects[r]
        return taught(rules, a, tiers[dept]) if a else 0

    def open_room(tiers, papers, k, r):
        dept, subjects, _ = route.rooms[k]
        a = subjects[r]
        return bool(a) and enrolled(rules, tiers, dict(papers), dept, a)

    def paper_ok(tiers, papers, r):
        """Whether the way on lets the wizard through with `papers` (its classroom opens as any)."""
        dept = route.rooms[route.exit][0]
        held = dict(papers)
        if gate == "always":
            return held.get(rules.needs[dept], 0) >= max(gate_tier, taught_tier(tiers, route.exit, r) - 1)
        if gate == "any":
            return max([t for d, t in held.items() if d != dept] + [0]) >= gate_tier
        return True

    def meeting_of(r):
        return {d: any(sub[r] != "" for dd, sub, _ in route.rooms if dd == d) for d in rules.depts}

    start = (route.start, tuple(1 for _ in rules.depts), papers0, -1)
    frontier = {start}
    seen = set(frontier)
    for r in range(rings):
        meeting = meeting_of(r)
        nxt = set()
        for region, tk, pk, last in frontier:
            tiers = dict(zip(rules.depts, tk))
            papers = dict(pk)
            # Where the wizard can be this period: through every classroom open to them.
            here = {region}
            grow = True
            while grow:
                grow = False
                for k, (_, _, gs) in enumerate(route.rooms):
                    if gs & here and open_room(tiers, pk, k, r) and not gs <= here:
                        here |= gs
                        grow = True
            if route.rooms[route.exit][2] & here and open_room(tiers, pk, route.exit, r) and paper_ok(tiers, pk, r):
                return r
            moves = []
            bells = here & route.cords
            if bells:
                moves.append((None, "", bells))
            for k, (dept, subjects, gs) in enumerate(route.rooms):
                if k != last and gs & here and open_room(tiers, pk, k, r):
                    moves.append((k, dept, gs))
            for k, attended, out in moves:
                after, _ = climb(rules, tiers, attended, meeting, geology)
                plist = [papers]
                if k is not None and route.rooms[k][1][r] not in rules.relic_moves:
                    plist = keep(papers, attended, taught_tier(tiers, k, r), cap)
                for p2 in plist:
                    for g in out:
                        st = (g, tuple(after[d] for d in rules.depts), frozen(p2), k if k is not None else -1)
                        if st not in seen:
                            seen.add(st)
                            nxt.add(st)
        frontier = nxt
        if not frontier:
            return None
    return None


def route_report(rules, data, rings=30):
    """The fewest rings through each real level, under the game's rules and a few others."""
    cases = [
        ("the game: another department's II paper", dict(gate="any", gate_tier=2), True),
        ("... with no keys (locked doors and gates shut)", dict(gate="any", gate_tier=2), False),
        ("... if the way on asked for no paper", dict(gate=None), True),
        ("... if it asked for a III paper", dict(gate="any", gate_tier=3), True),
        ("... if it asked for the department before's II paper", dict(gate="always", gate_tier=2), True),
    ]
    out = {}
    for name, kw, keys in cases:
        results = []
        for level in data["levels"]:
            route = Route(level, keys=keys)
            results.append(way_through(rules, route, rings=rings, **kw))
        got = [x for x in results if x is not None]
        out[name] = {"rings": results, "never": len(results) - len(got), "median": statistics.median(got) if got else None,
                     "min": min(got) if got else None, "max": max(got) if got else None}
        hist = defaultdict(int)
        for x in results:
            hist["never" if x is None else x] += 1
        print(f"{name:<55} median {out[name]['median']}, range {out[name]['min']}-{out[name]['max']}, never {out[name]['never']} of {len(results)}   {dict(sorted(hist.items(), key=lambda kv: (kv[0] == 'never', kv[0] if kv[0] != 'never' else 0)))}")
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("rules", help="the JSON tests/dump_timetable.gd wrote")
    ap.add_argument("--json", help="write every result here too")
    ap.add_argument("--rings", type=int, default=36)
    ap.add_argument("--route", action="store_true", help="only the way through real levels (fewest rings from the way in to the way on)")
    args = ap.parse_args()
    data = json.load(open(args.rules, encoding="utf-8"))
    rules = Rules(data)
    bad = check(rules, data)
    print(f"model against the game: {len(data['climb'])} climbs and {sum(len(l['rooms']) for l in data['levels'])} classrooms, {len(bad)} mismatches")
    for b in bad[:10]:
        print("  ", b)
    if bad:
        sys.exit(1)
    if args.route:
        report = {"route": route_report(rules, data)}
        if args.json:
            json.dump(report, open(args.json, "w", encoding="utf-8"), indent=1)
        return
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
    print("\nrandom play (60 rings): share of rings at II+ / III+")
    print("  " + "  ".join(f"{d}: {rp[d][0]:.2f}/{rp[d][1]:.2f}" for d in ORDER))
    print(f"  median rings to a first paper of tier III, any department: {statistics.median(firsts)}")
    print(f"  runs stuck (no choice left): {report['random']['stuck_share']:.0%}")

    # 4. Other rules for geology.
    report["geology"] = {}
    for g in ["strata", "strict_lowest", "below_average", "pressure", "lowest_or_tied"]:
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
