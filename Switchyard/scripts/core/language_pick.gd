class_name LanguagePick
extends RefCounted

## Oyun dilinin seçimi (SAF mantık, sahneye ve işletim sistemine bağımlı değil). Kural:
## 1. Ayarda kaydedilmiş dil destekleniyorsa o kazanır (oyuncu ayardan seçtiyse hep geçerli).
## 2. Yoksa cihaz dili destekleniyorsa o ("tr_TR" -> tr, "es-MX" -> es).
## 3. Aksi halde (desteklenmeyen dil, boş) İNGİLİZCE.
## Eksik çeviri anahtarları project.godot `locale/fallback="en"` ile İngilizceye düşer.
## Cihaz yerel adı DIŞARIDAN verilir: testler bu makinenin dilinden etkilenmez.

const FALLBACK: String = "en"


## "tr_TR", "en-US", "zh_Hans_CN", "tr" -> küçük harfli ilk parça; boşsa "".
static func language_of(locale: String) -> String:
	var cleaned: String = locale.strip_edges().replace("-", "_")
	return cleaned.get_slice("_", 0).to_lower()


## saved: ayardaki dil ("" = hiç seçilmemiş), device_locale: OS.get_locale(), supported: desteklenen kodlar.
static func resolve(saved: String, device_locale: String, supported: Array[String]) -> String:
	var wanted: String = language_of(saved)
	if not wanted.is_empty() and supported.has(wanted):
		return wanted
	var device: String = language_of(device_locale)
	if not device.is_empty() and supported.has(device):
		return device
	return FALLBACK
