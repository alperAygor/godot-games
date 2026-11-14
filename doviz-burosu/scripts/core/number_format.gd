class_name NumberFormat
extends RefCounted
## Büyük sayıları kısaltır: 950 → "950", 1234 → "1.23K", 5600000 → "5.60M".

const SUFFIXES := ["", "K", "M", "B", "T", "aa", "ab", "ac", "ad"]


static func short(value: float) -> String:
	var sign := "-" if value < 0.0 else ""
	var v := absf(value)
	if v < 10.0:
		var rounded := snappedf(v, 0.1)
		return sign + (str(int(rounded)) if is_equal_approx(rounded, roundf(rounded)) else "%.1f" % rounded)
	if v < 1000.0:
		return sign + str(int(floorf(v)))
	var tier := 0
	while v >= 1000.0 and tier < SUFFIXES.size() - 1:
		v /= 1000.0
		tier += 1
	var text := "%.2f" % v if v < 10.0 else ("%.1f" % v if v < 100.0 else str(int(floorf(v))))
	return sign + text + SUFFIXES[tier]
