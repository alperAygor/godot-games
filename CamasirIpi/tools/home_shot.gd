extends SceneTree

## Ana ekran yerleşim görüntüsü (gerçek pencere): Oyna düğmesinin dikdörtgenini ve güvenli alana
## göre oranını yazar, PNG kaydeder. Her en-boy oranı için ayrı çalıştırılır (pencere boyutu = oran):
##   godot --path . --resolution 540x1200 -s res://tools/home_shot.gd -- --out=/tmp/home_9x20.png
## Oyuncunun kaydına yazmaz (Progress.persist = false). Kısa ve sert zaman aşımıyla çalıştırın.

const HOME_SCENE: String = "res://scenes/Home.tscn"
const SHOT_AFTER_MSEC: int = 1400

var _out: String = "/tmp/home.png"
var _home: Node = null
var _start: int = 0


func _initialize() -> void:
	root.get_node("Progress").set("persist", false)
	# Bellekte temiz durum: karşılama/geri dönüş sayfası ekranı örtmesin (diske yazılmaz).
	root.get_node("Progress").call("reset_state")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	_home = (load(HOME_SCENE) as PackedScene).instantiate()
	root.add_child(_home)
	current_scene = _home
	_start = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _start < SHOT_AFTER_MSEC:
		# Karşılama sayfaları (oyuncunun gerçek kayıt tarihlerinden açılabilir) yerleşimi örtmesin.
		for sheet: Node in _home.find_children("*", "Sheet", true, false):
			sheet.queue_free()
		return false
	var view: Vector2 = root.get_visible_rect().size
	var play: Button = _home.get("_play_button") as Button
	var layout: Dictionary = _home.get("_layout") as Dictionary
	var usable: Rect2 = layout["usable"] as Rect2
	var rect: Rect2 = play.get_global_rect()
	print("HOME görünür %s, Oyna %s, merkez x fark %.1f, dikey oran %.3f, güvenli alanda %s" % [str(view), str(rect),
		rect.get_center().x - usable.get_center().x, (rect.get_center().y - usable.position.y) / usable.size.y,
		str(usable.encloses(rect))])
	var image: Image = root.get_texture().get_image()
	image.save_png(_out)
	quit(0)
	return true
