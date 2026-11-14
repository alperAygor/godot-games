extends Node

## Ödüllü reklam orkestrasyonu. SDK bilmez; `AdsProvider` ile konuşur.
## Ödül YALNIZCA sağlayıcıdan `rewarded` geldikten sonra verilir (idempotent).

## Ödüllü yerleşimler (tasarım belgesi): EXTRA_FUSE sigortalar bitince +1 hak, DOUBLE_COINS seviye sonu
## jeton ikiye katlama, HINT bir cihazın doğru prizi, DAY_PREVIEW gün önizleme, RENOVATION_EARLY yenileme
## parçasını erken açma. INTERSTITIAL ödüllü değildir: `show_interstitial()` ile gösterilir, ödül sinyali vermez.
## Sıra `AdsProvider.INTERSTITIAL_PLACEMENT` ile aynı kalmalı (testle sabitli). Yeni yerleşim sona eklenir.
enum Placement { EXTRA_FUSE, DOUBLE_COINS, HINT, DAY_PREVIEW, RENOVATION_EARLY, INTERSTITIAL }

const PLACEMENT_KEYS: Dictionary = {
	Placement.EXTRA_FUSE: "extra_fuse",
	Placement.DOUBLE_COINS: "double_coins",
	Placement.HINT: "hint",
	Placement.DAY_PREVIEW: "day_preview",
	Placement.RENOVATION_EARLY: "renovation_early",
	Placement.INTERSTITIAL: "interstitial_slot",
}

const LIMITS_PATH: String = "res://data/ads.json"
const SETTINGS_KEY: String = "settings"
const PACING_KEY: String = "interstitial"
const QUIET_KEY: String = "quiet"
const BANNER_KEY: String = "banner"
## Gösterim istendikten sonra reklam bu sürede ekrana gelmezse akış reklamsız sürer.
const DEFAULT_SHOW_TIMEOUT: float = 3.0

## data/ads.json okunamazsa kullanılan yedek limitler (tur = bir seviye denemesi).
const DEFAULT_LIMITS: Dictionary = {
	"extra_fuse": {"per_run": 1, "per_session": 30},
	"double_coins": {"per_run": 1, "per_session": 30},
	"hint": {"per_run": 3, "per_session": 60},
	"day_preview": {"per_run": 1, "per_session": 30},
	"renovation_early": {"per_run": 1, "per_session": 30},
	"interstitial_slot": {"per_run": 99, "per_session": 999},
}

signal ad_started(placement: Placement)
signal rewarded_finished(placement: Placement, success: bool)
signal ad_failed(placement: Placement, reason: String)
## Geçiş reklamı bitti (success=false: gösterilemedi); akış her iki durumda da devam eder.
signal interstitial_finished(success: bool)
## Banner görünürlüğü değişti (ekran kimliği ve görünür mü).
signal banner_changed(screen_id: StringName, visible: bool)

var provider: AdsProvider = null
## Son `set_banner_visible` çağrısının ekranı ve sonucu (mock yalnız kaydeder; testler okur).
var banner_screen: StringName = &""
var banner_visible: bool = false

var _limits: Dictionary = {}
var _used_run: Dictionary = {}
var _used_session: Dictionary = {}
var _pending: int = -1
## Bekleyen gösterim "ekrana geldi" sinyalini aldı mı; gelmediyse zaman aşımı akışı serbest bırakır.
var _pending_shown: bool = false
var _pending_ticket: int = 0
var _show_timeout: float = DEFAULT_SHOW_TIMEOUT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_limits()
	set_provider(make_default_provider())


## Seçim: AdMob eklentisi varsa AdMob; yoksa hata ayıklama sürümünde sahte sağlayıcı; yayın
## sürümünde reklamsız (sahte "ödül" ASLA gerçek oyuncuya verilmez).
static func make_default_provider() -> AdsProvider:
	if AdmobAdsProvider.plugin_present():
		return AdmobAdsProvider.new()
	if OS.is_debug_build():
		return MockAdsProvider.new()
	return NoAdsProvider.new()


func set_provider(new_provider: AdsProvider) -> void:
	if provider != null:
		if provider.shown.is_connected(_on_provider_shown):
			provider.shown.disconnect(_on_provider_shown)
		if provider.rewarded.is_connected(_on_provider_rewarded):
			provider.rewarded.disconnect(_on_provider_rewarded)
		if provider.failed.is_connected(_on_provider_failed):
			provider.failed.disconnect(_on_provider_failed)
		if provider.dismissed.is_connected(_on_provider_dismissed):
			provider.dismissed.disconnect(_on_provider_dismissed)
	provider = new_provider
	if provider != null:
		provider.shown.connect(_on_provider_shown)
		provider.rewarded.connect(_on_provider_rewarded)
		provider.failed.connect(_on_provider_failed)
		provider.dismissed.connect(_on_provider_dismissed)
		provider.initialize()


func can_offer(placement: Placement) -> bool:
	if provider == null or not provider.is_ready(placement):
		return false
	if _pending != -1:
		return false
	var key: String = PLACEMENT_KEYS.get(placement, "")
	var limit: Dictionary = _limits.get(key, DEFAULT_LIMITS.get(key, {"per_run": 1, "per_session": 1}))
	var used_run: int = int(_used_run.get(key, 0))
	var used_session: int = int(_used_session.get(key, 0))
	return used_run < int(limit.get("per_run", 1)) and used_session < int(limit.get("per_session", 1))


func show_rewarded(placement: Placement) -> void:
	if _pending != -1:
		ad_failed.emit(placement, "already_pending")
		return
	if not can_offer(placement):
		ad_failed.emit(placement, "not_available")
		return
	_begin_pending(placement)
	provider.show(placement)
	ad_started.emit(placement)


## Geçiş reklamı: sıklık kararı `AdPacing`de; burası yalnız sağlayıcıyı çalıştırır.
func show_interstitial() -> bool:
	if _pending != -1 or provider == null or not provider.is_ready(Placement.INTERSTITIAL):
		return false
	_begin_pending(Placement.INTERSTITIAL)
	provider.show(Placement.INTERSTITIAL)
	ad_started.emit(Placement.INTERSTITIAL)
	return true


## `data/ads.json` -> "interstitial" bloğu (AdPacing girdisi: first_after_level, gap_cycle ...).
func interstitial_pacing() -> Dictionary:
	return _block(PACING_KEY)


## `data/ads.json` -> "quiet" bloğu (ilk N seviye reklam/mağaza/açılır pencere yok).
func quiet_policy() -> Dictionary:
	return _block(QUIET_KEY)


func banner_policy() -> Dictionary:
	return _block(BANNER_KEY)


## Seviye geçişinde geçiş reklamı gösterilmeli mi? Tüm koşullar (sessiz dönem, 5. seviyeden sonra,
## 2-3 seviyede bir, 90 sn, ödüllü izlendi mi, reklamlar kaldırıldı mı) `AdPacing`dedir.
## `completed_level` az önce bitirilen seviyedir.
func should_show_interstitial(completed_level: int, rewarded_in_transition: bool) -> bool:
	var data: ProgressData = Progress.data
	return AdPacing.should_show(completed_level, Progress.remove_ads_owned(), rewarded_in_transition,
		data.levels_since_interstitial, data.interstitials_shown, data.last_interstitial_time,
		Time.get_unix_time_from_system(), interstitial_pacing(), quiet_policy())


## Banner politikası: yalnız mahalle (ana ekran) ve koleksiyon ekranında görünür; oyun ekranı dahil
## diğer her ekran gizler. Sessiz dönemde ve "reklamları kaldır" sonrası da gizlidir.
## Her ekran açılışında çağrılır; dönen değer banner'ın görünür olup olmadığıdır.
func set_banner_visible(screen_id: StringName) -> bool:
	var visible: bool = AdPacing.banner_allowed(screen_id, Progress.remove_ads_owned(),
		Progress.is_quiet_period(), banner_policy())
	banner_screen = screen_id
	banner_visible = visible
	if provider != null:
		if visible:
			provider.show_banner()
		else:
			provider.hide_banner()
	banner_changed.emit(screen_id, visible)
	return visible


## Ödüllü reklam politikası: sessiz dönemde (ilk seviyeler) hiçbir ödüllü reklam sunulmaz.
func is_offer_allowed(level_number: int) -> bool:
	return not AdPacing.is_quiet(level_number, quiet_policy())


## Sağlayıcıya sıradaki reklamları önceden yüklemesini söyler (açılış ve ekran geçişleri).
func preload_ads() -> void:
	if provider != null:
		provider.preload_ads()


func reset_run_limits() -> void:
	_used_run.clear()
	_pending = -1


## Oturum limitlerini de sıfırlar (testler ve "yeni oyun" için).
func reset_session_limits() -> void:
	_used_run.clear()
	_used_session.clear()
	_pending = -1


func used_in_run(placement: Placement) -> int:
	return int(_used_run.get(PLACEMENT_KEYS.get(placement, ""), 0))


## Bekleyen gösterim için ters sayım başlar: reklam `_show_timeout` sn içinde ekrana gelmezse
## başarısız sayılır. Neden: yüklü sanılan reklam gösterilemezse "Devam" düğmesi sonsuza dek
## beklemesin (ürün kararı: reklam yoksa oyuncu hiçbir şey fark etmeden devam eder).
func _begin_pending(placement: int) -> void:
	_pending = placement
	_pending_shown = false
	_pending_ticket += 1
	var ticket: int = _pending_ticket
	get_tree().create_timer(_show_timeout, true, false, true).timeout.connect(_on_show_timeout.bind(ticket))


func _on_show_timeout(ticket: int) -> void:
	if ticket == _pending_ticket and _pending != -1 and not _pending_shown:
		_on_provider_failed("timeout")


func _on_provider_shown() -> void:
	_pending_shown = true


## Geçiş reklamı kapanınca tamamlanır; ödüllü reklamda kapanış tek başına ödül sayılmaz
## (ödül `rewarded` ile gelir; ödülsüz kapanışı sağlayıcı `failed` olarak bildirir).
func _on_provider_dismissed() -> void:
	if _pending == Placement.INTERSTITIAL:
		_on_provider_rewarded()


func _on_provider_rewarded() -> void:
	if _pending == -1:
		return
	var placement: Placement = _pending
	_pending = -1
	if placement == Placement.INTERSTITIAL:
		interstitial_finished.emit(true)
		return
	var key: String = PLACEMENT_KEYS.get(placement, "")
	_used_run[key] = int(_used_run.get(key, 0)) + 1
	_used_session[key] = int(_used_session.get(key, 0)) + 1
	rewarded_finished.emit(placement, true)


func _on_provider_failed(reason: String) -> void:
	if _pending == -1:
		return
	var placement: Placement = _pending
	_pending = -1
	if placement == Placement.INTERSTITIAL:
		interstitial_finished.emit(false)
		return
	rewarded_finished.emit(placement, false)
	ad_failed.emit(placement, reason)


func _block(key: String) -> Dictionary:
	var block: Variant = _limits.get(key)
	return (block as Dictionary) if block is Dictionary else {}


func _load_limits() -> void:
	_limits = DEFAULT_LIMITS.duplicate(true)
	_show_timeout = DEFAULT_SHOW_TIMEOUT
	if not FileAccess.file_exists(LIMITS_PATH):
		push_warning("AdManager: %s yok, varsayılan limitler kullanılıyor" % LIMITS_PATH)
		return
	var text: String = FileAccess.get_file_as_string(LIMITS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("AdManager: %s okunamadı, varsayılan limitler" % LIMITS_PATH)
		return
	_limits = (parsed as Dictionary).duplicate(true)
	var settings: Variant = _limits.get(SETTINGS_KEY)
	if settings is Dictionary:
		_show_timeout = maxf(float((settings as Dictionary).get("show_start_timeout_seconds",
			DEFAULT_SHOW_TIMEOUT)), 0.5)
