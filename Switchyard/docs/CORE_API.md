# Switchyard — katman sözleşmeleri

Bu belge ve iki sözleşme dosyası (`scripts/game/level_session.gd`, `scripts/core/level_catalog.gd`) yalnız lider
tarafından değiştirilir. Kurallar: `docs/DESIGN.md` §1-2.

## 1. Seviye dosyası (`data/levels/<id>.json`)

```json
{
  "id": "w1-007",
  "world": 1,
  "cells": [
    { "x": 1, "y": 4, "a": [], "b": [1] },
    { "x": 2, "y": 4, "a": [0], "b": [2, 5], "kind": "plain" }
  ],
  "vehicles": [
    { "id": "L", "type": "loco", "cell": 0 },
    { "id": "r1", "type": "wagon", "color": "red", "cell": 3 }
  ],
  "links": [["L", "r1"]],
  "targets": [{ "cell": 6, "color": "red" }],
  "par": 7,
  "solution": [
    { "t": "drive", "side": "b", "steps": 3, "branches": [1] },
    { "t": "uncouple", "between": ["L", "r1"] }
  ],
  "metrics": { "min_cells": 19, "states": 4210, "detours": 2, "solutions_at_par": 1 }
}
```

- Hücre kimliği dizideki sırasıdır. `x`, `y` çizim için ızgara birimi (kesirli olabilir); kurallar bunları kullanmaz.
- `a`, `b`: o yandaki komşu hücre kimlikleri (0-2 adet). İki komşu = makas, sıra dal numarasıdır (0, 1).
- `kind` isteğe bağlı (varsayılan `plain`); mekanikler buraya ve araçların `kind` alanına eklenir.
- `color`: `red`, `blue`, `yellow`, `green`, `purple`, `orange`; lokomotif hedefi için `loco`.
- `solution` eylemleri: `drive` (`side`: lokomotifin hangi yanına doğru; `steps`: hücre sayısı; `branches`: sürüş
  boyunca karşılaşılan dal seçimleri, sırayla, eksikse 0) ve `uncouple` (`between`: iki araç kimliği).
- `par`: en az hamle (`docs/DESIGN.md` §2 sayım kuralı). `metrics` çözücüden gelir.

`data/levels/index.json`: oyundaki sıra.
```json
{ "levels": [ { "id": "w1-001", "world": 1, "par": 2, "difficulty": 1 } ] }
```
`difficulty` 1-10 (ölçütlerden türetilir; harita ve denge için).

## 2. Çekirdek kurallar (`scripts/core/yard/`, saf, RefCounted)

Çekirdek işçisi sınıfları kendisi biçimlendirir; aşağıdaki yüzey görünüm ve kabuk için SABİTTİR.

```gdscript
class_name YardLevel extends RefCounted
static func from_dict(data: Dictionary) -> YardLevel      # doğrular; hatada null + push_error
var id: String
var world: int
var par: int
func cell_count() -> int
func cell_pos(cell: int) -> Vector2                       # ızgara birimi
func neighbors(cell: int, side: int) -> PackedInt32Array  # side: YardRules.SIDE_A / SIDE_B
func cell_kind(cell: int) -> String
func targets() -> Array[Dictionary]                       # {cell:int, color:String}
func solution() -> Array[Dictionary]

class_name YardState extends RefCounted
func duplicate_state() -> YardState
func vehicle_ids() -> PackedStringArray
func vehicle_cell(id: String) -> int
func vehicle_at(cell: int) -> String                      # "" = boş
func vehicle_type(id: String) -> String                   # "loco" | "wagon"
func vehicle_color(id: String) -> String
func is_linked(id_a: String, id_b: String) -> bool
func links() -> Array[PackedStringArray]                  # her biri iki kimlik
func train() -> PackedStringArray                         # katar: bir uçtan öbürüne sırayla
func key() -> String                                      # durumun kararlı özeti (geri al, test)

class_name YardRules extends RefCounted
const SIDE_A := 0
const SIDE_B := 1
static func initial_state(level: YardLevel) -> YardState
## Bir hücre sürüş. `branch`: baş dallanan yana bakıyorsa dal numarası. Durumu yerinde değiştirir.
static func step(level: YardLevel, state: YardState, side: int, branch: int) -> YardStep
## O yönde bir adım mümkün mü ve baş dal seçimi istiyor mu (görünüm sürüklerken sorar).
static func probe(level: YardLevel, state: YardState, side: int) -> YardProbe
static func uncouple(level: YardLevel, state: YardState, id_a: String, id_b: String) -> bool
static func is_solved(level: YardLevel, state: YardState) -> bool
## Çözüm eylemini uygular (testler ve ipucu gösterimi).
static func apply_action(level: YardLevel, state: YardState, action: Dictionary) -> bool

class_name YardStep extends RefCounted
var moved: bool                       # katar bir hücre ilerledi mi
var coupled: PackedStringArray        # bu adımda katara bağlanan araçlar (canlandırma, ses)
var blocked: String                   # "" | "buffer" | "self" | mekanik adı
var moves: Dictionary                 # araç kimliği -> [eski hücre, yeni hücre]

class_name YardProbe extends RefCounted
var possible: bool
var needs_branch: bool
var branch_cells: PackedInt32Array    # needs_branch ise iki dalın ilk hücreleri (görünüm parmağa yakın olanı seçer)
```

İpucu: `YardHint.next_action(level, state, history) -> Dictionary`. Oyuncunun durumu kayıtlı çözüm yolundaysa sıradaki
eylemi; değilse sınırlı süreli arama; o da bulamazsa `{ "t": "rewind", "to": n }` (geçmişte çözüm yolundaki son an)
döndürür. Ayrıntı çekirdek işçisinin; yüzey sabit.

## 3. Oturum sözleşmesi (`scripts/game/level_session.gd`)

Kabuk sahayı yalnız `LevelSession` üzerinden kullanır; görünüm bunu uygular (`YardSession`). Kabuk kendi probeları
için sahte bir uygulama (`StubSession`) taşır.

## 4. Katalog (`scripts/core/level_catalog.gd`)

`LevelCatalog.entries()` oyundaki sırayı verir (`index.json`); `LevelCatalog.load_level(id)` seviye sözlüğünü döndürür.
