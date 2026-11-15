extends SceneTree
## Gün 1 öğretici sondası (headless): yeni hikaye oyunu → sabah → masa; hikaye olaylarını geçer, öğreticinin her adımını
## gerçek dokunuşlarla (TouchInput) yapar, günün kalanını kusursuz oynar ve mesai bitti sayfasına ulaşır.
## Betikli çalıştığı için kayıt/ayar sandbox'tadır (JsonIO); gerçek kullanıcı dosyalarına dokunmaz.
##   godot --headless --path . -s res://tools/tutorial_probe.gd
## Çıkış: 0 = öğretici tamamlandı ve gün bitti, 1 = başarısız (nedeni yazılır).
## Akışın kendisi `tools/tutorial_probe_flow.gd`'dedir (autoload adlarını kullandığı için çalışma anında yüklenir);
## testler de onu çağırır (`test_tutorial`).

const FLOW_PATH := "res://tools/tutorial_probe_flow.gd"
const WATCHDOG_SECONDS := 180.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(func() -> void:  # betik hatasında askıda kalmasın
		print("[TutorialProbe] zaman aşımı")
		quit(1))
	root.get_node("SettingsManager").set_value("game", "consent_asked", true, false)
	root.get_node("SceneManager").transition_time = 0.0
	var flow: GDScript = load(FLOW_PATH)
	var report: Dictionary = {"ok": false, "reason": "akış yüklenemedi"}
	if flow != null and flow.can_instantiate():
		report = await flow.play_first_day(self)
	print("[TutorialProbe] ", JSON.stringify(report))
	quit(0 if bool(report.get("ok", false)) else 1)
