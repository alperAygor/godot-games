extends TestCase

## CargoHealth: birikimli hasar, Şok Jeli koruması, kırık kargo. Sözleşme: ARCHITECTURE.md §4.2.

const PROFILE: Dictionary = {
	"impact_threshold": 5.0, "impact_scale": 0.05,
	"slosh_threshold": 6.0, "slosh_scale": 0.012,
	"fall_threshold": 0.25, "fall_scale": 1.0,
}


func test_new_cargo_is_intact() -> void:
	var h: CargoHealth = CargoHealth.new(PROFILE)
	assert_almost_eq(h.damage(), 0.0, 0.0001)
	assert_almost_eq(h.integrity(), 1.0, 0.0001)
	assert_false(h.is_broken())
	assert_eq(h.jelly_left(), 0)


func test_impact_adds_damage_and_returns_applied_amount() -> void:
	var h: CargoHealth = CargoHealth.new(PROFILE)
	var applied: float = h.apply_impact(7.0)   # (7-5)*0.05 = 0.10
	assert_almost_eq(applied, 0.10, 0.0001)
	assert_almost_eq(h.damage(), 0.10, 0.0001)
	assert_almost_eq(h.integrity(), 0.90, 0.0001)


func test_damage_accumulates_across_sources() -> void:
	var h: CargoHealth = CargoHealth.new(PROFILE)
	h.apply_impact(7.0)             # 0.10
	h.apply_slosh(10.0, 0.5)        # 0.024
	h.apply_fall(0.75)              # 0.50
	assert_almost_eq(h.damage(), 0.624, 0.0001)
	assert_false(h.is_broken())


func test_damage_is_clamped_and_cargo_breaks() -> void:
	var h: CargoHealth = CargoHealth.new(PROFILE)
	h.apply_impact(1000.0)
	assert_almost_eq(h.damage(), 1.0, 0.0001)
	assert_true(h.is_broken())
	assert_almost_eq(h.integrity(), 0.0, 0.0001)


func test_applied_amount_is_clamped_to_remaining_integrity() -> void:
	var h: CargoHealth = CargoHealth.new(PROFILE)
	h.apply_fall(1.2)               # (1.2-0.25)*1.0 = 0.95
	var applied: float = h.apply_fall(0.45)  # istenen 0.20; kalan 0.05
	assert_almost_eq(applied, 0.05, 0.0001)
	assert_almost_eq(h.damage(), 1.0, 0.0001)


func test_broken_cargo_ignores_further_damage() -> void:
	var h: CargoHealth = CargoHealth.new(PROFILE)
	h.apply_impact(1000.0)
	assert_almost_eq(h.apply_impact(1000.0), 0.0, 0.0001)
	assert_almost_eq(h.apply_slosh(100.0, 1.0), 0.0, 0.0001)
	assert_almost_eq(h.damage(), 1.0, 0.0001)


func test_zero_damage_events_do_not_change_state() -> void:
	var h: CargoHealth = CargoHealth.new(PROFILE)
	assert_almost_eq(h.apply_impact(1.0), 0.0, 0.0001)
	assert_almost_eq(h.apply_slosh(1.0, 1.0), 0.0, 0.0001)
	assert_almost_eq(h.apply_fall(0.1), 0.0, 0.0001)
	assert_almost_eq(h.damage(), 0.0, 0.0001)


func test_jelly_absorbs_the_breaking_hit_once() -> void:
	var h: CargoHealth = CargoHealth.new(PROFILE, 1)
	assert_eq(h.jelly_left(), 1)
	var applied: float = h.apply_impact(1000.0)
	assert_almost_eq(h.damage(), 0.95, 0.0001)
	assert_almost_eq(applied, 0.95, 0.0001)
	assert_false(h.is_broken())
	assert_eq(h.jelly_left(), 0)
	h.apply_impact(1000.0)          # jel bitti
	assert_true(h.is_broken())


func test_jelly_is_not_consumed_by_small_hits() -> void:
	var h: CargoHealth = CargoHealth.new(PROFILE, 1)
	h.apply_impact(7.0)
	h.apply_slosh(10.0, 0.5)
	assert_eq(h.jelly_left(), 1)
	assert_false(h.is_broken())


func test_two_jelly_charges_absorb_two_breaking_hits() -> void:
	var h: CargoHealth = CargoHealth.new(PROFILE, 2)
	h.apply_impact(1000.0)
	h.apply_impact(1000.0)
	assert_false(h.is_broken())
	assert_eq(h.jelly_left(), 0)
	assert_almost_eq(h.damage(), 0.95, 0.0001)
	h.apply_impact(1000.0)
	assert_true(h.is_broken())


func test_jelly_never_lowers_existing_damage() -> void:
	var h: CargoHealth = CargoHealth.new(PROFILE, 1)
	h.apply_fall(1.22)              # 0.97 (kırılmadı, jel kullanılmadı)
	assert_almost_eq(h.damage(), 0.97, 0.0001)
	assert_eq(h.jelly_left(), 1)
	var applied: float = h.apply_impact(1000.0)   # bu vuruş kırardı -> jel emer
	assert_almost_eq(h.damage(), 0.97, 0.0001)
	assert_almost_eq(applied, 0.0, 0.0001)
	assert_eq(h.jelly_left(), 0)
	assert_false(h.is_broken())


func test_negative_jelly_charges_are_treated_as_zero() -> void:
	var h: CargoHealth = CargoHealth.new(PROFILE, -3)
	assert_eq(h.jelly_left(), 0)
	h.apply_impact(1000.0)
	assert_true(h.is_broken())


func test_cargo_instances_do_not_share_state() -> void:
	var a: CargoHealth = CargoHealth.new(PROFILE)
	var b: CargoHealth = CargoHealth.new(PROFILE)
	a.apply_impact(15.0)
	assert_almost_eq(a.damage(), 0.5, 0.0001)
	assert_almost_eq(b.damage(), 0.0, 0.0001)


func test_repair_heals_fraction_of_damage() -> void:
	var health: CargoHealth = CargoHealth.new({"impact_threshold": 1.0, "impact_scale": 0.1, "mass": 1.0})
	health.apply_fall(0.0)
	health._damage = 0.6   # saf mantık testi: iç durumu doğrudan kuruyoruz
	var healed: float = health.repair(0.5)
	assert_almost_eq(healed, 0.3, 0.0001)
	assert_almost_eq(health.damage(), 0.3, 0.0001)


func test_repair_ignores_broken_and_bad_input() -> void:
	var health: CargoHealth = CargoHealth.new({})
	health._damage = 1.0
	assert_almost_eq(health.repair(0.5), 0.0, 0.0001)
	assert_true(health.is_broken())
	var other: CargoHealth = CargoHealth.new({})
	other._damage = 0.4
	assert_almost_eq(other.repair(-1.0), 0.0, 0.0001)
	assert_almost_eq(other.repair(NAN), 0.0, 0.0001)
	assert_almost_eq(other.repair(5.0), 0.4, 0.0001)
	assert_almost_eq(other.damage(), 0.0, 0.0001)
