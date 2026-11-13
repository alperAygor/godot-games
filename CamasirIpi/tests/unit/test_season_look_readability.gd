extends TestCase

## Oyun alanı (y 250..1250) her mevsimde SOLUK ve düşük kontrastlı kalmalı: doygun çamaşırlar
## manzaranın önünde okunsun. Test, mekânın uzak/orta katmanlarından oyun alanına düşen pikselleri
## örnekler, derecelendirmenin CPU eşiyle (SeasonLook.grade_color) boyar ve yazla kıyaslar:
## ortalama parlaklık eşiğin üstünde, doygunluk ve parlaklık yayılımı (kontrast) yazdan belirgin fazla değil.

const PLAY_TOP: float = 250.0
const PLAY_BOTTOM: float = 1250.0
## Katman ekranda bu y'de başlar (data/locations.json "pos").
const LAYERS: Array[Array] = [["bg_far", 620.0], ["bg_mid", 760.0]]
const STEP: int = 23
const ALPHA_MIN: float = 0.9
## Oyun alanı manzarası ortalamada en az bu kadar aydınlık olmalı (gündüz, gün tonu öncesi).
const MIN_MEAN_LUMA: float = 0.62
## Mevsim, yazdakinden en fazla bu kadar doygunluk / parlaklık yayılımı ekleyebilir.
const MAX_EXTRA_SAT: float = 0.1
const MAX_SPREAD_RATIO: float = 1.3


func test_play_area_stays_pale_in_every_season() -> void:
	for index: int in range(LocationCycle.count()):
		var id: String = LocationCycle.id_at(index)
		var colors: Array[Color] = _play_area_colors(id)
		assert_true(colors.size() > 50, "%s örnek yok" % id)
		var summer: Vector3 = _stats(colors, {})
		for season: String in SeasonCycle.ORDER:
			for file_name: String in ["bg_far", "bg_mid"]:
				var grade: Dictionary = SeasonLook.grade_for(id, season, file_name)
				for variant: float in [0.0, 1.0]:
					var stats: Vector3 = _stats(colors, grade, variant)
					var label: String = "%s/%s/%s/v%d" % [id, season, file_name, int(variant)]
					assert_true(stats.x >= MIN_MEAN_LUMA, "%s çok koyu (%.2f)" % [label, stats.x])
					assert_true(stats.y <= summer.y + MAX_EXTRA_SAT, "%s çok doygun (%.2f > %.2f)" % [label, stats.y, summer.y])
					assert_true(stats.z <= summer.z * MAX_SPREAD_RATIO + 0.01,
						"%s kontrast arttı (%.3f > %.3f)" % [label, stats.z, summer.z])


func test_grade_color_cpu_twin_moves_foliage_only() -> void:
	var autumn: Dictionary = SeasonLook.grade_for("garden", SeasonCycle.AUTUMN, "bg_mid")
	var leaf: Color = Color.html("#a8d69a")
	var sky: Color = Color.html("#cfe8f6")
	var graded_leaf: Color = SeasonLook.grade_color(leaf, autumn)
	assert_true(graded_leaf.h < 0.15, "sonbaharda yeşillik turuncuya dönmeli (ton %.2f)" % graded_leaf.h)
	var graded_sky: Color = SeasonLook.grade_color(sky, autumn)
	assert_true(absf(graded_sky.h - sky.h) < 0.03, "mavi pus yeşillik maskesine girmemeli")
	var winter: Dictionary = SeasonLook.grade_for("garden", SeasonCycle.WINTER, "bg_mid")
	assert_true(SeasonLook.grade_color(leaf, winter).get_luminance() > 0.8, "kışın çalı karla örtülür")


## Oyun alanına düşen opak piksellerin bir ızgarası (her katmandan).
func _play_area_colors(id: String) -> Array[Color]:
	var colors: Array[Color] = []
	var dir: String = String(LocationCycle.data_for(id).get("dir", ""))
	for spec: Array in LAYERS:
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(dir + String(spec[0]) + ".png"))
		if image == null:
			continue
		var top: int = maxi(int(PLAY_TOP - float(spec[1])), 0)
		var bottom: int = mini(int(PLAY_BOTTOM - float(spec[1])), image.get_height())
		for y: int in range(top, bottom, STEP):
			for x: int in range(0, image.get_width(), STEP):
				var color: Color = image.get_pixel(x, y)
				if color.a >= ALPHA_MIN:
					colors.append(color)
	return colors


## (ortalama parlaklık, ortalama doygunluk, parlaklık standart sapması)
func _stats(colors: Array[Color], grade: Dictionary, variant: float = 0.0) -> Vector3:
	var sum: float = 0.0
	var sum_sq: float = 0.0
	var sat: float = 0.0
	for color: Color in colors:
		var graded: Color = SeasonLook.grade_color(color, grade, variant)
		var luma: float = graded.get_luminance()
		sum += luma
		sum_sq += luma * luma
		sat += graded.s
	var count: float = maxf(float(colors.size()), 1.0)
	var mean: float = sum / count
	return Vector3(mean, sat / count, sqrt(maxf(sum_sq / count - mean * mean, 0.0)))
