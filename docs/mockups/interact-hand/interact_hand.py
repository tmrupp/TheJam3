"""The interact hand (RisoPrompt.draw_hand), traced from a drawing of a pointing hand: pointing
left in a 600x600 space, flat pieces in one ink, and paper cuts (open strokes) where the drawing
has lines inside the silhouette. Its points are the game's (RisoPrompt.HAND_PIECES, HAND_CUTS,
HAND_GAP): change both together. Each outline is RisoShapes.smooth's curve (a quadratic through
each edge's midpoint, each point its control), each cut RisoShapes.smooth_open's.

    python interact_hand.py [reference.png]

writes interact_hand.svg, interact_hand_small.png (turned to point down, close up and at play
size) and, given the drawing it was traced from, interact_hand_preview.png (over it)."""
import sys, os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REF = sys.argv[1] if len(sys.argv) > 1 else None
GAP = 7.5          # paper either side of a cut, drawing px (RisoPrompt.HAND_GAP)
INK = "#1d2a24"
PAPER = "#ece6d6"

# The pieces, all one ink.
PIECES = [
    ("pinky", [(282, 345), (290, 395), (305, 428), (330, 446), (352, 432), (346, 398), (332, 362), (318, 340)]),
    ("ring", [(214, 340), (209, 398), (216, 444), (240, 461), (262, 446), (268, 392), (270, 340)]),
    ("middle", [(150, 342), (146, 398), (150, 428), (172, 439), (193, 426), (203, 380), (206, 342)]),
    ("hand", [(9.6, 215.3), (2.7, 197.3), (17.8, 187.4), (58.9, 166.1), (103.4, 152.1),
              (150, 142), (300, 152), (395, 190), (480, 222),
              (500, 222), (500, 383), (470, 392), (400, 392), (350, 384), (300, 338),
              (250, 296), (236, 270), (206, 222),
              (150, 198), (111.7, 199.3), (73.9, 207.4), (37.8, 222.1), (21.7, 230.2)]),
    ("thumb", [(318, 248), (250, 268), (190, 288), (142, 300), (124, 322), (138, 346), (178, 350),
               (262, 334), (336, 318)]),
]


# The cuts: open strokes of paper, GAP wide either side, along the thumb's top and its underside.
CUTS = [
    ("thumb_top", [(232, 273), (262, 263), (296, 253), (326, 246)]),
    ("thumb_under", [(160, 353), (205, 349), (262, 337), (324, 323)]),
]


def smooth_open(pts, seg=4):
    """The open curve through the ends and each inner edge's midpoint, each inner point its control."""
    out = [pts[0]]
    n = len(pts)
    for i in range(1, n - 1):
        a = pts[0] if i == 1 else ((pts[i - 1][0] + pts[i][0]) / 2, (pts[i - 1][1] + pts[i][1]) / 2)
        b = pts[-1] if i == n - 2 else ((pts[i][0] + pts[i + 1][0]) / 2, (pts[i][1] + pts[i + 1][1]) / 2)
        p = pts[i]
        for s in range(1, seg + 1):
            t = s / seg
            q0 = (a[0] + (p[0] - a[0]) * t, a[1] + (p[1] - a[1]) * t)
            q1 = (p[0] + (b[0] - p[0]) * t, p[1] + (b[1] - p[1]) * t)
            out.append((q0[0] + (q1[0] - q0[0]) * t, q0[1] + (q1[1] - q0[1]) * t))
    return out


def svg_open(pts):
    mid = lambda a, b: ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    d = [f"M{pts[0][0]:.1f},{pts[0][1]:.1f}"]
    n = len(pts)
    for i in range(1, n - 1):
        b = pts[-1] if i == n - 2 else mid(pts[i], pts[i + 1])
        d.append(f"Q{pts[i][0]:.1f},{pts[i][1]:.1f} {b[0]:.1f},{b[1]:.1f}")
    return " ".join(d)


def smooth(pts, seg=4):
    n = len(pts)
    out = []
    for i in range(n):
        p0, p, p1 = pts[i - 1], pts[i], pts[(i + 1) % n]
        a = ((p0[0] + p[0]) / 2, (p0[1] + p[1]) / 2)
        b = ((p[0] + p1[0]) / 2, (p[1] + p1[1]) / 2)
        for s in range(seg):
            t = s / seg
            q0 = (a[0] + (p[0] - a[0]) * t, a[1] + (p[1] - a[1]) * t)
            q1 = (p[0] + (b[0] - p[0]) * t, p[1] + (b[1] - p[1]) * t)
            out.append((q0[0] + (q1[0] - q0[0]) * t, q0[1] + (q1[1] - q0[1]) * t))
    return out


def svg_path(pts):
    n = len(pts)
    mid = lambda a, b: ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    m = mid(pts[-1], pts[0])
    d = [f"M{m[0]:.1f},{m[1]:.1f}"]
    for i in range(n):
        b = mid(pts[i], pts[(i + 1) % n])
        d.append(f"Q{pts[i][0]:.1f},{pts[i][1]:.1f} {b[0]:.1f},{b[1]:.1f}")
    return " ".join(d) + "Z"


def write_svg(path, view="0 120 600 360"):
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}" width="600" height="360">',
           f'<rect x="0" y="120" width="600" height="360" fill="{PAPER}"/>']
    out.append(f'<g fill="{INK}">')
    for name, pts in PIECES:
        out.append(f'  <path id="{name}" d="{svg_path(pts)}"/>')
    out.append("</g>")
    out.append(f'<g fill="none" stroke="{PAPER}" stroke-width="{GAP * 2:g}" stroke-linecap="round" stroke-linejoin="round">')
    for name, pts in CUTS:
        out.append(f'  <path id="{name}" d="{svg_open(pts)}"/>')
    out.append("</g>")
    out.append("</svg>")
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")


def preview(path, ref=None, scale=1.0):
    w, h = int(600 * scale), int(600 * scale)
    img = Image.new("RGB", (w, h), PAPER)
    d = ImageDraw.Draw(img)
    for name, pts in PIECES:
        d.polygon([(x * scale, y * scale) for x, y in smooth(pts)], fill=INK)
    r = GAP * scale
    for name, pts in CUTS:
        line = [(x * scale, y * scale) for x, y in smooth_open(pts)]
        d.line(line, fill=PAPER, width=max(1, int(GAP * 2 * scale)), joint="curve")
        for x, y in (line[0], line[-1]):
            d.ellipse((x - r, y - r, x + r, y + r), fill=PAPER)
    img = img.crop((0, int(120 * scale), w, int(480 * scale)))
    if ref:
        r = Image.open(ref).convert("RGB").resize((w, h)).crop((0, int(120 * scale), w, int(480 * scale)))
        over = Image.blend(img, r, 0.45)
        both = Image.new("RGB", (img.width, img.height * 2), PAPER)
        both.paste(img, (0, 0))
        both.paste(over, (0, img.height))
        img = both
    img.save(path)


def small(path, ref_px=48):
    """The hand turned to point down, at play size and blown up, beside a close-up, on a disc."""
    big = Image.new("RGB", (600, 600), PAPER)
    d = ImageDraw.Draw(big)
    for name, pts in PIECES:
        d.polygon(smooth(pts), fill=INK)
    for name, pts in CUTS:
        line = smooth_open(pts)
        d.line(line, fill=PAPER, width=int(GAP * 2), joint="curve")
        for x, y in (line[0], line[-1]):
            d.ellipse((x - GAP, y - GAP, x + GAP, y + GAP), fill=PAPER)
    turned = big.crop((0, 120, 600, 480)).rotate(90, expand=True, fillcolor=PAPER)
    k = ref_px / turned.height
    tiny = turned.resize((max(1, int(turned.width * k)), ref_px), Image.LANCZOS)
    out = Image.new("RGB", (tiny.width * 8 + 380, 400), (30, 34, 40))
    out.paste(turned.resize((int(turned.width * 380 / turned.height * 0.95), int(380 * 0.95))), (10, 10))
    out.paste(tiny.resize((tiny.width * 8, tiny.height * 8), Image.NEAREST), (370, 8))
    out.save(path)


write_svg(os.path.join(HERE, "interact_hand.svg"))
small(os.path.join(HERE, "interact_hand_small.png"))
if REF:
    preview(os.path.join(HERE, "interact_hand_preview.png"), REF)
print("ok")
