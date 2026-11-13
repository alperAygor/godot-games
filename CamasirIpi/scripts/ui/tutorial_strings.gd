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
	"joker": {"title": "Joker sepet", "line": "Gökkuşağı sepet ilk konan rengi alır, o renkle dolar."},
	"big_basket": {"title": "Büyük sepet", "line": "Bu sepet 3 değil 5 çamaşırla dolar."},
	"stain": {"title": "Lekeli", "line": "Lekeli çamaşır önce askıda bir hamle kurur, sonra sepete geçer."},
	"chain": {"title": "Zincirli mandal", "line": "Birini alınca zincirli eşi de askıya düşer."},
	"wind": {"title": "Rüzgâr", "line": "Sayaç bitince işaretli çamaşır yanındakinin üstüne savrulur."},
	"slide": {"title": "Sürgülü İp", "line": "İşaretli sıra birkaç hamlede bir yana kayar, sonra geri gelir."},
	"mode_moves": {"title": "Sınırlı hamle", "line": "Hepsini sayaç bitmeden topla."},
	"mode_short_rack": {"title": "Kısa askı", "line": "Bu bölümde askıda daha az yer var."},
	"mode_orders": {"title": "Sipariş", "line": "Sepetleri gösterilen renk sırasıyla doldur, bonus kazan."},
	"mode_boss": {"title": "Büyük çamaşır günü", "line": "İlk ip boşalınca ikinci tahta gelir; askı ve sepetler sürer."},
	"undo": {"title": "Geri al", "line": "Son hamleni geri alır."},
	"pin_remover": {"title": "Mandal çıkarıcı", "line": "Seçtiğin çamaşırı hemen serbest bırakır."},
	"extra_slot": {"title": "+1 askı", "line": "Bekleme askısına bir yer daha ekler."},
}


static func card_title(feature: String) -> String:
	return String((CARDS.get(feature, {}) as Dictionary).get("title", feature))


static func card_line(feature: String) -> String:
	return String((CARDS.get(feature, {}) as Dictionary).get("line", ""))
