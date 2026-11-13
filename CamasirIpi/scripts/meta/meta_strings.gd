class_name MetaStrings
extends RefCounted

## Meta katmanının (çamaşırhane + koleksiyon) kullanıcıya görünen tüm metinleri (Türkçe).
## NEDEN ayrı dosya: meta ekranları başka işçiyle paralel geliştirildi; ortak `UiStrings`'e
## dokunmadan dil/metin cilası tek yerden yapılabilsin.

# Çamaşırhane
const LOCATION_NAMES: Dictionary[String, String] = {
	"corner": "Köşe Çamaşırhanesi",
	"seaside": "Sahil Çamaşırhanesi",
	"attic": "Çatı Katı",
	"hotel": "Otel",
}
const TASK_NAMES: Dictionary[String, String] = {
	"floor": "Zemin",
	"wall": "Duvar boyası",
	"machine1": "Çamaşır makinesi",
	"shelf": "Raf",
	"sign": "Tabela",
	"plant": "Saksı çiçeği",
	"lamp": "Lamba",
	"window": "Pencere",
	"counter": "Tezgâh",
	"machine2": "İkinci makine",
	"rug": "Halı",
	"door": "Kapı",
}
const PROGRESS_FORMAT: String = "%d/%d"
const COST_FORMAT: String = "%d"
const NEED_STARS: String = "Seviye geç, yıldız kazan"
const PICK_LOOK: String = "Görünümü seç"
const LOCATION_DONE: String = "Tamamlandı"
const BONUS_FORMAT: String = "+%d"
const SOON: String = "Yakında"
const NEXT_LOCATION: String = "Sıradaki"

# Koleksiyon
const COLLECTION_TITLE: String = "Koleksiyon"
const SET_NAMES: Dictionary[String, String] = {
	"turkiye": "Türkiye",
	"japonya": "Japonya",
	"meksika": "Meksika",
	"iskocya": "İskoçya",
	"hindistan": "Hindistan",
	"hollanda": "Hollanda",
}
const NEXT_PIECE_FORMAT: String = "%d seviye sonra yeni parça"
const ALL_PIECES: String = "Tüm parçalar toplandı"
const SET_PROGRESS_FORMAT: String = "%d/%d"
const NEW_BADGE: String = "Yeni"


static func location_name(id: String) -> String:
	return LOCATION_NAMES.get(id, id)


static func task_name(id: String) -> String:
	return TASK_NAMES.get(id, id)


static func country_name(id: String) -> String:
	return SET_NAMES.get(id, id)
