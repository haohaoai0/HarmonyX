from pathlib import Path

from PIL import Image


CANVAS_SIZE = 1024
LOGO_CANVAS_SIZE = 660
PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = PROJECT_ROOT / "assets" / "app-icons" / "x-logo-2025-preview.png"
MEDIA_DIRECTORY = (
    PROJECT_ROOT / "AppScope" / "resources" / "base" / "media"
)


def main() -> None:
    source = Image.open(SOURCE_PATH).convert("RGBA")

    mask = source.getchannel("A")
    if mask.getbbox() is None:
        raise RuntimeError("The X logo source contains no visible pixels")

    logo = mask.resize((LOGO_CANVAS_SIZE, LOGO_CANVAS_SIZE), Image.Resampling.LANCZOS)
    offset = ((CANVAS_SIZE - LOGO_CANVAS_SIZE) // 2, (CANVAS_SIZE - LOGO_CANVAS_SIZE) // 2)
    MEDIA_DIRECTORY.mkdir(parents=True, exist_ok=True)

    variants = [
        ("black", (0, 0, 0), (255, 255, 255)),
        ("white", (255, 255, 255), (0, 0, 0)),
    ]
    for suffix, background, foreground in variants:
        image = Image.new("RGB", (CANVAS_SIZE, CANVAS_SIZE), background)
        logo_layer = Image.new("RGB", (LOGO_CANVAS_SIZE, LOGO_CANVAS_SIZE), foreground)
        image.paste(logo_layer, offset, logo)
        path = MEDIA_DIRECTORY / f"alt_icon_x_{suffix}.png"
        image.save(path, format="PNG", optimize=True)
        print(f"{path.name}: {image.size}, {image.mode}, {path.stat().st_size} bytes")

    print(f"Source raster: {source.size}; centered mark: {logo.getbbox()}")


if __name__ == "__main__":
    main()
