#!/usr/bin/env python3
"""data/theme.json -> assets/theme/ui_theme.tres

Neden uretici: renk/boyut/kose yaricapi .tscn dosyalarina dagildiginda tutarlilik
bozuluyor ve her ekran ayni StyleBox'lari tekrar yaziyor. Tek kaynak:
data/theme.json. Degisiklik -> yeniden uret.

F7.6b gorsel faz: palet ve olcu token'lari buraya tasindi; UI kodunda renk sabiti
kalmaz (kod yalniz UiTheme.token() ile okur). Tum yumusak golgeler ve pill
butonlar tek yerden uretilir.

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


def stylebox(sid, bg_hex, border_hex, radius, px, py, border_width,
             bg_alpha=1.0, border_alpha=1.0, shadow_hex=None, shadow_opacity=0.0,
             shadow_size=0, shadow_offset_y=0):
    """Tek stil kutusu; golge ve esit dort kenar cizgisi destekli."""
    line = '[sub_resource type="StyleBoxFlat" id="%s"]\n' % sid
    line += "content_margin_left = %d.0\n" % px
    line += "content_margin_top = %d.0\n" % py
    line += "content_margin_right = %d.0\n" % px
    line += "content_margin_bottom = %d.0\n" % py
    line += "bg_color = %s\n" % color(bg_hex, bg_alpha)
    line += "border_width_left = %d\n" % border_width
    line += "border_width_top = %d\n" % border_width
    line += "border_width_right = %d\n" % border_width
    line += "border_width_bottom = %d\n" % border_width
    line += "border_color = %s\n" % color(border_hex, border_alpha)
    line += "corner_radius_top_left = %d\n" % radius
    line += "corner_radius_top_right = %d\n" % radius
    line += "corner_radius_bottom_right = %d\n" % radius
    line += "corner_radius_bottom_left = %d\n" % radius
    if shadow_hex is not None and shadow_size > 0:
        line += "shadow_color = %s\n" % color(shadow_hex, shadow_opacity)
        line += "shadow_size = %d\n" % shadow_size
        line += "shadow_offset = Vector2(0, %d)\n" % shadow_offset_y
    line += "\n"
    return line


def build(theme):
    palette = theme["palette"]
    metrics = theme["metrics"]
    radius = int(metrics["radius"])
    radius_pill = int(metrics["radius_pill"])
    radius_chip = int(metrics["radius_chip"])
    border = int(metrics["border"])
    px = int(metrics["padding_x"])
    py = int(metrics["padding_y"])
    px_card = int(metrics["padding_card"])
    shadow_size = int(metrics["shadow_size"])
    shadow_opacity = float(metrics["shadow_opacity"])
    shadow_offset_y = int(metrics["shadow_offset_y"])

    blocks = []
    # Birincil: turkuaz pill. Basılı durumda içerik hafif aşağı kayar.
    blocks.append(stylebox("SB_primary", palette["primary"], palette["primary_dark"],
                           radius_pill, px, py, border,
                           shadow_hex=palette["primary_dark"], shadow_opacity=0.12,
                           shadow_size=shadow_size, shadow_offset_y=shadow_offset_y))
    blocks.append(stylebox("SB_primary_hover", palette["primary"], palette["primary_dark"],
                           radius_pill, px, py, border,
                           shadow_hex=palette["primary_dark"], shadow_opacity=0.16,
                           shadow_size=shadow_size, shadow_offset_y=shadow_offset_y))
    blocks.append(stylebox("SB_primary_pressed", palette["primary_dark"], palette["primary_dark"],
                           radius_pill, px, py + 4, border,
                           shadow_hex=palette["primary_dark"], shadow_opacity=0.18,
                           shadow_size=int(shadow_size * 0.6), shadow_offset_y=int(shadow_offset_y * 0.4)))
    blocks.append(stylebox("SB_primary_disabled", palette["primary"], palette["primary_dark"],
                           radius_pill, px, py, border, bg_alpha=0.45, border_alpha=0.4))

    # İkincil: beyaz kart, ince iç çizgi; ikincil eylemler.
    # Modern düz görünüm: çizgi/gölge yok, yalnız soluk dolgu.
    blocks.append(stylebox("SB_secondary", palette["text"], palette["text"],
                           radius_pill, px, py, border, bg_alpha=0.07, border_alpha=0.0))
    blocks.append(stylebox("SB_secondary_hover", palette["text"], palette["text"],
                           radius_pill, px, py, border, bg_alpha=0.11, border_alpha=0.0))
    blocks.append(stylebox("SB_secondary_pressed", palette["text"], palette["text"],
                           radius_pill, px, py + 3, border, bg_alpha=0.15, border_alpha=0.0))
    blocks.append(stylebox("SB_secondary_disabled", palette["text"], palette["text"],
                           radius_pill, px, py, border, bg_alpha=0.04, border_alpha=0.0))

    # Kart: beyaz %90, buyuk radius, cok ince golge + ic cizgi.
    blocks.append(stylebox("SB_card", palette["surface"], palette["text"],
                           radius, px_card, px_card, border, bg_alpha=0.96, border_alpha=0.0,
                           shadow_hex=palette["text"], shadow_opacity=shadow_opacity,
                           shadow_size=shadow_size, shadow_offset_y=shadow_offset_y))

    # Cip (hap): kucuk bilgi kapsulu (cuzdan, odul).
    blocks.append(stylebox("SB_chip", palette["text"], palette["text"],
                           radius_chip, px_card, int(py * 0.7), border, bg_alpha=0.06, border_alpha=0.0))

    # Ilerleme cubugu yolu ve dolgusu (dolgu rengi HUD'da canli degisir).
    blocks.append(stylebox("SB_bar_track", palette["text"], palette["text"],
                           radius_pill, 0, 0, 0, bg_alpha=0.10, border_alpha=0.0))
    blocks.append(stylebox("SB_bar_fill", palette["primary"], palette["primary"],
                           radius_pill, 0, 0, 0, bg_alpha=1.0, border_alpha=0.0))

    resources = []
    resources.append("default_font = ExtResource(\"1_font\")")
    resources.append("Label/colors/font_color = %s" % color(palette["text"]))
    resources.append("Label/font_sizes/font_size = %d" % int(theme["base_font_size"]))

    # Birincil buton (Buton turunun varsayilani).
    resources.append("Button/colors/font_color = %s" % color(palette["on_primary"]))
    resources.append("Button/colors/font_hover_color = %s" % color(palette["on_primary"]))
    resources.append("Button/colors/font_pressed_color = %s" % darken(palette["on_primary"], 0.12))
    resources.append("Button/colors/font_disabled_color = %s" % color(palette["on_primary"], 0.7))
    resources.append("Button/font_sizes/font_size = %d" % int(metrics["button_font_size"]))
    resources.append('Button/styles/normal = SubResource("SB_primary")')
    resources.append('Button/styles/hover = SubResource("SB_primary_hover")')
    resources.append('Button/styles/pressed = SubResource("SB_primary_pressed")')
    resources.append('Button/styles/disabled = SubResource("SB_primary_disabled")')

    # İkincil buton turu.
    resources.append('SecondaryButton/base_type = &"Button"')
    resources.append("SecondaryButton/colors/font_color = %s" % color(palette["on_surface"]))
    resources.append("SecondaryButton/colors/font_hover_color = %s" % color(palette["on_surface"]))
    resources.append("SecondaryButton/colors/font_pressed_color = %s" % darken(palette["on_surface"], 0.12))
    resources.append("SecondaryButton/colors/font_disabled_color = %s" % color(palette["on_surface"], 0.5))
    resources.append("SecondaryButton/font_sizes/font_size = %d" % int(metrics["secondary_button_font_size"]))
    resources.append('SecondaryButton/styles/normal = SubResource("SB_secondary")')
    resources.append('SecondaryButton/styles/hover = SubResource("SB_secondary_hover")')
    resources.append('SecondaryButton/styles/pressed = SubResource("SB_secondary_pressed")')
    resources.append('SecondaryButton/styles/disabled = SubResource("SB_secondary_disabled")')

    # Kart ve cip panel turleri (stil varyasyonlari Godot 4.7'de calisir).
    resources.append('CardPanel/base_type = &"PanelContainer"')
    resources.append('CardPanel/styles/panel = SubResource("SB_card")')
    resources.append('ChipPanel/base_type = &"PanelContainer"')
    resources.append('ChipPanel/styles/panel = SubResource("SB_chip")')

    # Ilerleme cubugu varsayilanlari.
    resources.append('ProgressBar/styles/background = SubResource("SB_bar_track")')
    resources.append('ProgressBar/styles/fill = SubResource("SB_bar_fill")')

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
