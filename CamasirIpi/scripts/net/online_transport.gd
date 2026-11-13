class_name OnlineTransport
extends RefCounted

## Bağlantı denetiminin "tel" katmanı: tek bir adrese GET atar, sonucu doğru/yanlış döndürür.
## Neden ayrı sınıf: karar mantığı (OnlineChecker) ağdan bağımsız sınanabilsin; testler bu
## sınıfı sahte bir alt sınıfla değiştirir, gerçek ağ yalnız HttpOnlineTransport'ta vardır.
## `probe` bir korutin olabilir (alt sınıflar `await` eder); çağıran her zaman `await` eder.


## true: adrese ulaşıldı ve beklenen durum kodu geldi. Taban sınıf hiçbir şeye ulaşamaz.
func probe(_url: String, _expected_status: int, _timeout_seconds: float) -> bool:
	return false
