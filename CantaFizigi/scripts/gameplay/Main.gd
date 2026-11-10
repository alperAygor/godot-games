extends Node3D

## Sahne kablolaması: sarsıntı, paket fiziği, HUD ve reklam ödülleri.
## Karar mantığı autoload'larda (GameManager / AdManager); burada yalnızca bağlanır.

@onready var grid: GridController = $ShakeRoot/BackpackGrid
@onready var shake: ShakeSimulator = $ShakeSimulator
@onready var hud: HUD = $HUD


func _ready() -> void:
	get_tree().paused = false
	GameManager.reset_run()

	hud.start_pressed.connect(_on_start_pressed)
	hud.extra_pocket_pressed.connect(_on_extra_pocket_pressed)
	hud.tape_pressed.connect(_on_tape_pressed)
	hud.revive_pressed.connect(_on_revive_pressed)
	hud.retry_pressed.connect(_on_retry_pressed)

	shake.shake_step.connect(_on_shake_step)
	shake.shake_finished.connect(_on_shake_finished)

	GameManager.run_failed.connect(_on_run_failed)
	GameManager.run_revived.connect(_on_run_revived)
	GameManager.phase_changed.connect(_on_phase_changed)

	AdManager.ad_started.connect(_on_ad_started)
	AdManager.rewarded_finished.connect(_on_rewarded_finished)

	grid.package_placed.connect(_on_package_placed)
	grid.package_broken.connect(_on_package_broken)
	GameManager.back_requested.connect(_on_back_requested)

	# "Çanta Kapasitesi" yükseltmesi başlangıç ızgarasını büyütür (4 -> 6 sütun).
	var base_cols: int = clampi(
		GridController.BASE_COLS + GameManager.profile.upgrade_level("bag_capacity"),
		GridController.BASE_COLS, GridController.MAX_COLS)
	if base_cols > GridController.BASE_COLS:
		grid.expand_to(base_cols)

	_refresh_hud()


# --------------------------------------------------------------------------
# HUD
# --------------------------------------------------------------------------
func _on_start_pressed() -> void:
	if GameManager.phase != GameManager.Phase.PACKING:
		return
	if grid.placed_count() == 0:
		hud.toast("Önce çantaya en az bir paket koy")
		return
	GameManager.start_delivery()
	grid.drag_enabled = false
	hud.set_status("Teslimat sürüyor — sarsıntıya dayan!")
	shake.start()
	_refresh_hud()


func _on_extra_pocket_pressed() -> void:
	if not AdManager.can_offer(AdManager.Placement.EXTRA_POCKET):
		hud.toast("Ekstra cep şu an kullanılamıyor")
		return
	AdManager.show_rewarded(AdManager.Placement.EXTRA_POCKET)


func _on_tape_pressed() -> void:
	if grid.broken_count() == 0:
		hud.toast("Kırık paket yok")
		return
	if not AdManager.can_offer(AdManager.Placement.TAPE_RESCUE):
		hud.toast("Bant şu an kullanılamıyor")
		return
	AdManager.show_rewarded(AdManager.Placement.TAPE_RESCUE)


func _on_revive_pressed() -> void:
	if not AdManager.can_offer(AdManager.Placement.TAPE_RESCUE):
		hud.toast("Bant şu an kullanılamıyor")
		return
	AdManager.show_rewarded(AdManager.Placement.TAPE_RESCUE)


func _on_retry_pressed() -> void:
	GameManager.reset_run()
	hud.hide_fail()
	GameManager.goto_scene(&"game")


## Geri tusu (Android) / Esc: turu birak ve menuye don.
func _on_back_requested() -> void:
	GameManager.reset_run()
	GameManager.goto_scene(&"menu")


## Tur sonucunu toplar: paket bazli hasar + yildiz/odul hesabi.
func _build_result(success: bool) -> Dictionary:
	var placed: int = 0
	var damage_sum: float = 0.0
	var report: Array = []
	for node: Node in get_tree().get_nodes_in_group(Package.GROUP_DRAGGABLE):
		var pkg: PackagePhysics = node as PackagePhysics
		if pkg == null or not pkg.has_meta("cell"):
			continue
		placed += 1
		var damage: float = 0.0
		if pkg.is_broken:
			damage = 1.0
		elif pkg.kind == PackagePhysics.Kind.ICE:
			damage = pkg.melt_ratio()
		damage_sum += damage
		report.append({"label": pkg.display_label, "damage": damage})

	var average: float = 0.0 if placed == 0 else damage_sum / float(placed)
	var base_fee: int = int(GameData.value("balance", "delivery_base_fee", 120))
	var result: Dictionary = RunScoring.compute(average, base_fee)
	result["success"] = success
	result["placed"] = placed
	result["report"] = report
	return result


# --------------------------------------------------------------------------
# sarsıntı ve paket fiziği
# --------------------------------------------------------------------------
func _on_shake_step(intensity: float, delta: float) -> void:
	for node: Node in get_tree().get_nodes_in_group(Package.GROUP_DRAGGABLE):
		var pkg: PackagePhysics = node as PackagePhysics
		# Yalnızca çantaya yerleştirilmiş paketler sarsıntıya maruz kalır;
		# tepsideki paketler "sürüşe katılmaz" (meta "cell" yerleşimi işaretler).
		if pkg != null and pkg.has_meta("cell"):
			pkg.apply_shake(intensity, delta)
	hud.set_shake_bar(intensity)


func _on_shake_finished() -> void:
	if GameManager.phase != GameManager.Phase.DELIVERING:
		return
	hud.set_shake_bar(0.0)
	if grid.broken_count() == 0:
		# Basarili tur: sonuc ekranina gec (odul/yildiz orada gosterilir).
		GameManager.finish_run(_build_result(true))
	else:
		GameManager.fail_run(&"damaged_delivery")


func _on_package_placed(_package: Package, _cell: Vector2i) -> void:
	AudioService.play_drop()
	for node: Node in get_tree().get_nodes_in_group(Package.GROUP_DRAGGABLE):
		var pkg: PackagePhysics = node as PackagePhysics
		if pkg != null and pkg.kind == PackagePhysics.Kind.ICE and pkg.melt_ratio() > 0.15:
			AudioService.play_ice_clink()
			break
	_refresh_hud()


func _on_package_broken(pkg: PackagePhysics) -> void:
	hud.toast("%s kırıldı!" % pkg.display_label)
	# Kırılma anında oyun duraklatılır ve hata tetiklenir; kurtarma yolu
	# (ödüllü "Paketi Bandıyla Kurtar") bu ekrandan sunulur.
	GameManager.fail_run(&"glass_broken")
	_refresh_hud()


# --------------------------------------------------------------------------
# oyun durumu
# --------------------------------------------------------------------------
func _on_run_failed(reason: StringName) -> void:
	shake.stop()
	hud.set_shake_bar(0.0)
	hud.show_fail(_reason_text(reason))
	_refresh_hud()


func _on_run_revived() -> void:
	hud.hide_fail()
	hud.toast("Paket bantlandı, teslimat sürüyor")
	shake.resume()
	_refresh_hud()


func _on_phase_changed(_from: GameManager.Phase, _to: GameManager.Phase) -> void:
	_refresh_hud()


func _on_ad_started(_placement: AdManager.Placement) -> void:
	hud.show_ad_overlay(true)


func _on_rewarded_finished(placement: AdManager.Placement, success: bool) -> void:
	hud.show_ad_overlay(false)
	if not success:
		hud.toast("Reklam yüklenemedi")
		return
	match placement:
		AdManager.Placement.EXTRA_POCKET:
			if grid.expand_to(grid.cols + 1):
				AudioService.play_success()
				hud.toast("Ekstra cep açıldı — ızgara 5x5")
		AdManager.Placement.TAPE_RESCUE:
			if grid.repair_first_broken():
				AudioService.play_drop()
			GameManager.revive()
		_:
			pass
	_refresh_hud()


func _reason_text(reason: StringName) -> String:
	match reason:
		&"glass_broken":
			return "Cam kutu kırıldı. Teslimat hasarlı."
		&"damaged_delivery":
			return "Süre bitti, hasarlı paketler var."
		_:
			return "Teslimat başarısız."


func _refresh_hud() -> void:
	var phase: GameManager.Phase = GameManager.phase
	var can_start: bool = phase == GameManager.Phase.PACKING and grid.placed_count() > 0
	var can_pocket: bool = phase == GameManager.Phase.PACKING \
		and grid.cols < GridController.MAX_COLS \
		and AdManager.can_offer(AdManager.Placement.EXTRA_POCKET)
	var can_tape: bool = phase != GameManager.Phase.FAILED \
		and grid.broken_count() > 0 \
		and AdManager.can_offer(AdManager.Placement.TAPE_RESCUE)
	hud.set_buttons(can_start, can_pocket, can_tape)
	if phase == GameManager.Phase.PACKING and grid.placed_count() == 0:
		hud.set_status("Paketleri hücrelere yerleştir")
