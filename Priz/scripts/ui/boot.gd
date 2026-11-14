extends Control

## Açılış: servisler hazır, kısa bir bekleme, ana ekrana geçiş.
## Bekleme, "flash" hissini önler ve sahnelerin arka planda yüklenmesine zaman tanır;
## 0.4 sn altına düşürmeyin.

const HOLD_SECONDS: float = 0.4


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.BOOT)
	# Dil, ilk ekran kurulmadan önce uygulanır: hiçbir ekran yarım çevrilmiş açılmaz.
	Loc.apply_saved()
	(get_node("Center/Column/Sub") as Label).text = Loc.t("BOOT_LOADING")
	(get_node("Center/Column/Title") as Label).text = Loc.t("GAME_TITLE")
	# Ana ekran ve oyun sahnesi (betik derlemesiyle birlikte) beklemede iş parçacığında yüklenir:
	# bekleme bitince ve ilk "Oyna"da ana iş parçacığı derleme için donmasın.
	GameManager.preload_scene(&"home")
	GameManager.preload_scene(&"game")
	await get_tree().create_timer(HOLD_SECONDS).timeout
	# Kayıtlı ses/müzik ayarı ilk sahneden önce uygulanır.
	UiData.apply_audio_settings()
	# Açılışta bağlantı denetimi (varsayılan: çevrimdışı oynamak yasak): çevrimdışıysa
	# "Bağlantı gerekli" sayfası, gelince devam. Kapı headless/editör/araçlarda kapalıdır.
	OnlineGate.guard(self, _route)


func _route() -> void:
	GameManager.goto_scene(&"home")
