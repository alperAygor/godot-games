extends TestCase
## AdFlow: veri doğrulama, ilk koşu temiz kuralı, çift çekirdek ekı, yenileme eşiği, geri sayım. Ayrıca TimeScale.

func test_shipped_file_values() -> void:
	var f := AdFlow.load_file()
	eq(f.min_completed_runs, 1, "ilk koşu temiz")
	eq(f.daily_bonus_cores, 50, "günlük bonus (dengeli: ≈ bir koşu)")
	eq(f.double_cores_multiplier, 2, "×2")
	near(f.revive_offer_seconds, 5.0, 0.001, "teklif geri sayımı")
	eq(f.reroll_grant, 1, "+1 yenileme")

func test_bad_values_fall_back() -> void:
	var f := AdFlow.from_dict({"daily_bonus_cores": "çok", "revive_offer_seconds": -3, "double_cores_multiplier": 0, "min_completed_runs": null})
	eq(f.daily_bonus_cores, 50, "metin → varsayılan")
	near(f.revive_offer_seconds, 1.0, 0.001, "alt sınıra sıkıştırılır")
	eq(f.double_cores_multiplier, 1, "çarpan ≥ 1")
	eq(f.min_completed_runs, 1, "null → varsayılan")
	eq(AdFlow.from_dict({"daily_bonus_cores": 99999999}).daily_bonus_cores, AdFlow.MAX_BONUS, "üst sınır")

func test_first_run_is_clean() -> void:
	var f := AdFlow.new()
	check(not f.ads_unlocked(0), "hiç koşu bitmedi: reklam arayüzü yok")
	check(f.ads_unlocked(1), "ikinci koşudan itibaren")
	check(f.ads_unlocked(40), "sonrası")

func test_double_bonus_is_extra_only() -> void:
	var f := AdFlow.new()
	eq(f.double_bonus(80), 80, "×2 = ek +80 (kazanç zaten kayıtlı)")
	eq(f.double_bonus(0), 0, "0 → 0")
	eq(f.double_bonus(-5), 0, "negatif → 0")
	f.double_cores_multiplier = 3
	eq(f.double_bonus(10), 20, "×3 = ek +20")

func test_reroll_offer_threshold() -> void:
	var f := AdFlow.new()
	check(f.reroll_offer_wanted(0), "yenileme bitti: teklif")
	check(not f.reroll_offer_wanted(1), "hakkı varken yok")

func test_countdown() -> void:
	var c := AdFlow.Countdown.new(5.0)
	eq(c.seconds_left(), 5, "başta 5")
	check(not c.tick(1.2), "bitmedi")
	eq(c.seconds_left(), 4, "3.8 → 4")
	near(c.fraction(), 3.8 / 5.0, 0.001, "oran")
	check(c.tick(10.0), "bitti: bir kez true")
	check(not c.tick(1.0), "ikinci kez true dönmez")
	eq(c.seconds_left(), 0, "0")
	check(c.expired, "bitti işareti")

func test_timescale_bug_death_slowmo_then_hitstop() -> void:
	## Eski hata: ölüm yavaş çekimi (0.3) sürerken başlayan vuruş donması, yavaş çekim 1.0'a döndükten sonra 0.3'ü geri yazardı.
	var t := TimeScale.new()
	var death := t.begin_override(0.3)
	near(t.current(), 0.3, 0.0001, "ölüm yavaş çekimi")
	var hit := t.begin_hit(0.1)
	near(t.current(), 0.03, 0.0001, "donma yavaş çekimle çarpılır")
	t.end_override(death)               # yavaş çekim bitti (0.9 sn)
	near(t.current(), 0.1, 0.0001, "donma sürerken yalnız donma")
	t.end_hit(hit)                      # donma bitti
	near(t.current(), 1.0, 0.0001, "bayat 0.3 KALMAZ: tam hız")

func test_timescale_hitstop_then_death() -> void:
	var t := TimeScale.new()
	var hit := t.begin_hit(0.12)
	var death := t.begin_override(0.3)
	t.end_hit(hit)
	near(t.current(), 0.3, 0.0001, "donma bitti, yavaş çekim sürüyor")
	t.end_override(death)
	near(t.current(), 1.0, 0.0001, "ikisi de bitti")

func test_timescale_settle_invalidates_pending_ends() -> void:
	var t := TimeScale.new()
	var hit := t.begin_hit(0.1)
	var death := t.begin_override(0.3)
	t.settle()                          # duraklatma / reklam / yeni koşu
	near(t.current(), 1.0, 0.0001, "settle sonrası tam hız")
	var hit2 := t.begin_hit(0.2)        # yeni donma
	t.end_hit(hit)                      # eski bitiş yeni donmayı BİTİRMEZ
	near(t.current(), 0.2, 0.0001, "eski bilet etkisiz")
	t.end_override(death)
	near(t.current(), 0.2, 0.0001, "eski yavaş çekim bileti etkisiz")
	t.end_hit(hit2)
	near(t.current(), 1.0, 0.0001, "güncel bilet kapatır")

func test_timescale_base_and_single_hit() -> void:
	var t := TimeScale.new()
	t.set_base(3.0)                     # araç hızı
	var hit := t.begin_hit(0.12)
	near(t.current(), 0.36, 0.0001, "temel × donma")
	eq(t.begin_hit(0.5), -1, "donma sürerken ikincisi eklenmez (eski davranış)")
	t.end_hit(hit)
	near(t.current(), 3.0, 0.0001, "temel hıza döner")
	t.begin_override(0.3)
	near(t.current(), 0.3, 0.0001, "ölüm yavaş çekimi mutlak (eski davranış)")
