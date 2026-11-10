extends TestCase

## ShakeSimulator: süre, şiddet sınırları, zarf eğrisi ve eve dönüş.

var _sim: ShakeSimulator = null
var _target: Node3D = null
var _finished: int = 0
var _step_count: int = 0


func before_each() -> void:
	_finished = 0
	_step_count = 0
	var holder: Node3D = Node3D.new()
	holder.name = "ShakeHolder"
	add_node(holder)

	_target = Node3D.new()
	_target.name = "Target"
	_target.position = Vector3(0.1, 0.2, 0.3)
	holder.add_child(_target)

	_sim = ShakeSimulator.new()
	_sim.name = "Sim"
	_sim.target_path = ^"../Target"
	_sim.duration = 5.0
	holder.add_child(_sim)
	_sim.shake_finished.connect(_on_finished)
	_sim.shake_step.connect(_on_step)


func after_each() -> void:
	if _sim != null and _sim.get_parent() != null:
		_sim.get_parent().free()
	_sim = null
	_target = null


func test_runs_for_duration_then_stops() -> void:
	_sim.start()
	var elapsed: float = _advance(6.0)
	assert_false(_sim.running, "5 sn sonunda durmalı")
	assert_eq(_finished, 1, "shake_finished tam bir kez")
	assert_greater(elapsed, 5.0)


func test_intensity_stays_in_range() -> void:
	_sim.start()
	var peak: float = 0.0
	var low: float = 1.0
	for i: int in 400:
		_sim._process(0.016)
		peak = maxf(peak, _sim.intensity)
		low = minf(low, _sim.intensity)
	assert_true(peak <= 1.0001, "şiddet 1'i aşmamalı")
	assert_true(low >= 0.0, "şiddet negatife düşmemeli")
	assert_greater(peak, 0.5, "sarsıntı gerçekten hissedilmeli")


func test_envelope_ramps_in_and_out() -> void:
	_sim.start()
	_sim._process(0.05)
	var early: float = _sim.intensity
	assert_true(early < 0.4, "rampa-in: ilk anlarda şiddet düşük olmalı")
	var guard: int = 0
	while _sim.progress_ratio() < 0.97 and guard < 400:
		_sim._process(0.016)
		guard += 1
	assert_true(_sim.intensity < 0.35, "rampa-out: son anlarda şiddet düşmeli")


func test_target_returns_to_rest_position() -> void:
	_sim.start()
	_advance(6.0)
	assert_true(_target.position.is_equal_approx(Vector3(0.1, 0.2, 0.3)), "hedef eski yerine dönmeli")
	assert_true(_target.rotation.is_equal_approx(Vector3.ZERO), "dönme sıfırlanmalı")


func test_stop_keeps_progress_and_resume_continues() -> void:
	_sim.start()
	for i: int in 60:
		_sim._process(0.016)
	var progress_before: float = _sim.progress_ratio()
	_sim.stop()
	assert_false(_sim.running)
	assert_almost_eq(_sim.progress_ratio(), progress_before, 0.001, "stop ilerlemeyi korumalı")
	assert_true(_target.position.is_equal_approx(Vector3(0.1, 0.2, 0.3)), "stop hedefi sıfırlamalı")
	_sim.resume()
	assert_true(_sim.running, "resume sarsıntıyı sürdürmeli")
	assert_almost_eq(_sim.progress_ratio(), progress_before, 0.001, "resume ilerlemeyi korumalı")


func test_restart_resets_progress() -> void:
	_sim.start()
	for i: int in 100:
		_sim._process(0.016)
	assert_greater(_sim.progress_ratio(), 0.0)
	_sim.stop()
	_sim.start()
	assert_almost_eq(_sim.progress_ratio(), 0.0, 0.001, "yeni başlangıç ilerlemeyi sıfırlar")


func _advance(seconds: float) -> float:
	var elapsed: float = 0.0
	while elapsed < seconds:
		_sim._process(0.016)
		elapsed += 0.016
	return elapsed


func _on_finished() -> void:
	_finished += 1


func _on_step(_intensity: float, _delta: float) -> void:
	_step_count += 1
