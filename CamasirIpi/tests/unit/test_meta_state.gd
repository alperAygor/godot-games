extends TestCase

## MetaState: tadilat sırası, varyant seçimi, mekân tamamlama jetonu, koleksiyon hesapları
## ve bozuk kayıt toleransı. Küçük, elle kurulmuş katalogla çalışır (veri dosyası değişse
## de kurallar sınansın); gerçek veri dosyaları ayrıca biçim açısından sınanır.

var _catalog: MetaCatalog = null


func before_each() -> void:
	_catalog = MetaCatalog.from_dicts({
		"variants_per_task": 3,
		"locations": [
			{"id": "a", "art": true, "completion_coins": 300, "tasks": [
				{"id": "floor", "cost": 1}, {"id": "wall", "cost": 2}, {"id": "lamp", "cost": 3.0}]},
			{"id": "b", "completion_coins": 400, "tasks": [{"id": "floor", "cost": 2}]},
		],
	}, {
		"levels_per_piece": 10,
		"sets": [
			{"id": "s1", "reward": "pin_x", "pieces": [{"kind": "towel"}, {"kind": "sock"}]},
			{"id": "s2", "reward": "rope_y", "pieces": [{"kind": "dress"}, {"kind": "tshirt"}, {"kind": "pants"}]},
		],
	})


func test_tasks_follow_fixed_order() -> void:
	var state: MetaState = MetaState.new()
	assert_eq(state.next_task(_catalog), 0)
	assert_eq(state.next_cost(_catalog), 1)
	assert_eq(state.complete_next(_catalog), 0)
	assert_eq(state.next_task(_catalog), 1)
	assert_eq(state.next_cost(_catalog), 2)
	assert_true(state.is_task_done(_catalog, 0, 0))
	assert_false(state.is_task_done(_catalog, 0, 1))


func test_float_cost_from_json_is_int() -> void:
	var state: MetaState = MetaState.new()
	state.complete_next(_catalog)
	state.complete_next(_catalog)
	assert_eq(state.next_cost(_catalog), 3, "3.0 -> 3")


func test_affordability() -> void:
	var state: MetaState = MetaState.new()
	assert_false(state.can_afford_next(_catalog, 0))
	assert_true(state.can_afford_next(_catalog, 1))


func test_variant_choice_saved_and_changeable_only_when_done() -> void:
	var state: MetaState = MetaState.new()
	assert_eq(state.variant(_catalog, 0, 0), -1, "bitmemiş görev eski görünür")
	assert_false(state.set_variant(_catalog, 0, 0, 1), "bitmemiş görevin varyantı değişmez")
	state.complete_next(_catalog, 0)
	assert_eq(state.variant(_catalog, 0, 0), 0)
	assert_true(state.set_variant(_catalog, 0, 0, 2))
	assert_eq(state.variant(_catalog, 0, 0), 2)
	assert_false(state.set_variant(_catalog, 0, 0, 3), "aralık dışı varyant reddedilir")
	assert_false(state.set_variant(_catalog, 0, 0, -1))
	assert_eq(state.variant(_catalog, 0, 0), 2)


func test_location_completion_pays_bonus_once_and_advances() -> void:
	var state: MetaState = MetaState.new()
	for _i: int in range(3):
		assert_eq(state.pending_bonus(_catalog), 0)
		state.complete_next(_catalog)
	assert_true(state.is_location_complete(_catalog, 0))
	assert_eq(state.next_task(_catalog), -1)
	assert_eq(state.pending_bonus(_catalog), 300)
	assert_eq(state.claim_bonus(_catalog), 300)
	assert_eq(state.current_location(_catalog), 1, "sıradaki mekân açılır")
	assert_true(state.is_location_unlocked(_catalog, 1))
	assert_eq(state.claim_bonus(_catalog), 0, "ikinci kez ödenmez")
	assert_eq(state.next_task(_catalog), 0, "yeni mekânın ilk görevi")
	assert_eq(state.next_cost(_catalog), 2)


func test_last_location_stays_after_completion() -> void:
	var state: MetaState = MetaState.new()
	for _i: int in range(3):
		state.complete_next(_catalog)
	state.claim_bonus(_catalog)
	state.complete_next(_catalog)
	assert_eq(state.claim_bonus(_catalog), 400)
	assert_eq(state.current_location(_catalog), 1, "son mekânda kalınır")
	assert_eq(state.next_task(_catalog), -1)
	assert_eq(state.complete_next(_catalog), -1)


func test_round_trip() -> void:
	var state: MetaState = MetaState.new()
	state.complete_next(_catalog, 0)
	state.complete_next(_catalog, 0)
	state.set_variant(_catalog, 0, 1, 2)
	state.pieces_seen = 3
	state.cosmetics.append("pin_x")
	var copy: MetaState = MetaState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(copy.done_count(_catalog, 0), 2)
	assert_eq(copy.variant(_catalog, 0, 1), 2)
	assert_eq(copy.pieces_seen, 3)
	assert_eq(copy.cosmetics, ["pin_x"] as Array[String])


func test_from_dict_tolerates_bad_data() -> void:
	assert_eq(MetaState.from_dict(null).location, 0)
	assert_eq(MetaState.from_dict("bozuk").location, 0)
	var state: MetaState = MetaState.from_dict({
		"location": "x", "done": {"a": 2.0, "b": "çok"}, "variants": [1, 2],
		"bonus_paid": "a", "pieces_seen": -5.0, "cosmetics": [1, "pin_x", "", "pin_x"],
	})
	assert_eq(state.location, 0)
	assert_eq(state.done_count(_catalog, 0), 2, "float sayı kabul edilir")
	assert_eq(state.done_count(_catalog, 1), 0, "bozuk sayı 0 olur")
	assert_true(state.variants.is_empty())
	assert_true(state.bonus_paid.is_empty())
	assert_eq(state.pieces_seen, 0, "eksi sayı 0'a sıkışır")
	assert_eq(state.cosmetics, ["pin_x"] as Array[String], "tekrar/boş/sayı ayıklanır")


func test_out_of_range_saved_values_are_clamped() -> void:
	var state: MetaState = MetaState.from_dict({"location": 99.0, "done": {"a": 1e9},
		"variants": {"a/floor": 7.0}})
	assert_eq(state.current_location(_catalog), 1)
	assert_eq(state.done_count(_catalog, 0), 3)
	assert_eq(state.variant(_catalog, 0, 0), 2)


func test_pieces_earned_from_level() -> void:
	# level = sıradaki seviye; bitirilen = level - 1.
	assert_eq(MetaState.pieces_earned(1, 10, 24), 0)
	assert_eq(MetaState.pieces_earned(10, 10, 24), 0)
	assert_eq(MetaState.pieces_earned(11, 10, 24), 1)
	assert_eq(MetaState.pieces_earned(35, 10, 24), 3)
	assert_eq(MetaState.pieces_earned(9999, 10, 24), 24, "toplamla sınırlı")
	assert_eq(MetaState.pieces_earned(-3, 10, 24), 0)
	assert_eq(MetaState.pieces_earned(50, 0, 24), 24, "bozuk adım 1'e düşer")


func test_levels_to_next_piece() -> void:
	assert_eq(MetaState.levels_to_next_piece(1, 10, 24), 10)
	assert_eq(MetaState.levels_to_next_piece(11, 10, 24), 10)
	assert_eq(MetaState.levels_to_next_piece(18, 10, 24), 3)
	assert_eq(MetaState.levels_to_next_piece(241, 10, 24), 0, "hepsi alındı")
	assert_almost_eq(MetaState.next_piece_progress(16, 10, 24), 0.5)


func test_set_ownership_fills_sets_in_order() -> void:
	var sizes: Array[int] = [2, 3]
	assert_eq(MetaState.set_owned(1, sizes, 0), 1)
	assert_eq(MetaState.set_owned(1, sizes, 1), 0)
	assert_eq(MetaState.set_owned(4, sizes, 0), 2)
	assert_eq(MetaState.set_owned(4, sizes, 1), 2)
	assert_true(MetaState.piece_owned(4, sizes, 1, 1))
	assert_false(MetaState.piece_owned(4, sizes, 1, 2))
	assert_eq(MetaState.set_owned(4, sizes, 5), 0, "geçersiz set")


func test_set_completion_unlocks_cosmetic_once() -> void:
	var state: MetaState = MetaState.new()
	assert_eq(state.unseen_pieces(_catalog, 21), 2)
	var first: Array[String] = state.sync_collection(_catalog, 21)
	assert_eq(first, ["pin_x"] as Array[String])
	assert_eq(state.unseen_pieces(_catalog, 21), 0)
	assert_eq(state.sync_collection(_catalog, 21).size(), 0, "tekrar açılmaz")
	assert_eq(state.sync_collection(_catalog, 51), ["rope_y"] as Array[String])
	assert_true(state.has_cosmetic("pin_x") and state.has_cosmetic("rope_y"))


func test_real_data_files_are_consistent() -> void:
	var catalog: MetaCatalog = MetaCatalog.load_default()
	assert_eq(catalog.location_count(), 4)
	assert_true(catalog.location_has_art(0))
	assert_false(catalog.location_has_art(1))
	assert_eq(catalog.task_count(0), 12)
	for task: int in range(catalog.task_count(0)):
		var cost: int = catalog.task_cost(0, task)
		assert_true(cost >= 1 and cost <= 3, "görev bedeli 1-3 yıldız")
		assert_eq(catalog.task_swatches(0, task).size(), catalog.variants_per_task, "her varyantın rengi var")
		assert_true(catalog.draw_order.has(catalog.task_id(0, task)), "görevin katmanı çizim sırasında")
	assert_eq(catalog.set_count(), 6)
	for index: int in range(catalog.set_count()):
		assert_eq(catalog.set_pieces(index).size(), 4, "set 4 parça")
		assert_false(catalog.set_reward(index).is_empty())
	assert_eq(catalog.levels_per_piece, 10)
