"""Resize the approved artwork into Android launcher resources (requires Pillow)."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/branding/app_icon.png"
RES = ROOT / "android/app/src/main/res"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def main():
    with Image.open(SOURCE) as artwork:
        if artwork.width != artwork.height:
            raise ValueError("Launcher artwork must be square; do not crop it.")
        artwork = artwork.convert("RGB")
        for density, scale in DENSITIES.items():
            directory = RES / f"mipmap-{density}"
            directory.mkdir(parents=True, exist_ok=True)

            # Legacy launchers use the exact approved square composition.
            size = round(48 * scale)
            artwork.resize((size, size), Image.Resampling.LANCZOS).save(
                directory / "ic_launcher.png"
            )

            # Adaptive layers are 108dp. Inset the complete source image so the
            # owl's ear tips stay inside the safe area under launcher masks.
            canvas_size = round(108 * scale)
            image_size = round(70 * scale)
            foreground = Image.new("RGBA", (canvas_size, canvas_size))
            inset = (canvas_size - image_size) // 2
            foreground.paste(
                artwork.resize((image_size, image_size), Image.Resampling.LANCZOS),
                (inset, inset),
            )
            foreground.save(directory / "ic_launcher_foreground.png")
            print(f"{density}: legacy {size}px, adaptive {canvas_size}px")


if __name__ == "__main__":
    main()
