extends TestCase

## RunFlow: ödüllü reklam yalnız başarıda ödül verir; geçiş reklamı AdPacing'e uyar;
## "bu geçişte ödüllü izlendiyse geçiş reklamı yok" kuralı. AdManager autoload'u sahte sağlayıcıyla
## sürülür ve test sonunda eski sağlayıcı geri konur. Kayıt diske YAZILMAZ (persist=false).

var _flow: RunFlow = null
var _ads: Node = null
var _progress: Node = null
var _old_provider: AdsProvider = null
var _old_persist: bool = true


## Anında biten sağlayıcı: ödüllü -> rewarded, geçiş -> dismissed. `fail` ise ödülsüz hata.
class InstantProvider extends AdsProvider:
	var fail: bool = false
	var shown_count: int = 0

	func is_ready(_placement: int) -> bool:
		return true

	func show(placement: int) -> void:
		shown_count += 1
		shown.emit()
		if fail:
			failed.emit("no_fill")
		elif placement == INTERSTITIAL_PLACEMENT:
			dismissed.emit()
		else:
			rewarded.emit()


func before_each() -> void:
	AnalyticsLog.echo = false
	AnalyticsLog.clear()
	_ads = autoload_node("AdManager")
	_progress = autoload_node("Progress")
	_old_provider = _ads.get("provider") as AdsProvider
	_old_persist = bool(_progress.get("persist"))
	_progress.set("persist", false)
	_progress.call("reset_state")
	_ads.call("reset_session_limits")
	_flow = RunFlow.new()
	add_node(_flow)


func after_each() -> void:
	_flow.queue_free()
	_ads.call("set_provider", _old_provider)
	_ads.call("reset_session_limits")
	_progress.call("reset_state")
	_progress.set("persist", _old_persist)


func _use(provider: InstantProvider) -> void:
	_ads.call("set_provider", provider)


func test_win_pays_and_advances_level() -> void:
	_flow.on_level_start(1)
	var result: Dictionary = _flow.on_win(1)
	assert_eq(int(result["coins"]), 20)
	assert_eq(int(result["level"]), 2)
	assert_eq(int(result["stars"]), 1)
	assert_eq(int(_progress.call("coins")), 20)
	assert_eq(int(_progress.call("win_streak")), 1)
	assert_eq(AnalyticsLog.count("level_win"), 1)


func test_rewarded_ad_grants_only_on_success() -> void:
	var provider: InstantProvider = InstantProvider.new()
	_use(provider)
	var granted: Array[int] = [0]
	var skipped: Array[int] = [0]
	_flow.on_level_start(8)
	_flow.watch(AdManager.Placement.DOUBLE_COINS, func() -> void: granted[0] += 1, func() -> void: skipped[0] += 1)
	assert_eq([granted[0], skipped[0]], [1, 0])
	assert_eq(AnalyticsLog.count("rewarded_watched"), 1)
	# Aynı turda ikinci kez sunulmaz (per_run=1).
	assert_false(_flow.can_watch(AdManager.Placement.DOUBLE_COINS))
	# Yeni turda başarısız reklam: ödül yok, "atlandı" geri çağrısı.
	_flow.on_level_start(9)
	provider.fail = true
	_flow.watch(AdManager.Placement.EXTRA_FUSE, func() -> void: granted[0] += 1, func() -> void: skipped[0] += 1)
	assert_eq([granted[0], skipped[0]], [1, 1])
	assert_eq(AnalyticsLog.count("rewarded_skipped"), 1)


func test_double_bonus_uses_multiplier_from_balance() -> void:
	assert_eq(_flow.double_bonus(20), 20, "2x: fazlalık = ödül kadar")
	assert_eq(_flow.double_bonus(0), 0)


func test_loss_resets_win_streak() -> void:
	_flow.on_level_start(1)
	_flow.on_win(1)
	assert_eq(int(_progress.call("win_streak")), 1)
	_flow.on_lose(2)
	assert_eq(int(_progress.call("win_streak")), 0)


func test_rewarded_hidden_in_quiet_period() -> void:
	_use(InstantProvider.new())
	_flow.on_level_start(2)
	assert_false(_flow.can_watch(AdManager.Placement.DOUBLE_COINS), "ilk 3 seviyede ödüllü reklam sunulmaz")
	_flow.on_level_start(4)
	assert_true(_flow.can_watch(AdManager.Placement.DOUBLE_COINS))


func test_game_level_start_hides_banner() -> void:
	_use(InstantProvider.new())
	_flow.on_level_start(6)
	assert_false(bool(_ads.get("banner_visible")))
	assert_eq(_ads.get("banner_screen"), &"game")


## Tam geçiş reklamı döngüsü: 5. seviye bitince reklam, sonra 2 seviye sonra, sonra 3 seviye sonra.
## Zaman kuralı (90 sn) bu testte kayıt zamanı geriye alınarak geçilir.
func test_interstitial_follows_pacing_cycle() -> void:
	var provider: InstantProvider = InstantProvider.new()
	_use(provider)
	var continued: Array[int] = [0]
	var ad_levels: Array[int] = []
	for level: int in range(1, 16):
		_flow.on_level_start(level)
		_flow.on_win(level)
		(_progress.get("data") as ProgressData).last_interstitial_time = 0.0
		var before: int = provider.shown_count
		_flow.maybe_interstitial(level, func() -> void: continued[0] += 1)
		if provider.shown_count > before:
			ad_levels.append(level)
	assert_eq(continued[0], 15, "akış her zaman sürer")
	assert_eq(ad_levels, [5, 7, 10, 12, 15] as Array[int])
	assert_eq(AnalyticsLog.count("interstitial_shown"), 5)


func test_interstitial_respects_ninety_second_gap() -> void:
	var provider: InstantProvider = InstantProvider.new()
	_use(provider)
	var data: ProgressData = _progress.get("data") as ProgressData
	data.levels_since_interstitial = 9
	_flow.maybe_interstitial(5, func() -> void: pass)
	assert_eq(provider.shown_count, 1)
	data.levels_since_interstitial = 9
	_flow.maybe_interstitial(8, func() -> void: pass)
	assert_eq(provider.shown_count, 1, "az önce reklam gösterildi: 90 sn dolmadan ikincisi yok")
	data.last_interstitial_time -= 91.0
	_flow.maybe_interstitial(8, func() -> void: pass)
	assert_eq(provider.shown_count, 2)


func test_no_interstitial_when_ads_removed_or_just_watched_rewarded() -> void:
	var provider: InstantProvider = InstantProvider.new()
	_use(provider)
	var continued: Array[int] = [0]
	var data: ProgressData = _progress.get("data") as ProgressData
	data.levels_since_interstitial = 9
	_progress.call("set_remove_ads_owned", true)
	_flow.maybe_interstitial(9, func() -> void: continued[0] += 1)
	assert_eq([continued[0], provider.shown_count], [1, 0], "reklamlar kaldırıldı")
	_progress.call("set_remove_ads_owned", false)
	_flow.on_level_start(8)
	_flow.watch(AdManager.Placement.DOUBLE_COINS, func() -> void: pass)
	var shown_after_rewarded: int = provider.shown_count
	_flow.maybe_interstitial(8, func() -> void: continued[0] += 1)
	assert_eq([continued[0], provider.shown_count], [2, shown_after_rewarded], "ödüllü izlenen geçişte geçiş reklamı yok")


func test_interstitial_failure_never_blocks_flow() -> void:
	var provider: InstantProvider = InstantProvider.new()
	provider.fail = true
	_use(provider)
	var continued: Array[int] = [0]
	(_progress.get("data") as ProgressData).levels_since_interstitial = 9
	_flow.maybe_interstitial(7, func() -> void: continued[0] += 1)
	assert_eq(continued[0], 1, "reklam gösterilemese de akış devam eder")
	assert_eq(AnalyticsLog.count("interstitial_shown"), 0)
