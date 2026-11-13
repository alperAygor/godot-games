class_name InfoSheet
extends Sheet

## Ana ekranın küçük sayfaları: "Yakında" (mağaza/koleksiyon yer tutucusu) ve Ayarlar.

const BODY_SIZE: int = UiKit.TYPE_BODY
const GAP: float = UiKit.SPACE_LG
const SECTION_GAP: float = UiKit.SPACE_XL


## Yer tutucu: "yakında". `icon_name` sekmenin ikonudur (sayfa hangi bölümden açıldığı belli olsun).
static func soon(parent: Node, icon_name: String) -> InfoSheet:
	var sheet: InfoSheet = InfoSheet.new()
	sheet.build(parent, false)
	sheet.dismiss_on_dim = true
	var column: VBoxContainer = sheet.content()
	column.add_child(UiKit.centered_disc(icon_name))
	sheet.add_gap(GAP)
	sheet.add_title(UiStrings.soon_title())
	column.add_child(UiKit.wrap_label(UiStrings.soon_body(), BODY_SIZE, UiKit.TEXT_MUTED))
	sheet.add_gap(SECTION_GAP)
	sheet._ok_button()
	sheet.play_intro()
	return sheet


static func settings(parent: Node) -> InfoSheet:
	var sheet: InfoSheet = InfoSheet.new()
	sheet.build(parent, false)
	sheet.dismiss_on_dim = true
	var column: VBoxContainer = sheet.content()
	sheet.add_title(UiStrings.settings_title())
	column.add_child(UiSettingsRow.new(true))
	sheet.add_gap(SECTION_GAP)
	var languages: UiLanguageRow = UiLanguageRow.new()
	languages.language_changed.connect(sheet._on_language_changed)
	column.add_child(languages)
	# Gizlilik seçenekleri yalnız reklam katmanı sunuyorsa görünür (AB/ABD onay formu için kanca).
	if UiData.privacy_options_available():
		sheet.add_gap(SECTION_GAP)
		var privacy: Button = UiKit.button(Loc.t("UI_PRIVACY_OPTIONS"), &"SecondaryButton", "lucide/lock",
			UiKit.HEIGHT_COMPACT)
		privacy.name = "PrivacyOptions"
		privacy.pressed.connect(UiData.show_privacy_options)
		column.add_child(privacy)
	sheet.add_gap(SECTION_GAP)
	sheet._ok_button()
	sheet.play_intro()
	return sheet


## Dil değişince ekran baştan kurulur: yarım çevrilmiş ekran kalmasın (bkz. Loc).
func _on_language_changed() -> void:
	GameManager.reload_scene()


func _ok_button() -> Button:
	var ok: Button = add_action(UiStrings.ok(), false)
	ok.pressed.connect(close)
	return ok
