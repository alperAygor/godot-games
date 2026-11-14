extends SceneTree
## Tüm ikonların bir sayfada görüntüsü (tools/screenshots/style/icons.png). Kullanım: godot --resolution 720x1280 --path . -s res://tools/icon_sheet.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var bg := ColorRect.new()
	bg.color = Color("F1E7D3")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.position = Vector2(20, 20)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	root.add_child(grid)
	for icon_name in Icons.SHAPES.keys():
		var box := VBoxContainer.new()
		var view := IconView.new(icon_name, Color("2B2A33"), 72.0)
		box.add_child(view)
		var label := Label.new()
		label.text = icon_name
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("2B2A33"))
		box.add_child(label)
		grid.add_child(box)
	await create_timer(0.5).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/screenshots/style"))
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/screenshots/style/icons.png"))
	quit(0)
