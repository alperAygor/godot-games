"""Switchyard text interface for BLIND playtesting. Stateless: every call rebuilds the level from its start and
applies the whole move string.

COMMANDS
  cli.py list                          playable levels
  cli.py show <level>                  draw the yard (vehicles, targets, links, legend)
  cli.py try <level> "<moves>"         apply moves, draw the result; when solved prints moves used and par
  cli.py rules                         game rules
  cli.py export-blind                  (developer) write solution-free copies to build/playtest/levels/

Default is BLIND mode: only build/playtest/levels/ is read (no solutions, no metrics). --dev reads data/levels/.

MOVE NOTATION (tokens separated by spaces)
  N3         Drive the loco toward its north-facing side and keep going the same way until the LOCO has moved
             3 cells. Directions: N NE E SE S SW W NW (up on the map = N). The direction only picks the FIRST
             step; after that the train follows the rails.
  N*         Drive the same way as far as possible (until a buffer/obstacle; touching a wagon there couples it).
  N5[NW,N]   Switch decisions met on the way, in order: the direction of the branch to leave that switch by.
             If a decision is needed and not given, the token fails and lists the options.
  L/r1       Uncouple between L and r1 (free, but the next drive counts as a new move).
Example:  python3 tools/yard/cli.py try w1-010 "N4[NW] r2/b1 S* N2"

COUNTING: one move = one uninterrupted drive in one direction, however many cells. Changing direction or
uncoupling starts a new move. "N2 N3" is a single move.
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import rules  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
DEV_DIR = os.path.join(ROOT, "data", "levels")
BLIND_DIR = os.path.join(ROOT, "build", "playtest", "levels")

COMPASS = {(0, -1): "N", (1, -1): "NE", (1, 0): "E", (1, 1): "SE", (0, 1): "S", (-1, 1): "SW", (-1, 0): "W",
           (-1, -1): "NW"}
COLOR_MARK = {"red": "R", "blue": "B", "yellow": "Y", "green": "G", "purple": "P", "orange": "O", "loco": "L"}

RULES_TEXT = """RULES
- The yard is made of cells; each cell holds at most one vehicle. You drive a single locomotive (L).
- Train = the loco plus the wagons hooked to it. Driving moves the whole train along the rails like a snake;
  it cannot turn on the spot or take a sharp turn at a switch (to go from one branch into the other you must
  pull back past the switch body and come back).
- Pushing: every wagon in front gets coupled automatically and is pushed along.
- Pulling: only coupled wagons follow.
- Uncouple (A/B): removes the hook between two coupled vehicles. Free; both stay where they are.
- A buffer (track end) or the train's own tail (on a loop) stops the train. Driving into a wagon that stands
  against a buffer couples it without moving.
- Goal: every marked cell holds a vehicle of its colour (stopped). Same-colour wagons are interchangeable.
- Move count: one uninterrupted drive in one direction = 1 move; a direction change or an uncouple starts a new one.
Special (some levels):
- Traction P: the loco can move at most P wagons (more get coupled, but the train will not budge).
- Spring switch (~): heading into its branch side always takes the same branch; no choice.
- Gate (#) and plate (_): gates are open while any vehicle stands on a plate; a closed gate cell cannot be entered.
"""


def load(level_id, dev):
    base = DEV_DIR if dev else BLIND_DIR
    path = os.path.join(base, level_id + ".json")
    if not os.path.exists(path):
        if not dev and not os.path.isdir(BLIND_DIR):
            raise SystemExit("no blind copies yet: a developer must run 'cli.py export-blind' first")
        raise SystemExit("no such level: %s" % level_id)
    with open(path) as f:
        data = json.load(f)
    return data, rules.Level(data)


def cname(level, c):
    x, y = level.pos[c]
    return "%s%d" % ("ABCDEFG"[int(x)], int(y))


def compass(level, p, q):
    (x1, y1), (x2, y2) = level.pos[p], level.pos[q]
    dx = (x2 > x1) - (x2 < x1)
    dy = (y2 > y1) - (y2 < y1)
    return COMPASS[(int(dx), int(dy))]


def vlabel(level, vid):
    if level.vtype[vid] == "loco":
        return "L "
    lab = vid[:2]
    if level.vkind[vid] == "fragile":
        lab = lab[0].upper() + lab[1:]
    return lab.ljust(2)


def render(level, st):
    W, H = 7, 11
    canvas = [[" "] * (W * 6 + 2) for _ in range(H * 2)]
    tmark = {c: COLOR_MARK[col] for (c, col) in level.targets}
    for c in range(level.n):
        x, y = int(level.pos[c][0]), int(level.pos[c][1])
        for s in (0, 1):
            for q in level.sides[c][s]:
                x2, y2 = int(level.pos[q][0]), int(level.pos[q][1])
                if (x2, y2) < (x, y):
                    continue
                if x2 == x and y2 == y + 1:
                    canvas[2 * y + 1][6 * x + 2] = "|"
                elif y2 == y and x2 == x + 1:
                    for k in range(6 * x + 4, 6 * x + 7):
                        canvas[2 * y][k] = "-"
                elif x2 == x + 1 and y2 == y + 1:
                    canvas[2 * y + 1][6 * x + 5] = "\\"
                elif x2 == x - 1 and y2 == y + 1:
                    canvas[2 * y + 1][6 * x - 1] = "/"
        v = st.at.get(c)
        if v is not None:
            content = vlabel(level, v)
        else:
            kind = level.kind[c]
            content = {"gate": " #", "plate": " _", "spring": " ~"}.get(kind, " .")
        token = content + tmark.get(c, " ")
        for k, ch in enumerate(token):
            canvas[2 * y][6 * x + 1 + k] = ch
    lines = []
    lines.append("     " + "".join(("%s" % "ABCDEFG"[x]).center(6) for x in range(W)))
    used_rows = sorted(set(int(level.pos[c][1]) for c in range(level.n)))
    lo, hi = used_rows[0], used_rows[-1]
    for r in range(2 * lo, 2 * hi + 1):
        label = "%2d   " % (r // 2) if r % 2 == 0 else "     "
        lines.append((label + "".join(canvas[r])).rstrip())
    return "\n".join(lines)


def loco_dirs(level, st):
    lc = st.pos[level.loco]
    out = []
    for s in (0, 1):
        nb = level.sides[lc][s]
        if nb:
            out.append((s, [compass(level, lc, q) for q in nb], nb))
    return out


def describe(level, st):
    lines = []
    tr = rules.train(level, st)
    lines.append("Loco L at %s.  Train (a-end..b-end): %s" % (cname(level, st.pos[level.loco]), "-".join(tr)))
    parts = []
    for s, dirs, nb in loco_dirs(level, st):
        pr = rules.probe(level, st, s)
        parts.append("%s (-> %s)%s" % ("/".join(dirs), "/".join(cname(level, q) for q in nb),
                                       "" if pr.possible else " blocked"))
    lines.append("Loco can drive: " + "  |  ".join(parts))
    vs = []
    for vid in level.vehicle_ids:
        if level.vtype[vid] == "wagon":
            vs.append("%s %s%s@%s" % (vid, level.vcolor[vid], "",
                                      cname(level, st.pos[vid])))
    lines.append("Wagons: " + ", ".join(vs))
    tg = {}
    for (c, col) in level.targets:
        tg.setdefault(col, []).append(cname(level, c))
    sat = 0
    for (c, col) in level.targets:
        v = st.at.get(c)
        if v is not None and ((col == "loco" and level.vtype[v] == "loco") or
                              (level.vtype[v] == "wagon" and level.vcolor[v] == col)):
            sat += 1
    lines.append("Targets: " + "; ".join("%s: %s" % (col, " ".join(cs)) for col, cs in tg.items()) +
                 "   (%d/%d filled)" % (sat, len(level.targets)))
    lk = sorted("-".join(sorted(k)) for k in st.links)
    lines.append("Links: " + (", ".join(lk) if lk else "none"))
    sws = []
    for c in range(level.n):
        for s in (0, 1):
            nb = level.sides[c][s]
            if len(nb) == 2:
                txt = "%s branches %s" % (cname(level, c), "/".join(compass(level, c, q) for q in nb))
                if level.kind[c] == "spring":
                    txt += " (spring: always %s)" % compass(level, c, nb[level.spring[c]])
                sws.append(txt)
    if sws:
        lines.append("Switches: " + "; ".join(sws))
    extra = []
    if level.power:
        extra.append("traction: loco moves at most %d wagon(s)" % level.power)
    gates = [cname(level, c) for c in range(level.n) if level.kind[c] == "gate"]
    plates = [cname(level, c) for c in range(level.n) if level.kind[c] == "plate"]
    if gates:
        extra.append("gates %s (%s), plates %s" % (" ".join(gates), "OPEN" if rules.gates_open(level, st)
                                                    else "CLOSED", " ".join(plates)))
    if extra:
        lines.append("Special: " + "; ".join(extra))
    lines.append("Legend: L=loco, r1=red wagon 1 (b=blue y=yellow g=green p=purple o=orange); 3rd char = target "
                 "colour of that cell (R/B/Y/G/P/O, L=loco spot); . empty rail, # gate, _ plate, ~ spring switch.")
    return "\n".join(lines)


class TokenError(Exception):
    pass


def parse_drive(tok):
    i = 0
    while i < len(tok) and tok[i] in "NSEW":
        i += 1
    d = tok[:i]
    if d not in COMPASS.values():
        raise TokenError("unknown direction: %r (N NE E SE S SW W NW)" % tok)
    rest = tok[i:]
    branches = []
    if "[" in rest:
        if not rest.endswith("]"):
            raise TokenError("switch list must end with ']': %r" % tok)
        rest, br = rest[:-1].split("[", 1)
        branches = [b.strip() for b in br.split(",") if b.strip()]
        for b in branches:
            if b not in COMPASS.values():
                raise TokenError("unknown switch direction: %r" % b)
    if rest == "*":
        count = None
    elif rest == "":
        count = 1
    elif rest.isdigit() and int(rest) > 0:
        count = int(rest)
    else:
        raise TokenError("cannot read cell count: %r" % tok)
    return d, count, branches


def apply_drive(level, st, tok, log):
    """Döner: [(side, branch, needs_branch)] uygulanan adımlar (sayım için)."""
    d, count, branches = parse_drive(tok)
    lc = st.pos[level.loco]
    side = None
    first_branch = None
    for s in (0, 1):
        nb = level.sides[lc][s]
        for k, q in enumerate(nb):
            if compass(level, lc, q) == d:
                side = s
                if len(nb) == 2:
                    first_branch = k
    if side is None:
        avail = ["/".join(dirs) for (_s, dirs, _nb) in loco_dirs(level, st)]
        raise TokenError("the loco has no rail toward %s (options: %s)" % (d, ", ".join(avail)))
    bq = list(branches)
    moved_cells = 0
    taken = []
    coupled = []
    stop_reason = ""
    guard = 0
    while count is None or moved_cells < count:
        guard += 1
        if guard > 200:
            stop_reason = "loop guard"
            break
        pr = rules.probe(level, st, side)
        br = 0
        if pr.needs_branch:
            head_is_loco = len(rules.walk(level, st, level.loco, side)) == 0
            if head_is_loco and first_branch is not None and not taken:
                br = first_branch
            elif bq:
                want = bq.pop(0)
                # karar hücresi: baş
                head = rules.walk(level, st, level.loco, side)
                hcell = st.pos[head[-1]] if head else st.pos[level.loco]
                opts = [compass(level, hcell, q) for q in pr.branch_cells]
                if want not in opts:
                    raise TokenError("switch %s has no %s branch (options: %s)" % (
                        cname(level, hcell), want, "/".join(opts)))
                br = opts.index(want)
            else:
                head = rules.walk(level, st, level.loco, side)
                hcell = st.pos[head[-1]] if head else st.pos[level.loco]
                opts = [compass(level, hcell, q) for q in pr.branch_cells]
                if count is None and moved_cells > 0:
                    stop_reason = "switch %s needs a decision (%s)" % (cname(level, hcell), "/".join(opts))
                    break
                raise TokenError("switch %s needs a branch: %s (e.g. %s%s[%s])" % (
                    cname(level, hcell), " or ".join(opts), d, "" if count is None else count, opts[0]))
        old = st.pos[level.loco]
        r = rules.step(level, st, side, br)
        if not r.effective():
            stop_reason = "blocked: %s" % {"buffer": "buffer", "self": "own train", "foul": "wagon on switch hooked to the other branch",
                                         "gate": "gate closed", "traction": "traction too low"}.get(r.blocked, r.blocked)
            break
        taken.append((side, br, pr.needs_branch))
        coupled += list(r.coupled)
        if r.moved:
            moved_cells += 1
        if r.blocked:
            stop_reason = "coupled, then blocked: %s" % r.blocked
            break
        side = rules.continue_side(level, old, st.pos[level.loco], side)
    if bq:
        raise TokenError("%d switch decision(s) unused (%s)" % (len(bq), ",".join(bq)))
    if count is not None and moved_cells < count:
        raise TokenError("asked for %d cell(s), could move %d (%s)" % (count, moved_cells, stop_reason or "?"))
    if not taken:
        raise TokenError("could not move at all (%s)" % (stop_reason or "blocked"))
    msg = "L moved %d cell(s)" % moved_cells
    if coupled:
        msg += ", coupled: %s" % " ".join(coupled)
    if stop_reason and count is None:
        msg += " (%s)" % stop_reason
    log.append(msg)
    return taken


def run_moves(level, text):
    """Döner (durum, hamle sayısı, günlük satırları, hata ya da None)."""
    st = rules.initial_state(level)
    moves = 0
    cont = None
    log = []
    for i, tok in enumerate(text.split()):
        try:
            if "/" in tok:
                a, b = tok.split("/", 1)
                if a not in level.vtype or b not in level.vtype:
                    raise TokenError("unknown vehicle id: %r" % tok)
                if not rules.uncouple(level, st, a, b):
                    raise TokenError("%s and %s are not coupled" % (a, b))
                cont = None
                log.append("%2d. %-12s uncoupled" % (i + 1, tok))
            else:
                snap = st.copy()
                sub = []
                taken = apply_drive(level, st, tok, sub)
                start_side = taken[0][0]
                if cont is None or start_side != cont:
                    moves += 1
                # devam yanı: sürüş sonundaki
                cont = _end_side(level, snap, taken)
                log.append("%2d. %-12s %s   [move %d]" % (i + 1, tok, sub[0], moves))
        except TokenError as e:
            log.append("%2d. %-12s ERROR: %s" % (i + 1, tok, e))
            return st, moves, log, str(e)
    return st, moves, log, None


def _end_side(level, st0, taken):
    st = st0.copy()
    side = taken[0][0]
    for (s, br, _nb) in taken:
        old = st.pos[level.loco]
        rules.step(level, st, s, br)
        side = rules.continue_side(level, old, st.pos[level.loco], s)
    return side


def cmd_show(args, dev):
    data, level = load(args[0], dev)
    st = rules.initial_state(level)
    print("Level %s" % level.id)
    print(render(level, st))
    print(describe(level, st))


def cmd_try(args, dev):
    if len(args) < 2:
        raise SystemExit('usage: cli.py try <level> "<moves>"')
    data, level = load(args[0], dev)
    st, moves, log, err = run_moves(level, args[1])
    print("\n".join(log))
    print()
    print(render(level, st))
    print(describe(level, st))
    print()
    if err:
        print("STOPPED: error above; the yard shown is the moment before the failing token. Moves: %d" % moves)
    elif rules.is_solved(level, st):
        print("SOLVED in %d moves (par %d)" % (moves, level.par))
    else:
        print("Not solved yet. Moves used: %d" % moves)


def cmd_list(dev):
    base = DEV_DIR if dev else BLIND_DIR
    idx = os.path.join(base, "index.json")
    if not os.path.exists(idx):
        raise SystemExit("no index: %s (cli.py export-blind)" % idx)
    with open(idx) as f:
        for e in json.load(f)["levels"]:
            print(e["id"])


def cmd_export_blind():
    os.makedirs(BLIND_DIR, exist_ok=True)
    with open(os.path.join(DEV_DIR, "index.json")) as f:
        index = json.load(f)
    out = []
    for e in index["levels"]:
        with open(os.path.join(DEV_DIR, e["id"] + ".json")) as f:
            d = json.load(f)
        for k in ("solution", "metrics"):
            d.pop(k, None)
        with open(os.path.join(BLIND_DIR, e["id"] + ".json"), "w") as f:
            json.dump(d, f, indent=1)
        out.append({"id": e["id"], "world": e["world"]})
    with open(os.path.join(BLIND_DIR, "index.json"), "w") as f:
        json.dump({"levels": out}, f, indent=1)
    print("wrote %d levels -> %s" % (len(out), BLIND_DIR))


def main(argv):
    dev = "--dev" in argv
    argv = [a for a in argv if a != "--dev"]
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        print(RULES_TEXT)
        return
    cmd, rest = argv[0], argv[1:]
    if cmd == "show" and rest:
        cmd_show(rest, dev)
    elif cmd == "try":
        cmd_try(rest, dev)
    elif cmd == "list":
        cmd_list(dev)
    elif cmd == "rules":
        print(RULES_TEXT)
    elif cmd == "export-blind":
        cmd_export_blind()
    else:
        print(__doc__)
        raise SystemExit(2)


if __name__ == "__main__":
    main(sys.argv[1:])
