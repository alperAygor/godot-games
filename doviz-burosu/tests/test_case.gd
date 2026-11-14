extends RefCounted
## Tüm testlerin temel sınıfı. tests/unit/test_*.gd dosyaları bunu extend eder.
## "test_" ile başlayan her metot bir testtir. Metot içinde await kullanılabilir.

## Çalıştırıcı tarafından atanır: autoload'lara tree.root üzerinden de erişilebilir.
var tree: SceneTree
var _failures: PackedStringArray = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_true(condition: bool, message := "") -> void:
	if not condition:
		_fail("true bekleniyordu", message)


func assert_false(condition: bool, message := "") -> void:
	if condition:
		_fail("false bekleniyordu", message)


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	if not _equals(actual, expected):
		_fail("beklenen <%s>, gelen <%s>" % [expected, actual], message)


func assert_ne(actual: Variant, unexpected: Variant, message := "") -> void:
	if _equals(actual, unexpected):
		_fail("<%s> olmamalıydı" % [actual], message)


func assert_almost_eq(actual: float, expected: float, tolerance := 0.0001, message := "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("beklenen ~%s, gelen %s" % [expected, actual], message)


func fail(message: String) -> void:
	_fail("başarısız", message)


func _equals(a: Variant, b: Variant) -> bool:
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in numeric and typeof(b) in numeric:
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


func _fail(reason: String, message: String) -> void:
	var text := reason if message.is_empty() else "%s — %s" % [message, reason]
	_failures.append(text)
