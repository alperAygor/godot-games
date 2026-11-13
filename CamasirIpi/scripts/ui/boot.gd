extends Control

## Açılış: servisler hazır, kısa bir bekleme, ana ekrana (ilk açılışta oyuna) geçiş.
## Bekleme, "flash" hissini önler; 0.4 sn altına düşürmeyin.

const HOLD_SECONDS: float = 0.4


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.BOOT)
	# Dil, ilk ekran kurulmadan önce uygulanır: hiçbir ekran yarım çevrilmiş açılmaz.
	Loc.apply_saved()
	(get_node("Center/Column/Sub") as Label).text = Loc.t("BOOT_LOADING")
	(get_node("Center/Column/Title") as Label).text = Loc.t("GAME_TITLE")
	# Açılış beklemesi boşa gitmesin: oyuncunun seviyesi şimdiden arka planda üretilir
	# ("Oyna"ya basınca ağır seviyede bile anında açılır).
	LevelPrefetch.request_level(Progress.level())
	# Bahçe dokuları da beklemede paralel yüklenir: ilk ekran (ana ekran/oyun) daha çabuk açılır.
	GardenBackdrop.warm_up()
	await get_tree().create_timer(HOLD_SECONDS).timeout
	# Kayıtlı ses/müzik ayarı ilk sahneden önce uygulanır; ilk açılış menüsüz doğrudan oyuna girer.
	UiData.apply_audio_settings()
	GameManager.goto_scene(&"game" if UiData.consume_first_launch() else &"home")
