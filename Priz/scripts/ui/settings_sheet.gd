class_name SettingsSheet
extends Sheet

## Ayarlar sayfası: ses/müzik/titreşim anahtarları + dil (TR/EN/ES) + (varsa) gizlilik seçenekleri.
## Ana ekrandan açılır. Dil değişince sahne baştan kurulur (yarım çevrilmiş ekran kalmasın).

const SECTION_GAP: float = UiKit.SPACE_XL


static func open(parent: Node) -> SettingsSheet:
	var sheet: SettingsSheet = SettingsSheet.new()
	sheet.build(parent, false)
	sheet.dismiss_on_dim = true
	var column: VBoxContainer = sheet.content()
	sheet.add_title(UiStrings.settings_title())
	column.add_child(UiSettingsRow.new())
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
	var ok: Button = sheet.add_action(UiStrings.ok(), false)
	ok.pressed.connect(sheet.close)
	sheet.play_intro()
	return sheet


## Dil değişince ekran baştan kurulur: yarım çevrilmiş ekran kalmasın (bkz. Loc).
func _on_language_changed() -> void:
	GameManager.reload_scene()
