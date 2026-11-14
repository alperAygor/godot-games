class_name PrizDaily
extends RefCounted
## "Günün dairesi": takvim tarihinden belirlenimci seviye. Aynı tarih her cihazda aynı
## seviyeyi verir (oyuncu ilerlemesine bağlı değildir). Zorluk, gün kipinin açıldığı ve
## oyuncuların çoğunun ulaştığı aralıkta tutulur: sanal seviye numarası 16-44 arasında,
## zor seviye (5'in katı) numaraları atlanır. Arayüz günlük seviyeyi seviye 15 geçilince açar.

const MIN_VIRTUAL: int = 16
const MAX_VIRTUAL: int = 44
const SEED_SALT: int = 977


## 1970-01-01'den bu yana gün sayısı (proleptik Gregoryen, saf tam sayı aritmetiği).
static func day_index(year: int, month: int, day: int) -> int:
	var y: int = year - (1 if month <= 2 else 0)
	var era: int = floori(float(y) / 400.0)
	var yoe: int = y - era * 400
	var mp: int = (month + 9) % 12
	var doy: int = int((153 * mp + 2) / 5.0) + day - 1
	var doe: int = yoe * 365 + int(yoe / 4.0) - int(yoe / 100.0) + doy
	return era * 146097 + doe - 719468


## Tarihin sanal seviye numarası.
static func virtual_level(index: int) -> int:
	var span: int = MAX_VIRTUAL - MIN_VIRTUAL + 1
	var n: int = MIN_VIRTUAL + posmod(index * 7, span)
	if PrizCurve.is_hard_level(n):
		n += 1
	return mini(n, MAX_VIRTUAL)


static func seed_for(index: int) -> int:
	return posmod(index * 2654435 + SEED_SALT, 2147483647)


static func level_id(year: int, month: int, day: int) -> String:
	return "daily_%04d-%02d-%02d" % [year, month, day]


## Tarihin günlük seviyesi. Başarısızsa null (testler 1 yıllık örnekte olmadığını doğrular).
static func generate(year: int, month: int, day: int, content: PrizContent) -> PrizLevel:
	var index: int = day_index(year, month, day)
	var generator: PrizGenerator = PrizGenerator.new(content)
	var level: PrizLevel = generator.generate_custom(virtual_level(index), seed_for(index),
			level_id(year, month, day))
	if level != null:
		level.meta["daily"] = "%04d-%02d-%02d" % [year, month, day]
	return level
