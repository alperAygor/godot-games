extends TestCase
## Kabul kapısı: data/levels altındaki HER dosya yüklenir, geçerlidir, çözülebilir ve
## kayıtlı zorluk aralığındadır. Çözülemeyen seviye yayına giremez.

const EXPECTED_COUNT: int = 60
const TIME_BUDGET_MS: int = 1000

var content: PrizContent


func before_each() -> void:
	if content == null:
		content = PrizContent.load_default()


func test_sixty_levels_shipped() -> void:
	var files: PackedStringArray = PrizLevel.shipped_files()
	assert_eq(files.size(), EXPECTED_COUNT)
	for i: int in files.size():
		assert_eq(files[i], PrizLevel.shipped_path(i + 1))


func test_every_level_file_is_solvable_and_in_band() -> void:
	var solver: PrizSolver = PrizSolver.new()
	var files: PackedStringArray = PrizLevel.shipped_files()
	assert_true(files.size() > 0, "seviye dosyası yok")
	for path: String in files:
		var level: PrizLevel = PrizLevel.load_file(path)
		assert_not_null(level, "yüklenemedi: %s" % path)
		if level == null:
			continue
		var errors: PackedStringArray = level.validate(content.registry)
		assert_true(errors.is_empty(), "%s: %s" % [path, str(errors)])
		var t0: int = Time.get_ticks_msec()
		var res: PrizSolveResult = solver.count_solutions(level, content.registry, level.band_max + 1)
		var ms: int = Time.get_ticks_msec() - t0
		assert_false(res.node_limit_hit, "%s: düğüm sınırı" % path)
		assert_true(res.count > 0, "ÇÖZÜLEMEZ: %s" % path)
		assert_true(res.count >= level.band_min and res.count <= level.band_max,
				"%s: çözüm %d, aralık %d-%d" % [path, res.count, level.band_min, level.band_max])
		assert_true(ms < TIME_BUDGET_MS, "%s: %d ms" % [path, ms])
		# Kayıtlı çözüm sayısı bilgi alanıyla tutarlı.
		assert_eq(int(level.meta.get("solutions", -1)), res.count, path)


func test_level_metadata_rules() -> void:
	for path: String in PrizLevel.shipped_files():
		var level: PrizLevel = PrizLevel.load_file(path)
		var n: int = level.number
		assert_eq(level.id, "level_%03d" % n)
		assert_eq(level.mode, PrizLevel.MODE_FLAT if n <= 14 else PrizLevel.MODE_DAY, path)
		assert_eq(level.fuse_rights, 0 if n <= 14 else 3, path)
		assert_eq(level.is_hard(), n % 5 == 0, path)
		assert_true(level.lines.size() >= 2 and level.lines.size() <= 4, path)
		for e: String in level.elements:
			assert_true(content.registry.get_element(e).unlock_level <= n, "%s: %s erken" % [path, e])
		for element: PrizElement in content.registry.introduced_at(n):
			assert_true(level.elements.has(element.id), "%s: tanıtılan öğe yok" % path)
		if n <= 5:
			assert_eq(level.rooms.size(), 1, path)
