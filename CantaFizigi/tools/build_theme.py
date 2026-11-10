#!/usr/bin/env python3
"""data/theme.json -> assets/theme/ui_theme.tres

Neden uretici: renk/boyut/kose yaricapi .tscn dosyalarina dagildiginda tutarlilik
bozuluyor ve her ekran ayni StyleBox'lari tekrar yaziyor (GOTCHAS.md #19).
Tek kaynak: data/theme.json. Degisiklik -> yeniden uret.

Kullanim:
    python3 tools/build_theme.py [--project .] [--check]

--check: dosya guncel degilse 1 doner (CI icin).
"""

import argparse
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def hex_to_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def rgb_to_color(rgb, alpha=1.0):
    return "Color(%.4f, %.4f, %.4f, %.4f)" % (rgb[0], rgb[1], rgb[2], alpha)


def mix(rgb_a, rgb_b, t):
    return tuple(a + (b - a) * t for a, b in zip(rgb_a, rgb_b))


def color(hex_value, alpha=1.0):
    return rgb_to_color(hex_to_rgb(hex_value), alpha)


def lighten(hex_value, t):
    return rgb_to_color(mix(hex_to_rgb(hex_value), (1.0, 1.0, 1.0), t))


def darken(hex_value, t):
    return rgb_to_color(mix(hex_to_rgb(hex_value), (0.0, 0.0, 0.0), t))


def style(id_name, bg, border, radius, px, py, border_width, swap_padding=False):
    top, bottom = (py + 4, py - 4) if swap_padding else (py, py + 4)
    return """[sub_resource type="StyleBoxFlat" id="{id}"]
content_margin_left = {px}.0
content_margin_top = {top}.0
content_margin_right = {px}.0
content_margin_bottom = {bottom}.0
bg_color = {bg}
border_width_bottom = {bw}
border_color = {border}
corner_radius_top_left = {r}
corner_radius_top_right = {r}
corner_radius_bottom_right = {r}
corner_radius_bottom_left = {r}
""".format(id=id_name, px=px, top=top, bottom=bottom, bg=bg,
           bw=border_width, border=border, r=radius)


def build(theme):
    palette = theme["palette"]
    metrics = theme["metrics"]
    radius = int(metrics["radius"])
    border = int(metrics["border"])
    px = int(metrics["padding_x"])
    py = int(metrics["padding_y"])

    blocks = []
    blocks.append(style("SB_primary", color(palette["primary"]),
                        color(palette["primary_dark"]), radius, px, py, border))
    blocks.append(style("SB_primary_hover", lighten(palette["primary"], 0.18),
                        color(palette["primary_dark"]), radius, px, py, border))
    blocks.append(style("SB_primary_pressed", darken(palette["primary"], 0.10),
                        color(palette["primary_dark"]), radius, px, py, max(1, border - 4), True))
    blocks.append(style("SB_primary_disabled", color(palette["primary"], 0.55),
                        color(palette["primary_dark"], 0.5), radius, px, py, border))

    blocks.append(style("SB_secondary", color(palette["accent"]),
                        color(palette["accent_dark"]), radius, px, py, max(1, border - 1)))
    blocks.append(style("SB_secondary_hover", lighten(palette["accent"], 0.25),
                        color(palette["accent_dark"]), radius, px, py, max(1, border - 1)))
    blocks.append(style("SB_secondary_pressed", darken(palette["accent"], 0.10),
                        color(palette["accent_dark"]), radius, px, py, 2, True))
    blocks.append(style("SB_secondary_disabled", color(palette["accent"], 0.5),
                        color(palette["accent_dark"], 0.45), radius, px, py, max(1, border - 1)))

    resources = []
    resources.append("default_font = ExtResource(\"1_font\")")
    # default_font_size KULLANILMAZ: Godot onu varyasyon aramasindan once kontrol edip
    # TitleLabel gibi tur varyasyonlarinin puntosunu golgeliyor (olculdu).
    # Taban boyutu tip uzerinden acikca verilir.
    resources.append("Label/font_sizes/font_size = %d" % int(theme["base_font_size"]))
    resources.append("Button/font_sizes/font_size = %d" % int(metrics["button_font_size"]))

    resources.append("Button/colors/font_color = %s" % color(palette["on_primary"]))
    resources.append("Button/colors/font_hover_color = %s" % color(palette["on_primary"]))
    resources.append("Button/colors/font_pressed_color = %s" % darken(palette["on_primary"], 0.15))
    resources.append("Button/colors/font_disabled_color = %s" % color(palette["on_primary"], 0.75))
    resources.append("Button/font_sizes/font_size = %d" % int(metrics["button_font_size"]))
    resources.append('Button/styles/normal = SubResource("SB_primary")')
    resources.append('Button/styles/hover = SubResource("SB_primary_hover")')
    resources.append('Button/styles/pressed = SubResource("SB_primary_pressed")')
    resources.append('Button/styles/disabled = SubResource("SB_primary_disabled")')

    resources.append('SecondaryButton/base_type = &"Button"')
    resources.append("SecondaryButton/colors/font_color = %s" % color(palette["on_accent"]))
    resources.append("SecondaryButton/colors/font_hover_color = %s" % color(palette["on_accent"]))
    resources.append("SecondaryButton/colors/font_pressed_color = %s" % darken(palette["on_accent"], 0.15))
    resources.append("SecondaryButton/colors/font_disabled_color = %s" % color(palette["on_accent"], 0.7))
    resources.append("SecondaryButton/font_sizes/font_size = %d" % int(metrics["secondary_button_font_size"]))
    resources.append('SecondaryButton/styles/normal = SubResource("SB_secondary")')
    resources.append('SecondaryButton/styles/hover = SubResource("SB_secondary_hover")')
    resources.append('SecondaryButton/styles/pressed = SubResource("SB_secondary_pressed")')
    resources.append('SecondaryButton/styles/disabled = SubResource("SB_secondary_disabled")')

    resources.append("Label/colors/font_color = %s" % color(palette["text"]))

    # NOT: Label tur varyasyonlari (TitleLabel vb.) Godot 4.7.2'de font_size/renk
    # icin UYGULANMIYOR (olculdu; stil varyasyonlari calisiyor). Bu yuzden etiket
    # punto/renkleri sahne icinde theme_override_* ile verilir (GOTCHAS.md #19).

    header = ('[gd_resource type="Theme" load_steps=%d format=3]\n\n'
              '[ext_resource type="FontFile" path="%s" id="1_font"]\n\n'
              % (len(blocks) + 2, theme["font"]))
    body = "\n".join(blocks)
    return header + body + "\n[resource]\n" + "\n".join(resources) + "\n"


def main():
    parser = argparse.ArgumentParser(description="theme.json -> ui_theme.tres")
    parser.add_argument("--project", default=".")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    project = os.path.abspath(args.project)
    theme_path = os.path.join(project, "data", "theme.json")
    out_path = os.path.join(project, "assets", "theme", "ui_theme.tres")

    if not os.path.exists(theme_path):
        print("hata: %s yok" % theme_path, file=sys.stderr)
        return 2

    with open(theme_path, encoding="utf-8") as handle:
        theme = json.load(handle)

    generated = build(theme)

    if args.check:
        current = ""
        if os.path.exists(out_path):
            with open(out_path, encoding="utf-8") as handle:
                current = handle.read()
        if current != generated:
            print("guncel degil: %s (tools/build_theme.py kosun)" % os.path.relpath(out_path, project),
                  file=sys.stderr)
            return 1
        print("tema guncel")
        return 0

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as handle:
        handle.write(generated)
    print("yazildi: %s" % os.path.relpath(out_path, project))
    return 0


if __name__ == "__main__":
    sys.exit(main())
