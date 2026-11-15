class_name YardState
extends RefCounted
## Değişken saha durumu: araç konumları + bağlar. Python aynası: tools/yard/rules.py `State`.
## Seviyeye başvuru tutar (araç türü/rengi ve katar sırası hücre yanlarına bağlı).

var level: YardLevel = null
var _pos: Dictionary[String, int] = {}
var _at: Dictionary[int, String] = {}
var _links: Dictionary[String, bool] = {}


static func create(lv: YardLevel, positions: Dictionary[String, int], link_list: Array[PackedStringArray]) -> YardState:
	var st: YardState = YardState.new()
	st.level = lv
	for vid: String in positions.keys():
		st._pos[vid] = positions[vid]
		st._at[positions[vid]] = vid
	for pair: PackedStringArray in link_list:
		st._links[YardLevel.link_key(pair[0], pair[1])] = true
	return st


func duplicate_state() -> YardState:
	var st: YardState = YardState.new()
	st.level = level
	st._pos = _pos.duplicate()
	st._at = _at.duplicate()
	st._links = _links.duplicate()
	return st


## Başka bir durumun içeriğini buraya kopyalar (atomik eylem uygulaması için).
func assign_from(other: YardState) -> void:
	_pos = other._pos.duplicate()
	_at = other._at.duplicate()
	_links = other._links.duplicate()


func vehicle_ids() -> PackedStringArray:
	return level.vehicle_ids()


func vehicle_cell(vid: String) -> int:
	return _pos.get(vid, -1)


func vehicle_at(cell: int) -> String:
	return _at.get(cell, "")


func vehicle_type(vid: String) -> String:
	return level.vehicle_type(vid)


func vehicle_color(vid: String) -> String:
	return level.vehicle_color(vid)


func vehicle_kind(vid: String) -> String:
	return level.vehicle_kind(vid)


func is_linked(id_a: String, id_b: String) -> bool:
	return _links.has(YardLevel.link_key(id_a, id_b))


func links() -> Array[PackedStringArray]:
	var keys: PackedStringArray = PackedStringArray(_links.keys())
	keys.sort()
	var out: Array[PackedStringArray] = []
	for k: String in keys:
		out.append(k.split("-"))
	return out


func add_link(id_a: String, id_b: String) -> void:
	_links[YardLevel.link_key(id_a, id_b)] = true


func remove_link(id_a: String, id_b: String) -> bool:
	return _links.erase(YardLevel.link_key(id_a, id_b))


func link_count() -> int:
	return _links.size()


## Araçları yeni hücrelere taşır (moves: kimlik -> yeni hücre). Kurallar dışında kullanılmaz.
func relocate(new_cells: Dictionary[String, int]) -> void:
	for vid: String in new_cells.keys():
		_at.erase(_pos[vid])
	for vid: String in new_cells.keys():
		_pos[vid] = new_cells[vid]
		_at[new_cells[vid]] = vid


## Katar: lokomotif hücresinin a-ucundan b-ucuna sırayla.
func train() -> PackedStringArray:
	var loco: String = level.loco_id
	var left: PackedStringArray = YardRules.walk(level, self, loco, YardRules.SIDE_A)
	var right: PackedStringArray = YardRules.walk(level, self, loco, YardRules.SIDE_B)
	var out: PackedStringArray = PackedStringArray()
	for i: int in range(left.size() - 1, -1, -1):
		out.append(left[i])
	out.append(loco)
	out.append_array(right)
	return out


## Kararlı özet; Python `State.key()` ile aynı biçim: "id@hücre;..." + "|" + "a-b,...".
func key() -> String:
	var ids: PackedStringArray = PackedStringArray(_pos.keys())
	ids.sort()
	var parts: PackedStringArray = PackedStringArray()
	for vid: String in ids:
		parts.append("%s@%d" % [vid, _pos[vid]])
	var lk: PackedStringArray = PackedStringArray(_links.keys())
	lk.sort()
	return ";".join(parts) + "|" + ",".join(lk)


## Renk-kanonik ve duran bağlardan bağımsız özet: aynı renkli vagonlar ve duran dizilerin bağları önemsiz.
## İpucu bununla "çözüm yolunda mı" diye bakar (çözücünün normalleştirmesiyle aynı, docs/YARD.md §3).
func canonical_key() -> String:
	var n: int = level.cell_count()
	var parts: PackedStringArray = PackedStringArray()
	for c: int in n:
		var vid: String = _at.get(c, "")
		if vid == "":
			parts.append(".")
		elif level.vehicle_type(vid) == "loco":
			parts.append("L")
		else:
			parts.append(level.vehicle_color(vid).substr(0, 2))
	var tr: PackedStringArray = train()
	var cells: PackedStringArray = PackedStringArray()
	for vid: String in tr:
		cells.append(str(_pos[vid]))
	return ",".join(parts) + "|" + ",".join(cells)
