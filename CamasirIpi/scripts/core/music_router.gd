class_name MusicRouter
extends RefCounted

## Müzik yönlendirmesi: hangi bağlamda (menü / oyun, mekân, gece) hangi parçanın çalacağı ve
## geçiş (crossfade) durumu. Saf mantık: ses sunucusu ve sahne bilgisi yok; `AudioService` uygular.
## Neden ayrı: çağrı noktaları (home.gd, game.gd) değişmeden aynı çağrılar doğru parçayı seçsin;
## eşleme ve "aynı parça tekrar istenirse yeniden başlatma" kuralı birim testle korunur.

enum Context { MENU, GAME }

const MENU_TRACK: String = "music_menu"
const DEFAULT_GAME_TRACK: String = "music_garden"
## Oyun içi parçalar: ortam sesi adı -> müzik adı (mekân kimliği + gece varyasyonu).
const TRACK_BY_AMBIENCE: Dictionary[String, String] = {
	"garden_ambience": "music_garden",
	"beach_ambience": "music_beach",
	"rooftop_ambience": "music_rooftop",
	"night_ambience": "music_night",
}
## Oyun içi (mekân) parçaları; menü bağlamında bunlardan biri istenirse menü teması çalar.
const GAME_TRACKS: Array[String] = ["music_garden", "music_beach", "music_rooftop", "music_night"]
const GAME_SCENE_FILE: String = "Game.tscn"
## Parça başına çalma seviyesi (dB, dosya seviyesine göre). Dosyalar aynı hedefe (-17 LUFS) normalleştirilmiştir;
## oyun içinde efektlerin altında kalsın diye oyun parçaları daha kısıktır.
const MENU_VOLUME_DB: float = 0.0
const GAME_VOLUME_DB: float = -4.0
## Geçiş süreleri (sn): menü <-> oyun biraz uzun, mekân/gece değişimi daha yumuşak ve uzun.
const CROSSFADE_MENU_S: float = 2.5
const CROSSFADE_PLACE_S: float = 4.0

## Şu an çalan (veya geçişle gelen) parça; boş = hiç.
var current: String = ""
var context: Context = Context.MENU
## Oyun bağlamında son bilinen ortam sesi adı: mekânı ve geceyi buradan çıkarırız.
var ambience_hint: String = ""


## Sahne yolundan bağlam: yalnız Game.tscn oyun; ana ekran, harita, mağaza vb. menü müziğiyle kalır.
static func context_for_scene(path: String) -> Context:
	return Context.GAME if path.get_file() == GAME_SCENE_FILE else Context.MENU


static func track_for_ambience(ambience_name: String) -> String:
	return String(TRACK_BY_AMBIENCE.get(ambience_name, DEFAULT_GAME_TRACK))


## İstenen müzik adını bağlama göre çözer: menüde bir mekân parçası istenirse (ör. eski çağrı
## `play_music("music_garden")`) menü teması; oyunda ise ortam ipucuna göre mekân parçası.
static func resolve(requested: String, for_context: Context, ambience: String = "") -> String:
	if requested.is_empty():
		return MENU_TRACK if for_context == Context.MENU else track_for_ambience(ambience)
	if for_context == Context.MENU:
		return MENU_TRACK if requested in GAME_TRACKS else requested
	# Oyunda mekân parçası istenirse ortam ipucu (mekân + gece) kazanır; ipucu yoksa istenen aynen çalar.
	if requested in GAME_TRACKS and not ambience.is_empty():
		return track_for_ambience(ambience)
	return requested


static func volume_db_for(track: String) -> float:
	return MENU_VOLUME_DB if track == MENU_TRACK else GAME_VOLUME_DB


static func crossfade_seconds(from_track: String, to_track: String) -> float:
	if from_track.is_empty():
		return CROSSFADE_MENU_S
	var from_menu: bool = from_track == MENU_TRACK
	var to_menu: bool = to_track == MENU_TRACK
	return CROSSFADE_MENU_S if from_menu != to_menu else CROSSFADE_PLACE_S


## Eşit güçlü geçiş: t 0..1 -> (çıkan, giren) kazanç dB. Toplam güç sabit kalır, ortada çukur olmaz.
static func equal_power_db(t: float) -> Vector2:
	var clamped: float = clampf(t, 0.0, 1.0)
	var out_gain: float = cos(clamped * PI * 0.5)
	var in_gain: float = sin(clamped * PI * 0.5)
	return Vector2(linear_to_db(maxf(out_gain, 0.0001)), linear_to_db(maxf(in_gain, 0.0001)))


## Önemli bir jingle'ın süresine göre müzik kısma süresi (sn): akıştan kısa, tavanı aşmaz.
static func duck_hold_seconds(stream_length: float, max_seconds: float) -> float:
	return clampf(stream_length, 0.0, max_seconds)


## Bir ses adı müziği kısmalı mı (ödül / sonuç jingle'ları).
static func is_duck_sound(sound_name: String, duck_names: Array[String]) -> bool:
	return sound_name in duck_names


# --- Durum geçişleri ----------------------------------------------------------------------------

## Sahne değişti: bağlamı günceller, çalması gereken parçayı döndürür.
func on_scene(path: String) -> String:
	context = context_for_scene(path)
	return target()


## Oyun düzeyi başladı / ortam sesi istendi: bağlam OYUN olur.
func on_ambience(ambience_name: String) -> String:
	context = Context.GAME
	ambience_hint = ambience_name
	return target()


## Doğrudan `play_music(ad)` çağrısı.
func on_play_music(requested: String) -> String:
	return resolve(requested, context, ambience_hint)


## Bağlama göre çalması gereken parça.
func target() -> String:
	if context == Context.MENU:
		return MENU_TRACK
	return track_for_ambience(ambience_hint)


## Hedef farklıysa geçiş gerekir. Aynı parça tekrar istenirse (yeniden başlatma yok) false.
func needs_switch(track: String) -> bool:
	return not track.is_empty() and track != current


func commit(track: String) -> void:
	current = track
