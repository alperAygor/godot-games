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


def style(id_name, bg, radius, px, py, radius_bottom=None):
    """Duz, cizgisiz, golgesiz StyleBox (kullanici tercihi: minimal modern arayuz)."""
    rb = radius if radius_bottom is None else radius_bottom
    return """[sub_resource type="StyleBoxFlat" id="{id}"]
content_margin_left = {px}.0
content_margin_top = {py}.0
content_margin_right = {px}.0
content_margin_bottom = {py}.0
bg_color = {bg}
corner_radius_top_left = {r}
corner_radius_top_right = {r}
corner_radius_bottom_right = {rb}
corner_radius_bottom_left = {rb}
anti_aliasing = true
anti_aliasing_size = 1.5
""".format(id=id_name, px=px, py=py, bg=bg, r=radius, rb=rb)


def button_states(blocks, resources, prefix, base, text_hex, font_size, radius, px, py):
    """Bir dugme turu icin normal/hover/pressed/disabled/focus. Basili: biraz koyu, golge yok."""
    blocks.append(style("SB_%s" % prefix, color(base), radius, px, py))
    blocks.append(style("SB_%s_hover" % prefix, lighten(base, 0.08), radius, px, py))
    blocks.append(style("SB_%s_pressed" % prefix, darken(base, 0.09), radius, px, py))
    blocks.append(style("SB_%s_disabled" % prefix, color(base, 0.5), radius, px, py))
    name = "Button" if prefix == "primary" else {"secondary": "SecondaryButton"}[prefix]
    if prefix != "primary":
        resources.append('%s/base_type = &"Button"' % name)
    resources.append("%s/colors/font_color = %s" % (name, color(text_hex)))
    resources.append("%s/colors/font_hover_color = %s" % (name, color(text_hex)))
    resources.append("%s/colors/font_pressed_color = %s" % (name, darken(text_hex, 0.1)))
    resources.append("%s/colors/font_focus_color = %s" % (name, color(text_hex)))
    resources.append("%s/colors/font_disabled_color = %s" % (name, color(text_hex, 0.6)))
    resources.append("%s/colors/icon_normal_color = %s" % (name, color(text_hex)))
    resources.append("%s/colors/icon_hover_color = %s" % (name, color(text_hex)))
    resources.append("%s/colors/icon_pressed_color = %s" % (name, color(text_hex)))
    resources.append("%s/constants/icon_max_width = 44" % name)
    resources.append("%s/constants/h_separation = 16" % name)
    resources.append("%s/font_sizes/font_size = %d" % (name, font_size))
    resources.append('%s/styles/normal = SubResource("SB_%s")' % (name, prefix))
    resources.append('%s/styles/hover = SubResource("SB_%s_hover")' % (name, prefix))
    resources.append('%s/styles/pressed = SubResource("SB_%s_pressed")' % (name, prefix))
    resources.append('%s/styles/disabled = SubResource("SB_%s_disabled")' % (name, prefix))
    resources.append('%s/styles/focus = SubResource("SB_empty")' % name)


def build(theme):
    palette = theme["palette"]
    metrics = theme["metrics"]
    radius = int(metrics["radius"])
    px = int(metrics["padding_x"])
    py = int(metrics["padding_y"])
    sheet_r = int(metrics["sheet_radius"])

    blocks = []
    resources = []
    blocks.append('[sub_resource type="StyleBoxEmpty" id="SB_empty"]\n')
    resources.append("default_font = ExtResource(\"1_font\")")
    # default_font_size KULLANILMAZ: Godot onu varyasyon aramasindan once kontrol edip
    # TitleLabel gibi tur varyasyonlarinin puntosunu golgeliyor (olculdu).
    # Taban boyutu tip uzerinden acikca verilir.
    resources.append("Label/font_sizes/font_size = %d" % int(theme["base_font_size"]))
    resources.append("Label/colors/font_color = %s" % color(palette["text"]))
    resources.append("RichTextLabel/colors/default_color = %s" % color(palette["text"]))
    resources.append("RichTextLabel/font_sizes/normal_font_size = %d" % int(theme["base_font_size"]))

    button_states(blocks, resources, "primary", palette["primary"], palette["on_primary"],
                  int(metrics["button_font_size"]), radius, px, py)
    button_states(blocks, resources, "secondary", palette["accent"], palette["on_accent"],
                  int(metrics["secondary_button_font_size"]), radius, px, py)

    # Paneller: krem alt sayfa (SheetPanel) ve yari saydam hap (ChipPanel). Cizgi/golge yok.
    blocks.append(style("SB_sheet", color(palette["sheet"]), sheet_r,
                        int(metrics["sheet_padding_x"]), int(metrics["sheet_padding_y"])))
    blocks.append(style("SB_chip", color("#FFFFFF", 0.62), 60,
                        int(metrics["chip_padding_x"]), int(metrics["chip_padding_y"])))
    resources.append('SheetPanel/base_type = &"PanelContainer"')
    resources.append('SheetPanel/styles/panel = SubResource("SB_sheet")')
    resources.append('ChipPanel/base_type = &"PanelContainer"')
    resources.append('ChipPanel/styles/panel = SubResource("SB_chip")')

    # NOT: Label tur varyasyonlari (TitleLabel vb.) Godot 4.7.2'de font_size/renk
    # icin UYGULANMIYOR (olculdu; stil varyasyonlari calisiyor). Bu yuzden etiket
    # punto/renkleri kodda/sahnede theme_override_* ile verilir (GOTCHAS.md #19).

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
