class_name LevelSession
extends Control
## SÖZLEŞME (yalnız lider değiştirir): kabuk (HUD, sonuç, reklam akışı) ile saha görünümü arasındaki tek yüzey.
## Görünüm bunu uygular (YardSession); kabuk kendi probeları için sahte bir uygulama (StubSession) kullanır.
## Kabuk sahanın içine bakmaz; görünüm kabuktan hiçbir şey çağırmaz.

## Her hamleden (ve geri al / baştan başlat sonrasında) sonra: o ana kadarki hamle sayısı ve seviyenin parı.
signal move_count_changed(moves: int, par: int)
## Geri alınacak bir şey var mı (HUD düğmesini açıp kapatır).
signal can_undo_changed(can_undo: bool)
## Seviye çözüldü; kutlama canlandırması bittikten sonra bir kez. result: { "level_id": String, "moves": int, "par": int }
signal solved(result: Dictionary)
## İpucu gösterimi bitti (HUD düğmesi yeniden açılır).
signal hint_finished

## Seviyeyi kurar ve oynanabilir hale getirir. Bilinmeyen kimlikte false döner.
func load_level(_level_id: String) -> bool:
	return false

## Son eylemi (sürüş ya da ayırma) geri alır.
func undo() -> void:
	pass

## Seviyeyi baştan başlatır (anında).
func restart() -> void:
	pass

## Ödül alındıktan sonra çağrılır: sıradaki doğru hamleyi sahada gösterir; bitince hint_finished.
func show_hint() -> void:
	pass

## Sayfa/reklam açıkken girdi kapatılır.
func set_input_enabled(_enabled: bool) -> void:
	pass

## Tanıtım kipi (ana ekran arka planı): seviyeyi kurar ve kayıtlı çözümünü döngüde kendi kendine oynatır.
## Girdi kapalıdır, hiçbir sinyal yayılmaz, ses çıkmaz. Bilinmeyen kimlikte false döner.
func start_demo(_level_id: String) -> bool:
	return false

## Tanıtım kipini durdurur (sahne değişirken).
func stop_demo() -> void:
	pass
