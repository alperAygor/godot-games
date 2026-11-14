class_name PrizCurve
extends RefCounted
## Zorluk eğrisi: seviye numarasından boyut ve zorluk hedefi. Üretici bunu okur.
##
## Zorluk ölçüsü çözücünün ayrık çözüm sayısıdır (PrizSolveResult.count): az çözüm = zor.
## - 1-3: öğretici, neredeyse her yerleşim tutar (bol boş kapasite).
## - 4-14: yumuşak; her 5. seviye zor.
## - Öğenin açıldığı seviyede öğe en yumuşak hâliyle gelir; o seviye aynı zamanda zorsa
##   "hard_intro" aralığı (normal ile zor arası) kullanılır.

var number: int = 1
var lines: int = 2
var rooms: int = 1
var devices: int = 2
## Cihaz sayısının üstündeki boş yuva sayısı (seçim alanı).
var spare: int = 1
var difficulty: String = PrizLevel.DIFF_NORMAL
var band_min: int = 1
var band_max: int = 1000
## Sıkılaştırmanın başlangıç boş kapasitesi (hat başına blok).
var slack: int = 1
var max_slack: int = 3
var tutorial: bool = false
## Açılmış isteğe bağlı öğelerden en fazla kaçı aynı seviyede.
var max_optional: int = 1


static func is_hard_level(level_number: int) -> bool:
	return level_number > 0 and level_number % 5 == 0


static func for_level(level_number: int, has_intro: bool) -> PrizCurve:
	var c: PrizCurve = PrizCurve.new()
	var n: int = maxi(level_number, 1)
	c.number = n
	var hard: bool = is_hard_level(n)
	c.difficulty = PrizLevel.DIFF_HARD if hard else PrizLevel.DIFF_NORMAL
	# Hat sayısı 2-4.
	if n <= 9:
		c.lines = 2
	elif n <= 29:
		c.lines = 3
	elif n <= 49:
		c.lines = 3 + (n % 2)
	else:
		c.lines = 4
	# Oda sayısı (oda kısıtı seviye 6'da açılır; öncesi tek oda).
	if n <= 5:
		c.rooms = 1
	elif n <= 19:
		c.rooms = 2
	elif n <= 39:
		c.rooms = 3
	else:
		c.rooms = 4
	# Cihaz sayısı büyür; zor seviyede bir fazla.
	if n == 1:
		c.devices = 2
	elif n <= 3:
		c.devices = 3
	else:
		c.devices = mini(3 + int(float(n) / 7.0), 11)
		if hard and n >= 10:
			c.devices = mini(c.devices + 1, 12)
	c.spare = 1 if n <= 3 or hard else 2
	if n >= 40 and not hard:
		c.spare = 3
	c.max_optional = 1 if n < 25 else (2 if n < 70 else 3)
	# Zorluk aralıkları.
	if n <= 3:
		c.tutorial = true
		c.band_min = 1
		c.band_max = 1000
		c.slack = 4 - n
		c.max_slack = 4
	elif hard and has_intro:
		c.band_min = 2
		c.band_max = 8
		c.slack = 1
	elif hard:
		c.band_min = 1 if n >= 20 else 2
		c.band_max = 4 if n >= 20 else 6
		c.slack = 0
	elif n <= 14:
		c.band_min = 3
		c.band_max = 24
		c.slack = 2
	else:
		c.band_min = 2
		c.band_max = 16
		c.slack = 1
	return c
