# Priz — çekirdek API (aşama 1)

Sahne ve arayüz kodu çekirdeğe **yalnız bu belgedeki** sınıf ve yöntemlerle dokunur. Çekirdek
`scripts/core/` altındadır: tümü `RefCounted`, sahnesiz, autoload'suz, global durumsuz ve
belirlenimcidir. Metin üretmez; yalnız kimlik (id) ve kod döner. Ekranda rakam gösterilmez:
yük/kapasite **blok sayısı** ya da **doluluk oranı** olarak gelir, arayüz bunu tüp, blok, ibre
olarak çizer.

## Hızlı başlangıç

```gdscript
var content := PrizContent.load_default()          # ana iş parçacığında, bir kez
var level := PrizLevel.load_shipped(12)            # data/levels/level_012.json
var board := PrizBoard.new(level, content.registry)

# Sürükleme başladı: parlayacak prizler ve diğerlerinin soluk kalma nedeni
var ok_sockets: Array[String] = board.sockets_accepting("d3")
var reasons: Dictionary = board.plug_reasons("d3")  # priz id → PrizReason

# Bırakıldı
var r: StringName = board.plug("d3", "s5")
if r != PrizReason.OK:
	pass  # fişi geri sektir, r'ye göre görsel ipucu ver (kapı simgesi, toprak simgesi ...)

# Gün kipi
if board.can_start_day():
	for e: PrizEvent in board.start_day():
		pass  # sırayla canlandır
```

## Sınıflar

| Sınıf | Görev |
|---|---|
| `PrizContent` | `registry` (öğeler) + `catalog` (cihaz kataloğu). `load_default()`, `create(registry, catalog)` |
| `PrizLevel` | Seviye verisi + JSON. `load_shipped(n)`, `load_file(path)`, `from_json(text)`, `to_json()`, `save_file(path)`, `copy()`, `validate(registry)`, `shipped_files()`, `shipped_path(n)`, `find_line/find_socket/find_device(id)`, `is_day_mode()`, `is_hard()`, `has_element(id)` |
| `PrizLine` / `PrizSocket` / `PrizDevice` | Seviye öğeleri (alanlar aşağıda). `get_prop(key, fallback)` |
| `PrizBoard` | Kural motoru ve oyun durumu |
| `PrizSolver` | Çözüm sayma, çözülebilirlik, ilk çözüm, ipucu |
| `PrizGenerator` | Tohumlu seviye üretici |
| `PrizDaily` | Tarihten günlük seviye |
| `PrizCurve` | Zorluk eğrisi (seviye numarası → boyut ve hedef) |
| `PrizElementRegistry` / `PrizElement` | İçerik öğeleri (tanıtım kartı kimlikleri dahil) |
| `PrizEvent`, `PrizHint`, `PrizSolveResult`, `PrizReason`, `PrizSlice` | Dönüş tipleri ve sabitler |

İç kullanım (arayüz dokunmaz): `PrizCompiled`, `PrizRule`, `PrizGenContext`, `PrizJson`, `PrizCatalog` (yalnız üretici).

## Gün dilimleri — `PrizSlice`

`MORNING=0, NOON=1, EVENING=2, NIGHT=3`, `COUNT=4`, `ALL_MASK=15`. Cihaz dilimleri bit maskesidir
(bit 0 sabah). Yardımcılar: `has(mask, slice)`, `ids_from_mask(mask)`, `mask_from_ids(ids)`,
`id_of(slice)`, `from_id(id)`, `rotate(mask, shift)`.
Düz kipte (seviye 1-14) tüm cihazlar her dilimde çalışır; dilim sorguları aynı değeri verir,
arayüz `slice = 0` kullanabilir.

## `PrizBoard`

Durum: `state()` → `PrizBoard.State.PLANNING | WON | LOST`; `is_planning()`, `is_won()`, `is_lost()`,
`is_day_mode()`, `fuse_rights()`, `days_run()`.

Yerleşim:
- `can_plug(device_id, socket_id) -> StringName` — `PrizReason` kodu (aşağıda). Durumu değiştirmez.
- `plug(device_id, socket_id) -> StringName` — OK ise takar (takılıysa taşır). Düz kipte son cihaz
  oturunca durum `WON` olur.
- `unplug(device_id) -> bool`, `clear()` — planlamada sınırsız geri alma.
- `socket_of(device_id) -> String` ("" = tepside), `devices_in(socket_id)`, `free_seats(socket_id)`,
  `is_all_plugged()`, `unplugged_devices()`, `placement() -> {device_id: socket_id}`,
  `apply_placement(plan) -> Array[String]` (kurala uymayıp atlananlar).

Vurgu:
- `sockets_accepting(device_id)` — tutulan cihazın şu an takılabileceği prizler.
- `plug_reasons(device_id) -> {socket_id: PrizReason}` — her prizin neden soluk olduğu.
- `line_sockets(line_id)`, `line_devices(line_id)`, `line_of_socket(socket_id)`, `line_of_device(device_id)`.

Yük (blok):
- `line_load(line_id, slice)` toplam (cihazlar + dış yük), `line_device_load`, `line_external_load`
  (komşu hattı), `line_capacity(line_id, slice)` etkin kapasite, `line_base_capacity(line_id)`
  taban (eski kablonun kullanılamaz bloklarını çizmek için: taban − etkin).
- `line_fill(line_id, slice) -> float` (1'i aşarsa taşma; kapasite 0 ve yük varsa 2.0),
  `line_peak_fill(line_id)`, `overflows() -> [{"line": id, "slice": s}]` (gün önizlemesi).
- `is_device_active(device_id, slice)`, `device_slices(device_id) -> mask`,
  `device_slices_at(device_id, socket_id)` (zamanlayıcılı prizi önizleme),
  `device_load_at(device_id, socket_id, slice)`.
- `NEAR_LIMIT_FILL = 0.8`.

Gün:
- `can_start_day()` — gün kipi + planlama + tüm cihazlar takılı ("Günü başlat" düğmesi bunu izler).
- `start_day() -> Array[PrizEvent]` — dört dilimi benzetir; başlatılamazsa boş dizi.
- `grant_extra_right()` — ödüllü reklam: +1 hak; `LOST` ise `PLANNING`e döner, plan korunur.

### Ret kodları — `PrizReason`

| Kod | Anlam | Not |
|---|---|---|
| `&"ok"` | takılabilir | |
| `&"unknown"` | bilinmeyen cihaz/priz kimliği | |
| `&"not_planning"` | seviye kazanıldı ya da kaybedildi | |
| `&"wrong_room"` | oda kısıtı (seviye 6+) | öğe: room_restriction |
| `&"needs_ground"` | cihaz topraklı priz ister | öğe: grounded_socket |
| `&"socket_full"` | prizin/uzatmanın yuvaları dolu | |
| `&"would_overflow"` | düz kip: takılırsa hat taşar, fiş oturmaz | gün kipinde planlamada taşmaya izin var |

Öğe dosyaları kendi kodlarını tanımlayabilir (kural parametresi `"reason"`); arayüz bilmediği
kodu genel "olmaz" titreşimiyle göstermelidir.

Kontrol sırası: unknown → not_planning → (aynı prize yeniden takma = ok) → öğe kuralları
(öğe sırasıyla) → socket_full → would_overflow.

### Gün olayları — `PrizEvent`

Alanlar: `type: StringName`, `slice: int` (-1 = yok), `line_id`, `device_id`, `blocks`, `capacity`,
`fill: float`, `rights: int` (-1 = yok).

| type | Doldurulan alanlar |
|---|---|
| `day_start` | — |
| `slice_begin` | slice |
| `device_off` | slice, device_id (önceki dilimde çalışıp bu dilimde susan) |
| `device_on` | slice, device_id |
| `line_load` | slice, line_id, blocks, capacity, fill — her dilimde her hat için, hat sırasıyla |
| `line_near_limit` | slice, line_id, blocks, capacity, fill (yük > 0, fill ≥ 0.8, taşmıyor) |
| `fuse_blown` | slice, line_id, blocks, capacity, fill, rights (kalan) — taşan her hat için |
| `back_to_planning` | slice, rights |
| `lose` | slice, rights = 0 |
| `day_survived` | — |
| `win` | — |

Bir dilimin sırası: `slice_begin` → `device_off`… → `device_on`… → `line_load`×hat →
`line_near_limit`… → (taşma varsa) `fuse_blown`… → `back_to_planning` | `lose` ve **durur**.
Aynı dilimde birden çok hat taşarsa her biri için `fuse_blown` gelir ama tek hak düşer.
Dört dilim geçerse `day_survived`, `win`. Plan hiçbir durumda silinmez.

## `PrizSolver`

```gdscript
var solver := PrizSolver.new()                 # PrizSolver.new(node_limit) da olur
var r: PrizSolveResult = solver.count_solutions(level, content.registry, cap)
solver.is_solvable(level, registry) -> bool
solver.first_solution(level, registry) -> {device_id: socket_id}
solver.hint(board) -> PrizHint
```
`PrizSolveResult`: `count`, `capped` (cap'e ulaştı), `node_limit_hit`, `nodes`, `solution`,
`is_solvable()`, `is_exact()`. `count` **ayrık** çözümlerdir: eş prizler (aynı hat, oda, props) ve
birebir aynı davranan cihazların yer değiştirmesi bir kez sayılır.

`PrizHint`: `kind` = `&"place"` (`device_id` cihazını `socket_id` prizine tak), `&"move"`
(`device_id` yerinden çıkmalı; `socket_id` boş değilse gideceği yer), `&"none"` (plan zaten
doğru), `&"unsolvable"`. İpucu her zaman mevcut plandan ulaşılabilen bir çözümle tutarlıdır.

## `PrizGenerator`, `PrizCurve`, `PrizDaily`

```gdscript
var gen := PrizGenerator.new(content)
var level := gen.generate(n)               # varsayılan tohum: PrizGenerator.default_seed(n)
var level2 := gen.generate(n, 12345)       # aynı tohum + numara → bayt-bayt aynı JSON
var daily := PrizDaily.generate(2026, 11, 14, content)   # aynı tarih → aynı seviye
```
Başarısızlıkta `null`. Günlük seviyenin `number` alanı sanal numaradır (16-44, zor değil);
`id` `"daily_YYYY-MM-DD"`, `meta.daily` tarihtir. Arayüz günlük seviyeyi seviye 15 geçilince açar
ve günlükte tanıtım kartı göstermez.

## Tanıtım kartları

`content.registry.introduced_at(level.number) -> Array[PrizElement]` (yalnız kampanya
seviyelerinde). `PrizElement`: `id`, `unlock_level`, `intro_art`, `intro_title`, `intro_body`
(görsel ve dil dosyası anahtarları).

## Veri biçimleri

### Seviye — `data/levels/level_NNN.json`

Anahtarlar sıralı, iki boşluk girintili; tüm sayılar tam sayı.

```json
{
  "format": 1, "id": "level_050", "number": 50, "seed": 1347965960,
  "mode": "day",                       // "flat" (1-14) | "day" (15+)
  "difficulty": "hard",                // "normal" | "hard" (her 5. seviye)
  "band": [2, 8],                      // kabul edilen ayrık çözüm sayısı aralığı
  "fuse_rights": 3,                    // gün kipinde 3, düz kipte 0
  "elements": ["room_restriction", "day_cycle", "solar_panel"],
  "rooms": ["living", "kitchen", "bedroom", "bath"],
  "lines": [{"id": "L2", "color": "yellow", "shape": "triangle", "capacity": 7,
             "props": {"solar": 1}}],
  "sockets": [{"id": "s0", "line": "L2", "room": "living", "anchor": "living_0",
               "seats": 1, "props": {}}],
  "devices": [{"id": "d0", "type": "computer", "load": 2, "room": "living",
               "slices": ["noon", "evening"], "props": {}}],
  "meta": {"solutions": 4, "nodes": 118, "attempt": 2}   // bilgi; oyun mantığı okumaz
}
```

- Renk kimlikleri `red, blue, yellow, green`; şekil kimlikleri `circle, square, triangle, star`
  (aynı sırayla eşleşir; renk körlüğü için şekil).
- Oda kimlikleri `living, kitchen, bedroom, bath`. `anchor` = `"<oda>_<sıra>"`; sahne her odada
  bu adlarla priz yer tutucuları tanımlar (bir odada en çok ~8).
- `seats > 1` = çoklu priz (uzatma).
- Bilinen `props`:
  - hat: `old_cable: int` (kullanılamaz blok), `solar: int` (öğlen ek blok),
    `neighbour: [s, ö, a, g]` (dilim başına komşu yükü), `off_slice: "<dilim>"` (o dilimde elektrik yok).
  - priz: `grounded: true`, `timer: int` (cihaz dilimlerini ileri kaydırma).
  - cihaz: `needs_ground: true`.

### Cihaz kataloğu — `data/balance/devices.json`

`{"devices": [{"type", "load": [min,max], "rooms": [...], "slices": [[...], ...], "ground": bool}]}`.
Sahne `type` kimliğine göre model ve döngü sesi seçer.

### İçerik öğesi — `data/elements/<id>.json`

```json
{
  "id": "solar_panel",
  "unlock_level": 50,
  "intro": {"art": "intro_solar_panel", "title": "element_solar_panel_title",
            "body": "element_solar_panel_body"},
  "requires": ["day_cycle"],
  "rules": [
    {"kind": "slice_bonus",
     "params": {"prop": "solar", "slices": ["noon"]},
     "gen": {"amount": [1, 2]}}
  ],
  "generator": {"always": false, "chance": 0.4}
}
```

- `rules[].kind` → `scripts/core/rules/rule_<kind>.gd`; ya da `"script"` ile yol (göreli yol öğe
  dosyasının klasörüne göre). İsteğe bağlı `"order"` uygulama sırasını ezer.
- `params` çalışma zamanı parametreleri, `gen` üretici ipuçları (`[min,max]` aralıkları;
  tanıtım seviyesinde alt sınır kullanılır).
- `generator.always`: açıldıktan sonra her seviyede. Değilse `chance` olasılıkla, seviye başına en
  çok `PrizCurve.max_optional` isteğe bağlı öğe. Açılış seviyesinde öğe mutlaka gelir ve o seviyede
  başka isteğe bağlı öğe olmaz. `requires`: önce seçilmiş olması gereken öğeler.

Var olan kural türleri: `same_room`, `strip`, `day_cycle`, `capacity_offset`, `flag_match`,
`slice_bonus`, `external_load`, `slice_shift`, `slice_off`.

## Yeni öğe eklemek

**Var olan kural türüyle (yalnız veri):** örneğin "USB isteyen cihaz":

```json
{
  "id": "usb_port", "unlock_level": 110,
  "intro": {"art": "intro_usb", "title": "element_usb_title", "body": "element_usb_body"},
  "rules": [{"kind": "flag_match",
             "params": {"device_flag": "needs_usb", "socket_flag": "usb", "reason": "needs_usb"},
             "gen": {"devices": [1, 2], "extra_sockets": [0, 1]}}],
  "generator": {"chance": 0.4}
}
```
Dosyayı `data/elements/` içine bırakmak yeter: kayıt defteri okur, üretici 110'da tanıtır, tahta
`&"needs_usb"` ret kodunu döner, çözücü kısıtı uygular.

**Yeni kural türü gerekiyorsa:** `PrizRule`den türeyen küçük bir betik + veri dosyası. Kancalar:

| Kanca | Ne zaman |
|---|---|
| `check_plug(level, device, socket) -> StringName` | statik takma kısıtı (yalnız cihaz + prizin hat/oda/props) |
| `modify_mask(level, device, socket, mask) -> int` | cihazın bu prizdeki çalışma dilimleri |
| `modify_load(level, device, socket, slice, blocks) -> int` | dilimdeki yük |
| `modify_capacity(level, line, slice, capacity) -> int` | hattın etkin kapasitesi |
| `external_load(level, line, slice) -> int` | cihazdan bağımsız hat yükü |
| `gen_stage()` + `gen_apply(ctx: PrizGenContext) -> bool` | üretici kancası (`STAGE_PRE_PLANT` yapı, `STAGE_POST_PLANT` gizli çözüme uyan kısıt) |

Örnek (testteki `tests/data/rules/rule_test_surge.gd`): gece ek yük.

```gdscript
extends PrizRule

func modify_load(_level: PrizLevel, device: PrizDevice, _socket: PrizSocket, slice: int,
		blocks: int) -> int:
	if blocks > 0 and bool(device.get_prop("surge", false)) and slice == PrizSlice.NIGHT:
		return blocks + param_int("extra", 1)
	return blocks
```
Tahta, çözücü ve üreticide değişiklik gerekmez (`tests/unit/test_elements.gd` bunu kanıtlar).

## İş parçacıkları

`PrizContent.load_default()` (betik yükler) **ana iş parçacığında** çağrılır. Sonra aynı `content`
salt okunur olarak paylaşılabilir; `PrizBoard`, `PrizSolver`, `PrizGenerator`, `PrizDaily`
çağrıları `WorkerThreadPool` görevinde güvenlidir (her çağrı kendi durumunu kurar). Bir
`PrizBoard` örneği tek iş parçacığından kullanılmalıdır.

## Araçlar

- `godot --headless --path . -s res://tools/gen_levels.gd` — 60 seviyeyi üretir (`--count=`, `--from=`, `--out=`).
- `godot --headless --path . -s res://tools/level_report.gd` — seviye tablosu.
