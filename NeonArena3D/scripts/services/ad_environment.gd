class_name AdEnvironment
extends RefCounted
## AdManager'ın dış dünyayla (saat, kayıt) konuştuğu İNCE sınır. Bu taban sınıf bellek içi bir uygulamadır:
## testler ve probeler gerçek kayda dokunmadan kullanır; oyun `SettingsAdEnvironment` kullanır.

var ads_removed: bool = false
var now_unix: int = 1_800_000_000
var runs_completed: int = 0
var last_interstitial_unix: int = 0   # 0 = hiç gösterilmedi
var daily_claimed_date: String = ""
var today: String = "2027-01-15"


func is_ads_removed() -> bool:
	return ads_removed


## Güvenilir şimdiki zaman (saniye, Unix). Saat geri alınırsa geri gitmemelidir (gerçek uygulama bunu sağlar).
func now() -> int:
	return now_unix


func today_key() -> String:
	return today


## Biten koşu sayısı (Settings.record_run sonrası güncel değer).
func runs_done() -> int:
	return runs_completed


func last_interstitial() -> int:
	return last_interstitial_unix


func record_interstitial() -> void:
	last_interstitial_unix = now()


func daily_date() -> String:
	return daily_claimed_date


func set_daily_date(date_key: String) -> void:
	daily_claimed_date = date_key
