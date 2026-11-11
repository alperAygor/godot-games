extends TestCase

## BatteryModel: batarya seviyesi, tüketim, şarj, boost. Sözleşme: ARCHITECTURE.md §4.3.
## Sınıf henüz YOK — testler sözleşmeden türetildi (kırmızı aşama).
##
## Varsayılanlar (sözleşme): capacity 100.0, speed_drain 0.02,
## empty_speed_factor 0.35, boost_factor 1.25.
##
## Varsayımlar (sözleşmede açık değil):
## - recharge(negatif) -> değişiklik yok (güvenli davranış).
## - start_boost(<= 0) -> boost aktif değil (süre 0'ın altına inmez).


func test_new_battery_is_full() -> void:
	var b: BatteryModel = BatteryModel.new()
	assert_almost_eq(b.level(), 1.0, 0.0001)
	assert_false(b.is_empty())
	assert_almost_eq(b.speed_factor(), 1.0, 0.0001)


func test_default_capacity_is_100() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.drain(25.0)
	# 75 / 100 = 0.75
	assert_almost_eq(b.level(), 0.75, 0.0001)


func test_drain_never_goes_below_zero() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.drain(1000.0)
	assert_almost_eq(b.level(), 0.0, 0.0001)
	assert_true(b.is_empty())


func test_drain_ignores_negative_amount() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.drain(-50.0)
	assert_almost_eq(b.level(), 1.0, 0.0001)


func test_drain_for_speed_uses_speed_squared_times_dt() -> void:
	var b: BatteryModel = BatteryModel.new(1.0)  # kapasite 1.0
	# tüketim = 0.02 * 2^2 * 1 = 0.08 -> level 0.92
	b.drain_for_speed(2.0, 1.0)
	assert_almost_eq(b.level(), 0.92, 0.0001)


func test_drain_for_speed_zero_speed_consumes_nothing() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.drain_for_speed(0.0, 1.0)
	assert_almost_eq(b.level(), 1.0, 0.0001)


func test_drain_for_speed_negative_speed_or_dt_consumes_nothing() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.drain_for_speed(-3.0, 1.0)
	b.drain_for_speed(3.0, -1.0)
	assert_almost_eq(b.level(), 1.0, 0.0001)


func test_recharge_increases_level() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.drain(50.0)
	b.recharge(25.0)
	# 75 / 100 = 0.75
	assert_almost_eq(b.level(), 0.75, 0.0001)


func test_recharge_never_exceeds_capacity() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.recharge(1000.0)
	assert_almost_eq(b.level(), 1.0, 0.0001)


func test_recharge_ignores_negative_amount() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.drain(50.0)
	b.recharge(-25.0)
	assert_almost_eq(b.level(), 0.5, 0.0001)


func test_refill_full_restores_capacity() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.drain(90.0)
	b.refill_full()
	assert_almost_eq(b.level(), 1.0, 0.0001)
	assert_false(b.is_empty())


func test_speed_factor_linear_from_full_to_empty() -> void:
	var b: BatteryModel = BatteryModel.new()
	assert_almost_eq(b.speed_factor(), 1.0, 0.0001)
	b.drain(50.0)
	# 0.35 + (1.0 - 0.35) * 0.5 = 0.675
	assert_almost_eq(b.speed_factor(), 0.675, 0.0001)
	b.drain(50.0)
	assert_true(b.is_empty())
	assert_almost_eq(b.speed_factor(), 0.35, 0.0001)


func test_custom_empty_speed_factor() -> void:
	var b: BatteryModel = BatteryModel.new(100.0, {"empty_speed_factor": 0.5})
	b.drain(1000.0)
	assert_true(b.is_empty())
	assert_almost_eq(b.speed_factor(), 0.5, 0.0001)


func test_custom_speed_drain_affects_consumption() -> void:
	var b: BatteryModel = BatteryModel.new(1.0, {"speed_drain": 0.1})
	# 0.1 * 2^2 * 1 = 0.4 -> level 0.6
	b.drain_for_speed(2.0, 1.0)
	assert_almost_eq(b.level(), 0.6, 0.0001)


func test_boost_active_during_window() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.start_boost(3.0)
	assert_true(b.boost_active())
	assert_almost_eq(b.speed_factor(), 1.25, 0.0001)


func test_boost_expires_after_tick() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.start_boost(1.0)
	b.tick(1.0)
	assert_false(b.boost_active())


func test_boost_speed_factor_overrides_empty_battery() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.drain(1000.0)
	assert_true(b.is_empty())
	b.start_boost(5.0)
	assert_almost_eq(b.speed_factor(), 1.25, 0.0001)


func test_speed_factor_returns_to_normal_after_boost() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.start_boost(1.0)
	assert_almost_eq(b.speed_factor(), 1.25, 0.0001)
	b.tick(1.0)
	assert_almost_eq(b.speed_factor(), 1.0, 0.0001)


func test_boost_does_not_drain_battery() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.start_boost(5.0)
	assert_almost_eq(b.level(), 1.0, 0.0001)


func test_tick_does_not_go_below_zero() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.start_boost(1.0)
	b.tick(100.0)
	b.tick(100.0)
	assert_false(b.boost_active())


func test_boost_zero_or_negative_seconds_is_not_active() -> void:
	var b: BatteryModel = BatteryModel.new()
	b.start_boost(0.0)
	assert_false(b.boost_active())
	b.start_boost(-1.0)
	assert_false(b.boost_active())


func test_battery_instances_do_not_share_state() -> void:
	var a: BatteryModel = BatteryModel.new()
	var b: BatteryModel = BatteryModel.new()
	a.drain(50.0)
	assert_almost_eq(a.level(), 0.5, 0.0001)
	assert_almost_eq(b.level(), 1.0, 0.0001)
