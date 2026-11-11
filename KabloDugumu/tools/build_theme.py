#!/usr/bin/env python3
"""data/theme.json -> assets/theme/ui_theme.tres

Neden uretici: renk/boyut/kose yaricapi .tscn dosyalarina dagildiginda tutarlilik
bozuluyor ve her ekran ayni StyleBox'lari tekrar yaziyor (GOTCHAS.md #19).
Tek kaynak: data/theme.json. Degisiklik -> yeniden uret.

Tasarim token'lari (ARCHITECTURE §15, v0.2): 8 px grid, buton yuksekligi 88-100
tasarim px, kose 20-28, Manrope. Govde fontu FontVariation'dir (wght 500):
Manrope degisken fontunun VARSAYILAN ekseni ExtraLight (200) oldugu icin
dogrudan .ttf kullanmak metni cok ince cizer (olculdu; bkz. ROADMAP riskleri).

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


def color(hex_value, alpha=1.0):
    rgb = hex_to_rgb(hex_value)
    return "Color(%.4f, %.4f, %.4f, %.4f)" % (rgb[0], rgb[1], rgb[2], alpha)


def mix(rgb_a, rgb_b, t):
    return tuple(a + (b - a) * t for a, b in zip(rgb_a, rgb_b))


def lighten(hex_value, t, alpha=1.0):
    rgb = mix(hex_to_rgb(hex_value), (1.0, 1.0, 1.0), t)
    return "Color(%.4f, %.4f, %.4f, %.4f)" % (rgb[0], rgb[1], rgb[2], alpha)


def darken(hex_value, t, alpha=1.0):
    rgb = mix(hex_to_rgb(hex_value), (0.0, 0.0, 0.0), t)
    return "Color(%.4f, %.4f, %.4f, %.4f)" % (rgb[0], rgb[1], rgb[2], alpha)


def style_flat(id_name, bg, radius, pad_x, pad_y, border="", border_color="", border_width=0):
    lines = ['[sub_resource type="StyleBoxFlat" id="%s"]' % id_name]
    lines.append("content_margin_left = %.1f" % pad_x)
    lines.append("content_margin_top = %.1f" % pad_y)
    lines.append("content_margin_right = %.1f" % pad_x)
    lines.append("content_margin_bottom = %.1f" % pad_y)
    if bg:
        lines.append("bg_color = %s" % bg)
    if border_width > 0 and border_color:
        lines.append("border_width_left = %d" % border_width)
        lines.append("border_width_top = %d" % border_width)
        lines.append("border_width_right = %d" % border_width)
        lines.append("border_width_bottom = %d" % border_width)
        lines.append("border_color = %s" % border_color)
    lines.append("corner_radius_top_left = %d" % radius)
    lines.append("corner_radius_top_right = %d" % radius)
    lines.append("corner_radius_bottom_right = %d" % radius)
    lines.append("corner_radius_bottom_left = %d" % radius)
    return "\n".join(lines) + "\n"


def build(theme):
    palette = theme["palette"]
    metrics = theme["metrics"]
    radius = int(metrics["radius"])
    radius_small = int(metrics["radius_small"])
    border = int(metrics["border"])
    pad_x = float(metrics["padding_x"])
    pad_y = float(metrics["padding_y"])
    icon_pad = float(metrics["icon_padding"])
    base_size = int(theme["base_font_size"])
    button_size = int(metrics["button_font_size"])
    secondary_size = int(metrics["secondary_button_font_size"])

    primary = palette["primary"]
    primary_dark = palette["primary_dark"]
    accent = palette["accent"]
    accent_dark = palette["accent_dark"]
    danger = palette["danger"]
    danger_dark = palette["danger_dark"]
    surface = palette["surface"]
    surface_high = palette["surface_high"]
    outline = palette["outline"]
    text = palette["text"]
    muted = palette["text_muted"]
    on_primary = palette["on_primary"]
    on_accent = palette["on_accent"]

    sub = []
    # --- birincil: mint dolgu, koyu metin ---
    sub.append(style_flat("SB_primary", color(primary), radius, pad_x, pad_y))
    sub.append(style_flat("SB_primary_hover", lighten(primary, 0.10), radius, pad_x, pad_y))
    sub.append(style_flat("SB_primary_pressed", darken(primary, 0.10), radius, pad_x,
                          max(1.0, pad_y - 2.0)))
    sub.append(style_flat("SB_primary_disabled", color(primary, 0.42), radius, pad_x, pad_y))
    # --- ikincil: amber dolgu (eski kontrat: kucuk aksiyonlar) ---
    sub.append(style_flat("SB_secondary", color(accent), radius, pad_x, pad_y))
    sub.append(style_flat("SB_secondary_hover", lighten(accent, 0.10), radius, pad_x, pad_y))
    sub.append(style_flat("SB_secondary_pressed", darken(accent, 0.10), radius, pad_x,
                          max(1.0, pad_y - 2.0)))
    sub.append(style_flat("SB_secondary_disabled", color(accent, 0.42), radius, pad_x, pad_y))
    # --- accent: sakin amber dolgu, koyu metin (v0.2 vurgu aksiyonu) ---
    sub.append(style_flat("SB_accent", color(accent), radius, pad_x, pad_y))
    sub.append(style_flat("SB_accent_hover", lighten(accent, 0.10), radius, pad_x, pad_y))
    sub.append(style_flat("SB_accent_pressed", darken(accent, 0.10), radius, pad_x,
                          max(1.0, pad_y - 2.0)))
    sub.append(style_flat("SB_accent_disabled", color(accent, 0.42), radius, pad_x, pad_y))
    # --- ghost: seffaf yuzey + ince cizgi (geri/menu gibi ikincil eylemler) ---
    ghost_base = color(outline, 0.28)
    sub.append(style_flat("SB_ghost", ghost_base, radius, pad_x, pad_y,
                          outline, color(outline, 0.60), max(1, border - 2)))
    sub.append(style_flat("SB_ghost_hover", color(surface_high, 0.85), radius, pad_x, pad_y,
                          outline, color(outline, 0.85), max(1, border - 2)))
    sub.append(style_flat("SB_ghost_pressed", color(surface, 0.95), radius, pad_x,
                          max(1.0, pad_y - 2.0), outline, color(outline, 0.85),
                          max(1, border - 2)))
    sub.append(style_flat("SB_ghost_disabled", color(outline, 0.16), radius, pad_x, pad_y,
                          outline, color(outline, 0.28), max(1, border - 2)))
    # --- icon: kare ikon butonu, yumusak yuzey ---
    icon_radius = radius_small
    sub.append(style_flat("SB_icon", color(surface_high, 0.78), icon_radius, icon_pad,
                          icon_pad, outline, color(outline, 0.55), 1))
    sub.append(style_flat("SB_icon_hover", color(surface_high, 0.95), icon_radius, icon_pad,
                          icon_pad, outline, color(outline, 0.85), 1))
    sub.append(style_flat("SB_icon_pressed", color(surface, 0.98), icon_radius, icon_pad,
                          icon_pad, outline, color(outline, 0.85), 1))
    sub.append(style_flat("SB_icon_disabled", color(surface_high, 0.34), icon_radius, icon_pad,
                          icon_pad, outline, color(outline, 0.22), 1))
    # --- danger: yumusak mercan, ghost zemin (sifirla gibi yikici eylemler) ---
    sub.append(style_flat("SB_danger", color(danger, 0.14), radius, pad_x, pad_y,
                          danger, color(danger, 0.55), max(1, border - 2)))
    sub.append(style_flat("SB_danger_hover", color(danger, 0.24), radius, pad_x, pad_y,
                          danger, color(danger, 0.85), max(1, border - 2)))
    sub.append(style_flat("SB_danger_disabled", color(danger, 0.08), radius, pad_x, pad_y,
                          danger, color(danger, 0.25), max(1, border - 2)))
    # --- kart / pill / odak ---
    sub.append(style_flat("SB_card", color(surface, 0.96), 28, 40.0, 36.0,
                          outline, color(outline, 0.70), max(1, border - 1)))
    sub.append(style_flat("SB_pill", color(surface_high, 0.80), 26, 24.0, 14.0,
                          outline, color(outline, 0.50), 1))
    sub.append('[sub_resource type="StyleBoxEmpty" id="SB_focus"]\n')

    resources = []
    resources.append('default_font = ExtResource("1_font")')
    resources.append("Label/font_sizes/font_size = %d" % base_size)
    resources.append("Label/colors/font_color = %s" % color(text))
    resources.append("Label/colors/font_shadow_color = %s" % color("#000000", 0.0))

    def button_entries(type_name, size, font_color, styles, base="Button"):
        if type_name != "Button":
            resources.append('%s/base_type = &"%s"' % (type_name, base))
        resources.append("%s/font_sizes/font_size = %d" % (type_name, size))
        resources.append("%s/colors/font_color = %s" % (type_name, font_color))
        resources.append("%s/colors/font_hover_color = %s" % (type_name, font_color))
        resources.append("%s/colors/font_pressed_color = %s" % (type_name, font_color))
        resources.append("%s/colors/font_disabled_color = %s" % (type_name, color(text, 0.55)))
        resources.append("%s/colors/font_focus_color = %s" % (type_name, font_color))
        for state in ("normal", "hover", "pressed", "disabled"):
            resources.append('%s/styles/%s = SubResource("SB_%s")' % (type_name, state, styles[state]))
        resources.append('%s/styles/focus = SubResource("SB_focus")' % type_name)

    button_entries("Button", button_size, color(on_primary),
                   {"normal": "primary", "hover": "primary_hover",
                    "pressed": "primary_pressed", "disabled": "primary_disabled"})
    button_entries("SecondaryButton", secondary_size, color(on_accent),
                   {"normal": "secondary", "hover": "secondary_hover",
                    "pressed": "secondary_pressed", "disabled": "secondary_disabled"})
    button_entries("AccentButton", secondary_size, color(on_accent),
                   {"normal": "accent", "hover": "accent_hover",
                    "pressed": "accent_pressed", "disabled": "accent_disabled"})
    button_entries("GhostButton", secondary_size, color(text),
                   {"normal": "ghost", "hover": "ghost_hover",
                    "pressed": "ghost_pressed", "disabled": "ghost_disabled"})
    button_entries("IconButton", secondary_size, color(text),
                   {"normal": "icon", "hover": "icon_hover",
                    "pressed": "icon_pressed", "disabled": "icon_disabled"})
    button_entries("DangerButton", secondary_size, color(danger),
                   {"normal": "danger", "hover": "danger_hover",
                    "pressed": "danger_hover", "disabled": "danger_disabled"})

    resources.append('PanelContainer/styles/panel = SubResource("SB_card")')
    resources.append('Pill/base_type = &"PanelContainer"')
    resources.append('Pill/styles/panel = SubResource("SB_pill")')
    resources.append('Badge/base_type = &"Label"')
    resources.append('Badge/styles/normal = SubResource("SB_badge")')
    # Badge stili pill'in kucuk ve koyu varyasyonu
    sub.insert(len(sub) - 1, style_flat("SB_badge", color("#141110", 0.92), 14, 12.0, 4.0,
                                        outline, color(outline, 0.45), 1))

    font_type = str(theme.get("font_type", "FontFile"))
    header = ('[gd_resource type="Theme" load_steps=%d format=3]\n\n'
              '[ext_resource type="%s" path="%s" id="1_font"]\n\n'
              % (len(sub) + 2, font_type, theme["font"]))
    return header + "\n".join(sub) + "\n[resource]\n" + "\n".join(resources) + "\n"


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
