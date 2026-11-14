extends TestCase

## Haptics: süreler veriden, ayar kapalıyken ve masaüstünde sessiz (çökmez).

func test_durations_come_from_balance_with_fallbacks() -> void:
	var table: Dictionary = ProgressData.load_balance()["haptics"] as Dictionary
	assert_eq(Haptics.duration_ms(Haptics.Kind.TICK, table), int(table["tick_ms"]))
	assert_eq(Haptics.duration_ms(Haptics.Kind.THUD, table), int(table["thud_ms"]))
	assert_eq(Haptics.duration_ms(Haptics.Kind.SUCCESS, {}), Haptics.DEFAULT_SUCCESS_MS)
	assert_true(Haptics.duration_ms(Haptics.Kind.TICK) < Haptics.duration_ms(Haptics.Kind.SUCCESS), "tık, başarıdan hafif")
	assert_eq(Haptics.duration_ms(Haptics.Kind.THUD, {"thud_ms": -5}), Haptics.DEFAULT_THUD_MS, "bozuk değer yedeğe düşer")


func test_respects_vibration_setting() -> void:
	var progress: Node = autoload_node("Progress")
	var old_persist: bool = bool(progress.get("persist"))
	progress.set("persist", false)
	progress.call("set_setting", "vibration", false)
	assert_false(Haptics.enabled())
	progress.call("set_setting", "vibration", true)
	assert_true(Haptics.enabled())
	progress.call("reset_state")
	progress.set("persist", old_persist)


func test_calls_are_safe_no_ops_on_desktop() -> void:
	Haptics.tick()
	Haptics.thud()
	Haptics.success()
	assert_eq(Haptics.available(), OS.has_feature("mobile"))
