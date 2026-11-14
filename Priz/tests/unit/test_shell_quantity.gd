extends TestCase

## Quantity: miktarların sayısız gösterimi (jeton simgeleri, seviye noktaları) — saf hesap.

var _display: Dictionary = {}


func before_each() -> void:
	_display = ProgressData.load_balance()["coin_display"] as Dictionary


func test_zero_coins_show_nothing_but_any_positive_shows_one_icon() -> void:
	assert_eq(Quantity.coin_layout(0, _display), {"icons": 0, "pile": false})
	assert_eq(Quantity.coin_layout(1, _display), {"icons": 1, "pile": false})
	assert_eq(Quantity.coin_layout(-5, _display), {"icons": 0, "pile": false}, "negatif sıfır sayılır")


func test_icons_grow_with_amount_and_are_capped() -> void:
	assert_eq(int(Quantity.coin_layout(10, _display)["icons"]), 1)
	assert_eq(int(Quantity.coin_layout(11, _display)["icons"]), 2)
	assert_eq(int(Quantity.coin_layout(20, _display)["icons"]), 2)
	assert_eq(int(Quantity.coin_layout(40, _display)["icons"]), 4)
	assert_eq(int(Quantity.coin_layout(50, _display)["icons"]), 5)
	assert_eq(int(Quantity.coin_layout(99999, _display)["icons"]), 5, "üst sınır max_icons")


func test_pile_appears_from_threshold() -> void:
	assert_false(bool(Quantity.coin_layout(99, _display)["pile"]))
	assert_true(bool(Quantity.coin_layout(100, _display)["pile"]))
	assert_true(bool(Quantity.coin_layout(123456, _display)["pile"]))


func test_icons_never_decrease_when_amount_increases() -> void:
	var last: int = 0
	for amount: int in range(0, 400, 3):
		var icons: int = int(Quantity.coin_layout(amount, _display)["icons"])
		assert_true(icons >= last, "simge sayısı azalmamalı")
		last = icons


func test_missing_display_uses_defaults() -> void:
	assert_eq(Quantity.coin_layout(25, {}), {"icons": 3, "pile": false})
	assert_eq(Quantity.coin_layout(100, {}), {"icons": 5, "pile": true})


func test_level_pips_cycle_every_block_with_hard_level_last() -> void:
	assert_eq(int(Quantity.level_pips(1)["done"]), 0)
	assert_eq(int(Quantity.level_pips(4)["done"]), 3)
	var hard: Dictionary = Quantity.level_pips(5)
	assert_eq(int(hard["current"]), 4, "5. seviye = zor = son nokta")
	assert_eq(int(hard["total"]), 5)
	assert_eq(int(Quantity.level_pips(6)["done"]), 0, "yeni blok")
	assert_eq(int(Quantity.level_pips(10)["current"]), 4)
	assert_eq(int(Quantity.level_pips(0)["done"]), 0, "geçersiz seviye 1 sayılır")


func test_block_size_comes_from_balance_with_floor() -> void:
	assert_eq(Quantity.block_size({"block": 5}), 5)
	assert_eq(Quantity.block_size({}), 5)
	assert_eq(Quantity.block_size({"block": 0}), 5, "geçersiz değer yedeğe düşer")
	assert_eq(Quantity.block_size({"block": 1}), 2, "en az iki nokta")


func test_chip_shows_icons_not_digits() -> void:
	var chip: UiChip = UiChip.new()
	add_node(chip)
	chip.setup("lucide/coins", UiKit.GOLD)
	chip.set_value(0)
	assert_eq(chip.icon_count(), 0)
	chip.set_value(30, false)
	assert_eq(chip.icon_count(), 3)
	assert_false(chip.has_pile())
	chip.set_value(250, false)
	assert_eq(chip.icon_count(), 5)
	assert_true(chip.has_pile())
	assert_eq(chip.find_children("*", "Label", true, false).size(), 0, "hapta hiç metin etiketi yok")
	chip.free()


func test_pips_state_is_clamped() -> void:
	var pips: UiPips = UiPips.new()
	pips.set_state(5, 9, 2, true)
	assert_eq(pips.done, 5)
	assert_true(pips.custom_minimum_size.x > 0.0)
	pips.set_state(0, 3)
	assert_eq(pips.done, 0)
	pips.free()
