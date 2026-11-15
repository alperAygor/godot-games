extends TestCase
## AdPacing: geçiş reklamı kuralları, TABLO testi. Veri data/ads.json'dan (AdConfig.pacing) gelir.

const NOW := 1_800_000_000

func _cfg() -> Dictionary:
	return AdConfig.pacing(AdConfig.load_file())

## Varsayılan bağlam: 4. koşu bitti, 2 ölüm, 600 sn geçti, ödüllü yok -> GÖSTERİLİR; testler tek alanı değiştirir.
func _ctx() -> AdPacing.Context:
	var c := AdPacing.Context.new()
	c.runs_completed = 4
	c.deaths_since_last = 2
	c.now_unix = NOW
	c.last_interstitial_unix = NOW - 600
	return c

func test_shipped_rules_match_design() -> void:
	var p := _cfg()
	eq(int(p["free_runs"]), 3, "ilk 3 koşu reklamsız")
	eq(int(p["min_seconds"]), 180, "en az 180 sn")
	eq(int(p["every_n_deaths"]), 2, "en fazla her 2. ölüm")
	eq(bool(p["block_after_rewarded"]), true, "ödüllüden sonra yok")
	eq(p["moments"], ["run_end"], "yalnız koşu sonu")

func test_baseline_shows() -> void:
	eq(AdPacing.evaluate(_ctx(), _cfg()), AdPacing.REASON_OK, "uygun bağlam gösterir")
	check(AdPacing.should_show(_ctx(), _cfg()), "should_show true")

func test_first_three_runs_never() -> void:
	for runs in [0, 1, 2, 3]:
		var c := _ctx()
		c.runs_completed = runs
		eq(AdPacing.evaluate(c, _cfg()), AdPacing.REASON_FREE_RUNS, "%d. koşu: yok" % runs)

func test_fourth_run_allowed() -> void:
	var c := _ctx()
	c.runs_completed = 4
	check(AdPacing.should_show(c, _cfg()), "4. koşu: var")
	c.runs_completed = 50
	check(AdPacing.should_show(c, _cfg()), "50. koşu: var")

func test_min_seconds_boundary() -> void:
	var c := _ctx()
	c.last_interstitial_unix = NOW - 179
	eq(AdPacing.evaluate(c, _cfg()), AdPacing.REASON_TOO_SOON, "179 sn: yok")
	c.last_interstitial_unix = NOW - 180
	eq(AdPacing.evaluate(c, _cfg()), AdPacing.REASON_OK, "180 sn: var")
	c.last_interstitial_unix = NOW - 181
	check(AdPacing.should_show(c, _cfg()), "181 sn: var")
	c.last_interstitial_unix = NOW
	eq(AdPacing.evaluate(c, _cfg()), AdPacing.REASON_TOO_SOON, "0 sn: yok")

func test_never_shown_before_has_no_time_limit() -> void:
	var c := _ctx()
	c.last_interstitial_unix = 0
	check(AdPacing.should_show(c, _cfg()), "hiç gösterilmediyse zaman şartı yok")

func test_clock_going_backwards_blocks() -> void:
	var c := _ctx()
	c.last_interstitial_unix = NOW + 10
	eq(AdPacing.evaluate(c, _cfg()), AdPacing.REASON_CLOCK, "saat geri: yok")
	c.last_interstitial_unix = NOW + 86400 * 400
	eq(AdPacing.evaluate(c, _cfg()), AdPacing.REASON_CLOCK, "yıllarca geri: yok")
	c.last_interstitial_unix = NOW   # aynı saniye: geri değil, ama 0 sn geçti
	eq(AdPacing.evaluate(c, _cfg()), AdPacing.REASON_TOO_SOON, "aynı saniye: erken")

func test_every_second_death() -> void:
	var c := _ctx()
	c.deaths_since_last = 0
	eq(AdPacing.evaluate(c, _cfg()), AdPacing.REASON_DEATHS, "0 ölüm: yok")
	c.deaths_since_last = 1
	eq(AdPacing.evaluate(c, _cfg()), AdPacing.REASON_DEATHS, "1. ölüm: yok")
	c.deaths_since_last = 2
	check(AdPacing.should_show(c, _cfg()), "2. ölüm: var")
	c.deaths_since_last = 5
	check(AdPacing.should_show(c, _cfg()), "reklam atlandıysa sonraki ölümde var")

func test_rewarded_just_watched_blocks() -> void:
	var c := _ctx()
	c.rewarded_just_watched = true
	eq(AdPacing.evaluate(c, _cfg()), AdPacing.REASON_REWARDED, "ödüllüden hemen sonra yok")
	var p := _cfg()
	p["block_after_rewarded"] = false
	check(AdPacing.should_show(c, p), "veri kapatırsa serbest")

func test_remove_ads_always_blocks() -> void:
	var c := _ctx()
	c.ads_removed = true
	eq(AdPacing.evaluate(c, _cfg()), AdPacing.REASON_ADS_REMOVED, "reklamsız: yok")
	c.runs_completed = 9999
	c.last_interstitial_unix = 0
	c.deaths_since_last = 9999
	eq(AdPacing.evaluate(c, _cfg()), AdPacing.REASON_ADS_REMOVED, "hangi koşulda olursa olsun yok")

func test_remove_ads_does_not_affect_rewarded() -> void:
	for id in AdPlacement.rewarded_ids():
		var c := _ctx()
		c.placement = id
		c.ads_removed = true
		c.runs_completed = 0
		eq(AdPacing.evaluate(c, _cfg()), AdPacing.REASON_OK, "%s: pacing'e tabi değil" % AdPlacement.key(id))

func test_only_allowed_moments() -> void:
	for moment in ["in_run", "cards", "boss", "", "menu"]:
		var c := _ctx()
		c.moment = moment
		eq(AdPacing.evaluate(c, _cfg()), AdPacing.REASON_MOMENT, "'%s' anında asla" % moment)

func test_disabled_by_data() -> void:
	var p := _cfg()
	p["enabled"] = false
	eq(AdPacing.evaluate(_ctx(), p), AdPacing.REASON_DISABLED, "veri kapatırsa hiç")

func test_rules_are_data_driven() -> void:
	var p := AdConfig.pacing({"interstitial": {"free_runs": 1, "min_seconds": 10, "every_n_deaths": 1}})
	var c := _ctx()
	c.runs_completed = 2
	c.deaths_since_last = 1
	c.last_interstitial_unix = NOW - 10
	check(AdPacing.should_show(c, p), "yeni sayılarla 2. koşu, 10 sn, 1 ölüm: var")
	c.runs_completed = 1
	eq(AdPacing.evaluate(c, p), AdPacing.REASON_FREE_RUNS, "free_runs=1: 1. koşu yok")
	c.runs_completed = 2
	c.last_interstitial_unix = NOW - 9
	eq(AdPacing.evaluate(c, p), AdPacing.REASON_TOO_SOON, "min_seconds=10: 9 sn yok")

func test_garbage_config_falls_back_to_safe_defaults() -> void:
	var p := AdConfig.pacing({"interstitial": {"free_runs": "x", "min_seconds": -5, "every_n_deaths": 0, "moments": 7, "enabled": "yes"}})
	eq(int(p["free_runs"]), 3, "bozuk free_runs -> 3")
	eq(int(p["min_seconds"]), 0, "negatif sn -> 0 (kırpılır)")
	eq(int(p["every_n_deaths"]), 1, "0 ölüm şartı -> en az 1")
	eq(p["moments"], ["run_end"], "bozuk moments -> varsayılan")
	eq(bool(p["enabled"]), true, "bozuk enabled -> varsayılan")
	var blank := AdConfig.pacing({})
	eq(int(blank["min_seconds"]), 180, "boş yapılandırma -> varsayılanlar")

func test_check_order_reports_most_specific_first() -> void:
	var c := _ctx()
	c.ads_removed = true
	c.runs_completed = 0
	eq(AdPacing.evaluate(c, _cfg()), AdPacing.REASON_ADS_REMOVED, "remove-ads her şeyden önce")
