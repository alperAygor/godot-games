"""Six untouched Godot window captures -> comparison sheet (python3, not -I)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
CELL_WIDTH = 432
CELL_HEIGHT = 768
GAP = 18
HEADER_HEIGHT = 132
FOOTER_HEIGHT = 54
PAPER = "#f7efe2"
INK = "#23334c"
STYLE_NAMES = ("A / TOON + OUTLINE", "B / SOFT CLAY", "C / BOLD FLAT")
FONT_PATH = "/System/Library/Fonts/Supplemental/Arial.ttf"


def main() -> None:
    title_font = ImageFont.truetype(FONT_PATH, 30)
    label_font = ImageFont.truetype(FONT_PATH, 19)
    small_font = ImageFont.truetype(FONT_PATH, 15)
    width = CELL_WIDTH * len(STYLE_NAMES) + GAP * (len(STYLE_NAMES) + 1)
    height = HEADER_HEIGHT + CELL_HEIGHT * 2 + GAP * 3 + FOOTER_HEIGHT
    sheet = Image.new("RGB", (width, height), PAPER)
    draw = ImageDraw.Draw(sheet)
    draw.text((GAP, 18), "MICRO COURIER / STYLE LAB 01", fill=INK, font=title_font)
    draw.text((GAP, 58), "Same geometry, placement and camera / wide above, detail below", fill=INK, font=label_font)
    expected_size = (720, 1280)
    for column, style in enumerate("abc"):
        x = GAP + column * (CELL_WIDTH + GAP)
        draw.text((x, 99), STYLE_NAMES[column], fill=INK, font=label_font)
        for row, frame in enumerate(("wide", "close")):
            source = Image.open(ROOT / f"style_{style}_{frame}.png").convert("RGB")
            assert source.size == expected_size, (style, frame, source.size)
            # Only the contact sheet is resized; the six source captures stay untouched.
            cell = source.resize((CELL_WIDTH, CELL_HEIGHT), Image.Resampling.LANCZOS)
            y = HEADER_HEIGHT + GAP + row * (CELL_HEIGHT + GAP)
            sheet.paste(cell, (x, y))
    draw.text((GAP, height - 32), "Godot 4.7.2 / OpenGL Compatibility / real window 720 x 1280 / no LUT, SSAO or screen-reading shader", fill=INK, font=small_font)
    sheet.save(ROOT / "style_lab_sheet.png")


if __name__ == "__main__":
    main()
