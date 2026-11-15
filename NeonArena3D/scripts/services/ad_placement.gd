class_name AdPlacement
extends RefCounted
## Reklam yerleşimlerinin TİPLİ kimlikleri. Sıra kayıt/test ile sabittir; yeni yerleşim SONA eklenir.
## Neden ayrı sınıf: sağlayıcılar, pacing ve testler autoload'a bağımlı olmadan aynı kimlikleri paylaşır.
##  REVIVE       ödüllü: ölümde bir kez "izle ve devam et"
##  DOUBLE_CORES ödüllü: koşu sonu çekirdek x2
##  REROLL       ödüllü: kart ekranında +1 yenileme
##  DAILY_BONUS  ödüllü: günlük bonus (gün başına bir kez, Settings.today_key())
##  INTERSTITIAL ödüllü DEĞİL: yalnız koşu bitiminde, AdPacing kararıyla

enum Id { REVIVE, DOUBLE_CORES, REROLL, DAILY_BONUS, INTERSTITIAL }

const KEYS: Dictionary = {
	Id.REVIVE: "REVIVE",
	Id.DOUBLE_CORES: "DOUBLE_CORES",
	Id.REROLL: "REROLL",
	Id.DAILY_BONUS: "DAILY_BONUS",
	Id.INTERSTITIAL: "INTERSTITIAL",
}


static func key(id: int) -> String:
	return String(KEYS.get(id, ""))


## Anahtardan kimlik; bilinmiyorsa -1.
static func from_key(name: String) -> int:
	for id: int in KEYS:
		if KEYS[id] == name:
			return id
	return -1


static func is_rewarded(id: int) -> bool:
	return KEYS.has(id) and id != Id.INTERSTITIAL


static func is_interstitial(id: int) -> bool:
	return id == Id.INTERSTITIAL


static func rewarded_ids() -> Array[int]:
	var out: Array[int] = []
	for id: int in KEYS:
		if id != Id.INTERSTITIAL:
			out.append(id)
	return out
