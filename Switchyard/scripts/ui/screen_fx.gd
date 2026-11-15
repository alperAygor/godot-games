class_name ScreenFx
extends RefCounted

## Ekran geçişlerinin tek kaynağı: kısa, hep aynı süre, parlama yok.
## Neden içerik düğümü: arka plan (opak) solmaz, yalnız üstündeki içerik solar; böylece geçişte
## pencerenin temizleme rengi (koyu) hiçbir zaman görünmez.
## Az hareket açıksa geçişler anında olur.

const FADE_IN_SECONDS: float = UiTokens.MOTION_SCREEN_SECONDS
const FADE_OUT_SECONDS: float = UiTokens.MOTION_SCREEN_SECONDS * 0.55


## İçerik solarak belirir (ekran açılışı).
static func fade_in(content: CanvasItem) -> void:
	if UiData.reduced_motion():
		return
	content.modulate.a = 0.0
	content.create_tween().tween_property(content, "modulate:a", 1.0, FADE_IN_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## İçerik solar, sonra `then` çalışır (ör. sahne değişimi). Aynı içerikte ikinci çağrı yok sayılır.
static func leave(content: CanvasItem, then: Callable) -> void:
	if content == null or not is_instance_valid(content) or content.has_meta(&"leaving"):
		return
	content.set_meta(&"leaving", true)
	if UiData.reduced_motion():
		then.call()
		return
	var tween: Tween = content.create_tween()
	tween.tween_property(content, "modulate:a", 0.0, FADE_OUT_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(then)
