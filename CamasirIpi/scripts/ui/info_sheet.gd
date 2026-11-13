class_name InfoSheet
extends Sheet

## Ana ekranın küçük sayfaları: "Yakında" (mağaza/koleksiyon yer tutucusu) ve Ayarlar.

const TITLE_SIZE: int = 52
const BODY_SIZE: int = 32
const DISC: float = 112.0
const ICON_PIXELS: float = 52.0
const GAP: float = 24.0
const OK_HEIGHT: float = 126.0


## Yer tutucu: "yakında". `icon_name` sekmenin ikonudur (sayfa hangi bölümden açıldığı belli olsun).
static func soon(parent: Node, icon_name: String) -> InfoSheet:
	var sheet: InfoSheet = InfoSheet.new()
	sheet.build(parent, false)
	sheet.dismiss_on_dim = true
	var column: VBoxContainer = sheet.content()
	column.add_child(sheet._icon_disc(icon_name))
	column.add_child(UiKit.spacer(GAP))
	column.add_child(UiKit.label(UiStrings.SOON_TITLE, TITLE_SIZE))
	column.add_child(UiKit.spacer(GAP * 0.4))
	var body: Label = UiKit.label(UiStrings.SOON_BODY, BODY_SIZE, UiKit.TEXT_MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	column.add_child(UiKit.spacer(GAP * 1.5))
	column.add_child(sheet._ok_button())
	sheet.play_intro()
	return sheet


static func settings(parent: Node) -> InfoSheet:
	var sheet: InfoSheet = InfoSheet.new()
	sheet.build(parent, false)
	sheet.dismiss_on_dim = true
	var column: VBoxContainer = sheet.content()
	column.add_child(UiKit.label(UiStrings.SETTINGS_TITLE, TITLE_SIZE))
	column.add_child(UiKit.spacer(GAP * 1.5))
	column.add_child(UiSettingsRow.new())
	column.add_child(UiKit.spacer(GAP * 1.8))
	column.add_child(sheet._ok_button())
	sheet.play_intro()
	return sheet


func _ok_button() -> Button:
	var ok: Button = UiKit.button(UiStrings.OK, &"SecondaryButton", "", OK_HEIGHT)
	ok.pressed.connect(close)
	return ok


func _icon_disc(icon_name: String) -> Control:
	var holder: CenterContainer = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = UiKit.ACCENT_SOFT
	box.set_corner_radius_all(int(DISC * 0.5))
	box.anti_aliasing = true
	disc.add_theme_stylebox_override("panel", box)
	disc.custom_minimum_size = Vector2(DISC, DISC)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(disc)
	var icon: TextureRect = UiKit.tinted_icon(icon_name, ICON_PIXELS, UiKit.ACCENT)
	icon.position = Vector2((DISC - ICON_PIXELS) * 0.5, (DISC - ICON_PIXELS) * 0.5)
	disc.add_child(icon)
	return holder
