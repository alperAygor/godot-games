class_name TestCase
extends RefCounted

## Basit test tabanı. Runner `tree` alanını doldurur; testler düğüm eklemek için
## `add_node()`, autoload'lara erişmek için `autoload_node()` kullanır.
##
## Autoload'lara NEDEN `get_node` ile: testler `-s` modunda çalışıyor ve orada
## autoload kimlikleri derleme anında çözülemiyor — çalışma anında aramak güvenli.

var tree: SceneTree = null

var _failures: Array[String] = []
var _assertions: int = 0


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func reset_state() -> void:
	_failures.clear()
	_assertions = 0


func failures() -> Array[String]:
	return _failures


func assertion_count() -> int:
	return _assertions


func add_node(node: Node) -> void:
	tree.root.add_child(node)


func autoload_node(autoload_name: String) -> Node:
	return tree.root.get_node_or_null(autoload_name)


func assert_true(condition: bool, message: String = "") -> void:
	_assertions += 1
	if not condition:
		_fail(message, "doğru olmalıydı")


func assert_false(condition: bool, message: String = "") -> void:
	_assertions += 1
	if condition:
		_fail(message, "yanlış olmalıydı")


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_assertions += 1
	if actual != expected:
		_fail(message, "beklenen <%s>, gelen <%s>" % [str(expected), str(actual)])


func assert_not_null(value: Variant, message: String = "") -> void:
	_assertions += 1
	if value == null:
		_fail(message, "null olmamalıydı")


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001,
		message: String = "") -> void:
	_assertions += 1
	if absf(actual - expected) > tolerance:
		_fail(message, "beklenen %.4f +- %.4f, gelen %.4f" % [expected, tolerance, actual])


func assert_greater(actual: float, minimum: float, message: String = "") -> void:
	_assertions += 1
	if actual <= minimum:
		_fail(message, "%.4f > %.4f olmalıydı" % [actual, minimum])


func fail(message: String) -> void:
	_assertions += 1
	_fail(message, "elle başarısız işaretlendi")


func _fail(message: String, detail: String) -> void:
	var label: String = message if message != "" else "doğrulama"
	_failures.append("%s (%s)" % [label, detail])
