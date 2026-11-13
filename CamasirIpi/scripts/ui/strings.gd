class_name UiStrings
extends RefCounted

## Arayüzün tüm kullanıcıya görünen metinleri (Türkçe) tek yerde.
## Neden tek dosya: dil eklemek/metin cilalamak için ekran kodunu taramak gerekmesin.

const GAME_TITLE: String = "Çamaşır İpi"
const LEVEL: String = "Seviye %d"

# Ana ekran
const SOON_TITLE: String = "Yakında"
const SOON_BODY: String = "Bu bölüm çok yakında burada olacak."
const OK: String = "Tamam"
const SETTINGS_TITLE: String = "Ayarlar"

# Ayar anahtarları ve alt yazıları
const SOUND: String = "Ses"
const MUSIC: String = "Müzik"
const VIBRATION: String = "Titreşim"

# Duraklatma
const PAUSED: String = "Duraklatıldı"
const RESUME: String = "Devam"

# Kazanma
const WIN_TITLE: String = "Harika!"
const WIN_CONTINUE: String = "Devam"
const WIN_DOUBLE: String = "2×"
const REWARD_FORMAT: String = "+%d"

# Kaybetme
const LOSE_TITLE: String = "Fırtına çıktı"
const LOSE_FEW_PREFIX: String = "Sadece"
const LOSE_REMAINING_SUFFIX: String = "çamaşır kaldı"
const LOSE_REVIVE: String = "+1 askı"
## Hamle bitince devam: +1 askı ile birlikte ek hamle de verilir; düğme bunu söyler.
const LOSE_REVIVE_MOVES: String = "+5 hamle"
const LOSE_TITLE_MOVES: String = "Hamle bitti"
const LOSE_COINS: String = "%d jeton ile devam"
const DAILY_TITLE: String = "Günlük"
const LOSE_RETRY: String = "Tekrar dene"
