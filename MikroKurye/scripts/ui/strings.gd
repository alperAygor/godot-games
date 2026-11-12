class_name UiStrings
extends RefCounted

## Arayüz metinleri tek yerde: çok dil sonra `tr()`/veri anahtarına taşınacak.
## Sözleşme: ARCHITECTURE.md §5.4. Sahneler sabit dizge taşımaz; buradan okur.

const MENU_PLAY: String = "Oyna"
const MENU_GARAGE: String = "Garaj"
const MENU_SETTINGS: String = "Ayarlar"
const MENU_SOUND: String = "Ses"
const MENU_HINT: String = "Siparişini seç, kuryeni geliştir."
const BACK: String = "Geri"
const SETTINGS_TITLE: String = "Ayarlar"
const SETTINGS_HINT: String = "Ses ve oyun tercihleri."
const SOUND_LABEL: String = "Ses"
const SOUND_ON: String = "Ses Açık"
const TUTORIAL_TITLE: String = "Mikro Kurye"
const TUTORIAL_NEXT: String = "Devam"
const TUTORIAL_START: String = "Başla"
const TUTORIAL_SKIP: String = "Atla"
## İlk açılış rehberi: kısa, dikey ekranda tek bakışta okunur üç sayfa.
const TUTORIAL_PAGES: Array[String] = [
	"Amaç: kargoyu sağlam taşıyıp yeşil teslimat alanlarına ulaş. Her teslimat yeni bir level açar; yol sonsuza kadar sürer ve zorlaşır.",
	"Sürüş: sol alttaki joystick ile yönlendir. Klavye tuşları, fanlar ve engellerden kaç; çarpmalar kargoyu yorar, sağlık biterse koşu biter.",
	"Garaj: kazandığın altın ve hurdayla robotu geliştir, rekorunu kır. Kargo kırılırsa kasanın yarısını alırsın.",
]
const ORDER_TITLE: String = "Sipariş Seç"
const ORDER_HINT: String = "Taşımak istediğin kargoyu seç."
const GARAGE_TITLE: String = "Garaj"
const GARAGE_HINT: String = "Altın ve hurdayla kuryeni güçlendir."
const DIFFICULTY: String = "Zorluk"
const REWARD: String = "Ödül"
const GOLD: String = "Altın"
const SCRAP: String = "Hurda"
const LEVEL: String = "Seviye"
const MAX_LEVEL: String = "MAKS"
const GOLD_SUFFIX: String = "Altın"
const SCRAP_SUFFIX: String = "Hurda"
const WALLET: String = "Cüzdan"
const REVIVE_TITLE: String = "Kargonu Kurtar"
const REVIVE_TEXT: String = "Reklam izle; kargo onarılsın ve son kontrol noktasından devam et."
const REVIVE_ACCEPT: String = "Reklam İzle ve Devam Et"
const REVIVE_DECLINE: String = "Bu Turu Bitir"
const RECHARGE: String = "Hızlı Şarj"
const RECHARGE_HINT: String = "Reklam izle, batarya dolsun ve kısa süre hızlan."
const DOUBLE_REWARD: String = "Ödülü 2× Yap"
const GOLDEN_BOX: String = "Altın Kutu Bonusu"
const TRY_BEFORE_BUY: String = "Dene"
const RESULT_SUCCESS: String = "Teslimat Tamamlandı"
const RESULT_FAIL: String = "Teslimat Hasarlı"
const RESULT_RETRY: String = "Tekrar Oyna"
const RESULT_MENU: String = "Ana Menü"

## Sonsuz mod (PROJECT_SPEC §14).
const HUD_RUN_FORMAT: String = "Level %d  ·  Teslimata %d m"
const HUD_OBJECTIVE: String = "Kargoyu yeşil teslimat alanına götür!"
const HUD_LEVEL_UP_FORMAT: String = "Level %d  ·  +%d altın"
const ENDLESS_BROKEN: String = "Kargo Kırıldı"
const ENDLESS_DONE: String = "Koşu Bitti"
const ENDLESS_STATS_FORMAT: String = "Level %d  ·  %d m  ·  %d puan"
const ENDLESS_HALF_PAY_FORMAT: String = "Kasa %d altın. Kargo kırıldığı için yarısı ödendi."
const ENDLESS_FULL_PAY_FORMAT: String = "Kasa %d altın, tamamı ödendi."
const NEW_RECORD_FORMAT: String = "Yeni rekor: %s!"
const RECORD_LEVEL: String = "level"
const RECORD_DISTANCE: String = "mesafe"
const RECORD_SCORE: String = "puan"
const RECORD_FORMAT: String = "Rekor: Level %d  ·  %d m  ·  %d puan"
const RECORD_NONE: String = "Henüz rekor yok. İlk koşuna çık!"
const BUY: String = "Yükselt"
const SOUND_ON_TEXT: String = "Açık"
const SOUND_OFF_TEXT: String = "Kapalı"


## `data/cargo.json` içindeki `name_key` -> görünen ad. Bilinmeyen anahtar
## olduğu gibi gösterilir; yeni kargo verisi kod değişikliği gerektirmez.
static func cargo_name(name_key: String) -> String:
	match name_key:
		"cargo.battery":
			return "Pil"
		"cargo.sd_card":
			return "SD Kart"
		"cargo.espresso":
			return "Espresso Kapsülü"
		_:
			return name_key


static func cargo_card(name: String, difficulty: int, reward_gold: int) -> String:
	return "%s\n%s %d · %s %d %s" % [
		name, DIFFICULTY, difficulty, REWARD, reward_gold, GOLD_SUFFIX]


static func category_name(category: String) -> String:
	match category:
		"chassis":
			return "Şasi"
		"wheels":
			return "Tekerlek"
		"battery":
			return "Batarya"
		"shock_gel":
			return "Şok Jeli"
		_:
			return category


## Bir sonraki yükseltme seviyesinin etkisi (kısa, kart altında gösterilir).
## Veri `data/upgrades.json` mod anahtarlarından gelir; değerler seviye başına aynıdır.
static func category_effect(category: String) -> String:
	match category:
		"chassis":
			return "Kargo sönümü iyileşir"
		"wheels":
			return "Yol tutuşu artar"
		"battery":
			return "Batarya kapasitesi artar"
		"shock_gel":
			return "Kırılmaya karşı 1 kez korur"
		_:
			return ""


static func gold_label(amount: int) -> String:
	return "%s: %d" % [GOLD, amount]


static func scrap_label(amount: int) -> String:
	return "%s: %d" % [SCRAP, amount]


static func wallet_label(gold: int, scrap: int) -> String:
	return "%s: %d %s · %d %s" % [WALLET, gold, GOLD_SUFFIX, scrap, SCRAP_SUFFIX]


## Seviye/maliyet metni; `cost` boşsa kategori maksimumdadır.
static func upgrade_button(category: String, level: int, max_level: int,
		cost: Dictionary) -> String:
	var name: String = category_name(category)
	if cost.is_empty():
		return "%s\n%s %d/%d · %s" % [name, LEVEL, level, max_level, MAX_LEVEL]
	var gold: int = int(cost.get("gold", 0))
	var scrap: int = int(cost.get("scrap", 0))
	return "%s\n%s %d/%d · %d %s / %d %s" % [
		name, LEVEL, level, max_level, gold, GOLD_SUFFIX, scrap, SCRAP_SUFFIX]
