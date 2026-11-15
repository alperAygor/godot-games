extends SceneTree
## Gün kipi kesit seviyeleri için rapor (başsız): her seviyenin ayrık çözüm sayısı, dilim başına toplam
## yük/kapasite ve "düz kipte olsaydı" çözülebilir mi (zamanın ek kapasite olduğunu gösterir).
##   godot --headless --path . -s res://tools/day_level_report.gd


func _initialize() -> void:
	var content: PrizContent = PrizContent.load_default()
	var solver: PrizSolver = PrizSolver.new()
	for path: String in DirAccess.get_files_at("res://data/levels_slice"):
		if not path.ends_with(".json"):
			continue
		var level: PrizLevel = PrizLevel.load_file("res://data/levels_slice/" + path)
		if not level.is_day_mode():
			continue
		var res: PrizSolveResult = solver.count_solutions(level, content.registry, 1000)
		var flat: PrizLevel = level.copy()
		flat.mode = PrizLevel.MODE_FLAT
		var flat_res: PrizSolveResult = solver.count_solutions(flat, content.registry, 1000)
		var cap: int = 0
		for line: PrizLine in level.lines:
			cap += line.capacity
		var per: Array[int] = [0, 0, 0, 0]
		for d: PrizDevice in level.devices:
			for s: int in PrizSlice.COUNT:
				if PrizSlice.has(d.slices, s):
					per[s] += d.blocks
		print("%s cihaz=%d çözüm=%d (düz kipte %d) dilim yükü=%s kapasite=%d" % [path, level.devices.size(), res.count,
			flat_res.count, str(per), cap])
	quit(0)
