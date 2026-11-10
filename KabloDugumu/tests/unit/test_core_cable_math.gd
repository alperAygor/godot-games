extends TestCase

## CableMath: 3D segment/polyline mesafesi, uzunluk ve esit yay orneklemesi.
## Referans degerler elle hesaplanmis geometrilerdir.


func test_segment_distance_crossing_segments_is_zero() -> void:
	var distance: float = CableMath.segment_distance(
		Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0),
		Vector3(0.0, -1.0, 0.0), Vector3(0.0, 1.0, 0.0))
	assert_almost_eq(distance, 0.0, 0.0001, "kesisen segmentler temas eder")


func test_segment_distance_parallel_segments_keeps_offset() -> void:
	var distance: float = CableMath.segment_distance(
		Vector3(0.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0),
		Vector3(0.0, 1.0, 0.0), Vector3(2.0, 1.0, 0.0))
	assert_almost_eq(distance, 1.0, 0.0001, "paralel segmentler 1 m uzak")


func test_segment_distance_skew_segments_keeps_gap() -> void:
	var distance: float = CableMath.segment_distance(
		Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0),
		Vector3(0.0, -1.0, 2.0), Vector3(0.0, 1.0, 2.0))
	assert_almost_eq(distance, 2.0, 0.0001, "aykiri segmentler arasi z farki")


func test_segment_distance_endpoint_to_segment() -> void:
	var distance: float = CableMath.segment_distance(
		Vector3(0.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0),
		Vector3(3.0, 1.0, 0.0), Vector3(3.0, 1.0, 0.0))
	assert_almost_eq(distance, sqrt(2.0), 0.0001, "nokta icin en yakin uca olan uzaklik")


func test_segment_distance_degenerate_points() -> void:
	var distance: float = CableMath.segment_distance(
		Vector3(1.0, 2.0, 3.0), Vector3(1.0, 2.0, 3.0),
		Vector3(4.0, 2.0, 3.0), Vector3(4.0, 2.0, 3.0))
	assert_almost_eq(distance, 3.0, 0.0001, "iki nokta arasi")


func test_segment_distance_is_finite_and_within_segment_hulls() -> void:
	var a0: Vector3 = Vector3(-0.6, 1.18, 0.055)
	var a1: Vector3 = Vector3(-0.3, 0.2, 0.055)
	var b0: Vector3 = Vector3(0.1, -0.4, 0.055)
	var b1: Vector3 = Vector3(0.5, 0.9, 0.055)
	var distance: float = CableMath.segment_distance(a0, a1, b0, b1)
	assert_true(is_finite(distance), "mesafe sonlu olmali")
	assert_greater(distance, -0.0001, "mesafe negatif olmamali")


func test_polyline_distance_identical_is_zero() -> void:
	var points: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.4, 2.0, 0.0)])
	assert_almost_eq(CableMath.polyline_distance(points, points.duplicate()), 0.0, 0.0001)


func test_polyline_distance_parallel_flat_lines() -> void:
	var a: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)])
	var b: PackedVector3Array = PackedVector3Array([
		Vector3(0.3, 0.0, 0.0), Vector3(0.3, 1.0, 0.0)])
	assert_almost_eq(CableMath.polyline_distance(a, b), 0.3, 0.0001)


func test_polyline_distance_needs_two_points() -> void:
	var single: PackedVector3Array = PackedVector3Array([Vector3.ZERO])
	var line: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3(0.0, 1.0, 0.0)])
	assert_true(is_inf(CableMath.polyline_distance(single, line)), "tek noktali polyline sinirsiz")
	assert_true(is_inf(CableMath.polyline_distance(PackedVector3Array(), line)))


func test_polyline_length_sums_segments() -> void:
	var points: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0), Vector3(3.0, 0.0, 0.0), Vector3(3.0, 4.0, 0.0)])
	assert_almost_eq(CableMath.polyline_length(points), 7.0, 0.0001)
	assert_almost_eq(CableMath.polyline_length(PackedVector3Array()), 0.0, 0.0001)


func test_resample_keeps_count_and_endpoints() -> void:
	var points: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0), Vector3(0.0, 2.0, 0.0), Vector3(1.5, 2.0, 0.0)])
	var resampled: PackedVector3Array = CableMath.resample(points, 9)
	assert_eq(resampled.size(), 9, "nokta sayisi tam olmali")
	assert_true(resampled[0].is_equal_approx(points[0]), "ilk uc korunur")
	assert_true(resampled[resampled.size() - 1].is_equal_approx(points[points.size() - 1]),
		"son uc korunur")


func test_resample_straight_line_is_evenly_spaced() -> void:
	var points: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0)])
	var resampled: PackedVector3Array = CableMath.resample(points, 5)
	assert_eq(resampled.size(), 5)
	for i: int in resampled.size():
		assert_almost_eq(resampled[i].x, 0.5 * float(i), 0.0001,
			"duz cizgide esit aralik (i=%d)" % i)


func test_resample_handles_zero_one_and_degenerate() -> void:
	var points: PackedVector3Array = PackedVector3Array([Vector3.ONE, Vector3.ONE])
	assert_eq(CableMath.resample(points, 0).size(), 0, "sifir adet istendiginde bos")
	assert_eq(CableMath.resample(points, 1).size(), 1, "tek nokta")
	var repeated: PackedVector3Array = PackedVector3Array([Vector3.ONE, Vector3.ONE, Vector3.ONE])
	var result: PackedVector3Array = CableMath.resample(repeated, 6)
	assert_eq(result.size(), 6, "cakisan noktalarda da adet tam")
	for point: Vector3 in result:
		assert_true(point.is_equal_approx(Vector3.ONE), "cakisan nokta korunur")
