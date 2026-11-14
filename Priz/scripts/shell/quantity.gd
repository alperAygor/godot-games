class_name Quantity
extends RefCounted

## Niceliklerin SAYISIZ gösterimi için saf hesap (Priz kuralı: ekranda rakam yok).
## Jeton: bir sıra jeton simgesi, `max_icons` ile sınırlı; `pile_from` ve üstünde "çok" yığını eklenir.
## Seviye: her blokta (varsayılan 5) 4 normal + 1 zor nokta; dolu noktalar blok içindeki ilerlemedir.
## Değerler `data/balance.json` (`coin_display`, `level_pips`); buradakiler yalnız yedektir.
## Çizim `UiChip` / `UiPips` widget'larındadır; bu sınıf sahnesiz ve birim testlidir.

const DEFAULT_PER_ICON: int = 10
const DEFAULT_MAX_ICONS: int = 5
const DEFAULT_PILE_FROM: int = 100
const DEFAULT_BLOCK: int = 5


## Jeton yerleşimi: {"icons": tek jeton sayısı, "pile": "çok" yığını var mı}.
## Pozitif her miktar en az 1 simge gösterir (sıfır dışında "boş" görünmesin).
static func coin_layout(amount: int, display: Dictionary = {}) -> Dictionary:
	var per_icon: int = maxi(ProgressData.to_count(display.get("per_icon"), DEFAULT_PER_ICON), 1)
	var max_icons: int = maxi(ProgressData.to_count(display.get("max_icons"), DEFAULT_MAX_ICONS), 1)
	var pile_from: int = maxi(ProgressData.to_count(display.get("pile_from"), DEFAULT_PILE_FROM), 1)
	var safe: int = maxi(amount, 0)
	var icons: int = 0
	if safe > 0:
		icons = clampi(ceili(float(safe) / float(per_icon)), 1, max_icons)
	return {"icons": icons, "pile": safe >= pile_from}


## Seviye noktaları: {"total": blok uzunluğu, "done": bloktaki biten sayısı, "current": şu anki nokta,
## "hard_last": son nokta zor seviye}. `level_number` 1 tabanlıdır.
static func level_pips(level_number: int, block: int = DEFAULT_BLOCK) -> Dictionary:
	var size: int = maxi(block, 2)
	var position: int = (maxi(level_number, 1) - 1) % size
	return {"total": size, "done": position, "current": position, "hard_last": true}


## Blok ayarı `balance.json`dan.
static func block_size(level_pips_table: Dictionary) -> int:
	var value: int = ProgressData.to_count(level_pips_table.get("block"), DEFAULT_BLOCK)
	return maxi(value, 2) if value > 0 else DEFAULT_BLOCK
