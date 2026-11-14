class_name Icons
extends RefCounted
## Minimal çizgi ikonlar (resim dosyası yok, koda çizilir; her boyutta keskin, renk serbest). Her ikon 0..1 birim karede
## tanımlı şekil listesidir: ["l", noktalar] açık çizgi, ["L", noktalar] kapalı çizgi, ["c", x, y, r] halka, ["d", x, y] nokta,
## ["f", noktalar] dolu çokgen, ["a", x, y, r, başlangıç°, bitiş°] yay. Yeni ikon = tabloya bir satır.

const SHAPES := {
	"close": [["l", [Vector2(.27, .27), Vector2(.73, .73)]], ["l", [Vector2(.73, .27), Vector2(.27, .73)]]],
	"back": [["l", [Vector2(.62, .2), Vector2(.34, .5), Vector2(.62, .8)]]],
	"check": [["l", [Vector2(.2, .52), Vector2(.42, .74), Vector2(.8, .28)]]],
	"play": [["f", [Vector2(.36, .22), Vector2(.36, .78), Vector2(.8, .5)]]],
	"ad": [["c", .5, .5, .36], ["f", [Vector2(.43, .36), Vector2(.43, .64), Vector2(.66, .5)]]],
	"settings": [["c", .5, .5, .14], ["c", .5, .5, .27],
		["l", [Vector2(.5, .12), Vector2(.5, .2)]], ["l", [Vector2(.5, .8), Vector2(.5, .88)]],
		["l", [Vector2(.12, .5), Vector2(.2, .5)]], ["l", [Vector2(.8, .5), Vector2(.88, .5)]],
		["l", [Vector2(.23, .23), Vector2(.29, .29)]], ["l", [Vector2(.71, .71), Vector2(.77, .77)]],
		["l", [Vector2(.77, .23), Vector2(.71, .29)]], ["l", [Vector2(.23, .77), Vector2(.29, .71)]]],
	"book": [["l", [Vector2(.5, .3), Vector2(.5, .8)]], ["l", [Vector2(.5, .3), Vector2(.2, .24), Vector2(.2, .74), Vector2(.5, .8)]],
		["l", [Vector2(.5, .3), Vector2(.8, .24), Vector2(.8, .74), Vector2(.5, .8)]]],
	"calc": [["L", [Vector2(.26, .16), Vector2(.74, .16), Vector2(.74, .84), Vector2(.26, .84)]], ["l", [Vector2(.34, .3), Vector2(.66, .3)]],
		["d", .36, .5], ["d", .5, .5], ["d", .64, .5], ["d", .36, .66], ["d", .5, .66], ["d", .64, .66]],
	"catalog": [["L", [Vector2(.2, .2), Vector2(.46, .2), Vector2(.46, .46), Vector2(.2, .46)]], ["L", [Vector2(.54, .2), Vector2(.8, .2), Vector2(.8, .46), Vector2(.54, .46)]],
		["L", [Vector2(.2, .54), Vector2(.46, .54), Vector2(.46, .8), Vector2(.2, .8)]], ["L", [Vector2(.54, .54), Vector2(.8, .54), Vector2(.8, .8), Vector2(.54, .8)]]],
	"uv": [["c", .5, .42, .17], ["l", [Vector2(.42, .62), Vector2(.42, .74), Vector2(.58, .74), Vector2(.58, .62)]],
		["l", [Vector2(.5, .1), Vector2(.5, .17)]], ["l", [Vector2(.2, .22), Vector2(.26, .28)]], ["l", [Vector2(.8, .22), Vector2(.74, .28)]],
		["l", [Vector2(.12, .44), Vector2(.2, .44)]], ["l", [Vector2(.88, .44), Vector2(.8, .44)]]],
	"magnifier": [["c", .44, .44, .24], ["l", [Vector2(.62, .62), Vector2(.82, .82)]]],
	"till": [["L", [Vector2(.16, .44), Vector2(.84, .44), Vector2(.84, .78), Vector2(.16, .78)]], ["l", [Vector2(.16, .56), Vector2(.84, .56)]],
		["l", [Vector2(.4, .67), Vector2(.6, .67)]], ["l", [Vector2(.28, .44), Vector2(.34, .26), Vector2(.66, .26), Vector2(.72, .44)]]],
	"rate": [["l", [Vector2(.2, .36), Vector2(.78, .36)]], ["l", [Vector2(.66, .24), Vector2(.78, .36), Vector2(.66, .48)]],
		["l", [Vector2(.8, .66), Vector2(.22, .66)]], ["l", [Vector2(.34, .54), Vector2(.22, .66), Vector2(.34, .78)]]],
	"calendar": [["L", [Vector2(.2, .26), Vector2(.8, .26), Vector2(.8, .82), Vector2(.2, .82)]], ["l", [Vector2(.2, .42), Vector2(.8, .42)]],
		["l", [Vector2(.36, .16), Vector2(.36, .32)]], ["l", [Vector2(.64, .16), Vector2(.64, .32)]]],
	"infinity": [["l", "infinity"]],
	"market": [["L", [Vector2(.24, .38), Vector2(.76, .38), Vector2(.82, .82), Vector2(.18, .82)]], ["l", [Vector2(.38, .38), Vector2(.38, .26), Vector2(.62, .26), Vector2(.62, .38)]]],
	"help": [["c", .5, .5, .36], ["l", [Vector2(.4, .4), Vector2(.44, .32), Vector2(.56, .32), Vector2(.6, .4), Vector2(.5, .5), Vector2(.5, .56)]], ["d", .5, .69]],
	"info": [["c", .5, .5, .36], ["l", [Vector2(.5, .46), Vector2(.5, .7)]], ["d", .5, .32]],
	"shield": [["L", [Vector2(.5, .16), Vector2(.8, .28), Vector2(.76, .6), Vector2(.5, .84), Vector2(.24, .6), Vector2(.2, .28)]], ["l", [Vector2(.38, .5), Vector2(.47, .6), Vector2(.64, .4)]]],
	"refresh": [["a", .5, .5, .28, 40.0, 330.0], ["l", [Vector2(.78, .18), Vector2(.8, .36), Vector2(.62, .36)]]],
	"share": [["c", .3, .5, .09], ["c", .72, .28, .09], ["c", .72, .72, .09], ["l", [Vector2(.37, .46), Vector2(.65, .32)]], ["l", [Vector2(.37, .54), Vector2(.65, .68)]]],
	"lock": [["L", [Vector2(.26, .46), Vector2(.74, .46), Vector2(.74, .8), Vector2(.26, .8)]], ["l", [Vector2(.34, .46), Vector2(.34, .34), Vector2(.4, .22), Vector2(.6, .22), Vector2(.66, .34), Vector2(.66, .46)]]],
	"coin": [["c", .5, .5, .34], ["c", .5, .5, .2]],
	"clock": [["c", .5, .5, .34], ["l", [Vector2(.5, .28), Vector2(.5, .5), Vector2(.66, .6)]]],
	"warning": [["L", [Vector2(.5, .18), Vector2(.85, .8), Vector2(.15, .8)]], ["l", [Vector2(.5, .4), Vector2(.5, .58)]], ["d", .5, .69]],
	"siren": [["a", .5, .64, .24, 180.0, 360.0], ["l", [Vector2(.26, .64), Vector2(.74, .64)]], ["l", [Vector2(.2, .76), Vector2(.8, .76)]],
		["l", [Vector2(.5, .18), Vector2(.5, .26)]], ["l", [Vector2(.24, .28), Vector2(.3, .34)]], ["l", [Vector2(.76, .28), Vector2(.7, .34)]]],
	"return": [["l", [Vector2(.78, .7), Vector2(.78, .44), Vector2(.3, .44)]], ["l", [Vector2(.44, .3), Vector2(.3, .44), Vector2(.44, .58)]]],
	"box": [["L", [Vector2(.2, .42), Vector2(.8, .42), Vector2(.8, .78), Vector2(.2, .78)]], ["l", [Vector2(.2, .42), Vector2(.3, .26), Vector2(.7, .26), Vector2(.8, .42)]], ["l", [Vector2(.42, .52), Vector2(.58, .52)]]],
	"newspaper": [["L", [Vector2(.18, .22), Vector2(.82, .22), Vector2(.82, .8), Vector2(.18, .8)]], ["l", [Vector2(.28, .36), Vector2(.52, .36)]],
		["l", [Vector2(.28, .5), Vector2(.72, .5)]], ["l", [Vector2(.28, .62), Vector2(.72, .62)]], ["l", [Vector2(.28, .72), Vector2(.56, .72)]]],
	"wallet": [["L", [Vector2(.16, .3), Vector2(.84, .3), Vector2(.84, .78), Vector2(.16, .78)]], ["l", [Vector2(.16, .42), Vector2(.84, .42)]], ["d", .7, .6]],
	"house": [["l", [Vector2(.18, .5), Vector2(.5, .2), Vector2(.82, .5)]], ["l", [Vector2(.28, .44), Vector2(.28, .8), Vector2(.72, .8), Vector2(.72, .44)]], ["l", [Vector2(.44, .8), Vector2(.44, .6), Vector2(.56, .6), Vector2(.56, .8)]]],
	"heart": [["l", "heart"]],
	"sound": [["L", [Vector2(.2, .42), Vector2(.34, .42), Vector2(.52, .26), Vector2(.52, .74), Vector2(.34, .58), Vector2(.2, .58)]], ["a", .52, .5, .16, -50.0, 50.0], ["a", .52, .5, .28, -50.0, 50.0]],
	"stamp": [["L", [Vector2(.4, .16), Vector2(.6, .16), Vector2(.6, .36), Vector2(.4, .36)]], ["l", [Vector2(.5, .36), Vector2(.5, .5)]],
		["L", [Vector2(.22, .5), Vector2(.78, .5), Vector2(.78, .64), Vector2(.22, .64)]], ["l", [Vector2(.18, .78), Vector2(.82, .78)]]],
	"document": [["L", [Vector2(.28, .16), Vector2(.72, .16), Vector2(.72, .84), Vector2(.28, .84)]], ["l", [Vector2(.38, .34), Vector2(.62, .34)]], ["l", [Vector2(.38, .48), Vector2(.62, .48)]], ["l", [Vector2(.38, .62), Vector2(.54, .62)]]],
	"radio": [["L", [Vector2(.14, .36), Vector2(.86, .36), Vector2(.86, .8), Vector2(.14, .8)]], ["l", [Vector2(.3, .36), Vector2(.66, .14)]],
		["c", .36, .58, .1], ["d", .68, .5], ["l", [Vector2(.58, .68), Vector2(.78, .68)]]],
	"phone": [["f", [Vector2(.2, .3), Vector2(.3, .18), Vector2(.42, .4), Vector2(.34, .5), Vector2(.5, .66), Vector2(.6, .58), Vector2(.82, .7), Vector2(.7, .82), Vector2(.5, .8), Vector2(.28, .62), Vector2(.2, .42)]]],
	"pin": [["c", .5, .3, .16], ["l", [Vector2(.38, .5), Vector2(.62, .5)]], ["l", [Vector2(.5, .5), Vector2(.5, .84)]]],
	"person": [["c", .5, .34, .15], ["a", .5, .86, .3, 195.0, 345.0]],
	"moon": [["a", .5, .5, .32, 120.0, 400.0]],
}


## Eğrisel ikonların noktaları (parametrik).
static func curve(curve_name: String) -> PackedVector2Array:
	var points := PackedVector2Array()
	match curve_name:
		"infinity":
			for i in range(0, 41):
				var t := TAU * i / 40.0
				var denominator := 1.0 + sin(t) * sin(t)
				points.append(Vector2(.5 + .34 * cos(t) / denominator, .5 + .34 * sin(t) * cos(t) / denominator))
		"heart":
			for i in range(0, 41):
				var t := TAU * i / 40.0
				var x := 16.0 * pow(sin(t), 3.0)
				var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
				points.append(Vector2(.5 + x / 40.0, .46 - y / 40.0))
	return points


static func has_icon(icon_name: String) -> bool:
	return SHAPES.has(icon_name)


## `icon_name` ikonunu `rect` içindeki en büyük kareye, `color` rengiyle ve `stroke` kalınlığıyla çizer.
static func draw_on(canvas: CanvasItem, icon_name: String, rect: Rect2, color: Color, stroke := 2.5) -> void:
	if not SHAPES.has(icon_name):
		return
	var side := minf(rect.size.x, rect.size.y)
	var origin := rect.position + (rect.size - Vector2(side, side)) / 2.0
	for shape: Array in SHAPES[icon_name]:
		match str(shape[0]):
			"l", "L":
				var points: PackedVector2Array = PackedVector2Array()
				var source: Variant = shape[1]
				if source is String:
					source = curve(str(source))
				for point: Vector2 in source:
					points.append(origin + point * side)
				if str(shape[0]) == "L":
					points.append(points[0])
				canvas.draw_polyline(points, color, stroke, true)
			"c":
				canvas.draw_arc(origin + Vector2(shape[1], shape[2]) * side, float(shape[3]) * side, 0.0, TAU, 40, color, stroke, true)
			"d":
				canvas.draw_circle(origin + Vector2(shape[1], shape[2]) * side, maxf(1.6, stroke * 0.7), color)
			"f":
				var polygon := PackedVector2Array()
				for point: Vector2 in shape[1]:
					polygon.append(origin + point * side)
				canvas.draw_colored_polygon(polygon, color)
			"a":
				canvas.draw_arc(origin + Vector2(shape[1], shape[2]) * side, float(shape[3]) * side, deg_to_rad(float(shape[4])), deg_to_rad(float(shape[5])), 28, color, stroke, true)
