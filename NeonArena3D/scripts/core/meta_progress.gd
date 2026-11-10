extends RefCounted
class_name MetaProgress
## Kalıcı ilerleme: çekirdek (para), atölye yükseltmeleri ve gemi sahipliği.
## Sahneden bağımsız; Settings bunu ConfigFile'a yazar.

const DEFAULT_SHIP := "vektor"

var upgrade_defs: Array = []
var ship_defs: Array = []
var cores := 0
var lifetime_cores := 0
var levels: Dictionary = {}
var ships_owned: Array = [DEFAULT_SHIP]
var ship := DEFAULT_SHIP

func _init(upgrades: Array = [], ships: Array = []) -> void:
	upgrade_defs = upgrades
	ship_defs = ships

# --- Yükseltmeler ----------------------------------------------------------------
func upgrade_def(id: String) -> Dictionary:
	for def in upgrade_defs:
		if str(def.get("id", "")) == id:
			return def
	return {}

func level(id: String) -> int:
	return int(levels.get(id, 0))

func max_level(id: String) -> int:
	return (upgrade_def(id).get("costs", []) as Array).size()

func next_cost(id: String) -> int:
	## Sıradaki seviyenin fiyatı; en üst seviyedeyse -1.
	var costs: Array = upgrade_def(id).get("costs", [])
	var lv := level(id)
	return int(costs[lv]) if lv < costs.size() else -1

func can_buy(id: String) -> bool:
	var cost := next_cost(id)
	return cost >= 0 and cores >= cost

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	cores -= next_cost(id)
	levels[id] = level(id) + 1
	return true

func effects() -> Dictionary:
	## Tüm yükseltmelerin toplam etkisi (Loadout.apply_effects ile uygulanır).
	var out: Dictionary = {}
	for def in upgrade_defs:
		var lv := level(str(def.get("id", "")))
		if lv <= 0:
			continue
		var effect: Dictionary = def.get("effect", {})
		for key in effect:
			out[key] = float(out.get(key, 0.0)) + float(effect[key]) * float(lv)
	return out

# --- Gemiler ---------------------------------------------------------------------
func ship_def(id: String) -> Dictionary:
	for def in ship_defs:
		if str(def.get("id", "")) == id:
			return def
	return {}

func owns_ship(id: String) -> bool:
	return ships_owned.has(id)

func ship_cost(id: String) -> int:
	return int(ship_def(id).get("cost", 0))

func buy_ship(id: String) -> bool:
	if owns_ship(id) or ship_def(id).is_empty() or cores < ship_cost(id):
		return false
	cores -= ship_cost(id)
	ships_owned.append(id)
	return true

func select_ship(id: String) -> bool:
	if not owns_ship(id):
		return false
	ship = id
	return true

func current_ship() -> Dictionary:
	var def := ship_def(ship)
	if def.is_empty() and not ship_defs.is_empty():
		return ship_defs[0]
	return def

# --- Ödül ------------------------------------------------------------------------
static func run_reward(score: int, wave: int, bosses: int, mult := 1.0) -> int:
	## Koşu sonu çekirdek: puan + ulaşılan dalga + yenilen boss, atölye çarpanıyla.
	var base := float(score) / 150.0 + float(maxi(0, wave - 1)) * 3.0 + float(bosses) * 20.0
	return maxi(0, int(round(base * mult)))

func earn(amount: int) -> void:
	cores += maxi(0, amount)
	lifetime_cores += maxi(0, amount)

# --- Kayıt -----------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"cores": cores, "lifetime": lifetime_cores, "levels": levels.duplicate(),
		"ships": ships_owned.duplicate(), "ship": ship,
	}

func from_dict(data: Dictionary) -> void:
	cores = maxi(0, int(data.get("cores", 0)))
	lifetime_cores = maxi(0, int(data.get("lifetime", cores)))
	levels = {}
	var raw: Dictionary = data.get("levels", {})
	for id in raw:
		if not upgrade_def(str(id)).is_empty():
			levels[str(id)] = clampi(int(raw[id]), 0, max_level(str(id)))
	ships_owned = [DEFAULT_SHIP]
	for id in data.get("ships", []):
		if not ships_owned.has(str(id)) and not ship_def(str(id)).is_empty():
			ships_owned.append(str(id))
	ship = str(data.get("ship", DEFAULT_SHIP))
	if not owns_ship(ship):
		ship = DEFAULT_SHIP
