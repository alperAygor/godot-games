extends TestCase
## Çeviri kapsamı: koddaki her tr("...") metninin İngilizcesi olmalı ve
## arayüz çağrılarına çevrilmemiş düz metin verilmemeli.

const EN_PATH := "res://data/lang_en.json"
const LETTERS := "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZQWXabcçdefgğhıijklmnoöprsştuüvyzqwx"

func _en() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EN_PATH))
	return parsed if parsed is Dictionary else {}

func _scripts(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scripts(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))

func _has_letter(text: String) -> bool:
	for ch in text:
		if LETTERS.contains(ch):
			return true
	return false

func _literals(source: String, pattern: String) -> Array:
	var re := RegEx.new()
	re.compile(pattern)
	var out: Array = []
	for m in re.search_all(source):
		out.append(m.get_string(1))
	return out

func test_language_file_loads() -> void:
	var en := _en()
	gt(float(en.size()), 50.0, "lang_en.json en az 50 kayıt içermeli")
	for key in en:
		check(str(en[key]).strip_edges() != "", "boş çeviri: " + str(key))

func test_every_tr_literal_is_translated() -> void:
	var en := _en()
	var files: Array = []
	_scripts("res://scripts", files)
	for path in files:
		var source := FileAccess.get_file_as_string(path)
		for text in _literals(source, "(?<![A-Za-z_])(?:tr|t)\\(\"((?:[^\"\\\\]|\\\\.)*)\"\\)"):
			if _has_letter(text):
				check(en.has(text), "%s: çevirisi yok → \"%s\"" % [path.get_file(), text])

func test_constant_tables_are_translated() -> void:
	var en := _en()
	for name in Settings.QUALITY_NAMES:
		check(en.has(name), "kalite adı çevrilmemiş: " + name)
	for tier in UIKit.TIER_NAME:
		check(en.has(UIKit.TIER_NAME[tier]), "nadirlik adı çevrilmemiş: " + str(UIKit.TIER_NAME[tier]))

func test_no_raw_text_in_ui_calls() -> void:
	## Arayüz çağrılarına doğrudan "metin" verilirse dil değişince Türkçe kalır.
	var files: Array = []
	_scripts("res://scripts", files)
	for path in files:
		var source := FileAccess.get_file_as_string(path)
		for text in _literals(source, "(?:KIT\\.(?:label|heading|button)|show_banner|toast|_row|_add_toggle|_stat_cell\\(grid, \"\\w+\",)\\(\\s*\"([^\"]*)\""):
			check(not _has_letter(text), "%s: çevrilmemiş arayüz metni → \"%s\"" % [path.get_file(), text])

func test_data_has_english() -> void:
	var cards: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))
	for card in cards:
		check(str(card.get("name_en", "")) != "", "kart İngilizce adı yok: " + str(card.get("id", "?")))
		check(str(card.get("desc_en", "")) != "", "kart İngilizce açıklaması yok: " + str(card.get("id", "?")))
	var maps: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps.json"))
	for theme in maps:
		check(str(theme.get("name_en", "")) != "", "harita İngilizce adı yok: " + str(theme.get("id", "?")))
		check(str(theme.get("boss_name_en", "")) != "", "boss İngilizce adı yok: " + str(theme.get("id", "?")))
