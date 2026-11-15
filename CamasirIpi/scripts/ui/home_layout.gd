class_name HomeLayout
extends RefCounted

## Ana ekran yerleşim hesabı (saf; düğüm yok, test edilir). Neden: öğeler sabit piksel y'leriyle
## (Oyna 1560, seri 1400 ...) 1080x1920'ye göre yerleşiyordu; "expand" esnetmesiyle uzun telefonda
## (9:20, 9:21) görünür alan 2400-2520 piksele uzayınca Oyna ekranın ortasının üstünde "havada"
## kalıyor, 9:16'da ise alt çubuğa yapışıyordu. Artık her şey KULLANILABİLİR alandan (güvenli alan
## ve sistem çubuğu payları düşülmüş) oranla hesaplanır: aynı oran, her telefonda aynı his.
##
## Dikey akış (yukarıdan): sayaç satırı -> başlık -> oyuncu tutma satırı -> süs ipi -> (askı) ->
## seri göstergesi -> OYNA (alt-orta, başparmak bölgesi) -> alt sekme çubuğu.

## Oyna düğmesinin merkezi: üst güvenli kenar ile alt çubuğun üstü arasındaki yolun bu oranında.
const PLAY_RATIO: float = 0.74
const TITLE_RATIO: float = 0.16
const ROPE_RATIO: float = 0.385
## Oyna'nın alt kenarı ile alt çubuk arasında en az bu kadar boşluk (yanlışlıkla sekmeye basılmasın).
const PLAY_BAR_CLEARANCE: float = 96.0
const STREAK_GAP: float = 36.0
## Arka plan askısı seri göstergesinin bu kadar üstünde kalır (askı düğmelerin arkasına girmesin).
const RACK_CLEARANCE: float = 70.0
const ENTRY_GAP: float = 8.0
const DESIGN_RACK_Y: float = 1130.0
const DESIGN_ROPE_Y: float = 700.0


## view: görünür alan (px); insets: (sol, üst, sağ, alt) güvenli alan payları; ölçüler: alt çubuk
## yüksekliği, Oyna yüksekliği, seri hapı yüksekliği, başlık yüksekliği.
## Dönen sözlük: "usable" (Rect2), "bar_top", "play_center" (Vector2, Oyna'nın merkezi), "streak_center_y",
## "title_top", "entry_y", "rope_y", "rack_y".
static func compute(view: Vector2, insets: Vector4, bar_height: float, play_height: float,
		streak_height: float, title_height: float) -> Dictionary:
	var usable: Rect2 = Rect2(insets.x, insets.y, maxf(view.x - insets.x - insets.z, 0.0),
		maxf(view.y - insets.y - insets.w, 0.0))
	var bar_top: float = usable.end.y - bar_height
	var span: float = maxf(bar_top - usable.position.y, 0.0)
	var play_y: float = usable.position.y + span * PLAY_RATIO
	play_y = minf(play_y, bar_top - PLAY_BAR_CLEARANCE - play_height * 0.5)
	var streak_y: float = play_y - play_height * 0.5 - STREAK_GAP - streak_height * 0.5
	var title_top: float = usable.position.y + span * TITLE_RATIO - title_height * 0.5
	var rope_y: float = usable.position.y + span * ROPE_RATIO
	var rack_y: float = minf(usable.position.y + span * (DESIGN_RACK_Y / DESIGN_ROPE_Y) * ROPE_RATIO,
		streak_y - streak_height * 0.5 - RACK_CLEARANCE)
	return {
		"usable": usable,
		"bar_top": bar_top,
		"play_center": Vector2(usable.get_center().x, play_y),
		"streak_center_y": streak_y,
		"title_top": title_top,
		"entry_y": title_top + title_height + ENTRY_GAP,
		"rope_y": rope_y,
		"rack_y": maxf(rack_y, rope_y + 1.0),
	}
