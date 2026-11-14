#!/usr/bin/env python3
"""Proje temasını (assets/theme/main_theme.tres) üretir: "nazik modern" görünüm.

Kullanım: python3 tools/build_theme.py
Renkler Figma'daki "Yurt Idle — Arayüz" dosyasındaki değişkenlerle aynı tutulur (PALETTE).
Tema dosyasını elle düzenleme; burada değiştirip betiği yeniden çalıştır.
"""
import os
import re

PALETTE = {
    # Stil A "Kâğıt Ofis" (Figma: Döviz Bürosu — Arayüz). Krem kâğıt, mürekkep, damga kırmızısı.
    "bg": "#CFC6A4",          # ekran zemini
    "surface": "#E2D9B8",     # kart / panel (kâğıt)
    "surface-2": "#D3C9A3",   # kart içi ikincil yüzey
    "line": "#8F8561",        # ince ayraç / kenar
    "text": "#25221A",        # mürekkep
    "text-muted": "#5E5640",
    "primary": "#587A3B",     # onay damgası yeşili: tamamla / ilerle
    "primary-down": "#46612E",
    "gold": "#C9A03A",        # reddet / uyarı
    "gold-soft": "#E8D9A0",
    "danger": "#A83A2C",      # polis / el koy
    "danger-down": "#872F23",
    "danger-soft": "#D9B5A3",
    "gold-down": "#A8832C",
    "ok-soft": "#BFCDA0",
    "info": "#3F5E73",        # mürekkep mavisi
    "info-down": "#314A5B",
    "info-soft": "#B4C2C4",
    "disabled": "#A99F7E",
    "ink": "#25221A",
    "window": "#2B3832",      # müşteri camı (koyu yeşil çerçeve)
    "window-line": "#161C18",
    "window-text": "#F5EEDC",
    "desk": "#46523D",        # tezgâh (yeşil keçe)
    "desk-line": "#2F3829",
    "desk-text": "#EDE5CF",
    "doc": "#E6DDB5",         # kimlik / beyan kâğıdı
    "doc-line": "#9A7F3C",
    "doc-text": "#3A2E22",
    "dim": "#1A1712",         # sayfa arkası kararma
    # Gişe sahnesi (Papers, Please / Buckshot Roulette havası): loş, yeşilimsi gri duvar, kehribar LCD, pirinç plaka.
    "booth": "#14110E",
    "booth-line": "#8A6A2B",
    "hud-amber": "#D9A845",
    "hud-amber-dim": "#9C7F42",
    "hud-clock": "#F0C24E",
    "hud-pay": "#9CCB7E",
    "brass": "#A8873C",
    "brass-line": "#6B4F1D",
    "brass-text": "#2E1F08",
    "metal": "#2A2F2D",
    "metal-down": "#1B1F1E",
    "metal-line": "#56625D",
    "receipt": "#E6DFC4",
    "receipt-line": "#9A9172",
    "tray": "#0C0B0A",
}
# Piksel görünümü (Faz 12b): keskin köşe, kalın koyu kenar, bulanıklaşmayan SERT kayık gölge (aynı bloğun koyu kopyası gibi).
PIXEL = True
FONT_SCALE = 1.32                         # VT323, Baloo'ya göre küçük durur
PIXEL_LINE = "#14120E"                    # kart/düğme kenarı (neredeyse siyah, sıcak)
SHADOW = (0.0, 0.0, 0.0, 0.40)            # kart: sert kayık gölge
HARD_SHADOW = (0.0, 0.0, 0.0, 0.55)       # düğme: biraz daha koyu


def rgba_hex(hex_color, alpha=1.0):
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return "Color(%.4g, %.4g, %.4g, %g)" % (r, g, b, alpha)


def rgba(name, alpha=1.0):
    h = PALETTE[name].lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return "Color(%.4g, %.4g, %.4g, %g)" % (r, g, b, alpha)


class Theme:
    def __init__(self):
        self.subs = []
        self.ext = []
        self.props = []
        self._ids = set()

    def box(self, id_, bg, alpha=1.0, radius=16, margin=(20, 14, 20, 14), shadow=True, border=None, border_w=0,
            radius_corners=None, hard=False):
        assert id_ not in self._ids
        self._ids.add(id_)
        lines = ['[sub_resource type="StyleBoxFlat" id="%s"]' % id_]
        for side, val in zip(("left", "top", "right", "bottom"), margin):
            lines.append("content_margin_%s = %s" % (side, float(val)))
        lines.append("bg_color = %s" % rgba(bg, alpha))
        if PIXEL:
            # Her yüzeyin koyu, kalın bir kenarı olur (zeminle karışmasın); kenar rengi bilinmiyorsa piksel çizgisi.
            if not border and (shadow or alpha >= 0.9) and radius > 4:
                border, border_w = "__pixel__", 3
            elif border:
                border_w = max(border_w, 3)
        if border:
            for side in ("left", "top", "right", "bottom"):
                lines.append("border_width_%s = %d" % (side, border_w))
            lines.append("border_color = %s" % (rgba_hex(PIXEL_LINE) if border == "__pixel__" or PIXEL else rgba(border)))
        corners = radius_corners or (radius, radius, radius, radius)
        if PIXEL:
            corners = tuple(0 if c <= 24 else 4 for c in corners)  # tam keskin; yalnızca çok büyük köşe 4 px'e iner
        for corner, val in zip(("top_left", "top_right", "bottom_right", "bottom_left"), corners):
            lines.append("corner_radius_%s = %d" % (corner, val))
        lines.append("corner_detail = 1" if PIXEL else "corner_detail = 8")
        if PIXEL:
            lines.append("anti_aliasing = false")
        else:
            lines.append("anti_aliasing_size = 1.2")
        if shadow and hard:
            lines.append("shadow_color = Color(%g, %g, %g, %g)" % HARD_SHADOW)
            lines.append("shadow_size = %d" % (1 if PIXEL else 3))
            lines.append("shadow_offset = Vector2(%d, %d)" % ((3, 4) if PIXEL else (0, 2)))
        elif shadow:
            lines.append("shadow_color = Color(%g, %g, %g, %g)" % SHADOW)
            lines.append("shadow_size = %d" % (1 if PIXEL else 6))
            lines.append("shadow_offset = Vector2(%d, %d)" % ((4, 4) if PIXEL else (0, 2)))
        self.subs.append("\n".join(lines) + "\n")
        return 'SubResource("%s")' % id_

    def empty(self, id_):
        self.subs.append('[sub_resource type="StyleBoxEmpty" id="%s"]\n' % id_)
        return 'SubResource("%s")' % id_

    def font(self, id_, path):
        self.ext.append('[ext_resource type="FontVariation" path="%s" id="%s"]' % (path, id_))
        return 'ExtResource("%s")' % id_

    def set(self, key, value):
        self.props.append("%s = %s" % (key, value))

    def variation(self, name, base):
        self.set("%s/base_type" % name, '&"%s"' % base)

    def label(self, name, color, size, alpha=1.0, font=None, outline=None):
        self.variation(name, "Label")
        self.set("%s/colors/font_color" % name, rgba(color, alpha))
        self.set("%s/font_sizes/font_size" % name, size)
        if font:
            self.set("%s/fonts/font" % name, font)
        if outline:
            self.set("%s/colors/font_outline_color" % name, rgba(outline[0], outline[2] if len(outline) > 2 else 1.0))
            self.set("%s/constants/outline_size" % name, outline[1])

    def panel(self, name, style):
        self.variation(name, "PanelContainer")
        self.set("%s/styles/panel" % name, style)

    def button(self, name, normal, pressed, disabled, font_color="surface", disabled_color="text-muted", size=30,
               icon=36, font=None, hover=None):
        self.variation(name, "Button")
        for state in ("font_color", "font_pressed_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"):
            self.set("%s/colors/%s" % (name, state), rgba(font_color))
        self.set("%s/colors/font_disabled_color" % name, rgba(disabled_color))
        self.set("%s/colors/icon_disabled_color" % name, "Color(1, 1, 1, 0.6)")
        self.set("%s/constants/icon_max_width" % name, icon)
        self.set("%s/constants/h_separation" % name, 10)
        self.set("%s/font_sizes/font_size" % name, size)
        if font:
            self.set("%s/fonts/font" % name, font)
        self.set("%s/styles/normal" % name, normal)
        self.set("%s/styles/hover" % name, hover or normal)
        self.set("%s/styles/pressed" % name, pressed)
        self.set("%s/styles/hover_pressed" % name, pressed)
        self.set("%s/styles/disabled" % name, disabled)
        self.set("%s/styles/focus" % name, 'SubResource("SB_empty")')

    def write(self, path):
        out = ["[gd_resource type=\"Theme\" format=3]", ""]
        out += self.ext + [""]
        out += self.subs
        out.append("[resource]")
        out += [re.sub(r"(font_sizes/font_size|default_font_size) = (\d+)", lambda m: "%s = %d" % (m.group(1), round(int(m.group(2)) * FONT_SCALE)), line)
                for line in self.props]
        with open(path, "w") as f:
            f.write("\n".join(out) + "\n")


def build():
    t = Theme()
    semibold = t.font("F_semibold", "res://assets/fonts/vt_regular.tres")
    bold = t.font("F_bold", "res://assets/fonts/vt_bold.tres")
    # Yazı tipi VT323 (piksel terminal; rakamları net). Dar ve uzun olduğundan boyutlar FONT_SCALE ile büyütülür.
    px = bold
    t.empty("SB_empty")

    # Temel kontroller (menü, ayarlar)
    t.set("default_font", semibold)
    t.set("default_font_size", 30)
    btn = t.box("SB_btn", "primary", radius=18, margin=(24, 14, 24, 16), hard=True)
    btn_down = t.box("SB_btn_down", "primary-down", radius=18, margin=(24, 18, 24, 12), shadow=False)
    btn_off = t.box("SB_btn_off", "surface-2", radius=18, margin=(24, 14, 24, 16), shadow=False, border="line", border_w=2)
    t.props += [
        'Button/colors/font_color = %s' % rgba("surface"),
        'Button/colors/font_pressed_color = %s' % rgba("surface"),
        'Button/colors/font_hover_color = %s' % rgba("surface"),
        'Button/colors/font_focus_color = %s' % rgba("surface"),
        'Button/colors/font_disabled_color = %s' % rgba("text-muted"),
        'Button/font_sizes/font_size = 28',
        'Button/styles/normal = %s' % btn, 'Button/styles/hover = %s' % btn, 'Button/styles/pressed = %s' % btn_down,
        'Button/styles/disabled = %s' % btn_off, 'Button/styles/focus = SubResource("SB_empty")',
        'CheckButton/font_sizes/font_size = 30',
        'Label/colors/font_color = %s' % rgba("text"),
        'Label/font_sizes/font_size = 30',
        'Panel/styles/panel = %s' % t.box("SB_bg", "booth", radius=0, margin=(0, 0, 0, 0), shadow=False),
        'PopupMenu/constants/v_separation = 28',
        'PopupMenu/font_sizes/font_size = 32',
    ]
    # Ayar satırları (CheckButton, OptionButton): beyaz kart, koyu yazı
    row = t.box("SB_row", "surface", radius=16, margin=(28, 18, 24, 20), border="line", border_w=2)
    row_down = t.box("SB_row_down", "surface-2", radius=16, margin=(28, 18, 24, 20), shadow=False, border="line", border_w=2)
    for kind in ("CheckButton", "OptionButton"):
        for state in ("font_color", "font_pressed_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"):
            t.set("%s/colors/%s" % (kind, state), rgba("text"))
        t.set("%s/styles/normal" % kind, row)
        t.set("%s/styles/hover" % kind, row)
        t.set("%s/styles/pressed" % kind, row_down)
        t.set("%s/styles/hover_pressed" % kind, row_down)
        t.set("%s/styles/focus" % kind, 'SubResource("SB_empty")')
    t.set("OptionButton/font_sizes/font_size", 30)
    slider = t.box("SB_slider", "line", radius=8, margin=(0, 8, 0, 8), shadow=False)
    slider_fill = t.box("SB_slider_fill", "primary", radius=8, margin=(0, 8, 0, 8), shadow=False)
    t.set("HSlider/styles/slider", slider)
    t.set("HSlider/styles/grabber_area", slider_fill)
    t.set("HSlider/styles/grabber_area_highlight", slider_fill)
    t.label("TitleLabel", "text", 56, font=px)
    t.label("SubtitleLabel", "text-muted", 24)

    # HUD
    pill = t.box("SB_pill", "surface", radius=16, margin=(22, 10, 22, 12), border="line", border_w=2)
    t.panel("PillPanel", pill)
    t.panel("HudPanel", pill)
    t.panel("DockPanel", t.box("SB_dock", "surface", radius=16, margin=(14, 12, 14, 14), border="line", border_w=2))
    t.panel("RibbonPanel", t.box("SB_ribbon", "surface", radius=16, margin=(16, 4, 16, 6), border="line", border_w=2))
    t.label("MoneyLabel", "text", 44, font=bold)
    t.label("IncomeLabel", "primary", 22)
    t.label("PillLabel", "text", 24)
    t.label("SmallLabel", "text-muted", 20)
    t.label("ToastLabel", "text", 28, font=bold, outline=("surface", 12, 0.95))
    bar_bg = t.box("SB_bar_bg", "line", radius=7, margin=(0, 0, 0, 0), shadow=False)
    bar_fill = t.box("SB_bar_fill", "gold", radius=7, margin=(0, 0, 0, 0), shadow=False)
    t.set("ProgressBar/styles/background", bar_bg)
    t.set("ProgressBar/styles/fill", bar_fill)
    t.variation("PowerBar", "ProgressBar")
    t.set("PowerBar/styles/background", bar_bg)
    t.set("PowerBar/styles/fill", bar_fill)
    t.variation("MilestoneBar", "ProgressBar")
    t.set("MilestoneBar/styles/background", bar_bg)
    t.set("MilestoneBar/styles/fill", t.box("SB_mile_fill", "primary", radius=7, margin=(0, 0, 0, 0), shadow=False))

    # Butonlar
    t.button("UpgradeButton", btn, btn_down, btn_off, size=26, icon=30, font=bold)
    rep = t.box("SB_repair", "danger", radius=18, margin=(20, 14, 20, 16), hard=True)
    rep_down = t.box("SB_repair_down", "danger-down", radius=18, margin=(20, 18, 20, 12), shadow=False)
    t.button("RepairButton", rep, rep_down, btn_off, size=26, icon=30, font=bold)
    nav = t.box("SB_nav", "surface-2", radius=16, margin=(8, 6, 8, 8), shadow=False)
    nav_down = t.box("SB_nav_down", "line", radius=16, margin=(8, 7, 8, 7), shadow=False)
    t.button("NavButton", nav, nav_down, nav, font_color="text", disabled_color="text-muted", size=18, icon=40)
    mv = t.box("SB_move", "primary", radius=16, margin=(18, 10, 24, 12), hard=True)
    mv_down = t.box("SB_move_down", "primary-down", radius=16, margin=(18, 14, 24, 8), shadow=False)
    mv_off = t.box("SB_move_off", "disabled", radius=16, margin=(18, 10, 24, 12), shadow=False)
    t.button("MoveButton", mv, mv_down, mv_off)
    ghost = t.box("SB_ghost", "surface-2", radius=16, margin=(18, 10, 18, 12), shadow=False, border="line", border_w=2)
    ghost_down = t.box("SB_ghost_down", "line", radius=16, margin=(18, 11, 18, 11), shadow=False, border="line", border_w=2)
    t.button("GhostButton", ghost, ghost_down, ghost, font_color="text", disabled_color="text-muted", size=22, icon=28)
    warn = t.box("SB_warn", "gold", radius=18, margin=(20, 14, 20, 16), hard=True)
    warn_down = t.box("SB_warn_down", "gold-down", radius=18, margin=(20, 18, 20, 12), shadow=False)
    t.button("WarnButton", warn, warn_down, btn_off, font_color="ink", size=26, icon=30, font=bold)
    t.button("KeyButton", ghost, ghost_down, ghost, font_color="text", disabled_color="text-muted", size=38, icon=28, font=bold)
    seg = t.box("SB_seg", "surface-2", radius=14, margin=(14, 8, 14, 10), shadow=False, border="line", border_w=2)
    seg_on = t.box("SB_seg_on", "text", radius=14, margin=(14, 8, 14, 10), shadow=False, border="text", border_w=2)
    t.variation("SegmentButton", "Button")
    for state in ("font_color", "font_hover_color", "font_focus_color"):
        t.set("SegmentButton/colors/%s" % state, rgba("text"))
    for state in ("font_pressed_color", "font_hover_pressed_color"):
        t.set("SegmentButton/colors/%s" % state, rgba("surface"))
    t.set("SegmentButton/font_sizes/font_size", 22)
    t.set("SegmentButton/styles/normal", seg)
    t.set("SegmentButton/styles/hover", seg)
    t.set("SegmentButton/styles/pressed", seg_on)
    t.set("SegmentButton/styles/hover_pressed", seg_on)
    t.set("SegmentButton/styles/focus", 'SubResource("SB_empty")')

    # Kartlar ve paneller
    t.panel("SheetPanel", t.box("SB_sheet", "surface", radius=0, margin=(24, 14, 24, 24),
                                radius_corners=(20, 20, 0, 0), border="line", border_w=2))
    t.panel("FloatCard", t.box("SB_float", "surface", radius=16, margin=(22, 18, 22, 20), border="line", border_w=2))
    t.panel("CardPanel", t.box("SB_card", "surface-2", radius=16, margin=(14, 12, 14, 12), shadow=False, border="line", border_w=2))
    t.panel("CardBrokenPanel", t.box("SB_card_broken", "danger-soft", radius=16, margin=(14, 12, 14, 12), shadow=False, border="danger", border_w=2))
    t.panel("BadgePanel", t.box("SB_badge", "info-soft", radius=14, margin=(6, 4, 6, 6), shadow=False))
    t.panel("TagPanel", t.box("SB_tag", "danger", radius=8, margin=(10, 2, 10, 4), shadow=False))
    t.panel("GoalPanel", t.box("SB_goal", "surface", radius=16, margin=(28, 24, 28, 28), border="line", border_w=2))
    t.panel("ChipPanel", t.box("SB_chip", "ink", alpha=0.82, radius=16, margin=(16, 10, 16, 12)))
    t.panel("UpgradeChip", t.box("SB_up_chip", "primary", radius=16, margin=(12, 4, 16, 6), shadow=False))
    t.panel("UpgradeChipOff", t.box("SB_up_chip_off", "text-muted", radius=16, margin=(12, 4, 16, 6), shadow=False))
    t.panel("SlipPanel", t.box("SB_slip", "gold-soft", radius=14, margin=(18, 12, 18, 14), border="gold", border_w=2))
    t.panel("SlipOkPanel", t.box("SB_slip_ok", "ok-soft", radius=14, margin=(18, 12, 18, 14), shadow=False, border="primary", border_w=2))
    t.panel("HandlePanel", t.box("SB_handle", "line", radius=4, margin=(0, 0, 0, 0), shadow=False))


    # Stil A: masa sahnesi paneli (müşteri camı, keçe tezgâh, kimlik kâğıdı, bırakma bölgeleri)
    t.panel("WindowPanel", t.box("SB_window", "window", radius=16, margin=(20, 16, 20, 18), border="window-line", border_w=5))
    t.panel("DeskPanel", t.box("SB_desk", "desk", radius=16, margin=(16, 14, 16, 14), shadow=False, border="desk-line", border_w=2))
    t.panel("DocPanel", t.box("SB_doc", "doc", radius=8, margin=(14, 10, 14, 12), shadow=False, border="doc-line", border_w=2))
    t.panel("ZoneAccept", t.box("SB_zone_ok", "primary", alpha=0.16, radius=18, margin=(10, 6, 10, 8), shadow=False, border="primary", border_w=3))
    t.panel("ZoneReturn", t.box("SB_zone_ret", "gold", alpha=0.18, radius=18, margin=(10, 6, 10, 8), shadow=False, border="gold", border_w=3))
    t.panel("ZoneConfiscate", t.box("SB_zone_con", "danger", alpha=0.16, radius=18, margin=(10, 6, 10, 8), shadow=False, border="danger", border_w=3))
    t.label("WindowTitle", "window-text", 32, font=px)
    t.label("WindowLabel", "window-text", 26)
    t.label("DeskLabel", "desk-text", 22)
    t.label("DocTitle", "doc-text", 20, alpha=0.7, font=bold)
    t.label("DocLine", "doc-text", 24, font=bold)
    t.label("DocDetail", "doc-text", 20, alpha=0.8)
    ink = t.box("SB_ink", "info", radius=18, margin=(24, 14, 24, 16), hard=True)
    ink_down = t.box("SB_ink_down", "info-down", radius=18, margin=(24, 18, 24, 12), shadow=False)
    t.button("InkButton", ink, ink_down, btn_off, size=28, font=bold)


    # Gişe sahnesi bileşenleri
    t.panel("BubblePanel", t.box("SB_bubble", "surface", radius=18, margin=(16, 10, 16, 12), border="ink", border_w=3))
    t.panel("PlatePanel", t.box("SB_plate", "brass", radius=6, margin=(14, 4, 14, 6), border="brass-line", border_w=3))
    t.panel("BoothHud", t.box("SB_booth_hud", "booth", alpha=0.94, radius=8, margin=(20, 10, 20, 12), shadow=False, border="booth-line", border_w=2))
    t.panel("ReceiptPanel", t.box("SB_receipt", "receipt", radius=3, margin=(12, 8, 12, 10), border="receipt-line", border_w=2))
    t.panel("TrayAccept", t.box("SB_tray_ok", "tray", alpha=0.55, radius=8, margin=(6, 4, 6, 6), shadow=False, border="primary", border_w=3))
    t.panel("TrayReturn", t.box("SB_tray_ret", "tray", alpha=0.55, radius=8, margin=(6, 4, 6, 6), shadow=False, border="gold", border_w=3))
    t.panel("TrayConfiscate", t.box("SB_tray_con", "tray", alpha=0.55, radius=8, margin=(6, 4, 6, 6), shadow=False, border="danger", border_w=3))
    t.label("BubbleLabel", "ink", 26)
    t.label("PlateLabel", "brass-text", 26, font=px)
    t.label("HudLabel", "hud-amber", 24)
    t.label("HudMuted", "hud-amber-dim", 22)
    t.label("HudClock", "hud-clock", 46, font=bold)
    t.label("HudPay", "hud-pay", 26, font=bold)
    tool = t.box("SB_tool", "metal", radius=8, margin=(12, 8, 12, 10), hard=True, border="metal-line", border_w=2)
    tool_down = t.box("SB_tool_down", "metal-down", radius=8, margin=(12, 11, 12, 7), shadow=False, border="metal-line", border_w=2)
    t.button("ToolButton", tool, tool_down, tool, font_color="hud-amber", disabled_color="hud-amber-dim", size=22, icon=28)
    # Gişe dışındaki koyu ekranlarda doğrudan zemine yazılan metinler
    t.label("BoothTitle", "hud-clock", 56, font=px)
    t.label("BoothHeading", "hud-amber", 36, font=px)
    t.label("BoothBody", "desk-text", 26)
    t.label("BoothMuted", "hud-amber-dim", 22)
    t.label("StampLabel", "danger", 72, font=px, outline=("surface", 10, 0.9))
    t.label("ChipLabel", "surface", 24)
    t.label("ChipTitle", "surface", 24)
    t.label("SheetTitle", "text", 34, font=px)
    t.label("SheetInfo", "text-muted", 22)
    t.label("CardTitle", "text", 24)
    t.label("CardDetail", "text-muted", 20)
    t.label("CardNote", "text-muted", 18)
    t.label("BadgeSmall", "info", 16)
    t.label("BadgeBig", "info", 32, font=bold)
    t.label("GoalTitle", "text", 36, font=bold)
    t.label("GoalLabel", "text", 22)
    t.label("GoalHint", "text-muted", 22)
    t.label("ItemTitle", "text", 30, font=bold)
    t.label("ItemSub", "text-muted", 22)
    t.label("TagLabel", "surface", 18)
    t.label("OnPrimaryLabel", "surface", 26, font=bold)
    t.label("SlipTitle", "text", 28, font=bold)
    t.label("SlipLine", "text", 22)
    t.label("BigNumber", "text", 40, font=bold)
    t.write(os.path.join(os.path.dirname(__file__), "..", "assets", "theme", "main_theme.tres"))


if __name__ == "__main__":
    build()
    print("assets/theme/main_theme.tres yazıldı")
