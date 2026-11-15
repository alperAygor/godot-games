class_name UiStrings
extends RefCounted

## Yer adı verilmiş dünyalar (sıra = dünya numarası).
const WORLD_KEYS: Array[String] = ["MAP_WORLD_1", "MAP_WORLD_2", "MAP_WORLD_3", "MAP_WORLD_4"]

## Arayüzün kullanıcıya görünen metinleri: `data/i18n/strings.csv` anahtarlarına ince sarmalayıcılar.
## NEDEN işlev (sabit değil): metin dil değişince yeniden çözülmeli; sabit yükleme anında donardı.
## Dile bağlı olmayan biçimler (sayı + işaret) sabit kalır.


static func game_title() -> String:
	return Loc.t("GAME_TITLE")


static func level(number: int) -> String:
	return Loc.f("LEVEL", [number])


static func ok() -> String:
	return Loc.t("OK")


static func settings_title() -> String:
	return Loc.t("SETTINGS_TITLE")


static func sound() -> String:
	return Loc.t("SETTINGS_SOUND")


static func music() -> String:
	return Loc.t("SETTINGS_MUSIC")


static func vibration() -> String:
	return Loc.t("SETTINGS_VIBRATION")


static func paused() -> String:
	return Loc.t("PAUSED")


static func resume() -> String:
	return Loc.t("RESUME")


static func home_levels() -> String:
	return Loc.t("HOME_LEVELS")


static func levels() -> String:
	return Loc.t("MAP_TITLE")


static func world(number: int) -> String:
	return Loc.f("MAP_WORLD", [number])


static func map_locked() -> String:
	return Loc.t("MAP_LOCKED")


static func moves() -> String:
	return Loc.t("HUD_MOVES")


static func par() -> String:
	return Loc.t("HUD_PAR")


## Sonuç başlığı yıldıza göre: 3 mükemmel, 2 çok iyi, 1 çözüldü.
static func result_title(stars: int) -> String:
	return Loc.t("RESULT_3" if stars >= 3 else ("RESULT_2" if stars == 2 else "RESULT_1"))


static func result_moves(moves_made: int, par_value: int) -> String:
	return Loc.f("RESULT_MOVES", [moves_made, par_value])


static func result_best() -> String:
	return Loc.t("RESULT_BEST")


static func result_next() -> String:
	return Loc.t("RESULT_NEXT")


static func result_retry() -> String:
	return Loc.t("RESULT_RETRY")


## Reklam sunulamadığında düğmenin nedeni söylediği kısa metin (neden kodu: RunFlow.REASON_*).
static func ad_reason(reason: String) -> String:
	match reason:
		"offline":
			return Loc.t("AD_OFFLINE")
		"timeout":
			return Loc.t("AD_TIMEOUT")
		"not_finished":
			return Loc.t("AD_NOT_FINISHED")
		_:
			return Loc.t("AD_NOT_READY")


## Reklam sunulamama nedeninin ikonu (toast'ta metnin yanında).
static func ad_reason_icon(reason: String) -> String:
	match reason:
		"offline":
			return "lucide/wifi-off"
		"timeout":
			return "lucide/clock"
		_:
			return "lucide/video"


static func skip_title() -> String:
	return Loc.t("SKIP_TITLE")


static func skip_body() -> String:
	return Loc.t("SKIP_BODY")


static func skip_watch() -> String:
	return Loc.t("SKIP_WATCH")


static func skip_cancel() -> String:
	return Loc.t("SKIP_CANCEL")


static func shop_remove_ads() -> String:
	return Loc.t("SHOP_REMOVE_ADS")


static func shop_ads_removed() -> String:
	return Loc.t("SHOP_ADS_REMOVED")


static func shop_note() -> String:
	return Loc.t("SHOP_NOTE")


static func shop_restore() -> String:
	return Loc.t("SHOP_RESTORE")


## Satın alma sonucu mesajı (neden kodu: IapProvider.REASON_*; "restored"/"nothing" geri yükleme sonuçları).
static func shop_message(code: String) -> String:
	match code:
		"restored":
			return Loc.t("SHOP_RESTORED")
		"nothing":
			return Loc.t("SHOP_NOTHING")
		"unavailable", "not_connected":
			return Loc.t("SHOP_UNAVAILABLE")
		_:
			return Loc.t("SHOP_FAILED")


static func home_tagline() -> String:
	return Loc.t("HOME_TAGLINE")


static func home_empty() -> String:
	return Loc.t("HOME_EMPTY")


## Dünya adı (1-4 yer adı; sonrası genel "Dünya N").
static func world_name(number: int) -> String:
	if number >= 1 and number <= WORLD_KEYS.size():
		return Loc.t(WORLD_KEYS[number - 1])
	return world(number)


static func map_empty() -> String:
	return Loc.t("MAP_EMPTY")


static func map_more() -> String:
	return Loc.t("MAP_NEXT_WORLD")


static func hold_restart() -> String:
	return Loc.t("HUD_HOLD_RESTART")


static func level_skipped() -> String:
	return Loc.t("HUD_LEVEL_SKIPPED")


static func coach(kind: String) -> String:
	match kind:
		"tap":
			return Loc.t("COACH_TAP")
		"switch":
			return Loc.t("COACH_SWITCH")
		_:
			return Loc.t("COACH_DRAG")


static func coach_dismiss() -> String:
	return Loc.t("COACH_DISMISS")


static func settings_feel() -> String:
	return Loc.t("SETTINGS_FEEL")


static func settings_language() -> String:
	return Loc.t("SETTINGS_LANGUAGE")


static func settings_store() -> String:
	return Loc.t("SETTINGS_STORE")


static func settings_privacy() -> String:
	return Loc.t("SETTINGS_PRIVACY")


static func reduced_motion() -> String:
	return Loc.t("SETTINGS_REDUCED")


static func shop_pending() -> String:
	return Loc.t("SHOP_PENDING")


static func shop_once() -> String:
	return Loc.t("SHOP_PRICE_ONCE")


static func net_lost() -> String:
	return Loc.t("NET_LOST")
