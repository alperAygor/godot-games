class_name OnlineChecker
extends RefCounted

## Bağlantı kararının saf mantığı: sırayla uç noktaları dener, ilk başarıda "çevrimiçi" der,
## sonucu kısa süre (TTL) önbellekte tutar. Aktarım ve saat dışarıdan verilir (test edilebilirlik).
## Neden TTL: her seviye başında ağa gitmek hem yavaş hem pil harcar; 60 sn içinde ikinci
## seviye anında başlar. Düşme anında değil, SONRAKİ seviye başında yeniden denetlenir.

## Hafif ve güvenilir iki uç nokta (yedekli): gövdesiz 204 döner, kişisel veri taşımaz.
const ENDPOINTS: Array[Dictionary] = [
	{"url": "https://connectivitycheck.gstatic.com/generate_204", "status": 204},
	{"url": "https://cp.cloudflare.com/generate_204", "status": 204},
]
const TTL_MSEC: int = 60000
## Tek istek için üst süre: yavaş ağda oyuncuyu bekletmemek için kısa.
const TIMEOUT_SECONDS: float = 4.0
const NEVER: int = -1

var transport: OnlineTransport = null
var ttl_msec: int = TTL_MSEC
var timeout_seconds: float = TIMEOUT_SECONDS
## Saat enjeksiyonu (ms): testler sahte zaman verir.
var clock: Callable = Callable()
## Kaç gerçek denetim yapıldı (önbellekten karşılananlar sayılmaz): testler için.
var probe_count: int = 0

var _ok_at_msec: int = NEVER


func _init(new_transport: OnlineTransport = null) -> void:
	transport = new_transport if new_transport != null else OnlineTransport.new()


func now_msec() -> int:
	return int(clock.call()) if clock.is_valid() else Time.get_ticks_msec()


## Son başarılı denetim TTL içinde mi (ağa gitmeden "çevrimiçi" saymak için).
func is_fresh() -> bool:
	return _ok_at_msec != NEVER and now_msec() - _ok_at_msec < ttl_msec


## Çevrimiçi mi? `force` önbelleği yok sayar (yeniden dene düğmesi). Korutin: çağıran `await` eder.
func check(force: bool = false) -> bool:
	if not force and is_fresh():
		return true
	for endpoint: Dictionary in ENDPOINTS:
		probe_count += 1
		var reached: bool = await transport.probe(String(endpoint["url"]), int(endpoint["status"]),
			timeout_seconds)
		if reached:
			_ok_at_msec = now_msec()
			return true
	_ok_at_msec = NEVER
	return false


func invalidate() -> void:
	_ok_at_msec = NEVER
