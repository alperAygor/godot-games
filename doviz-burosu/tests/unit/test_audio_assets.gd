extends "res://tests/test_case.gd"
## Ses varlıkları: kayıt defteri (data/sounds.json) ile diskteki dosyalar uyumlu; yeniden üretilen her ses lisans kaydında.
## Kayıt `python3 tools/make_sfx.py --process` ile yazılır (docs/AUDIO.md, docs/AUDIO_LICENSE.md, assets/audio/PROVENANCE.md).

const SOUNDS_PATH := "res://data/sounds.json"
const LICENSE_PATH := "res://docs/AUDIO_LICENSE.md"
const PROVENANCE_PATH := "res://assets/audio/PROVENANCE.md"
const AUDIO_DIRS := ["res://assets/audio/sfx/", "res://assets/audio/music/"]


func _registry() -> Dictionary:
	return JsonIO.read_dict(SOUNDS_PATH)


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_registry_lists_every_audio_file_and_nothing_else() -> void:
	var registry := _registry()
	assert_eq(registry.size(), 38, "38 ses kayıtlı")
	var on_disk := {}
	for dir in AUDIO_DIRS:
		for file_name in DirAccess.get_files_at(dir):
			if file_name.get_extension() == "mp3":
				on_disk[file_name.get_basename()] = dir + file_name
	for sound_name: String in on_disk:
		assert_true(registry.has(sound_name), "%s diskte var ama kayıtta yok" % sound_name)
	for sound_name: String in registry:
		assert_true(on_disk.has(sound_name), "%s kayıtlı ama dosyası yok" % sound_name)
		assert_eq(str(registry[sound_name]["path"]), on_disk.get(sound_name, ""), "%s yolu" % sound_name)


func test_every_registered_sound_exists_and_loads() -> void:
	var audio: Node = tree.root.get_node("AudioManager")
	var registry := _registry()
	for sound_name: String in registry:
		var entry: Dictionary = registry[sound_name]
		assert_true(FileAccess.file_exists(str(entry["path"])), "%s dosyası" % sound_name)
		var stream: AudioStream = audio.track_stream(sound_name) if str(entry["kind"]) == "music" and not sound_name.begins_with("stinger") else audio.sfx_stream(sound_name)
		assert_true(stream != null, "%s ses yöneticisinde bulunur (ad ve API değişmedi)" % sound_name)
		assert_true(stream.get_length() > 0.2, "%s boş değil" % sound_name)


func test_registered_hash_matches_the_shipped_file() -> void:
	var registry := _registry()
	for sound_name: String in registry:
		var entry: Dictionary = registry[sound_name]
		assert_eq(FileAccess.get_sha256(str(entry["path"])), str(entry["sha256"]), "%s SHA-256 (kayıt eski: --process çalıştır)" % sound_name)


func test_licence_ledger_covers_every_regenerated_file() -> void:
	var registry := _registry()
	var licence := _text(LICENSE_PATH)
	var provenance := _text(PROVENANCE_PATH)
	assert_false(licence.is_empty(), "docs/AUDIO_LICENSE.md var")
	var regenerated := 0
	for sound_name: String in registry:
		var entry: Dictionary = registry[sound_name]
		if bool(entry["regenerated"]):
			regenerated += 1
			assert_true(licence.contains("`%s`" % sound_name), "%s lisans kaydında" % sound_name)
			assert_true(provenance.contains("`%s`" % sound_name) and provenance.contains(str(entry["sha256"])), "%s üretim kaydında (SHA-256 ile)" % sound_name)
			assert_true(str(entry["model"]) in ["eleven_text_to_sound_v3", "music_v2_5"], "%s modeli" % sound_name)
			assert_eq(str(entry["source"]), "elevenlabs-paid-plan")
		else:
			assert_true(licence.contains("`%s`" % sound_name), "%s hâlâ-ücretsiz-plan listesinde" % sound_name)
			assert_eq(str(entry["source"]), "elevenlabs-free-plan")
	assert_true(regenerated >= 20, "kritik sesler yeniden üretilmiş (en az 20)")
	assert_true(licence.contains("starter") or licence.contains("Starter"), "plan katmanı kayıtlı")
