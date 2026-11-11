extends TestCase

## CheckpointTracker: kontrol noktası kaydı ve yalnız ileri ilerleme. Sözleşme: ARCHITECTURE.md §4.6.
## Sınıf henüz YOK — testler sözleşmeden türetildi (kırmızı aşama).
##
## Varsayımlar (sözleşmede açık değil):
## - Başlangıçta last_id() == -1 (henüz hiçbir nokta geçilmedi).
## - reach(id) YALNIZCA id > last_id() ise ilerler; kayıt şartı yoktur.
## - last_position() geçilen son id'nin KAYITLI konumudur; kayıt yoksa Vector3.ZERO.
## - reset() ilerlemeyi başa alır (kayıtların korunup korunmadığı test edilmez).


func test_new_tracker_has_no_progress() -> void:
	var t: CheckpointTracker = CheckpointTracker.new()
	assert_eq(t.last_id(), -1)
	assert_eq(t.last_position(), Vector3.ZERO)


func test_register_then_reach_advances_forward() -> void:
	var t: CheckpointTracker = CheckpointTracker.new()
	t.register(0, Vector3(0, 0, 0))
	t.register(1, Vector3(1, 2, 3))
	assert_true(t.reach(0))
	assert_eq(t.last_id(), 0)
	assert_eq(t.last_position(), Vector3(0, 0, 0))
	assert_true(t.reach(1))
	assert_eq(t.last_id(), 1)
	assert_eq(t.last_position(), Vector3(1, 2, 3))


func test_reach_backward_or_same_is_ignored() -> void:
	var t: CheckpointTracker = CheckpointTracker.new()
	t.register(0, Vector3(0, 0, 0))
	t.register(1, Vector3(1, 0, 0))
	t.register(2, Vector3(2, 0, 0))
	t.reach(0)
	t.reach(1)
	assert_false(t.reach(0), "geriye gidis sayilmamali")
	assert_false(t.reach(1), "ayni nokta ilerleme degil")
	assert_eq(t.last_id(), 1)
	assert_eq(t.last_position(), Vector3(1, 0, 0))


func test_reach_forward_skips_are_allowed() -> void:
	var t: CheckpointTracker = CheckpointTracker.new()
	t.register(0, Vector3.ZERO)
	t.register(3, Vector3(3, 0, 0))
	t.reach(0)
	assert_true(t.reach(3), "ileri yonde atlama ilerlemedir")
	assert_eq(t.last_id(), 3)
	assert_eq(t.last_position(), Vector3(3, 0, 0))


func test_unregistered_last_position_is_zero() -> void:
	var t: CheckpointTracker = CheckpointTracker.new()
	t.register(0, Vector3(1, 1, 1))
	t.reach(0)
	# 1 kayıtlı değil; reach yalnız ileri ilerlemeyi önemser, konum kayıtsız kalır
	assert_true(t.reach(1))
	assert_eq(t.last_id(), 1)
	assert_eq(t.last_position(), Vector3.ZERO)


func test_reset_clears_progress() -> void:
	var t: CheckpointTracker = CheckpointTracker.new()
	t.register(0, Vector3(0, 0, 0))
	t.register(1, Vector3(1, 0, 0))
	t.reach(0)
	t.reach(1)
	assert_eq(t.last_id(), 1)
	t.reset()
	assert_eq(t.last_id(), -1)
	assert_eq(t.last_position(), Vector3.ZERO)


func test_instances_do_not_share_state() -> void:
	var a: CheckpointTracker = CheckpointTracker.new()
	var b: CheckpointTracker = CheckpointTracker.new()
	a.register(0, Vector3.ZERO)
	a.reach(0)
	assert_eq(a.last_id(), 0)
	assert_eq(b.last_id(), -1)
