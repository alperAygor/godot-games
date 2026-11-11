extends TestCase

## SfxGate: aynı sesin 80 ms içinde tekrarını engelleyen saf mantık.
## Sözleşme: ARCHITECTURE.md §5.6 (`balance.audio.min_gap_ms`).

const GAP_MS: int = 80


func test_first_play_is_allowed() -> void:
	var gate: SfxGate = SfxGate.new()
	assert_true(gate.allow("impact_heavy", 1000, GAP_MS))


func test_same_sound_inside_gap_is_rejected() -> void:
	var gate: SfxGate = SfxGate.new()
	assert_true(gate.allow("impact_heavy", 1000, GAP_MS))
	assert_false(gate.allow("impact_heavy", 1000 + GAP_MS - 1, GAP_MS),
		"pencerenin içindeki ikinci çalma reddedilmeli")


func test_same_sound_at_gap_boundary_is_allowed() -> void:
	var gate: SfxGate = SfxGate.new()
	assert_true(gate.allow("impact_heavy", 1000, GAP_MS))
	assert_true(gate.allow("impact_heavy", 1000 + GAP_MS, GAP_MS),
		"tam 80 ms sonra çalınabilmeli")


func test_rejected_attempt_does_not_extend_window() -> void:
	var gate: SfxGate = SfxGate.new()
	assert_true(gate.allow("ui_tap", 1000, GAP_MS))
	assert_false(gate.allow("ui_tap", 1040, GAP_MS))
	assert_true(gate.allow("ui_tap", 1080, GAP_MS),
		"reddedilen deneme son kabul edilen zamanı değiştirmemeli")


func test_different_sounds_are_independent() -> void:
	var gate: SfxGate = SfxGate.new()
	assert_true(gate.allow("impact_light", 1000, GAP_MS))
	assert_true(gate.allow("impact_heavy", 1000, GAP_MS),
		"farklı sesler birbirini engellememeli")


func test_zero_gap_always_allows() -> void:
	var gate: SfxGate = SfxGate.new()
	assert_true(gate.allow("key_press", 500, 0))
	assert_true(gate.allow("key_press", 500, 0))


func test_empty_sound_and_negative_gap_are_safe() -> void:
	var gate: SfxGate = SfxGate.new()
	assert_false(gate.allow("", 1000, GAP_MS), "boş ses adı çalınmamalı")
	assert_true(gate.allow("boost", 1000, -50), "negatif boşluk 0 sayılmalı")


func test_reset_clears_history() -> void:
	var gate: SfxGate = SfxGate.new()
	assert_true(gate.allow("delivery", 1000, GAP_MS))
	gate.reset()
	assert_true(gate.allow("delivery", 1010, GAP_MS), "reset sonrası geçmiş temizlenmeli")
	assert_eq(gate.last_time("delivery"), 1010)
