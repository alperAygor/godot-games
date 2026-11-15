class_name LanguagePick
extends RefCounted
## Oyun dilinin seçimi (saf mantık, sahneye bağımlı değil). Kural:
## 1. Ayarda kaydedilmiş dil destekleniyorsa o kazanır (oyuncu ayardan seçtiyse hep geçerli).
## 2. Yoksa cihaz dili destekleniyorsa o ("tr_TR" -> tr, "en_US" -> en, "pt-BR" -> pt ancak destekleniyorsa).
## 3. Aksi halde (desteklenmeyen dil, boş) İNGİLİZCE.
## Eksik çeviri anahtarları project.godot `locale/fallback="en"` ile İngilizceye düşer.

const FALLBACK := "en"


## Yerel adından ("tr_TR", "en-US", "zh_Hans_CN", "tr") dil kodunu çıkarır: küçük harf, ilk parça. Boş ise "".
static func language_of(locale: String) -> String:
	var cleaned := locale.strip_edges().replace("-", "_")
	return cleaned.get_slice("_", 0).to_lower()


## saved: ayardaki dil ("" = seçilmemiş), device_locale: OS.get_locale() ("tr_TR"), supported: desteklenen kodlar.
static func resolve(saved: String, device_locale: String, supported: Array) -> String:
	var wanted := language_of(saved)
	if not wanted.is_empty() and wanted in supported:
		return wanted
	var device := language_of(device_locale)
	if not device.is_empty() and device in supported:
		return device
	return FALLBACK
