class_name OnlineGate
extends RefCounted

## "Çevrimdışı oynamak yasak" kapısı. Açılışta ve HER seviye başlamadan önce (normal, tekrar,
## günlük, zen) bağlantıyı denetler; yoksa sakin bir "Bağlantı gerekli" sayfası açar ve seviyeyi
## bağlantı gelene dek başlatmaz. Seviye ortasında bağlantı koparsa oyun KESİLMEZ; denetim bir
## sonraki seviye başında yapılır.
## Otomatik kapanır: editör, headless ve araç/prob çalıştırmalarında ağa asla bağımlı olunmaz
## (`enabled=false` ya da kendiliğinden). Testler `forced=true` + sahte aktarımla kapıyı sınar.
## Not (Android): dışa aktarım ön ayarında INTERNET izni açık olmalı (HTTPRequest için).

const ARG_FORCE: String = "--online-gate"
const HEADLESS_DRIVER: String = "headless"
const EVENT_SHOWN: String = "online_gate_shown"
const EVENT_RETRY: String = "online_gate_retry"
const EVENT_PASSED: String = "online_gate_passed"

## Araçlar kapatır (map_shot, probelar): kapı hiç devreye girmez.
static var enabled: bool = true
## Testler/ekran araçları: editör/headless otomatik kapanışını aşar (kapı yine `enabled` ister).
static var forced: bool = false

static var _checker: OnlineChecker = null
static var _sheet: OnlineSheet = null
## Bir denetim sürerken gelen ikinci istek yok sayılır: aynı seviye iki kez başlamasın
## (ilk isteğin `proceed`'i zaten çalışacak).
static var _checking: bool = false


## Kendiliğinden kapalı ortam mı: editör, headless sürücü (CI/prob) ya da araç.
static func auto_disabled() -> bool:
	return OS.has_feature("editor") or DisplayServer.get_name() == HEADLESS_DRIVER


static func is_active() -> bool:
	if not enabled:
		return false
	return forced or OS.get_cmdline_user_args().has(ARG_FORCE) or not auto_disabled()


## Testler: sahte aktarım takar (saat dahil önbellek sıfırlanır).
static func set_transport(transport: OnlineTransport) -> OnlineChecker:
	_checker = OnlineChecker.new(transport)
	return _checker


static func checker() -> OnlineChecker:
	if _checker == null:
		var loop: SceneTree = Engine.get_main_loop() as SceneTree
		_checker = OnlineChecker.new(HttpOnlineTransport.new(loop.root if loop != null else null))
	return _checker


## Testler: her şeyi başlangıç durumuna döndürür.
static func reset() -> void:
	enabled = true
	forced = false
	_checker = null
	_checking = false
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.queue_free()
	_sheet = null


## Seviye hemen başlayabilir mi (kapı kapalı ya da yakın zamanda doğrulanmış).
static func passes_now() -> bool:
	return not is_active() or checker().is_fresh()


## `proceed`'i bağlantı doğrulanınca çağırır. Kapı kapalı/önbellek taze ise anında; değilse
## denetler, çevrimdışıysa sayfa açar ve bağlantı gelince çağırır. `host`: sayfanın ekleneceği düğüm.
static func guard(host: Node, proceed: Callable) -> void:
	if passes_now():
		proceed.call()
		return
	_run_guard(host, proceed)


static func _run_guard(host: Node, proceed: Callable) -> void:
	if _sheet != null and is_instance_valid(_sheet):
		# Zaten açık: tek sayfa; bağlantı gelince o devam ettirir (yalnız ilk istek).
		return
	if _checking:
		return
	_checking = true
	var online: bool = await checker().check()
	_checking = false
	if online:
		if proceed.is_valid():
			proceed.call()
		return
	if host == null or not is_instance_valid(host):
		return
	AnalyticsLog.record(EVENT_SHOWN, {})
	_sheet = OnlineSheet.open(host, checker())
	_sheet.passed.connect(_on_sheet_passed.bind(proceed), CONNECT_ONE_SHOT)


static func _on_sheet_passed(proceed: Callable) -> void:
	_sheet = null
	AnalyticsLog.record(EVENT_PASSED, {})
	if proceed.is_valid():
		proceed.call()


## Sayfa şu an açık mı (probe/test).
static func sheet_open() -> bool:
	return _sheet != null and is_instance_valid(_sheet)
