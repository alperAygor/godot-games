class_name RetentionStrings
extends RefCounted

## Tutundurma metinleri: `strings.csv` (RET_ önekli) anahtarlarına ince sarmalayıcılar.
## Kasıtlı az metin: anlatımı ikonlar ve sayılar yapar.
## Dinamik anahtar BİLEREK yok: aşağıdaki tablolar her anahtarı düz metin olarak taşır ki
## "kullanılmayan anahtar" denetimi (test_loc) ve arama çalışsın.

## Haftalık tema kimliği -> [başlık, hedef] anahtarları.
const THEME_KEYS: Dictionary = {
	"blue": ["RET_W_BLUE", "RET_G_BLUE"],
	"red": ["RET_W_RED", "RET_G_RED"],
	"green": ["RET_W_GREEN", "RET_G_GREEN"],
	"yellow": ["RET_W_YELLOW", "RET_G_YELLOW"],
	"purple": ["RET_W_PURPLE", "RET_G_PURPLE"],
	"chain": ["RET_W_CHAIN", "RET_G_CHAIN"],
	"baskets": ["RET_W_BASKETS", "RET_G_BASKETS"],
	"stars": ["RET_W_STARS", "RET_G_STARS"],
}
## Görev kimliği -> [çoğul anahtar, tekil anahtar ("" = tekil ayrımı yok)].
const MISSION_KEYS: Dictionary = {
	"levels": ["RET_M_LEVELS", ""],
	"stars3": ["RET_M_STARS3", "RET_M_STARS3_ONE"],
	"low_rack": ["RET_M_LOW_RACK", "RET_M_LOW_RACK_ONE"],
	"baskets": ["RET_M_BASKETS", ""],
	"chain": ["RET_M_CHAIN", ""],
	"daily": ["RET_M_DAILY", ""],
	"booster": ["RET_M_BOOSTER", "RET_M_BOOSTER_ONE"],
	"bird": ["RET_M_BIRD", ""],
	"cat": ["RET_M_CAT", ""],
}


static func missions_title() -> String:
	return Loc.t("RET_MISSIONS_TITLE")


static func weekly_title() -> String:
	return Loc.t("RET_WEEKLY_TITLE")


static func chest_bonus() -> String:
	return Loc.t("RET_CHEST_BONUS")


static func milestones_title() -> String:
	return Loc.t("RET_MILESTONES_TITLE")


static func to_go(levels: int) -> String:
	return Loc.t("RET_TO_GO_ONE") if levels == 1 else Loc.f("RET_TO_GO", [levels])


static func claim() -> String:
	return Loc.t("RET_CLAIM")


static func locked(level: int) -> String:
	return Loc.f("RET_LOCKED", [level])


static func days_left(days: int) -> String:
	return Loc.t("RET_LAST_DAY") if days <= 1 else Loc.f("RET_DAYS_LEFT", [days])


static func week_note(coins: int) -> String:
	return Loc.f("RET_WEEK_NOTE", [coins])


static func theme_title(theme_id: String) -> String:
	return Loc.t(String((THEME_KEYS.get(theme_id, ["", ""]) as Array)[0]))


static func theme_goal(theme_id: String) -> String:
	return Loc.t(String((THEME_KEYS.get(theme_id, ["", ""]) as Array)[1]))


## Görev metni: tanımdaki "args" sırasıyla ("target", "param") biçimlenir. Hedef 1 ve tekil
## anahtar varsa o kullanılır ("Bir seviyeyi ... bitir"); tekilde hedef sayısı metne girmez.
static func mission_text(def: Dictionary, target: int) -> String:
	var keys: Array = MISSION_KEYS.get(String(def.get("id", "")), ["", ""]) as Array
	var singular: bool = target == 1 and not String(keys[1]).is_empty()
	var args: Array = []
	for name: Variant in def.get("args", []) as Array:
		if String(name) == "target":
			if not singular:
				args.append(target)
		else:
			args.append(int(def.get("param", 0)))
	var key: String = String(keys[1] if singular else keys[0])
	return Loc.f(key, args) if not args.is_empty() else Loc.t(key)


static func welcome_title() -> String:
	return Loc.t("RET_WELCOME_TITLE")


static func welcome_body(days: int) -> String:
	return Loc.f("RET_WELCOME_BODY", [days])


static func streak_title(days: int) -> String:
	return Loc.f("RET_STREAK_TITLE", [days])


static func streak_body() -> String:
	return Loc.t("RET_STREAK_BODY")
