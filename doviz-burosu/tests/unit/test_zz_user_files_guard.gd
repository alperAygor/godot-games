extends "res://tests/test_case.gd"
## Bekçi: test paketi oyuncunun GERÇEK kayıt/ayar dosyalarına dokunmamalı. Dosya adı "zz" ile başlar ki en sona çalışsın.
## Mekanizma: betikli (-s) çalışmada JsonIO, kayıt ve ayarları `user://_sandbox/` altına yönlendirir ve süreç açılırken
## gerçek `user://save.*` / `settings.*` dosyalarının parmak izini (zaman, boyut, md5) alır; burada karşılaştırılır.


func test_runs_are_sandboxed() -> void:
	assert_true(JsonIO.is_sandboxed(), "testler sandbox'ta çalışmalı (DV_REAL_USER_DATA=1 ile mi çalıştırıldı?)")
	assert_true(tree.root.get_node("SaveManager").save_path.begins_with(JsonIO.SANDBOX_DIR), "SaveManager yolu sandbox'ta")
	assert_true(tree.root.get_node("SettingsManager").settings_path.begins_with(JsonIO.SANDBOX_DIR), "SettingsManager yolu sandbox'ta")


func test_real_user_files_were_not_touched_by_the_suite() -> void:
	if not JsonIO.is_sandboxed():
		return
	var before := JsonIO.boot_fingerprint()
	var now := JsonIO.real_files_fingerprint()
	assert_eq(now, before, "gerçek user://save.* / settings.* dosyaları test sırasında değişti, eklendi ya da silindi")
