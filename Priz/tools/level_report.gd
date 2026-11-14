extends SceneTree
## Gönderilen seviyelerin raporu: kip, hat/cihaz/priz sayısı, öğeler, çözüm sayısı,
## çözücü düğümleri, zorluk etiketi ve doğrulama süresi.
##   godot --headless --path . -s res://tools/level_report.gd

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	quit(_run())
	return true


func _run() -> int:
	var content: PrizContent = PrizContent.load_default()
	var solver: PrizSolver = PrizSolver.new()
	var files: PackedStringArray = PrizLevel.shipped_files()
	print("| # | kip | hat | cihaz | priz (yuva) | zorluk | aralık | çözüm | düğüm | ms | öğeler |")
	print("|---|---|---|---|---|---|---|---|---|---|---|")
	var bad: int = 0
	var worst_ms: int = 0
	for path: String in files:
		var level: PrizLevel = PrizLevel.load_file(path)
		if level == null:
			print("| %s | YÜKLENEMEDİ |" % path.get_file())
			bad += 1
			continue
		var seats: int = 0
		for socket: PrizSocket in level.sockets:
			seats += socket.seats
		var t0: int = Time.get_ticks_usec()
		var res: PrizSolveResult = solver.count_solutions(level, content.registry, level.band_max + 1)
		var ms: int = int((Time.get_ticks_usec() - t0) / 1000.0)
		worst_ms = maxi(worst_ms, ms)
		var ok: bool = res.count >= level.band_min and res.count <= level.band_max \
				and not res.node_limit_hit
		if not ok:
			bad += 1
		var elems: Array[String] = []
		for e: String in level.elements:
			elems.append(e)
		print("| %d | %s | %d | %d | %d (%d) | %s | %d-%d | %d%s | %d%s | %d | %s |" % [
			level.number, level.mode, level.lines.size(), level.devices.size(),
			level.sockets.size(), seats, level.difficulty, level.band_min, level.band_max,
			res.count, "" if ok else " HATA", res.nodes, " SINIR" if res.node_limit_hit else "",
			ms, ", ".join(elems) if not elems.is_empty() else "-"])
	print("")
	print("%d seviye, en yavaş doğrulama %d ms, %d hatalı" % [files.size(), worst_ms, bad])
	print("SONUC: %s" % ("gecti" if bad == 0 and files.size() > 0 else "basarisiz"))
	return 0 if bad == 0 else 1
