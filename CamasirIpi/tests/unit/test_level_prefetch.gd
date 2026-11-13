extends TestCase

## Arka plan üretimi (LevelPrefetch): iş parçacığında üretilen seviye eşzamanlı üretimle BİREBİR
## aynı olmalı; önbellek kopya döndürmeli (oyun değiştirse de asıl bozulmasın); tipli diziler
## korunmalı (DailyPuzzle `as Array[Dictionary]` ile okur).

## Erken, patron, ağır (55: ~1 sn) ve geniş tahta seviyeleri: paralel üretilir, test kısa kalır.
const LEVELS: Array[int] = [5, 23, 30, 55, 61]
const DAILY_DATE: String = "2026-03-14"
const DAILY_PLAYER_LEVEL: int = 34


func before_each() -> void:
	LevelPrefetch.drain()
	LevelPrefetch.enabled = true


func after_each() -> void:
	LevelPrefetch.drain()


func test_background_result_equals_sync() -> void:
	for level: int in LEVELS:
		LevelPrefetch.request_level(level)
	for level: int in LEVELS:
		var background: Dictionary = LevelPrefetch.take_level(level)
		assert_eq(background, LevelCache.level(level), "seviye %d: arka plan == eşzamanlı" % level)
		assert_true(background["items"] is Array[Dictionary], "seviye %d: items tipli kalmalı" % level)


func test_take_without_request_is_sync_and_cached_copy() -> void:
	var first: Dictionary = LevelPrefetch.take_level(7)
	assert_eq(first, LevelCache.level(7), "istenmemiş seviye eşzamanlı üretilir")
	(first["items"] as Array).clear()
	var second: Dictionary = LevelPrefetch.take_level(7)
	assert_eq(second, LevelCache.level(7), "önbellek kopya döndürür; dönen sözlüğü değiştirmek asılı bozmaz")


func test_disabled_runs_sync() -> void:
	LevelPrefetch.enabled = false
	LevelPrefetch.request_level(9)
	assert_false(LevelPrefetch.is_ready(LevelPrefetch.level_key(9)), "kapalıyken iş başlamaz")
	assert_eq(LevelPrefetch.take_level(9), LevelCache.level(9))
	LevelPrefetch.enabled = true


func test_cache_is_bounded() -> void:
	for level: int in range(1, LevelPrefetch.MAX_CACHED + 3):
		LevelPrefetch.take_level(level)
	assert_false(LevelPrefetch.is_ready(LevelPrefetch.level_key(1)), "en eski sonuç atılmalı")
	assert_true(LevelPrefetch.is_ready(LevelPrefetch.level_key(LevelPrefetch.MAX_CACHED + 2)), "en yeni kalmalı")


func test_daily_background_equals_sync() -> void:
	# Kurallar ana iş parçacığında bir kez okunur (statik önbellek yarışı olmasın).
	DailyPuzzle.rules()
	var key: String = "daily:%s:%d" % [DAILY_DATE, DAILY_PLAYER_LEVEL]
	var job: Callable = DailyPuzzle.build_level.bind(DAILY_DATE, DAILY_PLAYER_LEVEL)
	LevelPrefetch.request(key, job)
	var background: Dictionary = LevelPrefetch.take(key, job)
	assert_eq(background, DailyPuzzle.build_level(DAILY_DATE, DAILY_PLAYER_LEVEL), "günlük: arka plan == eşzamanlı")


func test_untaken_request_does_not_block_eviction() -> void:
	# Hiç alınmayan bir istek (tekrar oynanan seviyenin "sonraki"si gibi) önbelleği kilitlememeli.
	LevelPrefetch.request("orphan", func() -> Dictionary: return {"orphan": true})
	while not LevelPrefetch.is_ready("orphan"):
		OS.delay_msec(1)
	for index: int in range(LevelPrefetch.MAX_CACHED + 3):
		LevelPrefetch.take("key:%d" % index, func() -> Dictionary: return {"index": index})
	assert_true(LevelPrefetch._results.size() <= LevelPrefetch.MAX_CACHED, "önbellek sınırı aşılmamalı")
	assert_eq(LevelPrefetch._tasks.size(), 0, "biten görevler havuzdan bırakılmalı")
	assert_true(LevelPrefetch.is_ready("key:%d" % (LevelPrefetch.MAX_CACHED + 2)), "en yeni sonuç kalmalı")
