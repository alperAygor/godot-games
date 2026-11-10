extends Node

## Oyun akışının tek sahibi: faz makinesi, başarısızlık/revive ve duraklatma.
## Sahneler kendi başlarına `get_tree().paused` değiştirmez; buradan geçer.

## Yeni degerler SONA eklenir: mevcut sayisal degerler korunur (testler ve
## araclar FAILED=2 varsayimini kullanir).
enum Phase { PACKING, DELIVERING, FAILED, DELIVERED, BOOT, MENU }

const SCENES: Dictionary = {
	&"boot": "res://scenes/Boot.tscn",
	&"menu": "res://scenes/Menu.tscn",
	&"game": "res://scenes/Main.tscn",
	&"result": "res://scenes/Result.tscn",
	&"upgrades": "res://scenes/Upgrades.tscn",
}

const SAVE_PATH_DEFAULT: String = "user://profile.save"

var phase: Phase = Phase.PACKING
## Son turun sonucu; Result sahnesi buradan okur.
var last_result: Dictionary = {}

## Kalici oyuncu verisi. Testler `save_path`i gecici bir dosyaya cekip gercek kaydi bozmaz.
var profile: PlayerProfile = PlayerProfile.create_default()
var save_path: String = SAVE_PATH_DEFAULT

signal phase_changed(from: Phase, to: Phase)
signal run_started()
signal run_failed(reason: StringName)
signal run_revived()
signal run_delivered()
signal back_requested()
signal currency_changed(amount: int)

var _failed_reason: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_profile()


func _notification(what: int) -> void:
	# Uygulama arka plana gecerken kaydet (mobilde en guvenilir an).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_profile()
		return
	# Android donanim geri tusu
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Masaustunde Esc — geri tusunun test edilebilir esi
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()


## Sahne gecisi tek yerden. Sahneler change_scene_to_file cagirmaz.
func goto_scene(scene_key: StringName) -> void:
	var path: Variant = SCENES.get(scene_key)
	if not (path is String):
		push_error("GameManager: bilinmeyen sahne '%s'" % scene_key)
		return
	get_tree().paused = false
	var error: Error = get_tree().change_scene_to_file(path as String)
	if error != OK:
		push_error("GameManager: sahne yuklenemedi (%s), hata %d" % [path, error])


## Turu bitirir: odulu isler, sonucu saklar ve sonuc ekranina gecer.
func finish_run(result: Dictionary) -> void:
	last_result = result
	add_currency(int(result.get("fee", 0)))
	add_reputation(int(result.get("reputation", 0)))
	profile.bump_stat("deliveries")
	if int(result.get("stars", 0)) >= 3:
		profile.bump_stat("perfect")
	save_profile()
	get_tree().paused = false
	_set_phase(Phase.DELIVERED)
	run_delivered.emit()
	goto_scene(&"result")


# --------------------------------------------------------------------------
# kayit / yukleme
# --------------------------------------------------------------------------
func add_currency(amount: int) -> void:
	profile.currency = maxi(0, profile.currency + amount)
	currency_changed.emit(profile.currency)


func spend_currency(amount: int) -> bool:
	if amount <= 0 or profile.currency < amount:
		return false
	profile.currency -= amount
	currency_changed.emit(profile.currency)
	return true


func add_reputation(delta: int) -> void:
	profile.reputation = clampi(profile.reputation + delta, 0, 5)


## Atomik yazma: once .tmp, sonra rename. Yarida kalan yazma kaydi bozmaz.
func save_profile() -> bool:
	var temp_path: String = save_path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("GameManager: kayit yazilamadi (%s)" % temp_path)
		return false
	file.store_string(JSON.stringify(profile.to_dictionary(), "\t"))
	file.close()
	var error: Error = DirAccess.rename_absolute(temp_path, save_path)
	if error != OK:
		push_error("GameManager: kayit yeniden adlandirilamadi (%d)" % error)
		return false
	return true


func load_profile() -> void:
	profile = PlayerProfile.create_default()
	if FileAccess.file_exists(save_path):
		var text: String = FileAccess.get_file_as_string(save_path)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			profile = PlayerProfile.from_dictionary(parsed as Dictionary)
			currency_changed.emit(profile.currency)
			return
		_backup_corrupt_save()
	# Kayit yok ya da okunamadi: ilk acilis sayilir ve baslangic sermayesi verilir.
	profile.currency = int(GameData.value("balance", "starting_currency", 0))
	currency_changed.emit(profile.currency)


func _backup_corrupt_save() -> void:
	push_warning("GameManager: kayit bozuk, yedeklenip sifirlandi (%s)" % save_path)
	DirAccess.copy_absolute(save_path, save_path + ".bak")
	DirAccess.remove_absolute(save_path)


func start_delivery() -> void:
	if phase != Phase.PACKING:
		return
	_failed_reason = &""
	_set_phase(Phase.DELIVERING)
	run_started.emit()


func fail_run(reason: StringName) -> void:
	if phase == Phase.FAILED or phase == Phase.DELIVERED:
		return
	_failed_reason = reason
	_set_phase(Phase.FAILED)
	run_failed.emit(reason)
	get_tree().paused = true


func revive() -> void:
	if phase != Phase.FAILED:
		return
	get_tree().paused = false
	_failed_reason = &""
	_set_phase(Phase.DELIVERING)
	run_revived.emit()


func complete_run() -> void:
	if phase == Phase.DELIVERED:
		return
	_set_phase(Phase.DELIVERED)
	run_delivered.emit()


func reset_run() -> void:
	get_tree().paused = false
	_failed_reason = &""
	AdManager.reset_run_limits()
	_set_phase(Phase.PACKING)


func failed_reason() -> StringName:
	return _failed_reason


func _set_phase(next: Phase) -> void:
	if next == phase:
		return
	var previous: Phase = phase
	phase = next
	phase_changed.emit(previous, next)
