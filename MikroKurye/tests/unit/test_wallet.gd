extends TestCase

## Wallet: Altın + Hurda bakiyesi, harcama, sözlüğe dönüştürme. Sözleşme: ARCHITECTURE.md §4.7.
## Sınıf henüz YOK — testler sözleşmeden türetildi (kırmızı aşama).
##
## Varsayımlar (sözleşmede açık değil):
## - from_dict: int alanına float değer de "yanlış tip" sayılır -> 0.


func test_new_wallet_is_empty() -> void:
	var w: Wallet = Wallet.new()
	assert_eq(w.gold(), 0)
	assert_eq(w.scrap(), 0)
	assert_eq(w.to_dict(), {"gold": 0, "scrap": 0})


func test_init_with_balances() -> void:
	var w: Wallet = Wallet.new(12, 7)
	assert_eq(w.gold(), 12)
	assert_eq(w.scrap(), 7)


func test_add_increases_balances() -> void:
	var w: Wallet = Wallet.new(10, 5)
	w.add(5, 3)
	assert_eq(w.gold(), 15)
	assert_eq(w.scrap(), 8)
	w.add(2)  # scrap varsayılan 0
	assert_eq(w.gold(), 17)
	assert_eq(w.scrap(), 8)


func test_add_ignores_negative_input() -> void:
	var w: Wallet = Wallet.new(10, 5)
	w.add(-100, -50)
	assert_eq(w.gold(), 10)
	assert_eq(w.scrap(), 5)


func test_can_afford_sufficient() -> void:
	var w: Wallet = Wallet.new(10, 5)
	assert_true(w.can_afford({"gold": 10, "scrap": 5}))
	assert_true(w.can_afford({"gold": 3, "scrap": 1}))


func test_can_afford_missing_key_is_zero() -> void:
	var w: Wallet = Wallet.new(10, 5)
	assert_true(w.can_afford({"gold": 10}))
	assert_true(w.can_afford({"scrap": 5}))
	assert_true(w.can_afford({}))


func test_can_afford_insufficient() -> void:
	var w: Wallet = Wallet.new(5, 0)
	assert_false(w.can_afford({"gold": 6}))
	assert_false(w.can_afford({"gold": 5, "scrap": 1}))


func test_spend_deducts_when_affordable() -> void:
	var w: Wallet = Wallet.new(10, 5)
	assert_true(w.spend({"gold": 4, "scrap": 2}))
	assert_eq(w.gold(), 6)
	assert_eq(w.scrap(), 3)


func test_spend_fails_without_changes() -> void:
	var w: Wallet = Wallet.new(5, 5)
	assert_false(w.spend({"gold": 6, "scrap": 0}))
	assert_eq(w.gold(), 5)
	assert_eq(w.scrap(), 5)
	assert_false(w.spend({"gold": 0, "scrap": 6}))
	assert_eq(w.gold(), 5)
	assert_eq(w.scrap(), 5)


func test_spend_exact_balance_drains_to_zero() -> void:
	var w: Wallet = Wallet.new(10, 0)
	assert_true(w.spend({"gold": 10}))
	assert_eq(w.gold(), 0)


func test_to_dict_round_trips_through_from_dict() -> void:
	var w: Wallet = Wallet.new(30, 12)
	var copy: Wallet = Wallet.from_dict(w.to_dict())
	assert_eq(copy.gold(), 30)
	assert_eq(copy.scrap(), 12)


func test_from_dict_missing_keys_are_zero() -> void:
	var w: Wallet = Wallet.from_dict({})
	assert_eq(w.gold(), 0)
	assert_eq(w.scrap(), 0)
	var partial: Wallet = Wallet.from_dict({"gold": 10})
	assert_eq(partial.gold(), 10)
	assert_eq(partial.scrap(), 0)


func test_from_dict_negative_is_zero() -> void:
	var w: Wallet = Wallet.from_dict({"gold": -10, "scrap": -5})
	assert_eq(w.gold(), 0)
	assert_eq(w.scrap(), 0)


func test_from_dict_wrong_type_is_zero() -> void:
	assert_eq(Wallet.from_dict({"gold": "10", "scrap": 5}).gold(), 0)
	assert_eq(Wallet.from_dict({"gold": true, "scrap": 5}).gold(), 0)
	# float, int alanı için yanlış tiptir
	assert_eq(Wallet.from_dict({"gold": 10.5, "scrap": 5}).gold(), 0)
	assert_eq(Wallet.from_dict({"gold": 10, "scrap": 5}).scrap(), 5)


func test_instances_do_not_share_state() -> void:
	var a: Wallet = Wallet.new(10, 5)
	var b: Wallet = Wallet.new()
	a.add(5)
	assert_eq(a.gold(), 15)
	assert_eq(b.gold(), 0)


func test_from_dict_accepts_whole_floats_from_json() -> void:
	# Godot JSON sayıları float döndürür (GOTCHAS #20): kayıt dosyası böyle okunur.
	var w: Wallet = Wallet.from_dict({"gold": 10.0, "scrap": 5.0})
	assert_eq(w.gold(), 10)
	assert_eq(w.scrap(), 5)
	var parsed: Variant = JSON.parse_string(JSON.stringify({"gold": 120, "scrap": 7}))
	var loaded: Wallet = Wallet.from_dict(parsed as Dictionary)
	assert_eq(loaded.gold(), 120)
	assert_eq(loaded.scrap(), 7)
	assert_eq(Wallet.from_dict({"gold": 10.5}).gold(), 0)
	assert_eq(Wallet.from_dict({"gold": -3.0}).gold(), 0)
