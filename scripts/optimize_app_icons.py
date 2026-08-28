from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
targets = [
    root / "assets/images/icon.png",
    root / "assets/images/splash-icon.png",
    root / "assets/images/favicon.png",
    root / "assets/images/android-icon-foreground.png",
]

for target in targets:
    with Image.open(target) as source:
        image = source.convert("RGB")
        image.thumbnail((512, 512), Image.Resampling.LANCZOS)
        image.save(target, "PNG", optimize=True, compress_level=9)
        print(f"Optimized {target.name}: {image.size[0]}x{image.size[1]}")
