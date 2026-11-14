class_name SafeAreaMath
extends RefCounted
## Ekranın güvenli alanını (çentik, kamera deliği, yuvarlak köşe, gezinme çubuğu) kenar boşluğuna çevirir.
## Saf hesap: sahneye bağımlı değil, testlenebilir. Dönen değerler Vector4(sol, üst, sağ, alt).

const SIMULATE_ARG := "--simulate-safe-area="


## screen_size ve safe_rect fiziksel piksel; scale = viewport birimi / fiziksel piksel.
static func margins(screen_size: Vector2, safe_rect: Rect2, scale: float) -> Vector4:
	if screen_size.x <= 0.0 or screen_size.y <= 0.0 or safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return Vector4.ZERO
	var left := maxf(safe_rect.position.x, 0.0)
	var top := maxf(safe_rect.position.y, 0.0)
	var right := maxf(screen_size.x - safe_rect.end.x, 0.0)
	var bottom := maxf(screen_size.y - safe_rect.end.y, 0.0)
	return Vector4(left, top, right, bottom) * scale


## Masaüstünde çentik denemek için: "--simulate-safe-area=üst,sağ,alt,sol" (viewport birimi, CSS sırası).
## Argüman yoksa veya bozuksa null döner.
static func parse_simulated(args: PackedStringArray) -> Variant:
	for arg in args:
		if not arg.begins_with(SIMULATE_ARG):
			continue
		var parts := arg.trim_prefix(SIMULATE_ARG).split(",")
		if parts.size() != 4:
			return null
		var top := parts[0].to_float()
		var right := parts[1].to_float()
		var bottom := parts[2].to_float()
		var left := parts[3].to_float()
		return Vector4(left, top, right, bottom)
	return null
