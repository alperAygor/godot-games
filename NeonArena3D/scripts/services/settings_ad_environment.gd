class_name SettingsAdEnvironment
extends AdEnvironment
## Gerçek oyun ortamı: `Settings` autoload'ının bayrakları (F4 sözleşmesi) ve güvenilir saati.
## Yazımlar Settings üzerinden gider (--no-save/--demo modunda diske yazılmaz).


func is_ads_removed() -> bool:
	return Settings.has_entitlement("remove_ads") or bool(Settings.get_flag("ads_removed", false))


func now() -> int:
	Settings.touch_clock()
	return Settings.trusted_now()


func today_key() -> String:
	return Settings.today_key()


func runs_done() -> int:
	return int(Settings.get_flag("run_counter", 0))


func last_interstitial() -> int:
	return int(Settings.get_flag("last_transition_time", 0))


func record_interstitial() -> void:
	Settings.mark_transition()


func daily_date() -> String:
	return String(Settings.get_flag("daily_bonus_date", ""))


func set_daily_date(date_key: String) -> void:
	Settings.set_flag("daily_bonus_date", date_key)
