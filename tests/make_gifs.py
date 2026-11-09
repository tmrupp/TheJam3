"""Turn the frames a GIF capture wrote (tests/capture_*_gif.gd: frame_NNN.png in a folder of the
stills folder) into a GIF beside them, at 30 frames a second.

    python tests/make_gifs.py garden_pod_gif garden_plant_gif

Needs Pillow. Each folder <name> under ../art-captures/riso-frames becomes <name>.gif there.
"""
import sys
from pathlib import Path

from PIL import Image

STILLS = Path(__file__).resolve().parent.parent.parent / "art-captures" / "riso-frames"
# Milliseconds a frame (30 frames a second), and the colours each frame is cut down to.
FRAME_MS = 33
COLOURS = 48


def make(name: str) -> Path:
    frames = sorted((STILLS / name).glob("frame_*.png"))
    if not frames:
        raise SystemExit(f"no frames in {STILLS / name}")
    images = [Image.open(f).convert("RGB").quantize(COLOURS, method=Image.Quantize.MEDIANCUT) for f in frames]
    out = STILLS / f"{name}.gif"
    images[0].save(out, save_all=True, append_images=images[1:], duration=FRAME_MS, loop=0, optimize=True)
    return out


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        path = make(arg)
        print(f"{path} ({path.stat().st_size // 1024} KB)")
