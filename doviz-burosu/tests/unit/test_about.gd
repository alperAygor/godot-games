extends "res://tests/session_case.gd"
## T-A2: Hakkında ve lisanslar. Lisans metinleri paketle gelen kaynak dosyalarla BİREBİR; paketlenen her yazı tipi/eklenti kayıtlı;
## "simülasyondur, finansal tavsiye değildir" bildirimi iki dilde var ve sürüm gösterilir.

const FONT_DIR := "res://assets/fonts/"


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path).trim_prefix("﻿")


func _entry(id: String) -> Dictionary:
	for entry: Dictionary in AboutSheet.components():
		if str(entry["id"]) == id:
			return entry
	return {}


func test_font_licence_texts_match_the_shipped_files_exactly() -> void:
	assert_eq(str(_entry("vt323")["text"]), _read("res://assets/fonts/OFL_VT323.txt"))
	assert_eq(str(_entry("baloo2")["text"]), _read("res://assets/fonts/OFL_Baloo2.txt"))
	assert_eq(str(_entry("pixelify")["text"]), _read("res://assets/fonts/OFL_PixelifySans.txt"))


func test_plugin_licence_text_matches_the_plugin_licence_file() -> void:
	assert_eq(str(_entry("billing")["text"]), _read("res://addons/GodotGooglePlayBilling/LICENSE"))
	var admob := str(_entry("admob")["text"])
	assert_true(admob.begins_with("MIT License"))
	assert_true(admob.contains("Permission is hereby granted"))
	assert_true(admob.contains("cengiz-pz"), "telif satırı plugin.cfg'deki sahip")


func test_every_packaged_font_and_plugin_has_a_licence_entry() -> void:
	var files := PackedStringArray()
	for entry: Dictionary in AboutSheet.components():
		for file in entry["files"]:
			files.append(str(file))
			assert_true(FileAccess.file_exists("res://" + str(file)) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://" + str(file))), "%s var" % file)
	for file_name in DirAccess.get_files_at(FONT_DIR):
		if file_name.get_extension() in ["ttf", "otf"]:
			assert_true(files.has("assets/fonts/" + file_name), "%s için lisans kaydı olmalı" % file_name)
	for plugin in DirAccess.get_directories_at("res://addons"):
		if plugin == "GMPShared":
			continue  # AdMob eklentisinin parçası (aynı kayıt)
		var covered := false
		for file in files:
			covered = covered or file == "addons/" + plugin
		assert_true(covered, "addons/%s için lisans kaydı olmalı" % plugin)


func test_used_font_is_marked_used_and_unused_ones_are_listed_for_removal() -> void:
	assert_true(bool(_entry("vt323")["used"]))
	assert_false(bool(_entry("baloo2")["used"]))
	assert_false(bool(_entry("pixelify")["used"]))
	var theme_text := FileAccess.get_file_as_string("res://assets/theme/main_theme.tres") + FileAccess.get_file_as_string("res://assets/fonts/vt_regular.tres")
	assert_false(theme_text.contains("Baloo2") or theme_text.contains("PixelifySans"), "kullanılmıyor dediklerimiz temada yok")


func test_licenses_json_is_shipped_by_the_export_filter() -> void:
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_true(presets.contains('include_filter="data/*.json"'), "data/*.json pakete girer; lisans metinleri orada")


func test_engine_licence_comes_from_the_engine() -> void:
	assert_true(Engine.get_license_text().contains("Permission is hereby granted"))
	assert_true(AboutSheet.engine_component_names().size() > 5)
	assert_true(AboutSheet.engine_version().begins_with("4."))


func test_about_sheet_shows_version_notice_credits_and_licence_list() -> void:
	await scenes.goto(Scenes.SETTINGS)
	await tree.process_frame
	for locale in ["en", "tr"]:
		TranslationServer.set_locale(locale)
		await tap("AboutButton")
		assert_true(node("AboutSheet") != null)
		assert_true((node("AboutVersion") as Label).text.contains(AboutSheet.game_version()))
		var notice := (node("AboutSimText") as Label).text.to_lower()
		if locale == "en":
			assert_true(notice.contains("fictional") and notice.contains("not") or notice.contains("nothing in the game is financial"), notice)
			assert_true(notice.contains("financial or investment advice"))
		else:
			assert_true(notice.contains("kurgusal") and notice.contains("finansal ya da yatırım tavsiyesi değildir"), notice)
		for entry: Dictionary in AboutSheet.components():
			assert_true(node("License_" + str(entry["id"])) != null, "License_%s" % entry["id"])
		assert_true(node("License_godot") != null)
		await tap("AboutCloseButton")
		await tree.process_frame
		assert_true(node("AboutSheet") == null)
	SettingsManager.apply_language()


func test_licence_detail_opens_and_back_returns_to_the_list() -> void:
	await scenes.goto(Scenes.SETTINGS)
	await tree.process_frame
	await tap("AboutButton")
	await tap("License_vt323")
	assert_eq((node("LicenseText") as Label).text, _read("res://assets/fonts/OFL_VT323.txt"))
	await TouchInput.back(tree)
	await tree.process_frame
	await tree.process_frame
	assert_true(node("AboutSheet") != null, "geri tuşu listeye döner, pencereyi kapatmaz")
	assert_true(node("License_vt323") != null)
	await tap("License_godot")
	assert_true((node("LicenseText") as Label).text.contains("Permission is hereby granted"))
	await tap("LicenseBackButton")
	assert_true(node("License_godot") != null)


func test_new_strings_exist_in_both_languages() -> void:
	var file := FileAccess.open("res://assets/translations/strings.csv", FileAccess.READ)
	var seen := 0
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 3 and row[0].begins_with("ACC_"):
			seen += 1
			assert_false(row[1].strip_edges().is_empty() or row[2].strip_edges().is_empty(), "%s boş çeviri" % row[0])
			assert_eq(row[1].count("%s"), row[2].count("%s"), "%s yer tutucu sayısı" % row[0])
	assert_true(seen >= 20)
