extends TestCase

## AdManager sözleşmesi (ARCHITECTURE.md §3): üç ödüllü yerleşim, tur/oturum
## limitleri, aynı anda tek reklam (pending) koruması, idempotent ödül.
## Ayrıca AudioService sözleşmesi (set_muted, has_sound) bu dosyada sınanır.
##
## Neden `call()`: testler `-s` modunda koşuyor ve orada autoload/enum kimlikleri
## derleme anında çözülemiyor (GOTCHAS.md #2). Enum değerleri çalışma anında
## `get_script_constant_map()` üzerinden okunur; böylece enum ÜYELERİ de sınanır.
##
## MockAdsProvider 1.2 sn zamanlayıcı kullandığı için testte beklemek anlamsız:
## limit/pending mantığı senkron bir StubAdsProvider ile sürülür. Mock'un kendi
## bitiş yolu ayrı testte doğrudan `_finish` çağrısıyla doğrulanır.

const SOUNDS_DIR: String = "res://assets/audio/sfx"
const AD_LIMITS_PATH: String = "res://data/ads.json"

const EXPECTED_LIMITS: Dictionary = {
	"FUSE_RESCUE": {"per_run": 1, "per_session": 5},
	"GOLDEN_CUTTER": {"per_run": 1, "per_session": 3},
	"INSULATION_SPRAY": {"per_run": 1, "per_session": 3},
}

const EXPECTED_SOUNDS: Array[String] = [
	"ui_tap", "cable_pull", "spark", "clack", "wrong_socket", "fuse_pop",
	"level_start", "shield_on", "cutter", "success", "win", "fail", "hum",
]

var _manager: Node = null
var _audio: Node = null
var _default_provider: AdsProvider = null

var _starts: Array[int] = []
var _rewards: Array[Dictionary] = []
var _ad_failures: Array[Dictionary] = []

var _fuse: int = 0
var _cutter: int = 1
var _spray: int = 2
var _limits_constant: Dictionary = {}


func before_each() -> void:
	_starts.clear()
	_rewards.clear()
	_ad_failures.clear()
	_manager = autoload_node("AdManager")
	_audio = autoload_node("AudioService")
	if _manager == null:
		fail("AdManager autoload bulunamadı")
		return
	_read_manager_constants()
	_manager.call("reset_session_limits")
	_default_provider = _manager.get("provider") as AdsProvider
	_connect_signals()
	# Senkron sağlayıcı: show -> rewarded aynı karede.
	_manager.call("set_provider", StubAdsProvider.new(true))


func after_each() -> void:
	if _manager != null:
		_disconnect_signals()
		_manager.call("set_provider", _default_provider)
		_manager.call("reset_session_limits")
	if _audio != null:
		_audio.call("set_muted", false)


# ---------------------------------------------------------------- sözleşme
func test_placement_enum_names_in_contract_order() -> void:
	if _manager == null:
		return
	assert_eq(_fuse, 0, "Placement.FUSE_RESCUE")
	assert_eq(_cutter, 1, "Placement.GOLDEN_CUTTER")
	assert_eq(_spray, 2, "Placement.INSULATION_SPRAY")
	var map: Dictionary = (_manager.get_script() as GDScript).get_script_constant_map()
	var placements: Dictionary = map.get("Placement", {}) as Dictionary
	assert_eq(placements.size(), 3, "Placement enum 3 üye")
	var keys: Dictionary = map.get("PLACEMENT_KEYS", {}) as Dictionary
	assert_eq(keys.size(), 3, "PLACEMENT_KEYS 3 yerleşim")
	for value: String in ["FUSE_RESCUE", "GOLDEN_CUTTER", "INSULATION_SPRAY"]:
		assert_true(keys.values().has(value), "PLACEMENT_KEYS: " + value)


func test_default_limits_constant_matches_spec() -> void:
	if _manager == null:
		return
	assert_eq(_limits_constant.size(), 3, "DEFAULT_LIMITS 3 yerleşim")
	for key: String in EXPECTED_LIMITS:
		assert_true(_limits_constant.has(key), "DEFAULT_LIMITS: " + key)
		var expected: Dictionary = EXPECTED_LIMITS[key] as Dictionary
		var actual: Dictionary = _limits_constant.get(key, {}) as Dictionary
		assert_eq(int(actual.get("per_run", -1)), int(expected["per_run"]), key + " per_run")
		assert_eq(int(actual.get("per_session", -1)), int(expected["per_session"]), key + " per_session")


func test_ads_json_matches_spec() -> void:
	var text: String = FileAccess.get_file_as_string(AD_LIMITS_PATH)
	assert_true(text != "", "data/ads.json okunabilmeli")
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "data/ads.json nesne olmalı")
	if not (parsed is Dictionary):
		return
	var table: Dictionary = parsed as Dictionary
	assert_eq(table.size(), 3, "ads.json 3 yerleşim")
	for key: String in EXPECTED_LIMITS:
		assert_true(table.has(key), "ads.json: " + key)
		var expected: Dictionary = EXPECTED_LIMITS[key] as Dictionary
		var actual: Dictionary = table.get(key, {}) as Dictionary
		assert_eq(int(actual.get("per_run", -1)), int(expected["per_run"]), key + " per_run")
		assert_eq(int(actual.get("per_session", -1)), int(expected["per_session"]), key + " per_session")


func test_default_provider_is_mock_and_ready() -> void:
	assert_not_null(_default_provider, "varsayılan sağlayıcı MockAdsProvider olmalı")
	if _default_provider == null:
		return
	var script: Script = _default_provider.get_script() as Script
	assert_not_null(script, "sağlayıcı script'i")
	if script != null:
		assert_true(script.resource_path.ends_with("mock_ads_provider.gd"),
			"varsayılan sağlayıcı mock olmalı: " + script.resource_path)
	assert_true(_default_provider.is_ready(_fuse), "mock FUSE_RESCUE için hazır")
	assert_true(_default_provider.is_ready(_cutter), "mock GOLDEN_CUTTER için hazır")
	assert_true(_default_provider.is_ready(_spray), "mock INSULATION_SPRAY için hazır")


# ---------------------------------------------------------------- akış
func test_all_three_placements_reward_once() -> void:
	if _manager == null:
		return
	for placement: int in _placements():
		assert_true(_can_offer(placement), "başlangıçta teklif edilebilmeli: %d" % placement)
		_show(placement)
		assert_eq(_starts.size(), _rewards.size(), "her reklam için ad_started")
		var last: Dictionary = _rewards[_rewards.size() - 1]
		assert_eq(int(last["placement"]), placement, "ödül yerleşimi")
		assert_true(bool(last["success"]), "ödül başarılı")
		assert_eq(_used_run(placement), 1, "tur içi kullanım 1")
		assert_eq(_used_session(placement), 1, "oturum kullanımı 1")
		assert_false(_can_offer(placement), "per_run=1 sonrası teklif kapanmalı")
	assert_eq(_rewards.size(), 3, "üç yerleşim de ödüllendi")
	assert_eq(_starts.size(), 3, "üç ad_started")
	assert_eq(_ad_failures.size(), 0, "bu akışta ad_failed olmamalı")


func test_second_use_blocked_until_reset_run_limits() -> void:
	if _manager == null:
		return
	_show(_fuse)
	assert_eq(_used_run(_fuse), 1)
	assert_false(_can_offer(_fuse), "aynı turda ikinci kez teklif edilmez")
	_show(_fuse)
	assert_eq(_rewards.size(), 1, "ikinci show_rewarded ödül üretmemeli")
	assert_eq(_ad_failures.size(), 1, "ikinci show_rewarded ad_failed üretmeli")
	assert_eq(String(_ad_failures[0]["reason"]), "not_available")
	_manager.call("reset_run_limits")
	assert_true(_can_offer(_fuse), "reset_run_limits sonrası tekrar teklif")
	_show(_fuse)
	assert_eq(_used_run(_fuse), 1, "yeni turda sayaç 1")
	assert_eq(_used_session(_fuse), 2, "oturum sayacı birikmeli")


func test_session_limits_enforced_and_reset_restores() -> void:
	if _manager == null:
		return
	_consume_session_uses(_fuse, 5)
	assert_false(_can_offer(_fuse), "FUSE_RESCUE per_session=5 dolmalı")
	_manager.call("reset_run_limits")
	assert_false(_can_offer(_fuse), "per_session dolunca reset_run_limits yetmez")
	_consume_session_uses(_cutter, 3)
	assert_false(_can_offer(_cutter), "GOLDEN_CUTTER per_session=3 dolmalı")
	_consume_session_uses(_spray, 3)
	assert_false(_can_offer(_spray), "INSULATION_SPRAY per_session=3 dolmalı")
	assert_eq(_used_session(_fuse), 5)
	assert_eq(_used_session(_cutter), 3)
	assert_eq(_used_session(_spray), 3)
	_manager.call("reset_session_limits")
	for placement: int in _placements():
		assert_true(_can_offer(placement), "reset_session_limits sonrası teklif açılmalı: %d" % placement)


func test_pending_blocks_concurrent_ads() -> void:
	if _manager == null:
		return
	var deferred: StubAdsProvider = StubAdsProvider.new(false)
	_manager.call("set_provider", deferred)
	_manager.call("reset_run_limits")
	_show(_fuse)
	assert_eq(_starts.size(), 1, "ilk reklam başladı")
	assert_eq(_rewards.size(), 0, "reklam henüz bitmedi")
	assert_true(bool(_manager.call("has_pending")), "pending koruması devrede")
	assert_false(_can_offer(_cutter), "pending varken yeni teklif yok")
	_show(_cutter)
	assert_eq(_ad_failures.size(), 1, "ikinci reklam reddedilmeli")
	assert_eq(String(_ad_failures[0]["reason"]), "already_pending")
	assert_eq(_used_run(_cutter), 0, "reddedilen reklam limit tüketmemeli")
	_manager.call("reset_run_limits")
	assert_false(bool(_manager.call("has_pending")), "reset pending'i temizler")
	assert_true(_can_offer(_cutter), "reset sonrası yeniden teklif")


func test_double_reward_signal_is_idempotent() -> void:
	if _manager == null:
		return
	var double_stub: StubAdsProvider = StubAdsProvider.new(true)
	double_stub.reward_emits = 2
	_manager.call("set_provider", double_stub)
	_manager.call("reset_run_limits")
	_show(_fuse)
	assert_eq(_rewards.size(), 1, "çift provider sinyali tek ödül üretmeli")
	assert_eq(_used_run(_fuse), 1, "tur sayacı bir kez artmalı")
	assert_eq(_used_session(_fuse), 1, "oturum sayacı bir kez artmalı")


func test_failed_ad_does_not_consume_limit() -> void:
	if _manager == null:
		return
	var failing: StubAdsProvider = StubAdsProvider.new(false)
	failing.fail_on_show = true
	_manager.call("set_provider", failing)
	_manager.call("reset_run_limits")
	_show(_spray)
	assert_eq(_rewards.size(), 1, "başarısız reklam da sonuç sinyali üretir")
	assert_false(bool(_rewards[0]["success"]), "success=false")
	assert_eq(_ad_failures.size(), 1, "ad_failed bir kez")
	assert_eq(_used_run(_spray), 0, "başarısız reklam tur limiti tüketmez")
	assert_eq(_used_session(_spray), 0, "başarısız reklam oturum limiti tüketmez")
	assert_false(bool(_manager.call("has_pending")), "başarısızlık pending'i kapatır")
	assert_true(_can_offer(_spray), "başarısızlıktan sonra yeniden teklif")


func test_no_ads_provider_offers_nothing() -> void:
	if _manager == null:
		return
	_manager.call("set_provider", NoAdsProvider.new())
	_manager.call("reset_run_limits")
	for placement: int in _placements():
		assert_false(_can_offer(placement), "NoAdsProvider teklif vermemeli: %d" % placement)
	_show(_fuse)
	assert_eq(_rewards.size(), 0, "reklam yoksa ödül de yok")
	assert_eq(_ad_failures.size(), 1, "not_available")


## Mock sağlayıcı: 1.2 sn timer'ı beklemeden `_finish` ile sürülür; her gösterim
## tam olarak bir terminal sinyal (rewarded XOR failed) üretmeli.
func test_mock_provider_finishes_exactly_once() -> void:
	var mock: MockAdsProvider = MockAdsProvider.new()
	mock.initialize()
	var counters: Array[int] = [0, 0, 0]  # shown, rewarded, failed
	mock.shown.connect(func() -> void: counters[0] += 1)
	mock.rewarded.connect(func() -> void: counters[1] += 1)
	mock.failed.connect(func(_reason: String) -> void: counters[2] += 1)
	for i: int in 20:
		var generation: int = int(mock.get("_generation"))
		mock.show(_fuse)
		assert_eq(int(mock.get("_generation")), generation + 1, "her show yeni nesil")
		var before_terminal: int = counters[1] + counters[2]
		mock.call("_finish", int(mock.get("_generation")))
		assert_eq(counters[1] + counters[2], before_terminal + 1, "tam bir terminal sinyal (%d)" % i)
		# Gerçek timer geç gelirse eski nesil olduğu için yok sayılır.
		mock.set("_generation", int(mock.get("_generation")) + 1)
	assert_eq(counters[0], 20, "20 shown")
	assert_eq(counters[1] + counters[2], 20, "20 terminal sinyal")
	assert_greater(float(counters[1]), 0.0, "mock en az bir başarı üretti")


# ---------------------------------------------------------------- ses
func test_audio_service_contract_and_sound_files() -> void:
	assert_not_null(_audio, "AudioService autoload")
	if _audio == null:
		return
	for sound_name: String in EXPECTED_SOUNDS:
		assert_true(bool(_audio.call("has_sound", sound_name)), "sounds.json: " + sound_name)
		var path: String = SOUNDS_DIR.path_join(sound_name + ".wav")
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, "wav açılabilmeli: " + path)
		if file != null:
			assert_greater(float(file.get_length()), 512.0, "wav > 512 bayt: " + path)
			file.close()
	assert_false(bool(_audio.call("has_sound", "yok_boyle_bir_ses")), "tanımsız ses yok")
	_audio.call("set_muted", true)
	assert_true(bool(_audio.get("muted")), "set_muted(true) -> muted")
	_audio.call("set_muted", false)
	assert_false(bool(_audio.get("muted")), "set_muted(false) -> açık")
	# Headless'ta sessiz: bunlar yalnızca çökmemeli; eksik ad tek uyarı üretir.
	_audio.call("play", "ui_tap", 0.05)
	_audio.call("play", "yok_boyle_bir_ses")


# ---------------------------------------------------------------- yardımcılar
## Testler için sağlayıcı: senkron/askıda ödül, hata yolu ve çift sinyal seçilebilir.
class StubAdsProvider extends AdsProvider:
	var ready: bool = true
	var reward_immediately: bool = true
	var fail_on_show: bool = false
	var reward_emits: int = 1
	var show_count: int = 0

	func _init(immediate: bool = true) -> void:
		reward_immediately = immediate

	func is_ready(_placement: int) -> bool:
		return ready

	func show(_placement: int) -> void:
		show_count += 1
		shown.emit()
		if fail_on_show:
			failed.emit("no_fill")
			return
		if not reward_immediately:
			return
		for i: int in reward_emits:
			rewarded.emit()


func _placements() -> Array[int]:
	return [_fuse, _cutter, _spray]


func _read_manager_constants() -> void:
	var map: Dictionary = (_manager.get_script() as GDScript).get_script_constant_map()
	var placements: Dictionary = map.get("Placement", {}) as Dictionary
	_fuse = int(placements.get("FUSE_RESCUE", -1))
	_cutter = int(placements.get("GOLDEN_CUTTER", -1))
	_spray = int(placements.get("INSULATION_SPRAY", -1))
	_limits_constant = map.get("DEFAULT_LIMITS", {}) as Dictionary


func _connect_signals() -> void:
	if not _manager.is_connected(&"rewarded_finished", _on_rewarded):
		_manager.connect(&"rewarded_finished", _on_rewarded)
	if not _manager.is_connected(&"ad_failed", _on_failed):
		_manager.connect(&"ad_failed", _on_failed)
	if not _manager.is_connected(&"ad_started", _on_started):
		_manager.connect(&"ad_started", _on_started)


func _disconnect_signals() -> void:
	if _manager.is_connected(&"rewarded_finished", _on_rewarded):
		_manager.disconnect(&"rewarded_finished", _on_rewarded)
	if _manager.is_connected(&"ad_failed", _on_failed):
		_manager.disconnect(&"ad_failed", _on_failed)
	if _manager.is_connected(&"ad_started", _on_started):
		_manager.disconnect(&"ad_started", _on_started)


func _can_offer(placement: int) -> bool:
	if _manager == null:
		return false
	return bool(_manager.call("can_offer", placement))


func _show(placement: int) -> void:
	if _manager == null:
		return
	_manager.call("show_rewarded", placement)


func _used_run(placement: int) -> int:
	if _manager == null:
		return 0
	return int(_manager.call("used_in_run", placement))


func _used_session(placement: int) -> int:
	if _manager == null:
		return 0
	return int(_manager.call("used_in_session", placement))


func _consume_session_uses(placement: int, count: int) -> void:
	for i: int in count:
		_show(placement)
		_manager.call("reset_run_limits")


func _on_started(placement: int) -> void:
	_starts.append(placement)


func _on_rewarded(placement: int, success: bool) -> void:
	_rewards.append({"placement": placement, "success": success})


func _on_failed(placement: int, reason: String) -> void:
	_ad_failures.append({"placement": placement, "reason": reason})
