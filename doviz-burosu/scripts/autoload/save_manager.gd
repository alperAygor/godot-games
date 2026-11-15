extends Node
## Oyun kaydı. Veri `data` sözlüğünde tutulur, `save_path` içine sürüm ve sağlama toplamıyla yazılır.
##
## Dosya zarfı: {"version": int, "saved_at": float, "checksum": md5, "data": {...}} (sürüm 1'de checksum yoktu).
## Sağlamlık kuralları:
##  - Yazma atomiktir (geçici dosya + geri okuma doğrulaması + rename); önceki GEÇERLİ dosya `<yol>.bak` olarak saklanır.
##  - Yüklerken ana dosya sırayla: ayrıştırılır, zarf doğrulanır, sağlama toplamı denetlenir, göçle bugünkü sürüme getirilir.
##  - Ana dosya bozuksa SİLİNMEZ: `save.corrupt.<zaman>.json` olarak kenara alınır; yedek geçerliyse oradan devam edilir
##    ve ana dosya yedekten yeniden yazılır (oyuncu bir şey fark etmez). İkisi de kullanılamazsa boş kayıtla açılır
##    (bozuk kopya diskte kalır); bu durum `last_load_status` ve `load_issue` sinyaliyle bildirilir.
##  - Daha yeni sürümden bir kayıt (oyuncu eski sürüme döndü) olduğu gibi okunur, bilinmeyen alanlar korunur; ilk yazmadan
##    önce (yüklemede değil, ilk yazmada) `save.v<N>.json` kopyası bırakılır ki yeni sürüme dönülünce hiçbir şey kaybolmasın.
## Arka plana geçince / odak kaybında / kapanış isteğinde `flush()` çalışır (değişmediyse diske dokunmaz).
## Betikle (`-s`) çalışırken (testler, araçlar) varsayılan yol gerçek kullanıcı dosyası DEĞİL, `JsonIO.SANDBOX_DIR` altıdır.

signal saved
signal loaded(data: Dictionary)
## Yüklemede normal olmayan bir durum oldu (sessiz kurtarma, kayıp, göç, daha yeni sürüm). `status` = LOAD_* sabitlerinden biri.
signal load_issue(status: String)
## Yaşam döngüsü kaydından hemen önce: sahibi olan sistemler (GameSession) bellekteki durumu `data` içine yazar.
signal lifecycle_flush_requested

## Dosya zarfının şema sürümü. Format değişince: artır, `_migration_step` zincirine bir adım ekle, test yaz.
## (Kariyer bloğunun kendi sürümü `Career.SAVE_VERSION`; göç onu da yükseltir.)
const SAVE_VERSION := 2
## Yükleme sonuçları (`last_load_status`).
const LOAD_FRESH := "fresh"  # dosya yok: yeni oyuncu
const LOAD_OK := "ok"
const LOAD_MIGRATED := "migrated"  # eski sürüm bugünküne yükseltildi
const LOAD_RECOVERED := "recovered_backup"  # ana dosya bozuktu, yedekten kurtarıldı
const LOAD_UNRECOVERABLE := "unrecoverable"  # ana dosya bozuk, yedek de yok/bozuk: boş kayıt (bozuk kopya saklandı)
const LOAD_FUTURE := "future_version"  # kayıt daha yeni sürümden; olduğu gibi okundu

## Testler farklı bir yol kullanabilsin diye değişken.
var save_path := JsonIO.user_file("save.json")
var data: Dictionary = {}
var last_load_status := LOAD_FRESH
## En son diske yazılan/okunan içeriğin parmak izi (değişmediyse `flush` yazmaz).
var _synced_stamp := ""
## Başka sürümden okunan dosyanın sürümü: üzerine İLK yazılmadan önce `save.v<N>.json` kopyası alınır (yüklemek diske dokunmaz).
var _copy_pending_version := 0


func _ready() -> void:
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()


func _exit_tree() -> void:
	# Android'de geri tuşuyla çıkış `quit()` çağırır ve kapanış isteği bildirimi gelmez; son bir güvenlik yazması.
	# Betikli (test/araç) çalıştırmada yapılmaz: kayıt yolu testlerce değiştirilmiş olabilir.
	if not JsonIO.is_sandboxed():
		flush()


## Yaşam döngüsü kaydı: sahiplerden bellekteki durumu iste, içerik son yazılandan farklıysa diske yaz.
func flush() -> Error:
	lifecycle_flush_requested.emit()
	if _stamp() == _synced_stamp and FileAccess.file_exists(save_path):
		return OK
	return save_game()


func save_game() -> Error:
	if _copy_pending_version > 0:
		if int(JsonIO.inspect(save_path)["data"].get("version", 0)) == _copy_pending_version:
			_keep_version_copy(_copy_pending_version)
		_copy_pending_version = 0
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"checksum": checksum_of(data),
		"data": data,
	}
	var err := JsonIO.write_dict(save_path, payload, true)
	if err == OK:
		_synced_stamp = _stamp()
		saved.emit()
	else:
		push_error("SaveManager: kayıt yazılamadı (hata %d)." % err)
	return err


## Diskten yükler ve `last_load_status` değerini döner. Kurtarma kuralları dosya başındaki açıklamada.
func load_game() -> String:
	var backup_path := JsonIO.backup_path(save_path)
	var main := _read_valid(save_path)
	var status := LOAD_OK
	var payload: Dictionary = {}

	if main["status"] == JsonIO.READ_MISSING:
		var backup := _read_valid(backup_path)  # ana dosya yok ama yedek var: yazma rename'inden önce kesilmiş olabilir
		if backup["status"] == JsonIO.READ_OK:
			payload = backup["payload"]
			status = LOAD_RECOVERED
		else:
			status = LOAD_FRESH
	elif main["status"] == JsonIO.READ_OK:
		payload = main["payload"]
	else:
		# Ana dosya var ama kullanılamaz: kenara al, yedeğe bak.
		JsonIO.quarantine(save_path)
		var backup := _read_valid(backup_path)
		if backup["status"] == JsonIO.READ_OK:
			payload = backup["payload"]
			status = LOAD_RECOVERED
		else:
			status = LOAD_UNRECOVERABLE

	data = {}
	if not payload.is_empty():
		var version := int(payload["version"])
		if version > SAVE_VERSION:
			status = LOAD_FUTURE if status == LOAD_OK else status
			_copy_pending_version = version
			data = payload["data"]
		else:
			if version < SAVE_VERSION:
				_copy_pending_version = version
				if status == LOAD_OK:
					status = LOAD_MIGRATED
			data = migrate(payload)["data"]

	last_load_status = status
	_synced_stamp = _stamp()
	if status == LOAD_RECOVERED:
		# Ana dosyayı sağlam içerikle hemen yeniden yaz (yedek zaten sağlam kalır).
		save_game()
	if status in [LOAD_RECOVERED, LOAD_UNRECOVERABLE, LOAD_FUTURE, LOAD_MIGRATED]:
		load_issue.emit(status)
	loaded.emit(data)
	return status


## Kaydı sıfırlar ve boş halini yazar (dosya silinmez). Yedek de silinir: bilerek sıfırlanan ilerleme geri gelmesin.
func reset_game() -> Error:
	data = {}
	var err := save_game()
	DirAccess.remove_absolute(JsonIO.backup_path(save_path))
	return err


# --- Göç ----------------------------------------------------------------------------------------------------

## Zarfı adım adım `SAVE_VERSION` sürümüne yükseltir (yeni sözlük döner). Sürümü zaten güncel/yeni olan değişmeden döner.
## Bir adım eksikse (programlama hatası) uyarır ve o noktada durur; veri atılmaz.
func migrate(payload: Dictionary) -> Dictionary:
	var current := payload.duplicate(true)
	var version := int(current.get("version", 1))
	while version < SAVE_VERSION:
		var stepped := _migration_step(version, current)
		if stepped.is_empty():
			push_warning("SaveManager: %d -> %d göç adımı yok." % [version, version + 1])
			break
		current = stepped
		var next_version := int(current.get("version", version))
		if next_version <= version:  # adım sürümü ilerletmediyse sonsuz döngüye girme
			break
		version = next_version
	return current


## `from_version` -> `from_version + 1`. Yeni sürüm eklerken buraya `match` kolu ekle; adım `version`ı kendisi artırır.
func _migration_step(from_version: int, payload: Dictionary) -> Dictionary:
	match from_version:
		1:
			# v1 -> v2: zarfa sağlama toplamı eklendi (yazma sırasında hesaplanır) ve kariyer bloğunun kendi sürümü açıkça damgalandı.
			var upgraded := payload.duplicate(true)
			var body: Dictionary = upgraded.get("data", {})
			if body.get("career") is Dictionary and not (body["career"] as Dictionary).is_empty():
				# Çalışma anında yüklenir: autoload'ın `Career` sınıfına derleme bağımlılığı olursa çıkışta betikler "kullanımda" kalıyor.
				var career_script: GDScript = load("res://scripts/core/career.gd")
				body["career"] = career_script.migrate_dict(body["career"])
			upgraded["data"] = body
			upgraded["version"] = 2
			upgraded.erase("checksum")
			return upgraded
	return {}


# --- Doğrulama ---------------------------------------------------------------------------------------------

## Zarf biçimi geçerli mi? `{"version": >=1 sayı, "data": Dictionary}` ve varsa sağlama toplamı tutmalı.
static func is_valid_payload(payload: Dictionary) -> bool:
	var version: Variant = payload.get("version")
	if not (version is int or version is float) or int(version) < 1:
		return false
	if not (payload.get("data") is Dictionary):
		return false
	# Daha yeni sürümün sağlama algoritması farklı olabilir: yalnızca bildiğimiz sürümlerde denetle.
	if int(version) <= SAVE_VERSION and payload.has("checksum") and str(payload["checksum"]) != checksum_of(payload["data"]):
		return false
	return true


## İçeriğin sağlama toplamı. Ondalık/tamsayı farkı (5 ile 5.0) gidiş-dönüşte değişmesin diye önce bir kez JSON turu atılır.
static func checksum_of(body: Dictionary) -> String:
	var normalized: Variant = JsonIO.parse_quiet(JSON.stringify(body))
	return JSON.stringify(normalized, "", true).md5_text()


## {"status": JsonIO.READ_*, "payload": Dictionary}; zarf geçersizse durum READ_INVALID olur.
func _read_valid(path: String) -> Dictionary:
	var info := JsonIO.inspect(path)
	if info["status"] == JsonIO.READ_OK and not is_valid_payload(info["data"]):
		info["status"] = JsonIO.READ_INVALID
	return {"status": info["status"], "payload": info["data"]}


func _stamp() -> String:
	return "%s|%s" % [save_path, checksum_of(data)]


## Farklı sürümden okunan dosyayı bir kez `save.v<N>.json` olarak sakla (göç hatası olursa ya da oyuncu yeni sürüme dönerse
## elle geri dönülebilsin). Zaten varsa dokunmaz.
func _keep_version_copy(version: int) -> void:
	var target := save_path.get_basename() + ".v%d." % version + save_path.get_extension()
	if FileAccess.file_exists(save_path) and not FileAccess.file_exists(target):
		DirAccess.copy_absolute(save_path, target)
