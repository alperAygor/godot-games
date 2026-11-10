extends TestCase

## Cam kırılması ve buz erimesi — bu oturumda bulunan iki hatanın koruma testleri.

var _break_count: int = 0
var _melt_count: int = 0


func before_each() -> void:
	_break_count = 0
	_melt_count = 0


func after_each() -> void:
	for node: Node in tree.root.get_children():
		if node is PackagePhysics:
			node.free()


func test_glass_survives_below_threshold() -> void:
	var pkg: PackagePhysics = _make(PackagePhysics.Kind.GLASS, 1.0)
	pkg.apply_shake(0.5, 0.5)  # stres = 0.5 * 1.0 * 0.5 = 0.25
	assert_false(pkg.is_broken, "eşiğin altında kırılmamalı")
	assert_almost_eq(pkg.stress, 0.25, 0.001)
	assert_eq(_break_count, 0)


func test_glass_breaks_when_threshold_reached() -> void:
	var pkg: PackagePhysics = _make(PackagePhysics.Kind.GLASS, 1.0)
	for i: int in 40:
		if pkg.is_broken:
			break
		pkg.apply_shake(1.0, 0.1)
	assert_true(pkg.is_broken, "eşik aşılınca kırılmalı")
	assert_eq(_break_count, 1, "kırılma sinyali tam bir kez")


func test_broken_glass_accepts_no_further_stress() -> void:
	var pkg: PackagePhysics = _make(PackagePhysics.Kind.GLASS, 1.0)
	for i: int in 40:
		if pkg.is_broken:
			break
		pkg.apply_shake(1.0, 0.1)
	var frozen: float = pkg.stress
	pkg.apply_shake(1.0, 5.0)
	assert_almost_eq(pkg.stress, frozen, 0.0001, "kırıldıktan sonra stres artmamalı")
	assert_eq(_break_count, 1)


func test_ice_melts_over_time() -> void:
	var pkg: PackagePhysics = _make(PackagePhysics.Kind.ICE, 1.0, 1.0)
	pkg.apply_shake(0.0, 0.5)  # hız = (0.5 + 0) / 1.0 -> 0.5 erime
	assert_almost_eq(pkg.melt, 0.5, 0.001)
	assert_false(pkg.is_melted, "yarı yolda erimemiş olmalı")
	pkg.apply_shake(0.0, 0.5)
	assert_true(pkg.is_melted, "süre dolunca erimeli")
	assert_eq(_melt_count, 1)


func test_shake_speeds_up_melting() -> void:
	var slow: PackagePhysics = _make(PackagePhysics.Kind.ICE, 1.0, 1.0)
	var fast: PackagePhysics = _make(PackagePhysics.Kind.ICE, 1.0, 1.0)
	slow.apply_shake(0.0, 0.2)
	fast.apply_shake(1.0, 0.2)
	assert_greater(fast.melt, slow.melt, "sarsıntı erimeyi hızlandırmalı")


func test_neighbour_stress_can_break_glass() -> void:
	var pkg: PackagePhysics = _make(PackagePhysics.Kind.GLASS, 1.0)
	pkg.add_stress(1.5)
	assert_true(pkg.is_broken, "komşu kaynaklı stres eşiği aşınca kırılmalı")


func test_iron_and_standard_never_break() -> void:
	var iron: PackagePhysics = _make(PackagePhysics.Kind.IRON, 1.0)
	var std: PackagePhysics = _make(PackagePhysics.Kind.STANDARD, 1.0)
	for i: int in 200:
		iron.apply_shake(1.0, 0.1)
		std.apply_shake(1.0, 0.1)
	assert_false(iron.is_broken)
	assert_false(std.is_broken)
	assert_eq(_break_count, 0)


func test_repair_restores_broken_glass() -> void:
	var pkg: PackagePhysics = _make(PackagePhysics.Kind.GLASS, 1.0)
	pkg.add_stress(2.0)
	assert_true(pkg.is_broken)
	pkg.repair()
	assert_false(pkg.is_broken)
	assert_almost_eq(pkg.stress, 0.0, 0.0001)
	assert_true(pkg.visible, "onarım sonrası görünür olmalı")


func _make(kind: PackagePhysics.Kind, threshold: float, melt: float = 3.0) -> PackagePhysics:
	var pkg: PackagePhysics = PackagePhysics.new()
	pkg.use_data_tuning = false
	pkg.kind = kind
	pkg.break_threshold = threshold
	pkg.fragility = 1.0
	pkg.melt_seconds = melt
	pkg.broken.connect(_on_broken)
	pkg.melted.connect(_on_melted)
	add_node(pkg)
	return pkg


func _on_broken(_package: PackagePhysics) -> void:
	_break_count += 1


func _on_melted(_package: PackagePhysics) -> void:
	_melt_count += 1
