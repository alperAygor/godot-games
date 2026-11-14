extends TestCase

## PlaceholderRun: yer tutucu tur mantığı (kazan / kaybet / devam). Gerçek oyunda kendi kural
## sınıfının testi bu dosyanın yerini alır; test kalıbı aynı kalır.

func test_wins_after_target_taps() -> void:
	var run: PlaceholderRun = PlaceholderRun.new(3)
	assert_true(run.is_playing())
	run.tap()
	run.tap()
	assert_eq(run.remaining(), 1)
	assert_false(run.is_won())
	run.tap()
	assert_true(run.is_won())
	assert_eq(run.remaining(), 0)


func test_taps_after_the_end_are_ignored() -> void:
	var run: PlaceholderRun = PlaceholderRun.new(1)
	assert_true(run.tap())
	assert_false(run.tap(), "kazanılmış turda dokunuş işlenmez")
	assert_eq(run.taps, 1)


func test_lose_then_revive_keeps_progress() -> void:
	var run: PlaceholderRun = PlaceholderRun.new(4)
	run.tap()
	run.lose()
	assert_true(run.is_lost())
	assert_false(run.tap(), "kayıpta dokunuş işlenmez")
	assert_true(run.revive())
	assert_true(run.is_playing())
	assert_eq(run.taps, 1, "devam ilerlemeyi korur")


func test_cannot_revive_when_not_lost_and_cannot_lose_after_win() -> void:
	var run: PlaceholderRun = PlaceholderRun.new(1)
	assert_false(run.revive())
	run.tap()
	run.lose()
	assert_true(run.is_won(), "kazanılmış tur kaybedilemez")


func test_target_is_at_least_one() -> void:
	assert_eq(PlaceholderRun.new(0).target, 1)
