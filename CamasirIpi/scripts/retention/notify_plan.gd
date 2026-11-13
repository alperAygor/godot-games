class_name RetentionNotifyPlan
extends RefCounted

## Yerel bildirim planı (saf mantık): HANGİ bildirim KAÇ saniye sonra. Saat dışarıdan gelir:
## now = {"day": "YYYY-MM-DD", "hour": int, "minute": int, "second": int} (yerel duvar saati).
## Neden duvar saatinden hesap: "yarın sabah" oyuncunun sabahıdır, 86400 sn sonrası değil.
## Bildirimler her etkinlikte yeniden kurulur (aynı kimlik üstüne yazar) -> "24 sa boşta" doğal çalışır.

const ID_DAILY_GIFT: String = "ret_daily_gift"
const ID_MISSIONS: String = "ret_missions"
const ID_WEEKLY_END: String = "ret_weekly_end"
const SECONDS_PER_HOUR: int = 3600
const SECONDS_PER_DAY: int = 86400


static func seconds_of_day(now: Dictionary) -> int:
	return int(now.get("hour", 0)) * SECONDS_PER_HOUR + int(now.get("minute", 0)) * 60 \
		+ int(now.get("second", 0))


## Şu andan sonraki ilk `hour`:00'a kadar saniye (aynı saatteyse ertesi gün).
static func seconds_until_hour(now_seconds_of_day: int, hour: int) -> int:
	var diff: int = hour * SECONDS_PER_HOUR - now_seconds_of_day
	return diff if diff > 0 else diff + SECONDS_PER_DAY


static func is_quiet(hour: int, cfg: Dictionary) -> bool:
	var from_hour: int = int(cfg.get("quiet_from", 22))
	var to_hour: int = int(cfg.get("quiet_to", 8))
	return hour >= from_hour or hour < to_hour


## flags: {"missions": bool, "weekly": bool} (açık mı). Dönen: [{id, seconds, title_key, body_key}].
static func plan(now: Dictionary, flags: Dictionary, cfg: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var now_seconds: int = seconds_of_day(now)
	var morning: int = int(cfg.get("morning_hour", 9))
	result.append({"id": ID_DAILY_GIFT, "seconds": seconds_until_hour(now_seconds, morning),
		"title_key": "RET_N_GIFT_T", "body_key": "RET_N_GIFT_B"})
	if bool(flags.get("missions", false)):
		var delay: int = int(cfg.get("idle_hours", 24)) * SECONDS_PER_HOUR
		var fire_second: int = (now_seconds + delay) % SECONDS_PER_DAY
		if is_quiet(fire_second / SECONDS_PER_HOUR, cfg):
			# Sessiz saate denk gelirse sabaha kaydır: gece 3'te "görevlerin seni bekliyor" olmaz.
			delay += seconds_until_hour(fire_second, morning)
		result.append({"id": ID_MISSIONS, "seconds": delay,
			"title_key": "RET_N_MISS_T", "body_key": "RET_N_MISS_B"})
	if bool(flags.get("weekly", false)):
		var days_ahead: int = int(cfg.get("weekly_weekday", 5)) - WeeklyEvent.weekday(String(now.get("day", "")))
		var weekly_second: int = days_ahead * SECONDS_PER_DAY + int(cfg.get("weekly_hour", 18)) * SECONDS_PER_HOUR - now_seconds
		# Hedef an geçtiyse (Cumartesi akşamından sonra) bu hafta bildirim yok.
		if days_ahead >= 0 and weekly_second > 0:
			result.append({"id": ID_WEEKLY_END, "seconds": weekly_second,
				"title_key": "RET_N_WEEK_T", "body_key": "RET_N_WEEK_B"})
	return result
