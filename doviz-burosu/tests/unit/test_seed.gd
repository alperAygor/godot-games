extends "res://tests/test_case.gd"
## Seed: FNV-1a ve tohumlu RNG deterministik olmalı (Günün Kuru buna dayanır).


func test_fnv1a_known_vectors() -> void:
	# Yayınlanmış 32 bit FNV-1a test vektörleri.
	assert_eq(Seed.fnv1a(""), 0x811C9DC5)
	assert_eq(Seed.fnv1a("a"), 0xE40C292C)
	assert_eq(Seed.fnv1a("foobar"), 0xBF9CF968)


func test_fnv1a_utf8_and_range() -> void:
	var value := Seed.fnv1a("Döviz Bürosu ş ğ İ")
	assert_true(value >= 0 and value <= 0xFFFFFFFF)
	assert_eq(Seed.fnv1a("Döviz Bürosu ş ğ İ"), value)
	assert_ne(Seed.fnv1a("daily-2026-10-26"), Seed.fnv1a("daily-2026-10-27"))


func test_rng_same_key_same_sequence() -> void:
	var a := Seed.rng("rate|FED|3")
	var b := Seed.rng("rate|FED|3")
	for i in 20:
		assert_eq(a.randi(), b.randi())


func test_rng_different_keys_differ() -> void:
	var a := Seed.rng("rate|FED|3")
	var b := Seed.rng("rate|FED|4")
	var same := true
	for i in 10:
		if a.randi() != b.randi():
			same = false
	assert_false(same)


func test_pick_and_chance() -> void:
	var generator := Seed.rng("pick")
	assert_eq(Seed.pick(generator, []), null)
	var seen := {}
	for i in 100:
		seen[Seed.pick(generator, ["a", "b", "c"])] = true
	assert_eq(seen.size(), 3)
	assert_true(Seed.chance(generator, 100))
	assert_false(Seed.chance(generator, 0))
