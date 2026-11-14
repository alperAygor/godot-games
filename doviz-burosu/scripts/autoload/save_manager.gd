extends Node
## Oyun kaydı. Veri `data` sözlüğünde tutulur, user://save.json içine sürüm bilgisiyle yazılır.
## Mobilde uygulama arka plana atılınca otomatik kaydeder.

signal saved
signal loaded(data: Dictionary)

const SAVE_VERSION := 1

## Testler farklı bir yol kullanabilsin diye değişken.
var save_path := "user://save.json"
var data: Dictionary = {}


func _ready() -> void:
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func save_game() -> Error:
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"data": data,
	}
	var err := JsonIO.write_dict(save_path, payload)
	if err == OK:
		saved.emit()
	else:
		push_error("SaveManager: kayıt yazılamadı (hata %d)." % err)
	return err


func load_game() -> void:
	var payload := JsonIO.read_dict(save_path, {})
	payload = _migrate(payload)
	data = payload.get("data", {})
	loaded.emit(data)


## Kaydı sıfırlar ve boş halini yazar (dosya silinmez).
func reset_game() -> Error:
	data = {}
	return save_game()


## Kayıt formatı değişince eski sürümleri burada yükselt.
func _migrate(payload: Dictionary) -> Dictionary:
	var version: int = int(payload.get("version", SAVE_VERSION))
	if version > SAVE_VERSION:
		push_warning("SaveManager: kayıt daha yeni bir sürümden (%d)." % version)
	return payload
