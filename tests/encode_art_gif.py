"""Encode Godot's deterministic PNG capture as a looping GIF (requires Pillow)."""
from pathlib import Path
import argparse
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument("frames", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
paths = sorted(args.frames.glob("frame_*.png"))
if len(paths) != 240:
    raise SystemExit(f"Expected 240 capture frames, found {len(paths)}")
# A common palette prevents color shimmer between frames.
with Image.open(paths[60]) as representative:
    palette = representative.convert("RGB").quantize(colors=192)
frames = []
for path in paths:
    with Image.open(path) as source:
        frames.append(source.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE))
args.output.parent.mkdir(parents=True, exist_ok=True)
frames[0].save(args.output, save_all=True, append_images=frames[1:],
               duration=[30, 30, 40] * 80, loop=0, optimize=False, disposal=1)
with Image.open(args.output) as result:
    print(f"GIF: {result.n_frames} frames, {result.size}, {args.output.stat().st_size} bytes")
