extends TestCase

## OverloadModel: dolum/bosalim, kalkan, add_load cezasi, tepe ve sigorta.
## Degerler data/balance.json varsayilanlariyla ayni (0.5 / 0.25 / 0.25) secildi.

var _model: OverloadModel = null


func before_each() -> void:
	_model = OverloadModel.new()
	_model.configure(0.5, 0.25, 0.25)


func after_each() -> void:
	_model = null


func test_starts_empty() -> void:
	assert_almost_eq(_model.value, 0.0)
	assert_almost_eq(_model.peak, 0.0)
	assert_false(_model.blown)
	assert_false(_model.is_shielded())
	assert_eq(_model.contact_count, 0)


func test_single_contact_fills_at_base_rate() -> void:
	_model.tick(1.0, 1)
	assert_almost_eq(_model.value, 0.5, 0.0001, "1 sn tek temas = fill hizi")
	assert_almost_eq(_model.current_fill_rate(0), 0.0)
	assert_almost_eq(_model.current_fill_rate(1), 0.5)


func test_extra_contacts_accelerate_fill() -> void:
	_model.tick(0.4, 3)
	# 3 temas: 0.5 + 0.25*2 = 1.0/sn; 0.4 sn -> 0.4
	assert_almost_eq(_model.value, 0.4, 0.0001)
	assert_almost_eq(_model.current_fill_rate(3), 1.0)


func test_no_contact_drains() -> void:
	_model.tick(1.0, 1)
	_model.tick(1.0, 0)
	assert_almost_eq(_model.value, 0.25, 0.0001, "0.5 - 0.25")


func test_drain_never_goes_negative() -> void:
	_model.add_load(0.1)
	_model.tick(100.0, 0)
	assert_almost_eq(_model.value, 0.0, 0.0001)


func test_peak_tracks_highest_value() -> void:
	_model.tick(1.0, 1)
	_model.tick(10.0, 0)
	assert_almost_eq(_model.value, 0.0, 0.0001)
	assert_almost_eq(_model.peak, 0.5, 0.0001, "tepe dusmez")


func test_blown_at_full_and_frozen() -> void:
	_model.tick(2.5, 1)
	assert_true(_model.blown, "bar 1.0'da sigorta atar")
	assert_almost_eq(_model.value, 1.0, 0.0001)
	assert_almost_eq(_model.peak, 1.0, 0.0001)
	_model.tick(5.0, 0)
	assert_almost_eq(_model.value, 1.0, 0.0001, "attiktan sonra bosalmaz")


func test_add_load_direct_penalty() -> void:
	_model.add_load(0.3)
	assert_almost_eq(_model.value, 0.3, 0.0001)
	assert_almost_eq(_model.peak, 0.3, 0.0001)
	_model.add_load(0.8)
	assert_true(_model.blown, "add_load sigortayi attirabilir")
	assert_almost_eq(_model.value, 1.0, 0.0001)


func test_negative_add_load_is_ignored() -> void:
	_model.add_load(-1.0)
	assert_almost_eq(_model.value, 0.0)


func test_shield_blocks_fill_and_expires() -> void:
	_model.add_shield(1.0)
	_model.tick(0.4, 1)
	assert_almost_eq(_model.value, 0.0, 0.0001, "kalkan dolumu engeller")
	assert_almost_eq(_model.shield_left, 0.6, 0.0001)
	_model.tick(0.6, 1)
	assert_almost_eq(_model.shield_left, 0.0, 0.0001)
	assert_almost_eq(_model.value, 0.0, 0.0001, "kalkanli gecen tum sure dolmaz")
	_model.tick(0.4, 1)
	assert_almost_eq(_model.value, 0.2, 0.0001, "kalkan bitince dolum baslar")


func test_shield_blocks_add_load() -> void:
	_model.add_shield(2.0)
	_model.add_load(0.5)
	assert_almost_eq(_model.value, 0.0, 0.0001)
	assert_false(_model.blown)


func test_shield_extends_to_larger_value_only() -> void:
	_model.add_shield(1.0)
	_model.add_shield(0.5)
	assert_almost_eq(_model.shield_left, 1.0, 0.0001)
	_model.add_shield(2.0)
	assert_almost_eq(_model.shield_left, 2.0, 0.0001)


func test_partial_shield_tick_fills_remaining_time() -> void:
	_model.add_shield(0.25)
	_model.tick(0.5, 1)
	# 0.25 sn kalkanli + 0.25 sn dolum: 0.5*0.25 = 0.125
	assert_almost_eq(_model.value, 0.125, 0.0001)


func test_reset_clears_everything() -> void:
	_model.tick(1.0, 2)
	_model.add_shield(3.0)
	_model.add_load(0.2)
	_model.reset()
	assert_almost_eq(_model.value, 0.0, 0.0001)
	assert_almost_eq(_model.peak, 0.0, 0.0001)
	assert_false(_model.blown)
	assert_almost_eq(_model.shield_left, 0.0, 0.0001)
	assert_eq(_model.contact_count, 0)


func test_non_positive_delta_is_noop() -> void:
	_model.tick(0.0, 1)
	_model.tick(-1.0, 1)
	assert_almost_eq(_model.value, 0.0, 0.0001)
	assert_eq(_model.contact_count, 0)


func test_contact_count_is_recorded() -> void:
	_model.tick(0.1, 4)
	assert_eq(_model.contact_count, 4)
	_model.tick(0.1, 0)
	assert_eq(_model.contact_count, 0)
