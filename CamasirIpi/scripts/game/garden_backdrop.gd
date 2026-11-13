class_name GardenBackdrop
extends Node2D

## Arka plan: Blender'da 3B modellenip render edilen katmanlar. Hangi MEKÂNIN katmanlarının
## kurulacağı seviyeye göre LocationCycle'dan gelir (bahçe / sahil / çatı katı, data/locations.json).
## Her mekân aynı katman sözleşmesine uyar: uzak, orta, çit eşdeğeri, zemin + sallanan "kahraman"
## (ağaç/palmiye tacı), direkler, süs bitkileri. Askı ve bulutlar tüm mekânlarda ortaktır.
## Katmanlar derinliğe göre çok hafif kayar (parallaks), bulutlar süzülür, taç ve süsler sallanır.
## `storm` 0..1 arttıkça sahne kararır ve rüzgâr hızlanır. Bekleme askısı `danger` ile kırmızıya döner.
## Gün döngüsü: `set_level(n)` günün saatini (DayCycle) ve mekânı seçer; görünüm ~1.5 sn'de,
## mekân değişirse katman seti ~1.8 sn'de yumuşakça geçer (eski set geçiş bitince bellekten atılır).
## Ana ekran `set_level` çağırmaz: kurulumda oyuncunun kayıtlı seviyesinin mekânı gösterilir.
## Mevsim (SeasonCycle, 30 seviyede bir; mekândan bağımsız): aynı katman seti mevsime göre renk
## derecelendirmesiyle boyanır (SeasonLook + season_grade.gdshader), taç/çit gibi küçük parçalar
## mevsimlik dokuyla değişir, küçük zemin süsleri ve ortam efektleri (SeasonFx) eklenir. Mevsim
## değişince set, mekân geçişiyle aynı yolla yumuşakça yeniden kurulur; yalnız etkin mekân x mevsim
## dokuları bellekte kalır. Ana ekran da aynı yoldan oyuncunun güncel mevsimini gösterir.

## Ortak dokular (bulut, askı) ve bahçe dokuları burada.
const BG_DIR: String = "res://assets/sprites/bg/"
const DESIGN_WIDTH: float = 1080.0
const STORM_TINT: Color = Color(0.6, 0.65, 0.74)
const DANGER_TINT: Color = Color(1.0, 0.55, 0.5)
## Veri eksikse kullanılan bahçe varsayılanları — [dosya, sol-üst konum, parallaks genliği (px)].
const LAYERS: Array[Array] = [
	["bg_far", Vector2(0.0, 620.0), 3.0],
	["bg_mid", Vector2(0.0, 760.0), 5.0],
]
const FRONT_LAYERS: Array[Array] = [
	["bg_fence", Vector2(0.0, 990.0), 8.0],
	["bg_grass", Vector2(0.0, 1100.0), 11.0],
]
const CLOUDS: Array[Array] = [
	["cloud_1", Vector2(-120.0, 90.0), 0.9, 7.0],
	["cloud_2", Vector2(520.0, 200.0), 0.8, 10.0],
	["cloud_3", Vector2(180.0, 430.0), 0.6, 5.0],
]
const RACK_FILE: String = "rack"
const TREE_BASE: Vector2 = Vector2(150.0, 1230.0)
const TRUNK_BASE_PIXEL: Vector2 = Vector2(180.0, 900.0)
const CROWN_PIVOT_PIXEL: Vector2 = Vector2(320.0, 500.0)
const CROWN_PIVOT: Vector2 = Vector2(150.0, 670.0)
const CROWN_SWAY_DEGREES: float = 1.4
const POLE_TOP: float = 200.0
const POLE_AXIS_PIXEL: float = 80.0
const POLE_AXIS_INSET: float = 40.0
const RACK_RAIL_PIXEL_Y: float = 66.0
const RACK_HOOK_TIP_PIXEL_Y: float = 150.0
const FLOWERS: Array[Array] = [
	["flower_1", Vector2(95.0, 1640.0), 0.9], ["flower_2", Vector2(1005.0, 1770.0), 1.0],
	["flower_1", Vector2(905.0, 1250.0), 0.55], ["flower_2", Vector2(60.0, 1300.0), 0.5],
]
const FLOWER_PIVOT_PIXEL: Vector2 = Vector2(80.0, 240.0)
const FLOWER_SWAY_DEGREES: float = 4.0
const DECOR_MODE_SKEW: String = "skew"
const PARALLAX_SPEED: float = 0.22
const CLOUD_WRAP_MARGIN: float = 700.0
## Fırtınada bulutlar bu renge çekilir (aşama bulut tonuyla çarpılır).
const STORM_CLOUD_TINT: Color = Color(0.62, 0.65, 0.72)
## Direk/askı manzara tonunu bu oranda alır: gece de görünür kalsın, ama sahneden kopmasın.
const PROPS_TINT_SHARE: float = 0.4
## Süs bitkileri doygun renkli; sahne tonunu bu oranda alır.
const FLOWER_TINT_SHARE: float = 0.6
## HUD yazısı: gökyüzü parlaklığı bu değerin altına inince açık renge geçmeye başlar.
const HUD_DARK_LUMA_START: float = 0.5
const HUD_DARK_LUMA_RANGE: float = 0.25
const HUD_LIGHT_TEXT: Color = Color(0.94, 0.96, 1.0)
## Hata ayıklama: `-- --phase=N` o gün aşamasını zorlar (ekran görüntüsü için).
const PHASE_ARG: String = "--phase="
## Hata ayıklama: `-- --level=N` (oyun sahnesiyle aynı argüman) ana ekranda da o seviyenin
## mekânını gösterir; kayda dokunmadan mekân çekimi alınabilsin.
const LEVEL_ARG: String = "--level="
## Fırtına/tehlike bundan küçük değişince tonlar yeniden yazılmaz: renkte < 1/255 fark eder
## (görünmez), ama yavaşça sönen fırtına her kare ~60 sprite'a yazmayı tetiklemez.
const TINT_EPSILON: float = 0.002
## Mekân geçişi (crossfade) süresi: gün geçişinden biraz uzun, "yolculuk" hissi için.
const PLACE_FADE_SECONDS: float = 1.8
## Yeni set erken belirir, eski set geç söner: arada gökyüzü yarı saydam iki katmandan
## "delik" gibi görünmesin.
const PLACE_FADE_IN_END: float = 0.65
const PLACE_FADE_OUT_START: float = 0.35

var storm: float = 0.0
var danger: float = 0.0
## Çamaşır/sepet katmanına uygulanacak çok hafif ortam tonu (game.gd okur).
var garment_tint: Color = Color.WHITE

var _current: DayLook = DayLook.new()
var _fade_from: DayLook = DayLook.new()
var _fade_to: DayLook = DayCycle.look_for_phase(0)
var _fade: float = 1.0
var _level_seen: int = -1
var _forced_phase: int = -1
var _sky_node: Node2D = null
var _sky_view: SkyView = null
var _fireflies: Fireflies = null
var _season_fx: SeasonFx = null
var _view: Vector2 = Vector2(DESIGN_WIDTH, 1920.0)
var _cover: float = 1.0

var _width: float = DESIGN_WIDTH
var _clouds: Array[Array] = []
var _rack: Sprite2D = null
## Manzara katmanları (ekran 1080'den genişse büyütülür); direk ve askı oyunla hizalı kalır.
var _scenery: Node2D = null
var _props: Node2D = null
## Etkin mekân seti ve (geçiş sırasında) sönen önceki set. `_sets` ikisini kare döngüsü için
## tutar; yalnız mekân değişince yeniden kurulur (kare başı bellek ayırma yok).
var _active: PlaceSet = null
var _leaving: PlaceSet = null
var _sets: Array[PlaceSet] = []
var _place_fade: float = 1.0
## Etkin geçişin süresi: mekân değişiminde PLACE_FADE_SECONDS, yalnız mevsim değişiminde biraz daha uzun.
var _place_fade_seconds: float = PLACE_FADE_SECONDS
## Son uygulanan fırtına/tehlike ve "ton yeniden uygulanmalı" bayrağı: değişmeyen kareler yazılmaz.
var _applied_storm: float = -1.0
var _applied_danger: float = -1.0
var _tints_dirty: bool = true
## Dokular uygulama boyunca önbellekte tutulur. Neden: ana ekran ve oyun aynı mekânı
## kullanır; her sahne geçişinde ~20 MB doku silinip yeniden yükleniyordu (geçiş anında takılma).
## Yalnız ETKİN mekânın dokuları kalır: mekân değişince eskisinin dokuları geçiş sonunda atılır.
static var _textures: Dictionary[String, Texture2D] = {}
## İş parçacığında yüklenmesi istenip henüz alınmamış yollar (çıkışta toplanır).
static var _requested: Array[String] = []
## Sahnede canlı olan arka planlar: önbellek budaması yalnız bunların (ve oyuncunun kayıtlı
## seviyesinin) mekânlarını tutar. Neden: önbellek sahneler arası paylaşıldığı için önceki sahnenin
## (ör. haritadan tekrar oynanan eski seviye, başka mevsim) dokuları hiç atılmıyordu; her yeni
## mekân x mevsim ~4-9 MiB doku belleğini kalıcı büyütüyordu.
static var _live: Array[GardenBackdrop] = []
## Bu oturumda "yeni yer" afişi gösterilmiş seviyeler (aynı seviye tekrarında yeniden çıkmasın).
static var _banner_shown: Dictionary[int, bool] = {}
## Aynı amaçla "mevsim geldi" afişi gösterilmiş seviyeler.
static var _season_banner_shown: Dictionary[int, bool] = {}


## Bir mekânın sahnedeki düğümleri ve kare döngüsünün ihtiyaç duyduğu önceden hazır listeler.
class PlaceSet:
	var id: String = ""
	var season: String = ""
	var scenery_root: Node2D = null
	var props_root: Node2D = null
	var parallax: Array[Sprite2D] = []
	var parallax_base: PackedFloat32Array = PackedFloat32Array()
	var parallax_amp: PackedFloat32Array = PackedFloat32Array()
	## Sahne tonu uygulanan sprite'lar (katmanlar + kahraman); süsler ayrı, daha hafif tonlanır.
	var tinted: Array[Sprite2D] = []
	var decor: Array[Sprite2D] = []
	var decor_amp: PackedFloat32Array = PackedFloat32Array()
	var decor_skew: Array[bool] = []
	var crown: Sprite2D = null
	var crown_sway: float = CROWN_SWAY_DEGREES
	var lights: Array[WindowLights] = []
	var glints: SeaGlints = null
	var firefly_scale: float = 1.0
	var paths: Array[String] = []

	func set_alpha(alpha: float) -> void:
		scenery_root.modulate.a = alpha
		props_root.modulate.a = alpha

	func free_nodes() -> void:
		scenery_root.queue_free()
		props_root.queue_free()


## Sahilde deniz bandında kıpırdayan yumuşak ışık pırıltıları: gündüz güneş, gece ay ışığı.
## İki grup ters fazda söner/parlar ve çok yavaş yana kayar; kare başına yalnız 2 grup yazılır.
class SeaGlints extends Node2D:
	const DAY_ALPHA: float = 0.42
	const NIGHT_ALPHA: float = 0.36
	const MOON_GLINT: Color = Color(0.86, 0.92, 1.0)
	const SUN_WHITEN: float = 0.6
	const PULSE_SPEED: float = 1.1
	const DRIFT_SPEED: float = 0.25
	const DRIFT_PIXELS: float = 7.0
	const LENGTH_MIN: float = 14.0
	const LENGTH_MAX: float = 34.0
	## Yassı parıltı: uzunluğun bu oranı kalınlık olur (su yüzeyinde yatay çizgi).
	const THICKNESS_SHARE: float = 0.12
	const VISIBLE_EPSILON: float = 0.01
	var _groups: Array[Node2D] = []

	func setup(spec: Dictionary) -> void:
		var raw_rect: Array = spec.get("rect", [0, 0, 0, 0]) as Array
		var area: Rect2 = Rect2(float(raw_rect[0]), float(raw_rect[1]), float(raw_rect[2]), float(raw_rect[3]))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(spec.get("seed", 1))
		for group_index: int in range(2):
			var group: Node2D = Node2D.new()
			add_child(group)
			_groups.append(group)
		for index: int in range(int(spec.get("count", 0))):
			# Ufka yakın (üst) pırıltılar daha küçük: perspektif.
			var depth: float = rng.randf()
			var length: float = lerpf(LENGTH_MIN, LENGTH_MAX, depth)
			var glint: Sprite2D = GlowTextures.make_sprite(GlowTextures.dot(), length, true)
			glint.scale.y *= THICKNESS_SHARE
			glint.position = area.position + Vector2(rng.randf() * area.size.x, depth * area.size.y)
			_groups[index % 2].add_child(glint)
		visible = false

	func apply(look: DayLook, time: float) -> void:
		var day: float = look.sun_alpha * DAY_ALPHA
		var night: float = look.moon_alpha * NIGHT_ALPHA
		var strength: float = maxf(day, night)
		var on: bool = strength > VISIBLE_EPSILON
		if visible != on:
			visible = on
		if not on:
			return
		var tint: Color = look.sun_color.lerp(Color.WHITE, SUN_WHITEN) if day >= night else MOON_GLINT
		for index: int in range(_groups.size()):
			var pulse: float = 0.5 + 0.5 * sin(time * PULSE_SPEED + float(index) * PI)
			_groups[index].modulate = Color(tint.r, tint.g, tint.b, strength * pulse)
			_groups[index].position.x = sin(time * DRIFT_SPEED + float(index) * 1.7) * DRIFT_PIXELS


## Yeni mekâna ilk girişte üstte beliren tek satırlık, sakin afiş ("Yeni durak: Sahil").
## Ayrı CanvasLayer: katman 0 = oyun dünyasıyla (çamaşırlar) aynı düzlemde ama ondan sonra çizilir;
## HUD ve açılan pencerelerin (katman 1: tanıtım kartı, duraklat) karartmasının ALTINDA kalır.
## Kendi kendini yok eder.
class PlaceBanner extends CanvasLayer:
	const LAYER: int = 0
	const FONT_SIZE: int = 34
	const PANEL_COLOR: Color = Color(0.985, 0.972, 0.94, 0.9)
	const SHADOW_COLOR: Color = Color(0.18, 0.2, 0.3, 0.1)
	const SHADOW_SIZE: int = 14
	const CORNER_RADIUS: int = 36
	const PAD_X: float = 40.0
	const PAD_Y: float = 10.0
	const BOX_HEIGHT: float = 120.0
	## Güvenli alanın üstünden itibaren afiş merkezi: HUD başlığının altı, en üst ipin üstü.
	const TOP_OFFSET: float = 158.0
	const RISE_PIXELS: float = 18.0
	const IN_SECONDS: float = 0.7
	const HOLD_SECONDS: float = 2.2
	const OUT_SECONDS: float = 0.8
	const ICON_SIZE: float = 56.0
	const ICON_GAP: int = 14
	## İkinci afişin beklemesi için bir afişin toplam ekranda kalma süresi.
	const TOTAL_SECONDS: float = IN_SECONDS + HOLD_SECONDS + OUT_SECONDS

	## `delay`: aynı seviyede iki afiş (yeni yer + yeni mevsim) üst üste binmesin diye ikincisi bekler.
	## `icon`: mevsim simgesi (yaprak, kar tanesi ...); yoksa yalnız yazı.
	func show_text(text: String, view: Vector2, delay: float = 0.0, icon: Texture2D = null) -> void:
		layer = LAYER
		var box: CenterContainer = CenterContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.size = Vector2(view.x, BOX_HEIGHT)
		var top: float = UiKit.safe_insets(view).y + TOP_OFFSET - BOX_HEIGHT * 0.5
		box.position = Vector2(0.0, top + RISE_PIXELS)
		box.modulate.a = 0.0
		add_child(box)
		var panel: PanelContainer = PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = PANEL_COLOR
		style.set_corner_radius_all(CORNER_RADIUS)
		style.shadow_color = SHADOW_COLOR
		style.shadow_size = SHADOW_SIZE
		style.content_margin_left = PAD_X
		style.content_margin_right = PAD_X
		style.content_margin_top = PAD_Y
		style.content_margin_bottom = PAD_Y
		style.anti_aliasing = true
		panel.add_theme_stylebox_override("panel", style)
		box.add_child(panel)
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", ICON_GAP)
		panel.add_child(row)
		if icon != null:
			var picture: TextureRect = TextureRect.new()
			picture.texture = icon
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.custom_minimum_size = Vector2.ONE * ICON_SIZE
			row.add_child(picture)
		row.add_child(UiKit.label(text, FONT_SIZE, UiKit.TEXT))
		var tween: Tween = box.create_tween()
		if delay > 0.0:
			tween.tween_interval(delay)
		tween.tween_property(box, "modulate:a", 1.0, IN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(box, "position:y", top, IN_SECONDS)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_interval(HOLD_SECONDS)
		tween.tween_property(box, "modulate:a", 0.0, OUT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)


func setup(view_size: Vector2, rack_hook_y: float) -> void:
	_view = view_size
	_width = view_size.x
	# Geniş ekranlarda (tablet) manzara kenarlarda boşluk bırakmasın diye büyütülür.
	_cover = maxf(view_size.x / DESIGN_WIDTH, 1.0)
	# Gök cisimleri/bulutlar manzaranın arkasında, ama sahne tonundan etkilenmeyen ayrı katmanda.
	_sky_node = Node2D.new()
	_sky_node.scale = Vector2.ONE * _cover
	add_child(_sky_node)
	_sky_view = SkyView.new()
	_sky_node.add_child(_sky_view)
	_sky_view.setup()
	_scenery = Node2D.new()
	_scenery.scale = Vector2.ONE * _cover
	add_child(_scenery)
	var start_level: int = _start_level()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(PHASE_ARG):
			_forced_phase = posmod(int(arg.substr(PHASE_ARG.length())), DayCycle.PHASE_COUNT)
	_props = Node2D.new()
	_props.position.x = (view_size.x - DESIGN_WIDTH) * 0.5
	add_child(_props)
	_width = view_size.x / _cover
	for spec: Array in CLOUDS:
		var cloud: Sprite2D = _sprite(_sky_node, BG_DIR, String(spec[0]), spec[1] as Vector2)
		cloud.scale = Vector2.ONE * float(spec[2])
		_clouds.append([cloud, float(spec[3])])
	_sky_view.lift_moon(_sky_node)
	# Ateş böcekleri tüm mekân setlerinin önünde, direklerin arkasında uçar; ışıklı olduğu için tonlanmaz.
	_fireflies = Fireflies.new()
	_scenery.add_child(_fireflies)
	_fireflies.setup()
	# Mevsim efektleri ateş böceklerinin önünde, direk/askının arkasında (çamaşırın hep arkasında).
	_season_fx = SeasonFx.new()
	_scenery.add_child(_season_fx)
	_season_fx.set_fade_seconds(SeasonLook.fade_seconds())
	# Askı: kanca uçları oyunun askı hizasına (çamaşırın asıldığı nokta) oturur. Tüm mekânlarda ortak.
	_rack = _sprite(_props, BG_DIR, RACK_FILE, Vector2((DESIGN_WIDTH - 1024.0) * 0.5, rack_hook_y - RACK_HOOK_TIP_PIXEL_Y))
	var place_id: String = LocationCycle.location_for(start_level)
	var season: String = SeasonLook.season_for_level(start_level)
	_active = _build_place(place_id, season)
	_refresh_sets()
	_live.append(self)
	_prune_cache()
	_season_fx.set_season(season, true)
	# İlk set_level() çağrısı gelene kadar geçerli bir görünüm olsun: ana ekranda kayıtlı seviyenin
	# mekânı ve mevsimi, şafak (ya da zorlanan aşama) paletiyle.
	_current.copy_from(LocationCycle.look_for(maxi(_forced_phase, 0), place_id, season))
	_apply_look(0.0)


## Seviye numarasına göre günün saatini ve mekânı ayarlar. İlk çağrı anında oturur; sonrakiler
## önceki görünümden DayCycle.FADE_SECONDS sürede yumuşakça geçer. Mekân değişirse katman seti
## de PLACE_FADE_SECONDS sürede geçer. Aynı seviye tekrarı geçiş başlatmaz.
func set_level(level: int) -> void:
	if level == _level_seen:
		return
	var first: bool = _level_seen < 0
	_level_seen = level
	var place_id: String = LocationCycle.location_for(level)
	var season: String = SeasonLook.season_for_level(level)
	_fade_from.copy_from(_current)
	_fade_to = LocationCycle.look_for_level(level, place_id, _forced_phase, season)
	_fade = 1.0 if first else 0.0
	if place_id != _active.id or season != _active.season:
		if first:
			_replace_place_now(place_id, season)
		else:
			# Yalnız mevsim değişiyorsa geçiş biraz daha uzun: "mevsim dönüyor" hissi, yolculuk değil.
			_place_fade_seconds = PLACE_FADE_SECONDS if place_id != _active.id else SeasonLook.fade_seconds()
			_begin_place_fade(place_id, season)
	_season_fx.set_season(season, first)
	if first:
		_current.copy_from(_fade_to)
		_apply_look(0.0)
	_tints_dirty = true
	var place_banner: bool = _maybe_show_banner(level, place_id)
	_maybe_show_season_banner(level, season, PlaceBanner.TOTAL_SECONDS + SeasonLook.banner_gap() if place_banner else 0.0)
	# Sonraki seviye yeni mekânda/mevsimdeyse dokuları şimdiden iş parçacığında yüklenir: geçiş anında
	# ~4 MB doku eşzamanlı yüklenip seviye başında takılma yapmasın.
	var next_id: String = LocationCycle.location_for(level + 1)
	var next_season: String = SeasonLook.season_for_level(level + 1)
	if next_id != place_id or next_season != season:
		_request_paths(_all_paths(next_id, next_season))


## Gökyüzü koyulaşınca (alacakaranlık/gece) koyu HUD yazısı okunmaz olur; bu yüzden
## varsayılan yazı rengi hedef aşamaya göre açık tona çekilir (seviye başında çağrılır).
func hud_text_color(default_color: Color) -> Color:
	var darkness: float = clampf((HUD_DARK_LUMA_START - _fade_to.sky_top.get_luminance()) / HUD_DARK_LUMA_RANGE, 0.0, 1.0)
	return default_color.lerp(HUD_LIGHT_TEXT, darkness)


## Aşama paleti + fırtına birleşik gökyüzü üst rengi (game.gd gradyanı için).
func sky_top(storm_color: Color, weight: float) -> Color:
	return _current.sky_top.lerp(_dimmed(storm_color), weight)


func sky_bottom(storm_color: Color, weight: float) -> Color:
	return _current.sky_bottom.lerp(_dimmed(storm_color), weight)


## Etkin mekânın kimliği (ana ekran / testler için bilgi amaçlı).
func place_id() -> String:
	return _active.id if _active != null else ""


## Etkin mevsim ("summer" | "autumn" | "winter" | "spring"): ses/analitik gibi sistemler için.
func season_id() -> String:
	return _active.season if _active != null else ""


## Fırtına rengi geceleyin de parlak gri kalmasın: aşamanın storm_dim değeriyle koyulur.
func _dimmed(color: Color) -> Color:
	return Color(color.r * _current.storm_dim, color.g * _current.storm_dim, color.b * _current.storm_dim, color.a)


## Ana ekran `set_level` çağırmaz: başlangıç mekânı `--level=` hata ayıklama argümanından ya da
## oyuncunun kayıtlı seviyesinden (Progress) seçilir.
func _start_level() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(LEVEL_ARG):
			return maxi(int(arg.substr(LEVEL_ARG.length())), 1)
	return _saved_level()


static func _saved_level() -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return 1
	var progress: Node = tree.root.get_node_or_null(^"Progress")
	if progress == null or not progress.has_method(&"level"):
		return 1
	return maxi(int(progress.call(&"level")), 1)


## "Yeni durak" afişi; gösterildiyse true (aynı seviyedeki mevsim afişi onun ardından gelir).
func _maybe_show_banner(level: int, place_id: String) -> bool:
	if level <= 1 or not LocationCycle.is_first_level_of_location(level) or _banner_shown.has(level):
		return false
	var key: String = LocationCycle.name_key(place_id)
	if key.is_empty():
		return false
	_banner_shown[level] = true
	var banner: PlaceBanner = PlaceBanner.new()
	add_child(banner)
	banner.show_text(Loc.f("PLACE_ARRIVE", [Loc.t(key)]), _view)
	return true


## "Sonbahar geldi" afişi: mevsimin ilk seviyesinde, simgesiyle; aynı seviyede yer afişi varsa ondan sonra.
func _maybe_show_season_banner(level: int, season: String, delay: float) -> void:
	if not SeasonLook.announces(level) or _season_banner_shown.has(level):
		return
	var key: String = SeasonLook.arrive_key(season)
	if key.is_empty():
		return
	_season_banner_shown[level] = true
	var icon_path: String = SeasonLook.icon_path(season)
	var icon: Texture2D = load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null
	var banner: PlaceBanner = PlaceBanner.new()
	add_child(banner)
	banner.show_text(Loc.t(key), _view, delay, icon)


## İlk seviye farklı bir mekândaysa (ör. oyun doğrudan 52. seviyeden açıldı) geçiş beklenmeden kurulur.
func _replace_place_now(place_id: String, season: String) -> void:
	var old: PlaceSet = _active
	_active = _build_place(place_id, season)
	old.free_nodes()
	_forget_textures(old, _active)
	_refresh_sets()
	_prune_cache()


func _begin_place_fade(place_id: String, season: String) -> void:
	if _leaving != null:
		# Geçiş sürerken yine değişirse (pratikte olmaz) yarım kalan eski set hemen atılır.
		_leaving.free_nodes()
		_forget_textures(_leaving, _active)
	_leaving = _active
	_active = _build_place(place_id, season)
	_active.set_alpha(0.0)
	_place_fade = 0.0
	_refresh_sets()


func _finish_place_fade() -> void:
	_leaving.free_nodes()
	_forget_textures(_leaving, _active)
	_leaving = null
	_active.set_alpha(1.0)
	_refresh_sets()


func _refresh_sets() -> void:
	_sets.clear()
	if _leaving != null:
		_sets.append(_leaving)
	_sets.append(_active)
	_tints_dirty = true


## Mekân x mevsim setini kurar: manzara düğümü ateş böceklerinin hemen arkasına, direkler askının
## arkasına. Mevsim: katmanlara derecelendirme malzemesi, varsa mevsimlik doku, zemin süsleri.
func _build_place(place_id: String, season: String) -> PlaceSet:
	var data: Dictionary = LocationCycle.data_for(place_id)
	var dir: String = String(data.get("dir", BG_DIR))
	var place: PlaceSet = PlaceSet.new()
	place.id = place_id
	place.season = season
	place.firefly_scale = float(data.get("fireflies", 1.0))
	place.scenery_root = Node2D.new()
	_scenery.add_child(place.scenery_root)
	_scenery.move_child(place.scenery_root, _fireflies.get_index())
	place.props_root = Node2D.new()
	_props.add_child(place.props_root)
	_props.move_child(place.props_root, _rack.get_index())
	var layers: Array[Sprite2D] = []
	for spec: Dictionary in _layer_specs(data, "back", LAYERS):
		layers.append(_add_layer(place, dir, spec))
	var hero: Dictionary = data.get("hero", {}) as Dictionary
	var hero_base: Vector2 = _vec(hero, "base", TREE_BASE)
	# Kahraman (ağaç/palmiye) çitin arkasında durur; taç ayrı sprite olduğu için rüzgârda sallanır.
	place.tinted.append(_season_sprite(place, dir, String(hero.get("trunk", "tree_trunk")),
		hero_base - _vec(hero, "trunk_base_px", TRUNK_BASE_PIXEL)))
	place.crown = _season_sprite(place, dir, String(hero.get("crown", "tree_crown")), Vector2.ZERO)
	place.crown.offset = -_vec(hero, "crown_pivot_px", CROWN_PIVOT_PIXEL)
	place.crown.position = _vec(hero, "crown_pivot", CROWN_PIVOT)
	place.crown_sway = float(hero.get("sway", CROWN_SWAY_DEGREES))
	place.tinted.append(place.crown)
	for spec: Dictionary in _layer_specs(data, "front", FRONT_LAYERS):
		layers.append(_add_layer(place, dir, spec))
	# Uzun ekranlarda (dar-uzun telefon) zemin ekranın altına kadar uzatılır.
	var ground: Sprite2D = layers[layers.size() - 1]
	var needed: float = _view.y / _cover - ground.position.y
	if ground.texture != null and needed > ground.texture.get_size().y:
		ground.scale.y = needed / ground.texture.get_size().y
	_add_decals(place, place.parallax_amp[place.parallax_amp.size() - 1])
	# Işıklar ait oldukları katmanın çocuğu: parallaks ile birlikte kayar, katman tonundan etkilenmez
	# (katmanlar self_modulate ile tonlanır).
	for raw: Variant in (data.get("lights", [{}]) as Array):
		var light_spec: Dictionary = raw as Dictionary
		var lights: WindowLights = WindowLights.new()
		layers[clampi(int(light_spec.get("layer", 0)), 0, layers.size() - 1)].add_child(lights)
		if light_spec.has("points"):
			lights.setup_from(light_spec)
		else:
			lights.setup()
		place.lights.append(lights)
	var glint_spec: Dictionary = data.get("glints", {}) as Dictionary
	if not glint_spec.is_empty():
		place.glints = SeaGlints.new()
		layers[clampi(int(glint_spec.get("layer", 0)), 0, layers.size() - 1)].add_child(place.glints)
		place.glints.setup(glint_spec)
	# Direkler iki kenarda; sağdaki aynalanır. Oyun koordinatlarıyla hizalıdır (büyütülmez).
	var pole_file: String = String(data.get("pole", "pole"))
	var pole_material: ShaderMaterial = SeasonLook.make_material(SeasonLook.prop_grade(place_id, season, pole_file))
	var left_pole: Sprite2D = _sprite(place.props_root, dir, pole_file, Vector2(POLE_AXIS_INSET - POLE_AXIS_PIXEL, POLE_TOP), place)
	left_pole.material = pole_material
	var right_pole: Sprite2D = _sprite(place.props_root, dir, pole_file,
		Vector2(DESIGN_WIDTH - POLE_AXIS_INSET - POLE_AXIS_PIXEL, POLE_TOP), place)
	right_pole.flip_h = true
	right_pole.material = pole_material
	# Kışın bahçe çiçekleri gizlenir (karda lale olmaz); yerini mevsim süsleri alır.
	var decor_specs: Array[Dictionary] = []
	if SeasonLook.shows_decor(place_id, season):
		decor_specs = _decor_specs(data)
	for spec: Dictionary in decor_specs:
		var decor: Sprite2D = _season_sprite(place, dir, String(spec.get("file", "")), Vector2.ZERO)
		decor.offset = -_vec(spec, "pivot_px", FLOWER_PIVOT_PIXEL)
		decor.position = _vec(spec, "pos", Vector2.ZERO)
		decor.scale = Vector2.ONE * float(spec.get("scale", 1.0))
		place.decor.append(decor)
		place.decor_amp.append(float(spec.get("sway", FLOWER_SWAY_DEGREES)))
		place.decor_skew.append(String(spec.get("mode", "")) == DECOR_MODE_SKEW)
	return place


## Parallaks katmanı. Neden yatay taşma payı: katman ±genlik kadar kaydığında kenarda gökyüzü
## şeridi açılıyordu; doku genlik kadar geniş çizilir (en çok %2 — gözle fark edilmez).
func _add_layer(place: PlaceSet, dir: String, spec: Dictionary) -> Sprite2D:
	var amp: float = float(spec.get("parallax", 0.0))
	var top_left: Vector2 = _vec(spec, "pos", Vector2.ZERO)
	var layer: Sprite2D = _season_sprite(place, dir, String(spec.get("file", "")), top_left)
	if layer.texture != null and amp > 0.0:
		var width: float = layer.texture.get_size().x
		layer.scale.x = (width + 2.0 * amp) / width
	place.parallax.append(layer)
	place.parallax_base.append(top_left.x - amp)
	place.parallax_amp.append(amp)
	place.tinted.append(layer)
	return layer


## Manzara sprite'ı, mevsime göre: mevsimlik dokusu varsa o yüklenir (aynı boyut ve çapa), yoksa
## mekânın dokusu derecelendirme malzemesiyle boyanır (yazın malzeme yok: bugünkü maliyet).
func _season_sprite(place: PlaceSet, dir: String, file_name: String, top_left: Vector2) -> Sprite2D:
	var swap: String = SeasonLook.swap_path(place.id, place.season, file_name)
	var sprite: Sprite2D = null
	if not swap.is_empty() and ResourceLoader.exists(swap):
		sprite = _sprite_at(place.scenery_root, swap, top_left, place)
	else:
		sprite = _sprite(place.scenery_root, dir, file_name, top_left, place)
	sprite.material = SeasonLook.make_material(SeasonLook.grade_for(place.id, place.season, file_name))
	return sprite


## Mevsimin küçük zemin süsleri (kar yığını, yaprak yığını, lale ...): zemin katmanının önünde,
## süs bitkilerinin arkasında; zeminle aynı parallaksla kayar, gün tonunu alır.
func _add_decals(place: PlaceSet, amp: float) -> void:
	for spec: Dictionary in SeasonLook.decals(place.id, place.season):
		var path: String = String(spec.get("file", ""))
		if not ResourceLoader.exists(path):
			continue
		var top_left: Vector2 = _vec(spec, "pos", Vector2.ZERO)
		var decal: Sprite2D = _sprite_at(place.scenery_root, path, top_left, place)
		decal.scale = Vector2.ONE * float(spec.get("scale", 1.0))
		decal.flip_h = bool(spec.get("flip", false))
		place.parallax.append(decal)
		place.parallax_base.append(top_left.x - amp)
		place.parallax_amp.append(amp)
		place.tinted.append(decal)


## Katman listesi: veride varsa o, yoksa bahçe sabitleri ([dosya, konum, genlik] -> sözlük).
static func _layer_specs(data: Dictionary, key: String, fallback: Array[Array]) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	if data.has(key):
		for raw: Variant in (data[key] as Array):
			specs.append(raw as Dictionary)
		return specs
	for spec: Array in fallback:
		var pos: Vector2 = spec[1] as Vector2
		specs.append({"file": spec[0], "pos": [pos.x, pos.y], "parallax": spec[2]})
	return specs


static func _decor_specs(data: Dictionary) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	if data.has("decor"):
		for raw: Variant in (data["decor"] as Array):
			specs.append(raw as Dictionary)
		return specs
	for spec: Array in FLOWERS:
		var pos: Vector2 = spec[1] as Vector2
		specs.append({"file": spec[0], "pos": [pos.x, pos.y], "scale": spec[2]})
	return specs


static func _vec(data: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var raw: Variant = data.get(key, null)
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float((raw as Array)[0]), float((raw as Array)[1]))
	return fallback


## Paleti sahneye uygular: durağan tonlar + zamana bağlı ışıklar.
func _apply_look(time: float) -> void:
	_apply_tints()
	_animate_lights(time)


## Durağan tonlar (katmanlar, süsler, direkler, bulutlar, gök cisimleri). Neden ayrı: bunlar
## yalnız gün/mekân geçişinde ya da fırtına değişince değişir; her kare yazılmaz.
func _apply_tints() -> void:
	var scenery: Color = _current.scenery_tint
	var flower_tint: Color = Color.WHITE.lerp(scenery, FLOWER_TINT_SHARE)
	for place: PlaceSet in _sets:
		for sprite: Sprite2D in place.tinted:
			sprite.self_modulate = scenery
		for decor: Sprite2D in place.decor:
			decor.self_modulate = flower_tint
	_props.modulate = Color.WHITE.lerp(scenery, PROPS_TINT_SHARE)
	garment_tint = _current.garment_tint
	var cloud_tint: Color = _current.cloud_tint * Color.WHITE.lerp(STORM_CLOUD_TINT, storm)
	for entry: Array in _clouds:
		(entry[0] as Sprite2D).modulate = cloud_tint
	_sky_view.apply_static(_current)
	modulate = Color.WHITE.lerp(STORM_TINT, storm * 0.8)
	_applied_storm = storm


## Zamana bağlı ışıklar (yıldız pırıltısı, ateş böcekleri, pencereler, deniz pırıltısı): her kare.
func _animate_lights(time: float) -> void:
	_sky_view.twinkle(_current, time)
	_fireflies.apply(_current.firefly_amount * _active.firefly_scale, time)
	for place: PlaceSet in _sets:
		for lights: WindowLights in place.lights:
			lights.apply(_current.window_glow, time)
		if place.glints != null:
			place.glints.apply(_current, time)


func _sprite(parent: Node, dir: String, file_name: String, top_left: Vector2, place: PlaceSet = null) -> Sprite2D:
	return _sprite_at(parent, dir + file_name + ".png", top_left, place)


func _sprite_at(parent: Node, path: String, top_left: Vector2, place: PlaceSet = null) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = _texture_at(path)
	sprite.centered = false
	sprite.position = top_left
	parent.add_child(sprite)
	if place != null and not place.paths.has(path):
		place.paths.append(path)
	return sprite


## Eski mekânın dokuları önbellekten atılır (yeni mekân ve ortak dokular kalır). Sprite'lar
## queue_free ile çıktığında son referans da düşer; yalnız etkin mekân bellekte kalır.
static func _forget_textures(old: PlaceSet, keep: PlaceSet) -> void:
	for path: String in old.paths:
		if not keep.paths.has(path) and not path.begins_with(BG_DIR + "cloud") and path != BG_DIR + RACK_FILE + ".png":
			_textures.erase(path)


func _enter_tree() -> void:
	# Yeniden ağaca girerse (taşıma) tekrar canlı sayılır; ilk kayıt `setup` içindedir.
	if _active != null and not _live.has(self):
		_live.append(self)


func _exit_tree() -> void:
	# Budama burada YAPILMAZ: ana ekran -> oyun geçişinde yeni sahne aynı dokuları hemen ister;
	# önbellekten düşerse diskten eşzamanlı yeniden yüklenirdi. Budama yeni arka plan kurulunca olur.
	_live.erase(self)


## Önbellekte yalnız canlı arka planların setleri (etkin + sönen), oyuncunun kayıtlı seviyesinin
## mekânı (ana ekran <-> oyun geçişi diskten yeniden yüklemesin) ve ortak dokular kalır.
## Sonraki seviye için iş parçacığında istenmiş (`_requested`) dokulara dokunulmaz.
static func _prune_cache() -> void:
	var keep: Dictionary[String, bool] = {}
	for path: String in _all_paths(LocationCycle.location_for(_saved_level()), SeasonLook.season_for_level(_saved_level())):
		keep[path] = true
	for backdrop: GardenBackdrop in _live:
		if not is_instance_valid(backdrop):
			continue
		for place: PlaceSet in [backdrop._active, backdrop._leaving]:
			if place == null:
				continue
			for path: String in place.paths:
				keep[path] = true
	for path: String in _textures.keys():
		if not keep.has(path) and not path.begins_with(BG_DIR + "cloud") and path != BG_DIR + RACK_FILE + ".png":
			_textures.erase(path)


## Açılışta (Boot beklemesi) ortak dokuları ve oyuncunun kayıtlı mekânının dokularını iş
## parçacıklarında paralel yüklemeye başlar. `_texture_at` hazır olanı alır; bitmemişse onu bekler.
static func warm_up() -> void:
	var level: int = _saved_level()
	_request_paths(_all_paths(LocationCycle.location_for(level), SeasonLook.season_for_level(level)))


static func _request_paths(paths: Array[String]) -> void:
	for path: String in paths:
		if not _textures.has(path) and not _requested.has(path) and ResourceLoader.exists(path):
			if ResourceLoader.load_threaded_request(path) == OK:
				_requested.append(path)


## Çıkışta: alınmamış iş parçacığı yüklemeleri bitirilip bırakılır, önbellek boşaltılır. Neden:
## açılış beklemesinde (0.4 sn) çıkılırsa yarım kalan yüklemeler "ObjectDB leaked" uyarısı veriyordu.
static func release_textures() -> void:
	for path: String in _requested:
		ResourceLoader.load_threaded_get(path)
	_requested.clear()
	_textures.clear()


## Bir mekân x mevsimin ihtiyaç duyduğu tüm doku yolları (ortak bulut + askı dahil; mevsimlik doku
## yazınkinin yerine geçer, süsler ve efekt dokuları eklenir).
static func _all_paths(place_id: String, season: String = SeasonCycle.SUMMER) -> Array[String]:
	var paths: Array[String] = [BG_DIR + RACK_FILE + ".png"]
	for spec: Array in CLOUDS:
		paths.append(BG_DIR + String(spec[0]) + ".png")
	var data: Dictionary = LocationCycle.data_for(place_id)
	var dir: String = String(data.get("dir", BG_DIR))
	var names: Array[String] = []
	for spec: Dictionary in _layer_specs(data, "back", LAYERS) + _layer_specs(data, "front", FRONT_LAYERS) + _decor_specs(data):
		names.append(String(spec.get("file", "")))
	var hero: Dictionary = data.get("hero", {}) as Dictionary
	names.append(String(hero.get("trunk", "tree_trunk")))
	names.append(String(hero.get("crown", "tree_crown")))
	names.append(String(data.get("pole", "pole")))
	for file_name: String in names:
		var swap: String = SeasonLook.swap_path(place_id, season, file_name)
		var path: String = swap if not swap.is_empty() else dir + file_name + ".png"
		if not paths.has(path):
			paths.append(path)
	for path: String in SeasonLook.extra_paths(place_id, season, false):
		if not paths.has(path):
			paths.append(path)
	return paths


static func _texture_at(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	if not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = null
	if _requested.has(path):
		_requested.erase(path)
		texture = ResourceLoader.load_threaded_get(path) as Texture2D
	if texture == null:
		texture = load(path) as Texture2D
	_textures[path] = texture
	return texture


func _process(delta: float) -> void:
	var time: float = float(Time.get_ticks_msec()) * 0.001
	var look_changed: bool = _tints_dirty or absf(storm - _applied_storm) > TINT_EPSILON
	_tints_dirty = false
	if _fade < 1.0:
		_fade = minf(_fade + delta / DayCycle.FADE_SECONDS, 1.0)
		_current.blend(_fade_from, _fade_to, smoothstep(0.0, 1.0, _fade))
		look_changed = true
	if _leaving != null:
		_place_fade = minf(_place_fade + delta / _place_fade_seconds, 1.0)
		_active.set_alpha(smoothstep(0.0, PLACE_FADE_IN_END, _place_fade))
		_leaving.set_alpha(1.0 - smoothstep(PLACE_FADE_OUT_START, 1.0, _place_fade))
		if _place_fade >= 1.0:
			_finish_place_fade()
	var wind: float = 1.0 + storm * 4.0
	# Çok yavaş, küçük yatay salınım: katmanlar farklı genlikte kaydığı için derinlik hissi verir.
	var drift: float = sin(time * PARALLAX_SPEED)
	var crown_angle: float = 0.6 * wind * sin(time * 0.7 * (1.0 + storm))
	for place: PlaceSet in _sets:
		for index: int in range(place.parallax.size()):
			place.parallax[index].position.x = place.parallax_base[index] + drift * place.parallax_amp[index]
		place.crown.rotation_degrees = place.crown_sway * crown_angle
		for index: int in range(place.decor.size()):
			var sway: float = place.decor_amp[index] * (1.0 + storm * 2.0) * sin(time * 1.5 + float(index) * 1.9)
			if place.decor_skew[index]:
				# Saksılı bitki: dönerse saksı da sallanırdı; kaykılma (skew) tabanı sabit tutar.
				place.decor[index].skew = deg_to_rad(sway)
			else:
				place.decor[index].rotation_degrees = sway
	for entry: Array in _clouds:
		var cloud: Sprite2D = entry[0] as Sprite2D
		cloud.position.x += float(entry[1]) * wind * delta
		if cloud.position.x > _width + 40.0:
			cloud.position.x = -CLOUD_WRAP_MARGIN
	if look_changed:
		_apply_tints()
	_animate_lights(time)
	_season_fx.apply(_current, storm, time, delta)
	if _rack != null and absf(danger - _applied_danger) > TINT_EPSILON:
		_applied_danger = danger
		_rack.modulate = Color.WHITE.lerp(DANGER_TINT, danger)
