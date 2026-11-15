extends TestCase
## ads.json yapısı, limit doğrulama, yerleşim kimlikleri ve kimlik güvenliği (yalnız Google TEST kimlikleri).

const TEST_APP := "ca-app-pub-3940256099942544~3347511713"
const TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL := "ca-app-pub-3940256099942544/1033173712"

func test_placement_ids_are_stable() -> void:
	eq(int(AdPlacement.Id.REVIVE), 0, "REVIVE=0")
	eq(int(AdPlacement.Id.DOUBLE_CORES), 1, "DOUBLE_CORES=1")
	eq(int(AdPlacement.Id.REROLL), 2, "REROLL=2")
	eq(int(AdPlacement.Id.DAILY_BONUS), 3, "DAILY_BONUS=3")
	eq(int(AdPlacement.Id.INTERSTITIAL), 4, "INTERSTITIAL=4 (sona eklenen yerleşimler sıralamayı bozmaz)")
	eq(AdsProvider.INTERSTITIAL_PLACEMENT, int(AdPlacement.Id.INTERSTITIAL), "sağlayıcı sabiti = enum")
	eq(AdPlacement.KEYS.size(), AdPlacement.Id.size(), "her kimliğin anahtarı var")

func test_keys_round_trip() -> void:
	for id: int in AdPlacement.KEYS:
		eq(AdPlacement.from_key(AdPlacement.key(id)), id, "anahtar gidiş-dönüş")
	eq(AdPlacement.from_key("NOPE"), -1, "bilinmeyen anahtar -1")
	check(not AdPlacement.is_rewarded(AdPlacement.Id.INTERSTITIAL), "geçiş ödüllü değil")
	eq(AdPlacement.rewarded_ids().size(), 4, "4 ödüllü yerleşim")

func test_every_placement_has_limits_in_data() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AdConfig.PATH))
	for id in AdPlacement.rewarded_ids():
		check((raw["placements"] as Dictionary).has(AdPlacement.key(id)), "ads.json: %s" % AdPlacement.key(id))

func test_shipped_limits() -> void:
	var cfg := AdConfig.load_file()
	eq(AdConfig.limits(cfg, "REVIVE")["per_run"], 1, "revive koşuda 1")
	eq(AdConfig.limits(cfg, "DOUBLE_CORES")["per_run"], 1, "çift çekirdek koşuda 1")
	eq(AdConfig.limits(cfg, "REROLL")["per_run"], 2, "reroll koşuda 2")
	eq(AdConfig.limits(cfg, "DAILY_BONUS")["per_day"], 1, "günlük bonus günde 1")
	eq(AdConfig.limits(cfg, "DAILY_BONUS")["per_run"], AdConfig.UNLIMITED, "günlükte koşu sınırı yok")

func test_defaults_equal_shipped_file() -> void:
	var cfg := AdConfig.load_file()
	for key: String in AdConfig.DEFAULTS["placements"]:
		eq(AdConfig.limits({}, key), AdConfig.limits(cfg, key), "yedek = dosya: %s" % key)
	eq(AdConfig.pacing({}), AdConfig.pacing(cfg), "yedek pacing = dosya")

func test_limit_sanitizing() -> void:
	var bad := {"placements": {"REVIVE": {"per_run": "x"}, "REROLL": {"per_run": -3}}}
	eq(AdConfig.limits(bad, "REVIVE")["per_run"], 1, "bozuk sayı -> 1 (kısıtlayıcı)")
	eq(AdConfig.limits(bad, "REROLL")["per_run"], 0, "negatif -> 0")
	eq(AdConfig.limits(bad, "NOPE")["per_run"], 1, "bilinmeyen yerleşim 1")
	eq(AdConfig.limits({}, "REVIVE")["per_run"], 1, "dosyasız varsayılan")

func test_timeouts_are_clamped() -> void:
	near(AdConfig.show_timeout({}), 3.0, 0.001, "varsayılan 3 sn")
	near(AdConfig.show_timeout({"settings": {"show_start_timeout_seconds": 0.0}}), 0.5, 0.001, "alt sınır 0.5")
	near(AdConfig.max_ad_seconds({"settings": {"max_ad_seconds": 99999}}), 600.0, 0.001, "üst sınır 600")

func test_ids_default_to_google_test_ids() -> void:
	var ids := AdmobAdsProvider.resolve_ids(AdmobAdsProvider.load_admob_config(), false)
	eq(String(ids["app_id"]), TEST_APP, "uygulama")
	eq(String(ids["rewarded_unit_id"]), TEST_REWARDED, "ödüllü")
	eq(String(ids["interstitial_unit_id"]), TEST_INTERSTITIAL, "geçiş")

func test_shipped_mode_is_test_and_production_is_placeholder() -> void:
	var admob := AdmobAdsProvider.load_admob_config()
	eq(String(admob["mode"]), "test", "mode=test gönderilir")
	for key: String in ["app_id", "rewarded_unit_id", "interstitial_unit_id"]:
		check(String((admob["production"] as Dictionary)[key]).begins_with("REPLACE_"), "production.%s yer tutucu (gerçek kimlik sahibindir)" % key)
		check(String((admob["test"] as Dictionary)[key]).contains("3940256099942544"), "test.%s Google'ın herkese açık test kimliği" % key)

func test_no_real_looking_ids_anywhere_in_data() -> void:
	var text := FileAccess.get_file_as_string(AdConfig.PATH)
	var rx := RegEx.new()
	rx.compile("ca-app-pub-\\d+")
	for m in rx.search_all(text):
		eq(m.get_string(), "ca-app-pub-3940256099942544", "yalnız Google test yayıncı kimliği")

func test_release_with_placeholder_falls_back_to_test_ids() -> void:
	var cfg := AdmobAdsProvider.load_admob_config()
	cfg["mode"] = "production"   # yayın sürümü + production + REPLACE_ => test kimliği
	var ids := AdmobAdsProvider.resolve_ids(cfg, false)
	eq(String(ids["rewarded_unit_id"]), TEST_REWARDED, "REPLACE_ varken test kimliği")
	eq(String(ids["app_id"]), TEST_APP, "app_id de test")

func test_production_ids_only_in_real_release() -> void:
	var production := {"app_id": "ca-app-pub-1~2", "rewarded_unit_id": "ca-app-pub-1/3", "interstitial_unit_id": "ca-app-pub-1/4"}
	var cfg := {"mode": "production", "production": production}
	eq(String(AdmobAdsProvider.resolve_ids(cfg, true)["rewarded_unit_id"]), TEST_REWARDED, "hata ayıklama = test")
	eq(String(AdmobAdsProvider.resolve_ids(cfg, false)["rewarded_unit_id"]), "ca-app-pub-1/3", "yayın + production + gerçek")
	cfg["mode"] = "test"
	eq(String(AdmobAdsProvider.resolve_ids(cfg, false)["rewarded_unit_id"]), TEST_REWARDED, "mode=test = test")

func test_one_placeholder_poisons_the_whole_set() -> void:
	var cfg := {"mode": "production", "production": {"app_id": "ca-app-pub-1~2", "rewarded_unit_id": "REPLACE_WITH_REAL_REWARDED_UNIT_ID", "interstitial_unit_id": "ca-app-pub-1/4"}}
	var ids := AdmobAdsProvider.resolve_ids(cfg, false)
	eq(String(ids["rewarded_unit_id"]), TEST_REWARDED, "tümü test kimliği")
	eq(String(ids["interstitial_unit_id"]), TEST_INTERSTITIAL, "karışık küme yok")
