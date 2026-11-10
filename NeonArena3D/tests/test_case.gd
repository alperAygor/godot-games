extends RefCounted
class_name TestCase
## Minik test çatısı: test_ ile başlayan metotlar çalışır.

var failures: PackedStringArray = PackedStringArray()
var assertions := 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func eq(actual, expected, message: String) -> void:
	assertions += 1
	if actual != expected:
		failures.append("%s — beklenen: %s, gelen: %s" % [message, str(expected), str(actual)])

func near(actual: float, expected: float, eps: float, message: String) -> void:
	assertions += 1
	if absf(actual - expected) > eps:
		failures.append("%s — beklenen: %.3f, gelen: %.3f" % [message, expected, actual])

func gt(actual: float, limit: float, message: String) -> void:
	assertions += 1
	if not actual > limit:
		failures.append("%s — %.3f > %.3f olmalıydı" % [message, actual, limit])
