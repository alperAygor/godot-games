extends TestCase

## AudioService v0.2 ASMR sözleşmesi (ARCHITECTURE §3, §11, §16):
## mevcut play/has_sound korunur; ambient loop API'si, bus mix'i, pause güvenliği
## ve mute'un user://settings.cfg'ye kalıcılığı sınanır.
##
## Neden `call()`: testler `-s` modunda koşuyor; autoload/enum kimlikleri derleme
## anında çözülmez (GOTCHAS #2). Çalışma anında autoload_node ile erişilir.

const SETTINGS_PATH: String = "user://settings.cfg"
const SFX_DIR: String = "res://assets/audio/sfx"

const EXPECTED_SOUNDS: Array[String] = [
	"ui_tap", "cable_pull", "cable_slide", "spark", "clack", "wrong_socket",
	"fuse_pop", "level_start", "shield_on", "cutter", "success", "win", "fail", "hum",
	"ambient_hum", "ambient_pad",
]

const EXPECTED_BUSES: Array[String] = ["Music", "SFX", "UI"]
const EXPECTED_BUS_DB: Dictionary = {"Music": -9.0, "SFX": -3.0, "UI": -5.0}

var _audio: Node = null


func before_each() -> void:
	_audio = autoload_node("AudioService")
	if _audio == null:
		fail("AudioService autoload bulunamadı")
		return
	_audio.call("stop_ambient", 0.0)
	_audio.call("set_muted", false)


func after_each() -> void:
	if _audio != null:
		_audio.call("stop_ambient", 0.0)
		_audio.call("set_muted", false)
	if tree != null:
		tree.paused = false


# ---------------------------------------------------------------- sözleşme
func test_contract_methods_exist() -> void:
	if _audio == null:
		return
	for method_name: String in ["play", "has_sound", "set_muted", "play_ambient",
			"stop_ambient", "current_ambient", "muted"]:
		var found: bool = _audio.has_method(method_name) or _audio.get(method_name) != null
		assert_true(found, "AudioService üyesi yok: " + method_name)


func test_expected_sounds_and_files() -> void:
	if _audio == null:
		return
	for sound_name: String in EXPECTED_SOUNDS:
		assert_true(bool(_audio.call("has_sound", sound_name)), "sounds.json: " + sound_name)
		var path: String = SFX_DIR.path_join(sound_name + ".wav")
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, "wav açılabilmeli: " + path)
		if file != null:
			assert_greater(float(file.get_length()), 512.0, "wav > 512 bayt: " + path)
			file.close()
	assert_false(bool(_audio.call("has_sound", "yok_boyle_bir_ses")), "tanımsız ses yok")


func test_common_sound_preload_list_is_valid() -> void:
	if _audio == null:
		return
	var map: Dictionary = (_audio.get_script() as GDScript).get_script_constant_map()
	var common: Array = map.get("COMMON_SOUNDS", []) as Array
	assert_greater(float(common.size()), 8.0, "COMMON_SOUNDS listesi dolu olmalı")
	for sound_name: Variant in common:
		var name_text: String = String(sound_name)
		assert_true(bool(_audio.call("has_sound", name_text)),
			"preload listesindeki ses sounds.json'da olmalı: " + name_text)
	# Headless'ta no-op olmalı ve çökmemeli (gerçek önden yükleme pencere modunda).
	_audio.call("_preload_common_sounds")
	assert_true(true, "headless preload güvenli")


func test_ambient_loop_lengths() -> void:
	if _audio == null:
		return
	var hum: AudioStreamWAV = load(SFX_DIR.path_join("ambient_hum.wav")) as AudioStreamWAV
	var pad: AudioStreamWAV = load(SFX_DIR.path_join("ambient_pad.wav")) as AudioStreamWAV
	assert_not_null(hum, "ambient_hum.wav yüklenmeli")
	assert_not_null(pad, "ambient_pad.wav yüklenmeli")
	if hum != null:
		assert_almost_eq(hum.get_length(), 8.0, 0.2, "ambient_hum 8 sn loop")
	if pad != null:
		assert_almost_eq(pad.get_length(), 12.0, 0.3, "ambient_pad 12 sn loop")


func test_bus_mix_created() -> void:
	if _audio == null:
		return
	for bus_name: String in EXPECTED_BUSES:
		var index: int = AudioServer.get_bus_index(StringName(bus_name))
		assert_true(index >= 0, "bus yok: " + bus_name)
		if index < 0:
			continue
		assert_almost_eq(AudioServer.get_bus_volume_db(index),
			float(EXPECTED_BUS_DB[bus_name]), 0.6, bus_name + " mix seviyesi")
	assert_eq(AudioServer.get_bus_index(&"Master"), 0, "Master bus 0")


# ---------------------------------------------------------------- mute
func test_mute_persists_in_settings() -> void:
	if _audio == null:
		return
	_audio.call("set_muted", true)
	assert_true(bool(_audio.get("muted")), "muted true olmalı")
	assert_true(AudioServer.is_bus_mute(0), "Master bus susturulmalı")
	var muted_config: ConfigFile = ConfigFile.new()
	assert_eq(muted_config.load(SETTINGS_PATH), OK, "settings.cfg okunmalı")
	assert_false(bool(muted_config.get_value("audio", "sound_enabled", true)),
		"audio/sound_enabled=false yazılmalı")
	assert_false(bool(muted_config.get_value("ui", "sound", true)),
		"ARCHITECTURE §11 aynası ui/sound=false")

	_audio.call("set_muted", false)
	assert_false(bool(_audio.get("muted")), "muted false olmalı")
	assert_false(AudioServer.is_bus_mute(0), "Master bus açılmalı")
	var unmuted_config: ConfigFile = ConfigFile.new()
	assert_eq(unmuted_config.load(SETTINGS_PATH), OK, "settings.cfg okunmalı")
	assert_true(bool(unmuted_config.get_value("audio", "sound_enabled", true)),
		"audio/sound_enabled=true yazılmalı")
	assert_true(bool(unmuted_config.get_value("ui", "sound", true)), "ui/sound=true")


func test_persisted_mute_is_loaded() -> void:
	if _audio == null:
		return
	_audio.call("set_muted", true)
	assert_false(bool(_audio.call("_load_sound_enabled")), "diskten susturulmuş okunmalı")
	_audio.call("set_muted", false)
	assert_true(bool(_audio.call("_load_sound_enabled")), "diskten açık okunmalı")


# ---------------------------------------------------------------- çalma
func test_headless_play_is_safe() -> void:
	if _audio == null:
		return
	# Headless'ta ses çıkmaz; API çökmemeli ve eksik ad tek uyarı üretmeli.
	_audio.call("play", "spark")
	_audio.call("play", "ui_tap", 0.2)
	_audio.call("play", "ambient_hum")
	_audio.call("play", "yok_boyle_bir_ses")
	_audio.call("set_muted", true)
	_audio.call("play", "spark")
	_audio.call("set_muted", false)
	assert_true(true, "headless play çökmedi")


# ---------------------------------------------------------------- ambient
func test_ambient_api_idempotent() -> void:
	if _audio == null:
		return
	assert_eq(String(_audio.call("current_ambient")), "", "başlangıçta ambient yok")
	_audio.call("play_ambient", "ambient_hum", 0.0)
	assert_eq(String(_audio.call("current_ambient")), "ambient_hum", "hum başladı")
	_audio.call("play_ambient", "ambient_hum", 0.0)
	assert_eq(String(_audio.call("current_ambient")), "ambient_hum", "tekrar çağrı idempotent")
	_audio.call("play_ambient", "ambient_pad", 0.0)
	assert_eq(String(_audio.call("current_ambient")), "ambient_pad", "pad'e geçiş")
	_audio.call("stop_ambient", 0.0)
	assert_eq(String(_audio.call("current_ambient")), "", "durduruldu")
	_audio.call("stop_ambient", 0.0)
	assert_eq(String(_audio.call("current_ambient")), "", "ikinci stop idempotent")


func test_ambient_unknown_or_empty_name_is_safe() -> void:
	if _audio == null:
		return
	_audio.call("play_ambient", "yok_boyle_bir_ambient", 0.0)
	assert_eq(String(_audio.call("current_ambient")), "", "bilinmeyen ambient durum değiştirmez")
	_audio.call("play_ambient", "", 0.0)
	assert_eq(String(_audio.call("current_ambient")), "", "boş ad stop gibi davranır")


func test_ambient_loop_flags_do_not_contaminate_oneshot() -> void:
	if _audio == null:
		return
	var looped: Variant = _audio.call("_loop_stream", "ambient_hum")
	assert_true(looped is AudioStreamWAV, "loop stream WAV olmalı")
	if looped is AudioStreamWAV:
		var looped_wav: AudioStreamWAV = looped as AudioStreamWAV
		assert_eq(looped_wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, "loop mode FORWARD")
		assert_greater(float(looped_wav.loop_end), 1000.0, "loop_end örnek sayısı")
	# Normal çalma yolu aynı kaynağı loop'lu görmemeli.
	var base: Variant = _audio.call("_stream", "ambient_hum")
	if base is AudioStreamWAV:
		assert_eq((base as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED,
			"tek çalma kaynağı loop'suz kalmalı")


func test_ambient_pause_safety_flags() -> void:
	if _audio == null:
		return
	assert_eq(_audio.process_mode, Node.PROCESS_MODE_ALWAYS, "servis pause'da çalışır")
	var player: Variant = _audio.get("_ambient_player")
	assert_not_null(player, "ambient player kurulmalı")
	if player is Node:
		assert_eq((player as Node).process_mode, Node.PROCESS_MODE_ALWAYS,
			"ambient player pause'da çalışır")
	# Pause sırasında çalar/durur çağrıları çökmemeli (tween pause mode process).
	_audio.call("play_ambient", "ambient_hum", 0.05)
	tree.paused = true
	_audio.call("stop_ambient", 0.05)
	_audio.call("play_ambient", "ambient_pad", 0.05)
	tree.paused = false
	assert_eq(String(_audio.call("current_ambient")), "ambient_pad", "pause'da ambient durumu korunur")
