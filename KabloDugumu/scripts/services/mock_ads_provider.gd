class_name MockAdsProvider
extends AdsProvider

## Geliştirme sağlayıcısı: gerçek SDK yokken reklam akışını uçtan uca test eder.
## Süre dolunca ödüllü reklam "tamamlandı" sayılır. Bazen başarısız olur ki
## hata yolu da (reklam dolmadı) gerçekten çalışsın.

const SIMULATED_LENGTH: float = 1.2
const FAILURE_CHANCE: float = 0.08

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
	var timer: SceneTreeTimer = _tree.create_timer(SIMULATED_LENGTH, true, false, true)
	timer.timeout.connect(_finish)


func _finish() -> void:
	if _rng.randf() < FAILURE_CHANCE:
		failed.emit("no_fill")
		return
	rewarded.emit()
