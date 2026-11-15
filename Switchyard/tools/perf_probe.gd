extends SceneTree

## Genel başarım probu: Home ve Game sahnelerinde kare süresi (ort./p99/en kötü) ve Home <-> Game
## döngülerinde nesne/düğüm/yetim sızıntısı. Çıktı konsola yazılır (rapor dosyası yok).
##   godot --headless --path . -s res://tools/perf_probe.gd             (CPU/betik payı; çizim yok)
##   godot --path . -s res://tools/perf_probe.gd                         (pencere; çizim çağrısı dahil)
## Oyun gerçek mekaniğe kavuşunca oyuna özgü senaryolar (ağır seviye, kaydırma...) buraya eklenir.
## Oyuncunun kaydına ASLA yazmaz (persist=false).

const SAMPLE_FRAMES: int = 120
const CYCLES: int = 6
const SETTLE_FRAMES: int = 8

var _failed: bool = false


func _initialize() -> void:
	root.get_node("Progress").set("persist", false)
	AnalyticsLog.echo = false
	OnlineGate.enabled = false
	_run()


func _frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame


func _open(path: String) -> void:
	if current_scene != null:
		current_scene.free()
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene


func _sample(label: String) -> void:
	var times: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for _i: int in range(SAMPLE_FRAMES):
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
	times.sort()
	var total: float = 0.0
	for value: float in times:
		total += value
	print("PERF %s kare ms: ort=%.2f p99=%.2f en_kotu=%.2f düğüm=%d" % [label, total / float(times.size()),
		times[int(float(times.size()) * 0.99)], times[times.size() - 1],
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])


func _run() -> void:
	await process_frame
	root.get_node("Progress").call("reset_state")
	_open("res://scenes/Home.tscn")
	await _frames(SETTLE_FRAMES)
	await _sample("home")
	_open("res://scenes/Game.tscn")
	await _frames(SETTLE_FRAMES)
	await _sample("game")
	# Sızıntı: Home <-> Game döngüsünden sonra düğüm/nesne sayısı büyümemeli.
	_open("res://scenes/Home.tscn")
	await _frames(SETTLE_FRAMES)
	var nodes_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects_before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for _cycle: int in range(CYCLES):
		_open("res://scenes/Game.tscn")
		await _frames(SETTLE_FRAMES)
		_open("res://scenes/Home.tscn")
		await _frames(SETTLE_FRAMES)
	var nodes_after: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects_after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	print("PERF sızıntı %d döngü: düğüm %d->%d nesne %d->%d yetim=%d" % [CYCLES, nodes_before, nodes_after,
		objects_before, objects_after, orphans])
	if nodes_after > nodes_before + 5 or orphans > 0:
		_failed = true
		printerr("PROBE HATA: Home<->Game döngüsünde sızıntı")
	print("PROBE SONUC: %s" % ("kaldi" if _failed else "gecti"))
	quit(1 if _failed else 0)
