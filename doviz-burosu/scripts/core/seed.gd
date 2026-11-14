class_name Seed
extends RefCounted
## Tohumlu rastgelelik. `String.hash()` sürümler/platformlar arasında aynı sonucu garanti etmez;
## Günün Kuru gibi herkesin aynı müşterileri görmesi gereken yerler için kendi FNV-1a'mızı kullanırız.

const FNV_OFFSET := 0x811C9DC5
const FNV_PRIME := 0x01000193
const MASK_32 := 0xFFFFFFFF


## 32 bit FNV-1a (UTF-8 baytları üzerinden). Sonuç 0..4294967295 arasıdır.
static func fnv1a(text: String) -> int:
	var hash_value := FNV_OFFSET
	for byte: int in text.to_utf8_buffer():
		hash_value = ((hash_value ^ byte) * FNV_PRIME) & MASK_32
	return hash_value


## Anahtar metninden tohumlanmış yeni bir RNG. Aynı anahtar her zaman aynı diziyi üretir.
## Anahtarı parçalara ayırarak ("rate|FED|3") bağımsız akışlar elde edilir.
static func rng(key: String) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = fnv1a(key)
	return generator


## Dizinin rastgele bir elemanı (dizi boşsa null).
static func pick(generator: RandomNumberGenerator, items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[generator.randi_range(0, items.size() - 1)]


## Yüzde olasılıkla true döner (0..100, tam sayı).
static func chance(generator: RandomNumberGenerator, percent: int) -> bool:
	return generator.randi_range(1, 100) <= percent
