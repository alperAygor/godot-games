extends TestCase

## Renk desenleri: 7 renk = 7 ayrı desen, sabit eşleme, kapalıyken/gizemde desen yok,
## palet game.gd ile aynı, glif atlası ve shader'lar yüklenir.

const GAME_SCRIPT: String = "res://scripts/ui/game.gd"
## Desen numarası değişirse shader ve kayıtlı oyun bozulur: eşleme burada sabitlenir.
const EXPECTED: Array[int] = [0, 1, 2, 3, 4, 5, 6]


func before_each() -> void:
	# Oyuncu kaydına yazma: yalnız bellekte.
	ColorPatterns.set_enabled(true, false)


func after_each() -> void:
	ColorPatterns.reset_cache()


func test_seven_distinct_patterns() -> void:
	var seen: Dictionary = {}
	for color_id: int in range(ColorPatterns.PALETTE.size()):
		var pattern: int = ColorPatterns.pattern_for(color_id)
		assert_true(pattern >= 0, "renk %d desen almalı" % color_id)
		seen[pattern] = true
	assert_eq(seen.size(), 7, "7 renk 7 ayrı desen almalı")


func test_mapping_is_stable() -> void:
	for color_id: int in range(EXPECTED.size()):
		assert_eq(ColorPatterns.pattern_for(color_id), EXPECTED[color_id], "renk %d deseni sabit" % color_id)
	# Palet dışı numara paletle sarılır (oyun `% COLORS.size()` kullanır).
	assert_eq(ColorPatterns.pattern_for(7), ColorPatterns.pattern_for(0))


func test_disabled_means_no_pattern() -> void:
	ColorPatterns.set_enabled(false, false)
	assert_false(ColorPatterns.enabled())
	for color_id: int in range(ColorPatterns.PALETTE.size()):
		assert_eq(ColorPatterns.pattern_for(color_id), ColorPatterns.NONE, "kapalıyken desen yok")
	assert_true(ColorPatterns.band_material(1) == null, "kapalıyken astar materyali yok")


func test_mystery_hides_pattern() -> void:
	for color_id: int in range(ColorPatterns.PALETTE.size()):
		assert_eq(ColorPatterns.pattern_for(color_id, true), ColorPatterns.NONE, "gizemli çamaşır deseni sızdırmaz")
	assert_eq(ColorPatterns.pattern_for(-1), ColorPatterns.NONE, "renksiz (joker) desensiz")


func test_color_lookup_round_trip() -> void:
	for color_id: int in range(ColorPatterns.PALETTE.size()):
		assert_eq(ColorPatterns.color_id_of(ColorPatterns.PALETTE[color_id]), color_id)
	assert_eq(ColorPatterns.color_id_of(Color.WHITE), -1, "joker beyazı palette yok")
	assert_eq(ColorPatterns.color_id_of(Color(0.72, 0.7, 0.8)), -1, "gizem grisi palette yok")


func test_palette_matches_game() -> void:
	var game: GDScript = load(GAME_SCRIPT) as GDScript
	assert_not_null(game)
	var colors: Array = game.get_script_constant_map()["COLORS"] as Array
	assert_eq(colors.size(), ColorPatterns.PALETTE.size(), "palet boyu")
	for index: int in range(colors.size()):
		assert_true((colors[index] as Color).is_equal_approx(ColorPatterns.PALETTE[index]), "palet rengi %d" % index)


func test_garment_material_receives_pattern() -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(ColorPatterns.SWAY_SHADER_PATH) as Shader
	assert_not_null(material.shader)
	ColorPatterns.apply_garment(null, material, ColorPatterns.PALETTE[2], false, true)
	assert_eq(int(material.get_shader_parameter("pattern_id")), ColorPatterns.DOTS)
	ColorPatterns.apply_garment(null, material, ColorPatterns.PALETTE[2], true, true)
	assert_eq(int(material.get_shader_parameter("pattern_id")), ColorPatterns.NONE, "gizemde desen yok")
	ColorPatterns.apply_garment(null, material, ColorPatterns.PALETTE[2], false, false)
	assert_true(float(material.get_shader_parameter("pattern_strength")) < 1.0, "kapalı çamaşırda silik")
	# Çift renk: sol/sağ ayrı desen.
	ColorPatterns.apply_ids(null, material, 1, 3, 1.0, false)
	assert_true(bool(material.get_shader_parameter("pattern_split")))
	assert_eq(int(material.get_shader_parameter("pattern_id_b")), ColorPatterns.CHECKS)


func test_glyph_atlas_and_shaders_load() -> void:
	assert_not_null(ColorPatterns.glyph_texture(), "glif atlası yüklenmeli")
	assert_not_null(load(ColorPatterns.SWAY_SHADER_PATH))
	assert_not_null(load(ColorPatterns.TINT_SHADER_PATH))
	var regions: Dictionary = {}
	for color_id: int in range(ColorPatterns.PALETTE.size()):
		regions[ColorPatterns.glyph_region(color_id).position.x] = true
	assert_eq(regions.size(), 7, "her renk ayrı glif hücresi")


## Çift renkli çamaşır: iki yarı kendi desenini taşır; gizem/polen deseni siler; yerleşince tek renk deseni.
func test_dual_garment_halves_carry_own_patterns() -> void:
	var view: GarmentView = GarmentView.new()
	view.setup(1, ColorPatterns.PALETTE[2], 150.0, 0, 0)
	view.set_dual(ColorPatterns.PALETTE[3])
	var material_a: ShaderMaterial = view.get("_material") as ShaderMaterial
	var material_b: ShaderMaterial = view.get("_dual_material") as ShaderMaterial
	assert_not_null(material_b, "ikinci yarının kendi materyali var")
	assert_true(material_a != material_b, "iki yarı materyali paylaşmaz")
	assert_eq(int(material_a.get_shader_parameter("pattern_id")), ColorPatterns.DOTS, "sol/ana yarı: sarı puan")
	assert_eq(int(material_b.get_shader_parameter("pattern_id")), ColorPatterns.CHECKS, "ikinci yarı: yeşil kare")
	view.set_mystery(true)
	assert_eq(int(material_a.get_shader_parameter("pattern_id")), ColorPatterns.NONE, "gizemde ana yarı desensiz")
	assert_eq(int(material_b.get_shader_parameter("pattern_id")), ColorPatterns.NONE, "gizemde ikinci yarı desensiz")
	view.set_mystery(false)
	view.set_dusty(true, true)
	assert_eq(int(material_b.get_shader_parameter("pattern_id")), ColorPatterns.NONE, "polende desen yok")
	view.set_dusty(false, false)
	view.set_open(false)
	assert_true(float(material_b.get_shader_parameter("pattern_strength")) < 1.0, "kapalıda ikinci yarı da silik")
	view.settle_dual(ColorPatterns.PALETTE[3], false)
	assert_eq(int(material_a.get_shader_parameter("pattern_id")), ColorPatterns.CHECKS, "yerleşince kalan rengin deseni")
	view.free()


## Ayar anahtarı çevrilince ağaçtaki çamaşırlar HEMEN güncellenir (bir sonraki seviye beklenmez).
func test_toggle_refreshes_live_garments() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var view: GarmentView = GarmentView.new()
	view.setup(2, ColorPatterns.PALETTE[1], 150.0, 0, 0)
	tree.root.add_child(view)
	var material: ShaderMaterial = view.get("_material") as ShaderMaterial
	assert_eq(int(material.get_shader_parameter("pattern_id")), ColorPatterns.STRIPES_V)
	ColorPatterns.set_enabled(false, false)
	assert_eq(int(material.get_shader_parameter("pattern_id")), ColorPatterns.NONE, "kapatınca canlı yenilenir")
	ColorPatterns.set_enabled(true, false)
	assert_eq(int(material.get_shader_parameter("pattern_id")), ColorPatterns.STRIPES_V, "açınca canlı yenilenir")
	tree.root.remove_child(view)
	view.free()
