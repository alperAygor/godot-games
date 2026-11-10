extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/Boot.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	var title: Label = scene.get_node("Center/Column/Title") as Label
	print("A_auto=%d" % title.get_theme_font_size("font_size"))
	print("B_explicit=%d" % title.get_theme_font_size("font_size", "TitleLabel"))
	print("C_has=%s" % str(title.get_theme().has_font_size("font_size", "TitleLabel")))

	var btn: Button = Button.new()
	btn.theme_type_variation = &"SecondaryButton"
	root.add_child(btn)
	print("D_btn_explicit=%d" % btn.get_theme_font_size("font_size", "SecondaryButton"))
	print("E_btn_style_bg=%s" % str(btn.get_theme_stylebox("normal").bg_color))
	print("F_btn_style_explicit=%s" % str(btn.get_theme_stylebox("normal", "SecondaryButton").bg_color))
	quit(0)
