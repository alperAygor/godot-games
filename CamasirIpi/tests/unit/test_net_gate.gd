extends TestCase

## Çevrimiçi kapısı: karar mantığı sahte aktarımla sınanır (gerçek ağ YOK). Kapı headless/editörde
## kendiliğinden kapalıdır; burada `forced` ile açılır.

const FAKE_START_MSEC: int = 1000


## Sıralı yanıt veren sahte aktarım: her `probe` çağrısı listeden bir sonuç tüketir (bitince son sonuç).
class FakeTransport extends OnlineTransport:
	var answers: Array[bool] = []
	var calls: Array[String] = []

	func probe(url: String, _status: int, _timeout: float) -> bool:
		calls.append(url)
		if answers.is_empty():
			return false
		return answers.pop_front() if answers.size() > 1 else answers[0]


var _now: int = FAKE_START_MSEC


func before_each() -> void:
	OnlineGate.reset()
	AnalyticsLog.echo = false
	AnalyticsLog.clear()
	_now = FAKE_START_MSEC


func after_each() -> void:
	OnlineGate.reset()


func _checker(transport: OnlineTransport) -> OnlineChecker:
	var checker: OnlineChecker = OnlineChecker.new(transport)
	checker.clock = func() -> int: return _now
	return checker


func _fake(answers: Array[bool]) -> FakeTransport:
	var fake: FakeTransport = FakeTransport.new()
	fake.answers = answers
	return fake


func test_online_passes_and_is_cached_for_ttl() -> void:
	var fake: FakeTransport = _fake([true])
	var checker: OnlineChecker = _checker(fake)
	assert_false(checker.is_fresh(), "başta önbellek boş")
	assert_true(await checker.check(), "çevrimiçi")
	assert_true(checker.is_fresh())
	assert_true(await checker.check(), "önbellekten")
	assert_eq(fake.calls.size(), 1, "ikinci denetim ağa gitmemeli")
	_now += OnlineChecker.TTL_MSEC - 1
	assert_true(checker.is_fresh(), "TTL bitmeden taze")
	_now += 2
	assert_false(checker.is_fresh(), "TTL bitince bayat")
	assert_true(await checker.check())
	assert_eq(fake.calls.size(), 2, "bayat önbellek yeniden denetler")


func test_falls_back_to_second_endpoint() -> void:
	var fake: FakeTransport = _fake([false, true])
	var checker: OnlineChecker = _checker(fake)
	assert_true(await checker.check(), "ikinci uç nokta yetmeli")
	assert_eq(fake.calls.size(), 2)
	assert_eq(fake.calls[0], String(OnlineChecker.ENDPOINTS[0]["url"]))
	assert_eq(fake.calls[1], String(OnlineChecker.ENDPOINTS[1]["url"]))


func test_offline_is_never_cached() -> void:
	var fake: FakeTransport = _fake([false])
	var checker: OnlineChecker = _checker(fake)
	assert_false(await checker.check())
	assert_false(checker.is_fresh())
	assert_false(await checker.check())
	assert_eq(fake.calls.size(), OnlineChecker.ENDPOINTS.size() * 2, "çevrimdışı her seferinde yeniden denenir")


func test_force_ignores_cache_and_drop_is_noticed() -> void:
	var fake: FakeTransport = _fake([true, false])
	var checker: OnlineChecker = _checker(fake)
	assert_true(await checker.check())
	assert_false(await checker.check(true), "zorla denetim bağlantı düştüğünü görmeli")
	assert_false(checker.is_fresh(), "başarısız denetim önbelleği siler")


func test_gate_is_disabled_in_headless_and_by_flag() -> void:
	assert_true(OnlineGate.auto_disabled(), "headless/editörde kendiliğinden kapalı")
	assert_false(OnlineGate.is_active())
	assert_true(OnlineGate.passes_now(), "kapalı kapı hiçbir şeyi engellemez")
	OnlineGate.forced = true
	assert_true(OnlineGate.is_active())
	OnlineGate.enabled = false
	assert_false(OnlineGate.is_active(), "araçlar enabled=false ile kapatabilir")


func test_gate_blocks_when_offline_and_proceeds_when_online() -> void:
	OnlineGate.forced = true
	var fake: FakeTransport = _fake([false])
	var checker: OnlineChecker = OnlineGate.set_transport(fake)
	checker.clock = func() -> int: return _now
	assert_false(OnlineGate.passes_now(), "çevrimdışı: seviye başlayamaz")
	var host: Node = Node.new()
	add_node(host)
	var started: Array[int] = [0]
	OnlineGate.guard(host, func() -> void: started[0] += 1)
	assert_eq(started[0], 0, "çevrimdışıyken başlatılmamalı")
	assert_true(OnlineGate.sheet_open(), "Bağlantı gerekli sayfası açılmalı")
	assert_eq(AnalyticsLog.count(OnlineGate.EVENT_SHOWN), 1)
	# Bağlantı gelir: sayfanın yeniden denemesi geçer ve seviye başlar.
	fake.answers = [true]
	var sheet: OnlineSheet = OnlineGate._sheet
	sheet._attempt(true)
	assert_eq(started[0], 1, "bağlantı gelince başlamalı")
	assert_eq(AnalyticsLog.count(OnlineGate.EVENT_PASSED), 1)
	assert_true(AnalyticsLog.count(OnlineGate.EVENT_RETRY) >= 1)
	assert_true(OnlineGate.passes_now(), "doğrulanınca önbellek taze")
	# Taze önbellekle ikinci seviye anında başlar, ağa gidilmez.
	var calls_before: int = fake.calls.size()
	OnlineGate.guard(host, func() -> void: started[0] += 1)
	assert_eq(started[0], 2)
	assert_eq(fake.calls.size(), calls_before)
	host.queue_free()
