class_name LevelPrefetch
extends RefCounted

## Arka planda seviye üretimi + küçük önbellek. Neden: ağır seviyelerde (55, 57, 66, 77, 96,
## 108) `LevelGenerator.generate` çözücü doğrulamalarıyla ~1 sn sürüyordu; ana iş parçacığında
## bu, kazanma sayfasından sonraki "Devam"da ekranın donması demekti. Sonraki seviye oyuncu
## oynarken/kazanma sayfasındayken WorkerThreadPool'da üretilir; `take` hazır sonucu alır.
##
## Doğruluk: üretici saf ve deterministiktir (yalnız yerel RNG, düğüm/autoload erişimi yok);
## bu yüzden arka plan sonucu eşzamanlı sonuçla BİREBİR aynıdır (test_level_prefetch.gd).
## İş parçacığında sahne ağacına hiç dokunulmaz: iş yalnız bir Callable çalıştırır ve sözlük döndürür.
## Kapanış: `drain()` (GameManager._exit_tree) bekleyen işleri bitirir; yarım iş kalmaz.

## Önbellekte tutulan en fazla sonuç (seviye sözlükleri küçük, birkaç KB). Tekrar dene /
## yeniden başlat aynı seviyeyi ister: önbellekte kalırsa yeniden üretilmez.
const MAX_CACHED: int = 4
const LEVEL_KEY: String = "level:%d"

## Testler/araçlar kapatabilir: kapalıyken her şey eşzamanlı (eski davranış).
static var enabled: bool = true
## Anahtar -> WorkerThreadPool görev kimliği (yalnız ana iş parçacığı yazar/okur).
static var _tasks: Dictionary[String, int] = {}
## Anahtar -> sonuç. İş parçacığı yazar, ana iş parçacığı okur: kilitle korunur.
static var _results: Dictionary[String, Dictionary] = {}
## Önbellek sırası (en eski başta) — yalnız ana iş parçacığı.
static var _order: Array[String] = []
static var _mutex: Mutex = Mutex.new()


static func level_key(level: int) -> String:
	return LEVEL_KEY % maxi(level, 1)


## Seviyenin arka planda üretimini başlatır (zaten varsa/sürüyorsa bir şey yapmaz).
static func request_level(level: int) -> void:
	request(level_key(level), LevelGenerator.generate.bind(maxi(level, 1)))


## Seviye sözlüğü: hazırsa önbellekten (kopya), üretimdeyse bitmesini bekler, hiç
## istenmemişse eşzamanlı üretir. Sonuç her durumda `LevelGenerator.generate(level)` ile aynıdır.
static func take_level(level: int) -> Dictionary:
	return take(level_key(level), LevelGenerator.generate.bind(maxi(level, 1)))


## Genel iş: `job` saf olmalı (düğüm/autoload yok) ve Dictionary döndürmeli.
static func request(key: String, job: Callable) -> void:
	if not enabled or _tasks.has(key) or _has_result(key):
		return
	_tasks[key] = WorkerThreadPool.add_task(_run.bind(key, job), false, "prefetch " + key)
	_touch(key)


static func is_ready(key: String) -> bool:
	if _has_result(key):
		return true
	return _tasks.has(key) and WorkerThreadPool.is_task_completed(_tasks[key])


static func take(key: String, job: Callable) -> Dictionary:
	_finish(key)
	_mutex.lock()
	var cached: Dictionary = _results.get(key, {}) as Dictionary
	_mutex.unlock()
	if cached.is_empty():
		cached = job.call() as Dictionary
		_store(key, cached)
	_touch(key)
	# Kopya: oyun/tahta sözlüğü değiştirse bile önbellekteki asıl kalsın (tekrar dene aynı başlar).
	return cached.duplicate(true)


## Bekleyen tüm işleri bitirir ve önbelleği boşaltır (kapanış / testler).
static func drain() -> void:
	for key: String in _tasks.keys():
		_finish(key)
	_mutex.lock()
	_results.clear()
	_mutex.unlock()
	_order.clear()


static func _finish(key: String) -> void:
	if not _tasks.has(key):
		return
	WorkerThreadPool.wait_for_task_completion(_tasks[key])
	_tasks.erase(key)


## İş parçacığında çalışır: yalnız saf iş + kilitli yazma.
static func _run(key: String, job: Callable) -> void:
	var result: Dictionary = job.call() as Dictionary
	_store(key, result)


static func _store(key: String, result: Dictionary) -> void:
	_mutex.lock()
	_results[key] = result
	_mutex.unlock()


static func _has_result(key: String) -> bool:
	_mutex.lock()
	var found: bool = _results.has(key)
	_mutex.unlock()
	return found


## Kullanılan anahtarı sona alır; sınır aşılırsa en eski (ve bitmiş) sonuç atılır.
static func _touch(key: String) -> void:
	_order.erase(key)
	_order.append(key)
	while _order.size() > MAX_CACHED:
		var oldest: String = _order[0]
		if _tasks.has(oldest):
			# Hâlâ üretiliyor: atılmaz (bitince alınacak); sınır geçici olarak aşılabilir.
			break
		_order.pop_front()
		_mutex.lock()
		_results.erase(oldest)
		_mutex.unlock()
