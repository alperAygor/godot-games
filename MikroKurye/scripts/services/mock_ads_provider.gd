class_name MockAdsProvider
extends AdsProvider

## Geliştirme sağlayıcısı: gerçek SDK yokken reklam akışını uçtan uca test eder.
## Süre dolunca ödüllü reklam "tamamlandı" sayılır. Bazen başarısız olur ki
## hata yolu da (reklam dolmadı) gerçekten çalışsın.

const SIMULATED_LENGTH: float = 1.2
const FAILURE_CHANCE: float = 0.08

## Probe/test kancaları (§5.5): instant gecikmeyi kaldırır, force_result -1 ise
## rastgele davranış korunur; 0 "no_fill", 1 "rewarded" üretir.
const FORCE_RANDOM: int = -1
const FORCE_FAILED: int = 0
const FORCE_REWARDED: int = 1

var instant: bool = false
var force_result: int = FORCE_RANDOM

var _tree: SceneTree = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func initialize() -> void:
	_tree = Engine.get_main_loop() as SceneTree
	_rng.seed = 20261110


func is_ready(_placement: int) -> bool:
	return true


func show(_placement: int) -> void:
	shown.emit()
	if _tree == null:
		failed.emit("no_scene_tree")
		return
	# process_always = true: sahne duraklatılmış olsa da reklam akışı ilerlesin.
	# instant modunda 0 sn'lik zamanlayıcı bir sonraki karede biter; probe beklemez.
	var length: float = 0.0 if instant else SIMULATED_LENGTH
	var timer: SceneTreeTimer = _tree.create_timer(length, true, false, true)
	timer.timeout.connect(_finish)


func _finish() -> void:
	if force_result == FORCE_FAILED:
		failed.emit("no_fill")
		return
	if force_result == FORCE_REWARDED:
		rewarded.emit()
		return
	if _rng.randf() < FAILURE_CHANCE:
		failed.emit("no_fill")
		return
	rewarded.emit()
