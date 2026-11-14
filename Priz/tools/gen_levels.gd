extends SceneTree
## Gönderilecek seviyeleri üretir ve data/levels/level_NNN.json olarak yazar.
##   godot --headless --path . -s res://tools/gen_levels.gd
##   godot --headless --path . -s res://tools/gen_levels.gd -- --count=60 --from=1
## Her seviye yazılmadan önce çözücüyle doğrulanır; doğrulanamayan seviye yazılmaz.

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	quit(_run())
	return true


func _run() -> int:
	var count: int = 60
	var first: int = 1
	var out_dir: String = PrizLevel.LEVELS_DIR
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			count = int(arg.split("=")[1])
		elif arg.begins_with("--from="):
			first = int(arg.split("=")[1])
		elif arg.begins_with("--out="):
			out_dir = arg.split("=")[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var content: PrizContent = PrizContent.load_default()
	if not content.registry.errors.is_empty():
		for e: String in content.registry.errors:
			print("ÖĞE HATASI: %s" % e)
		print("SONUC: basarisiz")
		return 1
	var generator: PrizGenerator = PrizGenerator.new(content)
	var solver: PrizSolver = PrizSolver.new()
	var failed: int = 0
	var started: int = Time.get_ticks_msec()
	for n: int in range(first, first + count):
		var t0: int = Time.get_ticks_msec()
		var level: PrizLevel = generator.generate(n)
		if level == null:
			print("URETILEMEDI  %d" % n)
			failed += 1
			continue
		var res: PrizSolveResult = solver.count_solutions(level, content.registry, level.band_max + 1)
		if res.count < level.band_min or res.count > level.band_max or res.node_limit_hit:
			print("DOGRULANAMADI %d (çözüm %d)" % [n, res.count])
			failed += 1
			continue
		var path: String = out_dir.path_join("level_%03d.json" % n)
		if not level.save_file(path):
			print("YAZILAMADI %s" % path)
			failed += 1
			continue
		print("seviye %3d  %-6s %-4s çözüm %3d  deneme %3d  %4d ms  %s" % [n, level.difficulty,
				level.mode, res.count, generator.last_attempts, Time.get_ticks_msec() - t0,
				",".join(level.elements)])
	print("toplam %d ms" % (Time.get_ticks_msec() - started))
	print("SONUC: %s" % ("gecti" if failed == 0 else "basarisiz"))
	return 0 if failed == 0 else 1
