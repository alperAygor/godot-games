extends SceneTree

## Performans ölçümü (gerçek pencere gerekir; headless render bilgisi vermez).
##
##   godot --path . --resolution 1080x1920 -s res://tools/perf_measure.gd -- --scene=res://scenes/Game.tscn --warmup=240 --sample=600
##
## Robotu tam gaz sürerken kare süresi (ort/p95/maks ms), çizim çağrısı, nesne ve
## üçgen sayısını yazar. Masaüstü sayıları Android'i kanıtlamaz; bütçe karşılaştırması
## ve gerilemeleri yakalamak içindir (hedef: <= 16.6 ms/kare, bkz. CLAUDE.md §8).

const FRAME_BUDGET_MS: float = 16.6

var _scene_path: String = "res://scenes/Game.tscn"
var _warmup: int = 240
var _sample: int = 600
var _count: int = 0
var _times: Array[float] = []
var _draw_calls: Array[float] = []
var _primitives: Array[float] = []
var _objects: Array[float] = []
var _last_us: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.split("=")[1]
		elif arg.begins_with("--warmup="):
			_warmup = int(arg.split("=")[1])
		elif arg.begins_with("--sample="):
			_sample = int(arg.split("=")[1])
	var packed: PackedScene = load(_scene_path) as PackedScene
	if packed == null:
		push_error("perf_measure: sahne yüklenemedi: %s" % _scene_path)
		quit(1)
		return
	root.add_child(packed.instantiate())
	_last_us = Time.get_ticks_usec()


func _process(_delta: float) -> bool:
	var robot: Node = get_first_node_in_group("robot")
	if robot != null and robot.has_method("set_move_input"):
		robot.call("set_move_input", Vector2(0.0, 1.0))
	var now: int = Time.get_ticks_usec()
	var frame_ms: float = float(now - _last_us) / 1000.0
	_last_us = now
	_count += 1
	if _count > _warmup:
		_times.append(frame_ms)
		_draw_calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		_primitives.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		_objects.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	if _times.size() >= _sample:
		_report()
		quit(0)
		return true
	return false


func _report() -> void:
	var sorted: Array[float] = _times.duplicate()
	sorted.sort()
	var p95: float = sorted[int(float(sorted.size()) * 0.95)]
	print("PERF kare_ms ort=%.2f p95=%.2f maks=%.2f bütçe=%.1f" % [_mean(_times), p95, sorted[sorted.size() - 1], FRAME_BUDGET_MS])
	print("PERF çizim_çağrısı ort=%.0f maks=%.0f" % [_mean(_draw_calls), _max(_draw_calls)])
	print("PERF üçgen ort=%.0f maks=%.0f" % [_mean(_primitives), _max(_primitives)])
	print("PERF nesne ort=%.0f maks=%.0f" % [_mean(_objects), _max(_objects)])


func _mean(values: Array[float]) -> float:
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / maxf(float(values.size()), 1.0)


func _max(values: Array[float]) -> float:
	var best: float = 0.0
	for v: float in values:
		best = maxf(best, v)
	return best
