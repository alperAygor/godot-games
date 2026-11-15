extends MenuScreen
## Nasıl oynanır: kontroller (dokunmatik / klavye) ve ipuçları. Salt okunur; durum yok.

const KIT = preload("res://scripts/ui/ui_kit.gd")


func build() -> void:
	root = host.make_screen("howto", 0.8)
	var panel := KIT.panel(KIT.VIOLET, 30.0)
	host.center(root).add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(760, 0)
	panel.add_child(box)
	box.add_child(KIT.heading(tr("NASIL OYNANIR"), 36, KIT.VIOLET))
	box.add_child(KIT.spacer(2))
	var controls: Array = []
	if Settings.touch:
		controls = [
			[tr("SOL ÇUBUK"), tr("hareket et")],
			[tr("SAĞ ÇUBUK"), tr("nişan al ve ateş et (boşken otomatik nişan)")],
			[tr("ATIL"), tr("kısa süre dokunulmaz ol, mermilerin içinden geç")],
			[tr("NOVA"), tr("dolunca: çevredeki düşmanları ve mermileri sil")],
		]
	else:
		controls = [
			[tr("WASD / OKLAR"), tr("hareket et")],
			[tr("FARE + SOL TIK"), tr("nişan al ve ateş et")],
			[tr("BOŞLUK / SHIFT"), tr("atıl: kısa süre dokunulmaz ol")],
			[tr("Q / SAĞ TIK"), tr("NOVA: çevredeki düşmanları ve mermileri sil")],
			["1 · 2 · 3", tr("kart seç      ESC duraklat      M sessiz")],
		]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 9)
	box.add_child(grid)
	for entry in controls:
		grid.add_child(KIT.label(entry[0], 18, KIT.CYAN, KIT.bold()))
		grid.add_child(KIT.label(entry[1], 18, KIT.TEXT))
	box.add_child(KIT.spacer(6))
	var tips := [
		tr("Düşman öldür, kombo büyüsün: puan ve XP katlanır."),
		tr("Seviye atlayınca 3 karttan birini seç; kartlar koşu boyunca kalıcıdır."),
		tr("Her 5. dalgada boss gelir. Yenersen yeni sektöre geçersin."),
		tr("Altın parlayan ELİT düşmanlar güçlüdür ama mutlaka ganimet bırakır."),
		tr("Uyumlu iki kartı birlikte alınca güçlü bir SİNERJİ kartı açılır."),
		tr("Yeşil can, sarı aşırı yük, mavi kalkan: yanından geçmen yeter."),
	]
	for tip in tips:
		var l := KIT.label("•  " + tip, 16, KIT.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(740, 0)
		box.add_child(l)
	box.add_child(KIT.spacer(6))
	var back := KIT.button(tr("ANLADIM"), KIT.VIOLET, Vector2(240, 58), 22, true)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(host._back)
	box.add_child(back)
	host.focus["howto"] = back
