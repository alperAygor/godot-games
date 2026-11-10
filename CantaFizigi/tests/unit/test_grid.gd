extends TestCase

## Izgara geometrisi ve doluluk: sınır taşması ve genişlemenin yer kaydırmaması.

const CELL: float = 0.075

var _grid: GridController = null


func before_each() -> void:
	_grid = GridController.new()
	var cells: Node3D = Node3D.new()
	cells.name = "Cells"
	_grid.add_child(cells)
	add_node(_grid)


func after_each() -> void:
	if _grid != null and _grid.get_parent() != null:
		_grid.free()
	_grid = null


func test_default_grid_is_4x5() -> void:
	assert_eq(_grid.cols, 4)
	assert_eq(_grid.rows, 5)


func test_footprint_cannot_overflow() -> void:
	assert_true(_grid._fits(Vector2i(0, 0), Vector2i(2, 2)), "köşeye 2x2 sığmalı")
	assert_false(_grid._fits(Vector2i(3, 0), Vector2i(2, 2)), "4 sütunda 2x2 taşmalı")
	assert_false(_grid._fits(Vector2i(0, 4), Vector2i(1, 2)), "son satırda 1x2 taşmalı")
	assert_true(_grid._fits(Vector2i(0, 3), Vector2i(1, 2)), "tam sığan 1x2 kabul edilmeli")


func test_place_occupies_whole_footprint() -> void:
	var iron: Package = _make_package(Vector2i(2, 2))
	assert_true(_grid._can_place(iron, Vector2i(2, 2)))
	_grid._place(iron, Vector2i(2, 2))
	assert_eq(_grid.placed_count(), 4, "2x2 paket 4 hücre kaplamalı")

	var small: Package = _make_package(Vector2i.ONE)
	assert_false(_grid._can_place(small, Vector2i(3, 3)), "dolu hücreye izin yok")
	assert_true(_grid._can_place(small, Vector2i(0, 0)), "boş hücreye izin var")


func test_expand_does_not_shift_existing_cells() -> void:
	var before_position: Vector3 = _grid._anchor_local(Vector2i(3, 4), Vector2i.ONE)
	assert_true(_grid.expand_to(5), "4 -> 5 genişleme kabul edilmeli")
	assert_eq(_grid.cols, 5)
	var after_position: Vector3 = _grid._anchor_local(Vector2i(3, 4), Vector2i.ONE)
	assert_true(before_position.is_equal_approx(after_position), "mevcut hücreler kaymamalı")
	assert_eq((_grid.get("_mat_by_cell") as Dictionary).size(), 25, "5x5 = 25 parıltı hücresi")


func test_expand_rejects_invalid_sizes() -> void:
	assert_false(_grid.expand_to(4), "aynı sütun sayısı reddedilmeli")
	assert_false(_grid.expand_to(99), "MAX_COLS üstü reddedilmeli")
	assert_eq(_grid.cols, 4)


func test_bonus_column_sits_outside_the_bag() -> void:
	_grid.expand_to(5)
	var first: Vector3 = _grid._cell_center_local(Vector2i(0, 0))
	var bonus: Vector3 = _grid._cell_center_local(Vector2i(4, 0))
	assert_greater(bonus.x, 0.15, "5. sütun çantanın sağ kenarının dışında olmalı")
	assert_almost_eq(bonus.x - first.x, 4.0 * CELL, 0.001, "sütunlar tam hücre aralıklı")


func test_placement_allowed_in_unlocked_column() -> void:
	_grid.expand_to(5)
	var pkg: Package = _make_package(Vector2i.ONE)
	assert_true(_grid._can_place(pkg, Vector2i(4, 0)), "yeni sütuna yerleştirme serbest olmalı")
	_grid._place(pkg, Vector2i(4, 0))
	assert_eq(_grid.placed_count(), 1)


func _make_package(footprint: Vector2i) -> Package:
	var pkg: Package = Package.new()
	pkg.footprint = footprint
	_grid.add_child(pkg)
	return pkg
