extends SceneTree
## Oyunu çalıştırır, belirtilen anlarda dokunma/kaydırma/geri tuşu simüle eder ve ekran görüntüsü kaydeder.
##
## Kullanım (proje kökünden; --headless KULLANMA, aşağıya bak):
##   godot --path . -s res://tools/screenshot.gd -- --times=1
##   godot --path . -s res://tools/screenshot.gd -- --times=0.5,2 --tap=SettingsButton@1 --back=3 --times=3.5
##
## Argümanlar (hepsi isteğe bağlı, eylemler tekrarlanabilir):
##   --times=0.5,2            Ekran görüntüsü anları, saniye (varsayılan: 1). Birden çok kez verilebilir.
##   --tap=X,Y@T              T. saniyede tasarım koordinatına (720x1280) dokun.
##   --tap=DüğümAdı@T         T. saniyede aktif sahnedeki düğümün ortasına dokun (%UniqueName veya düğüm adı).
##   --swipe=X1,Y1>X2,Y2@T    T. saniyede kaydır (0.3 sn). Süre için: @T:0.6
##   --back=T                 T. saniyede Android geri tuşu.
##   --scene=res://...        Başlangıç sahnesi (varsayılan: ana sahne).
##   --out=klasör             Çıktı klasörü, proje köküne göre (varsayılan: tools/screenshots).
##   --prefix=ad              Dosya adı öneki (varsayılan: sahne adı).
##   --simulate-safe-area=88,0,68,0   Çentik simülasyonu (SafeAreaContainer okur; üst,sağ,alt,sol).
## Aynı saniyede önce eylem, sonra çekim yapılır. Çıkış kodu: 0 başarılı, 1 bir eylem/çekim başarısız, 2 kullanım hatası.
##
## Neden headless değil: --headless modunda dummy render sürücüsü piksel üretmez, görüntü boş gelir.
## Ekransız Linux/CI'da sanal ekran kullan:  xvfb-run -a godot --path . -s res://tools/screenshot.gd

const TouchInput := preload("res://tools/touch_input.gd")

var _events: Array[Dictionary] = []
var _scene_path := ""
var _out_dir := "tools/screenshots"
var _prefix := ""
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _parse_args():
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		printerr("screenshot.gd: --headless modunda görüntü alınamaz (render yok). --headless olmadan veya xvfb-run ile çalıştır.")
		quit(2)
		return

	if _scene_path.is_empty():
		_scene_path = ProjectSettings.get_setting("application/run/main_scene", "")
	var packed: PackedScene = load(_scene_path) if not _scene_path.is_empty() else null
	if packed == null:
		printerr("screenshot.gd: sahne yüklenemedi: '%s'" % _scene_path)
		quit(2)
		return
	if _prefix.is_empty():
		_prefix = _scene_path.get_file().get_basename()

	var out_abs := ProjectSettings.globalize_path("res://").path_join(_out_dir)
	DirAccess.make_dir_recursive_absolute(out_abs)
	if not FileAccess.file_exists(out_abs.path_join(".gdignore")):
		FileAccess.open(out_abs.path_join(".gdignore"), FileAccess.WRITE)  # Godot PNG'leri içe aktarmasın

	await process_frame  # autoload'lar hazır olsun
	change_scene_to_packed(packed)
	await process_frame
	await process_frame

	var started := Time.get_ticks_msec() / 1000.0
	for event in _events:
		var wait: float = event.t - (Time.get_ticks_msec() / 1000.0 - started)
		if wait > 0.0:
			await create_timer(wait, true, false, true).timeout
		await _apply(event, out_abs)

	quit(0 if _failures == 0 else 1)


func _apply(event: Dictionary, out_abs: String) -> void:
	match event.kind:
		"shot":
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var file_path := out_abs.path_join("%s_%06.2fs.png" % [_prefix, event.t])
			if image.save_png(file_path) == OK:
				print("screenshot.gd: [%.2fs] kaydedildi %s (%dx%d)" % [event.t, file_path, image.get_width(), image.get_height()])
			else:
				printerr("screenshot.gd: [%.2fs] kaydedilemedi %s" % [event.t, file_path])
				_failures += 1
		"tap_pos":
			print("screenshot.gd: [%.2fs] dokun %s" % [event.t, event.pos])
			await TouchInput.tap(self, event.pos)
		"tap_node":
			if await TouchInput.tap_node(self, event.node):
				print("screenshot.gd: [%.2fs] dokun düğüm '%s'" % [event.t, event.node])
			else:
				printerr("screenshot.gd: [%.2fs] düğüm bulunamadı veya görünmüyor: '%s' (sahne: %s)" % [
					event.t, event.node, current_scene.scene_file_path if current_scene else "yok"])
				_failures += 1
		"swipe":
			print("screenshot.gd: [%.2fs] kaydır %s → %s" % [event.t, event.from, event.to])
			await TouchInput.swipe(self, event.from, event.to, event.duration)
		"back":
			print("screenshot.gd: [%.2fs] geri tuşu" % event.t)
			await TouchInput.back(self)


func _parse_args() -> bool:
	var shots_given := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--times="):
			shots_given = true
			for part in arg.trim_prefix("--times=").split(",", false):
				_events.append({"t": part.to_float(), "kind": "shot"})
		elif arg.begins_with("--tap="):
			var spec := _split_time(arg.trim_prefix("--tap="))
			if spec.is_empty():
				return _usage_error(arg)
			var target: String = spec.body
			var parts := target.split(",")
			if parts.size() == 2 and parts[0].is_valid_float() and parts[1].is_valid_float():
				_events.append({"t": spec.t, "kind": "tap_pos", "pos": Vector2(parts[0].to_float(), parts[1].to_float())})
			else:
				_events.append({"t": spec.t, "kind": "tap_node", "node": target})
		elif arg.begins_with("--swipe="):
			var spec := _split_time(arg.trim_prefix("--swipe="))
			var points: PackedStringArray = spec.get("body", "").split(">")
			if spec.is_empty() or points.size() != 2:
				return _usage_error(arg)
			var a := points[0].split(",")
			var b := points[1].split(",")
			if a.size() != 2 or b.size() != 2:
				return _usage_error(arg)
			_events.append({"t": spec.t, "kind": "swipe", "duration": spec.duration,
				"from": Vector2(a[0].to_float(), a[1].to_float()), "to": Vector2(b[0].to_float(), b[1].to_float())})
		elif arg.begins_with("--back="):
			_events.append({"t": arg.trim_prefix("--back=").to_float(), "kind": "back"})
		elif arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--prefix="):
			_prefix = arg.trim_prefix("--prefix=")
	if not shots_given:
		_events.append({"t": 1.0, "kind": "shot"})
	# Zamana göre sırala; aynı anda önce eylem, sonra çekim.
	_events.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if not is_equal_approx(x.t, y.t):
			return x.t < y.t
		return x.kind != "shot" and y.kind == "shot")
	return true


## "gövde@T" veya "gövde@T:süre" → {body, t, duration}
func _split_time(text: String) -> Dictionary:
	var at := text.rfind("@")
	if at <= 0:
		return {}
	var time_part := text.substr(at + 1).split(":")
	return {
		"body": text.substr(0, at),
		"t": time_part[0].to_float(),
		"duration": time_part[1].to_float() if time_part.size() > 1 else 0.3,
	}


func _usage_error(arg: String) -> bool:
	printerr("screenshot.gd: anlaşılmayan argüman '%s' (dosyanın başındaki kullanıma bak)" % arg)
	return false
