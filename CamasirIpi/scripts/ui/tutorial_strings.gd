class_name TutorialStrings
extends RefCounted

## Öğretici metinlerinin TEK yeri (Türkçe). Neden ayrı: metin düzeltmek kod/veri dosyasına
## dokunmayı gerektirmesin; çeviri gerekirse tek dosya değişir.

const OK_BUTTON: String = "Tamam"

const CARDS: Dictionary = {
	"wet": {"title": "Islak", "line": "Islak çamaşır: önce sık, sonra al."},
	"mystery": {"title": "Gizemli", "line": "Üstü açılınca gerçek rengi belli olur."},
	"lock": {"title": "Kilitli", "line": "Anahtar renkli sepet dolunca kilit açılır."},
	"sheet": {"title": "Çarşaf", "line": "Çarşaf büyüktür, altındakileri kapatır."},
	"sock_pair": {"title": "Çorap çifti", "line": "İki çorabı birlikte sepete gönder."},
	"dye": {"title": "Boya", "line": "Boyalı çamaşır yanındakilerin rengini değiştirir."},
	"undo": {"title": "Geri al", "line": "Son hamleni geri alır."},
	"pin_remover": {"title": "Mandal çıkarıcı", "line": "Seçtiğin çamaşırı hemen serbest bırakır."},
	"extra_slot": {"title": "+1 askı", "line": "Bekleme askısına bir yer daha ekler."},
}


static func card_title(feature: String) -> String:
	return String((CARDS.get(feature, {}) as Dictionary).get("title", feature))


static func card_line(feature: String) -> String:
	return String((CARDS.get(feature, {}) as Dictionary).get("line", ""))
