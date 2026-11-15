extends TestCase

## Hızlı oyun temposu (Motion) ve ses kapısı (SoundGate): saf parçalar.


func after_each() -> void:
	Motion.reset_pace()


func test_calm_interval_keeps_premium_pace() -> void:
	assert_almost_eq(Motion.pace_for_interval(Motion.PACE_CALM_MSEC), 1.0)
	assert_almost_eq(Motion.pace_for_interval(1500.0), 1.0, 0.001, "sakin oyuncu yavaşlamaz/hızlanmaz")


func test_fast_interval_reaches_max_and_is_monotonic() -> void:
	assert_almost_eq(Motion.pace_for_interval(Motion.PACE_FAST_MSEC), Motion.PACE_MAX)
	assert_almost_eq(Motion.pace_for_interval(0.0), Motion.PACE_MAX)
	var previous: float = 0.0
	for interval: float in [1000.0, 600.0, 450.0, 300.0, 200.0, 100.0]:
		var pace: float = Motion.pace_for_interval(interval)
		assert_true(pace >= previous, "aralık kısaldıkça tempo artar")
		previous = pace


func test_tracked_tween_follows_pace() -> void:
	var node: Node = Node.new()
	add_node(node)
	var tween: Tween = Motion.track(node.create_tween())
	tween.tween_interval(10.0)
	Motion.set_pace(2.5)
	assert_almost_eq(Motion.pace, 2.5, 0.001, "tempo kaydedildi")
	# 10 sn'lik bekleme 2.5 kat hızda: 4.1 sn'lik adım onu bitirir (hız çarpanı süren tween'e uygulandı).
	tween.custom_step(4.1)
	assert_false(tween.is_running(), "süren tween de hızlanır")
	tween = Motion.track(node.create_tween())
	tween.tween_interval(10.0)
	assert_eq(Motion.running_tracked(), 1)
	tween.kill()
	assert_eq(Motion.running_tracked(), 0, "öldürülen tween sayılmaz")


func test_sound_gate_drops_machine_gun_repeats() -> void:
	var gate: SoundGate = SoundGate.new()
	assert_eq(gate.admit("cloth", 1000), Vector2(1.0, 0.0), "ilk ses olduğu gibi")
	assert_eq(gate.admit("cloth", 1010), Vector2.ZERO, "çok yakın tekrar düşer")
	var second: Vector2 = gate.admit("cloth", 1100)
	assert_true(second.x > 1.0 and second.y < 0.0, "kısa aralıkta tekrar: perde adımı + hafif kısma")


func test_sound_gate_pitch_steps_are_capped_and_notes_exempt() -> void:
	var gate: SoundGate = SoundGate.new()
	var last: Vector2 = Vector2.ZERO
	for step: int in range(10):
		last = gate.admit("fold_puff", 1000 + step * 60)
	assert_almost_eq(last.x, 1.0 + SoundGate.PITCH_STEP * float(SoundGate.MAX_STEPS), 0.0001, "perde sınırlı")
	var notes: SoundGate = SoundGate.new()
	notes.admit("note", 0)
	assert_eq(notes.admit("note", 100).x, 1.0, "nota perdesi zincirden gelir, kapı değiştirmez")


func test_sound_gate_limits_total_voices() -> void:
	var gate: SoundGate = SoundGate.new()
	var admitted: int = 0
	for index: int in range(12):
		if gate.admit("s%d" % index, 500 + index) != Vector2.ZERO:
			admitted += 1
	assert_eq(admitted, SoundGate.MAX_PER_WINDOW, "havuz (6 oynatıcı) asla taşmaz")
	assert_true(gate.admit("late", 500 + SoundGate.WINDOW_MSEC + 20) != Vector2.ZERO, "pencere geçince yine çalar")
