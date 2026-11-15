extends Node
## Reklam orkestrasyonu (autoload `AdManager`). SDK bilmez; `AdsProvider` ile konuşur. Oyun kodu bunu doğrudan değil
## `Ads` cephesiyle (scripts/services/ads.gd) kullanır.
##
## Güvenceler:
##  * Ödül YALNIZCA sağlayıcıdan `rewarded` gelince verilir (bir istek = en fazla bir ödül; geç/yinelenen sinyal yok sayılır).
##  * Onay (consent) çözülmeden hiçbir reklam sunulmaz/istenmez.
##  * Reklam gelmezse (3 sn) ya da takılırsa (max_ad_seconds) akış SERBEST kalır; oyun asla reklama bağımlı beklemez.
##  * Sağlayıcı yoksa/hazır değilse her çağrı güvenli no-op'tur.
##  * Geçiş reklamı kararı `AdPacing`de (saf); burası yalnız bağlam kurar ve sağlayıcıyı çalıştırır.

signal ad_started(placement: int)
## success=true ise ödül verildi (limitler sayıldı). success=false: ödül YOK.
signal rewarded_finished(placement: int, success: bool)
signal ad_failed(placement: int, reason: String)
## Geçiş reklamı bitti (success=false: gösterilemedi); akış her iki durumda da devam eder.
signal interstitial_finished(success: bool)
## Onay çözüldü / sağlayıcı değişti: UI reklam düğmelerini yeniden değerlendirsin.
signal availability_changed()

var provider: AdsProvider = null
var env: AdEnvironment = null
var config: Dictionary = {}
## Son `maybe_interstitial` kararının nedeni (AdPacing.REASON_*; hata ayıklama/probe için).
var last_pacing_reason: String = ""

var _used_run: Dictionary = {}
var _used_session: Dictionary = {}
var _pending: int = -1
var _pending_shown: bool = false
var _pending_ticket: int = 0
var _on_reward: Callable = Callable()
var _on_fail: Callable = Callable()
var _on_then: Callable = Callable()
var _consent_resolved: bool = false
var _can_request_ads: bool = false
var _consent_generation: int = 0
var _deaths_since_interstitial: int = 0
var _rewarded_this_run: bool = false
var _show_timeout: float = 3.0
var _max_ad_seconds: float = 180.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup(AdConfig.load_file(), SettingsAdEnvironment.new(), make_default_provider())


## Seçim: AdMob yerel eklentisi (Android singleton) varsa AdMob; yoksa hata ayıklama sürümünde sahte sağlayıcı;
## yayın sürümünde reklamsız (sahte "ödül" ASLA gerçek oyuncuya verilmez).
## Komut satırı (yalnız hata ayıklama): --ads=none  --ads-outcome=success|dismissed|no_fill|timeout  --ads-delay=<sn>
static func make_default_provider() -> AdsProvider:
	if AdmobAdsProvider.plugin_present():
		return AdmobAdsProvider.new()
	if not OS.is_debug_build():
		return NoAdsProvider.new()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--ads=none" in args:
		return NoAdsProvider.new()
	var mock: MockAdsProvider = MockAdsProvider.new()
	for arg: String in args:
		if arg.begins_with("--ads-outcome="):
			var names: Array = MockAdsProvider.Outcome.keys()
			var idx: int = names.find(arg.get_slice("=", 1).to_upper())
			if idx >= 0:
				mock.outcome = idx as MockAdsProvider.Outcome
		elif arg.begins_with("--ads-delay="):
			mock.delay_seconds = maxf(0.0, arg.get_slice("=", 1).to_float())
	return mock


## Ortamı kurar (ağaca girmeden de çağrılabilir: birim testler). Sağlayıcı verilirse onay akışı başlar.
func setup(new_config: Dictionary, environment: AdEnvironment, new_provider: AdsProvider) -> void:
	config = new_config
	env = environment
	_show_timeout = AdConfig.show_timeout(config)
	_max_ad_seconds = AdConfig.max_ad_seconds(config)
	set_provider(new_provider)


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
	_abandon_pending()
	provider = new_provider
	_consent_resolved = false
	_can_request_ads = false
	_consent_generation += 1
	if provider == null:
		availability_changed.emit()
		return
	provider.shown.connect(_on_provider_shown)
	provider.rewarded.connect(_on_provider_rewarded)
	provider.failed.connect(_on_provider_failed)
	provider.dismissed.connect(_on_provider_dismissed)
	provider.request_consent(_on_consent_resolved.bind(_consent_generation))


func _on_consent_resolved(can_request: bool, generation: int) -> void:
	if generation != _consent_generation or provider == null or _consent_resolved:
		return
	_consent_resolved = true
	_can_request_ads = can_request
	if can_request:
		provider.initialize()
	availability_changed.emit()


# --- Sorgular -------------------------------------------------------------------------------

func consent_resolved() -> bool:
	return _consent_resolved


func is_ads_removed() -> bool:
	return env != null and env.is_ads_removed()


func privacy_options_required() -> bool:
	return provider != null and _consent_resolved and provider.privacy_options_required()


func show_privacy_options(on_done: Callable) -> void:
	if provider == null or not privacy_options_required():
		_call(on_done)
		return
	provider.show_privacy_options(on_done)


## Bu yerleşim şu anda sunulabilir mi (düğme gösterilsin mi)? Sağlayıcı hazır + onay çözülmüş + sınırlar içinde.
## INTERSTITIAL için yalnız "sağlayıcı hazır / remove-ads değil" bakılır; zaman/koşu kuralı `maybe_interstitial`da (bağlam ister).
func can_show(placement: int) -> bool:
	if provider == null or env == null or not _consent_resolved or not _can_request_ads or _pending != -1:
		return false
	if not AdPlacement.KEYS.has(placement):
		return false
	if AdPlacement.is_interstitial(placement):
		return not env.is_ads_removed() and provider.is_ready(placement)
	if not provider.is_ready(placement):
		return false
	var key: String = AdPlacement.key(placement)
	var limits: Dictionary = AdConfig.limits(config, key)
	if int(_used_run.get(key, 0)) >= int(limits["per_run"]) or int(_used_session.get(key, 0)) >= int(limits["per_session"]):
		return false
	if placement == AdPlacement.Id.DAILY_BONUS and int(limits["per_day"]) >= 1:
		# Günlük sınır kayıtta tutulur (tarih anahtarı); güvenilir saat geri alınmaya karşı korur.
		if env.daily_date() == env.today_key():
			return false
	return true


func used_in_run(placement: int) -> int:
	return int(_used_run.get(AdPlacement.key(placement), 0))


# --- Yaşam döngüsü ---------------------------------------------------------------------------

## Yeni koşu başlarken: koşu limitlerini ve "ödüllü izlendi" işaretini sıfırlar.
func begin_run() -> void:
	_used_run.clear()
	_rewarded_this_run = false
	_abandon_pending()


## Oturum limitlerini de sıfırlar (testler ve "yeni oyun" için).
func reset_session() -> void:
	begin_run()
	_used_session.clear()
	_deaths_since_interstitial = 0


# --- Ödüllü ---------------------------------------------------------------------------------

## Ödüllü reklam ister. `on_reward` YALNIZ sağlayıcı ödülü onaylayınca çağrılır; başarısızlıkta `on_fail(reason)`.
## Dönüş: istek başladı mı (false -> hiçbir şey yapılmadı; `on_fail("not_available")` çağrılır).
func show_rewarded(placement: int, on_reward: Callable, on_fail: Callable = Callable()) -> bool:
	if not AdPlacement.is_rewarded(placement):
		_fail_now(placement, "not_rewarded", on_fail)
		return false
	if not can_show(placement):
		_fail_now(placement, "not_available", on_fail)
		return false
	_on_reward = on_reward
	_on_fail = on_fail
	_begin_pending(placement)
	ad_started.emit(placement)
	provider.show(placement)
	return true


func _fail_now(placement: int, reason: String, on_fail: Callable) -> void:
	ad_failed.emit(placement, reason)
	if on_fail.is_valid():
		on_fail.call(reason)


# --- Geçiş ----------------------------------------------------------------------------------

## Koşu bittiğinde (Settings.record_run SONRASI) bir kez çağrılır. Kural uygunsa geçiş reklamı gösterir; ne olursa olsun
## `then` TAM BİR KEZ çağrılır (reklam yok/gösterilemedi/bitti). `run_context`: {"died": bool (varsayılan true),
## "moment": String (varsayılan "run_end"), "runs_completed": int (isteğe bağlı geçersiz kılma)}.
## Dönüş: reklam gösterilmeye başlandı mı.
func maybe_interstitial(run_context: Dictionary, then: Callable) -> bool:
	if bool(run_context.get("died", true)):
		_deaths_since_interstitial += 1
	if env == null:
		last_pacing_reason = "no_environment"
		_call(then)
		return false
	var ctx: AdPacing.Context = AdPacing.Context.new()
	ctx.moment = String(run_context.get("moment", "run_end"))
	ctx.runs_completed = int(run_context.get("runs_completed", env.runs_done()))
	ctx.deaths_since_last = _deaths_since_interstitial
	ctx.now_unix = env.now()
	ctx.last_interstitial_unix = env.last_interstitial()
	ctx.rewarded_just_watched = _rewarded_this_run
	ctx.ads_removed = env.is_ads_removed()
	last_pacing_reason = AdPacing.evaluate(ctx, AdConfig.pacing(config))
	if last_pacing_reason != AdPacing.REASON_OK:
		_call(then)
		return false
	if not can_show(AdPlacement.Id.INTERSTITIAL):
		last_pacing_reason = "provider_unavailable"
		_call(then)
		return false
	_on_then = then
	_begin_pending(AdPlacement.Id.INTERSTITIAL)
	ad_started.emit(AdPlacement.Id.INTERSTITIAL)
	provider.show(AdPlacement.Id.INTERSTITIAL)
	return true


func _call(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()


func preload_ads() -> void:
	if provider != null and _consent_resolved and _can_request_ads:
		provider.preload_ads()


# --- Bekleyen istek ve zaman aşımları ----------------------------------------------------------

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Bekleyen gösterim için iki ters sayım: (1) `show_start_timeout_seconds` içinde ekrana gelmezse, (2) `max_ad_seconds`
## içinde bitmezse akış reklamsız serbest bırakılır (ürün kararı: reklam yoksa oyuncu hiçbir şey fark etmeden devam eder).
func _begin_pending(placement: int) -> void:
	_pending = placement
	_pending_shown = false
	_pending_ticket += 1
	var ticket: int = _pending_ticket
	var tree: SceneTree = _tree()
	if tree != null:
		tree.create_timer(_show_timeout, true, false, true).timeout.connect(_on_show_timeout.bind(ticket))
		tree.create_timer(_max_ad_seconds, true, false, true).timeout.connect(_on_hard_timeout.bind(ticket))


func _on_show_timeout(ticket: int) -> void:
	if ticket == _pending_ticket and _pending != -1 and not _pending_shown:
		_on_provider_failed("timeout")


func _on_hard_timeout(ticket: int) -> void:
	if ticket == _pending_ticket and _pending != -1:
		_on_provider_failed("timeout")


## Bekleyen isteği ödülsüz bırakır (sağlayıcı değişti / yeni koşu): geri çağrılar çağrılmaz.
func _abandon_pending() -> void:
	_pending = -1
	_pending_ticket += 1
	_on_reward = Callable()
	_on_fail = Callable()
	_on_then = Callable()


func _on_provider_shown() -> void:
	_pending_shown = true


## Geçiş reklamı kapanınca tamamlanır; ödüllü reklamda kapanış tek başına ödül sayılmaz
## (ödül `rewarded` ile gelir; ödülsüz kapanışı sağlayıcı `failed` olarak bildirir).
func _on_provider_dismissed() -> void:
	if _pending == AdPlacement.Id.INTERSTITIAL:
		_finish_interstitial(true)


func _on_provider_rewarded() -> void:
	if _pending == -1:
		return   # geç/yinelenen sinyal: ödül YOK
	if _pending == AdPlacement.Id.INTERSTITIAL:
		_finish_interstitial(true)
		return
	var placement: int = _pending
	var reward: Callable = _on_reward
	_pending = -1
	_on_reward = Callable()
	_on_fail = Callable()
	var key: String = AdPlacement.key(placement)
	_used_run[key] = int(_used_run.get(key, 0)) + 1
	_used_session[key] = int(_used_session.get(key, 0)) + 1
	_rewarded_this_run = true
	if placement == AdPlacement.Id.DAILY_BONUS:
		env.set_daily_date(env.today_key())
	rewarded_finished.emit(placement, true)
	_call(reward)


func _on_provider_failed(reason: String) -> void:
	if _pending == -1:
		return
	if _pending == AdPlacement.Id.INTERSTITIAL:
		_finish_interstitial(false)
		return
	var placement: int = _pending
	var fail: Callable = _on_fail
	_pending = -1
	_on_reward = Callable()
	_on_fail = Callable()
	rewarded_finished.emit(placement, false)
	ad_failed.emit(placement, reason)
	if fail.is_valid():
		fail.call(reason)


func _finish_interstitial(success: bool) -> void:
	var shown: bool = _pending_shown or success
	var then: Callable = _on_then
	_pending = -1
	_on_then = Callable()
	if shown:
		env.record_interstitial()
		_deaths_since_interstitial = 0
	interstitial_finished.emit(success)
	_call(then)
