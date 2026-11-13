class_name Boosters
extends RefCounted

## Saf mantık: güçlendiriciler (geri al, mandal sökücü, +1 askı). Sahneye bağımlı değildir.
## Asıl durum değişikliği `LaundryBoard` içindedir (undo/force_take/add_rack_slot); burada
## açılma seviyeleri, kullanılabilirlik kuralları ve seviye içi sınırlar tek yerde durur.
## Sayılar (cüzdan) bu sınıfın işi değildir: oyun bunları `Progress` autoload'undan ya da
## oturumluk yedekten okur (bkz. BoosterBar).

const UNDO: String = "undo"
const PIN_REMOVER: String = "pin_remover"
const EXTRA_SLOT: String = "extra_slot"
const IDS: Array[String] = [UNDO, PIN_REMOVER, EXTRA_SLOT]
## Açılma seviyeleri: oyuncu önce temel kuralı öğrensin, kurtarıcılar zorluk arttıkça gelsin.
const UNDO_FROM_LEVEL: int = 6
const PIN_REMOVER_FROM_LEVEL: int = 12
const EXTRA_SLOT_FROM_LEVEL: int = 18
## Askı görselinde 5 kanca var: +1 askı en fazla bu sayıya kadar çıkarabilir.
const MAX_RACK_SLOTS: int = 5
## Seviye başına +1 askı en fazla bir kez (tek seviyede askıyı sınırsız büyütmek zorluğu siler).
const EXTRA_SLOT_PER_LEVEL: int = 1
## Bilinmeyen kimlik hiç açılmaz.
const NEVER_LEVEL: int = 1 << 30

var _extra_used: int = 0


static func unlock_level(id: String) -> int:
	match id:
		UNDO:
			return UNDO_FROM_LEVEL
		PIN_REMOVER:
			return PIN_REMOVER_FROM_LEVEL
		EXTRA_SLOT:
			return EXTRA_SLOT_FROM_LEVEL
	return NEVER_LEVEL


static func is_unlocked(id: String, level: int) -> bool:
	return level >= unlock_level(id)


## Yeni seviye: seviye içi sınırlar sıfırlanır.
func reset() -> void:
	_extra_used = 0


## Bu an kullanılabilir mi (sayı denetimi hariç)?
func can_use(id: String, board: LaundryBoard) -> bool:
	if board == null:
		return false
	match id:
		UNDO:
			return board.can_undo()
		PIN_REMOVER:
			return not board.is_over() and not pin_targets(board).is_empty()
		EXTRA_SLOT:
			return not board.is_won() and _extra_used < EXTRA_SLOT_PER_LEVEL \
				and board.rack_slots() < MAX_RACK_SLOTS
	return false


## Son dokunuşu geri alır. Başarılıysa true (oyun görünümü tahtadan yeniden kurmalı).
func undo(board: LaundryBoard) -> bool:
	return can_use(UNDO, board) and board.undo()


## Mandal sökücünün hedef olabileceği parçalar: ipte olup normal yolla alınamayanlar
## (üstü kapalı ya da kilitli). Açık parçayı sökmek güçlendiriciyi boşa harcatır.
static func pin_targets(board: LaundryBoard) -> Array[int]:
	var result: Array[int] = []
	for id: int in board.item_ids():
		if is_pin_target(board, id):
			result.append(id)
	return result


## Patron seviyesinin henüz gelmemiş ekranındaki parça hedef olamaz (görünmüyor).
static func is_pin_target(board: LaundryBoard, id: int) -> bool:
	return board.is_on_line(id) and not board.is_hidden(id) and (not board.is_open(id) or board.is_locked(id))


## Hedef parçayı engellere bakmadan alır. Boş liste = kullanılamadı (hedef değil ya da
## askı dolu reddi: EVENT_RACK_FULL tek olay olarak döner; güçlendirici harcanmamalı).
func pin(board: LaundryBoard, id: int) -> Array[Dictionary]:
	if not is_pin_target(board, id) or board.is_over():
		return [] as Array[Dictionary]
	return board.force_take(id)


## Harcandı mı? (askı-dolu reddinde güçlendirici düşülmez)
static func pin_succeeded(events: Array[Dictionary]) -> bool:
	return not events.is_empty() and String(events[0]["type"]) == LaundryBoard.EVENT_PIN_REMOVED


func extra_slot(board: LaundryBoard) -> bool:
	if not can_use(EXTRA_SLOT, board):
		return false
	board.add_rack_slot()
	_extra_used += 1
	return true
