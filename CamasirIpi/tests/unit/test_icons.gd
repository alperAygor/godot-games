extends TestCase

## Ikon tablosu ve yukleme: tablo bos degilse Texture2D gercekten yuklenmeli.

func test_table_is_not_empty() -> void:
	assert_true(Icons.has_icon("lucide/star"), "lucide/star tabloda olmali")
	assert_greater(float(Icons.names().size()), 5.0, "en az 6 ikon bekleniyor")


func test_texture_loads() -> void:
	var texture2d: Texture2D = Icons.texture("lucide/star")
	assert_not_null(texture2d, "star.svg Texture2D olarak yuklenmeli")
	if texture2d != null:
		assert_greater(float(texture2d.get_width()), 0.0, "genislik > 0")


func test_unknown_icon_returns_null() -> void:
	assert_false(Icons.has_icon("lucide/boyle-bir-ikon-yok"))


func test_apply_sets_button_icon() -> void:
	var button: Button = Button.new()
	add_node(button)
	Icons.apply(button, "lucide/play")
	assert_not_null(button.icon, "buton ikonu atanmali")
	button.free()
